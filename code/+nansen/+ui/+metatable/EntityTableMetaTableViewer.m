classdef EntityTableMetaTableViewer < handle
%EntityTableMetaTableViewer NANSEN adapter for the standalone entity table.

    properties (Constant, Hidden)
        VALID_TABLE_CLASS = {'nansen.metadata.MetaTable', 'table'};
    end

    properties
        ShowIgnoredEntries = true
        AllowTableEdits = true
        TableFontSize = 12
        MetaTableType = 'session'

        SelectedEntries
        CellEditCallback
        KeyPressCallback
        MouseDoubleClickedFcn = []
        Theme (1,1) string = "light"

        DeleteColumnFcn = []
        UpdateColumnFcn = []
        ResetColumnFcn = []
        EditColumnFcn = []
        GetTableVariableAttributesFcn = []
    end

    properties (SetAccess = private, SetObservable = true)
        MetaTable
        MetaTableCell cell
        MetaTableVariableNames
        MetaTableVariableAttributes
    end

    properties (Dependent)
        ColumnSettings
        DisplayedRows
    end

    properties (SetAccess = private)
        ColumnModel
        ColumnFilter
    end

    properties
        AppRef
        Parent
        HTable
        JTable = []

        ColumnContextMenu = []
        TableContextMenu = []

        DataFilterMap = []
        ExternalFilterMap = []
        FilterChangedListener event.listener
    end

    properties (Access = private)
        ColumnSettings_
        EntityTableView = []
        EntityTableListeners = []
        ColumnWidthChangedListener = []
        RowKeyVariableName = 'NansenRowIndex__'
        ColumnFilterActive = []
        ActiveColumnFilterNames (1,:) string = strings(1, 0)
        IsConstructed = false
        RequireReset = false
        MouseMotionCallback = []
        AutoFitColumnWidths (1,1) logical = true
        AutoAppliedColumnWidths (1,:) double = []
        IsApplyingColumnWidths (1,1) logical = false
        HtmlStyleConfigurationRows = []
        UseHtmlTable (1,1) logical = false
    end

    events
        TableUpdated
        SelectionChanged
    end

    methods
        function obj = EntityTableMetaTableViewer(varargin)
            nansen.util.ensureEntityTableOnPath()
            obj.UseHtmlTable = obj.shouldUseHtmlTable();
            obj.parseInputs(varargin)

            obj.ColumnModel = nansen.ui.MetaTableColumnLayout(...
                obj, 'ColumnSettings', obj.ColumnSettings);
            obj.createEntityTable(table.empty, entitytable.ColumnSpec.empty(1, 0))
            obj.createColumnContextMenu()
            obj.ColumnFilter = nansen.ui.metatable.ModernMetaTableColumnFilter(obj, obj.AppRef);

            obj.IsConstructed = true;

            if ~isempty(obj.MetaTableCell)
                obj.refreshTable()
                obj.HTable.Visible = 'on';
                drawnow
            end
        end

        function delete(obj)
            obj.captureColumnWidths()
            obj.deleteColumnWidthListener()
            obj.deleteEntityTableListeners()

            if ~isempty(obj.EntityTableView) && isvalid(obj.EntityTableView)
                delete(obj.EntityTableView)
            elseif ~isempty(obj.HTable) && isvalid(obj.HTable)
                delete(obj.HTable)
            end

            if ~isempty(obj.ColumnModel) && isvalid(obj.ColumnModel)
                delete(obj.ColumnModel)
            end
        end
    end

    methods
        function rowIndices = get.DisplayedRows(obj)
            if isempty(obj.EntityTableView) || ~isvalid(obj.EntityTableView)
                rowIndices = [];
            else
                rowIndices = obj.EntityTableView.getDisplayRowIndex();
                rowIndices = rowIndices(:).';
            end
        end

        function set.MetaTable(obj, newTable)
            if isa(newTable, 'nansen.metadata.MetaTable')
                obj.MetaTable = newTable.entries;
            elseif isa(newTable, 'table')
                obj.MetaTable = newTable;
            else
                error('New value of MetaTable property must be a MetaTable or a table object')
            end

            obj.onMetaTableSet(newTable)
        end

        function set.MetaTableType(obj, newValue)
            oldType = obj.MetaTableType;
            obj.MetaTableType = lower(newValue);
            obj.RequireReset = ~strcmpi(oldType, newValue); %#ok<MCSUP>
        end

        function set.ColumnSettings(obj, newSettings)
            if isempty(obj.ColumnModel)
                obj.ColumnSettings_ = newSettings;
            else
                obj.ColumnModel.replaceColumnSettings(newSettings);
                obj.updateColumnLayout()
            end
        end

        function colSettings = get.ColumnSettings(obj)
            if isempty(obj.ColumnModel)
                colSettings = obj.ColumnSettings_;
            else
                colSettings = obj.ColumnModel.settings;
            end
        end

        function set.ColumnFilter(obj, newValue)
            obj.ColumnFilter = newValue;
            if ~isempty(newValue)
                obj.onColumnFilterSet()
            end
        end

        function set.ShowIgnoredEntries(obj, newValue)
            assert(islogical(newValue), 'Value for ShowIgnoredEntries must be a boolean')
            obj.ShowIgnoredEntries = newValue;
            obj.applySystemFilters()
        end

        function set.AllowTableEdits(obj, newValue)
            assert(islogical(newValue), 'Value for AllowTableEdits must be a boolean')
            obj.AllowTableEdits = newValue;
            obj.updateColumnEditable()
        end

        function set.TableFontSize(obj, newValue)
            obj.TableFontSize = newValue;
            obj.onTableFontSizeSet()
        end

        function set.KeyPressCallback(obj, newValue)
            obj.KeyPressCallback = newValue;
            obj.setKeyPressFcn(newValue)
        end

        function set.GetTableVariableAttributesFcn(obj, newValue)
            obj.GetTableVariableAttributesFcn = newValue;
            obj.onTableVariableAttributesFcnSet()
        end

        function set.TableContextMenu(obj, newValue)
            obj.TableContextMenu = newValue;
            obj.syncEntityTableContextMenus()
        end

        function set.ColumnContextMenu(obj, newValue)
            obj.ColumnContextMenu = newValue;
            obj.syncEntityTableContextMenus()
        end
    end

    methods
        function cleanup = suspendRefresh(obj)
            cleanup = obj.suspendEntityTableRefresh();
        end

        function setBusy(obj, isBusy, message)
            arguments
                obj
                isBusy (1,1) logical
                message (1,1) string = "Working..."
            end

            if isempty(obj.EntityTableView) || ~isvalid(obj.EntityTableView) || ...
                    ~ismethod(obj.EntityTableView, 'setBusy')
                return
            end

            obj.EntityTableView.setBusy(isBusy, message);
        end

        function refreshColumnModel(obj, syncTable)
            if nargin < 2
                syncTable = true;
            end

            obj.ColumnModel.updateColumnEditableState()
            if syncTable
                obj.syncEntityTableColumnSpecs()
            end
        end

        function resetTable(obj, resetView)
            if nargin < 2
                resetView = true;
            end

            obj.MetaTable = table.empty;

            if resetView
                obj.refreshTable(table.empty, true)
            end
        end

        function resetColumnFilters(obj)
            obj.clearUserColumnFilters()
        end

        function updateCells(obj, rowIdxData, colIdxData, newData)
            obj.MetaTableCell(rowIdxData, colIdxData) = newData;
            obj.updateTableView([], false)
            drawnow
        end

        function updateTableRow(obj, rowIdxData, tableRowData)
            colIdx = 1:size(tableRowData, 2);
            if isa(tableRowData, 'table')
                tableRowData = table2cell(tableRowData);
            end
            obj.updateCells(rowIdxData, colIdx, tableRowData)
        end

        function updateFormattedTableColumnData(obj, columnName, columnData)
            columnIndex = find(strcmp(obj.MetaTable.Properties.VariableNames, columnName));
            obj.MetaTableCell(:, columnIndex) = table2cell(columnData);
        end

        function appendTableRow(~, ~)
        end

        function updateVisibleRows(obj, rowInd)
            [numRows, ~] = size(obj.MetaTable);
            obj.ExternalFilterMap = false(numRows, 1);
            obj.ExternalFilterMap(rowInd) = true;
            obj.applySystemFilters()
            obj.notifyTableRowsUpdated()
        end

        function refreshTable(obj, newTable, flushTable, requestFocus)
            requireReset = isempty(obj.MetaTable) || obj.RequireReset;

            if nargin >= 2 && ~(isnumeric(newTable) && isempty(newTable))
                obj.MetaTable = newTable;
            end

            if nargin < 3 || isempty(flushTable)
                flushTable = requireReset;
            end
            if nargin < 4 || isempty(requestFocus)
                requestFocus = true;
            end

            if flushTable
                obj.DataFilterMap = [];
                obj.ColumnFilterActive = [];
                obj.ActiveColumnFilterNames = strings(1, 0);
                if ~isempty(obj.EntityTableView) && isvalid(obj.EntityTableView)
                    obj.EntityTableView.resetFilters()
                end
                if ~isempty(obj.MetaTable) && ~isempty(obj.ColumnFilter)
                    obj.ColumnFilter.onMetaTableChanged()
                end
                obj.RequireReset = false;
            elseif ~isempty(obj.ColumnFilter)
                obj.ColumnFilter.onMetaTableUpdated()
            end

            drawnow
            if ~isempty(obj.MetaTable)
                obj.updateMetaTableVariableAttributes()
                % EntityTable validates column specs against its current
                % data, so table refreshes must update data and specs in
                % the same operation.
                obj.updateTableView([], requestFocus)
            else
                obj.createEntityTable(table.empty, entitytable.ColumnSpec.empty(1, 0))
            end
        end

        function replaceTable(obj, newTable)
            obj.MetaTable = newTable;
            if ~isempty(obj.ColumnFilter)
                obj.ColumnFilter.onMetaTableChanged()
            end
            obj.updateTableView()
        end

        function rowInd = getMetaTableRows(obj, rowIndDisplay)
            if isempty(rowIndDisplay)
                rowInd = [];
                return
            end

            displayRows = rowIndDisplay(rowIndDisplay > 0);
            allDisplayRows = obj.EntityTableView.getDisplayRowIndex();
            displayRows = displayRows(displayRows <= numel(allDisplayRows));
            rowInd = allDisplayRows(displayRows);

            if iscolumn(rowInd)
                rowInd = transpose(rowInd);
            end
        end

        function IND = getSelectedEntries(obj)
            if isempty(obj.EntityTableView) || ~isvalid(obj.EntityTableView)
                IND = [];
                return
            end

            IND = obj.EntityTableView.getSelectedRowKeys();
            IND = transpose(double(sort(unique(IND(:)))));
        end

        function setSelectedEntries(obj, IND, ~)
            if isempty(obj.EntityTableView) || ~isvalid(obj.EntityTableView)
                return
            end

            if isempty(IND)
                obj.EntityTableView.setSelectedRowKeys([])
            else
                obj.EntityTableView.setSelectedRowKeys(IND(:))
            end
        end

        function [columnNames, variableNames] = getColumnNames(obj, columnIndices)
            if nargin < 2
                columnIndices = [];
            end

            [columnNames, variableNames] = obj.ColumnModel.getColumnNames();
            if ~isempty(columnIndices)
                columnNames = columnNames(columnIndices);
                variableNames = variableNames(columnIndices);
            end
            if isscalar(columnNames) && iscell(columnNames)
                columnNames = columnNames{1};
                variableNames = variableNames{1};
            end
        end

        function focusTable(obj)
            if ~isempty(obj.HTable) && isvalid(obj.HTable)
                try
                    uifocus(obj.HTable)
                catch
                    hFigure = ancestor(obj.HTable, 'figure');
                    if ~isempty(hFigure) && isvalid(hFigure)
                        figure(hFigure)
                    end
                end
            end
        end

        function setTableTooltip(obj, tooltipText)
            if ~isempty(obj.HTable) && isvalid(obj.HTable) && isprop(obj.HTable, 'Tooltip')
                obj.HTable.Tooltip = tooltipText;
            end
        end

        function setKeyPressFcn(obj, callback)
            if ~isempty(obj.HTable) && isvalid(obj.HTable) && isprop(obj.HTable, 'KeyPressFcn')
                obj.HTable.KeyPressFcn = callback;
            end
        end

        function listenerHandle = addMouseMotionCallback(obj, callback)
            obj.MouseMotionCallback = callback;
            listenerHandle = [];
        end

        function flushColumnSettings(obj)
            obj.captureColumnWidths()
            obj.captureColumnOrder()
        end

        function n = getDisplayedRowCount(obj)
            n = numel(obj.DisplayedRows);
        end

        function n = getSelectedRowCount(obj)
            n = numel(obj.getSelectedEntries());
        end

        function updateTableView(obj, ~, requestFocus)
            if isempty(obj.ColumnModel) || isempty(obj.MetaTableCell)
                return
            end
            if nargin < 3 || isempty(requestFocus)
                requestFocus = true;
            end

            dataTable = obj.buildEntityTableData();
            columnSpecs = obj.buildEntityTableColumnSpecs();
            refreshCleanup = obj.suspendEntityTableRefresh();
            obj.createOrUpdateEntityTable(dataTable, columnSpecs)
            obj.applySystemFilters()

            obj.HTable.Visible = 'on';
            obj.syncColumnFormatAndEditable()
            delete(refreshCleanup)

            if requestFocus
                obj.focusTable()
            end

            drawnow
        end

        function updateColumnLayout(obj)
            if isempty(obj.ColumnModel)
                return
            end
            if isempty(obj.MetaTable)
                obj.createEntityTable(table.empty, entitytable.ColumnSpec.empty(1, 0))
                drawnow
                return
            end

            obj.syncEntityTableColumnSpecs()
        end

        function updateColumnLabelFilterIndicator(obj, filterActive)
            if nargin < 2
                if isempty(obj.ColumnFilter)
                    filterActive = [];
                else
                    filterActive = obj.ColumnFilter.isColumnFilterActive;
                end
            end

            obj.ColumnFilterActive = filterActive;
            obj.syncEntityTableColumnSpecs()
        end

        function popup = openFilterControl(obj, dataColumnIndex)
            popup = obj.openFilterPopupForDataColumn(dataColumnIndex);
        end

        function popup = openFilterPopupForDataColumn(obj, dataColumnIndex)
            popup = [];
            if isempty(obj.EntityTableView) || ~isvalid(obj.EntityTableView) || isempty(obj.MetaTable)
                return
            end
            if dataColumnIndex < 1 || dataColumnIndex > numel(obj.MetaTableVariableNames)
                return
            end

            variableName = string(obj.MetaTableVariableNames{dataColumnIndex});
            popup = obj.EntityTableView.showFilterPopup(variableName);
        end

        function clearUserColumnFilters(obj)
            obj.ActiveColumnFilterNames = strings(1, 0);
            obj.updateColumnFilterState()

            if ~isempty(obj.EntityTableView) && isvalid(obj.EntityTableView)
                obj.EntityTableView.resetFilters()
                obj.applySystemFilters()
            else
                obj.notifyTableRowsUpdated()
            end
        end

        function updateColumnEditable(obj)
            obj.syncEntityTableColumnSpecs()
            obj.syncColumnFormatAndEditable()
        end

        function C = getDisplayTableData(obj, rowIndices, columnIndices)
            C = obj.MetaTableCell(rowIndices, columnIndices);
            C = cellfun(@obj.normalizeDisplayValue, C, 'UniformOutput', false);
        end

        function changeColumnNames(obj, newNames)
            if ~isempty(obj.HTable) && isvalid(obj.HTable) && ...
                    isprop(obj.HTable, 'ColumnName')
                obj.HTable.ColumnName = newNames;
            end
        end

        function changeColumnWidths(obj, newWidths)
            if ~isempty(obj.HTable) && isvalid(obj.HTable)
                obj.setTableColumnWidths(num2cell(newWidths));
                obj.fitColumnsToTableWidth()
            end
        end

        function fitColumnsToTableWidth(obj)
            if ~obj.AutoFitColumnWidths || isempty(obj.HTable) || ~isvalid(obj.HTable)
                return
            end

            columnWidths = obj.getBaseVisibleColumnWidths();
            if isempty(columnWidths)
                return
            end

            tablePosition = obj.getTablePixelPosition();
            availableWidth = floor(tablePosition(3) - obj.getRowHeaderWidth() - 2);
            if availableWidth <= 0
                return
            end

            currentWidth = sum(columnWidths);
            if currentWidth <= 0
                return
            end
            if currentWidth >= availableWidth
                obj.AutoAppliedColumnWidths = [];
                obj.setTableColumnWidths(num2cell(columnWidths));
                return
            end

            fittedWidths = floor(columnWidths .* availableWidth ./ currentWidth);
            fittedWidths(end) = fittedWidths(end) + availableWidth - sum(fittedWidths);
            obj.AutoAppliedColumnWidths = fittedWidths;
            obj.setTableColumnWidths(num2cell(fittedWidths));
        end
    end

    methods (Access = private)
        function tf = shouldUseHtmlTable(~)
            tf = false;
            try
                tf = logical(getpref('nansen', 'useHtmlTable', false));
            catch
            end
            tf = tf && exist('entitytable.backend.HtmlBackend', 'class') == 8;
        end

        function tableView = createTableView(obj, parent, dataTable, options)
            arguments
                obj
                parent
                dataTable table
                options.RowKey = []
                options.ColumnSpecs = []
                options.SelectionMode (1,1) string = "multiple"
            end

            backend = "uitable";
            if obj.UseHtmlTable
                backend = "html";
            end

            tableView = entitytable.EntityTableView(parent, dataTable, ...
                RowKey=options.RowKey, ...
                ColumnSpecs=options.ColumnSpecs, ...
                SelectionMode=options.SelectionMode, ...
                Backend=backend, ...
                Theme=obj.Theme);
        end

        function applyFigureTheme(obj, parent)
            if isempty(parent) || strlength(obj.Theme) == 0
                return
            end

            hFigure = ancestor(parent, 'figure');
            if isempty(hFigure) || ~isvalid(hFigure) || ~isprop(hFigure, 'Theme')
                return
            end

            hFigure.Theme = obj.Theme;
            if isprop(hFigure, 'ToolBar')
                hFigure.ToolBar = 'none';
            end
        end

        function cleanup = suspendEntityTableRefresh(obj)
            cleanup = onCleanup(@() []);
            if isempty(obj.EntityTableView) || ...
                    ~isvalid(obj.EntityTableView) || ...
                    ~ismethod(obj.EntityTableView, 'suspendRefresh')
                return
            end

            cleanup = obj.EntityTableView.suspendRefresh();
        end

        function parseInputs(obj, listOfArgs)
            [nvPairs, remainingArgs] = utility.getnvpairs(listOfArgs);

            for i = 1:2:numel(nvPairs)
                if isprop(obj, nvPairs{i})
                    obj.(nvPairs{i}) = nvPairs{i+1};
                end
            end

            if isempty(remainingArgs)
                return
            end

            if isgraphics(remainingArgs{1})
                obj.Parent = remainingArgs{1};
                remainingArgs = remainingArgs(2:end);
            end

            if isempty(remainingArgs)
                return
            end

            if obj.isValidTableClass(remainingArgs{1})
                obj.MetaTable = remainingArgs{1};
            end
        end

        function createEntityTable(obj, dataTable, columnSpecs)
            if isempty(obj.Parent)
                obj.Parent = uifigure(...
                    'Name', 'NANSEN Metadata Table', ...
                    'Visible', 'on');
                obj.applyFigureTheme(obj.Parent)
            end

            tableLayout = obj.captureTableLayout();
            obj.deleteEntityTableListeners()
            if ~isempty(obj.EntityTableView) && isvalid(obj.EntityTableView)
                delete(obj.EntityTableView)
            end

            if isempty(dataTable)
                placeholderTable = table(strings(0, 1), 'VariableNames', {'Empty'});
                placeholderSpec = entitytable.ColumnSpec("Empty", ...
                    DisplayName="", Visible=true, Width=100, Order=1);
                obj.EntityTableView = obj.createTableView(obj.Parent, ...
                    placeholderTable, ColumnSpecs=placeholderSpec, ...
                    SelectionMode="multiple");
            else
                obj.EntityTableView = obj.createTableView(obj.Parent, ...
                    dataTable, RowKey=obj.RowKeyVariableName, ...
                    ColumnSpecs=columnSpecs, SelectionMode="multiple");
            end

            obj.HTable = obj.EntityTableView.getComponent();
            obj.applyTableProperties()
            obj.restoreTableLayout(tableLayout)
            obj.attachEntityTableListeners()
            obj.syncEntityTableContextMenus()
        end

        function createOrUpdateEntityTable(obj, dataTable, columnSpecs)
            needsCreate = isempty(obj.EntityTableView) || ~isvalid(obj.EntityTableView);
            schemaChanged = false;
            if ~needsCreate
                oldNames = string(obj.EntityTableView.Data.Properties.VariableNames);
                newNames = string(dataTable.Properties.VariableNames);
                schemaChanged = ~isequal(oldNames, newNames);
                needsCreate = schemaChanged && ...
                    ~(obj.UseHtmlTable && ...
                    ismethod(obj.EntityTableView, 'setDataAndColumnSpecs'));
            end

            selectedEntries = obj.getSelectedEntries();
            userFilterSpecs = obj.captureUserFilterSpecs();
            if needsCreate
                obj.createEntityTable(dataTable, columnSpecs)
            elseif obj.UseHtmlTable && ...
                    ismethod(obj.EntityTableView, 'setDataAndColumnSpecs')
                tableLayout = obj.captureTableLayout();
                obj.EntityTableView.setDataAndColumnSpecs(dataTable, ...
                    obj.RowKeyVariableName, columnSpecs, ...
                    ResetInteractionState=schemaChanged);
                obj.HTable = obj.EntityTableView.getComponent();
                obj.applyTableProperties()
                obj.restoreTableLayout(tableLayout)
                obj.syncEntityTableContextMenus()
            else
                tableLayout = obj.captureTableLayout();
                obj.EntityTableView.ColumnSpecs = columnSpecs;
                obj.EntityTableView.setData(dataTable, obj.RowKeyVariableName);
                obj.HTable = obj.EntityTableView.getComponent();
                obj.applyTableProperties()
                obj.restoreTableLayout(tableLayout)
                obj.syncEntityTableContextMenus()
            end

            if ~isempty(selectedEntries)
                obj.setSelectedEntries(selectedEntries)
            end
            obj.restoreUserFilterSpecs(userFilterSpecs)
        end

        function filterSpecs = captureUserFilterSpecs(obj)
            arguments
                obj
            end

            filterSpecs = struct("VariableName", cell(1, 0), "FilterSpec", cell(1, 0));
            if isempty(obj.EntityTableView) || ~isvalid(obj.EntityTableView)
                return
            end

            variableNames = obj.ActiveColumnFilterNames;
            for i = 1:numel(variableNames)
                variableName = variableNames(i);
                if obj.isSystemFilterVariable(variableName)
                    continue
                end

                filterSpec = obj.EntityTableView.getFilterSpec(variableName);
                if isempty(filterSpec)
                    continue
                end

                filterSpecs(end+1).VariableName = variableName; %#ok<AGROW>
                filterSpecs(end).FilterSpec = filterSpec;
            end
        end

        function restoreUserFilterSpecs(obj, filterSpecs)
            arguments
                obj
                filterSpecs (1,:) struct
            end

            if isempty(filterSpecs) || isempty(obj.EntityTableView) || ~isvalid(obj.EntityTableView)
                return
            end

            tableVariableNames = string(obj.MetaTableVariableNames);
            restoredVariableNames = strings(1, 0);
            for i = 1:numel(filterSpecs)
                variableName = string(filterSpecs(i).VariableName);
                if ~any(tableVariableNames == variableName)
                    continue
                end

                obj.EntityTableView.setFilter(variableName, filterSpecs(i).FilterSpec)
                restoredVariableNames(end+1) = variableName; %#ok<AGROW>
            end

            obj.ActiveColumnFilterNames = unique(restoredVariableNames, 'stable');
            obj.updateColumnFilterState()
        end

        function applyTableProperties(obj)
            if isempty(obj.HTable) || ~isvalid(obj.HTable)
                return
            end

            obj.HTable.Tag = 'MetaTable';
            if isprop(obj.HTable, 'FontSize')
                obj.HTable.FontSize = obj.TableFontSize;
            end
            if isprop(obj.HTable, 'FontName')
                obj.HTable.FontName = 'avenir next';
            end
            if isprop(obj.HTable, 'Units')
                obj.HTable.Units = 'normalized';
            end
            if isprop(obj.HTable, 'Position')
                obj.HTable.Position = obj.getInitialTablePosition();
            end
            if isprop(obj.HTable, 'Visible')
                obj.HTable.Visible = 'off';
            end
            if isprop(obj.HTable, 'SizeChangedFcn')
                obj.HTable.SizeChangedFcn = @(~, ~) obj.fitColumnsToTableWidth();
            end
            obj.configureColumnRearranging()
            obj.attachColumnWidthListener()
            obj.setKeyPressFcn(obj.KeyPressCallback)
        end

        function tableLayout = captureTableLayout(obj)
            tableLayout = struct('Units', [], 'Position', []);
            if isempty(obj.HTable) || ~isvalid(obj.HTable)
                return
            end

            if isprop(obj.HTable, 'Units')
                tableLayout.Units = obj.HTable.Units;
            end
            if isprop(obj.HTable, 'Position')
                tableLayout.Position = obj.HTable.Position;
            end
        end

        function restoreTableLayout(obj, tableLayout)
            if isempty(obj.HTable) || ~isvalid(obj.HTable)
                return
            end

            if ~isempty(tableLayout.Units) && isprop(obj.HTable, 'Units')
                obj.HTable.Units = tableLayout.Units;
            end
            if ~isempty(tableLayout.Position) && isprop(obj.HTable, 'Position')
                obj.HTable.Position = tableLayout.Position;
            end
        end

        function width = getRowHeaderWidth(obj)
            width = 0;
            try
                if isprop(obj.HTable, 'RowName') && ~isempty(obj.HTable.RowName)
                    width = 48;
                end
            catch
            end
        end

        function tablePosition = getTablePixelPosition(obj)
            if isempty(obj.HTable) || ~isvalid(obj.HTable)
                tablePosition = [0 0 0 0];
            elseif isprop(obj.HTable, 'Units')
                tablePosition = getpixelposition(obj.HTable, true);
            elseif isprop(obj.HTable, 'Position')
                tablePosition = obj.HTable.Position;
            else
                tablePosition = [0 0 0 0];
            end
        end

        function tablePosition = getInitialTablePosition(obj)
            if isprop(obj.HTable, 'Units')
                tablePosition = [0 0 1 1];
                return
            end

            tablePosition = [0 0 1 1];
            try
                tablePosition = obj.getParentContentPixelPosition();
            catch
            end
        end

        function position = getParentContentPixelPosition(obj)
            parent = obj.HTable.Parent;
            if isa(parent, 'matlab.ui.container.Tab')
                position = uim.utility.getContentPixelPosition(parent);
            elseif isprop(parent, 'Position')
                position = [0, 0, parent.Position(3:4)];
            else
                position = getpixelposition(parent);
                position(1:2) = [0, 0];
            end

            position(3:4) = max(1, position(3:4));
        end

        function columnWidths = getBaseVisibleColumnWidths(obj)
            columnWidths = [];
            if ~isempty(obj.ColumnModel) && isvalid(obj.ColumnModel)
                columnWidths = obj.ColumnModel.getColumnWidths();
                columnWidths = obj.normalizeColumnWidths(columnWidths);
            end

            if isempty(columnWidths)
                if ismethod(obj.EntityTableView, 'getColumnWidths')
                    columnWidths = obj.EntityTableView.getColumnWidths();
                elseif isprop(obj.HTable, 'ColumnWidth')
                    columnWidths = obj.normalizeColumnWidths(obj.HTable.ColumnWidth);
                end
                columnWidths = obj.normalizeColumnWidths(columnWidths);
            end
        end

        function configureColumnRearranging(obj)
            if isempty(obj.HTable) || ~isvalid(obj.HTable)
                return
            end

            if isprop(obj.HTable, 'ColumnRearrangeable')
                obj.HTable.ColumnRearrangeable = true;
            end
            if isprop(obj.HTable, 'DisplayDataChangedFcn')
                obj.HTable.DisplayDataChangedFcn = ...
                    @(src, evt) obj.onModernDisplayDataChanged(src, evt);
            end
        end

        function attachColumnWidthListener(obj)
            obj.deleteColumnWidthListener()
            if isempty(obj.HTable) || ~isvalid(obj.HTable)
                return
            end
            if ~isprop(obj.HTable, 'ColumnWidth')
                return
            end

            obj.ColumnWidthChangedListener = addlistener(obj.HTable, ...
                'ColumnWidth', 'PostSet', @(~, ~) obj.onTableColumnWidthChanged());
        end

        function deleteColumnWidthListener(obj)
            if ~isempty(obj.ColumnWidthChangedListener)
                delete(obj.ColumnWidthChangedListener)
                obj.ColumnWidthChangedListener = [];
            end
        end

        function setTableColumnWidths(obj, columnWidths)
            if isempty(obj.HTable) || ~isvalid(obj.HTable)
                return
            end

            obj.IsApplyingColumnWidths = true;
            cleanup = onCleanup(@() obj.finishApplyingColumnWidths());
            if ismethod(obj.EntityTableView, 'setColumnWidths')
                obj.EntityTableView.setColumnWidths(columnWidths);
            elseif isprop(obj.HTable, 'ColumnWidth')
                obj.HTable.ColumnWidth = columnWidths;
            end
        end

        function finishApplyingColumnWidths(obj)
            obj.IsApplyingColumnWidths = false;
        end

        function applyHtmlInterpreterStyles(obj)
            obj.removeHtmlInterpreterStyles()

            if isempty(obj.HTable) || ~isvalid(obj.HTable) || ...
                    isempty(obj.ColumnModel) || isempty(obj.MetaTableCell)
                return
            end
            if ~isprop(obj.HTable, 'StyleConfigurations')
                return
            end

            visibleColumns = obj.ColumnModel.getColumnIndices();
            htmlColumns = false(1, numel(visibleColumns));
            for i = 1:numel(visibleColumns)
                htmlColumns(i) = obj.isHtmlFormattedColumn(visibleColumns(i));
            end

            if ~any(htmlColumns)
                return
            end

            htmlStyle = uistyle('Interpreter', 'html');
            addStyle(obj.HTable, htmlStyle, 'column', find(htmlColumns))
            obj.HtmlStyleConfigurationRows = height(obj.HTable.StyleConfigurations);
        end

        function removeHtmlInterpreterStyles(obj)
            if isempty(obj.HtmlStyleConfigurationRows) || ...
                    isempty(obj.HTable) || ~isvalid(obj.HTable) || ...
                    ~isprop(obj.HTable, 'StyleConfigurations')
                obj.HtmlStyleConfigurationRows = [];
                return
            end

            try
                styleRows = obj.HtmlStyleConfigurationRows;
                styleRows = styleRows(styleRows <= height(obj.HTable.StyleConfigurations));
                if ~isempty(styleRows)
                    removeStyle(obj.HTable, styleRows)
                end
            catch
            end

            obj.HtmlStyleConfigurationRows = [];
        end

        function tf = isHtmlFormattedColumn(obj, columnIndex)
            columnValues = obj.MetaTableCell(:, columnIndex);
            tf = any(cellfun(@obj.isHtmlFormattedValue, columnValues));
        end

        function tf = isHtmlFormattedValue(~, value)
            if isstring(value) && isscalar(value)
                value = char(value);
            end

            tf = ischar(value) && startsWith(strtrim(value), '<html', ...
                'IgnoreCase', true);
        end

        function attachEntityTableListeners(obj)
            obj.deleteEntityTableListeners()
            obj.EntityTableListeners = [ ...
                addlistener(obj.EntityTableView, 'SelectionChanged', @obj.onEntitySelectionChanged), ...
                addlistener(obj.EntityTableView, 'CellEdited', @obj.onEntityCellEdited), ...
                addlistener(obj.EntityTableView, 'CellActivated', @obj.onEntityCellActivated), ...
                addlistener(obj.EntityTableView, 'FilterChanged', @obj.onEntityFilterChanged), ...
                addlistener(obj.EntityTableView, 'ColumnLayoutChanged', @obj.onEntityColumnLayoutChanged), ...
                addlistener(obj.EntityTableView, 'ContextMenuOpening', @obj.onEntityContextMenuOpening) ...
                ];
        end

        function deleteEntityTableListeners(obj)
            if isempty(obj.EntityTableListeners)
                return
            end

            for i = 1:numel(obj.EntityTableListeners)
                if isvalid(obj.EntityTableListeners(i))
                    delete(obj.EntityTableListeners(i))
                end
            end
            obj.EntityTableListeners = [];
        end

        function syncEntityTableContextMenus(obj)
            if isempty(obj.EntityTableView) || ~isvalid(obj.EntityTableView)
                return
            end

            obj.EntityTableView.TableContextMenu = obj.TableContextMenu;
            obj.EntityTableView.ColumnHeaderContextMenu = obj.ColumnContextMenu;
        end

        function createColumnContextMenu(obj)
        %createColumnContextMenu Create the NANSEN column header menu.

            if ~isempty(obj.ColumnContextMenu) && isvalid(obj.ColumnContextMenu)
                return
            end

            hFigure = ancestor(obj.Parent, 'figure');
            if isempty(hFigure) && ~isempty(obj.HTable) && isvalid(obj.HTable)
                hFigure = ancestor(obj.HTable, 'figure');
            end
            if isempty(hFigure)
                return
            end

            obj.ColumnContextMenu = uicontextmenu(hFigure);

            obj.createMenuItem(obj.ColumnContextMenu, 'Sort A-Z', 'Sort Ascend');
            obj.createMenuItem(obj.ColumnContextMenu, 'Sort Z-A', 'Sort Descend');
            obj.createMenuItem(obj.ColumnContextMenu, 'Reset Filters', 'Reset Filters', true);
            obj.createMenuItem(obj.ColumnContextMenu, 'Hide this column', 'Hide Column', true);
            obj.createMenuItem(obj.ColumnContextMenu, ...
                'Set column width...', 'Set Column Width');

            hTmp = obj.createMenuItem(obj.ColumnContextMenu, ...
                'Column settings...', 'ColumnSettings', true);
            obj.setMenuCallback(hTmp, @(~, ~) obj.ColumnModel.editSettings);

            hTmp = obj.createMenuItem(obj.ColumnContextMenu, ...
                'Update column data', 'Update Column', true);
            obj.createMenuItem(hTmp, 'Update selected rows', 'Update selected rows');
            obj.createMenuItem(hTmp, 'Update all rows', 'Update all rows');
            obj.createMenuItem(hTmp, 'Reset selected rows', 'Reset selected rows', true);
            obj.createMenuItem(hTmp, 'Reset all rows', 'Reset all rows');
            obj.createMenuItem(hTmp, 'Edit tablevar function', ...
                'Edit tablevar function', true);

            obj.createMenuItem(obj.ColumnContextMenu, ...
                'Delete this column', 'Delete Column');

            obj.syncEntityTableContextMenus()
        end

        function hMenu = createMenuItem(obj, parent, text, tag, separator)
            if nargin < 5
                separator = false;
            end

            hMenu = uimenu(parent);
            obj.setMenuText(hMenu, text);
            hMenu.Tag = tag;
            if separator && isprop(hMenu, 'Separator')
                hMenu.Separator = 'on';
            end
        end

        function onEntityContextMenuOpening(obj, ~, evt)
            if ~isfield(evt.Context, 'Region') || string(evt.Context.Region) ~= "header"
                return
            end

            obj.configureColumnContextMenu(evt.DisplayColumn, evt.VariableName)
        end

        function configureColumnContextMenu(obj, displayColumn, variableName)
            if isempty(obj.ColumnModel) || isempty(obj.MetaTableVariableAttributes)
                return
            end
            if isempty(displayColumn) || displayColumn < 1
                return
            end

            [~, visibleVariableNames] = obj.ColumnModel.getColumnNames();
            visibleVariableNames = string(visibleVariableNames);
            if displayColumn > numel(visibleVariableNames)
                return
            end

            if isempty(variableName)
                currentColumnName = visibleVariableNames(displayColumn);
            else
                currentColumnName = string(variableName);
            end

            columnNumber = find(visibleVariableNames == currentColumnName, 1, 'first');
            if isempty(columnNumber)
                columnNumber = displayColumn;
            end

            visibleColumns = obj.ColumnModel.getColumnIndices();
            columnFormat = obj.getColumnFormatForVisibleColumn(visibleColumns, columnNumber);
            varAttr = obj.getVariableAttribute(currentColumnName);

            hMenu = obj.EntityTableView.getUnifiedContextMenu();
            obj.configureColumnContextMenuItems(hMenu, columnNumber, ...
                currentColumnName, columnFormat, varAttr);
        end

        function columnFormat = getColumnFormatForVisibleColumn(obj, visibleColumns, columnNumber)
            columnFormat = 'char';
            if isempty(visibleColumns) || columnNumber > numel(visibleColumns)
                return
            end

            columnFormats = obj.getVisibleColumnFormat(visibleColumns);
            if columnNumber <= numel(columnFormats)
                columnFormat = columnFormats{columnNumber};
            end
        end

        function varAttr = getVariableAttribute(obj, variableName)
            attributeNames = string({obj.MetaTableVariableAttributes.Name});
            tableTypes = string({obj.MetaTableVariableAttributes.TableType});
            isMatch = attributeNames == string(variableName) & ...
                strcmpi(tableTypes, obj.MetaTableType);

            if any(isMatch)
                varAttr = obj.MetaTableVariableAttributes(find(isMatch, 1, 'first'));
            else
                error('Variable attributes does not exist. This is unexpected.')
            end
        end

        function configureColumnContextMenuItems(obj, hMenu, columnNumber, ...
                currentColumnName, columnFormat, varAttr)
            if isempty(hMenu) || ~isvalid(hMenu)
                return
            end

            obj.configureSortMenuItem(hMenu, 'Sort Ascend', columnFormat, ...
                columnNumber, 'ascend');
            obj.configureSortMenuItem(hMenu, 'Sort Descend', columnFormat, ...
                columnNumber, 'descend');
            obj.setTaggedMenuCallback(hMenu, 'Reset Filters', ...
                @(~, ~) obj.resetColumnFilters());
            obj.setTaggedMenuCallback(hMenu, 'Hide Column', ...
                @(~, ~) obj.hideColumn(columnNumber));
            obj.setTaggedMenuCallback(hMenu, 'Set Column Width', ...
                @(~, ~) obj.promptColumnWidth(columnNumber));
            obj.configureUpdateColumnMenu(hMenu, currentColumnName, varAttr);
            obj.configureDeleteColumnMenu(hMenu, currentColumnName, varAttr);
        end

        function configureSortMenuItem(obj, hMenu, tag, columnFormat, ...
                columnNumber, sortDirection)
            hItem = obj.findTaggedMenuItem(hMenu, tag);
            if isempty(hItem)
                return
            end

            if strcmp(sortDirection, 'ascend')
                obj.setMenuText(hItem, 'Sort A-Z');
            else
                obj.setMenuText(hItem, 'Sort Z-A');
            end

            if ischar(columnFormat) || (isstring(columnFormat) && isscalar(columnFormat))
                columnFormat = char(columnFormat);
                switch columnFormat
                    case 'numeric'
                        if strcmp(sortDirection, 'ascend')
                            obj.setMenuText(hItem, 'Sort low-high');
                        else
                            obj.setMenuText(hItem, 'Sort high-low');
                        end
                    case 'logical'
                        if strcmp(sortDirection, 'ascend')
                            obj.setMenuText(hItem, 'Sort false-true');
                        else
                            obj.setMenuText(hItem, 'Sort true-false');
                        end
                end
            end

            obj.setMenuCallback(hItem, ...
                @(~, ~) obj.sortColumn(columnNumber, sortDirection));
        end

        function configureUpdateColumnMenu(obj, hMenu, currentColumnName, varAttr)
            hItem = obj.findTaggedMenuItem(hMenu, 'Update Column');
            if isempty(hItem)
                return
            end

            hasUpdateFunction = isfield(varAttr, 'HasUpdateFunction') && ...
                varAttr.HasUpdateFunction;
            if hasUpdateFunction
                hItem.Enable = 'on';
                if ~isempty(obj.UpdateColumnFcn)
                    obj.setTaggedMenuCallback(hItem, 'Update selected rows', ...
                        @(~, ~) obj.UpdateColumnFcn(currentColumnName, 'SelectedRows'));
                    obj.setTaggedMenuCallback(hItem, 'Update all rows', ...
                        @(~, ~) obj.UpdateColumnFcn(currentColumnName, 'AllRows'));
                    obj.setTaggedMenuCallback(hItem, 'Reset selected rows', ...
                        @(~, ~) obj.ResetColumnFcn(currentColumnName, 'SelectedRows'));
                    obj.setTaggedMenuCallback(hItem, 'Reset all rows', ...
                        @(~, ~) obj.ResetColumnFcn(currentColumnName, 'AllRows'));
                    obj.setTaggedMenuCallback(hItem, 'Edit tablevar function', ...
                        @(~, ~) obj.EditColumnFcn(currentColumnName));
                end
            else
                hItem.Enable = 'off';
            end
        end

        function configureDeleteColumnMenu(obj, hMenu, currentColumnName, varAttr)
            hItem = obj.findTaggedMenuItem(hMenu, 'Delete Column');
            if isempty(hItem)
                return
            end

            isCustom = isfield(varAttr, 'IsCustom') && varAttr.IsCustom;
            if isCustom
                hItem.Enable = 'on';
                if ~isempty(obj.DeleteColumnFcn)
                    obj.setMenuCallback(hItem, ...
                        @(~, ~) obj.DeleteColumnFcn(currentColumnName));
                end
            else
                hItem.Enable = 'off';
            end
        end

        function setTaggedMenuCallback(obj, parent, tag, callbackFcn)
            hItem = obj.findTaggedMenuItem(parent, tag);
            if isempty(hItem)
                return
            end
            obj.setMenuCallback(hItem, callbackFcn);
        end

        function hItem = findTaggedMenuItem(~, parent, tag)
            hItem = findobj(parent, 'Tag', tag);
            if isempty(hItem)
                return
            end
            hItem = hItem(1);
        end

        function setMenuText(~, hItem, text)
            if isprop(hItem, 'Text')
                hItem.Text = text;
            elseif isprop(hItem, 'Label')
                hItem.Label = text;
            end
        end

        function setMenuCallback(~, hItem, callbackFcn)
            if isprop(hItem, 'Callback')
                hItem.Callback = callbackFcn;
            end
            if isprop(hItem, 'MenuSelectedFcn')
                hItem.MenuSelectedFcn = callbackFcn;
            end
        end

        function sortColumn(obj, columnNumber, sortDirection)
        %sortColumn Sort column in specified direction.

            visibleColumns = obj.ColumnModel.getColumnIndices();
            if columnNumber < 1 || columnNumber > numel(visibleColumns)
                return
            end

            dataColumnIndex = visibleColumns(columnNumber);
            variableName = string(obj.MetaTableVariableNames{dataColumnIndex});
            obj.EntityTableView.sortByColumn(variableName, string(sortDirection))
            obj.notifyTableRowsUpdated()
        end

        function hideColumn(obj, columnNumber)
            obj.ColumnModel.hideColumn(columnNumber);
        end

        function promptColumnWidth(obj, columnNumber)
            columnWidths = obj.getCurrentVisibleColumnWidths();
            if isempty(columnWidths) || columnNumber > numel(columnWidths)
                return
            end

            currentWidth = round(columnWidths(columnNumber));
            answer = inputdlg( ...
                {'Column width (pixels):'}, ...
                'Set Column Width', [1 35], {num2str(currentWidth)});
            if isempty(answer)
                return
            end

            newWidth = str2double(answer{1});
            if isnan(newWidth) || ~isfinite(newWidth) || newWidth <= 0
                return
            end

            columnWidths(columnNumber) = max(20, round(newWidth));
            obj.AutoAppliedColumnWidths = [];
            obj.ColumnModel.setColumnWidths(columnWidths);
            obj.setTableColumnWidths(num2cell(columnWidths));
        end

        function syncEntityTableColumnSpecs(obj)
            if isempty(obj.EntityTableView) || ~isvalid(obj.EntityTableView) || isempty(obj.MetaTable)
                return
            end

            obj.EntityTableView.ColumnSpecs = obj.buildEntityTableColumnSpecs();
            obj.syncColumnFormatAndEditable()
        end

        function syncColumnFormatAndEditable(obj)
            if isempty(obj.HTable) || ~isvalid(obj.HTable) || isempty(obj.MetaTable)
                return
            end

            visibleColumns = obj.ColumnModel.getColumnIndices();
            if isempty(visibleColumns)
                return
            end

            columnEditable = obj.getVisibleColumnEditable();
            columnFormat = obj.getVisibleColumnFormat(visibleColumns);
            if ismethod(obj.EntityTableView, 'setColumnFormatAndEditable')
                obj.EntityTableView.setColumnFormatAndEditable(columnFormat, columnEditable)
            else
                if isprop(obj.HTable, 'ColumnEditable')
                    obj.HTable.ColumnEditable = columnEditable;
                end
                if isprop(obj.HTable, 'ColumnFormat')
                    obj.HTable.ColumnFormat = columnFormat;
                end
            end
            obj.applyHtmlInterpreterStyles()
            obj.configureColumnRearranging()
            obj.fitColumnsToTableWidth()
        end

        function dataTable = buildEntityTableData(obj)
            if isempty(obj.MetaTable)
                dataTable = table.empty;
                return
            end

            dataTable = cell2table(obj.MetaTableCell, ...
                'VariableNames', obj.MetaTableVariableNames);
            dataTable.(obj.RowKeyVariableName) = (1:height(dataTable)).';
        end

        function columnSpecs = buildEntityTableColumnSpecs(obj)
            if isempty(obj.MetaTable)
                columnSpecs = entitytable.ColumnSpec.empty(1, 0);
                return
            end

            variableNames = string(obj.MetaTableVariableNames);
            visibleColumns = obj.ColumnModel.getColumnIndices();
            [columnLabels, visibleVariableNames] = obj.ColumnModel.getColumnNames();
            columnLabels = string(columnLabels);
            visibleVariableNames = string(visibleVariableNames);
            columnWidths = obj.ColumnModel.getColumnWidths();
            columnEditable = obj.getVisibleColumnEditable();

            columnSpecs = entitytable.ColumnSpec.empty(1, 0);
            for i = 1:numel(variableNames)
                visibleIdx = find(visibleColumns == i, 1, 'first');
                isVisible = ~isempty(visibleIdx);

                if isVisible
                    displayName = columnLabels(visibleIdx);
                    if obj.isColumnFilterActive(variableNames(i))
                        displayName = "* " + displayName;
                    end
                    width = columnWidths(visibleIdx);
                    isEditable = columnEditable(visibleIdx);
                    order = visibleIdx;
                else
                    nameIdx = find(visibleVariableNames == variableNames(i), 1, 'first');
                    if isempty(nameIdx)
                        displayName = variableNames(i);
                    else
                        displayName = columnLabels(nameIdx);
                    end
                    width = "auto";
                    isEditable = false;
                    order = numel(variableNames) + i;
                end

                columnSpecs(1, end+1) = entitytable.ColumnSpec(variableNames(i), ...
                    DisplayName=displayName, Visible=isVisible, Width=width, ...
                    Order=order, IsEditable=isEditable, ...
                    Options=obj.getOptionsForVariable(variableNames(i)), ...
                    TooltipFcn=obj.getTooltipFcnForVariable(variableNames(i)), ...
                    UserData=obj.getEntityTableColumnUserData(i)); %#ok<AGROW>
            end

            columnSpecs(1, end+1) = entitytable.ColumnSpec( ...
                string(obj.RowKeyVariableName), Visible=false, ...
                Width=1, Order=numel(variableNames) + 1);
        end

        function applySystemFilters(obj)
            if isempty(obj.EntityTableView) || ~isvalid(obj.EntityTableView) || isempty(obj.MetaTable)
                return
            end

            obj.applyExternalRowFilter()
            obj.applyIgnoredRowsFilter()
            obj.notifyTableRowsUpdated()
        end

        function applyExternalRowFilter(obj)
            if isempty(obj.ExternalFilterMap)
                obj.EntityTableView.clearFilter(obj.RowKeyVariableName)
                return
            end

            visibleRows = find(obj.ExternalFilterMap);
            obj.EntityTableView.setFilter(obj.RowKeyVariableName, ...
                entitytable.FilterSpec.setMembership(obj.RowKeyVariableName, visibleRows))
        end

        function applyIgnoredRowsFilter(obj)
            ignoreVariableName = obj.getIgnoreVariableName();
            if ignoreVariableName == ""
                return
            end

            if obj.ShowIgnoredEntries
                obj.EntityTableView.clearFilter(ignoreVariableName)
            else
                obj.EntityTableView.setFilter(ignoreVariableName, ...
                    entitytable.FilterSpec(ignoreVariableName, "custom", ...
                    Value=@(value) obj.isNotIgnoredValue(value)))
            end
        end

        function tf = isSystemFilterVariable(obj, variableName)
            variableName = string(variableName);
            tf = variableName == string(obj.RowKeyVariableName);
            ignoreVariableName = obj.getIgnoreVariableName();
            if ignoreVariableName ~= "" && variableName == ignoreVariableName && ~obj.ShowIgnoredEntries
                tf = true;
            end
        end

        function tf = isColumnFilterActive(obj, variableName)
            tf = any(obj.ActiveColumnFilterNames == string(variableName));
        end

        function setColumnFilterActive(obj, variableName, isActive)
            variableName = string(variableName);
            if variableName == "" || obj.isSystemFilterVariable(variableName)
                return
            end

            if isActive
                obj.ActiveColumnFilterNames = unique([obj.ActiveColumnFilterNames, variableName], 'stable');
            else
                obj.ActiveColumnFilterNames(obj.ActiveColumnFilterNames == variableName) = [];
            end

            obj.updateColumnFilterState()
        end

        function updateColumnFilterState(obj)
            variableNames = string(obj.MetaTableVariableNames);
            active = ismember(variableNames, obj.ActiveColumnFilterNames);

            obj.ColumnFilterActive = active(:);
            if ~isempty(obj.ColumnFilter) && isvalid(obj.ColumnFilter)
                obj.ColumnFilter.setActiveVariableNames(obj.ActiveColumnFilterNames)
            end

            obj.syncEntityTableColumnSpecs()
        end

        function variableName = getIgnoreVariableName(obj)
            variableNames = string(obj.MetaTableVariableNames);
            matchIdx = find(contains(lower(variableNames), 'ignore'), 1, 'first');
            if isempty(matchIdx)
                variableName = "";
            else
                variableName = variableNames(matchIdx);
            end
        end

        function tf = isNotIgnoredValue(~, value)
            if isempty(value)
                tf = true;
            elseif islogical(value)
                tf = ~value;
            else
                tf = ~strcmpi(string(value), "true");
            end
        end

        function editable = getVisibleColumnEditable(obj)
            visibleColumns = obj.ColumnModel.getColumnIndices();
            if isempty(visibleColumns)
                editable = [];
                return
            end

            editable = obj.ColumnModel.getColumnIsEditable;
            [~, variableNames] = obj.ColumnModel.getColumnNames();
            variableNames = string(variableNames);

            if ~isempty(obj.MetaTableVariableAttributes)
                attributeNames = string({obj.MetaTableVariableAttributes.Name});
                [isMatched, attributeIdx] = ismember(variableNames, attributeNames);

                isEditableAttribute = false(size(editable));
                if any(isMatched)
                    isEditableAttribute(isMatched) = ...
                        [obj.MetaTableVariableAttributes(attributeIdx(isMatched)).IsEditable];
                end
                editable = editable & isEditableAttribute;

                hasOptions = false(size(editable));
                if any(isMatched)
                    matchedAttributes = obj.MetaTableVariableAttributes(attributeIdx(isMatched));
                    hasOptions(isMatched) = [matchedAttributes.HasOptions] & ...
                        strcmpi({matchedAttributes.TableType}, obj.MetaTableType);
                end
                editable = editable | hasOptions;
            end

            columnNames = obj.ColumnModel.getColumnNames();
            if obj.AllowTableEdits
                editable(contains(lower(columnNames), 'ignore')) = true;
                editable(contains(lower(columnNames), 'description')) = true;
            else
                editable(:) = false;
            end
        end

        function columnFormat = getVisibleColumnFormat(obj, visibleColumns)
            columnFormat = repmat({'char'}, 1, numel(visibleColumns));
            if isempty(visibleColumns) || isempty(obj.MetaTableCell) || size(obj.MetaTableCell, 1) == 0
                return
            end

            C = obj.MetaTableCell(:, visibleColumns);
            firstRow = C(1, :);

            isNumeric = cellfun(@(value) isnumeric(value) && ...
                (isscalar(value) || isempty(value)), firstRow, 'UniformOutput', true);
            columnFormat(isNumeric) = {'numeric'};

            isLogical = cellfun(@(value) islogical(value) && ...
                (isscalar(value) || isempty(value)), firstRow, 'UniformOutput', true);
            columnFormat(isLogical) = {'logical'};

            if ~isempty(obj.MetaTable)
                T = obj.MetaTable(1, visibleColumns);
                isEnumeration = cellfun(@(value) isenum(value), table2cell(T), 'UniformOutput', true);
                for i = find(isEnumeration)
                    enumObject = T{1, i};
                    if iscell(enumObject)
                        enumObject = enumObject{1};
                    end
                    [~, enumNames] = enumeration(enumObject);
                    columnFormat{i} = enumNames;
                end

                isCategorical = cellfun(@(value) iscategorical(value), table2cell(T), 'UniformOutput', true);
                for i = find(isCategorical)
                    categoricalObject = T{1, i};
                    if iscell(categoricalObject)
                        categoricalObject = categoricalObject{1};
                    end
                    if isprotected(categoricalObject)
                        columnFormat{i} = categories(categoricalObject);
                    else
                        columnFormat{i} = cat(1, '<undefined>', categories(categoricalObject));
                    end
                end
            end

            [~, variableNames] = obj.ColumnModel.getColumnNames();
            variableNames = string(variableNames);
            for i = 1:numel(variableNames)
                options = obj.getOptionsForVariable(variableNames(i));
                if isempty(options)
                    continue
                end
                columnFormat{i} = obj.normalizeColumnOptions(options);
            end
        end

        function options = getOptionsForVariable(obj, variableName)
            options = [];
            if isempty(obj.MetaTableVariableAttributes)
                return
            end

            attributeNames = string({obj.MetaTableVariableAttributes.Name});
            tableTypes = string({obj.MetaTableVariableAttributes.TableType});
            hasOptions = [obj.MetaTableVariableAttributes.HasOptions];
            matchIdx = find(attributeNames == string(variableName) & ...
                strcmpi(tableTypes, obj.MetaTableType) & hasOptions, 1, 'first');

            if ~isempty(matchIdx)
                options = obj.MetaTableVariableAttributes(matchIdx).OptionsList;
            end
        end

        function tooltipFcn = getTooltipFcnForVariable(obj, variableName)
            tooltipFcn = [];
            if isempty(obj.MetaTableVariableAttributes)
                return
            end

            attributeNames = string({obj.MetaTableVariableAttributes.Name});
            tableTypes = string({obj.MetaTableVariableAttributes.TableType});
            matchIdx = find(attributeNames == string(variableName) & ...
                strcmpi(tableTypes, obj.MetaTableType), 1, 'first');
            if isempty(matchIdx)
                return
            end

            varAttr = obj.MetaTableVariableAttributes(matchIdx);
            hasRendererFunction = isfield(varAttr, 'HasRendererFunction') && ...
                varAttr.HasRendererFunction;
            hasClassName = isfield(varAttr, 'ClassName') && ~isempty(varAttr.ClassName);
            if hasRendererFunction && hasClassName
                className = varAttr.ClassName;
                tooltipFcn = @(value, ~) obj.getTableVariableTooltip(className, value);
            end
        end

        function userData = getEntityTableColumnUserData(obj, columnIndex)
            userData = struct();
            if obj.UseHtmlTable && obj.isHtmlFormattedColumn(columnIndex)
                userData.Renderer = "html";
            end
        end

        function str = getTableVariableTooltip(~, className, value)
            str = "";
            try
                tableVariableObj = feval(className, value);
                str = string(tableVariableObj.getCellTooltipString());
            catch
            end
        end

        function options = normalizeColumnOptions(~, options)
            if iscell(options) && isscalar(options) && iscell(options{1})
                options = options{1};
            end
            if isstring(options)
                options = cellstr(options);
            end
        end

        function onMetaTableSet(obj, newTable)
            if isa(newTable, 'nansen.metadata.MetaTable')
                T = newTable.getFormattedTableData([], [], 'modern');
                obj.MetaTableType = lower(newTable.getTableType());
                obj.MetaTableCell = table2cell(T);
            elseif isa(newTable, 'table')
                obj.MetaTableCell = table2cell(newTable);
            end

            if ~isempty(obj.MetaTable)
                obj.MetaTableVariableNames = obj.MetaTable.Properties.VariableNames;
                obj.RowKeyVariableName = obj.getUniqueRowKeyVariableName(obj.MetaTableVariableNames);
            else
                obj.MetaTableVariableNames = {};
                obj.RowKeyVariableName = 'NansenRowIndex__';
            end

            obj.MetaTableVariableAttributes = obj.getMetaTableVariableAttributes();
        end

        function onTableVariableAttributesFcnSet(obj)
            obj.MetaTableVariableAttributes = obj.getMetaTableVariableAttributes();
            if obj.IsConstructed
                obj.updateColumnLayout()
            end
        end

        function onTableFontSizeSet(obj)
            if ~isempty(obj.HTable) && isvalid(obj.HTable) && isprop(obj.HTable, 'FontSize')
                obj.HTable.FontSize = obj.TableFontSize;
            end
        end

        function onColumnFilterSet(obj)
            if ~isempty(obj.FilterChangedListener)
                delete(obj.FilterChangedListener)
            end

            obj.FilterChangedListener = addlistener(obj.ColumnFilter, ...
                'FilterUpdated', @obj.onFilterUpdated);
        end

        function onFilterUpdated(obj, ~, ~)
            obj.updateTableView([], false)
            obj.notifyTableRowsUpdated()
        end

        function updateMetaTableVariableAttributes(obj)
            obj.MetaTableVariableAttributes = obj.getMetaTableVariableAttributes();
        end

        function S = getMetaTableVariableAttributes(obj)
            if isempty(obj.MetaTable)
                S = struct.empty;
            elseif ~isempty(obj.GetTableVariableAttributesFcn)
                S = obj.GetTableVariableAttributesFcn(obj.MetaTableType);
            else
                S = obj.getDefaultMetaTableVariableAttributes();
            end
        end

        function S = getDefaultMetaTableVariableAttributes(obj)
            import nansen.metadata.abstract.TableVariable;

            if isempty(obj.MetaTable)
                S = struct.empty;
                return
            end

            varNames = obj.MetaTable.Properties.VariableNames;
            numVars = numel(varNames);
            S = TableVariable.getDefaultTableVariableAttribute();
            S = repmat(S, 1, numVars);

            [S(1:numVars).Name] = varNames{:};
            [S(1:numVars).TableType] = deal(obj.MetaTableType);
        end

        function value = normalizeDisplayValue(obj, value)
            if ischar(value)
                return
            elseif isnumeric(value) || islogical(value)
                if isscalar(value) || isempty(value)
                    return
                else
                    value = mat2str(value);
                end
            else
                value = obj.stringifyDisplayValue(value);
            end
        end

        function str = stringifyDisplayValue(obj, value)
            if isempty(value)
                str = '';
            elseif iscell(value)
                str = obj.stringifyCellValue(value);
            elseif isstring(value) || isdatetime(value) || isduration(value) || ...
                    iscategorical(value) || isenum(value)
                str = obj.stringifyStringConvertibleValue(value);
            elseif isstruct(value)
                str = strtrim(evalc('disp(value)'));
            else
                try
                    str = char(value);
                catch
                    str = strtrim(evalc('disp(value)'));
                end
            end
        end

        function str = stringifyCellValue(obj, value)
            if isempty(value)
                str = '';
                return
            end

            parts = cellfun(@obj.stringifyDisplayValue, value(:), ...
                'UniformOutput', false);
            str = char(strjoin(string(parts), ', '));
        end

        function str = stringifyStringConvertibleValue(~, value)
            if isscalar(value)
                str = char(value);
            else
                str = char(strjoin(string(value(:).'), ', '));
            end
        end

        function onEntityCellEdited(obj, ~, evtData)
            tableRowInd = evtData.ModelRow;
            tableColInd = find(strcmp(obj.MetaTableVariableNames, evtData.VariableName), 1, 'first');
            if isempty(tableRowInd) || isempty(tableColInd)
                return
            end

            obj.MetaTableCell{tableRowInd, tableColInd} = evtData.NewValue;

            if ~isempty(obj.CellEditCallback)
                evt = uiw.event.EventData(...
                    'Indices', [tableRowInd, tableColInd], ...
                    'NewValue', evtData.NewValue, ...
                    'PreviousValue', evtData.OldValue);
                obj.CellEditCallback(obj.HTable, evt)
            end
        end

        function onEntitySelectionChanged(obj, ~, ~)
            selectedRows = obj.getSelectedEntries();
            evtData = uiw.event.EventData('SelectedRows', selectedRows);
            obj.notify('SelectionChanged', evtData)
        end

        function onModernDisplayDataChanged(obj, src, evt)
            if obj.isDisplayDataInteraction(evt, "rearrange")
                obj.captureColumnWidths()
                obj.captureColumnOrder()
                obj.syncEntityTableColumnSpecs()
                obj.syncEntityTableContextMenus()
                obj.clearDisplayColumnOrder(src)
                return
            end

            if obj.isDisplayDataInteraction(evt, "resize")
                obj.AutoAppliedColumnWidths = [];
                obj.captureColumnWidths()
                return
            end

            if obj.hasEventProperty(evt, 'DisplayRowName')
                displayRowName = obj.getEventProperty(evt, 'DisplayRowName');
                if ~isempty(displayRowName) && ...
                        obj.EntityTableView.applyNativeDisplayRowNames(displayRowName)
                    obj.notifyTableRowsUpdated()
                    return
                end
            end

            displayData = [];
            if obj.hasEventProperty(evt, 'DisplayData')
                displayData = obj.getEventProperty(evt, 'DisplayData');
            elseif isprop(src, 'DisplayData')
                displayData = src.DisplayData;
            end

            if obj.EntityTableView.applyNativeDisplayOrder(displayData)
                obj.notifyTableRowsUpdated()
            end
        end

        function onTableColumnWidthChanged(obj)
            if obj.IsApplyingColumnWidths
                return
            end

            obj.AutoAppliedColumnWidths = [];
            obj.captureColumnWidths()
        end

        function onEntityColumnLayoutChanged(obj, ~, ~)
            if obj.IsApplyingColumnWidths
                return
            end

            obj.AutoAppliedColumnWidths = [];
            obj.captureColumnWidths()
            obj.captureColumnOrder()
        end

        function onEntityCellActivated(obj, src, evt)
            if isempty(obj.MouseDoubleClickedFcn)
                return
            end

            if isempty(evt.DisplayRow) || isempty(evt.DisplayColumn) || ...
                    any([evt.DisplayRow, evt.DisplayColumn] == 0)
                return
            end

            evtData = uiw.event.EventData(...
                'Cell', [evt.DisplayRow, evt.DisplayColumn], ...
                'SelectionType', 'open', ...
                'Button', 1, ...
                'Position', [0 0], ...
                'MetaOn', false, ...
                'ControlOn', false);

            obj.MouseDoubleClickedFcn(src.getComponent(), evtData)
        end

        function onEntityFilterChanged(obj, ~, evt)
            if isempty(evt.VariableName)
                obj.ActiveColumnFilterNames = strings(1, 0);
                obj.updateColumnFilterState()
            else
                obj.setColumnFilterActive(evt.VariableName, ~isempty(evt.FilterSpec))
            end
            obj.notifyTableRowsUpdated()
        end

        function notifyTableRowsUpdated(obj)
            if isempty(obj.MetaTableCell)
                rows = [];
            else
                rows = obj.DisplayedRows;
            end
            evtdata = uiw.event.EventData('RowIndices', rows, 'Type', 'TableFilterUpdate');
            obj.notify('TableUpdated', evtdata)
        end

        function captureColumnWidths(obj)
            if isempty(obj.HTable) || ~isvalid(obj.HTable) || isempty(obj.ColumnModel)
                return
            end
            if obj.IsApplyingColumnWidths
                return
            end

            columnWidths = obj.getCurrentVisibleColumnWidths();
            if isequal(columnWidths, obj.AutoAppliedColumnWidths)
                return
            end
            if isequal(columnWidths, obj.ColumnModel.getColumnWidths())
                return
            end
            if ~isempty(columnWidths)
                obj.ColumnModel.setColumnWidths(columnWidths);
            end
        end

        function columnWidths = getCurrentVisibleColumnWidths(obj)
            columnWidths = [];
            if ~isempty(obj.EntityTableView) && isvalid(obj.EntityTableView) && ...
                    ismethod(obj.EntityTableView, 'getColumnWidths')
                columnWidths = obj.EntityTableView.getColumnWidths();
                columnWidths = obj.normalizeColumnWidths(columnWidths);
            elseif ~isempty(obj.HTable) && isvalid(obj.HTable) && ...
                    isprop(obj.HTable, 'ColumnWidth')
                columnWidths = obj.normalizeColumnWidths(obj.HTable.ColumnWidth);
            end
            if isempty(columnWidths) && ~isempty(obj.ColumnModel) && isvalid(obj.ColumnModel)
                columnWidths = obj.ColumnModel.getColumnWidths();
                columnWidths = obj.normalizeColumnWidths(columnWidths);
            end
        end

        function captureColumnOrder(obj)
            if isempty(obj.HTable) || ~isvalid(obj.HTable) || isempty(obj.ColumnModel)
                return
            end
            if ~isempty(obj.EntityTableView) && isvalid(obj.EntityTableView) && ...
                    ismethod(obj.EntityTableView, 'getColumnVariableOrder')
                newVariableOrder = obj.EntityTableView.getColumnVariableOrder();
                [~, variableNames] = obj.ColumnModel.getColumnNames();
                if ~isequal(newVariableOrder, string(variableNames))
                    obj.ColumnModel.setNewColumnVariableOrder(newVariableOrder);
                    if ~isempty(obj.ColumnFilter) && isvalid(obj.ColumnFilter)
                        obj.ColumnFilter.hideFilters()
                    end
                end
                return
            end
            if ~isprop(obj.HTable, 'DisplayColumnOrder')
                return
            end

            displayColumnOrder = obj.HTable.DisplayColumnOrder;
            if isempty(displayColumnOrder)
                return
            end

            [~, variableNames] = obj.ColumnModel.getColumnNames();
            if numel(displayColumnOrder) ~= numel(variableNames)
                return
            end

            newVariableOrder = string(variableNames(displayColumnOrder));
            if isequal(newVariableOrder, string(variableNames))
                return
            end

            obj.ColumnModel.setNewColumnVariableOrder(newVariableOrder);
            if ~isempty(obj.ColumnFilter) && isvalid(obj.ColumnFilter)
                obj.ColumnFilter.hideFilters()
            end
        end

        function columnWidths = normalizeColumnWidths(~, columnWidths)
            if iscell(columnWidths)
                parsedWidths = nan(1, numel(columnWidths));
                for i = 1:numel(columnWidths)
                    parsedWidths(i) = parseWidth(columnWidths{i});
                end
                if any(~isfinite(parsedWidths))
                    columnWidths = [];
                else
                    columnWidths = parsedWidths;
                end
            elseif ~isnumeric(columnWidths)
                columnWidths = parseWidth(columnWidths);
                if ~isfinite(columnWidths)
                    columnWidths = [];
                end
            else
                columnWidths = double(columnWidths(:).');
            end

            function width = parseWidth(widthValue)
                if isnumeric(widthValue) && isscalar(widthValue)
                    width = double(widthValue);
                    return
                end
                if isstring(widthValue) || ischar(widthValue)
                    width = str2double(string(widthValue));
                    if isempty(width) || isnan(width)
                        width = NaN;
                    end
                    return
                end
                width = NaN;
            end
        end

        function tf = isDisplayDataInteraction(obj, evt, interactionName)
            tf = false;
            if ~obj.hasEventProperty(evt, 'Interaction')
                return
            end

            interaction = obj.getEventProperty(evt, 'Interaction');
            interaction = lower(string(interaction));
            interactionName = lower(string(interactionName));
            tf = any(interaction == interactionName | contains(interaction, interactionName));
        end

        function tf = hasEventProperty(~, evt, propertyName)
            tf = isprop(evt, propertyName) || ...
                (isstruct(evt) && isfield(evt, propertyName));
        end

        function value = getEventProperty(~, evt, propertyName)
            value = evt.(propertyName);
        end

        function clearDisplayColumnOrder(~, hTable)
            if isempty(hTable) || ~isvalid(hTable) || ...
                    ~isprop(hTable, 'DisplayColumnOrder')
                return
            end

            try
                hTable.DisplayColumnOrder = [];
            catch
            end
        end

        function rowKeyName = getUniqueRowKeyVariableName(~, variableNames)
            rowKeyName = 'NansenRowIndex__';
            while any(strcmp(variableNames, rowKeyName))
                rowKeyName = [rowKeyName, '_']; %#ok<AGROW>
            end
        end
    end

    methods (Static)
        function tf = isValidTableClass(var)
            validClasses = nansen.ui.metatable.EntityTableMetaTableViewer.VALID_TABLE_CLASS;
            tf = any(cellfun(@(type) isa(var, type), validClasses));
        end
    end
end
