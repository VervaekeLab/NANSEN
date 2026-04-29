classdef Registry < nansen.plugin.base.Registry
%Registry Registry for NANSEN file adapter plugins.

    properties (Constant, Access = protected)
        PluginType = 'fileadapter'
        SidecarFilename = 'fileadapter.plugin.json'
    end

    properties (Access = private)
        AdditionalRootPaths cell = {}
    end

    methods (Static)

        function registry = getInstance(forceRefresh)
        %getInstance Return current file adapter registry instance.
            persistent registryInstance

            if nargin < 1
                forceRefresh = false;
            end

            if isempty(registryInstance) || ~isvalid(registryInstance)
                registryInstance = nansen.plugin.fileadapter.Registry();
            end

            if forceRefresh
                registryInstance.refresh()
            end

            registry = registryInstance;
        end

    end

    methods

        function addRootPath(obj, rootPath)
        %addRootPath Add a root path for adapter discovery.
            obj.AdditionalRootPaths{end+1} = rootPath;
            obj.clear()
        end

        function entries = listLegacy(obj)
        %listLegacy Return legacy nansen.dataio.listFileAdapters structs.
            specs = obj.list();

            entries = struct( ...
                'AdapterId', {}, ...
                'DisplayName', {}, ...
                'FileAdapterName', {}, ...
                'FunctionName', {}, ...
                'SupportedFileTypes', {}, ...
                'DataType', {}, ...
                'SourcePath', {}, ...
                'Implementation', {});

            for i = 1:numel(specs)
                fileAdapterSpec = nansen.plugin.fileadapter.FileAdapterSpec.fromPluginSpec(specs(i));
                entries(end+1) = fileAdapterSpec.toLegacyStruct(); %#ok<AGROW>
            end
        end

        function entries = findByFileType(obj, fileType)
        %findByFileType Return legacy entries supporting a file extension.
            if strncmp(fileType, '.', 1)
                fileType = fileType(2:end);
            end
            fileType = lower(fileType);

            entries = obj.listLegacy();
            if isempty(entries)
                return
            end

            keep = arrayfun( ...
                @(s) any(strcmpi(fileType, s.SupportedFileTypes)), entries);
            entries = entries(keep);
        end

        function entry = findByName(obj, adapterName)
        %findByName Return one legacy entry by id, display name or function.
            entries = obj.listLegacy();
            isMatch = strcmp({entries.FileAdapterName}, adapterName) | ...
                strcmp({entries.AdapterId}, adapterName) | ...
                strcmp({entries.FunctionName}, adapterName);

            if ~any(isMatch)
                error('Nansen:FileAdapterRegistry:AdapterNotFound', ...
                    'File adapter "%s" was not found.', adapterName)
            elseif sum(isMatch) > 1
                error('Nansen:FileAdapterRegistry:AmbiguousAdapterName', ...
                    ['File adapter name "%s" matches multiple adapters. ', ...
                    'Use a stable adapter id instead.'], adapterName)
            end

            entry = entries(isMatch);
        end

        function adapter = createAdapter(obj, adapterName, filePath, varargin)
        %createAdapter Create adapter instance for a named adapter.
            spec = obj.get(adapterName);
            fileAdapterSpec = nansen.plugin.fileadapter.FileAdapterSpec.fromPluginSpec(spec);

            implementationKind = nansen.plugin.base.PluginSpec.getField( ...
                fileAdapterSpec.Implementation, {'kind'}, '');

            switch lower(implementationKind)
                case 'function'
                    adapter = nansen.plugin.fileadapter.FunctionFileAdapter( ...
                        filePath, fileAdapterSpec, varargin{:});
                case 'function-set'
                    adapter = nansen.plugin.fileadapter.FunctionFileAdapter( ...
                        filePath, fileAdapterSpec, varargin{:});
                case 'builtin'
                    adapter = [];
                otherwise
                    className = nansen.plugin.base.PluginSpec.getField( ...
                        fileAdapterSpec.Implementation, {'class', 'entrypoint'}, '');
                    adapterFcn = str2func(className);
                    adapter = adapterFcn(filePath, varargin{:});
            end
        end

    end

    methods (Access = protected)

        function rootPaths = getRootPaths(obj)
        %getRootPaths Return roots where file adapters are defined.
            rootPaths = [obj.AdditionalRootPaths, { ...
                fullfile(nansen.localpath('integrations'), 'fileadapters'), ...
                nansen.localpath('builtin_file_adapter') ...
                }];
        end

        function specs = discoverCompatibilitySpecs(obj)
        %discoverCompatibilitySpecs Import existing FileAdapter subclasses.
            specs = obj.emptySpecArray();
            rootPaths = obj.getRootPaths();

            fileAdapterFolders = utility.path.listSubDir(rootPaths, '', {}, inf);
            fileAdapterFolders = [reshape(rootPaths, 1, []), fileAdapterFolders];
            fileAdapterMfiles = utility.path.listFiles(fileAdapterFolders, '.m');

            for i = 1:numel(fileAdapterMfiles)
                try
                    className = utility.path.abspath2funcname(fileAdapterMfiles{i});
                    mc = meta.class.fromName(className);

                    if isempty(mc) || ~nansen.plugin.fileadapter.Registry.isFileAdapterClass(mc)
                        continue
                    end

                    [~, displayName] = fileparts(fileAdapterMfiles{i});
                    supportedTypes = nansen.plugin.fileadapter.Registry.getConstantPropertyValue( ...
                        mc, 'SUPPORTED_FILE_TYPES');
                    dataType = nansen.plugin.fileadapter.Registry.getConstantPropertyValue( ...
                        mc, 'DataType');

                    spec = nansen.plugin.fileadapter.FileAdapterSpec();
                    spec.Id = className;
                    spec.DisplayName = displayName;
                    spec.Description = nansen.plugin.fileadapter.Registry.getOptionalConstantPropertyValue( ...
                        mc, 'Description', '');
                    spec.Source = 'class';
                    spec.SourcePath = fileAdapterMfiles{i};
                    spec.Implementation = struct('language', 'matlab', ...
                        'kind', 'class', 'entrypoint', className, 'class', className);
                    spec.TypeData = struct( ...
                        'SupportedFileTypes', {supportedTypes}, ...
                        'DataType', dataType);

                    specs(end+1) = spec; %#ok<AGROW>
                catch ME
                    obj.addIssue('error', ME.message, fileAdapterMfiles{i});
                end
            end

            % Sidecar-backed adapters are preferred during resolution, but
            % class adapters remain listed for compatibility until in-tree
            % adapters have explicit sidecars.
        end

        function spec = readSidecarSpec(~, filePath)
        %readSidecarSpec Read sidecar and convert to FileAdapterSpec.
            baseSpec = nansen.plugin.base.PluginSpec.fromJsonFile(filePath);
            spec = nansen.plugin.fileadapter.FileAdapterSpec.fromPluginSpec(baseSpec);

            if isempty(spec.Id)
                [~, folderName] = fileparts(fileparts(filePath));
                spec.Id = folderName;
            end
            if isempty(spec.DisplayName)
                [~, folderName] = fileparts(fileparts(filePath));
                spec.DisplayName = folderName;
            end
            if isempty(spec.Source)
                spec.Source = 'sidecar';
            end
        end

        function spec = normalizeSpec(obj, spec)
        %normalizeSpec Fill file-adapter defaults.
            spec = normalizeSpec@nansen.plugin.base.Registry(obj, spec);
            spec.PluginType = obj.PluginType;

            if isempty(spec.DisplayName)
                spec.DisplayName = spec.Id;
            end
        end

        function [specs, issues] = postprocessSpecs(obj, specs)
        %postprocessSpecs Add Default adapter after base validation.
            [specs, issues] = postprocessSpecs@nansen.plugin.base.Registry(obj, specs);

            defaultSpec = nansen.plugin.fileadapter.FileAdapterSpec();
            defaultSpec.Id = 'Default';
            defaultSpec.DisplayName = 'Default';
            defaultSpec.Description = 'MATLAB load/save fallback for MAT files';
            defaultSpec.Source = 'builtin';
            defaultSpec.Implementation = struct('language', 'matlab', ...
                'kind', 'builtin', 'entrypoint', 'load');
            defaultSpec.TypeData = struct('SupportedFileTypes', {{'mat'}}, ...
                'DataType', 'N/A');
            specs = [defaultSpec, specs];
        end

        function specs = emptySpecArray(~)
        %emptySpecArray Return an empty file-adapter spec array.
            specs = nansen.plugin.fileadapter.FileAdapterSpec.empty;
        end

    end

    methods (Access = private)

        function specs = removeSpecsWithSidecar(~, specs)
        %removeSpecsWithSidecar Prefer sidecars over inferred class specs.
            if isempty(specs)
                return
            end

            keep = true(1, numel(specs));
            for i = 1:numel(specs)
                sidecarPath = fullfile(fileparts(specs(i).SourcePath), ...
                    'fileadapter.plugin.json');
                if isfile(sidecarPath)
                    keep(i) = false;
                end
            end
            specs = specs(keep);
        end

    end

    methods (Static, Access = private)

        function tf = isFileAdapterClass(mc)
        %isFileAdapterClass True for direct FileAdapter subclasses.
            tf = any(strcmp({mc.SuperclassList.Name}, ...
                'nansen.dataio.FileAdapter'));
        end

        function value = getConstantPropertyValue(mc, propertyName)
        %getConstantPropertyValue Get default value for a class property.
            isProp = strcmp({mc.PropertyList.Name}, propertyName);
            if ~any(isProp)
                error('Nansen:FileAdapterRegistry:MissingProperty', ...
                    'File adapter "%s" is missing property "%s".', ...
                    mc.Name, propertyName)
            end

            value = mc.PropertyList(isProp).DefaultValue;
        end

        function value = getOptionalConstantPropertyValue(mc, propertyName, defaultValue)
        %getOptionalConstantPropertyValue Get optional constant property.
            isProp = strcmp({mc.PropertyList.Name}, propertyName);
            if any(isProp)
                value = mc.PropertyList(isProp).DefaultValue;
            else
                value = defaultValue;
            end
        end

    end

end
