function addpath()
%NANSEN.ADDPATH Add Nansen folder to path.
%
%   This function makes sure nansen is on top of the path...Important,
%   because some functions in Nansen should take precedence over other
%   functions from toolboxes..

%   Note (Todo): This should be solved in a different way, or users need 
%   to be informed of this behavior...
    
    currentpath = path;
    expression = sprintf('.*?(?=%s)', pathsep); % Everything before the first pathsep
    firstPathOnPath = regexp(currentpath, expression, 'match', 'once');

    nansenRootPath = nansen.rootpath();
    if isequal( firstPathOnPath, nansenRootPath ); return; end
    
    warning('off', 'MATLAB:rmpath:DirNotFound')
    rmpath(genpath(nansenRootPath))
    warning('on', 'MATLAB:rmpath:DirNotFound')

    pathList = genpath(nansenRootPath);
    
    pathListCell = strsplit(pathList, pathsep);
    keep = ~contains(pathListCell, '.git');
    pathListCell = pathListCell(keep);
    pathListNoGit = strjoin(pathListCell, pathsep);
    
    addpath(pathListNoGit)
end

