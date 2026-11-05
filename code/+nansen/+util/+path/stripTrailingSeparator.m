function pathStr = stripTrailingSeparator(pathStr)
%stripTrailingSeparator Remove trailing file separators from a path
%
%   pathStr = stripTrailingSeparator(pathStr) removes any trailing file
%   separators, so that two paths naming the same folder compare equal.
%
%   A root keeps its separator. This covers a path consisting only of a
%   separator, and a drive letter followed by a separator, such as Z:\.
%   Without the separator, Z: names the current folder on drive Z rather
%   than the root of the drive.
%
%   Example:
%       nansen.util.path.stripTrailingSeparator('/data/projects/')
%       % Returns '/data/projects'
%
%   See also nansen.util.path.isSamePath

    arguments
        pathStr (1,:) char
    end

    while numel(pathStr) > 1 && pathStr(end) == filesep && ~isDriveRoot(pathStr)
        pathStr(end) = [];
    end
end

function tf = isDriveRoot(pathStr)
%isDriveRoot Check whether a path is a drive letter followed by a separator

    tf = numel(pathStr) == 3 && ismember(upper(pathStr(1)), 'A':'Z') ...
        && pathStr(2) == ':';
end
