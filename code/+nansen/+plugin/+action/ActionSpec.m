classdef ActionSpec < nansen.plugin.base.PluginSpec
%ActionSpec Metadata for an entity/action plugin.

    properties (Dependent)
        EntityType
        MethodName
        FunctionName
        TaskType
        BatchMode
        IsQueueable
        Alternatives
        MenuLocation
    end

    methods

        function obj = ActionSpec(S)
            if nargin == 0
                S = struct();
            end

            obj@nansen.plugin.base.PluginSpec(S);
            obj.PluginType = 'action';
        end

        function value = get.EntityType(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.TypeData, ...
                {'EntityType', 'entityType'}, 'session');
        end

        function value = get.MethodName(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.TypeData, ...
                {'MethodName', 'methodName'}, obj.DisplayName);
            if isempty(value)
                value = obj.Id;
            end
        end

        function value = get.FunctionName(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.Implementation, ...
                {'entrypoint', 'function', 'class'}, '');
        end

        function value = get.TaskType(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.TypeData, ...
                {'TaskType', 'taskType'}, '');
            if isempty(value)
                value = nansen.plugin.base.PluginSpec.getField(obj.Implementation, ...
                    {'kind'}, '');
            end
        end

        function value = get.BatchMode(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.TypeData, ...
                {'BatchMode', 'batchMode'}, 'serial');
        end

        function value = get.IsQueueable(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.TypeData, ...
                {'IsQueueable', 'isQueueable'}, true);
        end

        function value = get.Alternatives(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.TypeData, ...
                {'Alternatives', 'alternatives'}, {});
            if ischar(value)
                value = {value};
            elseif isstring(value)
                value = cellstr(value);
            end
        end

        function value = get.MenuLocation(obj)
            value = nansen.plugin.base.PluginSpec.getField(obj.TypeData, ...
                {'MenuLocation', 'menuLocation', 'menuPath'}, {});
            if ischar(value)
                value = {value};
            elseif isstring(value)
                value = cellstr(value);
            end
        end

        function S = toTaskAttributes(obj)
        %toTaskAttributes Convert to SessionTaskMenu-compatible attributes.
            S = struct();
            S.FunctionName = obj.FunctionName;
            S.FunctionHandle = str2func(obj.FunctionName);
            S.TaskType = obj.TaskType;
            S.IsQueueable = obj.IsQueueable;
            S.BatchMode = obj.BatchMode;
            S.MethodName = obj.MethodName;
            S.Alternatives = obj.Alternatives;

            if isfield(obj.TypeData, 'DefaultOptions')
                S.DefaultOptions = obj.TypeData.DefaultOptions;
            end
            if isfield(obj.TypeData, 'OptionsManager')
                S.OptionsManager = obj.TypeData.OptionsManager;
            end
        end

    end

    methods (Static)

        function spec = fromPluginSpec(pluginSpec)
        %fromPluginSpec Convert base PluginSpec to ActionSpec.
            spec = nansen.plugin.action.ActionSpec.empty;
            for i = 1:numel(pluginSpec)
                spec(end+1) = nansen.plugin.action.ActionSpec( ...
                    pluginSpec(i).struct()); %#ok<AGROW>
                spec(end).TypeData = pluginSpec(i).TypeData;
            end
        end

    end

end
