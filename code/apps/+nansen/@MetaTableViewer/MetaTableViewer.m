classdef MetaTableViewer < handle & uiw.mixin.AssignPVPairs
%MetaTableViewer Implementation of UI table for viewing metadata tables.
%
%   This class is built around the Table class from the Widgets Toolbox.
%   This is a very responsive java based table implementation. This class
%   extends the functionality of the uiw.widget.Table in primarily two
%   ways:
%       1) Columns can be filtered
%       2) Settings for columns are saved until next time table is opened.
%           (Columns widths, column visibility and column label is saved
%           across matlab sessions) Todo: Also save column editable...
    
% - - - - - - - - - - - - - - - TODO - - - - - - - - - - - - - - - - -
    %  *[ ] Update table without emptying data! Use add column/remove
    %   [ ] jTable.setPreserveSelectionsAfterSorting(true); Is this useful
    %       here???
    %   [ ] Save table settings to project folder

    %       column from the java column model when hiding/showing columns
    %   [ ] Outsource everything column related to column model
    %   [ ] Create table with all columns and store the tablecolumn objects in the column model if rows are hidden?
    %
    %   [x] Make ignore column editable
    %   [x] Set method for metaTable...
    %   [x] Revert change from metatable. need to get formatted data from
    %       table!
    %   [ ] Should the filter be a RowModel?
    %   [ ] Make method for getting colorcoded column names (based on
    %   column filters, and always run columnNames through this method
    %   before setting the on the table object
    %   [ ] Will ColumnFilter.isColumnFilterActive always match the columns
    %       in the column model? Need to verify
    %   [ ] Straighten out what to do about the MetaTable property.
    %       Problem: if the input metatable was a MetaTable object, it
    %       might contain data which is not renderable in the uitable, i.e
    %       structs. If table data is changed, and data is put back into
    %       the table version of the MetaTable, the set.MetaTable methods
    %       creates a downstream bug because it sets it, and consequently
    %       the MetaTableCell property without getting formatted data from
    %       the metatable class. For now, I keep as it is, because the only
    %       column I edit is the ignore column, and the MetaTable property
    %       is not used anywhere. But this can be a BIG PROBLEM if things
    %       change some time.
    
% - - - - - - - - - - - - - - PROPERTIES - - - - - - - - - - - - - - -

    properties (Constant, Hidden)
        VALID_TABLE_CLASS = {'nansen.metadata.MetaTable', 'table'};
    end
    
    properties % Table preferences
        ShowIgnoredEntries = true
        AllowTableEdits = true
        TableFontSize = 12
        MetaTableType = 'session' %Note: should always be lowercase
    end

    properties
        SelectedEntries         % Selected rows from full table, irrespective of sorting and filtering.
        CellEditCallback
        KeyPressCallback
        
        MouseDoubleClickedFcn = [] % This should be internalized, but for now it is assigned from session browser/nansen
        
        DeleteColumnFcn = []    % This should be internalized, but for now it is assigned from session browser/nansen
        UpdateColumnFcn = []    % This should be internalized, but for now it is assigned from session browser/nansen
        ResetColumnFcn = []     % This should be internalized, but for now it is assigned from session browser/nansen
        EditColumnFcn = []      % This should be internalized, but for now it is assigned from session browser/nansen
    
        % Does this make sense? Thinking that this should be taken care of
        % at another level, as the Metatable viewer is not nansen specific...
        GetTableVariableAttributesFcn = [] % Function handle for retrieving table variable attributes.
    end
    
    properties (SetAccess = private, SetObservable = true)
        MetaTable               % Table version of the table data
        MetaTableCell cell      % Cell array version of the table data
        MetaTableVariableNames  % Cell array of variable names in full table
        MetaTableVariableAttributes % Struct with attributes of metatable variables.
    end

    properties (Dependent)
        ColumnSettings

        % DisplayedRows - Rows of the original metatable which are
        % currently displayed
        DisplayedRows
        
        % DisplayedColumns - Columns of the original metatable which are
        % currently displayed (not implemented yet)
        % DisplayedColumns
    end
    
    properties (SetAccess = private)
        ColumnModel             % Class instance for updating columns based on user preferences.
        ColumnFilter            % Class instance for filtering data based on column variables.
    end
    
    properties %(Access = private)
        
        AppRef
        Parent
        HTable
        JTable
        
        ColumnContextMenu = []
        TableContextMenu = []
        
        DataFilterMap = []  % Boolean "map" (numRows x numColumns) with false for cells that is outside filter range
        ExternalFilterMap = [] % Boolean vector with rows that are "filtered" externally. Todo: Formalize this better.
        FilterChangedListener event.listener
        
        ColumnWidthChangedListener
        ColumnsRearrangedListener
        MouseDraggedInHeaderListener
        
        ColumnPressedTimer
    end
    
    properties (Access = private)
        ColumnSettings_
        lastMousePressTic
        IsConstructed = false;
        RequireReset = false;
    end
    
    events
        TableUpdated
        SelectionChanged
    end
    
% - - - - - - - - - - - - - - - METHODS - - - - - - - - - - - - - - -
    
    methods % Structors
        
        function obj = MetaTableViewer(varargin)
        %MetaTableViewer Construct for MetaTableViewer
        
            % Take care of input arguments.
            obj.parseInputs(varargin)

            %if ~isempty(obj.ColumnSettings)
                nvPairs = {'ColumnSettings', obj.ColumnSettings};
            %else
            %    nvPairs = {};
            %end
            
            % Initialize the column model.
            obj.ColumnModel = nansen.ui.MetaTableColumnLayout(obj, nvPairs{:});
            
            obj.createUiTable()
            
            obj.ColumnFilter = nansen.ui.MetaTableColumnFilter(obj, obj.AppRef);
            
            obj.IsConstructed = true;

            if ~isempty(obj.MetaTableCell)
                obj.refreshTable()
                obj.HTable.Visible = 'on'; % Make table visible
                drawnow
            end
        end
       
        function delete(obj)
            if ~isempty(obj.HTable) && isvalid(obj.HTable)
                columnWidths = obj.HTable.ColumnWidth;
                obj.ColumnModel.setColumnWidths(columnWidths);
            
                delete(obj.ColumnModel)
                
                delete(obj.HTable)
            end
        end
    end
    
    methods % Set/get
        
        function rowIndices = get.DisplayedRows(obj)
            if ~isempty(obj.ExternalFilterMap)
                visibleRows = find( obj.ExternalFilterMap );
            else
                visibleRows = 1:size(obj.MetaTableCell, 1);
            end
            
            rowIndices = obj.getCurrentRowSelection();
            rowIndices = intersect(rowIndices, visibleRows, 'stable');
        end

        function set.MetaTable(obj, newTable)
        % Set method for metatable.
        %
        % 1) If the newValue is a MetaTable object, the table data is
        %    retrieved before updating the property.
        % 2) After new value is set it is passed on the onMetaTableSet
        %    method which will also update the metaTableCell property and
        %    update the ui table.
        
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
            obj.onMetaTableTypeSet(oldType, lower(newValue))
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
            
        end

        function set.GetTableVariableAttributesFcn(obj, newValue)
            obj.GetTableVariableAttributesFcn = newValue;
            obj.onTableVariableAttributesFcnSet()
        end
    end
        
    methods % Public methods
        
        function refreshColumnModel(obj)
        %refreshColumnModel Refresh the columnmodel
        %
        %   Note: This method should be called whenever a new metatable is
        %   set, and whenever a metatable variable definition is changed.
        %
        %   Todo: {Find a way to make this happen when it is needed, instead
        %   of requiring this method to be called explicitly. This fix need
        %   to be implemented on the class (table model) owning the
        %   columnmodel}
            
            obj.ColumnModel.updateColumnEditableState()
        end
        
        function resetTable(obj, resetView)
            
            % Note: There is an option here to not reset the table view,
            % This is useful for aethetic reasons, to prevent flickering
            % when updating a table.
            if nargin < 2
                resetView = true; % todo: make nv pair args
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
        %updateCells Update subset of cells...
        
            % Note: The uiw.widget.Table setCell method takes the java
            % table model's row order into account when inserting data into
            % cells, but not the column order. That's why the rearrangement
            % of rows and columns below are not equivalent
            
            % Place new data in the cell representation of the metatable.
            obj.MetaTableCell(rowIdxData, colIdxData) = newData;
            
            % Get indices of visible rows based on data filter states
            rowIdxVisible = obj.getCurrentRowSelection();
            
            % Get indices of visible columns based on user selection of which columns to display
            colIdxVisible = obj.getCurrentColumnSelection();
            
            % Rearrange rows taking the table sorting into account:
            if ~isempty(obj.HTable.RowSortIndex)
                rowIdxVisible = rowIdxVisible(obj.HTable.RowSortIndex);
            end

            % Get the current order of column indices from java's column model
            [colIdxJava, ~] = obj.ColumnModel.getColumnModelIndexOrder();
            
            %Todo: Is it still a possibility that these are not the same length?
            %colIdxVisible = colIdxVisible(colIdxJava);
                        
            % Get the indices for where to insert data in the uitable, i.e
            % find which index of the visible data that corresponds with
            % the index of the actual data.
            [~, rowIdxUiTable, rowIdxDataSubset] = intersect(rowIdxVisible, rowIdxData, 'stable');
            [~, colIdxUiTable, colIdxDataSubset] = intersect(colIdxVisible, colIdxData, 'stable');
            
            % Insert data into the table model cell by cell
            for i = 1:numel(rowIdxUiTable)
                for j = 1:numel(colIdxUiTable)
                    % Get indices for current uitable cell
                    iRow = rowIdxUiTable(i);
                    jCol = colIdxJava( colIdxUiTable(j) ); % Reorder based on the underlying column order of the java model because this is not done internally in setCell
                    % Get value of data for current cell
                    thisValue = newData(rowIdxDataSubset(i), colIdxDataSubset(j));
                    % Insert value
                    obj.HTable.setCell(iRow, jCol, thisValue)
                end
            end
            drawnow
        end

        function updateTableRow(obj, rowIdxData, tableRowData)
        %updateTableRow Update data of specified table row
            % Count number of columns and get column indices
            colIdx = 1:size(tableRowData, 2);
            
            if isa(tableRowData, 'table')
                newData = table2cell(tableRowData);
            elseif isa(tableRowData, 'cell')
                %pass
            else
                error('Table row data is in the wrong format')
            end
            
            % Refresh cells of ui table...
            obj.updateCells(rowIdxData, colIdx, newData)
        end

        function updateFormattedTableColumnData(obj, columnName, columnData)
        %reformatTableColumnData Reformat data for specified column
            columnIndex = find(strcmp(obj.MetaTable.Properties.VariableNames, columnName));
            obj.MetaTableCell(:, columnIndex) = table2cell(columnData);
        end

        function appendTableRow(obj, rowData)
            % Would be neat, but haven't found a way to do it.
        end
        
        function updateVisibleRows(obj, rowInd)

            [numRows, ~] = size(obj.MetaTable);
            obj.ExternalFilterMap = false(numRows, 1);
            obj.ExternalFilterMap(rowInd) = true;
                        
            obj.updateTableView(rowInd)
        end
        
        function refreshTable(obj, newTable, flushTable)
        %refreshTable Method for refreshing the table
        
            % TODO: Make sure the selection is maintained.
            
            % Note: If [] is provided as 2nd arg, the table is not reset.
            % This might be used in some cases where the table should be
            % kept, but the flushTable flag is provided.
            
            requireReset = isempty( obj.MetaTable ) || obj.RequireReset;

            if nargin >= 2 && ~(isnumeric(newTable) && isempty(newTable))
                obj.MetaTable = newTable;
            end
            
            if nargin < 3 || isempty(flushTable)
                flushTable = requireReset;
            end
            
            % Todo: Save selection
            %selectedEntries = obj.getSelectedEntries();

            if flushTable % Empty table, gives smoother update in some cases
                obj.HTable.Data = {};
                obj.DataFilterMap = []; % reset data filter map
                if ~isempty(obj.MetaTable)
                    obj.ColumnFilter.onMetaTableChanged()
                end
                obj.RequireReset = false;
            else
                if ~isempty(obj.ColumnFilter)
                    obj.ColumnFilter.onMetaTableUpdated()
                end
            end
            
            drawnow
            if ~isempty(obj.MetaTable)
                obj.updateColumnLayout()
                obj.updateTableView()
            else
                obj.HTable.ColumnName = cell(1,0);
            end
            drawnow
            % Todo: Restore selection
            %obj.setSelectedEntries(selectedEntries);
            
        end
        
        function replaceTable(obj, newTable)
            obj.MetaTable = newTable;
            obj.ColumnFilter.onMetaTableChanged()
            obj.updateTableView()
        end
        
        function rowInd = getMetaTableRows(obj, rowIndDisplay)
            
            % Todo: Determine if this method is useful in
            % getSelectedEntries/setSelectedEntries?
            dataInd = get(obj.HTable.JTable.Model, 'Indexes');
            
            if ~isempty(dataInd)
                rowInd = dataInd(rowIndDisplay)+1; % +1 because java indices start at 0
            else
                rowInd = rowIndDisplay;
            end
      
            % Get currently visible row and column indices.
            visibleRowInd = obj.getCurrentRowSelection();
            
            % Get row and column indices for original data (unfiltered, unsorted, allcolumns)
            rowInd = visibleRowInd(rowInd);
            
            % Make sure output is a column vector
            if iscolumn(rowInd)
                rowInd = transpose(rowInd);
            end
        end
        
        function IND = getSelectedEntries(obj)
        %getSelectedEntries Get selected entries based on the MetaTable
        %
        %   Get selected entry from original metatable taking column
        %   sorting and filtering into account.
        
            IND = obj.HTable.SelectedRows;
            
            dataInd = get(obj.HTable.JTable.Model, 'Indexes');

            if ~isempty(dataInd)
                IND = dataInd(IND)+1; % +1 because java indices start at 0
                IND = transpose( double( sort(IND) ) ); % return as row vector
            else
                IND = IND;
            end
            
            % Get currently visible row and column indices.
            visibleRowInd = obj.getCurrentRowSelection();
            
            % Get row and column indices for original data (unfiltered, unsorted, allcolumns)
            IND = visibleRowInd(IND);
        end
       
        function setSelectedEntries(obj, IND, preventCallback)
        %setSelectedEntries Set row selection
        
            if nargin < 3
                preventCallback = false; % todo: make nv pair args
            end

            % Get currently visible row indices.
            visibleRowInd = obj.getCurrentRowSelection();
            
            % Get row indices based on the underlying table model (taking sorting into account)
            dataInd = get(obj.HTable.JTable.Model, 'Indexes') + 1;
            if isempty(dataInd)
                dataInd = 1:numel(visibleRowInd);
            end
            
            % Reorder the visible row indices according to possible sort
            % order
            visibleRowInd = visibleRowInd(dataInd);
            
            % Find the rownumber corresponding to the given entries.
            selectedRows = find(ismember(visibleRowInd, IND));

            % Set the row selection
            if preventCallback
                obj.HTable.disableCallbacks();
                obj.HTable.SelectedRows = selectedRows;
                drawnow
                obj.HTable.enableCallbacks();
            else
                obj.HTable.SelectedRows = selectedRows;
            end
        end
    
        function columnNames = getColumnNames(obj, columnIndices)
        % getColumnNames - Get name of column(s) given column indices
            if nargin < 2; columnIndices = []; end
            
            columnNames = obj.ColumnModel.getColumnNames();
            if ~isempty(columnIndices)
                columnNames = columnNames(columnIndices);
            end
            if numel(columnNames) == 1 && iscell(columnNames)
                columnNames = columnNames{1};
            end
        end
    end
   
    methods (Access = private) % Create components
        
        function parseInputs(obj, listOfArgs)
         %parseInputs Input parser that checks for expected input classes
            
            [nvPairs, remainingArgs] = utility.getnvpairs(listOfArgs);
            
            % Need to set name value pairs first
            obj.assignPVPairs(nvPairs{:})
            
            if isempty(remainingArgs);    return;    end
            
            % Check if first argument is a graphical container
            % Todo: check that graphical object is an actual container...
            if isgraphics(remainingArgs{1})
                obj.Parent = remainingArgs{1};
                remainingArgs = remainingArgs(2:end);
            end
            
            if isempty(remainingArgs);    return;    end

            % Check if first argument in list is a valid metatable class
            if obj.isValidTableClass( remainingArgs{1} )
                obj.MetaTable = remainingArgs{1};
                remainingArgs = remainingArgs(2:end);
            end
            
            if isempty(remainingArgs);    return;    end

        end
        
        function createUiTable(obj)
            
            for i = 1:2
            
                try
                    obj.HTable = uim.widget.StylableTable(...
                        'Parent', obj.Parent,...
                        'Tag','MetaTable',...
                        'Editable', true, ...
                        'RowHeight', 30, ...
                        'FontSize', obj.TableFontSize, ...
                        'FontName', 'helvetica', ...
                        'FontName', 'avenir next', ...
                        'SelectionMode', 'discontiguous', ...
                        'Sortable', true, ...
                        'Units','normalized', ...
                        'Position',[0 0.0 1 1], ...
                        'HeaderPressedCallback', @obj.onMousePressedInHeader, ...
                        'HeaderReleasedCallback', @obj.onMouseReleasedFromHeader, ...
                        'MouseClickedCallback', @obj.onMousePressedInTable, ...
                        'Visible', 'off', ...
                        'BackgroundColor', [1,1,0.5]);
                    break
                
                catch ME
                    switch ME.identifier
                        case 'MATLAB:Java:ClassLoad'
                            nansen.config.path.addUiwidgetsJarToJavaClassPath()
                        otherwise
                            rethrow(ME)
                    end
                end
            end
            
            if isempty(obj.HTable)
                tf = nansen.internal.setup.isUiwidgetsOnJavapath();
                if ~tf
                    error('Failed to create the gui. Try to install to Widgets Toolbox v1.3.330 again')
                else
                    error('Nansen:MetaTableViewer:CorruptedJavaPath', ...
                        'uiwidget jar is on javapath, but table creation failed.')
                end
            end
            
            obj.HTable.CellEditCallback = @obj.onCellValueEdited;
            obj.HTable.CellSelectionCallback = @obj.onCellSelectionChanged;
            obj.HTable.JTable.getTableHeader().setReorderingAllowed(true);
            obj.JTable = obj.HTable.JTable;

            % Listener that detects if column widths change if user drags
            % column headers edges to resize columns.
            obj.ColumnWidthChangedListener = listener(obj.HTable, ...
                'ColumnWidthChanged', @obj.onColumnWidthChanged);
            
            obj.ColumnsRearrangedListener = listener(obj.HTable, ...
                'ColumnsRearranged', @obj.onColumnsRearranged);
            
            obj.MouseDraggedInHeaderListener = listener(obj.HTable, ...
                'MouseDraggedInHeader', @obj.onMouseDraggedInTableHeader);
            
            obj.HTable.Theme = uim.style.tableLight;
            
        end
        
        function createColumnContextMenu(obj)
        %createColumnContextMenu Create a context menu for columns
        
        % Note: This context menu is reused for all columns, but because
        % it's appearance might depend on the column it is opened above,
        % some changes are done in the method openColumnContextMenu before
        % it is made visible. Also, a callback function is set there.
        
            hFigure = ancestor(obj.Parent, 'figure');
            
            % Create a context menu item for each of the different column
            % formats.

            obj.ColumnContextMenu = uicontextmenu(hFigure);
            
            % Create items of the menu for columns of char type
            hTmp = uimenu(obj.ColumnContextMenu, 'Label', 'Sort A-Z');
            hTmp.Tag = 'Sort Ascend';
            
            hTmp = uimenu(obj.ColumnContextMenu, 'Label', 'Sort Z-A');
            hTmp.Tag = 'Sort Descend';
            
