function tf = isAbsolutePath(pathStr)
%isAbsolutePath Check whether a path is absolute on this platform
%
%   tf = isAbsolutePath(pathStr) returns true when pathStr is rooted, so
%   that it resolves to the same location regardless of the current folder.
%
%   A leading "~" is not treated as absolute, because MATLAB's file
%   functions do not expand it.
%
%   Example:
%       nansen.util.path.isAbsolutePath('/data/projects')   % true
%       nansen.util.path.isAbsolutePath('data/projects')    % false
%
%   See also fullfile, isfolder

    arguments
        pathStr (1,:) char
    end

    if ispc
        % Drive letter, or a UNC share
        tf = ~isempty( regexp(pathStr, '^([A-Za-z]:[\\/]|\\\\)', 'once') );
    else
        tf = startsWith(pathStr, '/');
    end
end
