function newProjectPath = autoUpdateProjectPath(projectNewName, projectOldName, currentProjectPath)

    if nargin < 3;  currentProjectPath = ''; end

    % Initialize a folder path based if one is not given
    if isempty(currentProjectPath)
        rootdir = utility.path.getAncestorDir(nansen.rootpath, 1);
        projectRootFolder = fullfile(rootdir, '_userdata', 'projects');

        projectRootFolder = getpref('NansenSetup', 'DefaultProjectPath', projectRootFolder);
    else
        projectRootFolder = currentProjectPath;
    end

    % Make sure the last folder of the path is the project folder
    [folderPath, fileName] = fileparts(projectRootFolder);
    if strcmp(fileName, projectOldName)
        newProjectPath = fullfile(folderPath, projectNewName);
    else
        newProjectPath = fullfile(projectRootFolder, projectNewName);
    end

end