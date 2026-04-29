classdef ModuleSpec < nansen.plugin.base.PluginSpec
%ModuleSpec Metadata for a NANSEN plugin module.

    properties (Dependent)
        Name
        ModuleVersion
        MinNansenVersion
        MaxNansenVersion
        Dependencies
        Provides
    end

    methods

        function obj = ModuleSpec(S)
            if nargin == 0
                S = struct();
            end

            obj@nansen.plugin.base.PluginSpec(S);
            obj.PluginType = 'module';
        end

        function value = get.Name(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.TypeData, ...
                {'Name', 'name'}, obj.DisplayName);
        end

        function value = get.ModuleVersion(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.TypeData, ...
                {'ModuleVersion', 'moduleVersion', 'version'}, obj.Version);
        end

        function value = get.MinNansenVersion(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.TypeData, ...
                {'MinNansenVersion', 'minNansenVersion'}, '');
        end

        function value = get.MaxNansenVersion(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.TypeData, ...
                {'MaxNansenVersion', 'maxNansenVersion'}, '');
        end

        function value = get.Dependencies(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.TypeData, ...
                {'Dependencies', 'dependencies'}, struct.empty);
        end

        function value = get.Provides(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.TypeData, ...
                {'Provides', 'provides'}, {});
            if ischar(value)
                value = {value};
            elseif isstring(value)
                value = cellstr(value);
            end
        end

    end

    methods (Static)

        function spec = fromPluginSpec(pluginSpec)
        %fromPluginSpec Convert base PluginSpec to ModuleSpec.
            spec = nansen.plugin.module.ModuleSpec.empty;
            for i = 1:numel(pluginSpec)
                spec(end+1) = nansen.plugin.module.ModuleSpec( ...
                    pluginSpec(i).struct()); %#ok<AGROW>
                spec(end).TypeData = pluginSpec(i).TypeData;
            end
        end

    end

end
