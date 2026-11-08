function reorganizeProjectFolder(projectFolderPath, projectManager)
% reorganizeProjectFolder - Reorganize a project folder based on
% refactoring/upgrading the project folder template

%   Steps:
%
%   - Make backup
%   - Load old project config
%   - Remove project from projectManager
%   - Use project manager to create new project
%   - Move old files from backup to original project folder
%       metadata
%       session methods
%       table variables
%       configs
%
%   If a step fails, the project folder is restored from the backup, a
%   project that was in the catalog is put back there, and the error is
%   rethrown. The folder then still has the old layout, so the upgrade can
%   be tried again. If the folder or the catalog entry can not be put back,
%   the error NANSEN:ProjectManager:ProjectRollbackFailed is thrown instead,
%   and its message names the backup folder.

    % Make backup
    projectFolderPathBackup = backupProjectFolder(projectFolderPath);

    removedCatalogEntry = struct.empty;

    try
        % Load old project configuration file
        S = loadOldConfigurations(projectFolderPathBackup);
        name = S.ProjectConfiguration.Name;
        description = S.ProjectConfiguration.Description;

        % If project is current,
        wasCurrent = false;
        if strcmp(projectManager.CurrentProject, name)
            wasCurrent = true;
            projectManager.changeProject('')
        end

        % Remove project from projectManager
        if projectManager.containsProject(name)
            removedCatalogEntry = projectManager.getProject(name);
            projectManager.removeProject(name)
        end

        % Create new project
        makeCurrentProject = wasCurrent;
        projectManager.createProject(name, description, projectFolderPath, makeCurrentProject)

        % Move files and folders
        projectPackageName = ['+', S.ProjectConfiguration.Name];

        % Move session methods
        oldSessionMethodFolder = fullfile(projectFolderPathBackup, 'Session Methods', projectPackageName);
        newSessionMethodFolder = fullfile(projectFolderPath, 'code', projectPackageName, '+sessionmethod');
        copyfile(oldSessionMethodFolder, newSessionMethodFolder)

        if isfolder(fullfile(projectFolderPathBackup, 'Metadata Tables', '+tablevar'))
            nansen.internal.refactor.moveTableVarsToProjectNameSpace( projectFolderPathBackup )
        end

        % Move table variables methods
        oldTableVarFolder = fullfile(projectFolderPathBackup, 'Metadata Tables', projectPackageName, '+tablevar');
        newTableVarFolder = fullfile(projectFolderPath, 'code', projectPackageName, '+tablevariable');
        copyfile(oldTableVarFolder, newTableVarFolder)

        % Copy metadata:
        oldMetadataFolder = fullfile(projectFolderPathBackup, 'Metadata Tables');
        newMetadataFolder = fullfile(projectFolderPath, 'metadata', 'tables');
        copyfile(oldMetadataFolder, newMetadataFolder)

        % Remove table variable folder:
        rmdir( fullfile(newMetadataFolder, projectPackageName), "s" )

        % Copy config files
        oldConfigFolder = fullfile(projectFolderPathBackup, 'Configurations');
        newConfigFolder = fullfile(projectFolderPath, 'configurations');
        copyfile(oldConfigFolder, newConfigFolder)

        % Rename options files:
        L = recursiveDir(fullfile(newConfigFolder, 'custom_options'), 'Type', 'file', 'FileType', 'mat');
        filePaths = utility.dir.abspath(L);

        projectName = S.ProjectConfiguration.Name;
        for i = 1:numel(filePaths)
            thisFilePath = filePaths{i};
            newFilePath = strrep(thisFilePath, [projectName, '.'], sprintf('%s.sessionmethod.', projectName));
            if ~strcmp(thisFilePath, newFilePath)
                movefile(thisFilePath, newFilePath)
            end
        end
    catch upgradeError
        rollbackErrors = undoUpgrade(projectManager, removedCatalogEntry, ...
            projectFolderPath, projectFolderPathBackup);

        if ~isempty(rollbackErrors)
            throwRollbackFailure(upgradeError, rollbackErrors, projectFolderPathBackup)
        end

        rethrow(upgradeError)
    end
