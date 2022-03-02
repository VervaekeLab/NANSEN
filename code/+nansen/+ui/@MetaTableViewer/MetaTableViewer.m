classdef MetaTableViewer < handle & uiw.mixin.AssignPVPairs

    
% - - - - - - - - - - - - - - - TODO - - - - - - - - - - - - - - - - -
    %   [ ] Make ignore column editable 
    %   [x] Set method for metaTable...
    %   [x] Revert change from metatable. need to get formatted data from
    %       table!
    %   [ ] Should the filter be a RowModel? 
    %   [ ] Straighten out what to do about the MetaTable property.
    %       Problem: if the input metatable was a MetaTable object, it
    %       might contain data which is not renderable in the uitable, i.e
    %       structs. If table data is changed, and data is put back into
    %       the table version of the MetaTable, the set.MetaTable methods
    %       creates a downstream bug because is sets it and consequently
    %       the MetaTableCell property without getting formatted data from
    %       the metatable class. For now, I keep as it is, because the only
    %       column I edit is the ignore column, and the MEtaTable property
    %       is not used anywhere. But this can be a BIG PROBLEM if things
    %       change some time.
    
% - - - - - - - - - - - - - - PROPERTIES - - - - - - - - - - - - - - - 

    properties (Constant, Hidden)
        VALID_TABLE_CLASS = {'nansen.metadata.MetaTable', 'table'};
    end
    
    properties % Table preferences
        ShowIgnoredEntries = true
        AllowTableEdits = true
    end
    
    properties
        SelectedEntries         % Selected rows from full table, irrespective of sorting and filtering.
        CellEditCallback
        KeyPressCallback
    end
    
    properties (SetAccess = private, SetObservable = true)
        MetaTable               % Table version of the table data
        MetaTableCell cell      % Cell array version of the table data
        MetaTableVariableNames  % Cell array of variable names in full table
    end
    
    properties %(Access = private)
        ColumnModel             % Class instance for updating columns based on user preferences.
        ColumnFilter            % Class instance for filtering data based on column variables.
        
        DisplayedRows % Rows of the original metatable which are currently displayed
        DisplayedColumns % Columns of the original metatable which are currently displayed
        
        AppRef
        Parent
        HTable
        JTable
        
        ColumnContextMenu = []
        
        DataFilterMap = []
        ColumnWidthChangedListener
    end
    
    properties (Access = private)
        isConstructed = false;
    end
    
