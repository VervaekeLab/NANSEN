function report = mergeUserDataFromReleases(options)
%mergeUserDataFromReleases Gather user data from every MATLAB release on this computer
%
%   nansen.internal.user.mergeUserDataFromReleases() looks through the
%   preference directory of every MATLAB release on this computer and
%   prints what it would merge into the user data directory of each NANSEN
%   profile. It changes nothing.
%
%   nansen.internal.user.mergeUserDataFromReleases(Apply=true) carries out
%   the merge. Close NANSEN in other MATLAB sessions first.
%
%   report = nansen.internal.user.mergeUserDataFromReleases(___) returns a
%   struct array with one element for each profile that has data to merge.
%
%   A session moves only the data of its own release, and sets aside the
%   data of a release that starts later, so a project known to one release
%   is missing from the catalog that another release moved first. This
%   function brings the data of all releases together:
%
%   - Project catalogs are combined. The entries of the catalog in the user
%     data directory are kept as they are. A project that several releases
%     list at the same path is added once. For a name listed at different
%     paths, a path that exists is preferred over one that does not, and
%     then the most recently saved catalog. The other path is reported.
%   - A project folder kept inside a preference directory is copied to the
%     user data directory, and its catalog entry is updated.
%   - The files in settings, custom_options and local are combined file by
%     file. A file that the user data directory holds is not overwritten.
%     Between releases the most recently changed content is used. MATLAB
%     copies the preference directory when a release is installed, which
%     dates the copies by the installation, so copies with the same content
%     count as one, dated by the oldest of them.
%   - Machine specific project configurations go to the machine specific
%     folder of the user data directory, where NANSEN looks for them.
%
%   Folders that a session set aside, named <folder>.unmigrated, are
%   included. Afterwards every folder that was merged is renamed to
%   <folder>.migrated, so that no session moves it again. Nothing is
%   deleted, so a copy that was not used stays in its .migrated folder.
%
%   If a step fails, the files added so far are removed and the preference
%   directories are left as they were.
%
%   Name-value arguments:
%       Apply          - Carry out the merge. Default is false.
%       Profiles       - Names of the profiles to merge. Default is every
%                        profile that has data.
%       PreferenceRoot - Folder that holds the preference directories of
%                        the releases. Default is the parent of prefdir.
%       UserDataRoot   - Folder to merge the profiles into, one subfolder
%                        each. Default is the user data directory of each
%                        profile.
%       Verbose        - Print what is merged. Default is true.
%
%   See also nansen.internal.user.migrateUserDataFolders,
%   nansen.internal.user.NansenUserSession/getUserDataDirectory

    arguments
        options.Apply (1,1) logical = false
        options.Profiles (1,:) string = string.empty(1, 0)
        options.PreferenceRoot (1,1) string = string(fileparts(prefdir))
        options.UserDataRoot (1,1) string = ""
        options.Verbose (1,1) logical = true
    end

    releaseFolders = findReleaseFolders(options.PreferenceRoot);
    profileNames = findProfileNames(releaseFolders);

    if ~isempty(options.Profiles)
        profileNames = profileNames(ismember(profileNames, options.Profiles));
    end

    plans = cell(1, numel(profileNames));
    for i = 1:numel(profileNames)
        plans{i} = planProfileMerge(profileNames(i), releaseFolders, options.UserDataRoot);
    end
    plans = [plans{:}];

    if ~isempty(plans)
        plans = plans([plans.HasDataToMerge]);
    end

    if options.Verbose
        printPlans(plans, releaseFolders, options.Apply)
    end

    if options.Apply
        assertProfilesAreNotInUse(plans)

        for i = 1:numel(plans)
            applyPlan(plans(i))
        end

        if options.Verbose && ~isempty(plans)
            fprintf(['\nMerged. The folders that were merged are renamed to ' ...
                '<folder>.migrated in each preference directory.\n'])
        end
    end

    report = createReport(plans);

    if ~nargout
        clear report
    end
end

