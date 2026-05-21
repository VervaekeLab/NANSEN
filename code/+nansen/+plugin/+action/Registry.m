classdef Registry < nansen.plugin.base.Registry
%Registry Registry for NANSEN action (session/entity method) plugins.
%
%   Discovers ActionSpec instances from sidecar JSON files and from
%   compatibility introspection of SessionMethod subclasses and
%   function-based entity methods.
%
%   Entity types are loaded lazily: paths for a given entity type are only
%   fetched and scanned the first time listByEntityType is called for that
%   type. This avoids scanning all entity folders upfront when only one
%   type is needed.
%
%   Discovery conventions (both handled transparently):
%     - Legacy:   <root>/+sessionmethod/          → EntityType 'session'
%     - Current:  <root>/+objectmethod/+<entity>/ → EntityType '<entity>'
%
%   Usage:
%     % With lazy loading (preferred):
%     pathResolver = @(entityType) project.getObjectMethodFolder(entityType);
%     registry = nansen.plugin.action.Registry(pathResolver, projectFolder);
%     specs    = registry.listByEntityType('session');
%
%     % With explicit paths (testing / backward-compat):
%     registry = nansen.plugin.action.Registry(rootPaths, projectFolder);
%     specs    = registry.list();
%
%   See also: nansen.plugin.base.Registry, nansen.plugin.action.ActionSpec

    properties (Constant, Access = protected)
        PluginType      = nansen.plugin.enum.PluginType.Action
        SidecarFilename = "action.plugin.json"
    end

    properties (Access = private)
        % PathResolver_ - Optional @(entityType)->paths function handle for
        %   lazy per-entity discovery. Empty when paths were injected directly.
        PathResolver_ = []

        % LoadedEntityTypes_ - Entity types whose paths are already in RootPaths_.
        LoadedEntityTypes_ (1,:) string = string.empty
    end

    % ------------------------------------------------------------------ %
    methods

        function obj = Registry(pathResolverOrPaths, projectFolder)
        %Registry Construct an action registry.
        %
        %   Registry(pathResolver, projectFolder)
        %     pathResolver — function handle @(entityType) -> cell of paths.
        %     Paths are fetched lazily on the first listByEntityType call for
        %     each entity type.
        %
        %   Registry(rootPaths, projectFolder)
        %     rootPaths — cell array of absolute folder paths. All paths are
        %     scanned immediately. Use for tests or when all paths are known.
            arguments
                pathResolverOrPaths = []
                projectFolder (1,1) string = ""
            end
            if iscell(pathResolverOrPaths) || ischar(pathResolverOrPaths) ...
                    || isstring(pathResolverOrPaths)
                % Direct path injection — behave like base constructor.
                initPaths       = pathResolverOrPaths;
                pathResolverArg = [];
            else
                % Function handle — start with no paths; load lazily.
                initPaths       = {};
                pathResolverArg = pathResolverOrPaths;
            end
            obj@nansen.plugin.base.Registry(initPaths, projectFolder);
            obj.PathResolver_ = pathResolverArg;
        end

    end

    % ------------------------------------------------------------------ %
    methods (Static)

        function registry = getInstance(projectFolder)
        %getInstance Return a registry scoped to the given project folder.
        %
        %   This form has no path resolver — it returns an empty registry
        %   suitable for API access (validate, diagnose) without project context.
        %   For a populated registry, construct directly:
        %     registry = nansen.plugin.action.Registry(pathResolver, projectFolder)
            arguments
                projectFolder (1,1) string = ""
            end
            persistent cachedRegistry
            if isempty(cachedRegistry) || ~isvalid(cachedRegistry) ...
                    || cachedRegistry.ProjectFolder ~= projectFolder
                cachedRegistry = nansen.plugin.action.Registry({}, projectFolder);
            end
            registry = cachedRegistry;
        end

    end

    % ------------------------------------------------------------------ %
    % Public API extensions
    % ------------------------------------------------------------------ %
    methods

        function specs = listByEntityType(obj, entityType)
        %listByEntityType Return specs for the given entity type.
        %
        %   When the registry was constructed with a path resolver, paths for
        %   this entity type are fetched and scanned on the first call.
        %   Subsequent calls for the same type use the cached spec list.
            arguments
                obj
                entityType (1,1) string = "session"
            end
            if ~isempty(obj.PathResolver_) ...
                    && ~any(strcmp(obj.LoadedEntityTypes_, entityType))
                obj.loadEntityType_(entityType);
            end
            all = obj.list();
            if isempty(all)
                specs = nansen.plugin.action.ActionSpec.empty;
                return
            end
            keep = arrayfun(@(s) strcmpi(char(s.EntityType), char(entityType)), all);
            specs = all(keep);
        end

        function S = getTaskAttributes(obj, actionId)
        %getTaskAttributes Return a SessionTaskMenu-compatible attribute struct.
            arguments
                obj
                actionId (1,1) string
            end
            spec = obj.resolve(actionId);
            S = spec.toTaskAttributes();
        end

    end

    % ------------------------------------------------------------------ %
    % Required abstract implementations
    % ------------------------------------------------------------------ %
    methods (Access = protected)

        function specs = parseSidecarFile(~, filePath)
        %parseSidecarFile Parse an action sidecar file into an ActionSpec array.
            specs = nansen.plugin.action.ActionSpec.fromJsonFile(filePath);
        end

        function specs = discoverCompatibilitySpecs(obj)
        %discoverCompatibilitySpecs Discover session methods without sidecars.
        %
        %   Scans root paths for .m files, checks each against the
        %   SessionMethod hierarchy via metaclass introspection, and builds
        %   an ActionSpec for each method that lacks a sidecar.
            specs = nansen.plugin.action.ActionSpec.empty;
            rootPaths = obj.getRootPaths();

            mFiles = nansen.plugin.action.Registry.listMatlabFiles(rootPaths);

            for i = 1:numel(mFiles)
                filePath = mFiles{i};
                if obj.hasSidecarForSourcePath(filePath)
                    continue
                end

                try
                    spec = obj.createSpecFromMFile_(filePath, rootPaths);
                    if ~isempty(spec)
                        specs(end+1) = spec; %#ok<AGROW>
                    end
                catch ME
                    obj.addIssue('warning', ME.message, filePath);
                end
            end
        end

        function specs = emptySpecArray(~)
        %emptySpecArray Return an empty typed array for concatenation.
            specs = nansen.plugin.action.ActionSpec.empty;
        end

    end

    % ------------------------------------------------------------------ %
    % Private helpers
    % ------------------------------------------------------------------ %
    methods (Access = private)

        function loadEntityType_(obj, entityType)
        %loadEntityType_ Fetch paths for entityType and append to RootPaths_.
        %
        %   Calls PathResolver_ to get the discovery roots, appends them to
        %   RootPaths_, marks the entity type as loaded, and invalidates the
        %   spec cache so the next list() call triggers a full re-scan.
            newPaths = obj.PathResolver_(char(entityType));
            if ischar(newPaths) || isstring(newPaths)
                newPaths = cellstr(newPaths);
            end
            if ~iscell(newPaths)
                newPaths = {};
            end
            obj.RootPaths_         = [obj.RootPaths_, newPaths(:)'];
            obj.LoadedEntityTypes_(end+1) = entityType;
            obj.IsLoaded           = false;   % force re-scan on next list()
        end

        function spec = createSpecFromMFile_(~, filePath, rootPaths)
        %createSpecFromMFile_ Infer an ActionSpec from a session method file.
            functionName = utility.path.abspath2funcname(filePath);
            mc = meta.class.fromName(functionName);

            if ~isempty(mc)
                if ~nansen.plugin.action.Registry.isSessionMethodClass_(mc)
                    spec = nansen.plugin.action.ActionSpec.empty;
                    return
                end
                attributes = nansen.plugin.action.Registry.readClassAttributes_(mc);
                kind = 'class';
                source = 'class';
            else
                functionHandle = str2func(functionName);
                try
                    attributes = functionHandle();
                catch
                    % Function requires runtime context (e.g. a loaded project)
                    % to return attributes — use an empty struct so the spec is
                    % still discoverable with sensible defaults.
                    attributes = struct();
                end
                if ~isstruct(attributes)
                    spec = nansen.plugin.action.ActionSpec.empty;
                    return
                end
                kind = 'function';
                source = 'function';
            end

            [~, fileName] = fileparts(filePath);

            if isfield(attributes, 'MethodName') && ~isempty(attributes.MethodName)
                displayName = attributes.MethodName;
            else
                displayName = utility.string.varname2label(fileName);
            end

            menuLoc = nansen.plugin.action.Registry.getMenuLocation_(filePath, rootPaths);

            opts = struct( ...
                'Id',           string(functionName), ...
                'DisplayName',  string(displayName), ...
                'Source',       string(source), ...
                'SourcePath',   string(filePath), ...
                'Implementation', struct('language', 'matlab', 'kind', kind, 'entrypoint', functionName), ...
                'EntityType',   string(nansen.plugin.action.Registry.inferEntityType_(filePath)), ...
                'MethodName',   string(displayName), ...
                'BatchMode',    string(nansen.plugin.base.Registry.getAttr_(attributes, 'BatchMode', 'serial')), ...
                'IsQueueable',  logical(nansen.plugin.base.Registry.getAttr_(attributes, 'IsQueueable', true)), ...
                'MenuLocation', menuLoc);

            if isfield(attributes, 'Alternatives') && ~isempty(attributes.Alternatives)
                opts.Alternatives = string(attributes.Alternatives(:)');
            end

            if isfield(attributes, 'Description') && ~isempty(attributes.Description)
                opts.Description = string(attributes.Description);
            end

            spec = nansen.plugin.action.ActionSpec(opts);
        end

    end

    % ------------------------------------------------------------------ %
    methods (Static, Access = private)

        function files = listMatlabFiles(rootPaths)
        %listMatlabFiles Return MATLAB source files under root paths.
        %   Skips +template and +abstract package folders.
            files = {};
            if ~iscell(rootPaths); rootPaths = {rootPaths}; end
            for i = 1:numel(rootPaths)
                if ~isfolder(rootPaths{i}); continue; end
                L = [dir(fullfile(rootPaths{i}, '**', '*.m')); ...
                     dir(fullfile(rootPaths{i}, '**', '*.mlx'))];
                if isempty(L); continue; end
                newFiles = fullfile({L.folder}, {L.name});
                skip = contains(newFiles, [filesep, '+template', filesep]) | ...
                       contains(newFiles, [filesep, '+abstract', filesep]);
                files = [files, newFiles(~skip)]; %#ok<AGROW>
            end
        end

        function menuLocation = getMenuLocation_(filePath, rootPaths)
        %getMenuLocation_ Derive menu location from folder hierarchy.
        %
        %   Returns a string array of path segments relative to the nearest
        %   root path, with package '+' prefixes stripped.
            [folderPath, ~] = fileparts(filePath);
            if ~iscell(rootPaths); rootPaths = {rootPaths}; end

            rootPath = '';
            for i = 1:numel(rootPaths)
                if startsWith(folderPath, rootPaths{i})
                    rootPath = rootPaths{i};
                    break
                end
            end

            if isempty(rootPath)
                menuLocation = string.empty;
                return
            end

            relativePath = erase(folderPath, rootPath);
            % Strip leading separator
            relativePath = regexprep(relativePath, ['^', regexptranslate('escape', filesep)], '');
            if isempty(relativePath)
                menuLocation = string.empty;
                return
            end
            % Convert path separators to dots, strip '+' package markers
            packageName  = strrep(relativePath, filesep, '.');
            parts        = strsplit(strrep(packageName, '+', ''), '.');
            parts        = parts(~cellfun(@isempty, parts));
            menuLocation = string(parts);
        end

        function attributes = readClassAttributes_(mc)
        %readClassAttributes_ Read known SessionMethod property default values.
            attributes = struct();
            propertyNames = {'MethodName', 'BatchMode', 'IsManual', ...
                'IsQueueable', 'OptionsManager', 'Alternatives', 'Description'};
            classPropertyNames = {mc.PropertyList.Name};
            for i = 1:numel(propertyNames)
                isMatch = strcmp(classPropertyNames, propertyNames{i});
                if any(isMatch)
                    attributes.(propertyNames{i}) = mc.PropertyList(isMatch).DefaultValue;
                end
            end
            if ~isfield(attributes, 'MethodName') || isempty(attributes.MethodName)
                parts = strsplit(mc.Name, '.');
                attributes.MethodName = utility.string.varname2label(parts{end});
            end
            if ~isfield(attributes, 'BatchMode')
                attributes.BatchMode = 'serial';
            end
            if ~isfield(attributes, 'IsQueueable')
                attributes.IsQueueable = true;
            end
        end

        function tf = isSessionMethodClass_(mc)
        %isSessionMethodClass_ True when the metaclass inherits from SessionMethod.
            tf = nansen.plugin.base.Registry.hasSuperclass_(mc, ...
                'nansen.session.SessionMethod');
        end

        function entityType = inferEntityType_(filePath)
        %inferEntityType_ Infer the entity type from a method file's path.
        %
        %   Handles both naming conventions:
        %     +sessionmethod/          → 'session'  (legacy)
        %     +objectmethod/+session/  → 'session'  (current)
        %     +objectmethod/+subject/  → 'subject'
        %
        %   Defaults to 'session' when neither pattern matches (e.g. flat
        %   method files placed directly in a root path).
            sep = regexptranslate('escape', filesep);

            % Legacy convention: <root>/+sessionmethod/
            if ~isempty(regexp(filePath, [sep, '\+sessionmethod', sep], 'once')) || ...
               ~isempty(regexp(filePath, [sep, '\+sessionmethod$'], 'once'))
                entityType = 'session';
                return
            end

            % Current convention: <root>/+objectmethod/+<entity>/
            tok = regexp(filePath, [sep, '\+objectmethod', sep, '\+(\w+)'], ...
                'tokens', 'once');
            if ~isempty(tok)
                entityType = tok{1};
                return
            end

            entityType = 'session';  % safe default
        end

    end

end
