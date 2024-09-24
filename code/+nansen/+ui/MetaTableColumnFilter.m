classdef MetaTableColumnFilter < handle
%MetaTableColumnFilter Provides filtering functionality to the MetaTableViewer    
    
    % Todo: 
    %   [ ] Better method(s) for setting position of filter controls
    
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
    
    events
        FilterUpdated
    end
    
    
    methods % Constructor
        
        function obj = MetaTableColumnFilter(uiTable, appRef)
        %MetaTableColumnFilter Create an object of this class
        %
        %   obj = MetaTableColumnFilter(hViewer, appRef) requires two
        %   inputs, uiTable (a MetaTableViewer object) and appRef (a
        %   reference/handle of the app containing the table)
        
            obj.MetaTableUi = uiTable;
            obj.AppReference = appRef;
            %obj.ComponentPanel = appRef.hLayout.SidePanel;
            
            % Add listener on metatable property set
            %l = addlistener(uiTable, 'MetaTable', 'PostSet', @(s,e) obj.onMetaTableChanged);
            %obj.MetaTableChangedListener = l;
            
            if isa(obj.MetaTableUi.MetaTable, 'table')
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
            obj.deleteFilterControls()
            obj.reinitializeFilterControlProperties()
        end
        
        function onMetaTableUpdated(obj)
        %onMetaTableUpdated Callback for when metatable is updated    
            
            % Reset filter controls if number of columns have changed
            numCols = size(obj.MetaTable, 2);
            if numCols ~= numel( obj.hColumnFilterPopups )
                obj.onMetaTableChanged
            end
            
            obj.updateColumnFilter()
        end
        
        function openFilterControl(obj, columnIdx)
        %openFilterControl Open control for filtering table rows
        
            if ~isempty(obj.hColumnFilterPopups{columnIdx})
                if obj.isColumnFilterDirty(columnIdx)
                    obj.isColumnFilterDirty(columnIdx) = false;
                end
                obj.refreshFilterControls(columnIdx)

                if strcmp(obj.PopupLocation, 'header')
                    pos = obj.getDropdownPosition(columnIdx);
                    obj.hColumnFilterPopups{columnIdx}.Position(1:2) = pos(1:2);
                    obj.forceFilterControlInView(obj.hColumnFilterPopups{columnIdx});
                end
                obj.hColumnFilterPopups{columnIdx}.Visible = 'on';
            else
                obj.initializeColumnFilterControl(columnIdx);
            end
        end
        
        function deleteFilterControls(obj)
            if ~isempty(obj.hColumnFilterPopups)
                cellfun(@(c) delete(c), obj.hColumnFilterPopups)
            end
        end
        
        function reinitializeFilterControlProperties(obj)
            % Get the variable names of the metatable
            varNames = obj.MetaTableUi.MetaTable.Properties.VariableNames;
            numColumns = numel(varNames);
            
            obj.hColumnFilterPopups = cell(numColumns, 1);
            
            obj.columnFilterType = repmat({'N/A'}, numColumns, 1);
            obj.isColumnFilterActive = false(numColumns,1);
            obj.isColumnFilterDirty = false(numColumns,1);
            
        end
        
        function initializeColumnFilterControl(obj, columnIdx)
        %initializeColumnFilterControl Create filter dropdown for column
            
            h = [];
        
            % Need table column data.
            rowIdx = find( all(obj.MetaTableUi.DataFilterMap, 2) );
            columnData = obj.MetaTable(rowIdx, columnIdx);
                  
            switch class(columnData{1})
                
                case 'logical'
                    items = {'Show All', 'True', 'False'};
                    h = obj.createMultiSelectionDropdown(items, columnIdx);
                    obj.columnFilterType{columnIdx} = 'multiSelection-logical';
                    
                case {'char', 'string'}
                    if isstring(columnData{1})
                        columnData = cellstr(columnData);
                    end
                    
                    uniqueColumnData = unique(columnData);
                    filterChoices = cat(1, 'Show All', uniqueColumnData);

                    nUnique = numel(uniqueColumnData);
                    
                    createDropdown = false;
                    fractionUnique = nUnique / numel(columnData) * 100;

                    if nUnique < 10
                        createDropdown = true;
                    elseif nUnique < 20 && fractionUnique < 90
                        createDropdown = true;
                    elseif nUnique < 50 && fractionUnique < 50
                        createDropdown = true;
                    end

                    if createDropdown
                        switch obj.PopupLocation
                            case 'sidepanel'
                                obj.createListboxSelector(filterChoices, columnIdx)
                            case 'header'
                                h = obj.createMultiSelectionDropdown(filterChoices, columnIdx);
                        end
                        obj.columnFilterType{columnIdx} = 'multiSelection';

                    else % Create a search/freetext filter widget
                        h = obj.createAutocompleteWidget(filterChoices, columnIdx);
                        obj.columnFilterType{columnIdx} = 'autocomplete';
                    end
                    
                case {'uint8', 'uint16', 'single', 'double'}
                    
                    columnData = cell2mat(columnData);
                    if isempty(columnData); return; end
                    [minValue, maxValue] = bounds(columnData);

                    h = obj.createRangeSelector([minValue, maxValue], columnIdx);
                    obj.columnFilterType{columnIdx} = 'numericRangeSelector';
                    
                case 'uint32'
                    
                    h = obj.createAutocompleteWidget(columnData, columnIdx);
                    obj.columnFilterType{columnIdx} = 'autocomplete';
                    h.PromptText = 'Search for id...';


                case 'datetime'
                    
                    h = obj.createDateIntervalSelector(columnIdx);            
                    obj.columnFilterType{columnIdx} = 'dateIntervalSelector';
                    
            end
            
            if ~isempty(h)
                obj.hColumnFilterPopups{columnIdx} = h;
            end
            
            obj.forceFilterControlInView(h);
        end
        
        function forceFilterControlInView(obj, hControl)
            % Make sure filter control stays within parent panel.
            parentPos = getpixelposition(obj.MetaTableUi.Parent);

            if sum(hControl.Position([1,3])) > parentPos(3)
                hControl.Position(1) = parentPos(3) - hControl.Position(3) - 5;
            end
            
            %hControl.Position(2) = hControl.Position(2) - hControl.Position(4);
            
        end
        
        function refreshFilterControls(obj, columnIdx)

            rowIdx = find( all(obj.MetaTableUi.DataFilterMap, 2) );
            
            % Need table column data.
            columnData = obj.MetaTable(:, columnIdx);
            
            switch obj.columnFilterType{columnIdx}
                case 'multiSelection'
                    columnData = cellstr(columnData); % If string array
                    uniqueColumnData = unique(columnData);
                    filterChoices = cat(1, 'Show All', uniqueColumnData);
                     
                    % Need to store current width because setting the
                    % string propery will resize the width of the control.
                    width = obj.hColumnFilterPopups{columnIdx}.Position(3);
                    
                    % Store currently selected values
                    oldValue = obj.hColumnFilterPopups{columnIdx}.Value;
                    oldString = obj.hColumnFilterPopups{columnIdx}.String(oldValue);

                    obj.hColumnFilterPopups{columnIdx}.String = filterChoices;
                    
                    % Reset selection:
                    [~, iA] = intersect(filterChoices, oldString, 'stable');
                    obj.hColumnFilterPopups{columnIdx}.Value = iA;
                    
                    % Reset width to original value
                    obj.hColumnFilterPopups{columnIdx}.Position(3) = width;
            end
        end
        
        function onColumnFilterValueChanged(obj, src, evt, columnIdx, skipNotify)
        %onColumnFilterValueChanged Update table data when column filter changes
        
        % Todo: make widgets specifications (which widget to use) part of
        % the table variable class specification
        
            if nargin < 5
                skipNotify = false; % Todo: Should make another method, so that this is not needed
            end
        
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
                            obj.isColumnFilterActive(columnIdx) = true;
                            obj.MetaTableUi.DataFilterMap(:, columnIdx) = columnData;
                            
                        case 'False'
                            obj.isColumnFilterActive(columnIdx) = true;
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
                        columnData = cellstr(columnData);
                        TF = ismember(columnData, currentSelection);
                        % TODO: Use ismember instead??
                        obj.MetaTableUi.DataFilterMap(:, columnIdx) = TF;
                        %obj.hColumnLabels(columnIdx).Color = obj.tableSettings.columnSpecialColor;
                        %obj.hColumnLabels(columnIdx).FontWeight = 'bold';
                    end
                    
                case {'searchField', 'autocomplete'}
                    currentSelection = h.SelectedItems;

                    if isnumeric(columnData{1})
                        columnData = cellfun(@num2str, columnData, 'UniformOutput', false);
                    end

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
                        obj.isColumnFilterActive(columnIdx) = false;
                        TF = true(size(columnData, 1), 1);
                    else
                        obj.isColumnFilterActive(columnIdx) = true;
                        dateInterval.TimeZone = columnData(1).TimeZone;
                        TF = columnData > dateInterval(1) & columnData < dateInterval(2);
                    end
                    obj.MetaTableUi.DataFilterMap(:, columnIdx) = TF;
                    
                case 'numericRangeSelector'
                    
                    columnData = cell2mat(columnData);
                    TF = columnData >= h.Low & columnData <= h.High;
                    obj.MetaTableUi.DataFilterMap(:, columnIdx) = TF;
                    if any(~TF)
                        obj.isColumnFilterActive(columnIdx) = true;
                    else
                        obj.isColumnFilterActive(columnIdx) = false;
                    end

            end
            
            obj.MetaTableUi.updateColumnLabelFilterIndicator(obj.isColumnFilterActive)

            if ~skipNotify
                evtData = event.EventData;
                obj.notify('FilterUpdated', evtData)
            end

            obj.isColumnFilterDirty(:) = true;
        end
        
        function updateColumnFilter(obj)
        %updateColumnFilter Update the column filter.   
            [numRows, numColumns] = size(obj.MetaTable); 
            obj.MetaTableUi.DataFilterMap = true(numRows, numColumns);
            
            % (mis)use the onColumnFilterValueChanged to update the filters
            % and add the optional flag for skipping event notification. 
            for i = 1:numColumns
                if ~isempty(obj.hColumnFilterPopups{i})
                    obj.onColumnFilterValueChanged([],[],i,true)
                end
            end
        end
        
        function resetFilters(obj)
        %resetFilters Reset all filters (and filter controls)
        
            obj.MetaTableUi.DataFilterMap = [];
            obj.isColumnFilterDirty(:) = true;
        
            obj.isColumnFilterActive(:) = false;
            obj.MetaTableUi.updateColumnLabelFilterIndicator(obj.isColumnFilterActive)

            evtData = event.EventData;
            obj.notify('FilterUpdated', evtData)
            
            % Reset filter controls
            for i = 1:numel(obj.hColumnFilterPopups)
                if ~isempty(obj.hColumnFilterPopups{i})
                    try
                        obj.hColumnFilterPopups{i}.reset()
                    catch
                        warning('Could not reset filter properly for column %d', i)
                    end
                end
            end
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
    
    
    methods (Access = private) % Methods for creating filtering widgets.
        
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
            %h.Position = pos;
            
            h.Callback = @(s,e,i) obj.onColumnFilterValueChanged(s,e,columnIdx);
                        
            obj.hColumnFilterPopups{columnIdx} = h;
            
        end
        
        function h = createMultiSelectionDropdown(obj, items, columnIdx)
        %createMultiSelectionDropdown    
            
            hParent = obj.MetaTableUi.Parent;
            position = obj.getDropdownPosition(columnIdx);

            bgColor = ones(1,3) * 0.94;
            fgColor = ones(1,3) * 0.1;
            
            h = uics.multiSelectionDropDown('Parent', hParent, ...
                'Location', position(1:2), 'String', items, 'BackgroundColor', ...
                bgColor, 'ForegroundColor', fgColor);
            h.String = items;
            
            h.Position(2) = position(2) + position(4) - h.Position(4);
            h.Position(3) = max([75, position(3) * 1.25]);
            
            h.Callback = @(s,e,i) obj.onColumnFilterValueChanged(s,e,columnIdx);
            h.giveFocus()
        end
        
        function h = createAutocompleteWidget(obj, items, columnIdx)
            
            hParent = obj.MetaTableUi.Parent;
            position = obj.getDropdownPosition(columnIdx);
            position(4) = 30;
            h = uics.searchAutoCompleteInputDlg(hParent, items, 'HideOnFocusLost', true);
            h.PromptText = 'Enter text...';
            h.Position = position;
            h.Position(2) = h.Position(2)-10;
            
            if h.Position(3) < 200; h.Position(3) = 200; end
            
            h.Callback = @(s,e,i) obj.onColumnFilterValueChanged(s,e,columnIdx);
        end
        
        function h = createRangeSelector(obj, dataRange, columnIdx)
            
            hParent = obj.MetaTableUi.Parent;
            position = obj.getDropdownPosition(columnIdx);
            position(4) = 30;
            
            % todo: make callback refreshrate dependent on table size...

            h = uics.rangeSelector(hParent, 'Minimum', dataRange(1), ...
                'Maximum', dataRange(2), 'CallbackRefreshRate', 0 );
            h.Position = position;
            h.Position(3) = max([position(3), 200]);
            h.Position(2) = position(2) - 10;
            
            h.Callback = @(s,e,i) obj.onColumnFilterValueChanged(s,e,columnIdx);
        end
        
        function h = createDateIntervalSelector(obj, columnIdx)
            
            hParent = obj.MetaTableUi.Parent;
            position = obj.getDropdownPosition(columnIdx);
            position(2) = position(2) - 210; %230 is height of date panel...
            h = uics.DateRangeSelector('Parent', hParent);
            h.Position(1:2) = position(1:2);
            h.Callback = @(s,e,i) obj.onColumnFilterValueChanged(s,e,columnIdx);
        end
        
        function position = getDropdownPosition(obj, columnIdx)
        %getDropdownPosition Get position to show dropdown control    
            
            % Get positions of parent containers.
            hParent = obj.MetaTableUi.Parent;
            parentPosition = getpixelposition(hParent);
            tablePosition = getpixelposition(obj.MetaTableUi.HTable);

            % Find the index of the current column
            dataColIndices = obj.MetaTableUi.ColumnModel.getColumnIndices();
            tableColumnIdx = find( ismember(dataColIndices, columnIdx) );
            
            % Compute the position in the table view of the column
            columnWidths = obj.MetaTableUi.ColumnModel.getColumnWidths();
            columnPositionX = sum(columnWidths(1:tableColumnIdx-1));
            xOffset = obj.MetaTableUi.HTable.getHorizontalScrollOffset;
            
            xPosition = columnPositionX - xOffset + tablePosition(1);
            yPosition = tablePosition(4) - 20;
            
            position(1:2) = [xPosition, yPosition];
            
            % Get height (or use default) for filter component
            if ~isempty(obj.hColumnFilterPopups{columnIdx})
                h = obj.hColumnFilterPopups{columnIdx};
                height = h.Position(4);
            else
                height = 20;
            end
            
            % Adjust position based on component height
            position(2) = position(2) - height;
            position(3) = min([columnWidths(tableColumnIdx), 300]);
            position(4) = height;
            
            % Make sure position stays within parent...
            if sum(position([1,3])) > parentPosition(3)
                position(1) = parentPosition(3) - position(3);
            end
        end
        
    end
    
    
end