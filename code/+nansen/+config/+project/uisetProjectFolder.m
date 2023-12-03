function newFolder = uisetProjectFolder(currentFolder, projectName)

    % Todo: Should this be a method of project manager???

    % Get the default project save location to use as initial path for
    % uigetdir
    currentFolder = getpref('NansenSetup', 'DefaultProjectPath', currentFolder);
    
    
    newFolder = uigetdir(currentFolder, 'Select New Project Folder');
            
    % Return if user canceled during uigetdir dialog
    if newFolder == 0; return; end

    [~, fileName] = fileparts(newFolder);
    
    % Make sure the last folder of the path is the project name
    if ~strcmp(fileName, projectName)
        newFolder = fullfile(newFolder, projectName);
    end

    % Set default project folder to where user selected the new folder.
    projectRootFolder = fileparts(newFolder);
    setpref('NansenSetup', 'DefaultProjectPath', projectRootFolder);

end