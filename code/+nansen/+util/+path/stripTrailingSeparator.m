function pathStr = stripTrailingSeparator(pathStr)
%stripTrailingSeparator Remove trailing file separators from a path
%
%   pathStr = stripTrailingSeparator(pathStr) removes any trailing file
%   separators, so that two paths naming the same folder compare equal. A
%   path consisting only of a separator is returned unchanged.
%
%   Example:
%       nansen.util.path.stripTrailingSeparator('/data/projects/')
%       % Returns '/data/projects'
%
%   See also nansen.util.path.isSamePath

    arguments
        pathStr (1,:) char
    end

    while numel(pathStr) > 1 && strcmp(pathStr(end), filesep)
        pathStr(end) = [];
    end
end
