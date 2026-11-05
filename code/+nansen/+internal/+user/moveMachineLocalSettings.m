function moveMachineLocalSettings(userDataDirectory)
%moveMachineLocalSettings Move machine specific files out of the shared settings folder
%
%   moveMachineLocalSettings(userDataDirectory) moves task_list.mat and
%   watch_folder_catalog.mat from the settings folder of userDataDirectory
%   to nansen.localdatadir(userDataDirectory), where nansen.localpath looks
%   for them as "TaskList" and "WatchFolderCatalog". The settings folder
%   holds preferences that can be shared between machines, while these
%   files name queued work and folders of one machine.
%
%   A file that the machine specific folder already holds is not
%   overwritten: the file in the settings folder stays where it is, and a
%   warning names both.
%
%   See also nansen.localdatadir, nansen.localpath

    arguments
        userDataDirectory (1,1) string
    end

    machineLocalFileNames = ["task_list.mat", "watch_folder_catalog.mat"];

    settingsFolder = fullfile(userDataDirectory, "settings");
    localFolder = string( nansen.localdatadir(userDataDirectory) );

    for fileName = machineLocalFileNames
        sourcePath = fullfile(settingsFolder, fileName);
        targetPath = fullfile(localFolder, fileName);

        if isfile(sourcePath) && isfile(targetPath)
            warning('NANSEN:UserSession:MachineLocalFileConflict', ...
                ['"%s" was not moved to "%s", because that folder already ' ...
                 'holds a file of the same name. NANSEN uses "%s".'], ...
                sourcePath, localFolder, targetPath)
        elseif isfile(sourcePath)
            if ~isfolder(localFolder); mkdir(localFolder); end
            movefile(sourcePath, targetPath)
        end
    end
end
