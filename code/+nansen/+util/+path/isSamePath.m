function tf = isSamePath(pathA, pathB)
%isSamePath Check whether two paths name the same folder
%
%   tf = isSamePath(pathA, pathB) compares two paths, ignoring trailing
%   file separators. The comparison ignores case on Windows only, matching
%   how the platform resolves paths.
%
%   Example:
%       nansen.util.path.isSamePath('/data/projects', '/data/projects/')
%       % Returns true
%
%   See also nansen.util.path.isSubPath

    arguments
        pathA (1,:) char
        pathB (1,:) char
    end

    pathA = nansen.util.path.stripTrailingSeparator(pathA);
    pathB = nansen.util.path.stripTrailingSeparator(pathB);

    if ispc
        tf = strcmpi(pathA, pathB);
    else
        tf = strcmp(pathA, pathB);
    end
end