function releaseFolders = findReleaseFolders(preferenceRoot)
%findReleaseFolders List the preference directories with NANSEN data, oldest release first

    listing = dir(preferenceRoot);
    names = string({listing([listing.isdir]).name});
    names = sort(names(matches(names, "R" + digitsPattern(4) + lettersPattern(1))));

    releaseFolders = fullfile(preferenceRoot, names);
    releaseFolders = releaseFolders(isfolder(fullfile(releaseFolders, "Nansen")));
    releaseFolders = reshape(releaseFolders, 1, []);
end

function profileNames = findProfileNames(releaseFolders)
%findProfileNames List the names of the profiles in the preference directories

    profileNames = strings(1, 0);

    for releaseFolder = releaseFolders
        profileNames = [profileNames, listSubfolders(fullfile(releaseFolder, "Nansen"))]; %#ok<AGROW>
    end

    profileNames = unique(profileNames);
end

function names = listSubfolders(folderPath)
%listSubfolders List the names of the folders in a folder, as a row of strings

    listing = dir(folderPath);
    names = reshape(string({listing([listing.isdir]).name}), 1, []);
    names(startsWith(names, ".")) = [];
end

function plan = planProfileMerge(profileName, releaseFolders, userDataRoot)
%planProfileMerge Work out what a merge does for one profile, without changing anything

    import nansen.config.project.ProjectManager

    if strlength(userDataRoot) > 0
        targetDirectory = fullfile(userDataRoot, profileName);
    else
        targetDirectory = string( ...
            nansen.internal.user.NansenUserSession.getUserDataDirectory(profileName));
    end

    catalogPath = string(ProjectManager.getCatalogPath(char(targetDirectory)));
    localDirectory = string(nansen.localdatadir(targetDirectory));

    sources = findSourceFolders(releaseFolders, profileName, targetDirectory);

    [entries, projectConflicts, numSourceEntries, unreadableFolders] = ...
        mergeCatalogs(catalogPath, sources, targetDirectory);

    candidates = collectFileCandidates(sources, entries, targetDirectory, localDirectory);
    [fileCopies, fileConflicts] = resolveFileCandidates(candidates);
    [folderCopies, folderConflicts] = planProjectFolderCopies(entries);

    sourceFolders = reshape(string({sources.Path}), 1, []);
    sourceFolders(ismember(sourceFolders, unreadableFolders)) = [];

    plan = struct( ...
        'Profile', profileName, ...
        'TargetDirectory', targetDirectory, ...
        'CatalogPath', catalogPath, ...
        'Entries', entries, ...
        'FileCopies', fileCopies, ...
        'FolderCopies', folderCopies, ...
        'ProjectConflicts', projectConflicts, ...
        'FileConflicts', fileConflicts, ...
        'FolderConflicts', folderConflicts, ...
        'SourceFolders', sourceFolders, ...
        'IsCatalogChanged', any(~[entries.IsInTarget]), ...
        'HasDataToMerge', numSourceEntries > 0 || ~isempty(candidates));
end

function sources = findSourceFolders(releaseFolders, profileName, targetDirectory)
%findSourceFolders List the user data folders of one profile, oldest release first

    userDataFolderNames = ["projects", "settings", "custom_options", "local"];

    sources = struct('Release', {}, 'ProfileFolder', {}, 'FolderName', {}, 'Path', {});

    for releaseFolder = releaseFolders
        profileFolder = fullfile(releaseFolder, "Nansen", profileName);

        % The preference directory can be the chosen user data directory
        if ~isfolder(profileFolder) ...
                || nansen.util.path.isSamePath(char(profileFolder), char(targetDirectory))
            continue
        end

        [~, release] = fileparts(releaseFolder);
        subfolders = listSubfolders(profileFolder);

        for folderName = userDataFolderNames
            setAsidePattern = folderName + ".unmigrated" + optionalPattern("_" + digitsPattern);
            isSource = subfolders == folderName | matches(subfolders, setAsidePattern);

            for subfolder = subfolders(isSource)
                sources(end+1) = struct('Release', release, ...
                    'ProfileFolder', profileFolder, 'FolderName', folderName, ...
                    'Path', fullfile(profileFolder, subfolder)); %#ok<AGROW>
            end
        end
    end
