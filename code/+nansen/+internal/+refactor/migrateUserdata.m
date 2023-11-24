function migrateUserdata(userSession)
%migrateUserdata Move the contents of _userdata to MATLAB's prefdir
%
%   The _userdata folder is a folder containing some important
%   configuration data, and it was originally part of the nansen repository
%   folder. This caused some problems when people reinstalled nansen
%   manually, and therefore the contents of this folder is now moved to
%   MATLAB's prefdir
    
    % Todo: If user projects are saved in the _userdata, move them to
    % userpath.

    fprintf( ['The "_userdata" folder which was originally part of the NANSEN ' ...
           'repository \nfolder will now be moved to MATLAB''s preferences ' ...
            'directory.\n'])

    oldPath = fullfile(nansen.rootpath, '_userdata');
    newPath = userSession.getPrefdir();

    dateStr = char( datetime('now', 'Format', 'yyyy_MM_dd') );
    timeStr = char( datetime('now', 'Format', '''T''_HHmmss') );

    backupPath = fullfile(userpath, 'Nansen', 'Backup', dateStr, 'Userdata', timeStr, '_userdata');
    if ~isfolder(backupPath); mkdir(backupPath); end
    
    try
        copyfile(oldPath, backupPath)
        copyfile(oldPath, newPath)
    catch ME
        newException = MException('NANSEN:UserDataMigrationFailed', ...
            'Could not copy userdata to new location. Please report!');
        newException = newException.addCause(ME);
        
        % Log the error message to the backup folder.
        errorFile = fullfile(backupPath, 'migration_failed_error.txt');
        utility.filewrite(errorFile, getReport(newException, 'extended'))
        throw(newException);
    end
    
    % If copy went fine, we can remove the original userdata folder from 
    % MATLAB's savepath and delete the folder from disk.
    rmpath(genpath(oldPath)); savepath
    disp('Removed _userdata from MATLAB''s search path and saved changes.')
    rmdir(oldPath, 's')
    fprintf('The "_userdata" folder was moved to %s\n', newPath)
    
    % Move the installed addons file.
    addonFilePathOld = fullfile(newPath, 'settings', 'installed_addons.mat');
    addonFilePathNew = fullfile(newPath, 'installed_addons.mat');
    movefile(addonFilePathOld, addonFilePathNew)

    % Update project catalog (if project data was located in _userdata):
    projectCatalogFilePath = fullfile(newPath, 'projects', 'project_catalog.mat');
    if isfile( projectCatalogFilePath )
        S = load(projectCatalogFilePath);
        for i = 1:numel(S.projectCatalog)
            thisPath = S.projectCatalog(i).Path;
            if contains(thisPath, oldPath)
                tempUpdatedPath = strrep(thisPath, oldPath, newPath);
                newProjectPath = moveProjectFolderToUserpath(tempUpdatedPath);
                S.projectCatalog(i).Path = newProjectPath;
            end
        end
        % Remove the Preferences field
        S.projectCatalog = rmfield(S.projectCatalog, 'Preferences');
        save(projectCatalogFilePath, '-struct', 'S');
    end
end


function newProjectFolderPath = moveProjectFolderToUserpath(projectFolderPath)
% moveProjectFolderToUserpath - Move a project folder to Nansen's userpath.
                    
    newRootPath = nansen.common.constant.DefaultProjectPath;
    [~, projectName] = fileparts(projectFolderPath);
    
    newProjectFolderPath = fullfile(newRootPath, projectName);

    movefile(projectFolderPath, newProjectFolderPath);

    % Move to files back.
    
    filesToKeepInOriginalLocation = {...
        'datalocation_local_rootpath_settings.mat', ...
        'task_list.mat' ...
    };

    for i = 1:numel(filesToKeepInOriginalLocation)
        iFilePath = fullfile(newProjectFolderPath, filesToKeepInOriginalLocation{i});
        if isfile( iFilePath )
            if ~isfolder(projectFolderPath); mkdir(projectFolderPath); end
            movefile( iFilePath, projectFolderPath);
        end
    end
end