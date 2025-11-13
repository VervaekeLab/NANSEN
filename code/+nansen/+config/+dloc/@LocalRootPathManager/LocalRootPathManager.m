classdef LocalRootPathManager < handle
%LocalRootPathManager Manages local root path settings for data locations
%
%   This class handles the management of local root paths, including:
%   - Loading and saving local root path settings
%   - Resolving disk names across different platforms
%   - Converting paths between different operating systems
%   - Managing volume information for dynamic drive mounting

    properties (Access = private)
        % SettingsFolder - Path to a folder for saving and loading settings file
        SettingsFolder string
        
        % VolumeInfo - A table of volume information
        VolumeInfo table

        % RootPathListOriginal - A list of original root paths that are
        % temporarily replaced by the local root paths managed by this class
        RootPathListOriginal
    end

    properties (Access = private)
        SettingsFilePath (1,1) string
    end
    
    properties (Constant, Access = private)
        SETTINGS_FILE_BASE_NAME = "datalocation_local_rootpath_settings"
    end
    
    % Constructor
    methods
        function obj = LocalRootPathManager(settingsFolder)
        %LocalRootPathManager Constructor
        %
        %   obj = LocalRootPathManager(projectPath) creates a new manager
        %   instance for the specified project path.

            arguments
                settingsFolder (1,1) string {mustBeFolder}
            end
            obj.SettingsFolder = settingsFolder;
        end
    end

    methods
        function configureLocalRootPath(obj, localRootPath, originalRootPath)
            % Todo: Should be checking and update storage backends for rootpaths as well
            fp = obj.createSettingsFilepath("json");
            fileStr = fileread(fp);

            fileStr = strrep(fileStr, originalRootPath, localRootPath);
            utility.filewrite(fp, fileStr)
        end

        function data = importLocalRootPaths(obj, data, preferences)
        %importLocalRootPaths Import local root paths and replace in data
        %
        %   data = importLocalRootPaths(obj, data, preferences) loads local
        %   root path settings and replaces the root paths in the data
        %   structure with local versions. The original root paths are
        %   stored for later restoration.
            
            % Store the originals in RootPathListOriginal property
            n = numel(data);
            [obj.RootPathListOriginal(1:n).Uuid] = data.Uuid;
            [obj.RootPathListOriginal(1:n).RootPath] = data.RootPath;
            
            computerID = utility.system.getComputerName(true);
            isSource = isequal(preferences.SourceID, computerID);
            
            if obj.hasLocalSettingsFile() && ~isSource
                S_ = obj.loadLocalSettings();
                reference = S_.RootPathListLocal;
                data = obj.updateRootPathFromReference(data, reference);
            end
        end
        
        function [data, rootPathList] = exportLocalRootPaths(obj, data, preferences)
        %exportLocalRootPaths Export local root paths and restore originals
        %
        %   [data, rootPathList] = exportLocalRootPaths(obj, data, preferences)
        %   saves the current local root paths and restores the original
        %   root paths in the data structure. Returns the modified data and
        %   the local root path list that was saved.
            
            computerID = utility.system.getComputerName(true);
            rootPathList = [];
            
            if ~isequal(preferences.SourceID, computerID)
                
                % 1) Save current root path list to local file
                n = numel(data);
                [rootPathList(1:n).Uuid] = data.Uuid;
                [rootPathList(1:n).RootPath] = data.RootPath;
                
                obj.saveLocalSettings(rootPathList);
                
                % 2) Restore originals
                reference = obj.RootPathListOriginal;
                data = obj.updateRootPathFromReference(data, reference);
            end
        end
        
        function target = updateRootPathFromReference(obj, target, source)
        %updateRootPathFromReference Update rootpath struct from reference
        %
        %   target = updateRootPathFromReference(obj, target, source) updates
        %   the rootpath struct based on the reference. The diskname is only
        %   copied if the disktype is local, to handle drives that should be
        %   equal across different systems vs drives that should not.
            
            for iDloc = 1:numel(source)
                
                thisUuid = source(iDloc).Uuid;
                targetIdx = find(strcmp( {target.Uuid}, thisUuid));
                
                if ~isempty(targetIdx) % Original rootpath list must exist
                    
                    iSource = source(iDloc);
                    iTarget = target(targetIdx);

                    if ~isempty(iSource)
                        continue
                    end
                    
                    referenceKeys = {iSource.RootPath.Key};
                    
                    for jKey = 1:numel(referenceKeys)
                        
                        thisKey = iSource.RootPath(jKey).Key;
                        keyIdx = find(strcmp( {iTarget.RootPath.Key}, thisKey ));
                        
                        if isempty(keyIdx)
                            continue;
                        else
                            iTarget.RootPath(keyIdx).Value = iSource.RootPath(jKey).Value;
                            
                            if isfield(iTarget.RootPath, 'DiskType')
                                % Do nothing, this should always be kept
                                % based on the current selection.
                            end
                            
                            if isfield(iSource.RootPath, 'DiskName')
                                if isfield(iTarget.RootPath, 'DiskType') && ...
                                        strcmp(iTarget.RootPath(keyIdx).DiskType, 'Local')
                                    iTarget.RootPath(keyIdx).DiskName = iSource.RootPath(jKey).DiskName;
                                end
                            end
                        end
                    end
                    
                    target(targetIdx) = iTarget;
                end
            end
        end
        
        function data = updateRootPathFromDiskName(obj, data)
        %updateRootPathFromDiskName Ensure path matches diskname for root
        %
        %   data = updateRootPathFromDiskName(obj, data) updates root paths
        %   based on disk names. On Windows, drive mounts for external drives
        %   are dynamic, and a drive might be mounted with different letters
        %   from time to time. This method updates the root path based on the
        %   name of the disk and the current letter assignment.
            
            if ispc
                volumeInfo = nansen.external.fex.sysutil.listMountedDrives();
                
                for i = 1:numel(data) % Loop through DataLocations
                    if ~isfield(data(i), 'RootPath')
                        continue
                    end
                    
                    if ~isfield(data(i).RootPath, 'DiskName')
                        data(i).RootPath = obj.addDiskNameToRootPathStruct(data(i).RootPath);
                    end
                    
                    for j = 1:numel(data(i).RootPath) % Loop through root folders
                        jDiskName = data(i).RootPath(j).DiskName;
                        
                        % If not assigned previously, diskName defaults to
                        % an empty double, but here, change it to a string.
                        if isempty(jDiskName) && isa(jDiskName, 'double')
                            jDiskName = "";
                        end
                        
                        isMatch = volumeInfo.VolumeName == jDiskName;
                        
                        if any(isMatch)
                            if sum(isMatch) > 1
                                warning('Multiple disks have the same name (%s)', jDiskName);
                            end
                            diskLetter = volumeInfo.DeviceID(isMatch);
                        else
                            diskLetter = sprintf('%d:', j);
                        end
                        
                        % Todo: Remove:
                        % Replace symbol that was meant to indicate drive
                        % is not connected, which turned out to be
                        % troublesome:
                        if strncmp(data(i).RootPath(j).Value, '~', 1)
                            data(i).RootPath(j).Value(1)=num2str(i);
                        end
                        
                        platformName = obj.pathIsWhichPlatform(data(i).RootPath(j).Value);
                        conversion = [platformName, '2', 'pc'];
                        
                        try
                            updatedPath = obj.replaceDiskMountInPath(data(i).RootPath(j).Value, diskLetter, conversion);
                        catch
                            updatedPath = data(i).RootPath(j).Value;
                        end
                        data(i).RootPath(j).Value = updatedPath;
                        
                        if ~isfolder( data(i).RootPath(j).Value )
                            % warning('Root not available')
                        end
                    end
                end
            else
                % Pass
                % Todo: root path was created in windows
            end
        end
        
        function diskName = resolveDiskName(obj, rootPath)
        %resolveDiskName Resolve disk name for given root path
        %
        %   diskName = resolveDiskName(obj, rootPath) returns the disk name
        %   for the specified root path, using platform-specific methods.
            
            if ismac
                diskName = obj.resolveDiskNameMac(rootPath);
            elseif ispc
                diskName = obj.resolveDiskNamePc(rootPath);
            elseif isunix
                diskName = obj.resolveDiskNameLinux(rootPath);
            end
        end
        
        function updateVolumeInfo(obj, volumeInfo)
        %updateVolumeInfo Update the volume info table
        %
        %   updateVolumeInfo(obj) updates volume info using system utilities.
        %   updateVolumeInfo(obj, volumeInfo) uses the provided volume info.
            
            import nansen.external.fex.sysutil.listMountedDrives
            if nargin < 2
                volumeInfo = listPhysicalDrives();
            end
            obj.VolumeInfo = volumeInfo;
        end
    end
       
    % Methods to handle settings file
    methods (Access = private)
        function filePath = createSettingsFilepath(obj, fileType)
        % createSettingsFilepath - Get file path for local root path settings
        %
        %   filePath = createSettingsFilepath(obj) returns the default .mat
        %   file path for local root path settings.
        %
        %   filePath = createSettingsFilepath(obj, fileType) specifies the
        %   file type ('mat' or 'json').
            
            arguments
                obj
                fileType (1,1) string = 'mat'
            end
            
            fileName = obj.SETTINGS_FILE_BASE_NAME + "." + fileType;
            filePath = fullfile(obj.SettingsFolder, fileName);
        end
           
        function tf = hasLocalSettingsFile(obj)
        %hasLocalSettingsFile Check if local settings file exists
        %
        %   tf = hasLocalSettingsFile(obj) returns true if a local root
        %   path settings file exists (either .mat or .json format).
            
            filePath = obj.createSettingsFilepath();
            
            if isfile(filePath)
                tf = true;
            elseif isfile(strrep(filePath, '.mat', '.json'))
                tf = true;
            else
                tf = false;
            end
        end
        
        function S = loadLocalSettings(obj)
        %loadLocalSettings Load local root path settings from file
        %
        %   S = loadLocalSettings(obj) loads and returns the local root
        %   path settings structure from file.
            
            filePath = obj.createSettingsFilepath();
            
            if isfile(filePath)
                S = load(filePath);
            elseif isfile(strrep(filePath, '.mat', '.json'))
                S = jsondecode(fileread(strrep(filePath, '.mat', '.json')));
            else
                error('File with local datalocation root paths were not found.')
            end
        end
        
        function saveLocalSettings(obj, rootPathList)
        %saveLocalSettings Save local root path settings to file
        %
        %   saveLocalSettings(obj, rootPathList) saves the provided root
        %   path list to the local settings file in JSON format.
            
            S_.RootPathListLocal = rootPathList;
            filePath = obj.createSettingsFilepath('json');
            utility.filewrite(filePath, jsonencode(S_, 'PrettyPrint', true));
        end
    end

    % Cross-platform path name utility methods
    methods (Static)
        function platformName = pathIsWhichPlatform(pathStr)
        %pathIsWhichPlatform Determine platform which a path is native to
        %
        %   platformName = pathIsWhichPlatform(obj, pathStr) returns the
        %   platform name ('mac', 'pc', 'unix', or 'unknown') based on the
        %   path string format/composition.

            platformName = nansen.util.path.detectPlatform(pathStr);
        end

        function pathStr = replaceDiskMountInPath(pathStr, mount, conversionType)
        %replaceDiskMountInPath Convert paths between platforms
        %
        %   pathStr = replaceDiskMountInPath(obj, pathStr, mount, conversionType)
        %   converts a path string from one platform format to another,
        %   replacing the disk mount point appropriately.

            pathStr = nansen.util.path.convertPlatformPath(pathStr, mount, conversionType);
        end
    end
    
    methods (Access = private)
        
        function diskName = resolveDiskNamePc(obj, rootPath)
        %resolveDiskNamePc Resolve disk name given disk letter (Windows)
            
            if isempty(obj.VolumeInfo)
                obj.updateVolumeInfo()
            end
            
            diskLetter = string(regexp(rootPath, '.*:', 'match'));
            try
                matchedIdx = find( obj.VolumeInfo.DeviceID == diskLetter );
            catch
                matchedIdx = [];
            end
            if ~isempty(matchedIdx)
                diskName = obj.VolumeInfo.VolumeName(matchedIdx);
            else
                diskName = '';
            end
        end
        
        function diskName = resolveDiskNameMac(obj, rootPath)
        %resolveDiskNameMac Resolve disk name for macOS
            
            splitPath = strsplit(rootPath, '/');
            matchedIdx = find( strcmp(splitPath, 'Volumes') ) + 1;
            if ~isempty(matchedIdx)
                diskName = splitPath{matchedIdx};
            else
                diskName = '';
            end
        end
        
        function diskName = resolveDiskNameLinux(obj, rootPath)
        %resolveDiskNameLinux Resolve disk name for a given root path on Linux
        %
        %   This function uses the Linux "df" command to determine the device
        %   associated with rootPath, and then "lsblk" to query the device for its
        %   volume label. If a label exists, it is returned as the disk name.
            
            % Use df to find the device corresponding to rootPath.
            % The -P option forces POSIX output format.
            [status, dfOutput] = system(sprintf('df -P "%s" | tail -1', rootPath));
            if status ~= 0 || isempty(dfOutput)
                diskName = '';
                return;
            end
            
            % The first token of the output is the device name.
            tokens = strsplit(strtrim(dfOutput));
            if isempty(tokens)
                diskName = '';
                return;
            end
            device = tokens{1};
            
            % Now use lsblk to get the LABEL for that device.
            % The -n option omits the header and -o LABEL selects the label column.
            [status, labelOutput] = system(sprintf('lsblk -no LABEL "%s"', device));
            if status == 0 && ~contains(labelOutput, 'not a block device')
                diskLabel = strtrim(labelOutput);
                if ~isempty(diskLabel)
                    diskName = diskLabel;
                    return;
                end
            end
            
            % Fallback: if no label is available, return the device name.
            diskName = device;
        end
        
        function rootPathStruct = addDiskNameToRootPathStruct(obj, rootPathStruct)
        %addDiskNameToRootPathStruct Add disk names to root path structure
            
            for i = 1:numel(rootPathStruct)
                rootPathStruct(i).DiskName = ...
                    obj.resolveDiskName(rootPathStruct(i).Value);
            end
        end
    end
end