end

function [entries, conflicts, numSourceEntries, unreadableFolders] = ...
        mergeCatalogs(catalogPath, sources, targetDirectory)
%mergeCatalogs Combine the catalog in the user data directory with those of the releases

    entries = emptyEntries();
    conflicts = struct('Project', {}, 'UsedPath', {}, 'OtherPath', {}, 'OtherRelease', {});
    numSourceEntries = 0;
    unreadableFolders = strings(1, 0);

    if isfile(catalogPath)
        S = load(catalogPath, 'projectCatalog');
        for rawEntry = reshape(S.projectCatalog, 1, [])
            entries(end+1) = createEntry(rawEntry, ...
                nansen.util.path.stripTrailingSeparator(char(rawEntry.Path)), ...
                strings(1, 0), "", true); %#ok<AGROW>
        end
    end

    catalogSources = sources(string({sources.FolderName}) == "projects");

    if isempty(catalogSources)
        return
    end

    % The most recently saved catalog goes first, and an entry that is
    % already there takes precedence over a later one
    catalogFiles = fullfile([catalogSources.Path], "project_catalog.mat");
    catalogFiles = reshape(catalogFiles, 1, []);
    hasCatalog = isfile(catalogFiles);
    catalogSources = catalogSources(hasCatalog);
    catalogFiles = catalogFiles(hasCatalog);

    savedTimes = arrayfun(@(filePath) dir(filePath).datenum, catalogFiles);
    [~, newestFirst] = sort(savedTimes, 'descend');

    for iCatalog = reshape(newestFirst, 1, [])
        source = catalogSources(iCatalog);

        try
            S = load(catalogFiles(iCatalog), 'projectCatalog');
            sourceEntries = reshape(S.projectCatalog, 1, []);
        catch ME
            warning('NANSEN:UserSession:UnreadableProjectCatalog', ...
                ['Could not read "%s", so that folder is not merged and stays ' ...
                 'where it is.\nReason: %s'], catalogFiles(iCatalog), ME.message)
            unreadableFolders(end+1) = source.Path; %#ok<AGROW>
            continue
        end

        numSourceEntries = numSourceEntries + numel(sourceEntries);

        for rawEntry = sourceEntries
            [projectPath, copyFrom] = resolveProjectPath(rawEntry.Path, source, targetDirectory);
            index = find(strcmp({entries.Name}, char(rawEntry.Name)), 1);

            if isempty(index)
                entries(end+1) = createEntry(rawEntry, projectPath, ...
                    source.Release, copyFrom, false); %#ok<AGROW>

            elseif nansen.util.path.isSamePath(entries(index).Path, projectPath)
                entries(index).Releases = unique([entries(index).Releases, source.Release]);

            elseif ~entries(index).IsInTarget && ~isProjectFolderFound(entries(index)) ...
                    && (isfolder(projectPath) || strlength(copyFrom) > 0)
                conflicts(end+1) = struct('Project', string(rawEntry.Name), ...
                    'UsedPath', string(projectPath), ...
                    'OtherPath', string(entries(index).Path), ...
                    'OtherRelease', strjoin(entries(index).Releases, ", ")); %#ok<AGROW>
                entries(index).Path = projectPath;
                entries(index).CopyFrom = copyFrom;
                entries(index).Releases = source.Release;

            else
                conflicts(end+1) = struct('Project', string(rawEntry.Name), ...
                    'UsedPath', string(entries(index).Path), ...
                    'OtherPath', string(projectPath), ...
                    'OtherRelease', source.Release); %#ok<AGROW>
            end
        end
    end
end

function entries = emptyEntries()
%emptyEntries Create an empty list of merged catalog entries

    entries = struct('Name', {}, 'ShortName', {}, 'Description', {}, 'Path', {}, ...
        'Releases', {}, 'CopyFrom', {}, 'IsInTarget', {});
end

