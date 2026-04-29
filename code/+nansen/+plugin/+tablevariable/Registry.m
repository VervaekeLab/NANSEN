classdef Registry < nansen.plugin.base.Registry
%Registry Registry for table variable plugins.

    properties (Constant, Access = protected)
        PluginType = 'tablevariable'
        SidecarFilename = 'tablevariable.plugin.json'
    end

    properties (Access = private)
        AdditionalRootPaths cell = {}
    end

    methods (Static)

        function registry = getInstance(forceRefresh)
        %getInstance Return shared table variable registry instance.
            persistent registryInstance

            if nargin < 1
                forceRefresh = false;
            end

            if isempty(registryInstance) || ~isvalid(registryInstance)
                registryInstance = nansen.plugin.tablevariable.Registry();
            end

            if forceRefresh
                registryInstance.refresh()
            end

            registry = registryInstance;
        end

    end

    methods

        function addRootPath(obj, rootPath)
        %addRootPath Add a root path for table variable discovery.
            obj.AdditionalRootPaths{end+1} = rootPath;
            obj.clear()
        end

        function names = listVariableNames(obj, tableType)
        %listVariableNames Return variable names for one metatable type.
            if nargin < 2
                tableType = 'session';
            end

            specs = obj.list('TableType', lower(tableType));
            names = {specs.VariableName};
        end

        function attributes = listAttributes(obj, tableType)
        %listAttributes Return MetaTableViewer-compatible attributes.
            if nargin < 2
                tableType = 'session';
            end

            specs = obj.list('TableType', lower(tableType));
            attributes = struct('Name', {}, 'IsCustom', {}, ...
                'IsEditable', {}, 'HasFunction', {}, 'FunctionName', {});

            for i = 1:numel(specs)
                tableVariableSpec = ...
                    nansen.plugin.tablevariable.TableVariableSpec.fromPluginSpec(specs(i));
                attributes(end+1) = tableVariableSpec.toAttributeStruct(); %#ok<AGROW>
            end
        end

    end

    methods (Access = protected)

        function rootPaths = getRootPaths(obj)
        %getRootPaths Return roots where table variables are defined.
            rootPaths = {fullfile(nansen.rootpath(), ...
                'code', '+nansen', '+metadata', '+tablevar')};

            projectPath = obj.getProjectTableVariablePath();
            if ~isempty(projectPath)
                rootPaths{end+1} = projectPath;
            end
            rootPaths = [rootPaths, obj.AdditionalRootPaths];
        end

        function specs = discoverCompatibilitySpecs(obj)
        %discoverCompatibilitySpecs Import existing table variable functions.
            specs = obj.emptySpecArray();
            mFiles = obj.listMatlabFiles(obj.getRootPaths());

            for i = 1:numel(mFiles)
                try
                    spec = obj.createSpecFromTableVariableFile(mFiles{i});
                    if ~isempty(spec)
                        specs(end+1) = spec; %#ok<AGROW>
                    end
                catch ME
                    obj.addIssue('error', ME.message, mFiles{i});
                end
            end
        end

        function spec = readSidecarSpec(~, filePath)
        %readSidecarSpec Read sidecar and convert to TableVariableSpec.
            baseSpec = nansen.plugin.base.PluginSpec.fromJsonFile(filePath);
            spec = nansen.plugin.tablevariable.TableVariableSpec.fromPluginSpec(baseSpec);

            if isempty(spec.Id)
                [~, folderName] = fileparts(fileparts(filePath));
                spec.Id = folderName;
            end
            if isempty(spec.DisplayName)
                spec.DisplayName = spec.Id;
            end
            if isempty(spec.Source)
                spec.Source = 'sidecar';
            end
        end

        function spec = normalizeSpec(obj, spec)
        %normalizeSpec Fill table variable defaults.
            spec = normalizeSpec@nansen.plugin.base.Registry(obj, spec);
            spec.PluginType = obj.PluginType;

            if isempty(spec.DisplayName)
                spec.DisplayName = spec.Id;
            end
            if isfield(spec.TypeData, 'TableType')
                spec.TypeData.TableType = lower(spec.TypeData.TableType);
            elseif isfield(spec.TypeData, 'tableType')
                spec.TypeData.tableType = lower(spec.TypeData.tableType);
            end
        end

        function specs = emptySpecArray(~)
        %emptySpecArray Return an empty table variable spec array.
            specs = nansen.plugin.tablevariable.TableVariableSpec.empty;
        end

    end

    methods (Access = private)

        function spec = createSpecFromTableVariableFile(~, filePath)
        %createSpecFromTableVariableFile Infer a table variable spec.
            functionName = utility.path.abspath2funcname(filePath);
            mc = meta.class.fromName(functionName);

            [~, fileName] = fileparts(filePath);
            spec = nansen.plugin.tablevariable.TableVariableSpec();
            spec.Id = functionName;
            spec.DisplayName = fileName;
            spec.SourcePath = filePath;
            spec.TypeData = struct( ...
                'VariableName', fileName, ...
                'TableType', nansen.plugin.tablevariable.Registry.inferTableType(filePath), ...
                'IsEditable', false);

            if ~isempty(mc)
                spec.Source = 'class';
                spec.Implementation = struct('language', 'matlab', ...
                    'kind', 'class', 'entrypoint', functionName);
                spec.TypeData.IsEditable = ...
                    nansen.plugin.tablevariable.Registry.getConstantPropertyValue( ...
                    mc, 'IS_EDITABLE', false);
                spec.TypeData.DefaultValue = ...
                    nansen.plugin.tablevariable.Registry.getConstantPropertyValue( ...
                    mc, 'DEFAULT_VALUE', []);
            else
                spec.Source = 'function';
                spec.Implementation = struct('language', 'matlab', ...
                    'kind', 'function', 'entrypoint', functionName);
            end
        end

    end

    methods (Static, Access = private)

        function rootPath = getProjectTableVariablePath()
        %getProjectTableVariablePath Return current project's tablevar root.
            rootPath = '';
            try
                rootPath = nansen.localpath('Custom Metatable Variable', 'current');
            catch
                rootPath = '';
            end
        end

        function files = listMatlabFiles(rootPaths)
        %listMatlabFiles Return MATLAB code files under root paths.
            files = {};
            if ~iscell(rootPaths)
                rootPaths = {rootPaths};
            end

            for i = 1:numel(rootPaths)
                if ~isfolder(rootPaths{i})
                    continue
                end

                L = dir(fullfile(rootPaths{i}, '**', '*.m'));
                files = [files, fullfile({L.folder}, {L.name})]; %#ok<AGROW>
            end

            isMixin = contains(files, [filesep, '+mixin', filesep]);
            isTemplate = contains(files, 'Template');
            files = files(~isMixin & ~isTemplate);
        end

        function tableType = inferTableType(filePath)
        %inferTableType Infer table type from project package path.
            folderPath = fileparts(filePath);
            [~, folderName] = fileparts(folderPath);
            if startsWith(folderName, '+')
                tableType = lower(strrep(folderName, '+', ''));
            else
                tableType = 'session';
            end
        end

        function value = getConstantPropertyValue(mc, propertyName, defaultValue)
        %getConstantPropertyValue Get a constant property default if present.
            isProp = strcmp({mc.PropertyList.Name}, propertyName);
            if any(isProp)
                value = mc.PropertyList(isProp).DefaultValue;
            else
                value = defaultValue;
            end
        end

    end

end
