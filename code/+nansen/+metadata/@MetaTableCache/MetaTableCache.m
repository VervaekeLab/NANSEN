classdef MetaTableCache < handle
%MetaTableCache Shared cache for open MetaTable instances
%
%   MetaTableCache keeps one live MetaTable handle per canonical file path.
%   It also polls cached files for disk-version changes and emits one
%   FileChangedOnDisk event for each newly observed on-disk version.

    properties (Access = private)
        InstanceMap containers.Map
        LastNotifiedVersion containers.Map
        PollingTimer timer
        ProjectManagerListener event.listener
    end

    events
        FileChangedOnDisk
    end

    methods (Static)
        function obj = instance(mode)
        %instance Get or reset the shared MetaTableCache instance

            arguments
                mode (1,1) string {mustBeMember(mode, ["get", "reset"])} = "get"
            end

            appDataKey = 'NansenMetaTableCache';

            if mode == "reset"
                existing = getappdata(0, appDataKey);
                if ~isempty(existing) && isvalid(existing)
                    delete(existing)
                end
                if isappdata(0, appDataKey)
                    rmappdata(0, appDataKey)
                end
                obj = [];
                return
            end

            obj = getappdata(0, appDataKey);
            if isempty(obj) || ~isvalid(obj)
                obj = nansen.metadata.MetaTableCache();
                setappdata(0, appDataKey, obj);
            end
        end
    end

    methods (Static, Hidden)
        function filePath = canonicalizeFilePath(filePath)
        %canonicalizeFilePath Return a stable absolute path for cache keys
        %
        %   The cache must use one key for each physical file. Without
        %   canonicalization, relative paths, absolute paths, and paths with
        %   dot segments could create separate live MetaTable handles for the
        %   same file, breaking stale-save protection.

            filePath = char(filePath);
            [status, attributes] = fileattrib(filePath);
            if ~status
                error('NANSEN:MetaTableCache:FileNotFound', ...
                    'Cannot cache MetaTable because file does not exist: %s', filePath)
            end

            filePath = attributes.Name;
        end
    end

    methods (Access = private)
        function obj = MetaTableCache()
            obj.InstanceMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.LastNotifiedVersion = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.listenToProjectManager()
        end

        function initializePollingTimer(obj)
            obj.PollingTimer = timer( ...
                'Name', 'MetaTableCache Polling Timer', ...
                'ExecutionMode', 'fixedRate', ...
                'Period', 10, ...
                'TimerFcn', @(~,~) obj.checkForFileChanges());
        end

        function listenToProjectManager(obj)
            try
                projectManager = nansen.config.project.ProjectManager.instance();
                obj.ProjectManagerListener = addlistener(projectManager, ...
                    'CurrentProjectSet', @(~,~) obj.clear());
            catch ME
                warning('NANSEN:MetaTableCache:NoProjectManager', ...
                    ['Could not subscribe to ProjectManager.CurrentProjectSet; ', ...
                     'cache will not auto-clear on project switch. Reason: %s'], ...
                    ME.message)
            end
        end

        function removeCachedPath(obj, canonicalPath)
        %removeCachedPath Evict a path that is already a cache key

            if isKey(obj.InstanceMap, canonicalPath)
                remove(obj.InstanceMap, canonicalPath);
            end
            if isKey(obj.LastNotifiedVersion, canonicalPath)
                remove(obj.LastNotifiedVersion, canonicalPath);
            end
        end
    end

    methods
        function metaTable = get(obj, filePath)
        %get Return the cached MetaTable for a file path, if one exists

            canonicalPath = nansen.metadata.MetaTableCache.canonicalizeFilePath(filePath);
            if isKey(obj.InstanceMap, canonicalPath) && isvalid(obj.InstanceMap(canonicalPath))
                metaTable = obj.InstanceMap(canonicalPath);
            else
                metaTable = [];
            end
        end

        function add(obj, filePath, metaTable)
        %add Add a MetaTable instance to the cache

            canonicalPath = nansen.metadata.MetaTableCache.canonicalizeFilePath(filePath);
            obj.InstanceMap(canonicalPath) = metaTable;
        end

        function remove(obj, filePath)
        %remove Evict a MetaTable from the cache

            canonicalPath = nansen.metadata.MetaTableCache.canonicalizeFilePath(filePath);
            if isKey(obj.InstanceMap, canonicalPath)
                remove(obj.InstanceMap, canonicalPath);
            end
            if isKey(obj.LastNotifiedVersion, canonicalPath)
                remove(obj.LastNotifiedVersion, canonicalPath);
            end
        end

        function clear(obj)
        %clear Evict all cached MetaTable instances

            obj.InstanceMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.LastNotifiedVersion = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        function pauseFileChangeMonitoring(obj)
        %pauseFileChangeMonitoring Pause background file-change monitoring

            if ~isempty(obj.PollingTimer) && isvalid(obj.PollingTimer) ...
                    && strcmp(obj.PollingTimer.Running, 'on')
                stop(obj.PollingTimer)
            end
        end

        function startFileChangeMonitoring(obj)
        %startFileChangeMonitoring Start app-managed file-change monitoring

            if isempty(obj.PollingTimer) || ~isvalid(obj.PollingTimer)
                obj.initializePollingTimer()
            end

            if strcmp(obj.PollingTimer.Running, 'off')
                start(obj.PollingTimer)
            end
        end

        function resumeFileChangeMonitoring(obj)
        %resumeFileChangeMonitoring Resume background file-change monitoring

            obj.startFileChangeMonitoring()
        end

        function checkForFileChanges(obj)
        %checkForFileChanges Poll cached MetaTables for on-disk changes

            filePaths = keys(obj.InstanceMap);
            for i = 1:numel(filePaths)
                filePath = filePaths{i};
                metaTable = obj.InstanceMap(filePath);

                if ~isvalid(metaTable) || ~isfile(filePath)
                    obj.removeCachedPath(filePath);
                    continue
                end

                try
                    if metaTable.isLatestVersion()
                        continue
                    end

                    if metaTable.isClean()
                        metaTable.reloadFromDisk()
                        if isKey(obj.LastNotifiedVersion, filePath)
                            remove(obj.LastNotifiedVersion, filePath);
                        end
                        continue
                    end

                    diskVersion = metaTable.getVersionNumberOnDisk();
                    if isKey(obj.LastNotifiedVersion, filePath) ...
                            && isequal(obj.LastNotifiedVersion(filePath), diskVersion)
                        continue
                    end

                    obj.LastNotifiedVersion(filePath) = diskVersion;
                    evtData = nansen.metadata.event.MetaTableFileChangedEventData(metaTable);
                    obj.notify('FileChangedOnDisk', evtData)

                catch ME
                    if strcmp(ME.identifier, 'NANSEN:VersionedFile:FileNotFound')
                        obj.removeCachedPath(filePath);
                    else
                        warning('NANSEN:MetaTableCache:PollingFailed', ...
                            'Could not poll cached MetaTable "%s": %s', ...
                            filePath, ME.message)
                    end
                end
            end
        end

        function delete(obj)
            if ~isempty(obj.PollingTimer) && isvalid(obj.PollingTimer)
                stop(obj.PollingTimer)
                delete(obj.PollingTimer)
            end

            if ~isempty(obj.ProjectManagerListener) && isvalid(obj.ProjectManagerListener)
                delete(obj.ProjectManagerListener)
            end
        end
    end
end
