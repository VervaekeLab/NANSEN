classdef Registry < nansen.plugin.base.Registry
%Registry Registry for imviewer plugins.

    properties (Constant, Access = protected)
        PluginType = 'imviewerplugin'
        SidecarFilename = 'imviewerplugin.plugin.json'
    end

    properties (Access = private)
        AdditionalRootPaths cell = {}
    end

    methods (Static)

        function registry = getInstance(forceRefresh)
        %getInstance Return shared imviewer plugin registry instance.
            persistent registryInstance

            if nargin < 1
                forceRefresh = false;
            end

            if isempty(registryInstance) || ~isvalid(registryInstance)
                registryInstance = nansen.plugin.imviewer.Registry();
            end

            if forceRefresh
                registryInstance.refresh()
            end

            registry = registryInstance;
        end

    end

    methods

        function addRootPath(obj, rootPath)
        %addRootPath Add a root path for imviewer plugin discovery.
            obj.AdditionalRootPaths{end+1} = rootPath;
            obj.clear()
        end

        function pluginFcn = getPluginFcn(obj, pluginName)
        %getPluginFcn Return constructor handle for an imviewer plugin.
            try
                spec = obj.resolve(pluginName);
            catch ME
                if ~strcmp(ME.identifier, 'Nansen:PluginRegistry:PluginNotFound')
                    rethrow(ME)
                end

                specs = obj.list();
                isMatch = strcmpi({specs.DisplayName}, pluginName) | ...
                    strcmpi({specs.Id}, pluginName);
                if ~any(isMatch)
                    rethrow(ME)
                end
                spec = specs(find(isMatch, 1, 'first'));
            end
            spec = nansen.plugin.imviewer.ImviewerPluginSpec.fromPluginSpec(spec);
            pluginFcn = str2func(spec.FunctionName);
        end

    end

    methods (Access = protected)

        function rootPaths = getRootPaths(obj)
        %getRootPaths Return roots where imviewer plugins are defined.
            rootPaths = [obj.AdditionalRootPaths, { ...
                fullfile(nansen.rootpath(), 'code', 'apps', '+imviewer', '+plugin'), ...
                fullfile(nansen.rootpath(), 'code', 'wrappers', '+nansen', '+plugin', '+imviewer') ...
                }];
        end

        function specs = discoverCompatibilitySpecs(obj)
        %discoverCompatibilitySpecs Import existing imviewer plugin classes.
            specs = obj.emptySpecArray();
            mFiles = obj.listPluginClassFiles(obj.getRootPaths());

            for i = 1:numel(mFiles)
                if obj.hasSidecarForSourcePath(mFiles{i})
                    continue
                end

                try
                    spec = obj.createSpecFromPluginFile(mFiles{i});
                    if ~isempty(spec)
                        specs(end+1) = spec; %#ok<AGROW>
                    end
                catch ME
                    obj.addIssue('error', ME.message, mFiles{i});
                end
            end
        end

        function spec = readSidecarSpec(~, filePath)
        %readSidecarSpec Read sidecar and convert to ImviewerPluginSpec.
            baseSpec = nansen.plugin.base.PluginSpec.fromJsonFile(filePath);
            spec = nansen.plugin.imviewer.ImviewerPluginSpec.fromPluginSpec(baseSpec);

            for i = 1:numel(spec)
                if isempty(spec(i).Id)
                    [~, folderName] = fileparts(fileparts(filePath));
                    spec(i).Id = folderName;
                end
                if isempty(spec(i).DisplayName)
                    spec(i).DisplayName = spec(i).Id;
                end
                if isempty(spec(i).Source)
                    spec(i).Source = 'sidecar';
                end
            end
        end

        function spec = normalizeSpec(obj, spec)
        %normalizeSpec Fill imviewer plugin defaults.
            spec = normalizeSpec@nansen.plugin.base.Registry(obj, spec);
            spec.PluginType = obj.PluginType;

            if isempty(spec.DisplayName)
                spec.DisplayName = spec.Id;
            end
        end

        function specs = emptySpecArray(~)
        %emptySpecArray Return an empty imviewer plugin spec array.
            specs = nansen.plugin.imviewer.ImviewerPluginSpec.empty;
        end

    end

    methods (Access = private)

        function spec = createSpecFromPluginFile(~, filePath)
        %createSpecFromPluginFile Infer a plugin spec from a class file.
            className = utility.path.abspath2funcname(filePath);
            mc = meta.class.fromName(className);
            if isempty(mc) || ~nansen.plugin.imviewer.Registry.isImviewerPluginClass(mc)
                spec = nansen.plugin.imviewer.ImviewerPluginSpec.empty;
                return
            end

            pluginName = nansen.plugin.imviewer.Registry.getPluginName(mc);
            spec = nansen.plugin.imviewer.ImviewerPluginSpec();
            spec.Id = className;
            spec.DisplayName = pluginName;
            spec.Source = 'class';
            spec.SourcePath = filePath;
            spec.Implementation = struct('language', 'matlab', ...
                'kind', 'class', 'entrypoint', className, 'class', className);
            spec.TypeData = struct( ...
                'Name', pluginName, ...
                'MenuLocation', {nansen.plugin.imviewer.Registry.inferMenuLocation(pluginName)});
        end

    end

    methods (Static, Access = private)

        function files = listPluginClassFiles(rootPaths)
        %listPluginClassFiles Return likely plugin class definition files.
            files = {};
            if ~iscell(rootPaths)
                rootPaths = {rootPaths};
            end

            for i = 1:numel(rootPaths)
                if ~isfolder(rootPaths{i})
                    continue
                end

                L = dir(fullfile(rootPaths{i}, '**', '*.m'));
                paths = fullfile({L.folder}, {L.name});
                isSettingsFunction = endsWith(paths, 'getDefaultSettings.m');
                files = [files, paths(~isSettingsFunction)]; %#ok<AGROW>
            end
        end

        function tf = isImviewerPluginClass(mc)
        %isImviewerPluginClass True for supported imviewer plugin classes.
            tf = nansen.plugin.imviewer.Registry.hasSuperclass( ...
                mc, 'imviewer.ImviewerPlugin') || ...
                nansen.plugin.imviewer.Registry.hasSuperclass( ...
                mc, 'applify.mixin.AppPlugin');
        end

        function tf = hasSuperclass(mc, superclassName)
        %hasSuperclass True if metaclass inherits from superclassName.
            tf = false;
            for i = 1:numel(mc.SuperclassList)
                if strcmp(mc.SuperclassList(i).Name, superclassName) || ...
                        nansen.plugin.imviewer.Registry.hasSuperclass( ...
                        mc.SuperclassList(i), superclassName)
                    tf = true;
                    return
                end
            end
        end

        function pluginName = getPluginName(mc)
        %getPluginName Read AppPlugin Name constant or fall back to class name.
            pluginName = '';
            isProp = strcmp({mc.PropertyList.Name}, 'Name');
            if any(isProp)
                pluginName = mc.PropertyList(isProp).DefaultValue;
            end

            if isempty(pluginName)
                classNameParts = strsplit(mc.Name, '.');
                pluginName = classNameParts{end};
            end
        end

        function menuLocation = inferMenuLocation(pluginName)
        %inferMenuLocation Keep current imviewer menu grouping.
            switch pluginName
                case {'NoRMCorre', 'FlowRegistration'}
                    menuLocation = {'Align Images'};
                otherwise
                    menuLocation = {};
            end
        end

    end

end