function entry = createEntry(rawEntry, projectPath, releases, copyFrom, isInTarget)
%createEntry Create a merged entry from a catalog entry of any NANSEN version
%
%   Older catalogs have no ShortName field and can hold strings, while the
%   project manager expects character vectors. A project's short name is
%   its name, as in ProjectManager/createProjectInfo.

    name = char(rawEntry.Name);

    shortName = name;
    if isfield(rawEntry, 'ShortName') && strlength(string(rawEntry.ShortName)) > 0
        shortName = char(rawEntry.ShortName);
    end

    description = '';
    if isfield(rawEntry, 'Description')
        description = char(rawEntry.Description);
    end

    entry = struct('Name', name, 'ShortName', shortName, 'Description', description, ...
        'Path', projectPath, 'Releases', releases, 'CopyFrom', copyFrom, ...
        'IsInTarget', isInTarget);
end

function [projectPath, copyFrom] = resolveProjectPath(storedPath, source, targetDirectory)
%resolveProjectPath Find where a catalog entry's project folder is and where it ends up
%
%   A project folder inside the preference directory has to move with the
%   data. A catalog saved there names it by its place in the projects
%   folder, also when that folder has since been renamed.

    projectPath = nansen.util.path.stripTrailingSeparator(char(storedPath));
    copyFrom = "";

    originalFolder = char(fullfile(source.ProfileFolder, "projects"));

    if nansen.util.path.isSubPath(projectPath, originalFolder)
        relativePath = extractAfter(string(projectPath), strlength(originalFolder) + 1);
        copyFrom = fullfile(source.Path, relativePath);
        projectPath = char(fullfile(targetDirectory, "projects", relativePath));
    end
end

function tf = isProjectFolderFound(entry)
%isProjectFolderFound Check whether the folder of a merged entry exists on this computer

    tf = isfolder(entry.Path) || (strlength(entry.CopyFrom) > 0 && isfolder(entry.CopyFrom));
end

function candidates = collectFileCandidates(sources, entries, targetDirectory, localDirectory)
%collectFileCandidates List every file in the releases and where it would go

    machineLocalFileNames = ["task_list.mat", "watch_folder_catalog.mat"];

    candidates = emptyCandidates();

    for source = reshape(sources, 1, [])
        switch source.FolderName
            case "settings"
                newCandidates = listCandidates(source, fullfile(targetDirectory, "settings"));

                % These name queued work and folders of this computer
                for i = 1:numel(newCandidates)
                    [~, name, extension] = fileparts(newCandidates(i).SourcePath);
                    if ismember(name + extension, machineLocalFileNames)
                        newCandidates(i).TargetPath = fullfile(localDirectory, name + extension);
                    end
                end

            case "projects"
                newCandidates = listLocalProjectCandidates(source, entries, localDirectory);

            otherwise
                newCandidates = listCandidates(source, fullfile(targetDirectory, source.FolderName));
        end

        candidates = [candidates, newCandidates]; %#ok<AGROW>
    end
end

function candidates = emptyCandidates()
%emptyCandidates Create an empty list of file candidates

    candidates = struct('SourcePath', {}, 'TargetPath', {}, 'ModifiedTime', {}, 'Release', {});
end

function candidates = listLocalProjectCandidates(source, entries, localDirectory)
%listLocalProjectCandidates List the machine specific configurations of the projects
%
%   A subfolder of a projects folder holds the configurations of a project
%   on this computer, unless it is the project folder itself. A subfolder
%   with no entry in the merged catalog belongs to a removed project.

    candidates = emptyCandidates();

    for projectName = listSubfolders(source.Path)
        index = find(strcmp({entries.Name}, char(projectName)), 1);
        if isempty(index)
            continue
        end

        folderPath = fullfile(source.Path, projectName);
        if nansen.util.path.isSamePath(char(entries(index).CopyFrom), char(folderPath))
            continue
        end

        projectSource = source;
        projectSource.Path = folderPath;
        targetFolder = fullfile(localDirectory, "projects", projectName);
        candidates = [candidates, listCandidates(projectSource, targetFolder)]; %#ok<AGROW>
    end
end

