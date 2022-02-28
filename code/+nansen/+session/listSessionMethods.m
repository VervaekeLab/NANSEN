function sessionMethodPathList = listSessionMethods(integrationNames)
%collectSessionMethods Collect known session methods for current project

    % Get folders where session methods functions are located.
    %defaultMethodsPath = fullfile(nansen.rootpath, '+session', '+methods');
    
    
    if nargin < 1
        integrationNames = 'ophys.twophoton';
    end
    
    sesMethodRootFolder = nansen.localpath('sessionmethods');
    
    integrationDirs = utility.path.packagename2pathstr(integrationNames);
    sesMethodRootPathList = fullfile(sesMethodRootFolder, integrationDirs);
    
    
    % Todo: create a function for this....
    projectRootPath = nansen.localpath('project');
    [~, projectName] = fileparts(projectRootPath);
    projectMethodsPath = fullfile(projectRootPath, ...
                'Session Methods', ['+', projectName] );
    
    
    sesMethodRootPathList = [sesMethodRootPathList; {projectMethodsPath}];
    
    %ignoreList = {'+abstract', '+template'};

    
    % Find all folders
    finished = false;
    packagePathList = {};

    while ~finished

        [absPath, ~] = utility.path.listSubDir(sesMethodRootPathList);

        if isempty(absPath)
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