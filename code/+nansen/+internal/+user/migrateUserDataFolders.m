function result = migrateUserDataFolders(sourceDirectory, targetDirectory, folderNames, options)
%migrateUserDataFolders Move user data folders to a directory that may hold some already
%
%   result = migrateUserDataFolders(sourceDirectory, targetDirectory,
%   folderNames) moves each folder in folderNames from sourceDirectory into
%   targetDirectory, like nansen.internal.user.moveUserDataFolders.
%
%   A folder that targetDirectory already holds with content, for example a
%   project catalog that another MATLAB release or another machine moved
%   there first, is not merged into. The copy in sourceDirectory is renamed
%   to <name>.unmigrated, or to <name>.unmigrated_2 and so on if that name
%   is taken, and stays in sourceDirectory. An empty copy is removed
%   instead, since it holds nothing to keep. No file is deleted.
%
%   result = migrateUserDataFolders(..., IsTargetInitialized=false) states
%   that no session has set up targetDirectory, so that what it holds was
%   left by a session that kept running while NANSEN was updated. Such a
%   folder is renamed to <name>.leftover in targetDirectory, or to
%   <name>.leftover_2 and so on if that name is taken, and the folder from
%   sourceDirectory takes its place. The default is true.
%
%   result = migrateUserDataFolders(..., CanReceiveFolders=false) states
%   that targetDirectory has moved on to a later layout than the folders in
%   sourceDirectory are in. Each of those folders is then renamed to
%   <name>.unmigrated as above, also when targetDirectory has no folder of
%   that name. The default is true.
%
%   result is a struct with the fields
%       MovedFolderNames    - names of the folders moved to targetDirectory
%       RenamedFolderNames  - names of the folders renamed in sourceDirectory
%       RenamedFolderPaths  - paths of those folders after the rename
%       LeftoverFolderPaths - paths of the folders renamed in targetDirectory
%
%   If a step fails, the steps done before it are undone, so both
%   directories are left as they were, and the error is thrown.
%
%   See also nansen.internal.user.moveUserDataFolders

    arguments
        sourceDirectory (1,1) string
        targetDirectory (1,1) string
        folderNames (1,:) string
        options.IsTargetInitialized (1,1) logical = true
        options.CanReceiveFolders (1,1) logical = true
    end

    sourceFolders = fullfile(sourceDirectory, folderNames);
    targetFolders = fullfile(targetDirectory, folderNames);

    isPresent = isfolder(sourceFolders);
    isTaken = false(size(folderNames));
    isEmptyCopy = false(size(folderNames));

    for i = find(isPresent)
        isTaken(i) = isfile(targetFolders(i)) ...
            || ( isfolder(targetFolders(i)) && ~isFolderEmpty(targetFolders(i)) );
        isEmptyCopy(i) = isFolderEmpty(sourceFolders(i));
    end

    isLeftover = ~options.IsTargetInitialized & isPresent & isTaken & ~isEmptyCopy;
    isTaken(isLeftover) = false;

    if ~options.CanReceiveFolders
        isTaken(isPresent) = true;
    end

    isToMove = isPresent & ~isTaken;
    isToRename = isPresent & isTaken & ~isEmptyCopy;
    isToRemove = isPresent & isTaken & isEmptyCopy;

    leftoverPaths = strings(size(folderNames));
    isLeftoverSetAside = false(size(folderNames));
    renamedPaths = strings(size(folderNames));
    isRenamed = false(size(folderNames));
    isRemoved = false(size(folderNames));

    % Folders are set aside before anything moves, because a rename is
    % undone by renaming back.
    try
        for i = find(isLeftover)
            leftoverPaths(i) = findUnusedPath(targetFolders(i) + ".leftover");
            movefile(targetFolders(i), leftoverPaths(i))
            isLeftoverSetAside(i) = true;
        end

        for i = find(isToRename)
            renamedPaths(i) = findUnusedPath(sourceFolders(i) + ".unmigrated");
            movefile(sourceFolders(i), renamedPaths(i))
            isRenamed(i) = true;
        end

        for i = find(isToRemove)
            rmdir(sourceFolders(i))
            isRemoved(i) = true;
        end

        nansen.internal.user.moveUserDataFolders( ...
            sourceDirectory, targetDirectory, folderNames(isToMove))
    catch MECause
        notRestored = [ ...
            restoreSetAsideFolders(sourceFolders, renamedPaths, isRenamed, isRemoved), ...
            restoreSetAsideFolders(targetFolders, leftoverPaths, isLeftoverSetAside, false(size(folderNames))) ];

        if isempty(notRestored)
            rethrow(MECause)
        end

        ME = MException('NANSEN:UserSession:RestoreUserDataFailed', ...
            ['Failed to move NANSEN user data from "%s" to "%s", and failed to ' ...
             'rename these folders back: %s.'], sourceDirectory, targetDirectory, ...
            strjoin(notRestored, ', '));
        ME = ME.addCause(MECause);
        throw(ME)
    end

    result = struct( ...
        'MovedFolderNames', folderNames(isToMove), ...
        'RenamedFolderNames', folderNames(isRenamed), ...
        'RenamedFolderPaths', renamedPaths(isRenamed), ...
        'LeftoverFolderPaths', leftoverPaths(isLeftoverSetAside) );
end

function notRestored = restoreSetAsideFolders(sourceFolders, renamedPaths, isRenamed, isRemoved)
%restoreSetAsideFolders Rename set aside folders back, and recreate removed empty ones

    notRestored = strings(1, 0);

    for i = find(isRenamed)
        try
            movefile(renamedPaths(i), sourceFolders(i))
        catch
            % The error thrown by the caller names every folder left renamed
            notRestored(end+1) = renamedPaths(i); %#ok<AGROW>
        end
    end

    for i = find(isRemoved)
        if ~isfolder(sourceFolders(i)); mkdir(sourceFolders(i)); end
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

function tf = isFolderEmpty(folderPath)
%isFolderEmpty Check whether a folder has no entries, hidden ones included

    listing = dir(folderPath);
    tf = all( ismember({listing.name}, {'.', '..'}) );
end