function candidates = listCandidates(source, targetFolder)
%listCandidates List the files of a folder and subfolders, with their target paths

    candidates = emptyCandidates();
    listing = dir(source.Path);

    for i = 1:numel(listing)
        name = string(listing(i).name);

        if any(name == [".", "..", ".DS_Store"])
            continue
        end

        if listing(i).isdir
            subfolderSource = source;
            subfolderSource.Path = fullfile(source.Path, name);
            candidates = [candidates, ...
                listCandidates(subfolderSource, fullfile(targetFolder, name))]; %#ok<AGROW>
        else
            candidates(end+1) = struct( ...
                'SourcePath', fullfile(source.Path, name), ...
                'TargetPath', fullfile(targetFolder, name), ...
                'ModifiedTime', listing(i).datenum, ...
                'Release', source.Release); %#ok<AGROW>
        end
    end
end

function [copies, conflicts] = resolveFileCandidates(candidates)
%resolveFileCandidates Decide which copy of each file to use

    copies = struct('SourcePath', {}, 'TargetPath', {});
    conflicts = struct('File', {}, 'UsedCopy', {}, 'OtherCopies', {});

    if isempty(candidates)
        return
    end

    targetPaths = [candidates.TargetPath];

    for targetPath = unique(targetPaths, "stable")
        group = candidates(targetPaths == targetPath);

        if isfile(targetPath)
            existingContent = readFileBytes(targetPath);
            isOther = arrayfun(@(c) ~isequal(readFileBytes(c.SourcePath), existingContent), group);
            usedCopy = "user data directory";
            otherCopies = [group(isOther).Release];
        else
            [chosen, otherCopies] = chooseNewestContent(group);
            usedCopy = chosen.Release;
            copies(end+1) = struct('SourcePath', chosen.SourcePath, ...
                'TargetPath', targetPath); %#ok<AGROW>
        end

        if ~isempty(otherCopies)
            conflicts(end+1) = struct('File', targetPath, ...
                'UsedCopy', usedCopy, 'OtherCopies', strjoin(otherCopies, ", ")); %#ok<AGROW>
        end
    end
end

function [chosen, otherReleases] = chooseNewestContent(group)
%chooseNewestContent Choose the most recently changed content among copies of a file
%
%   MATLAB copies the preference directory when a release is installed,
%   and the copies are dated by the installation. Copies with the same
%   content are counted as one, dated by the oldest of them, so that an
%   untouched copy does not win over a later change in another release.

    contents = arrayfun(@(c) readFileBytes(c.SourcePath), group, 'UniformOutput', false);

    contentIds = zeros(1, numel(group));
    for i = 1:numel(group)
        contentIds(i) = find(cellfun(@(other) isequal(other, contents{i}), contents), 1);
    end

    uniqueIds = unique(contentIds);
    contentDates = arrayfun(@(id) min([group(contentIds == id).ModifiedTime]), uniqueIds);

    [~, newest] = max(contentDates);
    isChosen = contentIds == uniqueIds(newest);

    chosen = group(find(isChosen, 1));
    otherReleases = [group(~isChosen).Release];
end

function bytes = readFileBytes(filePath)
%readFileBytes Read the content of a file for comparison

    fileId = fopen(filePath, 'r');
    closeFile = onCleanup(@() fclose(fileId));
    bytes = fread(fileId, inf, '*uint8');
end

function [copies, conflicts] = planProjectFolderCopies(entries)
%planProjectFolderCopies List the project folders to copy from a preference directory

    copies = struct('SourceFolder', {}, 'TargetFolder', {});
    conflicts = struct('Project', {}, 'TargetFolder', {}, 'SourceFolder', {});

    for entry = reshape(entries, 1, [])
        if strlength(entry.CopyFrom) == 0 || ~isfolder(entry.CopyFrom)
            continue
        end

        if isfolder(entry.Path)
            conflicts(end+1) = struct('Project', string(entry.Name), ...
                'TargetFolder', string(entry.Path), 'SourceFolder', entry.CopyFrom); %#ok<AGROW>
        else
            copies(end+1) = struct('SourceFolder', entry.CopyFrom, ...
                'TargetFolder', string(entry.Path)); %#ok<AGROW>
        end
    end