% %             hTmp = uimenu(obj.ColumnContextMenu, 'Label', 'Filter...');
% %             hTmp.Tag = 'Filter';
% %             hTmp.Separator = 'on';
            
            hTmp = uimenu(obj.ColumnContextMenu, 'Label', 'Reset Filters');
            hTmp.Tag = 'Reset Filters';
            hTmp.Separator = 'on';
            
            hTmp = uimenu(obj.ColumnContextMenu, 'Label', 'Hide this column');
            hTmp.Tag = 'Hide Column';
            hTmp.Separator = 'on';
            
            hTmp = uimenu(obj.ColumnContextMenu, 'Label', 'Column settings...');
            hTmp.Tag = 'ColumnSettings';
            hTmp.MenuSelectedFcn = @(s,e) obj.ColumnModel.editSettings;
            
            hTmp = uimenu(obj.ColumnContextMenu, 'Label', 'Update column data');
            hTmp.Separator = 'on';
            hTmp.Tag = 'Update Column';

              hSubMenu = uimenu(hTmp, 'Label', 'Update selected rows');
              hSubMenu.Tag = 'Update selected rows';
              hSubMenu = uimenu(hTmp, 'Label', 'Update all rows');
              hSubMenu.Tag = 'Update all rows';
              
              hSubMenu = uimenu(hTmp, 'Label', 'Reset selected rows', 'Separator', 'on');
              hSubMenu.Tag = 'Reset selected rows';
              hSubMenu = uimenu(hTmp, 'Label', 'Reset all rows');
              hSubMenu.Tag = 'Reset all rows';

              hSubMenu = uimenu(hTmp, 'Label', 'Edit tablevar function', 'Separator', 'on');
              hSubMenu.Tag = 'Edit tablevar function';
                           
            hTmp = uimenu(obj.ColumnContextMenu, 'Label', 'Delete this column');
            hTmp.Tag = 'Delete Column';
            
        end
        
        function createColumnFilterComponents(obj)
            % todo
        end
    end
    
    methods (Access = {?nansen.MetaTableViewer, ?nansen.ui.MetaTableColumnLayout, ?nansen.ui.MetaTableColumnFilter})
          
        function updateTableView(obj, visibleRows, requestFocus)

            % visibleRows : list of indices of rows to show
            % requestFocus : boolean, whether table should request focus.

            % Note: When updating filters (especially search autocomplete)
            % the table should not request focus. In other cases, I dont
            % remember why the table should request focus...

            if isempty(obj.ColumnModel); return; end % On construction...
                        
            [numRows, numColumns] = size(obj.MetaTableCell); %#ok<ASGLU>

            if nargin < 2 || isempty(visibleRows); visibleRows = 1:numRows; end
            if nargin < 3 || isempty(requestFocus); requestFocus = true; end

            % Get based on user selection of which columns to display
            visibleColumns = obj.getCurrentColumnSelection();
            
            % Get visible rows based on filter states
            filteredRows = obj.getCurrentRowSelection();
            visibleRows = intersect(filteredRows, visibleRows, 'stable');

            % Get subset of data from metatable that should be put in the
            % uitable.
            tableDataView = obj.MetaTableCell(visibleRows, visibleColumns);

            % Rearrange columns according to current state of the java
            % column model
            [javaColIndex, ~] = obj.ColumnModel.getColumnModelIndexOrder();
            javaColIndex = javaColIndex(1:numel(visibleColumns));
            tableDataView(:, javaColIndex) = tableDataView;
            
            % Assign updated table data to the uitable property
            obj.HTable.Data = tableDataView;
            obj.HTable.Visible = 'on';

            obj.updateColumnLabelFilterIndicator()
            
            % Why????
            if requestFocus
                obj.HTable.JTable.requestFocus()
            end

            drawnow
        end
        
        function updateColumnLayout(obj) %protected
        %updateColumnLayout Update the columnlayout based on user settings
        
            if isempty(obj.ColumnModel); return; end
            if isempty(obj.MetaTable)
                obj.HTable.ColumnName = {''};
                drawnow
                return;
            end
            
            colIndices = obj.ColumnModel.getColumnIndices();
            
            % Set column names
            [columnLabels, variableNames] = obj.ColumnModel.getColumnNames();
            obj.HTable.ColumnName = columnLabels;

            obj.updateColumnEditable()
            
            % Set column widths
            newColumnWidths = obj.ColumnModel.getColumnWidths();
            obj.changeColumnWidths(newColumnWidths)
            
            C = obj.MetaTableCell; % Column format is determined from the cell version of table.
            C = C(:, colIndices);
            T = obj.MetaTable(1,:); % Need to check original data for special data types, i.e enums
            T = T(:, colIndices);
            
            % Return if table has no rows.
            if size(C,1)==0; return; end
            
            % Set column format and formatdata
            dataTypes = cellfun(@(cell) class(cell), C(1,:), 'uni', 0);
            colFormatData = arrayfun(@(i) [], 1:numel(dataTypes), 'uni', 0);
            
            dataTypes(strcmp(dataTypes, 'string')) = {'char'};
            dataTypes(strcmp(dataTypes, 'categorical')) = {'char'};

            % Note, this is done before checking for enum on purpose
            % (Todo: Adapt special enum classes to also use the CompactDisplayProvider...)
            isCustomDisplay = @(x) isa(x, 'matlab.mixin.CustomCompactDisplayProvider');
            isCustomDisplayObj = cellfun(@(cell) isCustomDisplay(cell), table2cell(T(1,:)), 'uni', 1);
            dataTypes(isCustomDisplayObj) = {'char'};

