function pathStr = getAncestorDir(pathStr, numFoldersUp)
%PATHTOOLS.GETPARENTDIR Get path to parent directory 
%
%   pathStr = getAncestorDir(pathStr) return the path to the folder 
%
%   pathStr = getAncestorDir(pathStr, N) return the path to a directory 3 
%   nodes up in the folder hierarchy.  

    % todo: fix line 17. Should check if ext is empty, not name...

    if nargin < 2
        numFoldersUp = 0;
    end
    
    % Check if the current path is a file or a folder:
    [folderPath, name, ext] = fileparts(pathStr);
    if ~isempty(name)
        pathStr = folderPath;
    end
    
    % Loop backward from current folder n times.
    for i = 1:numFoldersUp
        pathStr = fileparts(pathStr);
    end

end