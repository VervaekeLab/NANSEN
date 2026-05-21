classdef (Abstract) Registry < handle
%Registry Abstract base class for per-project plugin registries.
%
%   Each plugin type provides a concrete subclass that defines its root
%   paths, spec class, and compatibility importer. The base class manages
%   the full discovery lifecycle: sidecar scanning, mtime caching,
%   deduplication, priority sorting, schema validation, disabled-state
%   persistence, and change events.
%
%   Constructor:
%     obj = Registry(projectFolder)
%
%   Subclasses must implement the abstract methods listed below and must
%   define the abstract constants PluginType and SidecarFilename.

    events
        PluginAdded
        PluginRemoved
        PluginRegistryRefreshed
    end

    properties (Abstract, Constant, Access = protected)
        % PluginType - Plugin type enum value for this registry.
        PluginType (1,1) nansen.plugin.enum.PluginType

        % SidecarFilename - Filename of the JSON sidecar (e.g. 'fileadapter.plugin.json').
        SidecarFilename (1,1) string
    end

    properties (SetAccess = private)
        % ProjectFolder - Root folder of the owning project (or "" for global).
        ProjectFolder (1,1) string = ""
    end

    properties (Access = protected)
        % RootPaths_ - Ordered discovery roots (project first, builtin last).
        RootPaths_ (1,:) cell = {}
    end

    properties (SetAccess = protected)
        % Specs - Discovered plugin specs (typed array set by concrete subclass).
        Specs

        % Issues - Schema and discovery issues from the last refresh.
        Issues struct

        % IsLoaded - True once refresh has been called at least once.
        IsLoaded (1,1) logical = false
    end

    properties (Access = protected)
        % MtimeCache - Maps sidecar file path → datenum at last parse.
        MtimeCache containers.Map

        % SpecCache - Maps sidecar file path → parsed spec array.
        SpecCache containers.Map
    end

    methods
        function obj = Registry(rootPaths, projectFolder)
        %Registry Construct a registry with ordered discovery roots.
        %
        %   obj = Registry(rootPaths, projectFolder)
        %
        %   rootPaths     - Cell array of absolute folder paths, ordered
        %                   highest-priority first (project, modules, builtin).
        %   projectFolder - Root folder of the owning project (or "" for
        %                   global). Scopes the disabled-plugin state file.
            arguments
                rootPaths     = {}
                projectFolder (1,1) string = ""
            end
            if ischar(rootPaths) || isstring(rootPaths)
                rootPaths = cellstr(rootPaths);
            end
            obj.ProjectFolder = projectFolder;
            obj.RootPaths_    = rootPaths;
            obj.Specs  = [];
            obj.Issues = obj.emptyIssues();
            obj.MtimeCache = containers.Map('KeyType', 'char', 'ValueType', 'double');
            obj.SpecCache  = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end
    end

    % Public API

    methods

        function specs = list(obj, options)
        %list Return discovered plugin specs, refreshing on first use.
        %
        %   specs = obj.list() returns enabled specs only.
        %   specs = obj.list('IncludeDisabled', true) includes disabled specs.
            arguments
                obj
                options.IncludeDisabled (1,1) logical = false
            end

            if ~obj.IsLoaded
                obj.refresh()
            end

            specs = obj.Specs;

            if ~options.IncludeDisabled
                specs = obj.removeDisabledSpecs(specs);
            end
        end

        function spec = get(obj, id)
        %get Return the spec for a stable plugin Id (alias for resolve).
            spec = obj.resolve(id);
        end

        function spec = resolve(obj, id)
        %resolve Return the spec for a stable plugin Id.
        %
        %   Matches by Id only. For human-facing name lookups use findByDisplayName.
        %   Errors if the id is not found.
            arguments
                obj
                id (1,1) string
            end

            specs = obj.list('IncludeDisabled', true);

            if isempty(specs)
                error('nansen:plugin:Registry:PluginNotFound', ...
                    'No plugin with Id "%s" was found.', id)
            end

            isMatch = strcmp([specs.Id], id);

            if ~any(isMatch)
                error('nansen:plugin:Registry:PluginNotFound', ...
                    'No plugin with Id "%s" was found.', id)
            end

            spec = specs(find(isMatch, 1, 'first'));
        end

        function specs = findByDisplayName(obj, name)
        %findByDisplayName Return specs whose DisplayName matches name.
        %
        %   Unlike resolve, this is a human-facing lookup that may return
        %   multiple results if names collide. Display-name collisions do not
        %   shadow — all matches are returned.
            arguments
                obj
                name (1,1) string
            end

            specs = obj.list();

            if isempty(specs)
                specs = obj.emptySpecArray();
                return
            end

            isMatch = strcmp([specs.DisplayName], name);
            specs = specs(isMatch);
        end

        function enable(obj, id)
        %enable Re-enable a previously disabled plugin.
            arguments
                obj
                id (1,1) string
            end

            ids = obj.readDisabledIds();
            ids = ids(~strcmp(ids, id));
            obj.writeDisabledIds(ids);
        end

        function disable(obj, id)
        %disable Prevent a plugin from appearing in list results.
        %
        %   The plugin remains discoverable via list('IncludeDisabled', true).
            arguments
                obj
                id (1,1) string
            end

            specs = obj.list('IncludeDisabled', true);

            if ~isempty(specs) && ~any(strcmp([specs.Id], id))
                error('nansen:plugin:Registry:PluginNotFound', ...
                    'No plugin with Id "%s" was found.', id)
            end

            ids = obj.readDisabledIds();
            if ~any(strcmp(ids, id))
                ids{end+1} = id;
                obj.writeDisabledIds(ids);
            end
        end

        function tf = isEnabled(obj, id)
        %isEnabled Return true if the plugin id is not in the disabled list.
            arguments
                obj
                id (1,1) string
            end

            tf = ~any(strcmp(obj.readDisabledIds(), id));
        end

        function refresh(obj)
        %refresh Rebuild the spec list from all configured roots.
        %
        %   Sidecars whose mtime is unchanged are not re-parsed. Schema
        %   validation runs on all loaded specs. Events fire for added and
        %   removed plugins, and always for PluginRegistryRefreshed.
            prevIds = string({});
            if obj.IsLoaded && ~isempty(obj.Specs)
                prevIds = [obj.Specs.Id];
            end

            obj.Issues = obj.emptyIssues();

            sidecarSpecs = obj.discoverSidecarSpecs();
            compatSpecs  = obj.discoverCompatibilitySpecs();
            compatSpecs  = obj.removeSpecsWithSidecar(compatSpecs);

            allSpecs = [sidecarSpecs, compatSpecs];
            [allSpecs, newIssues] = obj.postprocessSpecs(allSpecs);

            obj.Specs    = allSpecs;
            obj.Issues   = [obj.Issues, newIssues];
            obj.IsLoaded = true;

            newIds = string({});
            if ~isempty(obj.Specs)
                newIds = [obj.Specs.Id];
            end

            addedIds   = setdiff(newIds, prevIds);
            removedIds = setdiff(prevIds, newIds);

            for i = 1:numel(addedIds)
                notify(obj, 'PluginAdded')
            end
            for i = 1:numel(removedIds)
                notify(obj, 'PluginRemoved')
            end
            notify(obj, 'PluginRegistryRefreshed')
        end

        function clear(obj)
        %clear Reset the registry so the next list call triggers a full refresh.
        %
        %   Also clears the spec and mtime caches, forcing JSON re-parsing.
            obj.Specs      = [];
            obj.Issues     = obj.emptyIssues();
            obj.IsLoaded   = false;
            obj.MtimeCache = containers.Map('KeyType', 'char', 'ValueType', 'double');
            obj.SpecCache  = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        function issues = validate(obj)
        %validate Return schema and discovery issues from the last refresh.
            if ~obj.IsLoaded
                obj.refresh()
            end
            issues = obj.Issues;
        end
    end

    % Abstract methods — subclasses must implement

    methods (Abstract, Access = protected)
        % parseSidecarFile Decode a sidecar file into a typed spec array.
        %
        %   This method is called by loadSidecarFile when a file needs to be
        %   (re-)parsed. Concrete registries call their own spec class's
        %   fromJsonFile to return the correctly typed array.
        specs = parseSidecarFile(obj, filePath)

        % discoverCompatibilitySpecs Return specs for plugins without sidecars.
        specs = discoverCompatibilitySpecs(obj)
    end

    % Protected discovery helpers

    methods (Access = protected)

        function rootPaths = getRootPaths(obj)
        %getRootPaths Return ordered discovery roots (highest-priority first).
        %
        %   Default implementation returns the RootPaths_ stored at
        %   construction. Subclasses may override for dynamic path resolution.
            rootPaths = obj.RootPaths_;
        end

        function tf = hasSidecarForSourcePath(obj, mFilePath)
        %hasSidecarForSourcePath True when a sidecar exists alongside the .m file.
            sidecarPath = fullfile(fileparts(mFilePath), obj.SidecarFilename);
            tf = isfile(sidecarPath);
        end

        function specs = discoverSidecarSpecs(obj)
        %discoverSidecarSpecs Scan root paths for sidecar files and load specs.
        %
        %   Uses an mtime cache to skip re-parsing unchanged sidecars. Parse
        %   errors are captured as Issues rather than propagated.
            specs = [];
            roots = obj.getRootPaths();

            if ischar(roots) || isstring(roots)
                roots = {char(roots)};
            end

            for i = 1:numel(roots)
                root = roots{i};
                if isempty(root) || ~isfolder(root)
                    continue
                end

                sidecarFiles = obj.findSidecarFiles(root);

                for j = 1:numel(sidecarFiles)
                    filePath = sidecarFiles{j};
                    try
                        newSpecs = obj.loadSidecarFile(filePath);
                        specs    = [specs, newSpecs]; %#ok<AGROW>
                    catch ME
                        obj.addIssue('error', ME.message, filePath)
                    end
                end
            end
        end

        function specs = loadSidecarFile(obj, filePath)
        %loadSidecarFile Load a sidecar, reusing the spec cache if mtime is unchanged.
            mtime = obj.getFileMtime(filePath);

            if obj.MtimeCache.isKey(filePath) ...
                    && obj.MtimeCache(filePath) == mtime ...
                    && obj.SpecCache.isKey(filePath)
                specs = obj.SpecCache(filePath);
                return
            end

            specs = obj.parseSidecarFile(filePath);
            obj.MtimeCache(filePath) = mtime;
            obj.SpecCache(filePath)  = specs;
        end

        function files = findSidecarFiles(obj, rootPath)
        %findSidecarFiles Recursively find all sidecars under rootPath.
            result = dir(fullfile(rootPath, '**', obj.SidecarFilename));
            files  = arrayfun(@(d) fullfile(d.folder, d.name), result, ...
                'UniformOutput', false);
        end

        function [specs, issues] = postprocessSpecs(obj, specs)
        %postprocessSpecs Sort by precedence, deduplicate, and validate.
            issues = obj.emptyIssues();

            if isempty(specs)
                return
            end

            specs = obj.sortSpecsByPriority(specs);
            [specs, dupIssues] = obj.deduplicateSpecs(specs);
            issues = [issues, dupIssues];
        end

        function specs = sortSpecsByPriority(obj, specs)
        %sortSpecsByPriority Order specs: project > integration > builtin.
            if isempty(specs)
                return
            end
            priorities = arrayfun(@(s) obj.getSpecPriority(s), specs);
            [~, idx]   = sort(priorities);
            specs      = specs(idx);
        end

        function priority = getSpecPriority(obj, spec)
        %getSpecPriority Compute sort key. Lower value = higher precedence.
            rootPriority = obj.getSpecRootPriority(spec);
            switch lower(char(spec.Source))
                case 'project';             srcPriority = 10;
                case 'sidecar';             srcPriority = 20;
                case {'class','function'};  srcPriority = 30;
                case 'builtin';             srcPriority = 40;
                otherwise;                  srcPriority = 50;
            end
            priority = rootPriority * 100 + srcPriority;
        end

        function priority = getSpecRootPriority(obj, spec)
        %getSpecRootPriority Priority based on which root path hosts the spec.
            roots    = obj.getRootPaths();
            if ischar(roots) || isstring(roots)
                roots = {char(roots)};
            end
            priority = numel(roots) + 1;
            for i = 1:numel(roots)
                root = roots{i};
                if ~isempty(root) && startsWith(spec.SourcePath, root)
                    priority = i;
                    return
                end
            end
        end

        function [specs, issues] = deduplicateSpecs(~, specs)
        %deduplicateSpecs Keep the highest-priority instance per Id.
        %
        %   Duplicate ids produce a structured error issue. Two plugins with
        %   the same id never silently shadow — the conflict is surfaced.
            issues = struct('Severity', {}, 'Message', {}, 'SourcePath', {});

            if isempty(specs)
                return
            end

            ids = string({specs.Id});
            [~, firstIdx] = unique(ids, 'stable');
            dupMask = true(1, numel(specs));
            dupMask(firstIdx) = false;

            for i = find(dupMask)
                issues(end+1) = struct( ...           %#ok<AGROW>
                    'Severity', 'error', ...
                    'Message',  sprintf( ...
                        'Duplicate plugin Id "%s" — keeping first occurrence, ignoring "%s".', ...
                        specs(i).Id, specs(i).SourcePath), ...
                    'SourcePath', specs(i).SourcePath);
            end

            specs = specs(firstIdx);
        end

        function specs = removeDisabledSpecs(obj, specs)
        %removeDisabledSpecs Filter out specs whose Id is in the disabled list.
            if isempty(specs)
                return
            end
            disabledIds = obj.readDisabledIds();
            if isempty(disabledIds)
                return
            end
            keep  = ~ismember(string({specs.Id}), string(disabledIds));
            specs = specs(keep);
        end

        function specs = removeSpecsWithSidecar(obj, specs)
        %removeSpecsWithSidecar Prefer sidecar discovery over compat introspection.
            if isempty(specs)
                return
            end
            keep = true(1, numel(specs));
            for i = 1:numel(specs)
                sidecarPath = fullfile(fileparts(specs(i).SourcePath), obj.SidecarFilename);
                keep(i) = ~isfile(sidecarPath);
            end
            specs = specs(keep);
        end

        function addIssue(obj, severity, message, sourcePath)
        %addIssue Append a structured validation or discovery issue.
            obj.Issues(end+1) = struct( ...
                'Severity',   severity, ...
                'Message',    message, ...
                'SourcePath', sourcePath);
        end

        function specs = emptySpecArray(~)
        %emptySpecArray Return an empty array compatible with MATLAB array concatenation.
            specs = [];
        end

        function mtime = getFileMtime(~, filePath)
        %getFileMtime Return the modification time of a file as datenum.
            d = dir(filePath);
            if isempty(d)
                mtime = 0;
            else
                mtime = d.datenum;
            end
        end
    end

    % Disabled-state persistence (project-scoped JSON file)

    methods (Access = protected)

        function ids = readDisabledIds(obj)
        %readDisabledIds Load the disabled-id list from the project preference file.
            prefsFile = obj.disabledPrefsFile();

            if ~isfile(prefsFile)
                ids = {};
                return
            end

            try
                raw = jsondecode(fileread(prefsFile));
                if ischar(raw) || isstring(raw)
                    ids = cellstr(raw);
                elseif iscell(raw)
                    ids = raw;
                else
                    ids = {};
                end
            catch
                ids = {};
            end
        end

        function writeDisabledIds(obj, ids)
        %writeDisabledIds Persist the disabled-id list to the project preference file.
            prefsFile = obj.disabledPrefsFile();
            prefsDir  = fileparts(prefsFile);

            if ~isfolder(prefsDir)
                mkdir(prefsDir)
            end

            fid     = fopen(prefsFile, 'w', 'n', 'UTF-8');
            cleanup = onCleanup(@() fclose(fid));
            fprintf(fid, '%s', jsonencode(ids, 'PrettyPrint', true));
        end

        function filePath = disabledPrefsFile(obj)
        %disabledPrefsFile Path to the JSON file storing disabled plugin ids.
            typeName = char(obj.PluginType);

            if obj.ProjectFolder == ""
                prefsRoot = fullfile(tempdir(), 'nansen_plugin_prefs');
            else
                prefsRoot = fullfile(obj.ProjectFolder, 'configurations', 'plugin_registry');
            end

            filePath = fullfile(prefsRoot, [typeName '_disabled.json']);
        end
    end

    % Protected static helpers — available to all concrete registries

    methods (Static, Access = protected)

        function tf = hasSuperclass_(mc, superclassName)
        %hasSuperclass_ Recursive superclass check (handles deep hierarchies).
            tf = false;
            for i = 1:numel(mc.SuperclassList)
                if strcmp(mc.SuperclassList(i).Name, superclassName) || ...
                        nansen.plugin.base.Registry.hasSuperclass_( ...
                        mc.SuperclassList(i), superclassName)
                    tf = true;
                    return
                end
            end
        end

        function value = getAttr_(S, fieldName, defaultValue)
        %getAttr_ Safe struct field read with a default.
            if isfield(S, fieldName) && ~isempty(S.(fieldName))
                value = S.(fieldName);
            else
                value = defaultValue;
            end
        end
    end

    % Private static helpers

    methods (Static, Access = private)

        function issues = emptyIssues()
            issues = struct('Severity', {}, 'Message', {}, 'SourcePath', {});
        end
    end
end
