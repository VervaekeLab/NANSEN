function newProjectPath = autoUpdateProjectPath(projectNewName, projectOldName, currentProjectPath)

    if nargin < 3;  currentProjectPath = ''; end

    % Initialize a folder path based if one is not given
    if isempty(currentProjectPath)
        projectRootFolder = fullfile(nansen.rootpath, '_userdata', 'projects');

        projectRootFolder = getpref('NansenSetup', 'DefaultProjectPath', projectRootFolder);
    else
        projectRootFolder = currentProjectPath;
    end

    % Make sure the last folder of the path is the project folder
    [folderPath, fileName] = fileparts(projectRootFolder);
    if strcmp(fileName, projectOldName)
        projectRootFolder = folderPath;
    end
    
    setpref('NansenSetup', 'DefaultProjectPath', projectRootFolder);

    newProjectPath = fullfile(projectRootFolder, projectNewName);


end