% - - - - - - - - - - - - - - - METHODS - - - - - - - - - - - - - - - 
    
    methods % Structors
        
        function obj = MetaTableViewer(varargin)
            
            % Take care of input arguments.
            obj.parseInputs(varargin)
            
            % Initialize the column model.
            obj.ColumnModel = nansen.ui.MetaTableColumnLayout(obj);
            
            obj.createUiTable()
            
            if ~isempty(obj.MetaTableCell)
                obj.refreshTable()
                obj.HTable.Visible = 'on'; % Make table visible
                drawnow
            end

        % % % Todo: Uncomment this (it was commented out when implementing roi table, dont remember why)
           %  obj.ColumnFilter = nansen.ui.MetaTableColumnFilter(obj, obj.AppRef);

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
        
        function set.KeyPressCallback(obj, newValue)
            
        end
    end
        
    methods % Public methods
        
        function refreshTable(obj, newTable)
        %refreshTable Method for refreshing the table
        
            currentTable = obj.MetaTable;
        
            if nargin == 2
                obj.MetaTable = newTable;
            else
                fprintf('Print message if this case occurs...\n')
            end
            
            % only update column layout if number of columns change
            if size(newTable, 2) ~= size(currentTable, 2)
                obj.updateColumnLayout()
            elseif size(currentTable, 1) == 0
                obj.updateColumnLayout()
            end
            
            obj.DataFilterMap = []; % reset data filter map
            obj.updateTableView()
            
        end
        
        function IND = getSelectedEntries(obj)
            
            IND = obj.HTable.SelectedRows;
            
            dataInd = get(obj.HTable.JTable.Model, 'Indexes');

            if ~isempty(dataInd)
                IND = dataInd(IND)+1; % +1 because java indices start at 0
                IND = transpose( double( sort(IND) ) ); % return as row vector
            else
                IND = IND; 
            end
            
        end
        
        function setSelectedEntries(obj, IND)
        %setSelectedEntries Set row selection
        
            dataInd = obj.HTable.RowSortIndex;
            selectedRows = find(ismember(dataInd, IND));

            if isempty(selectedRows)
                selectedRows = IND;
            end
            
            obj.HTable.SelectedRows = selectedRows;
            
        end

    end
   
    methods (Access = private) % Create components
        
        function parseInputs(obj, listOfArgs)
         %parseInputs Input parser that checks for expected input classes
         
            if isempty(listOfArgs);    return;    end
            
            % Check if first argument is a graphical container
            % Todo: check that graphical object is an actual container...
            if isgraphics(listOfArgs{1})
                obj.Parent = listOfArgs{1};
                listOfArgs = listOfArgs(2:end);
            end
            
            if isempty(listOfArgs);    return;    end

            % Check if first argument in list is a valid metatable class
            if obj.isValidTableClass( listOfArgs{1} )
                obj.MetaTable = listOfArgs{1};
                listOfArgs = listOfArgs(2:end);
            end
            
            if isempty(listOfArgs);    return;    end

            % Assume rest of inputs are name value pairs
            obj.assignPVPairs(listOfArgs{:})
            
        end
        
        function createUiTable(obj)
            
            for i = 1:2
            
                try
                    obj.HTable = uim.widget.StylableTable(...
                        'Parent', obj.Parent,...
                        'Tag','MetaTable',...
                        'Editable', true, ...
                        'RowHeight', 30, ...
                        'FontSize', 8, ...
                        'FontName', 'helvetica', ...
                        'FontName', 'avenir next', ...
                        'SelectionMode', 'discontiguous', ...
                        'Sortable', true, ...
                        'Units','normalized', ...
                        'Position',[0 0.0 1 1], ...
                        'HeaderPressedCallback', @obj.onMousePressedInHeader, ...
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
            
            obj.HTable.CellEditCallback = @obj.onCellValueEdited;
            
            % Listener that detects if column widths change if user drags
            % column headers edges to resize columns.
            el = listener(obj.HTable, 'ColumnWidthChanged', ...
                @obj.onColumnWidthChanged);
            obj.ColumnWidthChangedListener = el;
            
            obj.HTable.Theme = uim.style.tableLight;
            
        end
        
        function createColumnContextMenu(obj)
            
            hFigure = ancestor(obj.Parent, 'figure');
            
            % Create a context menu item for each of the different column
            % formats.

            obj.ColumnContextMenu = uicontextmenu(hFigure);
            
            % Create items of the menu for columns of char type
            hTmp = uimenu(obj.ColumnContextMenu, 'Label', 'Sort A-Z');
            hTmp.Tag = 'Sort Ascend';
            
            hTmp = uimenu(obj.ColumnContextMenu, 'Label', 'Sort Z-A');
            hTmp.Tag = 'Sort Descend';
            
            hTmp = uimenu(obj.ColumnContextMenu, 'Label', 'Filter...');
            hTmp.Tag = 'Filter';
            hTmp.Separator = 'on';
            
            hTmp = uimenu(obj.ColumnContextMenu, 'Label', 'Hide this column');
            hTmp.Tag = 'Hide Column';
            hTmp.Separator = 'on';
            
            hTmp = uimenu(obj.ColumnContextMenu, 'Label', 'Column settings...');
            hTmp.Tag = 'ColumnSettings';
            hTmp.MenuSelectedFcn = @(s,e) obj.ColumnModel.editSettings;
            
        end
        
        function createColumnFilterComponents(obj)
            % todo
        end
        
    end
    
    methods (Access = {?nansen.ui.MetaTableViewer, ?nansen.ui.MetaTableColumnLayout, ?nansen.ui.MetaTableColumnFilter})
           
        function updateColumnLayout(obj) %protected

            if isempty(obj.ColumnModel); return; end
            
            colIndices = obj.ColumnModel.getColumnIndices();
            %numColumns = numel(colIndices);
            
            % Set column names
            columnNames = obj.ColumnModel.getColumnNames();
            if ~isequal(columnNames, obj.HTable.ColumnName)
                obj.HTable.ColumnName = columnNames;
            end
            
            obj.updateColumnEditable()
            
            
            % Set column widths
            newColumnWidths = obj.ColumnModel.getColumnWidths();
            obj.changeColumnWidths(newColumnWidths)
            
            % Set column format            
            T = obj.MetaTableCell; % Column format is determied for the cell version of table.
            T = T(:, colIndices);
            
            if size(T,1)==0
                return; 
            end
            
            % Make sure data types are valid types for the
            % uiw.widgets.Table
            dataTypes = cellfun(@(cell) class(cell), T(1,:), 'uni', 0);
            isNumeric = cellfun(@(cell) isnumeric(cell), T(1,:), 'uni', 1);
            isString =  cellfun(@(cell) isstring(cell), T(1,:), 'uni', 1);

            dataTypes(isNumeric) = {'numeric'};
            dataTypes(isString) = {'char'};

            obj.HTable.ColumnFormat = dataTypes;

            % Maybe call this separately???
            %obj.updateTableView()
            
            % Need to update theme...? I should really comment nonsensical
            % stuff better.
            obj.HTable.Theme = obj.HTable.Theme;

        end
        
        function updateTableView(obj)

            if isempty(obj.ColumnModel); return; end % On construction...
            
            % Todo: Get based on user selection of which columns to display
            columns = obj.getCurrentColumnSelection();
            
            % Todo: Get based on filter states
            rows = obj.getCurrentRowSelection(); 

            % Table data should already be formatted
            obj.HTable.Data = obj.MetaTableCell(rows, columns);
            obj.HTable.Visible = 'on';
            drawnow
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

        function updateColumnEditable(obj)
        %updateColumnEditable Update the ColumnEditable property of table
        %
        %   Set column editable, adjusting for which columns are currently
        %   displayed and whether table should be editable or not.
            
            if isempty(obj.ColumnModel); return; end % On construction...
        
            columnNames = obj.ColumnModel.getColumnNames();
            numColumns = numel(columnNames);

            % Set column editable (By default, none are editable)
            allowEdit = false(1, numColumns);
            
            % Set ignoreFlag to editable if options allow
            if obj.AllowTableEdits
                allowEdit( contains(lower(columnNames), 'ignore') ) = true;
            end
            
            obj.HTable.ColumnEditable = allowEdit;
            
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
        
            if isa(newTable, 'nansen.metadata.MetaTable')
                T = newTable.getFormattedTableData();
                obj.MetaTableCell = table2cell(T);
            elseif isa(newTable, 'table')
                obj.MetaTableCell = table2cell(newTable);
            end
            
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
        end
        
        function colInd = getCurrentColumnSelection(obj)
            % Get column indices that are visible in the uitable
            if isempty(obj.ColumnModel); return; end % On construction...
            
            colInd = obj.ColumnModel.getColumnIndices();
        end
        
    end
 
    methods (Access = private) % Mouse / user event callbacks
        
        function onMousePressedInHeader(obj, src, evt)
            
            buttonNum = get(evt, 'Button');
            
            if buttonNum == 3 %rightclick
                
                % These are coords in table
                clickPosX = get(evt, 'X');
                clickPosY = get(evt, 'Y');
                
                % todo: get column header x- and y positions in figure.
                
                obj.openColumnContextMenu(clickPosX, clickPosY);
            end
            
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
            tableColInd = colInd(evtData.Indices(2));
            
            % Update value in table and table cell array
            %obj.MetaTable(tableRowInd, tableColInd) = {evtData.NewValue};
            obj.MetaTableCell{tableRowInd, tableColInd} = evtData.NewValue;
            
            % Invoke external callback if it is assigned.
            if ~isempty( obj.CellEditCallback )
                evtData.Indices = [tableRowInd, tableColInd];
                obj.CellEditCallback(src, evtData)
            end
        end
        
        function onColumnWidthChanged(obj, src, event)
        %onColumnWidthChanged Callback for events where column widths are
        %changed by resizing column widths in from gui.
            obj.ColumnModel.setColumnWidths(obj.HTable.ColumnWidth)
        end
        
        function openColumnContextMenu(obj, x, y)
            
            if isempty(obj.ColumnContextMenu)
                obj.createColumnContextMenu()
            end
            
            mPos = java.awt.Point(x,y);
            
            % Todo: select appearance of context menu based on column type.
            colNumber = obj.HTable.JTable.columnAtPoint(mPos) + 1; % Note, java indexing starts at 0.
            columnType = obj.HTable.ColumnFormat{colNumber};
            
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
                        
                    case 'Hide Column'
                        hTmp.Callback = @(s,e,iCol) obj.hideColumn(colNumber);
                        
                    otherwise
                        % Do nothing
                end
            end
            
            
            % Determine the coordinates within the figure where the context
            % menu should be made visible.
            xOff = obj.HTable.getHorizontalScrollOffset();
            
            tablePosition = getpixelposition(obj.HTable, true);
            y = tablePosition(4);
            
            x = x + tablePosition(1);
            y = y + tablePosition(2);
            
            % Set position and make menu visible.
            obj.ColumnContextMenu.Position = [x+10-xOff,y-20];
            obj.ColumnContextMenu.Visible = 'on';
            
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
        
        function filterColumn(obj, columnNumber)
            
            colIndices = obj.ColumnModel.getColumnIndices();
            dataColumnIndex = colIndices(columnNumber);
            
            obj.ColumnFilter.openFilterControl(dataColumnIndex)            
            obj.AppRef.showSidePanel()
        end
    end
    
    methods (Static)
        
        function tf = isValidTableClass(var)
        %isValidTable Test if var satisfies the list of valid table classes
            VALID_CLASSES = nansen.ui.MetaTableViewer.VALID_TABLE_CLASS;
            tf = any(cellfun(@(type) isa(var, type), VALID_CLASSES));
        end
        
    end
    
end