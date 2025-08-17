function convertedPath = convertPlatformPath(pathStr, newMount, conversionType)
%convertPlatformPath Convert paths between platforms with mount point replacement
%
%   convertedPath = convertPlatformPath(pathStr, newMount, conversionType)
%   converts a path string from one platform format to another, replacing
%   the disk mount point appropriately.
%
%   INPUTS:
%   pathStr        - Original path string
%   newMount       - New mount point (drive letter, volume name, mount path, etc.)
%   conversionType - Type of conversion (see supported types below)
%
%   SUPPORTED CONVERSIONS:
%   'mac2pc'    - /Volumes/disk/path -> D:\path
%   'mac2mac'   - /Volumes/old/path -> /Volumes/new/path  
%   'mac2unix'  - /Volumes/disk/path -> /mnt/disk/path
%   'pc2mac'    - D:\path -> /Volumes/disk/path
%   'pc2pc'     - D:\path -> E:\path
%   'pc2unix'   - D:\path -> /mnt/disk/path
%   'unix2mac'  - /mnt/disk/path -> /Volumes/disk/path
%   'unix2pc'   - /mnt/disk/path -> D:\path
%   'unix2unix' - /mnt/old/path -> /mnt/new/path
%
%   EXAMPLES:
%   convertPlatformPath('/Volumes/MyDisk/data', 'D:', 'mac2pc')
%   % Returns: 'D:\data'
%
%   convertPlatformPath('C:\Users\john', '/home/shared', 'pc2unix')
%   % Returns: '/home/shared/Users/john'
%
%   convertPlatformPath('/mnt/storage/data', 'MyDisk', 'unix2mac')
%   % Returns: '/Volumes/MyDisk/data'

    arguments
        pathStr (1,1) string {mustBeTextScalar, mustBeNonmissing}
        newMount (1,1) string {mustBeTextScalar, mustBeNonmissing}
        conversionType (1,1) string {mustBeMember(conversionType, [...
            "mac2pc", "mac2mac", "mac2unix", ...
            "pc2mac", "pc2pc", "pc2unix", ...
            "unix2mac", "unix2pc", "unix2unix"])}
    end
    
    % Handle empty paths
    if strlength(pathStr) == 0
        convertedPath = "";
        return;
    end
    
    try
        % Perform the conversion based on type
        switch conversionType
            case 'mac2pc'
                convertedPath = convertMacToPc(pathStr, newMount);
            case 'mac2mac'
                convertedPath = convertMacToMac(pathStr, newMount);
            case 'mac2unix'
                convertedPath = convertMacToUnix(pathStr, newMount);
            case 'pc2mac'
                convertedPath = convertPcToMac(pathStr, newMount);
            case 'pc2pc'
                convertedPath = convertPcToPc(pathStr, newMount);
            case 'pc2unix'
                convertedPath = convertPcToUnix(pathStr, newMount);
            case 'unix2mac'
                convertedPath = convertUnixToMac(pathStr, newMount);
            case 'unix2pc'
                convertedPath = convertUnixToPc(pathStr, newMount);
            case 'unix2unix'
                convertedPath = convertUnixToUnix(pathStr, newMount);
        end
        
    catch ME
        % Provide meaningful error context
        error('utility:path:ConversionFailed', ...
            'Failed to convert path "%s" with mount "%s" using conversion "%s". Error: %s', ...
            pathStr, newMount, conversionType, ME.message);
    end
end

