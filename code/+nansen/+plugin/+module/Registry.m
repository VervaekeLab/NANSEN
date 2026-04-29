classdef Registry < nansen.plugin.base.Registry
%Registry Registry for NANSEN module metadata.

    properties (Constant, Access = protected)
        PluginType = 'module'
        SidecarFilename = 'module.nansen.json'
    end

    properties (Access = private)
        AdditionalRootPaths cell = {}
    end

    methods (Static)

        function registry = getInstance(forceRefresh)
        %getInstance Return shared module registry instance.
            persistent registryInstance

            if nargin < 1
                forceRefresh = false;
            end

            if isempty(registryInstance) || ~isvalid(registryInstance)
                registryInstance = nansen.plugin.module.Registry();
            end

            if forceRefresh
                registryInstance.refresh()
            end

            registry = registryInstance;
        end

    end

    methods

        function addRootPath(obj, rootPath)
        %addRootPath Add a root path for module metadata discovery.
            obj.AdditionalRootPaths{end+1} = rootPath;
            obj.clear()
        end

    end

    methods (Access = protected)

        function rootPaths = getRootPaths(obj)
        %getRootPaths Return roots where module metadata can exist.
            rootPaths = [{nansen.rootpath()}, obj.AdditionalRootPaths];
        end

        function spec = readSidecarSpec(~, filePath)
        %readSidecarSpec Read sidecar and convert to ModuleSpec.
            baseSpec = nansen.plugin.base.PluginSpec.fromJsonFile(filePath);
            spec = nansen.plugin.module.ModuleSpec.fromPluginSpec(baseSpec);

            for i = 1:numel(spec)
                if isempty(spec(i).Id)
                    spec(i).Id = spec(i).Name;
                end
                if isempty(spec(i).DisplayName)
                    spec(i).DisplayName = spec(i).Name;
                end
                if isempty(spec(i).Source)
                    spec(i).Source = 'sidecar';
                end
            end
        end

        function [specs, issues] = postprocessSpecs(obj, specs)
        %postprocessSpecs Validate modules after base processing.
            [specs, issues] = postprocessSpecs@nansen.plugin.base.Registry(obj, specs);

            knownModuleIds = {specs.Id};
            for i = 1:numel(specs)
                moduleSpec = nansen.plugin.module.ModuleSpec.fromPluginSpec(specs(i));
                issues = [issues, ...
                    obj.validateModuleDependencies(moduleSpec, knownModuleIds)]; %#ok<AGROW>
            end
        end

        function specs = emptySpecArray(~)
        %emptySpecArray Return an empty module spec array.
            specs = nansen.plugin.module.ModuleSpec.empty;
        end

    end

    methods (Access = private)

        function issues = validateModuleDependencies(obj, spec, knownModuleIds)
        %validateModuleDependencies Check declared module dependencies.
            issues = obj.getEmptyIssues();
            dependencies = spec.Dependencies;
            if isempty(dependencies)
                return
            end

            for i = 1:numel(dependencies)
                dependencyName = nansen.plugin.base.PluginSpec.getField( ...
                    dependencies(i), {'Module', 'module', 'Id', 'id'}, '');
                if isempty(dependencyName)
                    continue
                end

                if ~any(strcmp(knownModuleIds, dependencyName))
                    issues(end+1) = obj.makeIssue('warning', ...
                        sprintf('Module "%s" depends on missing module "%s".', ...
                        spec.Id, dependencyName), spec.SourcePath); %#ok<AGROW>
                end
            end
        end

    end

end
