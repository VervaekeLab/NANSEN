function platformName = detectPlatform(pathName)
%detectPlatform Determine which platform a path is native to
%
%   platformName = detectPlatform(pathStr) returns the platform name 
%   ('windows', 'mac', 'unix', or 'unknown') based on the path string format.
%
%   Supported formats:
%   - Windows: C:\path, D:\folder, \\server\share (UNC paths)
%   - Mac: /Volumes/diskname, /Users/username, /Applications/
%   - Unix/Linux: /home/user, /usr/local, /opt/, / (root)
%
%   Examples:
%       detectPlatform('C:\Users\john')           % returns 'windows'
%       detectPlatform('/Volumes/MyDisk')         % returns 'mac'
%       detectPlatform('/home/user')              % returns 'unix'
%       detectPlatform('\\server\share')          % returns 'windows'
%       detectPlatform('')                        % returns 'unknown'
%
%   See also: ispc, ismac, isunix

    arguments
        pathName (1,1) string {mustBeTextScalar}
    end

    platformName = 'unknown';

    % Handle empty or missing input
    if ismissing(pathName) || strlength(pathName) == 0
        return;
    end
    
    % Convert to char for consistent processing
    pathName = char(pathName);
    
    % Windows detection (check first due to specificity)
    if looksLikeWindows(pathName)
        platformName = 'windows';
        return;
    end
    
    % Mac detection (check before generic Unix)
    if looksLikeMac(pathName)
        platformName = 'mac';
        return;
    end
    
    % Unix/Linux detection
    if looksLikeUnix(pathName)
        platformName = 'unix';
        return;
    end
    
    % Default case
    platformName = 'unknown';
end

function isWin = looksLikeWindows(pathChar)
%looksLikeWindows Check if path follows Windows conventions
    % Drive letter pattern (C:, D:, etc.)
    isDriveLetter = length(pathChar) >= 2 && ...
                   isstrprop(pathChar(1), 'alpha') && ...
                   pathChar(2) == ':';
    
    % UNC path pattern (\\server\share)
    isUNC = length(pathChar) >= 2 && ...
            strcmp(pathChar(1:2), '\\');
    
    isWin = isDriveLetter || isUNC;
end

function isMacOS = looksLikeMac(pathChar)
%looksLikeMac Check if path follows macOS conventions
    macPrefixes = {'/Volumes/', '/Users/', '/Applications/', '/System/', '/Library/'};
    isMacOS = any(cellfun(@(prefix) startsWith(pathChar, prefix), macPrefixes));
end

function isUnixLike = looksLikeUnix(pathChar)
%looksLikeUnix Check if path follows Unix/Linux conventions
    % Must start with / or ~ and not be a Mac-specific path
    startsCorrectly = length(pathChar) >= 1 && ...
                     (pathChar(1) == '/' || pathChar(1) == '~');
    
    % Exclude Mac paths that were already checked
    isNotMac = ~looksLikeMac(pathChar);
    
    isUnixLike = startsCorrectly && isNotMac;
end
