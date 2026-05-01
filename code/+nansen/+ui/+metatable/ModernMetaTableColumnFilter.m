classdef ModernMetaTableColumnFilter < handle
%ModernMetaTableColumnFilter Filtering state for the native table backend.
%
%   The legacy filter class owns Java/uicontrol popup widgets. This modern
%   class keeps the filtering contract in place without depending on Java.
%   A richer uifigure filter UI can be layered onto this class later.

    properties
        AppReference
        ComponentPanel
        hColumnFilterPopups
        columnFilterType
        isColumnFilterActive
        isColumnFilterDirty
    end

    properties (SetAccess = private)
        MetaTableUi
        TableParent
    end

    properties (Dependent, SetAccess = private)
        MetaTable
    end

    events
        FilterUpdated
    end

    methods
        function obj = ModernMetaTableColumnFilter(uiTable, appRef)
            obj.MetaTableUi = uiTable;
            obj.AppReference = appRef;

            if isa(obj.MetaTableUi.MetaTable, 'table')
                obj.onMetaTableChanged()
            end
        end

        function metaTable = get.MetaTable(obj)
            metaTable = obj.MetaTableUi.MetaTableCell;
        end
    end

    methods
        function onMetaTableChanged(obj)
            obj.reinitializeFilterControlProperties()
        end

        function onMetaTableUpdated(obj)
            if isempty(obj.hColumnFilterPopups)
                obj.onMetaTableChanged()
            end
        end

        function popup = openFilterControl(obj, columnIdx)
            popup = [];
            if isempty(obj.MetaTableUi) || ~isvalid(obj.MetaTableUi)
                return
            end

            popup = obj.MetaTableUi.openFilterControl(columnIdx);
            if isempty(popup)
                return
            end

            if isempty(obj.hColumnFilterPopups)
                obj.reinitializeFilterControlProperties()
            end
            obj.hColumnFilterPopups{columnIdx} = popup;
        end

        function deleteFilterControls(obj)
            obj.hColumnFilterPopups = {};
        end

        function reinitializeFilterControlProperties(obj)
            if isempty(obj.MetaTableUi.MetaTable)
                numColumns = 0;
            else
                numColumns = width(obj.MetaTableUi.MetaTable);
            end

            obj.hColumnFilterPopups = cell(numColumns, 1);
            obj.columnFilterType = repmat({'N/A'}, numColumns, 1);
            obj.isColumnFilterActive = false(numColumns, 1);
            obj.isColumnFilterDirty = false(numColumns, 1);
        end

        function resetFilters(obj)
            obj.MetaTableUi.clearUserColumnFilters()
        end

        function hideFilters(~)
        end

        function setActiveVariableNames(obj, variableNames)
            obj.isColumnFilterActive(:) = false;
            if isempty(variableNames) || isempty(obj.MetaTableUi.MetaTable)
                return
            end

            tableVariableNames = string(obj.MetaTableUi.MetaTable.Properties.VariableNames);
            obj.isColumnFilterActive = ismember(tableVariableNames, string(variableNames(:)));
            obj.isColumnFilterDirty(:) = true;
        end
    end
end
