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
    
    % Make backup
    projectFolderPathBackup = backupProjectFolder(projectFolderPath);

    % If something fails, move backup back to original location
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
        L = utility.dir.recursiveDir(fullfile(newConfigFolder, 'custom_options'), 'Type', 'file', 'FileType', 'mat');
        filePaths = utility.dir.abspath(L);
    
        projectName = S.ProjectConfiguration.Name;
        for i = 1:numel(filePaths)
            thisFilePath = filePaths{i};
            newFilePath = strrep(thisFilePath, [projectName, '.'], sprintf('%s.sessionmethod.', projectName));
            if ~strcmp(thisFilePath, newFilePath)
                movefile(thisFilePath, newFilePath)
            end
        end
    catch ME %#ok<NASGU>
        if isfolder(projectFolderPath)
            rmdir(projectFolderPath, 'S')
        end
        copyfile(projectFolderPathBackup, projectFolderPath);
    end
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