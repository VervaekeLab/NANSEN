classdef TableVariableSpec < nansen.plugin.base.PluginSpec
%TableVariableSpec Metadata for table variable plugins.

    properties (Dependent)
        TableType
        VariableName
        FunctionName
        IsEditable
        DefaultValue
    end

    methods

        function obj = TableVariableSpec(S)
            if nargin == 0
                S = struct();
            end

            obj@nansen.plugin.base.PluginSpec(S);
            obj.PluginType = 'tablevariable';
        end

        function value = get.TableType(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.TypeData, ...
                {'TableType', 'tableType'}, 'session');
        end

        function value = get.VariableName(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.TypeData, ...
                {'VariableName', 'variableName'}, obj.DisplayName);
            if isempty(value)
                value = obj.Id;
            end
        end

        function value = get.FunctionName(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.Implementation, ...
                {'entrypoint', 'function', 'class'}, '');
        end

        function value = get.IsEditable(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.TypeData, ...
                {'IsEditable', 'isEditable'}, false);
        end

        function value = get.DefaultValue(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.TypeData, ...
                {'DefaultValue', 'defaultValue'}, []);
        end

        function S = toAttributeStruct(obj)
        %toAttributeStruct Convert to getMetaTableVariableAttributes shape.
            S = struct();
            S.Name = obj.VariableName;
            S.IsCustom = true;
            S.IsEditable = obj.IsEditable;
            S.HasFunction = ~isempty(obj.FunctionName);

            if S.HasFunction
                S.FunctionName = obj.FunctionName;
            end
        end

    end

    methods (Static)

        function spec = fromPluginSpec(pluginSpec)
        %fromPluginSpec Convert base PluginSpec to TableVariableSpec.
            spec = nansen.plugin.tablevariable.TableVariableSpec.empty;
            for i = 1:numel(pluginSpec)
                spec(end+1) = nansen.plugin.tablevariable.TableVariableSpec( ...
                    pluginSpec(i).struct()); %#ok<AGROW>
                spec(end).TypeData = pluginSpec(i).TypeData;
            end
        end

    end

end
