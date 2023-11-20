function sessionMethodPathList = listSessionMethods(integrationNames)
%collectSessionMethods Collect known session methods for current project

    % Todo: Delete (deprecated)

    if nargin < 1
        integrationNames = 'ophys.twophoton';
    end
    
    % Get folder for the general session methods.
    
    %sesMethodRootFolder = nansen.localpath('sessionmethods');
    sesMethodRootFolder = '';
    integrationDirs = utility.path.packagename2pathstr(integrationNames);
    sesMethodRootPathList = fullfile(sesMethodRootFolder, integrationDirs);
    
    % Get folder for the current project's session methods
    projectMethodsPath = nansen.session.methods.getProjectsSessionMethodsDirectory();
    
    sesMethodRootPathList = [sesMethodRootPathList; {projectMethodsPath}];
    
    %ignoreList = {'+abstract', '+template'};

    
    % Find all folders
    finished = false;
    packagePathList = {};

    while ~finished

        [absPath, ~] = utility.path.listSubDir(sesMethodRootPathList);

        if isempty(absPath) || isequal(absPath, sesMethodRootPathList)
            finished = true;
        else
            packagePathList = [packagePathList, absPath];
            sesMethodRootPathList = absPath;
        end
    end
     
    
    
    % Find all matlab functions in the session methods folders.
    L = [];

    for i = 1:numel(packagePathList)
        
        L_ = dir(fullfile(packagePathList{i}, '*.m'));
        if i == 1
            L = L_;
        else
            L = cat(1, L, L_);
        end
        
    end
    
    sessionMethodPathList = fullfile({L.folder}, {L.name});
    
    % Transpose to column vector for easier readability on disp
    sessionMethodPathList = transpose(sessionMethodPathList);
    
end


function tf = validateIntegration(integrationFolder)


end