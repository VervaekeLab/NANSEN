function tf = isSubPath(pathStr, parentPath)
%isSubPath Check whether a path is located inside a parent folder
%
%   tf = isSubPath(pathStr, parentPath) returns true when pathStr names a
%   file or folder inside parentPath. A path equal to parentPath is not
%   inside it, and a sibling whose name merely starts with the parent's
%   name is not either.
%
%   Example:
%       nansen.util.path.isSubPath('/data/proj/a', '/data/proj')   % true
%       nansen.util.path.isSubPath('/data/project', '/data/proj')  % false
%
%   See also nansen.util.path.isSamePath

    arguments
        pathStr (1,:) char
        parentPath (1,:) char
    end

    parentPath = nansen.util.path.stripTrailingSeparator(parentPath);

    tf = startsWith(string(pathStr), strcat(parentPath, filesep), "IgnoreCase", ispc);
end
