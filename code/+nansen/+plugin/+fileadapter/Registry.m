classdef Registry < nansen.plugin.base.Registry
%Registry Registry for NANSEN file adapter plugins.
%
%   Discovers FileAdapterSpec instances from sidecar JSON files and from
%   compatibility introspection of nansen.dataio.FileAdapter subclasses.
%
%   Root priority (highest first):
%     1. Project root (constructor argument)
%     2. Module fileadapter folders
%     3. Builtin (code/+nansen/+dataio/+fileadapter)
%
%   Usage:
%     registry = nansen.plugin.fileadapter.Registry();
%     specs    = registry.list();
%     spec     = registry.resolve('nansen.dataio.fileadapter.imagestack.ImageStack');
%
%   See also: nansen.plugin.base.Registry, nansen.plugin.fileadapter.FileAdapterSpec

    properties (Constant, Access = protected)
        PluginType      = nansen.plugin.enum.PluginType.FileAdapter
        SidecarFilename = "fileadapter.plugin.json"
    end

    % ------------------------------------------------------------------ %
    methods (Static)

        function registry = getInstance(projectFolder)
        %getInstance Return a registry for the given project folder.
        %
        %   Uses a persistent instance per project folder as a placeholder
        %   until the project manager lifecycle is wired in (Phase 2+).
            arguments
                projectFolder (1,1) string = ""
            end

            persistent cachedRegistry

            if isempty(cachedRegistry) || ~isvalid(cachedRegistry) ...
                    || cachedRegistry.ProjectFolder ~= projectFolder
                cachedRegistry = nansen.plugin.fileadapter.Registry(projectFolder);
            end

            registry = cachedRegistry;
        end

    end

    % ------------------------------------------------------------------ %
    % Public API extensions
    % ------------------------------------------------------------------ %
    methods

        function spec = findByName(obj, adapterName)
        %findByName Return a spec by stable Id or display name.
        %
        %   Tries resolve(id) first; falls back to findByDisplayName.
        %   Errors if no match is found, warns if multiple matches exist.
            arguments
                obj
                adapterName (1,1) string
            end

            try
                spec = obj.resolve(adapterName);
                return
            catch
                % Not found by Id — try display name
            end

            specs = obj.findByDisplayName(adapterName);
            if isempty(specs)
                error('nansen:plugin:fileadapter:Registry:NotFound', ...
                    'File adapter "%s" was not found.', adapterName)
            elseif numel(specs) > 1
                warning('nansen:plugin:fileadapter:Registry:AmbiguousName', ...
                    'File adapter name "%s" matches %d adapters; using first.', ...
                    adapterName, numel(specs))
            end
            spec = specs(1);
        end

        function entries = listLegacy(obj, fileType)
        %listLegacy Return legacy struct array as produced by listFileAdapters.
        %
        %   entries = registry.listLegacy()
        %   entries = registry.listLegacy(fileExtension)
            arguments
                obj
                fileType (1,1) string = ""
            end

            specs = obj.list();
            entries = arrayfun(@(s) s.toLegacyStruct(), specs);

            if strlength(fileType) > 0
                fileType = strrep(char(fileType), '.', '');
                keep = arrayfun( ...
                    @(e) any(strcmpi(fileType, e.SupportedFileTypes)), entries);
                entries = entries(keep);
            end

            if isempty(entries)
                entries = struct( ...
                    'AdapterId', '', 'DisplayName', '', ...
                    'FileAdapterName', 'N/A', 'FunctionName', '', ...
                    'SupportedFileTypes', {{}}, 'DataType', '', ...
                    'SourcePath', '', 'Implementation', struct());
            end
        end

        function adapter = createAdapter(obj, adapterName, filePath, varargin)
        %createAdapter Instantiate a file adapter by id or display name.
        %
        %   adapter = registry.createAdapter(adapterName, filePath)
        %   adapter = registry.createAdapter(adapterName, filePath, ...)
            arguments
                obj
                adapterName (1,1) string
                filePath    (1,1) string
            end
            arguments (Repeating)
                varargin
            end

            spec = obj.findByName(adapterName);

            if ~isstruct(spec.Implementation) || ~isfield(spec.Implementation, 'kind')
                error('nansen:plugin:fileadapter:Registry:MissingKind', ...
                    'File adapter "%s" has no implementation.kind.', adapterName)
            end

            switch lower(spec.Implementation.kind)
                case {'function', 'function-set'}
                    adapter = nansen.plugin.fileadapter.FunctionFileAdapter( ...
                        filePath, spec, varargin{:});

                case 'builtin'
                    adapter = [];

                otherwise
                    % Class-based adapter
                    if isfield(spec.Implementation, 'class')
                        className = spec.Implementation.class;
                    elseif isfield(spec.Implementation, 'entrypoint')
                        className = spec.Implementation.entrypoint;
                    else
                        error('nansen:plugin:fileadapter:Registry:MissingEntrypoint', ...
                            'File adapter "%s" has no class or entrypoint.', adapterName)
                    end
                    adapterFcn = str2func(className);
                    adapter = adapterFcn(filePath, varargin{:});
            end
        end

    end

    % ------------------------------------------------------------------ %
    % Required abstract implementations
    % ------------------------------------------------------------------ %
    methods (Access = protected)

        function rootPaths = getRootPaths(obj)
        %getRootPaths Return ordered discovery roots (project first, builtin last).
            % Navigate from this file to the code root to avoid nansen.localpath
            thisDir  = fileparts(mfilename('fullpath'));
            % thisDir = .../code/+nansen/+plugin/+fileadapter
            codeRoot = fileparts(fileparts(fileparts(thisDir)));

            builtinRoot = fullfile(codeRoot, '+nansen', '+dataio', '+fileadapter');
            modulesRoot = nansen.common.constant.ModuleRootDirectory();

            rootPaths = {};

            if obj.ProjectFolder ~= ""
                rootPaths{end+1} = char(obj.ProjectFolder);
            end

            if isfolder(modulesRoot)
                rootPaths{end+1} = modulesRoot;
            end

            if isfolder(builtinRoot)
                rootPaths{end+1} = builtinRoot;
            end
        end

        function specs = parseSidecarFile(~, filePath)
        %parseSidecarFile Parse a sidecar file into a FileAdapterSpec array.
            specs = nansen.plugin.fileadapter.FileAdapterSpec.fromJsonFile(filePath);
        end

        function specs = discoverCompatibilitySpecs(obj)
        %discoverCompatibilitySpecs Discover FileAdapter subclasses without sidecars.
        %
        %   Scans root paths for .m files, checks each against the
        %   FileAdapter superclass via metaclass introspection, and builds
        %   a FileAdapterSpec for each class that lacks a sidecar.
            specs = nansen.plugin.fileadapter.FileAdapterSpec.empty;

            rootPaths = obj.getRootPaths();
            for r = 1:numel(rootPaths)
                root = rootPaths{r};
                if ~isfolder(root); continue; end

                mFiles = obj.findMFilesRecursive(root);
                for i = 1:numel(mFiles)
                    filePath = mFiles{i};
                    if obj.hasSidecarForSourcePath(filePath)
                        continue
                    end

                    try
                        className = utility.path.abspath2funcname(filePath);
                        mc = meta.class.fromName(className);
                        if isempty(mc) || ~obj.isFileAdapterClass(mc)
                            continue
                        end

                        spec = obj.specFromMetaClass(mc, filePath);
                        specs(end+1) = spec; %#ok<AGROW>
                    catch ME
                        obj.addIssue('warning', ME.message, filePath);
                    end
                end
            end
        end

        function specs = emptySpecArray(~)
        %emptySpecArray Return an empty typed array for concatenation.
            specs = nansen.plugin.fileadapter.FileAdapterSpec.empty;
        end

    end

    % ------------------------------------------------------------------ %
    % Phase 2 postprocessing — add Default adapter
    % ------------------------------------------------------------------ %
    methods (Access = protected)

        function [specs, issues] = postprocessSpecs(obj, specs)
        %postprocessSpecs Sort, deduplicate, and prepend the Default builtin.
            [specs, issues] = postprocessSpecs@nansen.plugin.base.Registry(obj, specs);

            opts = struct( ...
                'Id',                 "Default", ...
                'DisplayName',        "Default", ...
                'Description',        "MATLAB load/save fallback for MAT files", ...
                'Source',             "builtin", ...
                'Implementation',     struct('language', 'matlab', 'kind', 'builtin', 'entrypoint', 'load'), ...
                'SupportedFileTypes', "mat", ...
                'DataType',           "N/A");

            defaultSpec = nansen.plugin.fileadapter.FileAdapterSpec(opts);
            specs = [defaultSpec, specs];
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

        function spec = specFromMetaClass(~, mc, filePath)
        %specFromMetaClass Build a FileAdapterSpec from a FileAdapter metaclass.
            [~, displayName] = fileparts(filePath);

            supportedTypes = nansen.plugin.fileadapter.Registry.readClassProperty( ...
                mc, 'SUPPORTED_FILE_TYPES');
            dataType = nansen.plugin.fileadapter.Registry.readClassProperty( ...
                mc, 'DataType');

            opts = struct( ...
                'Id',                 string(mc.Name), ...
                'DisplayName',        string(displayName), ...
                'Description',        string(nansen.plugin.fileadapter.Registry.readOptionalClassProperty(mc, 'Description', '')), ...
                'Source',             "class", ...
                'SourcePath',         string(filePath), ...
                'Implementation',     struct('language', 'matlab', 'kind', 'class', 'entrypoint', mc.Name, 'class', mc.Name), ...
                'SupportedFileTypes', string(supportedTypes(:)'), ...
                'DataType',           string(dataType));

            spec = nansen.plugin.fileadapter.FileAdapterSpec(opts);
        end

    end

    methods (Static, Access = private)

        function tf = isFileAdapterClass(mc)
        %isFileAdapterClass True when the metaclass inherits from nansen.dataio.FileAdapter.
            tf = any(strcmp({mc.SuperclassList.Name}, 'nansen.dataio.FileAdapter'));
        end

        function mFiles = findMFilesRecursive(rootPath)
        %findMFilesRecursive Return all .m files under rootPath.
            result = dir(fullfile(rootPath, '**', '*.m'));
            mFiles = arrayfun(@(d) fullfile(d.folder, d.name), result, ...
                'UniformOutput', false);
        end

        function value = readClassProperty(mc, propertyName)
        %readClassProperty Read the DefaultValue of a named class property.
            isProp = strcmp({mc.PropertyList.Name}, propertyName);
            if ~any(isProp)
                error('nansen:plugin:fileadapter:Registry:MissingProperty', ...
                    'Class "%s" does not define property "%s".', ...
                    mc.Name, propertyName)
            end
            value = mc.PropertyList(isProp).DefaultValue;
        end

        function value = readOptionalClassProperty(mc, propertyName, defaultValue)
        %readOptionalClassProperty Read an optional class property with a fallback.
            isProp = strcmp({mc.PropertyList.Name}, propertyName);
            if any(isProp)
                value = mc.PropertyList(isProp).DefaultValue;
            else
                value = defaultValue;
            end
        end

    end

end
