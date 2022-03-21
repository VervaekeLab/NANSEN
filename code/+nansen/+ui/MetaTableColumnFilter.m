classdef MetaTableColumnFilter < handle
    
    
    properties
        AppReference
        ComponentPanel 
        
        hColumnFilterPopups
        
        columnFilterType
        isColumnFilterActive
        isColumnFilterDirty 
        
    end
    
    properties (SetAccess = immutable)
        PopupLocation = 'header'; %'sidebar'
    end
    
    properties (Dependent, SetAccess = private)
    	MetaTable   % Meta table data (depends on metatable viewer obj)
    end
    
    properties (SetAccess = private) %?
        % Question: Is this the MetaTable object or the metatable table???
        MetaTableUi
        TableParent
    end
    
    properties (Access = private, Hidden)
        MetaTableChangedListener
    end
    
    
    methods % Constructor
        
        function obj = MetaTableColumnFilter(hViewer, appRef)
                       
            obj.MetaTableUi = hViewer;
            obj.AppReference = appRef;
            obj.ComponentPanel = appRef.hLayout.SidePanel;
            
            % Add listener on metatable property set
            l = addlistener(hViewer, 'MetaTable', 'PostSet', @(s,e) obj.onMetaTableChanged);
            obj.MetaTableChangedListener = l;
            
            if ~isempty(obj.MetaTableUi.MetaTable)
                obj.onMetaTableChanged()
            end
            
        end
        
    end
    
    methods
        function metaTable = get.MetaTable(obj)
            % Get the cell array version of meta table
            metaTable = obj.MetaTableUi.MetaTableCell;
        end
    end
    
    methods
        
        function onMetaTableChanged(obj)
        %onMetaTableChanged Make necessary updates to property values.
        
            % Get the variable names of the metatable
            varNames = obj.MetaTableUi.MetaTable.Properties.VariableNames;
            numColumns = numel(varNames);
            
            if ~isempty(obj.hColumnFilterPopups)
                cellfun(@(c) delete(c), obj.hColumnFilterPopups)
            end
            
            obj.hColumnFilterPopups = cell(numColumns,1);
            
            obj.columnFilterType = repmat({'N/A'}, numColumns, 1);
            obj.isColumnFilterActive = false(numColumns,1);
            obj.isColumnFilterDirty = false(numColumns,1);
            
        end
        
        function openFilterControl(obj, columnIdx, point)
        %openFilterControl Open control for filtering table rows
        
            if ~isempty(obj.hColumnFilterPopups{columnIdx})
                if obj.isColumnFilterDirty(columnIdx)
                    obj.refreshFilterControls(columnIdx)
                    obj.isColumnFilterDirty(columnIdx) = false;
                end
                if strcmp(obj.PopupLocation, 'header')
                    pos = obj.getDropdownPosition(columnIdx, point);
                    obj.hColumnFilterPopups{columnIdx}.Position(1:2) = pos(1:2);
                end
                obj.hColumnFilterPopups{columnIdx}.Visible = 'on';
            else
                obj.initializeColumnFilterControl(columnIdx, point);
            end
        end
        
        function initializeColumnFilterControl(obj, columnIdx, point)
        %initializeColumnFilterControl Create filter dropdown for column
            
            h = [];
        
            % Need table column data.
            rowIdx = find( all(obj.MetaTableUi.DataFilterMap, 2) );
            columnData = obj.MetaTable(rowIdx, columnIdx);
                        
            switch class(columnData{1})
                
                case 'logical'
                    items = {'Show All', 'True', 'False'};
                    h = obj.createMultiSelectionDropdown(items, columnIdx, point);
                    obj.columnFilterType{columnIdx} = 'multiSelection-logical';
                    
                case 'char'
                    
                    uniqueColumnData = unique(columnData);
                    filterChoices = cat(1, 'Show All', uniqueColumnData);

                    if numel(uniqueColumnData) < numel(columnData)*0.95
                        
                        switch obj.PopupLocation
                            case 'sidepanel'
                                obj.createListboxSelector(filterChoices, columnIdx)
                            case 'header'
                                h = obj.createMultiSelectionDropdown(filterChoices, columnIdx, point);
                        end
                        obj.columnFilterType{columnIdx} = 'multiSelection';

                    else % Todo: Create a auto-search input dlg.
                        
                        h = obj.createAutocompleteWidget(filterChoices, columnIdx, point);
                        obj.columnFilterType{columnIdx} = 'autocomplete';

                    end
                    
                case {'uint8', 'uint16', 'single', 'double'}
                    
                    columnData = cell2mat(columnData);
                    [minValue, maxValue] = bounds(columnData);

                    h = obj.createRangeSelector([minValue, maxValue], columnIdx, point);
                    obj.columnFilterType{columnIdx} = 'numericRangeSelector';
                    
                case 'uint32'
                    
                    h = obj.createAutocompleteWidget(columnData, columnIdx, point);
                    obj.columnFilterType{columnIdx} = 'autocomplete';
                    h.PromptText = 'Search for id...';


                case 'datetime'
                    
                    h = obj.createDateIntervalSelector(columnIdx, point);            
                    obj.columnFilterType{columnIdx} = 'dateIntervalSelector';
                    
            end
            
            if ~isempty(h)
                obj.hColumnFilterPopups{columnIdx} = h;
            end
            
        end
        
        function initializeColumnFilterDropdownControl(obj, columnIdx)
           
        end
        
        function refreshFilterControls(obj, columnIdx)

            rowIdx = find( all(obj.MetaTableUi.DataFilterMap, 2) );
            
            % Need table column data.
            columnData = obj.MetaTable(rowIdx, columnIdx);
            
            switch obj.columnFilterType{columnIdx}
                case 'multiSelection'
                    uniqueColumnData = unique(columnData);
                    filterChoices = cat(1, 'Show All', uniqueColumnData);
                    
                    obj.hColumnFilterPopups{columnIdx}.String = filterChoices;
                    obj.hColumnFilterPopups{columnIdx}.Value = 1;
            end
        end
        
        function onColumnFilterUpdated(obj, src, evt, columnIdx)
        %onColumnFilterUpdated Update table data when column filter changes
            
        
        % Todo: Update the row subset selection and then call the
        % updateTableView method
        
        % Todo: make widgets specifications (which widget to use) part of
        % the table variable class specification
        
            %colInd = obj.getCurrentColumnSelection();
            T = obj.MetaTable;
            
            [numRows, numColumns] = size(T);
            
            % Initialize the filter matrix if this is the first time.
            if isempty(obj.MetaTableUi.DataFilterMap)
                obj.MetaTableUi.DataFilterMap = true(numRows, numColumns);
            end
            
            % Get column data for current columns
            columnData = T(:, columnIdx);            
            h = obj.hColumnFilterPopups{columnIdx};

            switch obj.columnFilterType{columnIdx}
                
                case 'multiSelection-logical'
                    currentSelection = h.String{h.Value};
                    columnData = cat(1, columnData{:});
                    switch currentSelection
                        case 'Show All'
                            obj.isColumnFilterActive(columnIdx) = false;
                            obj.MetaTableUi.DataFilterMap(:, columnIdx) = true;
                        case 'True'
                            obj.isColumnFilterActive(columnIdx) = false;
                            obj.MetaTableUi.DataFilterMap(:, columnIdx) = columnData;
                            
                        case 'False'
                            obj.isColumnFilterActive(columnIdx) = false;
                            obj.MetaTableUi.DataFilterMap(:, columnIdx) = ~columnData;
                            
                    end
                    
                case 'multiSelection'
                    
                    currentSelection = h.String(h.Value);
                    
                    if strcmp(currentSelection{1}, 'Show All')
                        obj.isColumnFilterActive(columnIdx) = false;
                        obj.MetaTableUi.DataFilterMap(:, columnIdx) = true;
                        h.Value = 1;
                        %obj.hColumnLabels(columnIdx).Color = ones(1,3)*0.8;
                    else
                        obj.isColumnFilterActive(columnIdx) = true;
                        TF = ismember(columnData, currentSelection);
                        % TODO: Use ismember instead??
                        obj.MetaTableUi.DataFilterMap(:, columnIdx) = TF;
                        %obj.hColumnLabels(columnIdx).Color = obj.tableSettings.columnSpecialColor;
                        %obj.hColumnLabels(columnIdx).FontWeight = 'bold';
                    end
                    
                case {'searchField', 'autocomplete'}
                    currentSelection = h.SelectedItems;
                    if isempty(currentSelection) || all(strcmp(currentSelection, 'Show All')) 
                        obj.isColumnFilterActive(columnIdx) = false;
                        obj.MetaTableUi.DataFilterMap(:, columnIdx) = true;
                    else
                        obj.isColumnFilterActive(columnIdx) = true;
                        TF = ismember(columnData, currentSelection);
                        obj.MetaTableUi.DataFilterMap(:, columnIdx) = TF;
                    end
                    
                case 'dateIntervalSelector'
                         
                    dateInterval = h.SelectedDateInterval;
                    columnData = cat(1, columnData{:});
                    
                    if isempty(dateInterval)
                        TF = true(size(columnData, 1), 1);
                    else
                        dateInterval.TimeZone = columnData(1).TimeZone;
                        TF = columnData > dateInterval(1) & columnData < dateInterval(2);
                    end
                    obj.MetaTableUi.DataFilterMap(:, columnIdx) = TF;
                    
                case 'numericRangeSelector'
                    
                    columnData = cell2mat(columnData);
                    TF = columnData >= h.Low & columnData <= h.High;
                    obj.MetaTableUi.DataFilterMap(:, columnIdx) = TF;
                    
            end
            
            obj.MetaTableUi.updateTableView()
            obj.isColumnFilterDirty(:) = true;
            
