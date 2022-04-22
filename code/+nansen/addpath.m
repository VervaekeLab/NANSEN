function addpath()
%NANSEN.ADDPATH Add Nansen folder to path.
%
%   This function makes sure nansen is on top of the path...Important,
%   because some functions in Nansen should take precedence over other
%   functions from toolboxes..
    
    currentpath = path;
    firstPathOnPath = regexp(currentpath, '.*?(?=:)', 'match', 'once');

    %nansenRootPath = nansen.localpath('root');
    nansenRootPath = utility.path.getAncestorDir(nansen.rootpath, 1);
    if isequal(firstPathOnPath, nansenRootPath); return; end
    
    warning('off', 'MATLAB:rmpath:DirNotFound')
    rmpath(genpath(nansenRootPath))
    warning('on', 'MATLAB:rmpath:DirNotFound')

    pathList = genpath(nansenRootPath);
    
    pathListCell = strsplit(pathList, ':');
    keep = ~contains(pathListCell, '.git');
    pathListCell = pathListCell(keep);
    pathListNoGit = strjoin(pathListCell, ':');
    
    addpath(pathListNoGit)
    
end