end

function assertProfilesAreNotInUse(plans)
%assertProfilesAreNotInUse Refuse to merge into the directory of the open session
%
%   An open session holds the catalog in memory, and overwrites the merged
%   catalog the next time it saves.

    import nansen.internal.user.NansenUserSession

    userSession = NansenUserSession.instance('', 'nocreate');
    if isempty(userSession) || isempty(plans)
        return
    end

    activeDirectory = userSession.getCurrentUserDataDirectory();

    isActive = arrayfun(@(plan) nansen.util.path.isSamePath( ...
        char(plan.TargetDirectory), activeDirectory), plans);

    if any(isActive)
        error('NANSEN:UserSession:ProfileInUse', ...
            ['The NANSEN session for the profile "%s" is open. Close it with ' ...
             'nansen.internal.user.NansenUserSession.reset(), and merge again.'], ...
            plans(find(isActive, 1)).Profile)
    end
end

function applyPlan(plan)
%applyPlan Carry out the merge of one profile

    wasTargetCreated = ~isfolder(plan.TargetDirectory);
    addedFiles = strings(1, 0);
    addedFolders = strings(1, 0);

    try
        for copy = reshape(plan.FileCopies, 1, [])
            makeParentFolder(copy.TargetPath)
            copyfile(copy.SourcePath, copy.TargetPath)
            addedFiles(end+1) = copy.TargetPath; %#ok<AGROW>
        end

        for copy = reshape(plan.FolderCopies, 1, [])
            makeParentFolder(copy.TargetFolder)
            copyfile(copy.SourceFolder, copy.TargetFolder)
            addedFolders(end+1) = copy.TargetFolder; %#ok<AGROW>
        end

        if plan.IsCatalogChanged
            writeCatalog(plan.CatalogPath, plan.Entries)
        end
    catch MECause
        removeAddedItems(plan.TargetDirectory, wasTargetCreated, addedFiles, addedFolders)

        ME = MException('NANSEN:UserSession:MergeUserDataFailed', ...
            ['Could not merge the data of the profile "%s" into "%s". The ' ...
             'preference directories were left as they were.'], ...
            plan.Profile, plan.TargetDirectory);
        ME = ME.addCause(MECause);
        throw(ME)
    end

    renameMergedFolders(plan.SourceFolders)
end

function makeParentFolder(itemPath)
%makeParentFolder Create the folder that an item goes into

    parentFolder = fileparts(itemPath);

    if ~isfolder(parentFolder)
        mkdir(parentFolder)
    end
end

function writeCatalog(catalogPath, entries)
%writeCatalog Save the merged catalog in the form that the project manager uses
%
%   The file is written beside the catalog and then moved over it, so that
%   a failed save leaves the existing catalog as it was.

    projectCatalog = rmfield(entries, {'Releases', 'CopyFrom', 'IsInTarget'});

    makeParentFolder(catalogPath)

    temporaryPath = catalogPath + ".merging.mat";
    save(temporaryPath, 'projectCatalog')
    movefile(temporaryPath, catalogPath, 'f')
end

function removeAddedItems(targetDirectory, wasTargetCreated, addedFiles, addedFolders)
%removeAddedItems Remove what a failed merge added to the user data directory

    if wasTargetCreated
        if isfolder(targetDirectory)
            [~] = rmdir(targetDirectory, 's');
        end
        return
    end

    for filePath = addedFiles
        delete(filePath)
    end

    for folderPath = addedFolders
        [~] = rmdir(folderPath, 's');
    end
end

function renameMergedFolders(folderPaths)
%renameMergedFolders Mark merged folders, so that no session moves them again
%
%   A failure is a warning, because the data has been merged. A session
%   sets aside a folder that was not renamed, and says so.

    for folderPath = folderPaths
        baseName = extractBefore(folderPath + ".unmigrated", ".unmigrated");
        newPath = findUnusedPath(baseName + ".migrated");

        try
            movefile(folderPath, newPath)
        catch ME
            warning('NANSEN:UserSession:MergedFolderNotRenamed', ...
                'The data in "%s" was merged, but the folder could not be renamed.\nReason: %s', ...
                folderPath, ME.message)
        end
    end
