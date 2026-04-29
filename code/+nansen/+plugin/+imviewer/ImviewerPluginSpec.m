classdef ImviewerPluginSpec < nansen.plugin.base.PluginSpec
%ImviewerPluginSpec Metadata for imviewer plugins.

    properties (Dependent)
        Name
        FunctionName
        MenuLocation
    end

    methods

        function obj = ImviewerPluginSpec(S)
            if nargin == 0
                S = struct();
            end

            obj@nansen.plugin.base.PluginSpec(S);
            obj.PluginType = 'imviewerplugin';
        end

        function value = get.Name(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.TypeData, ...
                {'Name', 'name'}, obj.DisplayName);
            if isempty(value)
                value = obj.DisplayName;
            end
        end

        function value = get.FunctionName(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.Implementation, ...
                {'entrypoint', 'class'}, '');
        end

        function value = get.MenuLocation(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.TypeData, ...
                {'MenuLocation', 'menuLocation'}, {});
            if ischar(value)
                value = {value};
            elseif isstring(value)
                value = cellstr(value);
            end
        end

    end

    methods (Static)

        function spec = fromPluginSpec(pluginSpec)
        %fromPluginSpec Convert base PluginSpec to ImviewerPluginSpec.
            spec = nansen.plugin.imviewer.ImviewerPluginSpec.empty;
            for i = 1:numel(pluginSpec)
                spec(end+1) = nansen.plugin.imviewer.ImviewerPluginSpec( ...
                    pluginSpec(i).struct()); %#ok<AGROW>
                spec(end).TypeData = pluginSpec(i).TypeData;
            end
        end

    end

end
