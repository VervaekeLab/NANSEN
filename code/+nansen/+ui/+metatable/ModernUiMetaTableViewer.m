classdef ModernUiMetaTableViewer < handle
%ModernUiMetaTableViewer Native MATLAB table backend for metadata tables.

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
        DisplayRowIndex = []
        DisplayColumnIndex = []
        IsConstructed = false
        RequireReset = false
        MouseMotionCallback = []
        HtmlStyleConfigurationRows = []
    end

    events
        TableUpdated
        SelectionChanged
    end

    methods
        function obj = ModernUiMetaTableViewer(varargin)
            obj.parseInputs(varargin)

            obj.ColumnModel = nansen.ui.MetaTableColumnLayout(...
                obj, 'ColumnSettings', obj.ColumnSettings);
            obj.createUiTable()
            obj.ColumnFilter = nansen.ui.metatable.ModernMetaTableColumnFilter(obj, obj.AppRef);

            obj.IsConstructed = true;

            if ~isempty(obj.MetaTableCell)
                obj.refreshTable()
                obj.HTable.Visible = 'on';
                drawnow
            end
        end

        function delete(obj)
            if ~isempty(obj.HTable) && isvalid(obj.HTable)
                columnWidths = obj.normalizeColumnWidths(obj.HTable.ColumnWidth);
                if ~isempty(columnWidths)
                    obj.ColumnModel.setColumnWidths(columnWidths);
                end
                delete(obj.HTable)
            end
            if ~isempty(obj.ColumnModel) && isvalid(obj.ColumnModel)
                delete(obj.ColumnModel)
            end
        end
    end

    methods
        function rowIndices = get.DisplayedRows(obj)
            if isempty(obj.MetaTableCell)
                rowIndices = [];
                return
            end

            if ~isempty(obj.ExternalFilterMap)
                visibleRows = find(obj.ExternalFilterMap);
            else
                visibleRows = 1:size(obj.MetaTableCell, 1);
            end

            rowIndices = obj.getCurrentRowSelection();
            rowIndices = intersect(rowIndices, visibleRows, 'stable');
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
            obj.RequireReset = ~strcmp(oldType, lower(newValue));
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
            obj.refreshTable()
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
    end

    methods
        function refreshColumnModel(obj, varargin)
            obj.ColumnModel.updateColumnEditableState()
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
            obj.ColumnFilter.resetFilters()
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
            obj.updateTableView(rowInd)
        end

        function refreshTable(obj, newTable, flushTable)
            requireReset = isempty(obj.MetaTable) || obj.RequireReset;

            if nargin >= 2 && ~(isnumeric(newTable) && isempty(newTable))
                obj.MetaTable = newTable;
            end

            if nargin < 3 || isempty(flushTable)
                flushTable = requireReset;
            end

            if flushTable
                obj.HTable.Data = {};
                obj.DataFilterMap = [];
                if ~isempty(obj.MetaTable)
                    obj.ColumnFilter.onMetaTableChanged()
                end
                obj.RequireReset = false;
            elseif ~isempty(obj.ColumnFilter)
                obj.ColumnFilter.onMetaTableUpdated()
            end

            drawnow
            if ~isempty(obj.MetaTable)
                obj.updateMetaTableVariableAttributes()
                obj.updateColumnLayout()
                obj.updateTableView()
            else
                obj.HTable.ColumnName = cell(1,0);
            end
        end

        function replaceTable(obj, newTable)
            obj.MetaTable = newTable;
            obj.ColumnFilter.onMetaTableChanged()
            obj.updateTableView()
        end

        function rowInd = getMetaTableRows(obj, rowIndDisplay)
            if isempty(rowIndDisplay)
                rowInd = [];
                return
            end

            rowIndDisplay = rowIndDisplay(rowIndDisplay > 0);
            rowInd = obj.DisplayRowIndex(rowIndDisplay);

            if iscolumn(rowInd)
                rowInd = transpose(rowInd);
            end
        end

        function IND = getSelectedEntries(obj)
            if isempty(obj.HTable) || isempty(obj.HTable.Selection)
                IND = [];
                return
            end

            selectedRows = obj.getSelectedViewRows();
            selectedRows = selectedRows(selectedRows > 0 & selectedRows <= numel(obj.DisplayRowIndex));
            IND = obj.DisplayRowIndex(selectedRows);
            IND = transpose(double(sort(unique(IND))));
        end

        function setSelectedEntries(obj, IND, preventCallback)
            if nargin < 3
                preventCallback = false; %#ok<NASGU>
            end

            if isempty(IND)
                obj.HTable.Selection = [];
                return
            end

            [isVisible, selectedRows] = ismember(IND, obj.DisplayRowIndex);
            selectedRows = selectedRows(isVisible);

            if isempty(selectedRows)
                obj.HTable.Selection = [];
            else
                obj.HTable.Selection = reshape(selectedRows, 1, []);
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
            if numel(columnNames) == 1 && iscell(columnNames)
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
            if ~isempty(obj.HTable) && isvalid(obj.HTable)
                obj.HTable.Tooltip = tooltipText;
            end
        end

        function setKeyPressFcn(obj, callback)
            if ~isempty(obj.HTable) && isvalid(obj.HTable)
                obj.HTable.KeyPressFcn = callback;
            end
        end

        function listenerHandle = addMouseMotionCallback(obj, callback)
            obj.MouseMotionCallback = callback;
            listenerHandle = [];
        end

        function n = getDisplayedRowCount(obj)
            if isempty(obj.HTable) || isempty(obj.HTable.Data)
                n = 0;
            else
                n = size(obj.HTable.Data, 1);
            end
        end

        function n = getSelectedRowCount(obj)
            n = numel(obj.getSelectedEntries());
        end
    end

    methods (Access = {?nansen.ui.metatable.ModernUiMetaTableViewer, ?nansen.ui.MetaTableColumnLayout, ?nansen.ui.metatable.ModernMetaTableColumnFilter})
        function updateTableView(obj, visibleRows, requestFocus)
            if isempty(obj.ColumnModel) || isempty(obj.MetaTableCell)
                return
            end

            if nargin < 2 || isempty(visibleRows)
                visibleRows = 1:size(obj.MetaTableCell, 1);
            end
            if nargin < 3 || isempty(requestFocus)
                requestFocus = true;
            end

            visibleColumns = obj.getCurrentColumnSelection();
            filteredRows = obj.getCurrentRowSelection();
            visibleRows = intersect(filteredRows, visibleRows, 'stable');

            obj.DisplayRowIndex = visibleRows;
            obj.DisplayColumnIndex = visibleColumns;

            obj.HTable.Data = obj.getDisplayTableData(visibleRows, visibleColumns);
            obj.HTable.Visible = 'on';

            obj.updateColumnLabelFilterIndicator()

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
                obj.HTable.ColumnName = {''};
                drawnow
                return
            end

            colIndices = obj.ColumnModel.getColumnIndices();
            [columnLabels, variableNames] = obj.ColumnModel.getColumnNames();

            obj.HTable.ColumnName = columnLabels;
            obj.updateColumnEditable()
            obj.changeColumnWidths(obj.ColumnModel.getColumnWidths())

            C = obj.MetaTableCell(:, colIndices);
            if size(C, 1) == 0
                return
            end

            T = obj.MetaTable(1, colIndices);
            columnFormat = repmat({'char'}, 1, numel(colIndices));

            displayData = obj.getDisplayTableData(1, colIndices);
            dataTypes = cellfun(@(cellValue) class(cellValue), displayData(1,:), 'UniformOutput', false);
            dataTypes(strcmp(dataTypes, 'string')) = {'char'};
            dataTypes(strcmp(dataTypes, 'categorical')) = {'char'};
            dataTypes(strcmp(dataTypes, 'datetime')) = {'char'};
            dataTypes(strcmp(dataTypes, 'duration')) = {'char'};

            isCustomDisplay = @(x) isa(x, 'matlab.mixin.CustomCompactDisplayProvider');
            isCustomDisplayObj = cellfun(@(cellValue) isCustomDisplay(cellValue), table2cell(T), 'UniformOutput', true);
            dataTypes(isCustomDisplayObj) = {'char'};

            isNumeric = cellfun(@(cellValue) isnumeric(cellValue), C(1,:), 'UniformOutput', true);
            columnFormat(isNumeric) = {'numeric'};

            isLogical = cellfun(@(cellValue) islogical(cellValue), C(1,:), 'UniformOutput', true);
            columnFormat(isLogical) = {'logical'};

            isEnumeration = cellfun(@(cellValue) isenum(cellValue), table2cell(T), 'UniformOutput', true);
            for i = find(isEnumeration)
                enumObject = T{1,i};
                if iscell(enumObject)
                    enumObject = enumObject{1};
                end
                [~, enumNames] = enumeration(enumObject);
                columnFormat{i} = enumNames;
            end

            isCategorical = cellfun(@(cellValue) iscategorical(cellValue), table2cell(T), 'UniformOutput', true);
            for i = find(isCategorical)
                categoricalObject = T{1,i};
                if iscell(categoricalObject)
                    categoricalObject = categoricalObject{1};
                end
                if isprotected(categoricalObject)
                    columnFormat{i} = categories(categoricalObject);
                else
                    columnFormat{i} = cat(1, '<undefined>', categories(categoricalObject));
                end
            end

            if ~isempty(obj.MetaTableVariableAttributes)
                isVarWithOptions = [obj.MetaTableVariableAttributes.HasOptions];
                isValidType = strcmp([obj.MetaTableVariableAttributes.TableType], obj.MetaTableType);
                customVarNames = {obj.MetaTableVariableAttributes(isVarWithOptions & isValidType).Name};
                [customVarNames, iA] = intersect(variableNames, customVarNames);

                for i = 1:numel(customVarNames)
                    thisName = customVarNames{i};
                    tableVarIndex = strcmp({obj.MetaTableVariableAttributes.Name}, thisName);
                    popupOptions = obj.MetaTableVariableAttributes(tableVarIndex).OptionsList;

                    if isa(popupOptions, 'cell') && numel(popupOptions) == 1
                        columnFormat(iA(i)) = popupOptions;
                    else
                        columnFormat(iA(i)) = {popupOptions};
                    end
                    obj.HTable.ColumnEditable(iA(i)) = true;
                end
            end

            if any(strcmp(dataTypes, 'cell'))
                error('The table contains values that can not be rendered. Please contact support.')
            end

            obj.HTable.ColumnFormat = columnFormat;
            obj.HTable.ColumnName = columnLabels;
            obj.applyHtmlInterpreterStyles()
            obj.ColumnModel.updateJavaColumnModel()
        end

        function updateColumnLabelFilterIndicator(obj, filterActive)
            if nargin < 2
                filterActive = obj.ColumnFilter.isColumnFilterActive;
            end

            colIndices = obj.ColumnModel.getColumnIndices();
            if ~isempty(filterActive)
                filterActive = filterActive(colIndices);
            end

            columnNames = obj.ColumnModel.getColumnNames();
            for i = 1:numel(columnNames)
                if ~isempty(filterActive) && filterActive(i)
                    columnNames{i} = sprintf('* %s', columnNames{i});
                end
            end
            if ~isempty(columnNames)
                obj.changeColumnNames(columnNames)
            end
        end

        function updateColumnEditable(obj)
            if isempty(obj.ColumnModel) || isempty(obj.MetaTableVariableAttributes)
                return
            end

            allowEdit = obj.ColumnModel.getColumnIsEditable;
            [~, variableNames] = obj.ColumnModel.getColumnNames();
            attributeColumnNames = {obj.MetaTableVariableAttributes.Name};
            [isMatched, attributeIdx] = ismember(variableNames, attributeColumnNames);

            isEditable = false(size(allowEdit));
            if any(isMatched)
                isEditable(isMatched) = [obj.MetaTableVariableAttributes(attributeIdx(isMatched)).IsEditable];
            end
            allowEdit = allowEdit & isEditable;

            columnNames = obj.ColumnModel.getColumnNames();
            if obj.AllowTableEdits
                allowEdit(contains(lower(columnNames), 'ignore')) = true;
                allowEdit(contains(lower(columnNames), 'description')) = true;
            else
                allowEdit(:) = false;
            end

            obj.HTable.ColumnEditable = allowEdit;
        end

        function C = getDisplayTableData(obj, rowIndices, columnIndices)
            C = obj.MetaTableCell(rowIndices, columnIndices);
            C = cellfun(@obj.normalizeDisplayValue, C, 'UniformOutput', false);
        end

        function changeColumnNames(obj, newNames)
            obj.HTable.ColumnName = newNames;
        end

        function changeColumnWidths(obj, newWidths)
            obj.HTable.ColumnWidth = num2cell(newWidths);
        end
    end

    methods (Access = private)
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

        function createUiTable(obj)
            if isempty(obj.Parent)
                obj.Parent = uifigure(...
                    'Name', 'NANSEN Metadata Table', ...
                    'Visible', 'on');
            end

            obj.HTable = uitable(obj.Parent, ...
                'Tag', 'MetaTable', ...
                'FontSize', obj.TableFontSize, ...
                'FontName', 'avenir next', ...
                'Units', 'normalized', ...
                'Position', [0 0 1 1], ...
                'Visible', 'off');

            obj.HTable.ColumnEditable = true;
            obj.HTable.ColumnSortable = true;
            obj.HTable.ColumnRearrangeable = true;
            obj.HTable.SelectionType = 'row';
            obj.HTable.Multiselect = 'on';
            obj.HTable.CellEditCallback = @obj.onCellValueEdited;
            obj.HTable.SelectionChangedFcn = @obj.onCellSelectionChanged;
            obj.HTable.DisplayDataChangedFcn = @obj.onDisplayDataChanged;
            obj.HTable.DoubleClickedFcn = @obj.onMouseDoubleClickedInTable;
            obj.HTable.ContextMenu = obj.TableContextMenu;
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
            else
                obj.MetaTableVariableNames = {};
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
            if ~isempty(obj.HTable)
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

        function applyHtmlInterpreterStyles(obj)
            obj.removeHtmlInterpreterStyles()

            if isempty(obj.HTable) || ~isvalid(obj.HTable) || ...
                    isempty(obj.ColumnModel) || isempty(obj.MetaTableCell)
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

        function onFilterUpdated(obj, ~, ~)
            obj.updateTableView([], false)

            if ~isempty(obj.ExternalFilterMap)
                visibleRows = find(obj.ExternalFilterMap);
            else
                visibleRows = 1:size(obj.MetaTableCell, 1);
            end

            rows = obj.getCurrentRowSelection();
            rows = intersect(rows, visibleRows, 'stable');

            evtdata = uiw.event.EventData('RowIndices', rows, 'Type', 'TableFilterUpdate');
            obj.notify('TableUpdated', evtdata)
        end

        function rowInd = getCurrentRowSelection(obj)
            [numRows, numColumns] = size(obj.MetaTableCell);
            if isempty(obj.DataFilterMap)
                obj.DataFilterMap = true(numRows, numColumns);
            end

            if ~obj.ShowIgnoredEntries && ~isempty(obj.MetaTable)
                varNames = obj.MetaTable.Properties.VariableNames;
                isIgnoreColumn = contains(lower(varNames), 'ignore');
                if any(isIgnoreColumn)
                    isIgnored = [obj.MetaTableCell{:, isIgnoreColumn}];
                    obj.DataFilterMap(:, isIgnoreColumn) = ~isIgnored;
                end
            end

            rowInd = find(all(obj.DataFilterMap, 2));

            if ~isempty(obj.ExternalFilterMap)
                rowInd = intersect(rowInd, find(obj.ExternalFilterMap), 'stable');
            end
        end

        function colInd = getCurrentColumnSelection(obj)
            if isempty(obj.ColumnModel)
                colInd = [];
                return
            end

            colInd = obj.ColumnModel.getColumnIndices();
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
            % Web uitable cells can only contain numeric, logical or char values.
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

        function onCellValueEdited(obj, ~, evtData)
            rowInd = obj.DisplayRowIndex;
            colInd = obj.DisplayColumnIndex;

            tableRowInd = rowInd(evtData.Indices(1));
            tableColInd = colInd(evtData.Indices(2));

            obj.MetaTableCell{tableRowInd, tableColInd} = evtData.NewData;

            if ~isempty(obj.CellEditCallback)
                evt = uiw.event.EventData(...
                    'Indices', [tableRowInd, tableColInd], ...
                    'NewValue', evtData.NewData, ...
                    'PreviousValue', evtData.PreviousData);
                obj.CellEditCallback(obj.HTable, evt)
            end
        end

        function onCellSelectionChanged(obj, ~, ~)
            selectedRows = obj.getSelectedEntries();
            evtData = uiw.event.EventData('SelectedRows', selectedRows);
            obj.notify('SelectionChanged', evtData)
        end

        function onDisplayDataChanged(obj, ~, evt)
            if isprop(evt, 'Interaction') && strcmp(evt.Interaction, 'rearrange')
                try
                    obj.ColumnModel.setNewColumnOrder(evt.DisplayColumnName)
                catch
                    % Native table callback metadata varies by release.
                end
            end
        end

        function onMouseDoubleClickedInTable(obj, src, evt)
            if isempty(obj.MouseDoubleClickedFcn)
                return
            end

            cellIndex = obj.getCellFromInteractionEvent(evt);
            if any(cellIndex == 0)
                return
            end

            evtData = uiw.event.EventData(...
                'Cell', cellIndex, ...
                'SelectionType', 'open', ...
                'Button', 1, ...
                'Position', [0 0], ...
                'MetaOn', false, ...
                'ControlOn', false);

            obj.MouseDoubleClickedFcn(src, evtData)
        end

        function cellIndex = getCellFromInteractionEvent(obj, evt)
            row = [];
            col = [];

            if isprop(evt, 'InteractionInformation')
                info = evt.InteractionInformation;
                row = obj.getInteractionProperty(info, 'Row');
                col = obj.getInteractionProperty(info, 'Column');
            end

            if isempty(row) || isempty(col)
                selection = obj.HTable.Selection;
                if isempty(selection)
                    cellIndex = [0 0];
                    return
                elseif size(selection, 2) == 2
                    row = selection(1,1);
                    col = selection(1,2);
                else
                    row = selection(1);
                    col = 1;
                end
            end

            cellIndex = [row, col];
        end

        function value = getInteractionProperty(~, info, propertyName)
            value = [];
            try
                if isprop(info, propertyName)
                    value = info.(propertyName);
                elseif isstruct(info) && isfield(info, propertyName)
                    value = info.(propertyName);
                end
            catch
                value = [];
            end
        end

        function selectedRows = getSelectedViewRows(obj)
            selection = obj.HTable.Selection;
            if isempty(selection)
                selectedRows = [];
            elseif strcmp(obj.HTable.SelectionType, 'row')
                selectedRows = selection(:);
            elseif isvector(selection)
                selectedRows = selection(:);
            elseif size(selection, 2) == 2
                selectedRows = selection(:,1);
            else
                selectedRows = selection;
            end
        end

        function columnWidths = normalizeColumnWidths(~, columnWidths)
            if iscell(columnWidths)
                isNumericWidth = cellfun(@isnumeric, columnWidths);
                numericWidths = columnWidths(isNumericWidth);
                if isempty(numericWidths)
                    columnWidths = [];
                else
                    columnWidths = [numericWidths{:}];
                end
            end
        end

    end

    methods (Static)
        function tf = isValidTableClass(var)
            validClasses = nansen.ui.metatable.ModernUiMetaTableViewer.VALID_TABLE_CLASS;
            tf = any(cellfun(@(type) isa(var, type), validClasses));
        end
    end
end
