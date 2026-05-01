classdef MetaTableViewer < handle
%MetaTableViewer Public facade for metadata table viewers.
%
%   This class preserves the historical nansen.MetaTableViewer API while
%   delegating rendering and interaction to a release-specific backend. The
%   legacy backend keeps the Java/Widgets Toolbox implementation for older
%   MATLAB releases. MATLAB R2025a and newer use a native uitable backend.

    properties (Constant, Hidden)
        VALID_TABLE_CLASS = {'nansen.metadata.MetaTable', 'table'};
    end

    properties (Access = private)
        Backend
        SelectionChangedListener event.listener
        TableUpdatedListener event.listener
    end

    properties (Dependent)
        ShowIgnoredEntries
        AllowTableEdits
        TableFontSize
        MetaTableType

        SelectedEntries
        CellEditCallback
        KeyPressCallback
        MouseDoubleClickedFcn
        DeleteColumnFcn
        UpdateColumnFcn
        ResetColumnFcn
        EditColumnFcn
        GetTableVariableAttributesFcn

        ColumnSettings

        AppRef
        Parent
        ColumnContextMenu
        TableContextMenu
        DataFilterMap
        ExternalFilterMap
    end

    properties (Dependent, SetAccess = private)
        MetaTable
        MetaTableCell
        MetaTableVariableNames
        MetaTableVariableAttributes
        DisplayedRows

        ColumnModel
        ColumnFilter

        HTable
        JTable
    end

    events
        TableUpdated
        SelectionChanged
    end

    methods
        function obj = MetaTableViewer(varargin)
            if nansen.util.useModernUiTable()
                obj.Backend = nansen.ui.metatable.EntityTableMetaTableViewer(varargin{:});
            else
                obj.Backend = nansen.ui.metatable.LegacyJavaMetaTableViewer(varargin{:});
            end

            obj.SelectionChangedListener = addlistener(obj.Backend, ...
                'SelectionChanged', @(src, evt) obj.notifySelectionChanged(evt));
            obj.TableUpdatedListener = addlistener(obj.Backend, ...
                'TableUpdated', @(src, evt) obj.notifyTableUpdated(evt));
        end

        function delete(obj)
            if ~isempty(obj.SelectionChangedListener)
                delete(obj.SelectionChangedListener)
            end
            if ~isempty(obj.TableUpdatedListener)
                delete(obj.TableUpdatedListener)
            end
            if ~isempty(obj.Backend) && isvalid(obj.Backend)
                delete(obj.Backend)
            end
        end
    end

    methods
        function refreshColumnModel(obj, varargin)
            obj.Backend.refreshColumnModel(varargin{:})
        end

        function cleanup = suspendRefresh(obj)
            cleanup = onCleanup(@() []);
            if ismethod(obj.Backend, 'suspendRefresh')
                cleanup = obj.Backend.suspendRefresh();
            end
        end

        function setBusy(obj, isBusy, message)
            arguments
                obj
                isBusy (1,1) logical
                message (1,1) string = "Working..."
            end

            if ismethod(obj.Backend, 'setBusy')
                obj.Backend.setBusy(isBusy, message)
            end
        end

        function resetTable(obj, varargin)
            obj.Backend.resetTable(varargin{:})
        end

        function resetColumnFilters(obj, varargin)
            obj.Backend.resetColumnFilters(varargin{:})
        end

        function updateCells(obj, varargin)
            obj.Backend.updateCells(varargin{:})
        end

        function updateTableRow(obj, varargin)
            obj.Backend.updateTableRow(varargin{:})
        end

        function updateFormattedTableColumnData(obj, varargin)
            obj.Backend.updateFormattedTableColumnData(varargin{:})
        end

        function updateVisibleRows(obj, varargin)
            obj.Backend.updateVisibleRows(varargin{:})
        end

        function refreshTable(obj, varargin)
            obj.Backend.refreshTable(varargin{:})
        end

        function replaceTable(obj, varargin)
            obj.Backend.replaceTable(varargin{:})
        end

        function rowInd = getMetaTableRows(obj, varargin)
            rowInd = obj.Backend.getMetaTableRows(varargin{:});
        end

        function IND = getSelectedEntries(obj, varargin)
            IND = obj.Backend.getSelectedEntries(varargin{:});
        end

        function setSelectedEntries(obj, varargin)
            obj.Backend.setSelectedEntries(varargin{:})
        end

        function [columnNames, variableNames] = getColumnNames(obj, varargin)
            [columnNames, variableNames] = obj.Backend.getColumnNames(varargin{:});
        end

        function focusTable(obj)
            if ismethod(obj.Backend, 'focusTable')
                obj.Backend.focusTable()
            elseif ~isempty(obj.JTable)
                obj.JTable.requestFocus()
            end
        end

        function setTableTooltip(obj, tooltipText)
            if ismethod(obj.Backend, 'setTableTooltip')
                obj.Backend.setTableTooltip(tooltipText)
            elseif ~isempty(obj.JTable)
                set(obj.JTable, 'ToolTipText', tooltipText)
            end
        end

        function setKeyPressFcn(obj, callback)
            if ismethod(obj.Backend, 'setKeyPressFcn')
                obj.Backend.setKeyPressFcn(callback)
            elseif ~isempty(obj.HTable)
                obj.HTable.KeyPressFcn = callback;
            end
        end

        function listenerHandle = addMouseMotionCallback(obj, callback)
            listenerHandle = [];
            if ismethod(obj.Backend, 'addMouseMotionCallback')
                listenerHandle = obj.Backend.addMouseMotionCallback(callback);
            elseif ~isempty(obj.HTable)
                listenerHandle = addlistener(obj.HTable, 'MouseMotion', callback);
            end
        end

        function n = getDisplayedRowCount(obj)
            if ismethod(obj.Backend, 'getDisplayedRowCount')
                n = obj.Backend.getDisplayedRowCount();
            elseif ~isempty(obj.HTable)
                n = size(obj.HTable.Data, 1);
            else
                n = 0;
            end
        end

        function n = getSelectedRowCount(obj)
            if ismethod(obj.Backend, 'getSelectedRowCount')
                n = obj.Backend.getSelectedRowCount();
            elseif ~isempty(obj.HTable)
                n = numel(obj.HTable.SelectedRows);
            else
                n = 0;
            end
        end

        function tf = usesModernBackend(obj)
            tf = isa(obj.Backend, 'nansen.ui.metatable.EntityTableMetaTableViewer') || ...
                isa(obj.Backend, 'nansen.ui.metatable.ModernUiMetaTableViewer');
        end

        function fitColumnsToTableWidth(obj)
            if ismethod(obj.Backend, 'fitColumnsToTableWidth')
                obj.Backend.fitColumnsToTableWidth()
            end
        end

        function flushColumnSettings(obj)
            if ismethod(obj.Backend, 'flushColumnSettings')
                obj.Backend.flushColumnSettings()
            end
        end
    end

    methods
        function value = get.ShowIgnoredEntries(obj), value = obj.Backend.ShowIgnoredEntries; end
        function set.ShowIgnoredEntries(obj, value), obj.Backend.ShowIgnoredEntries = value; end

        function value = get.AllowTableEdits(obj), value = obj.Backend.AllowTableEdits; end
        function set.AllowTableEdits(obj, value), obj.Backend.AllowTableEdits = value; end

        function value = get.TableFontSize(obj), value = obj.Backend.TableFontSize; end
        function set.TableFontSize(obj, value), obj.Backend.TableFontSize = value; end

        function value = get.MetaTableType(obj), value = obj.Backend.MetaTableType; end
        function set.MetaTableType(obj, value), obj.Backend.MetaTableType = value; end

        function value = get.SelectedEntries(obj), value = obj.Backend.SelectedEntries; end
        function set.SelectedEntries(obj, value), obj.Backend.SelectedEntries = value; end

        function value = get.CellEditCallback(obj), value = obj.Backend.CellEditCallback; end
        function set.CellEditCallback(obj, value), obj.Backend.CellEditCallback = value; end

        function value = get.KeyPressCallback(obj), value = obj.Backend.KeyPressCallback; end
        function set.KeyPressCallback(obj, value), obj.Backend.KeyPressCallback = value; end

        function value = get.MouseDoubleClickedFcn(obj), value = obj.Backend.MouseDoubleClickedFcn; end
        function set.MouseDoubleClickedFcn(obj, value), obj.Backend.MouseDoubleClickedFcn = value; end

        function value = get.DeleteColumnFcn(obj), value = obj.Backend.DeleteColumnFcn; end
        function set.DeleteColumnFcn(obj, value), obj.Backend.DeleteColumnFcn = value; end

        function value = get.UpdateColumnFcn(obj), value = obj.Backend.UpdateColumnFcn; end
        function set.UpdateColumnFcn(obj, value), obj.Backend.UpdateColumnFcn = value; end

        function value = get.ResetColumnFcn(obj), value = obj.Backend.ResetColumnFcn; end
        function set.ResetColumnFcn(obj, value), obj.Backend.ResetColumnFcn = value; end

        function value = get.EditColumnFcn(obj), value = obj.Backend.EditColumnFcn; end
        function set.EditColumnFcn(obj, value), obj.Backend.EditColumnFcn = value; end

        function value = get.GetTableVariableAttributesFcn(obj), value = obj.Backend.GetTableVariableAttributesFcn; end
        function set.GetTableVariableAttributesFcn(obj, value), obj.Backend.GetTableVariableAttributesFcn = value; end

        function value = get.MetaTable(obj), value = obj.Backend.MetaTable; end

        function value = get.MetaTableCell(obj), value = obj.Backend.MetaTableCell; end
        function value = get.MetaTableVariableNames(obj), value = obj.Backend.MetaTableVariableNames; end
        function value = get.MetaTableVariableAttributes(obj), value = obj.Backend.MetaTableVariableAttributes; end

        function value = get.ColumnSettings(obj), value = obj.Backend.ColumnSettings; end
        function set.ColumnSettings(obj, value), obj.Backend.ColumnSettings = value; end

        function value = get.DisplayedRows(obj), value = obj.Backend.DisplayedRows; end

        function value = get.ColumnModel(obj), value = obj.Backend.ColumnModel; end
        function value = get.ColumnFilter(obj), value = obj.Backend.ColumnFilter; end

        function value = get.AppRef(obj), value = obj.Backend.AppRef; end
        function set.AppRef(obj, value), obj.Backend.AppRef = value; end

        function value = get.Parent(obj), value = obj.Backend.Parent; end
        function set.Parent(obj, value), obj.Backend.Parent = value; end

        function value = get.HTable(obj), value = obj.Backend.HTable; end
        function value = get.JTable(obj), value = obj.Backend.JTable; end

        function value = get.ColumnContextMenu(obj), value = obj.Backend.ColumnContextMenu; end
        function set.ColumnContextMenu(obj, value)
            obj.Backend.ColumnContextMenu = value;
        end

        function value = get.TableContextMenu(obj), value = obj.Backend.TableContextMenu; end
        function set.TableContextMenu(obj, value)
            obj.Backend.TableContextMenu = value;
            if isa(obj.Backend, 'nansen.ui.metatable.EntityTableMetaTableViewer')
                return
            end
            if ~isempty(obj.Backend.HTable) && isvalid(obj.Backend.HTable) ...
                    && isprop(obj.Backend.HTable, 'ContextMenu')
                obj.Backend.HTable.ContextMenu = value;
            end
        end

        function value = get.DataFilterMap(obj), value = obj.Backend.DataFilterMap; end
        function set.DataFilterMap(obj, value), obj.Backend.DataFilterMap = value; end

        function value = get.ExternalFilterMap(obj), value = obj.Backend.ExternalFilterMap; end
        function set.ExternalFilterMap(obj, value), obj.Backend.ExternalFilterMap = value; end
    end

    methods (Access = private)
        function notifySelectionChanged(obj, evt)
            obj.notify('SelectionChanged', evt)
        end

        function notifyTableUpdated(obj, evt)
            obj.notify('TableUpdated', evt)
        end
    end

    methods (Static)
        function tf = isValidTableClass(var)
        %isValidTable Test if var satisfies the list of valid table classes
            validClasses = nansen.MetaTableViewer.VALID_TABLE_CLASS;
            tf = any(cellfun(@(type) isa(var, type), validClasses));
        end
    end
end