end

function folderPath = findUnusedPath(basePath)
%findUnusedPath Append a number to a path until nothing exists at it

    folderPath = basePath;
    suffix = 1;

    while isfolder(folderPath) || isfile(folderPath)
        suffix = suffix + 1;
        folderPath = basePath + "_" + suffix;
    end
end

function printPlans(plans, releaseFolders, isApply)
%printPlans Print what the merge does for each profile

    [~, releaseNames] = arrayfun(@fileparts, releaseFolders, 'UniformOutput', false);
    fprintf('NANSEN data was found in these MATLAB releases: %s\n', ...
        strjoin(string(releaseNames), ", "))

    if isempty(plans)
        fprintf('There is nothing to merge.\n')
        return
    end

    for plan = plans
        fprintf('\nProfile "%s" goes to %s\n', plan.Profile, plan.TargetDirectory)
        printProjects(plan)
        fprintf('  Files to copy: %d\n', numel(plan.FileCopies))
        printConflicts(plan)
    end

    if ~isApply
        fprintf(['\nNothing was changed. To carry out the merge, run ' ...
            'nansen.internal.user.mergeUserDataFromReleases(Apply=true)\n'])
    end
end

function printProjects(plan)
%printProjects Print the projects of the merged catalog

    numAdded = sum(~[plan.Entries.IsInTarget]);
    fprintf('  Projects: %d, of which %d new to the catalog\n', numel(plan.Entries), numAdded);

    for entry = reshape(plan.Entries, 1, [])
        if isProjectFolderFound(entry)
            status = "";
        else
            status = "  (folder not found: " + entry.Path + ")";
        end

        if entry.IsInTarget
            origin = "already there";
        else
            origin = strjoin(entry.Releases, ", ");
        end

        fprintf('    %-36s %s%s\n', entry.Name, origin, status)
    end
end

function printConflicts(plan)
%printConflicts Print the choices made between different copies of the same item

    for conflict = reshape(plan.ProjectConflicts, 1, [])
        fprintf('  Project "%s" has another path in %s, which is not used: %s\n', ...
            conflict.Project, conflict.OtherRelease, conflict.OtherPath)
    end

    for conflict = reshape(plan.FolderConflicts, 1, [])
        fprintf('  The folder of project "%s" is already at %s, so %s is not copied\n', ...
            conflict.Project, conflict.TargetFolder, conflict.SourceFolder)
    end

    if ~isempty(plan.FileConflicts)
        fprintf('  Files with different copies (the others stay in the .migrated folders):\n')

        for conflict = reshape(plan.FileConflicts, 1, [])
            relativePath = erase(conflict.File, plan.TargetDirectory + filesep);
            fprintf('    %s: using %s, not %s\n', relativePath, ...
                conflict.UsedCopy, conflict.OtherCopies)
        end
    end
end

function report = createReport(plans)
%createReport Describe the merge of each profile, for the caller

    report = struct('Profile', {}, 'TargetDirectory', {}, 'Projects', {}, ...
        'FileCopies', {}, 'FolderCopies', {}, 'ProjectConflicts', {}, ...
        'FileConflicts', {}, 'FolderConflicts', {}, 'SourceFolders', {});

    for i = 1:numel(plans)
        plan = plans(i);

        projects = struct('Name', {plan.Entries.Name}, 'Path', {plan.Entries.Path}, ...
            'Releases', {plan.Entries.Releases}, 'IsNew', num2cell(~[plan.Entries.IsInTarget]));

        report(i) = struct('Profile', plan.Profile, ...
            'TargetDirectory', plan.TargetDirectory, ...
            'Projects', projects, ...
            'FileCopies', plan.FileCopies, ...
            'FolderCopies', plan.FolderCopies, ...
            'ProjectConflicts', plan.ProjectConflicts, ...
            'FileConflicts', plan.FileConflicts, ...
            'FolderConflicts', plan.FolderConflicts, ...
            'SourceFolders', plan.SourceFolders);
    end
end
