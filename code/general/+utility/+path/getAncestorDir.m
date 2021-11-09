function pathStr = getAncestorDir(pathStr, numFoldersUp)
%PATHTOOLS.GETPARENTDIR Get path to parent directory 
%
%   pathStr = getAncestorDir(pathStr) return the path to the folder 
%
%   pathStr = getAncestorDir(pathStr, N) return the path to a directory 3 
%   nodes up in the folder hierarchy.  

    if nargin < 2
        numFoldersUp = 0;
    end
    
    % Check if the current path is a file or a folder:
    [folderPath, fileName, ~] = fileparts(pathStr);
    if ~isempty(fileName)
        pathStr = folderPath;
    end
    
    % Loop backward from current folder n times.
    for i = 1:numFoldersUp
        pathStr = fileparts(pathStr);
    end

end