% % %             % Note: Important to reset this before updating. Columns can be
% % %             % rearranged and number of columns can change. If
% % %             % ColumnFormatData does not match the specified column format
% % %             % an error might occur.
% % %             obj.HTable.ColumnFormatData = colFormatData;

            % Enums: (here we need to use non-cell version). Todo: Find
            % better solution...
            isEnumeration = cellfun(@(cell) isenum(cell), table2cell(T(1,:)), 'uni', 1);
            dataTypes(isEnumeration) = {'popup'};
            enumerationIdx = find(isEnumeration);
            for i = enumerationIdx
                enumObject = T{1,i};
                if iscell(enumObject); enumObject = enumObject{1}; end
                [~, m] = enumeration( enumObject ); % need to get enum for original....
                %colFormatData{i} = [C(1,i); m];
                colFormatData{i} = m;
            end

            isCategorical = cellfun(@(cell) iscategorical(cell), table2cell(T(1,:)), 'uni', 1);
            dataTypes(isCategorical) = {'popup'};
            categoricalIdx = find(isCategorical);
            for i = categoricalIdx
                categoricalObject = T{1,i};
                if iscell(categoricalObject); categoricalObject = categoricalObject{1}; end
                if isprotected(categoricalObject)
                    colFormatData{i} = categories(categoricalObject);
                else
                    % colFormatData{i} = categories(categoricalObject);
                    
                    % Add <undefined> as an option for unprotected categoricals
                    % - Question: Does that responsibility lie here or upstream?
                    colFormatData{i} = cat(1, '<undefined>', categories(categoricalObject));
                end
            end

            % All numeric types should be called 'numeric'
            isNumeric = cellfun(@(cell) isnumeric(cell), C(1,:), 'uni', 1);
            dataTypes(isNumeric) = {'numeric'};
            
            isDatetime = cellfun(@(cell) isdatetime(cell), C(1,:), 'uni', 1);
            dataTypes(isDatetime) = {'date'};
            
            % Todo: get from nansen preferences...
            colFormatData(isDatetime) = {'MMM-dd-yyyy    '};

            % NOTE: This is temporary. Need to generalize, not make special
            % treatment for session table

            isVarWithOptions = [obj.MetaTableVariableAttributes.HasOptions];
            isValidType = strcmp([obj.MetaTableVariableAttributes.TableType], obj.MetaTableType);

            customVarNames = {obj.MetaTableVariableAttributes(isVarWithOptions & isValidType).Name};
            [customVarNames, iA] = intersect(variableNames, customVarNames);
            
            for i = 1:numel(customVarNames)
                thisName = customVarNames{i};
                tableVarIndex = strcmp({obj.MetaTableVariableAttributes.Name}, thisName);
                
                popupOptions = obj.MetaTableVariableAttributes(tableVarIndex).OptionsList;

                dataTypes(iA(i)) = {'popup'};
                if isa(popupOptions, 'cell') && numel(popupOptions) == 1
                    colFormatData(iA(i)) = popupOptions;
                else
                    colFormatData(iA(i)) = {popupOptions};
                end
                obj.HTable.ColumnEditable(iA(i)) = true;
            end

            if any(strcmp(dataTypes, 'cell'))
                error('The table contains values that can not be rendered. Please contact support.')
            end
            
            % Update the column formatting properties
            obj.HTable.ColumnFormatData = []; % Reset ColumnFormatData before changing ColumnFormat
            obj.HTable.ColumnFormat = dataTypes;
            obj.HTable.ColumnFormatData = colFormatData;

            % Set column names. Do this last because this will control that
            % the correct number of columns are shown.
            obj.HTable.ColumnName = columnLabels;
            
            % Update indicators for table filters because these are reset
            % when column name is set
            obj.updateColumnLabelFilterIndicator()

            obj.ColumnModel.updateJavaColumnModel()

            % Maybe call this separately???
            %obj.updateTableView()
            
            % Need to update theme...? I should really comment nonsensical
            % stuff better.
            obj.HTable.Theme = obj.HTable.Theme;
        end

        function updateColumnLabelFilterIndicator(obj, filterActive)

            if nargin < 2
                filterActive = obj.ColumnFilter.isColumnFilterActive;
            end

            onColor = '#017100';

            colIndices = obj.ColumnModel.getColumnIndices();
            filterActive = filterActive(colIndices);

            columnNames = obj.ColumnModel.getColumnNames();

            for i = 1:numel(obj.HTable.ColumnName)
                if ~isempty(filterActive) && filterActive(i)
                    columnNames{i} = sprintf('<HTML><FONT color="%s">%s</Font>', onColor, columnNames{i});
                    %columnNames{i} = sprintf('<HTML><FONT
                    %color="%s"><b>%s</Font>', onColor, columnNames{i});
                    %makes very bold
                end
            end
            if ~isempty(columnNames)
                obj.changeColumnNames(columnNames)
            end
        end
        
        function updateColumnEditable(obj)
        %updateColumnEditable Update the ColumnEditable property of table
        %
        %   Set column editable, adjusting for which columns are currently
        %   displayed and whether table should be editable or not.
            
            if isempty(obj.ColumnModel); return; end % On construction...
            
            % Set column editable (By default, none are editable)
            allowEdit = obj.ColumnModel.getColumnIsEditable;
            
            [~, variableNames] = obj.ColumnModel.getColumnNames();
            attributeColumnNames = {obj.MetaTableVariableAttributes.Name};
            [~, ~, iC] = intersect(variableNames, attributeColumnNames, 'stable');
            
            isEditable = [obj.MetaTableVariableAttributes(iC).IsEditable];
            allowEdit = allowEdit & isEditable;

            % Set ignoreFlag to editable if options allow
            columnNames = obj.ColumnModel.getColumnNames();
            if obj.AllowTableEdits
                allowEdit( contains(lower(columnNames), 'ignore') ) = true;
                allowEdit( contains(lower(columnNames), 'description') ) = true;
            else
                allowEdit(:) = false;
            end
                        
            obj.HTable.ColumnEditable = allowEdit;
            
        end
        
        function changeColumnNames(obj, newNames)
            obj.HTable.ColumnName = newNames;
        end % Todo: make dependent property and set method (?)
        
        function changeColumnWidths(obj, newWidths)
            
            if isa(obj.HTable, 'uim.widget.StylableTable')
                % Use custom method of table model to set column width.
                obj.HTable.changeColumnWidths(newWidths)
            else
                obj.HTable.ColumnWidth = newWidths;
            end
            
        end % Todo: make dependent property and set method (?)
        
        function changeColumnToShow(obj)
            
        end % Todo: make dependent property and set method (?)
        
        function changeColumnOrder(obj)
            % todo howdo
        end
    end
    
    methods (Access = private) % Update table & internal housekeeping
                
        function onMetaTableSet(obj, newTable)
        %onMetaTableSet Internal callback for when the MetaTable property
        %is set.
        %
        % Need to store the metatable as a cell array for presenting it in
        % the UI table. (Relevant mostly for MetaTable objects because they
        % might contain column data that needs to be formatted.
            
        % Todo: count number of columns of old and new;
        % compare column names. If changed, reset/update column model...

            if isa(newTable, 'nansen.metadata.MetaTable')
                T = newTable.getFormattedTableData();
                obj.MetaTableType = lower( newTable.getTableType() );
                obj.MetaTableCell = table2cell(T);
            elseif isa(newTable, 'table')
                obj.MetaTableCell = table2cell(newTable);
            end

            % Update metatable variable attributes.
            S = obj.getMetaTableVariableAttributes();
            obj.MetaTableVariableAttributes = S;
        end
        
        function onMetaTableTypeSet(obj, oldType, newType)
            obj.RequireReset = ~strcmp(oldType, newType);
        end

        function onTableVariableAttributesFcnSet(obj)
            S = obj.getMetaTableVariableAttributes();
            obj.MetaTableVariableAttributes = S;
            if obj.IsConstructed
                obj.updateColumnLayout()
            end
        end

        function onTableFontSizeSet(obj)
            if ~isempty(obj.HTable)
                obj.HTable.FontSize = obj.TableFontSize;
                obj.HTable.RowHeight = obj.TableFontSize + 20;
            end
        end

        function onColumnFilterSet(obj)
        %onColumnFilterSet Callback for property value set.
            if ~isempty(obj.FilterChangedListener)
                delete(obj.FilterChangedListener)
            end
            
            obj.FilterChangedListener = addlistener(obj.ColumnFilter, ...
                'FilterUpdated', @obj.onFilterUpdated);
        end
        
        function onFilterUpdated(obj, src, evt)
        %onFilterUpdated Callback for table filter update events
            
            obj.updateTableView([], false)
            
            if ~isempty(obj.ExternalFilterMap)
                visibleRows = find( obj.ExternalFilterMap );
            else
                visibleRows = 1:size(obj.MetaTableCell, 1);
            end
            
            rows = obj.getCurrentRowSelection();
            rows = intersect(rows, visibleRows, 'stable');
            
            evtdata = uiw.event.EventData('RowIndices', rows, 'Type', 'TableFilterUpdate');
            obj.notify('TableUpdated', evtdata)
        end
        
        function rowInd = getCurrentRowSelection(obj)
            % Get row indices that are visible in the uitable

            % Initialize the data filter map if it is empty.
            [numRows, numColumns] = size(obj.MetaTableCell);
            if isempty(obj.DataFilterMap)
                obj.DataFilterMap = true(numRows, numColumns);
            end
            
            % Remove ignored entries based on preference in settings.
            if ~obj.ShowIgnoredEntries
                
                varNames = obj.MetaTable.Properties.VariableNames;
                
                isIgnoreColumn = contains(lower(varNames), 'ignore');
                if any(isIgnoreColumn)
                
                    isIgnored = [ obj.MetaTableCell{:, isIgnoreColumn} ];
                
                    % Negate values of the ignore flag in the filter map
                    obj.DataFilterMap(:, isIgnoreColumn) = ~isIgnored;
                end
            end
            
            % Get indices for rows where all cells in the map are true
            rowInd = find( all(obj.DataFilterMap, 2) );
            
            if ~isempty(obj.ExternalFilterMap)
                rowInd = intersect(rowInd, find(obj.ExternalFilterMap), 'stable');
            end
        end
        
        function colInd = getCurrentColumnSelection(obj)
            % Get column indices that are visible in the uitable
            if isempty(obj.ColumnModel); return; end % On construction...
            
            colInd = obj.ColumnModel.getColumnIndices();
        end

        function S = getMetaTableVariableAttributes(obj)
        % Get metatable variable attributes based on table type.

            if ~isempty(obj.GetTableVariableAttributesFcn)
                S = obj.GetTableVariableAttributesFcn(obj.MetaTableType);
            else
                S = obj.getDefaultMetaTableVariableAttributes();
            end
        end
        
        function S = getDefaultMetaTableVariableAttributes(obj)
        %Get default table variable attributes from TableVariable class.
            import nansen.metadata.abstract.TableVariable;
            
            varNames = obj.MetaTable.Properties.VariableNames;
            numVars = numel(varNames);
            S = TableVariable.getDefaultTableVariableAttribute();
            S = repmat(S, 1, numVars);
            
            % Fill out names and table type
            [S(1:numVars).Name] = varNames{:};
            [S(1:numVars).TableType] = deal(obj.MetaTableType);
        end
    end
 
    methods (Access = private) % Mouse / user event callbacks
        
        function onHeaderPressTimerRunOut(obj, src, evt)
            
            if isempty(obj.ColumnPressedTimer)
                return
            end
            
            stop(obj.ColumnPressedTimer)
            delete(obj.ColumnPressedTimer)
            obj.ColumnPressedTimer = [];
            
            clickPosX = get(evt, 'X');
            clickPosY = get(evt, 'Y');
            obj.openColumnFilter(clickPosX, clickPosY)
            
        end

        function onMousePressedInHeader(obj, src, evt)
        %onMousePressedInHeader Handles mouse press in the table header.

            buttonNum = get(evt, 'Button');
            if get(evt,'Modifiers')==18,
                buttonNum = 3;
            end;            
            obj.lastMousePressTic = tic;

            % Need to call this to make sure filterdropdowns disappear if
            % mouse is pressed in column header...
            obj.ColumnFilter.hideFilters();
            
            % Check the cursor type of the mouse pointer. If it equals 11,
            % it corresponds with the special case when the pointer is
            % clicked on the border between to columns. In this case, abort.
            if obj.HTable.JTable.getTableHeader().getCursor().getType() == 11
                return
            end
            
            % The action of pressing and holding for a split second should
            % open the column filter. This is managed by a timer, and here,
            % if a timer is not already active we start it and set the
            % sortable to false
            if buttonNum == 1 && get(evt, 'ClickCount') == 1
                
                if isempty(obj.ColumnPressedTimer)
                    obj.ColumnPressedTimer = timer();
                    obj.ColumnPressedTimer.Period = 1;
                    obj.ColumnPressedTimer.StartDelay = 0.25;
                    obj.ColumnPressedTimer.TimerFcn = @(s,e) obj.onHeaderPressTimerRunOut(s, evt);
                    start(obj.ColumnPressedTimer)
                    obj.HTable.JTable.getModel().setSortable(0)
                end
                
            % For right clicks, open the context menu.
            elseif buttonNum == 3 %rightclick
                
                % These are coords in table
                clickPosX = get(evt, 'X');
                clickPosY = get(evt, 'Y');
                
                % todo: get column header x- and y positions in figure.
                obj.openColumnContextMenu(clickPosX, clickPosY);
            end
        end
        
        function onMouseDraggedInTableHeader(obj, src, evt)
            
            if ~isempty( obj.ColumnPressedTimer )
                % Simulate mouse release to cancel the timer
                obj.onMouseReleasedFromHeader([], [])
            end
            
            dPos = (evt.MousePointCurrent -  evt.MousePointStart);
            dS = sqrt(sum(dPos.^2));
            
            if dS > 10
                if ~isempty(obj.ColumnFilter)
                    obj.ColumnFilter.hideFilters();
                end
            end
        end
        
        function onMouseReleasedFromHeader(obj, src, evt)
                        
            if ~isempty(obj.ColumnPressedTimer)
                stop(obj.ColumnPressedTimer)
                delete(obj.ColumnPressedTimer)
                obj.ColumnPressedTimer = [];
                
                % Mouse was released before 1 second passed.
                obj.HTable.JTable.getModel().setSortable(1)
            end
        end
        
        function onMousePressedInTable(obj, src, evt)
        %onMousePressedInTable Callback for mousepress in table.
        %
        %   This function is primarily used for
        %       1) Creating an action on doubleclick
        %       2) Selecting cell on right click

            % Return if instance is not valid.
            if ~exist('obj', 'var') || ~isvalid(obj); return; end

            obj.ColumnFilter.hideFilters()
            if isempty(obj.MetaTable); return; end
            obj.updateColumnEditable()

            if strcmp(evt.SelectionType, 'normal')
                % Do nothing.
                % Get row where mouse press occurred.
                row = evt.Cell(1); col = evt.Cell(2);
                if row == 0 || col == 0
                    obj.HTable.SelectedRows = [];
                    
                    % Make sure editable cell is not in focus when editing
                    % is stopped, because it will be rendered with a black
                    % background.
                    colIdx = find( ~obj.HTable.ColumnEditable, 1, 'first');
                    
                    cellEditor = obj.HTable.JTable.getCellEditor();
                    if ~isempty( cellEditor )
                        cellEditor.stopCellEditing();
                    end

                    selectionModel = obj.HTable.JTable.getColumnModel.getSelectionModel;

                    if ~isempty(colIdx)
                        % Give focus to a non-editable cell.
                        set(selectionModel, 'LeadSelectionIndex', colIdx-1)
                    else
                        % Set selection index to something near guaranteed
                        % to not be in the current table (if no cells are
                        % non-editable)
                        set(selectionModel, 'LeadSelectionIndex', 9999)
                    end
                end
                    
            elseif strcmp(evt.SelectionType, 'open')
            
                if ~isempty(obj.MouseDoubleClickedFcn)
                    obj.MouseDoubleClickedFcn(src, evt)
                else
                    obj.onMouseDoubleClickedInTable(src, evt)
                end
                
                % Todo:
                % Double click action should depend on which column click
                % happens over.