%% Mac Conversions
function convertedPath = convertMacToPc(pathStr, newMount)
%convertMacToPc Convert Mac path to PC format
    remainingPath = extractMacVolumePath(pathStr);
    if isempty(remainingPath)
        convertedPath = char(newMount);
    else
        convertedPath = fullfile(char(newMount), remainingPath);
        convertedPath = strrep(convertedPath, '/', '\');
    end
end

function convertedPath = convertMacToMac(pathStr, newMount)
%convertMacToMac Convert Mac path to different Mac volume
    remainingPath = extractMacVolumePath(pathStr);
    if isempty(remainingPath)
        convertedPath = sprintf('/Volumes/%s', newMount);
    else
        convertedPath = sprintf('/Volumes/%s/%s', newMount, remainingPath);
    end
end

function convertedPath = convertMacToUnix(pathStr, newMount)
%convertMacToUnix Convert Mac path to Unix mount format
    remainingPath = extractMacVolumePath(pathStr);
    newMount = ensureUnixMountFormat(newMount);
    
    if isempty(remainingPath)
        convertedPath = char(newMount);
    else
        convertedPath = sprintf('%s/%s', newMount, remainingPath);
    end
end

%% PC Conversions
function convertedPath = convertPcToMac(pathStr, newMount)
%convertPcToMac Convert PC path to Mac format
    remainingPath = extractPcDrivePath(pathStr);
    if isempty(remainingPath)
        convertedPath = sprintf('/Volumes/%s', newMount);
    else
        remainingPath = strrep(remainingPath, '\', '/');
        convertedPath = sprintf('/Volumes/%s/%s', newMount, remainingPath);
    end
end

function convertedPath = convertPcToPc(pathStr, newMount)
%convertPcToPc Convert PC path to different drive letter
    remainingPath = extractPcDrivePath(pathStr);
    if isempty(remainingPath)
        convertedPath = char(newMount);
    else
        convertedPath = sprintf('%s\\%s', newMount, remainingPath);
    end
end

function convertedPath = convertPcToUnix(pathStr, newMount)
%convertPcToUnix Convert PC path to Unix mount format
    remainingPath = extractPcDrivePath(pathStr);
    newMount = ensureUnixMountFormat(newMount);
    
    if isempty(remainingPath)
        convertedPath = char(newMount);
    else
        remainingPath = strrep(remainingPath, '\', '/');
        convertedPath = sprintf('%s/%s', newMount, remainingPath);
    end
end

%% Unix Conversions
function convertedPath = convertUnixToMac(pathStr, newMount)
%convertUnixToMac Convert Unix path to Mac format
    remainingPath = extractUnixMountPath(pathStr);
    if isempty(remainingPath)
        convertedPath = sprintf('/Volumes/%s', newMount);
    else
        convertedPath = sprintf('/Volumes/%s/%s', newMount, remainingPath);
    end
end

function convertedPath = convertUnixToPc(pathStr, newMount)
%convertUnixToPc Convert Unix path to PC format
    remainingPath = extractUnixMountPath(pathStr);
    if isempty(remainingPath)
        convertedPath = char(newMount);
    else
        convertedPath = fullfile(char(newMount), remainingPath);
        convertedPath = strrep(convertedPath, '/', '\');
    end
end

function convertedPath = convertUnixToUnix(pathStr, newMount)
%convertUnixToUnix Convert Unix path to different mount point
    remainingPath = extractUnixMountPath(pathStr);
    newMount = ensureUnixMountFormat(newMount);
    
    if isempty(remainingPath)
        convertedPath = char(newMount);
    else
        convertedPath = sprintf('%s/%s', newMount, remainingPath);
    end
end

%% Helper Functions for Path Extraction
function remainingPath = extractMacVolumePath(pathStr)
%extractMacVolumePath Extract path after /Volumes/VolumeName/
    pathParts = strsplit(pathStr, '/');
    
    if length(pathParts) < 3 || ~strcmp(pathParts{2}, 'Volumes')
        % Not a standard volume path or too short
        remainingPath = '';
        return;
    end
    
    if length(pathParts) > 3
        remainingPath = strjoin(pathParts(4:end), '/');
    else
        remainingPath = '';
    end
end

function remainingPath = extractPcDrivePath(pathStr)
%extractPcDrivePath Extract path after drive letter or UNC share
    
    % Handle UNC paths
    if startsWith(pathStr, "\\")
        parts = strsplit(pathStr, '\');
        if length(parts) > 4
            remainingPath = strjoin(parts(5:end), '\');
        else
            remainingPath = '';
        end
        return;
    end
    
    % Regular drive letter path
    if length(pathStr) >= 2 && pathStr(2) == ':'
        remainingPath = pathStr(3:end);
        if startsWith(remainingPath, "\")
            remainingPath = remainingPath(2:end);
        end
        if isempty(remainingPath)
            remainingPath = '';
        end
    else
        % No drive letter - treat entire path as remaining
        remainingPath = char(pathStr);
    end
end

function remainingPath = extractUnixMountPath(pathStr)
%extractUnixMountPath Extract path after common mount points
    
    % Common Unix mount prefixes to recognize
    commonMounts = {'/mnt/', '/media/', '/run/media/', '/mount/', '/data/', '/storage/'};
    
    for i = 1:length(commonMounts)
        mountPrefix = commonMounts{i};
        if startsWith(pathStr, mountPrefix)
            % Find the next directory separator after mount prefix
            pathAfterMount = pathStr(length(mountPrefix)+1:end);
            sepIdx = find(pathAfterMount == '/', 1);
            
            if isempty(sepIdx)
                % No subdirectories after mount point
                remainingPath = '';
            else
                remainingPath = pathAfterMount(sepIdx+1:end);
            end
            return;
        end
    end
    
    % Fallback: try to extract after first two directory levels
    % e.g., /any/mount/remaining -> remaining
    pathParts = strsplit(pathStr, '/');
    if length(pathParts) > 3
        remainingPath = strjoin(pathParts(4:end), '/');
    else
        remainingPath = '';
    end
end

function mountPath = ensureUnixMountFormat(newMount)
%ensureUnixMountFormat Ensure mount path follows Unix conventions
    
    % If newMount doesn't start with /, assume it's a mount name to be added to /mnt/
    if ~startsWith(newMount, "/")
        mountPath = sprintf('/mnt/%s', newMount);
    else
        mountPath = char(newMount);
    end
    
    % Remove trailing slash if present
    if endsWith(mountPath, "/") && length(mountPath) > 1
        mountPath = mountPath(1:end-1);
    end
end