% % %             keepRows = all(obj.MetaTableUi.DataFilterMap, 2);
% % %             T = T(keepRows, :);
% % %             
% % %             % Todo: should not have to do this every time...
% % %             %T = obj.formatTableData(T);
% % %             
% % %             obj.hTableView.Data = table2cell(T);
% % %             
% % %             % Matlab uitable automatically resets rowheight when Data
% % %             % property is updated....
% % %             obj.refreshRowHeight();
% % %             
% % %             %obj.refreshTableModel()
        end
        
        function resetFilters(obj)
            obj.MetaTableUi.DataFilterMap = [];
            obj.isColumnFilterDirty(:) = true;
            obj.MetaTableUi.updateTableView()
        end
        
        function hideFilters(obj)
            
            h = gco; % Duct tape and superglue ftw.
            if ~isempty(h)
                if contains(h.Tag, 'Range Slider') || contains( h.Tag, 'Range Selector')
                    return
                end
            end
            
            for i = 1:numel(obj.hColumnFilterPopups)
                if ~isempty(obj.hColumnFilterPopups{i})
                    if strcmp(obj.hColumnFilterPopups{i}.Visible, 'on')
                        obj.hColumnFilterPopups{i}.Visible = 'off';
                    end
                end
            end
            
        end
        
    end
    
    
    methods (Access = private)
        
        function createListboxSelector(obj, filterChoices, columnIdx)
            
            parentPos = getpixelposition(obj.ComponentPanel);
            margins = 15;
            
            h = uicontrol(obj.ComponentPanel, 'style', 'listbox');
            h.String = filterChoices;
            h.BackgroundColor = obj.ComponentPanel.BackgroundColor;
            h.ForegroundColor = obj.ComponentPanel.ForegroundColor;
                        
            h.Max = 2;
            
            componentHeight = h.Extent(4);
            pos = [margins, parentPos(4)-margins-componentHeight, ...
                   parentPos(3)-2*margins, componentHeight];
            

            h.Units = 'pixels';
            h.Position = pos;
            
            h.Callback = @(s,e,i) obj.onColumnFilterUpdated(s,e,columnIdx);
                        
            obj.hColumnFilterPopups{columnIdx} = h;
            
        end
        
        function h = createMultiSelectionDropdown(obj, items, columnIdx, point)
        %createMultiSelectionDropdown    
            
            hParent = obj.MetaTableUi.Parent;
            position = obj.getDropdownPosition(columnIdx, point);

            bgColor = ones(1,3) * 0.94;
            fgColor = ones(1,3) * 0.1;
            
            h = uics.multiSelectionDropDown('Parent', hParent, ...
                'Location', position(1:2), 'String', items, 'BackgroundColor', ...
                bgColor, 'ForegroundColor', fgColor);
            h.String = items;
            
            h.Position(2) = position(2) + position(4) - h.Position(4);
            h.Position(3) = max([75, position(3) * 1.25]);
            
            h.Callback = @(s,e,i) obj.onColumnFilterUpdated(s,e,columnIdx);
            h.giveFocus()

            %obj.columnFilterType{columnIdx} = 'multiSelectionDropdown';
            
        end
        
        function h = createAutocompleteWidget(obj, items, columnIdx, point)
            
            hParent = obj.MetaTableUi.Parent;
            position = obj.getDropdownPosition(columnIdx, point);
            position(4) = 30;
            h = uics.searchAutoCompleteInputDlg(hParent, items, 'HideOnFocusLost', true);
            h.PromptText = 'Enter text...';
            h.Position = position;
            h.Position(2) = h.Position(2)-10;
            
            if h.Position(3) < 200; h.Position(3) = 200; end
            
            h.Callback = @(s,e,i) obj.onColumnFilterUpdated(s,e,columnIdx);

        end
        
        function h = createRangeSelector(obj, dataRange, columnIdx, point)
            
            hParent = obj.MetaTableUi.Parent;
            position = obj.getDropdownPosition(columnIdx, point);
            position(4) = 30;
            
            h = uics.rangeSelector(hParent, 'Minimum', dataRange(1), ...
                'Maximum', dataRange(2), 'CallbackRefreshRate', 0.5 );
            h.Position = position;
            h.Position(3) = max([position(3), 200]);
            h.Position(2) = position(2) - 10;

            h.Callback = @(s,e,i) obj.onColumnFilterUpdated(s,e,columnIdx);
        
        end
        
        function h = createDateIntervalSelector(obj, columnIdx, point)
            
            hParent = obj.MetaTableUi.Parent;
            position = obj.getDropdownPosition(columnIdx, point);
            position(2) = position(2) - 210; %230 is height of date panel...
            h = uics.DateRangeSelector('Parent', hParent);
            h.Position(1:2) = position(1:2);
            h.Callback = @(s,e,i) obj.onColumnFilterUpdated(s,e,columnIdx);
            
        end
        
        function position = getDropdownPosition(obj, columnIdx, headerColumnPoint)
        %getDropdownPosition Get position to show dropdown control    
            
            hParent = obj.MetaTableUi.Parent;
            parentPosition = getpixelposition(hParent, 1);
            colWidth = obj.MetaTableUi.ColumnModel.getColumnWidths();
            
            dataColIndices = obj.MetaTableUi.ColumnModel.getColumnIndices();
            tableColumnIdx = find( ismember(dataColIndices, columnIdx) );
            
            colWidth = colWidth(tableColumnIdx);
            
            if ~isempty(obj.hColumnFilterPopups{columnIdx})
                h = obj.hColumnFilterPopups{columnIdx};
                height = h.Position(4);
            else
                height = 20;
            end
            
            position(1) = headerColumnPoint(1) - colWidth/2;
            position(2) = headerColumnPoint(2) - height - parentPosition(2) - 10;
            position(3) = colWidth;
            position(4) = height;
            
        end
    end
    
    
end