% %                     if isequal(get(event, 'button'), 3)
% %                         return
% %                     end
% %
% %                     currentFields = app.tableSettings.FieldNames(app.tableSettings.FieldsToShow);
% %                     so = retrieveSessionObject(app, app.highlightedSessions(end));
% %
% %                     if numel(app.highlightedSessions) > 1
% %                         warning('Multiple sessions, selected, operation applies to last session only.')
% %                     end
% %
% %                     if strcmp(currentFields{j+1}, 'Notes')
% %                         app.showNotes(so.sessionID)
% %                     else
% %                         %so.openFolder
% %                         openFolder(so.sessionID, 'datadrive', 'processed')
% %                     end
                    
            elseif evt.Button == 3 || strcmp(evt.SelectionType, 'alt')
                
                if ismac && evt.Button == 1 && evt.MetaOn
                    return % Command click on mac should not count as right click
                end

                if ispc && evt.Button == 1 && evt.ControlOn
                    return % Control click on windows should not count as right click
                end

                % Get row where mouse press occurred.
                row = evt.Cell(1); col = evt.Cell(2);
                
                % Select row where mouse is pressed if it is not already
                % selected
                if ~ismember(row, obj.HTable.SelectedRows)
                    if row > 0 && col > 0
                        obj.HTable.SelectedRows = row;
                    else
                        obj.HTable.SelectedRows = [];
                        return
                    end
                end

                % Open context menu for table
                if ~isempty(obj.TableContextMenu)
                    position = obj.getTableContextMenuPosition(evt.Position);
                    obj.openTableContextMenu(position(1), position(2));
                end
            end
        end  
                    
        function onMouseDoubleClickedInTable(obj, src, evt)
        % onMouseDoubleClickedInTable - Callback for double clicks
        %
        %   Check if the currently selected column has an associated table
        %   variable definition with a double click callback function.

            thisRow = evt.Cell(1); % Clicked row index
            thisCol = evt.Cell(2); % Clicked column index
            
            if thisRow == 0 || thisCol == 0
                return
            end
            
            % Get name of column which was clicked
            thisColumnName = obj.getColumnNames(thisCol);

            % Use table variable attributes to check if a double click 
            % callback function exists for the current table column
            TVA = obj.MetaTableVariableAttributes([obj.MetaTableVariableAttributes.HasDoubleClickFunction]);
            
            isMatch = strcmp(thisColumnName, {TVA.Name});

            if any( isMatch )
                tableVariableFunctionName = TVA(isMatch).RendererFunctionName;
                
                if ~isempty(tableVariableFunctionName)
                    tableRowIdx = app.UiMetaTableViewer.getMetaTableRows(thisRow); % Visible row to data row transformation
                    tableValue = app.MetaTable.entries{tableRowIdx, thisColumnName};
                    tableVariableObj = feval(tableVariableFunctionName, tableValue);
                    
                    tableRowData = app.MetaTable.entries(tableRowIdx,:);
                    metaObj = app.tableEntriesToMetaObjects( tableRowData );
                    tableVariableObj.onCellDoubleClick( metaObj );
                else
                    if isa(TVA(isMatch).DoubleClickFunctionName, 'function_handle')
                        TVA(isMatch).DoubleClickFunctionName()
                    else
                        error('Not supported')
                    end
                end
            end
        end
        

        function onMouseMotionInTable(obj, src, evt)
            % This functionality is put in the nansen app for now.
        end
        
        function onCellValueEdited(obj, src, evtData)
        %onCellValueEdited Callback for value change in cell
        %
        %   1) Update original table data
        %   2) Modify evtData and pass on to class' CellEditCallback
            
        % Todo: For time being (oct2021) the only editable column is the
        % ignore flag column. Should refresh the table if ignore rows are
        % set to hidden, but for now, the ignored rows will disappear on
        % next table update.
        
            % Get currently visible row and column indices.
            rowInd = obj.getCurrentRowSelection();
            colInd = obj.getCurrentColumnSelection();
            
            % Get row and column indices for original data (unfiltered, unsorted, allcolumns)
            tableRowInd = rowInd(evtData.Indices(1));
            
            evtColIdx = obj.ColumnModel.getColumnIdx( evtData.Indices(2) ); % 2 is for columns
            tableColInd = colInd(evtColIdx);
            
            % Todo: Implement this, if dropdown contains actionable options
            % formatted like this: <action name>
            % % newValue = evtData.NewValue;
            % % if startsWith(newValue, '<') && endsWith(newValue, '>')
            % %     evtData.NewValue = [];
            % % end
            
            % Update value in table and table cell array
            %obj.MetaTable(tableRowInd, tableColInd) = {evtData.NewValue};
            obj.MetaTableCell{tableRowInd, tableColInd} = evtData.NewValue;
            
            % Invoke external callback if it is assigned.
            if ~isempty( obj.CellEditCallback )
                evtData.Indices = [tableRowInd, tableColInd];
                obj.CellEditCallback(src, evtData)
            end
        end
        
        function onCellSelectionChanged(obj, src, evt)
            %evtData = event.EventData;
            evtData = uiw.event.EventData('SelectedRows', evt.SelectedRows);
            obj.notify('SelectionChanged', evtData)
        end
        
        function onColumnWidthChanged(obj, src, event)
        %onColumnWidthChanged Callback for events where column widths are
        %changed by resizing column widths in from gui.
            obj.ColumnModel.setColumnWidths(obj.HTable.ColumnWidth)
        end
        
        function onColumnsRearranged(obj, src, evt)
        %onColumnsRearranged Callback for event when columns are rearranged
        %
        % This event is triggered when user drags columns to rearrange
            
            % Tell columnmodel of new order...
            newColumnArrangement = obj.HTable.getColumnOrder;
            obj.ColumnModel.setNewColumnOrder(newColumnArrangement)
                        
            if ~isempty(obj.ColumnFilter)
                obj.ColumnFilter.hideFilters();
            end
        end
        
        function columnIdx = getColumnAtPoint(obj, x, y)
        %getColumnAtPoint Returns the column index at point (x,y)
        %
        %   Conversion from java to matlab:
            
            mPos = java.awt.Point(x, y);
            columnIdx = obj.HTable.JTable.columnAtPoint(mPos) + 1;
            % Note, java indexing starts at 0, so added 1.
            
        end
        
        function position = getTableContextMenuPosition(obj, eventPosition)
        %getTableContextMenuPosition Get cmenu position from event position
        
            % Get scroll positions in table
            xScroll = obj.HTable.getHorizontalScrollOffset();
            yScroll = obj.HTable.getVerticalScrollOffset();
                        
            % Get position where mouseclick occurred (in figure)
            clickPosX = eventPosition(1) - xScroll;
            clickPosY = eventPosition(2) - yScroll;
            
            % Convert to position inside table
            tablePosition = getpixelposition(obj.HTable, true);
            tableLocationX = tablePosition(1);
            tableHeight = tablePosition(4);
            
            positionX = clickPosX + tableLocationX + 1; % +1 because ad hoc...
            % obj.HTable.RowHeight??
            positionY = tableHeight - clickPosY + 19; % +15 because ad hoc... size of table header?
            position = [positionX, positionY];
            
        end
        
        function figureCoords = javapoint2figurepoint(obj, javaCoords)
        %javapoint2figurepoint Find coordinates of point in figure units
        %
        %   figureCoords = javapoint2figurepoint(obj, javaCoords) returns
        %   figureCoords ([x,y]) of point in figure (measured from lower
        %   left corner) based on javaCoords ([x,y]) from a java mouse
        %   event in the table (measured from upper left corner in table).
        
            % Note:
            % x is position measured from left inside table
            % y is position measured from top inside table

            % Get pixel position of table referenced in figure.
            tablePosition = getpixelposition(obj.HTable, true);
            
            x0 = tablePosition(1);
            y0 = tablePosition(2);
            tableHeight = tablePosition(4);
            
            xPosition = x0 + javaCoords(1);
            yPosition = y0 + tableHeight - javaCoords(2);
             
            figureCoords = [xPosition, yPosition];
            
        end
        
        function openColumnContextMenu(obj, x, y)
            
            colNumber = obj.getColumnAtPoint(x, y);
            if colNumber == 0; return; end
            
            if isempty(obj.ColumnContextMenu)
                obj.createColumnContextMenu()
            end
            
            % Get column name of column where context menu should open
            [~, varNames] = obj.ColumnModel.getColumnNames();
            currentColumnName = varNames{colNumber};
            
            % Get column number according to the underlying java column
            % models column order.
            [colIdxJava, ~] = obj.ColumnModel.getColumnModelIndexOrder();
            colNumber = colIdxJava(colNumber);
            
            columnType = obj.HTable.ColumnFormat{colNumber};
            
            isMatch = strcmp( {obj.MetaTableVariableAttributes.Name}, currentColumnName ) & ...
                contains([obj.MetaTableVariableAttributes.TableType], obj.MetaTableType, 'IgnoreCase', true);
            if any(isMatch)
                varAttr = obj.MetaTableVariableAttributes(isMatch);
            else
                error('Variable attributes does not exist. This is unexpected.')
            end
            
            % Select appearance of context menu based on column type:
            for i = 1:numel(obj.ColumnContextMenu.Children)
                hTmp = obj.ColumnContextMenu.Children(i);
                
                switch hTmp.Tag
                    case 'Sort Ascend'
                        switch columnType
                            case 'char'
                                hTmp.Label = 'Sort A-Z';
                            case 'numeric'
                                hTmp.Label = 'Sort low-high';
                            case 'logical'
                                hTmp.Label = 'Sort false-true';
                        end
                        hTmp.Callback = @(s,e,iCol,dir) obj.sortColumn(colNumber,'ascend');

                    case 'Sort Descend'
                        switch columnType
                            case 'char'
                                hTmp.Label = 'Sort Z-A';
                            case 'numeric'
                                hTmp.Label = 'Sort high-low';
                            case 'logical'
                                hTmp.Label = 'Sort true-false';
                        end
                        hTmp.Callback = @(s,e,iCol,dir) obj.sortColumn(colNumber,'descend');
                        
                    case 'Filter'
                        hTmp.Callback = @(s,e,iCol) obj.filterColumn(colNumber);
                    case 'Reset Filters'
                        hTmp.Callback = @(s,e,iCol) obj.resetColumnFilters();
                        
                    case 'Hide Column'
                        hTmp.Callback = @(s,e,iCol) obj.hideColumn(colNumber);
                        
                    case 'Update Column'
                        if varAttr.HasUpdateFunction % (Does it have to be custom?)% varAttr.IsCustom && varAttr.HasUpdateFunction
                            hTmp.Enable = 'on';
                            if ~isempty(obj.UpdateColumnFcn)
                                % Children are reversed from creation
                                hTmp.Children(1).Callback = @(s,e,name) obj.EditColumnFcn(currentColumnName);
                                hTmp.Children(2).Callback = @(name, mode) obj.ResetColumnFcn(currentColumnName, 'AllRows');
                                hTmp.Children(3).Callback = @(name, mode) obj.ResetColumnFcn(currentColumnName, 'SelectedRows');
                                hTmp.Children(4).Callback = @(name, mode) obj.UpdateColumnFcn(currentColumnName, 'AllRows');
                                hTmp.Children(5).Callback = @(name, mode) obj.UpdateColumnFcn(currentColumnName, 'SelectedRows');
                            end
                        else
                            hTmp.Enable = 'off';
                        end
                        
                    case 'Delete Column'
                        if varAttr.IsCustom
                            hTmp.Enable = 'on';
                            if ~isempty(obj.DeleteColumnFcn)
                                hTmp.Callback = @(colName, evt) obj.DeleteColumnFcn(currentColumnName);
                            end
                        else
                            hTmp.Enable = 'off';
                        end
                        
                    otherwise
                        % Do nothing
                end
            end

            % Get the coordinates for where to show the context menu
            figurePoint = obj.javapoint2figurepoint([x, y]);
            
            % Adjust for the horizontal scroll position in the table.
            xOff = obj.HTable.getHorizontalScrollOffset();
            figurePoint = figurePoint - [xOff, 0];
            
            % Set position and make menu visible.
            obj.ColumnContextMenu.Position = figurePoint;
            obj.ColumnContextMenu.Visible = 'on';
            
        end
        
        function openTableContextMenu(obj, x, y)
            
            if isempty(obj.TableContextMenu); return; end

            % Set position and make menu visible.
            obj.TableContextMenu.Position = [x,y];
            obj.TableContextMenu.Visible = 'on';
            
        end
        
        function openColumnFilter(obj, x, y)
        %openColumnFilter Open column filter as dropdown below column header
            
            tableColumnIdx = obj.getColumnAtPoint(x, y);
            if tableColumnIdx == 0; return; end
            
            colIndices = obj.ColumnModel.getColumnIndices();
            dataColumnIndex = colIndices(tableColumnIdx);
            
            obj.ColumnFilter.openFilterControl(dataColumnIndex)

        end
        
        function filterColumn(obj, columnNumber)
        %filterColumn Open column filter in sidepanel
        
            colIndices = obj.ColumnModel.getColumnIndices();
            dataColumnIndex = colIndices(columnNumber);
            
            obj.ColumnFilter.openFilterControl(dataColumnIndex)
            obj.AppRef.showSidePanel()
            
        end
        
        function sortColumn(obj, columnIdx, sortDirection)
        %sortColumn Sort column in specified direction
            sortAscend = strcmp(sortDirection, 'ascend');
            sortDescend = strcmp(sortDirection, 'descend');
            
            obj.HTable.JTable.sortColumn(columnIdx-1, 1, sortAscend)

        end
        
        function hideColumn(obj, columnNumber)
        	obj.ColumnModel.hideColumn(columnNumber);
        end
    end
    
    methods (Static)
        
        function tf = isValidTableClass(var)
        %isValidTable Test if var satisfies the list of valid table classes
            VALID_CLASSES = nansen.MetaTableViewer.VALID_TABLE_CLASS;
            tf = any(cellfun(@(type) isa(var, type), VALID_CLASSES));
        end
    end
end
