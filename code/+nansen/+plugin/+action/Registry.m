classdef Registry < nansen.plugin.base.Registry
%Registry Registry for NANSEN action (session method) plugins.
%
%   Discovers ActionSpec instances from sidecar JSON files and from
%   compatibility introspection of SessionMethod subclasses and
%   function-based session methods.
%
%   Root paths are provided at construction time (typically the cell array
%   returned by project.getObjectMethodFolder). Each path is scanned for:
%     - action.plugin.json sidecar files
%     - *.m / *.mlx files implementing SessionMethod subclasses or functions
%
%   MenuLocation for compatibility-discovered specs is inferred from the
%   package folder hierarchy relative to the nearest root path.
%
%   Usage:
%     rootPaths = currentProject.getObjectMethodFolder('Session');
%     registry  = nansen.plugin.action.Registry(rootPaths);
%     specs     = registry.list();
%     spec      = registry.resolve('nansen.module.ophys...');
%
%   See also: nansen.plugin.base.Registry, nansen.plugin.action.ActionSpec

    properties (Constant, Access = protected)
        PluginType      = nansen.plugin.enum.PluginType.Action
        SidecarFilename = "action.plugin.json"
    end

    properties (Access = private)
        RootPaths_ cell = {}
    end

    % ------------------------------------------------------------------ %
    methods

        function obj = Registry(rootPaths, projectFolder)
        %Registry Construct an action registry from a set of root paths.
        %
        %   obj = Registry(rootPaths) where rootPaths is a cell array of
        %   absolute folder paths (e.g. from project.getObjectMethodFolder).
        %
        %   obj = Registry(rootPaths, projectFolder) additionally scopes the
        %   disabled-plugin state to the given project folder.
            arguments
                rootPaths     = {}
                projectFolder (1,1) string = ""
            end
            obj@nansen.plugin.base.Registry(projectFolder)
            if ischar(rootPaths) || isstring(rootPaths)
                rootPaths = cellstr(rootPaths);
            end
            obj.RootPaths_ = rootPaths;
        end

    end

    % ------------------------------------------------------------------ %
    % Public API extensions
    % ------------------------------------------------------------------ %
    methods

        function specs = listByEntityType(obj, entityType)
        %listByEntityType Return specs matching the given entity type.
            arguments
                obj
                entityType (1,1) string = "session"
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

        function rootPaths = getRootPaths(obj)
        %getRootPaths Return discovery root paths (as provided at construction).
            rootPaths = obj.RootPaths_;
        end

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

        function tf = hasSidecarForSourcePath(obj, mFilePath)
        %hasSidecarForSourcePath True when a sidecar exists alongside the .m file.
            sidecarPath = fullfile(fileparts(mFilePath), obj.SidecarFilename);
            tf = isfile(sidecarPath);
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
                'EntityType',   "session", ...
                'MethodName',   string(displayName), ...
                'BatchMode',    string(nansen.plugin.action.Registry.getAttr_(attributes, 'BatchMode', 'serial')), ...
                'IsQueueable',  logical(nansen.plugin.action.Registry.getAttr_(attributes, 'IsQueueable', true)), ...
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
            tf = nansen.plugin.action.Registry.hasSuperclass_(mc, ...
                'nansen.session.SessionMethod');
        end

        function tf = hasSuperclass_(mc, superclassName)
        %hasSuperclass_ Recursive superclass check (handles deep hierarchies).
            tf = false;
            for i = 1:numel(mc.SuperclassList)
                if strcmp(mc.SuperclassList(i).Name, superclassName) || ...
                        nansen.plugin.action.Registry.hasSuperclass_( ...
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

end