end

function rollbackErrors = undoUpgrade(projectManager, catalogEntry, projectFolderPath, backupFolderPath)
%undoUpgrade Put a removed catalog entry and the project folder back
%
%   Each step runs also when the other one fails. A project whose folder
%   can not be restored is then still listed and reported as missing, and
%   a catalog that refuses the entry does not cost the project its folder.
%
%   Output:
%       rollbackErrors - Cell array with the error of each step that failed

    arguments
        projectManager (1,1) nansen.config.project.ProjectManager
        catalogEntry struct
        projectFolderPath (1,1) string
        backupFolderPath (1,1) string
    end

    rollbackErrors = {};

    try
        restoreCatalogEntry(projectManager, catalogEntry)
    catch rollbackError
        rollbackErrors{end+1} = rollbackError;
    end

    try
        restoreProjectFolder(projectFolderPath, backupFolderPath)
    catch rollbackError
        rollbackErrors{end+1} = rollbackError;
    end
end

function restoreCatalogEntry(projectManager, catalogEntry)
%restoreCatalogEntry Add a removed project back to the catalog
%
%   createProject adds the project to the catalog before the later steps of
%   the upgrade run, so the entry is already there if one of those failed.

    arguments
        projectManager (1,1) nansen.config.project.ProjectManager
        catalogEntry struct
    end

    if isempty(catalogEntry) || projectManager.containsProject(catalogEntry.Name)
        return
    end

    projectManager.addProject(catalogEntry.Name, catalogEntry.Description, catalogEntry.Path)
end

function restoreProjectFolder(projectFolderPath, backupFolderPath)
%restoreProjectFolder Replace a project folder with its backup

    arguments
        projectFolderPath (1,1) string
        backupFolderPath (1,1) string
    end

    if isfolder(projectFolderPath)
        rmdir(projectFolderPath, 's')
    end
    copyfile(backupFolderPath, projectFolderPath);
end

function throwRollbackFailure(upgradeError, rollbackErrors, backupFolderPath)
%throwRollbackFailure Report that a failed upgrade could not be undone
%
%   The error that stopped the upgrade is the first cause, because a report
%   of the failure names that error as its reason.

    arguments
        upgradeError (1,1) MException
        rollbackErrors (1,:) cell
        backupFolderPath (1,1) string
    end

    rollbackMessages = string(cellfun(@(rollbackError) rollbackError.message, ...
        rollbackErrors, UniformOutput=false));

    exception = MException("NANSEN:ProjectManager:ProjectRollbackFailed", ...
        "The project could not be put back after the failed update: %s " + ...
        "The folder as it was before the update is in ""%s"".", ...
        strjoin(rollbackMessages, " "), backupFolderPath);

    exception = exception.addCause(upgradeError);
    for i = 1:numel(rollbackErrors)
        exception = exception.addCause(rollbackErrors{i});
    end

    throw(exception)
end

function backupFolderPath = backupProjectFolder(projectFolderPath)

    [~, projectName] = fileparts(projectFolderPath);

    dateStr = char( datetime('now', 'Format', 'yyyy_MM_dd') );
    timeStr = char( datetime('now', 'Format', '''T''_HHmmss') );
    backupFolderPath = fullfile(userpath, 'Nansen', 'Backup', dateStr, 'Projects', [timeStr, '_', projectName]);
    if ~isfolder(backupFolderPath); mkdir(backupFolderPath); end

    % Make backup:
    try
        copyfile(projectFolderPath, backupFolderPath);
        rmdir(projectFolderPath, 's')
    catch
        [~, projectName] = fileparts(projectFolderPath);
        error('Something went wrong during backup of project "%s".', projectName)
    end
end

function S = loadOldConfigurations(projectFolderPath)

% Load project configuration
    oldConfigurationFileName = 'nansen_project_configuration.mat';
    filePath = fullfile(projectFolderPath, oldConfigurationFileName);
    S = load(filePath, 'ProjectConfiguration');
end
