function tf = isSamePath(pathA, pathB)
%isSamePath Check whether two paths name the same folder
%
%   tf = isSamePath(pathA, pathB) compares two paths, ignoring trailing
%   file separators.
%
%   The comparison ignores case on Windows and macOS, because their default
%   volumes (NTFS and APFS) do not distinguish names by case. On a volume
%   formatted as case-sensitive, two folders whose names differ only in
%   case are reported as the same.
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

    if ispc || ismac
        tf = strcmpi(pathA, pathB);
    else
        tf = strcmp(pathA, pathB);
    end
end
