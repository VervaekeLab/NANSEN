classdef TableVariableSpec < nansen.plugin.base.PluginSpec
%TableVariableSpec Metadata for a NANSEN table variable plugin.
%
%   Concrete PluginSpec subclass that adds table-variable–specific typed
%   properties: the metadata entity type the variable targets, whether it
%   is user-editable in the table, its null/default value, and any list
%   alternatives the user can choose from.
%
%   Sidecar JSON format (camelCase only):
%     schemaVersion   "1.0"
%     id              Stable plugin identifier (full package name)
%     displayName     Human-readable label
%     implementation  { language, kind, entrypoint }
%     variableName    Simple class name shown as column header
%     tableType       "session" | "subject"
%     isEditable      true | false
%     alternatives    [string, ...]   (optional)
%
%   See also: nansen.plugin.base.PluginSpec, nansen.plugin.tablevariable.Registry

    properties (Constant)
        TYPE    = 'tablevariable'
        VERSION = '1.0'
        PluginType = nansen.plugin.enum.PluginType.TableVariable
    end

    properties (Access = protected)
        RequiredProperties = ["Id", "VariableName", "TableType"]
    end

    properties
        % VariableName - Simple class name used as the table column header.
        VariableName (1,1) string = ""

        % TableType - Metadata entity type this variable targets ("session"|"subject").
        TableType (1,1) string = "session"

        % IsEditable - True when the user can edit this variable in the table.
        IsEditable (1,1) logical = false

        % DefaultValue - The null/unset value shown before the variable is assigned.
        %   Intentionally untyped because concrete classes may use [], {}, struct, etc.
        DefaultValue = []

        % Alternatives - Ordered list of valid choices (for editable list variables).
        Alternatives (1,:) string = string.empty
    end

    methods

        function obj = TableVariableSpec(options)
        %TableVariableSpec Construct a table variable spec from a property struct.
            arguments
                options (1,1) struct = struct
            end
            obj@nansen.plugin.base.PluginSpec(options)
        end

        function S = toStruct(obj)
        %toStruct Serialize to a flat camelCase struct matching the sidecar format.
            S = toStruct@nansen.plugin.base.PluginSpec(obj);
            S.variableName = char(obj.VariableName);
            S.tableType    = char(obj.TableType);
            S.isEditable   = obj.IsEditable;
            S.alternatives = cellstr(obj.Alternatives);
        end

        function S = toVariableAttributes(obj)
        %toVariableAttributes Build a struct compatible with buildTableVariableTable output.
        %
        %   Returns a struct with the same fields as
        %   TableVariable.getDefaultTableVariableAttribute(), filled from
        %   this spec. Computed fields (HasUpdateFunction, etc.) are
        %   introspected from the metaclass when the entrypoint is on path.

            S = nansen.metadata.abstract.TableVariable.getDefaultTableVariableAttribute();

            S.Name      = char(obj.VariableName);
            S.TableType = char(obj.TableType);
            S.IsEditable = obj.IsEditable;

            entrypoint = obj.resolveEntrypoint();
            if ~isempty(entrypoint)
                S.HasClassDefinition = true;
                S.ClassName = entrypoint;
                S.NullValue = obj.DefaultValue;

                if ~isempty(obj.Alternatives)
                    S.HasOptions   = true;
                    S.OptionsList  = cellstr(obj.Alternatives);
                end

                % Introspect override methods from metaclass
                mc = meta.class.fromName(entrypoint);
                if ~isempty(mc)
                    S = nansen.plugin.tablevariable.TableVariableSpec.fillMethodFlags(S, mc, entrypoint);
                end
            end
        end

    end

    methods (Static)

        function specs = fromJsonFile(filePath)
        %fromJsonFile Read one or more TableVariableSpecs from a sidecar JSON file.
        %
        %   Handles both single-plugin sidecars and grouped-array format.
            S = nansen.plugin.base.PluginSpec.readJsonFile(filePath);
            if isfield(S, 'plugins')
                specs = nansen.plugin.tablevariable.TableVariableSpec.empty;
                for i = 1:numel(S.plugins)
                    specs(end+1) = nansen.plugin.tablevariable.TableVariableSpec.fromSidecarStruct( ...
                        S.plugins(i), filePath); %#ok<AGROW>
                end
            else
                specs = nansen.plugin.tablevariable.TableVariableSpec.fromSidecarStruct(S, filePath);
            end
        end

        function spec = fromSidecarStruct(S, sourcePath)
        %fromSidecarStruct Build a TableVariableSpec from a decoded sidecar struct.
            arguments
                S          (1,1) struct
                sourcePath (1,1) string = ""
            end

            opts = nansen.plugin.base.PluginSpec.parseBaseFields(S, sourcePath);

            if isfield(S, 'variableName') && ~isempty(S.variableName)
                opts.VariableName = string(S.variableName);
            end
            if isfield(S, 'tableType') && ~isempty(S.tableType)
                opts.TableType = string(S.tableType);
            end
            if isfield(S, 'isEditable')
                opts.IsEditable = logical(S.isEditable);
            end
            if isfield(S, 'alternatives') && ~isempty(S.alternatives)
                opts.Alternatives = string(S.alternatives(:)');
            end

            spec = nansen.plugin.tablevariable.TableVariableSpec(opts);
        end

    end

    methods (Access = private)
    end

    methods (Static, Access = private)

        function S = fillMethodFlags(S, mc, className)
        %fillMethodFlags Fill HasUpdateFunction etc. by inspecting metaclass overrides.
            BASE_CLASS = 'nansen.metadata.abstract.TableVariable';

            [hasUpdate, updateName] = nansen.plugin.tablevariable.TableVariableSpec.isOverridden( ...
                mc, className, 'update', BASE_CLASS);
            if hasUpdate
                S.HasUpdateFunction  = true;
                S.UpdateFunctionName = updateName;
            end

            [hasClick, clickName] = nansen.plugin.tablevariable.TableVariableSpec.isOverridden( ...
                mc, className, 'onCellDoubleClick', BASE_CLASS);
            if hasClick
                S.HasDoubleClickFunction  = true;
                S.DoubleClickFunctionName = clickName;
            end

            % Check for TableColumnFormatter mixin (renderer support)
            if nansen.plugin.tablevariable.TableVariableSpec.hasSuperclass( ...
                    mc, 'nansen.metadata.abstract.TableColumnFormatter')
                S.HasRendererFunction  = true;
                S.RendererFunctionName = className;
            end
        end

        function [tf, fcnName] = isOverridden(mc, className, methodName, baseClass)
        %isOverridden True when methodName is defined by a class other than baseClass.
            tf      = false;
            fcnName = '';
            matches = strcmp({mc.MethodList.Name}, methodName);
            if ~any(matches); return; end
            defClass = mc.MethodList(find(matches,1)).DefiningClass.Name;
            if ~strcmp(defClass, baseClass)
                tf      = true;
                fcnName = strjoin({className, methodName}, '.');
            end
        end

        function tf = hasSuperclass(mc, superclassName)
        %hasSuperclass Recursive superclass check for metaclass objects.
            tf = false;
            for i = 1:numel(mc.SuperclassList)
                if strcmp(mc.SuperclassList(i).Name, superclassName) || ...
                        nansen.plugin.tablevariable.TableVariableSpec.hasSuperclass( ...
                        mc.SuperclassList(i), superclassName)
                    tf = true;
                    return
                end
            end
        end

    end

end
