function pathStr = getAncestorDir(pathStr, numFoldersUp)
%UTILITY.PATH.GETANCESTORDIR Get path to ancestor directory 
%
%   pathStr = getAncestorDir(pathStr) return the path to the parent folder
%   of the given pathStr. If pathStr points to a file, the returned folder is 
%   the parent folder of the folder containing the file.
%
%   pathStr = getAncestorDir(pathStr, N) return the path to a directory N 
%   nodes up in the folder hierarchy.  

    if nargin < 2
        numFoldersUp = 1;
    end
    
    % Check if the current path is a file or a folder. If it is a file, add
    % one to number of folders to traverse.
    if isfile(pathStr)
        % For files, first iteration below gives current folder.
        numFoldersUp = numFoldersUp + 1;
    end
    
    % Loop backward from current folder n times.
    for i = 1:numFoldersUp
        pathStr = fileparts(pathStr);
    end
end