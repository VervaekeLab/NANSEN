function tf = isSubPath(pathStr, parentPath)
%isSubPath Check whether a path is located inside a parent folder
%
%   tf = isSubPath(pathStr, parentPath) returns true when pathStr names a
%   file or folder inside parentPath. A path equal to parentPath is not
%   inside it, and a sibling whose name merely starts with the parent's
%   name is not either.
%
%   Case is ignored on the platforms where nansen.util.path.isSamePath
%   ignores it, Windows and macOS.
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

    pathStr = nansen.util.path.stripTrailingSeparator(pathStr);
    parentPath = nansen.util.path.stripTrailingSeparator(parentPath);

    % A root, such as / or Z:\, keeps its separator
    if ~endsWith(parentPath, filesep)
        parentPath = [parentPath, filesep];
    end

    tf = numel(pathStr) > numel(parentPath) ...
        && startsWith(pathStr, parentPath, "IgnoreCase", ispc || ismac);
end
