classdef UiControlTable < handle & matlab.mixin.Heterogeneous
%UiControlTable Interface for plotting ui components in a table like layout.
%
% This is an abstract class and subclasses should control which component
% libraries to use. I.e one subclass can be made to work with appdesigner
% figures, and another could work with traditional figures.
    
%   Todo: 
%     [v] many (most) sublasses have an advanced options view. Should make
%         that behavior part of this superclass.
%
%     [ ] Toolbar should not be part of the table class...
%     
%     [ ] Get cell locations as array with one entry for each column of a
%         row. (see getCellPosition)

%     [ ] Do the centering when getting the cell locations.
%     [ ] Set fontsize/bg color and other properties in batch.


    properties % Table info/data
        ColumnNames cell = {}
        ColumnFormat cell = {}
        Data 
        SelectedRows = []
    end
    
    properties % Table layout
        TableMargin = 20;   % Space in pixels around the table within the parent container.
        TablePadding = 5;   % Space in pixels between table outline and table components.
        
        ShowToolbar = true
        ShowColumnHeader = true
        ShowColumnHeaderHelp = true
        ColumnHeaderHelpFcn = []
        RowHeight = 20;
        ColumnWidths
        RowSpacing = 15;
        ColumnSpacing = 15;
    end
    
    properties % Table style / appearance
        BackgroundColor = [1, 1, 1]
        TableBorderColor = [0.1, 0.1, 0.1];
        
        RowBackgroundColor = [1, 1, 1];
        RowSelectedBackgroundColor = [0.9, 0.9, 0.9];
        
        FontName = 'helvetica';
    end
    
    properties % Graphical properties
        Parent
        Position
    end

    properties (Abstract, Constant, Access = protected)
        DEFAULT_COMPONENT_HEIGHT
    end
    
    properties (Access = protected, Hidden) % Internal layout properties
        RowLocations        % Y position of each table row
        ColumnLocations     % X position of each table column
        TablePanelPosition
        ColumnHeaderPosition
    end
    
    properties (Dependent)
        NumRows
        NumColumns
    end
    
    properties (Access = protected, Hidden) % Internal graphical properties
        % HeaderPanel % Not implemented
        TablePanel matlab.ui.container.Panel
        ToolbarPanel matlab.ui.container.Panel

        ColumnHeaderLabels cell  % matlab.ui.control.Label (this does not work because some of these migth be empty)
        ColumnLabelHelpButton  cell  % matlab.ui.control.Image (ditto)
        ColumnHeaderBorder
        RowControls
        
        TableComponentCellArray
    end
    
    properties (Access = protected, Hidden) % Internal listeners
        ParentDestroyedListener
        ParentResizedListener
        IsConstructed = false
    end
    
    
    methods (Abstract, Access = protected)
        
        % Method for opening new figure if parent is not assigned
        openNewFigure(obj) 
        
        % For subclasses that have default values for some properties
        assignDefaultTablePropertyValues(obj) % Todo: rename
        
        % Create panels and other containers for table components
        createLayoutContainers(obj)
        
        % Create the table header
        createHeader(obj)

        % Create the table row controls
        createTableRowComponents(obj)
        
        % Update table row background (i.e if row is selected)
        updateTableRowBackground(rowNumber, isSelected)
        
        setTableScrolling(obj, state)
    end
    
    methods % Structors
        
        function obj = UiControlTable(varargin)
        %UiControlTable UiControlTable constructor class      
        
        % Todo: 
        %   [ ] Accept table and/or struct array as data?
        
          %%% Assign inputs.
            varargin = obj.checkForParentArgin(varargin);                       % Assigns Parent if it is given as the first input.
            varargin = obj.assignPropertyValue(varargin, 'Parent');             % Assigns Parent if it is given as a name-value combination.
            varargin = obj.assignPropertyValue(varargin, 'Position');           % Assigns Position if it is given as a name-value combination.
            varargin = obj.assignPropertyValue(varargin, 'TablePanel');         % Assigns TablePanel if it is given as a name-value combination.
            varargin = obj.assignPropertyValue(varargin, 'ToolbarPanel');       % Assigns ToolbarPanel if it is given as a name-value combination.

            try % Call method that might be defined in subclasses.
                obj.assignDefaultTablePropertyValues() %#ok<MCNPN>
            catch
                % Continue, everything is fine!
            end
            
            % Create new figure if parent is not provided
            if isempty(obj.Parent);      obj.openNewFigure();    end
            
            % Assign position if position is not given
            if isempty(obj.Position);    obj.autoAssignPosition();    end
            
            obj.assignPropertyValue(varargin, 'all');
            
          %%% Run configuration and creation
            obj.configureLayout()

            % obj.createTablePanel()
            % obj.createTempAxes()

            obj.createLayoutContainers()
            
            if ~obj.NumColumns == 0
                obj.ColumnLocations = obj.calculateColumnPositions();
            end
            
            if ~obj.NumRows == 0
                obj.RowLocations = obj.calculateRowPositions();
            end
            
            if obj.ShowColumnHeader && ~isempty(obj.ColumnNames)
                obj.createHeader()
            end
            
            obj.createTable()
            
            if obj.ShowToolbar
                if isempty(obj.ToolbarPanel)
                    hPanel = obj.Parent.Parent;
                else
                    hPanel = obj.ToolbarPanel;
                end
                obj.createToolbarComponents(hPanel)
            end
            
            obj.IsConstructed = true;
            
            % These are not activated...
            %addlistener(ancestor(obj.Parent, 'figure'), 'SizeChanged', @obj.onParentResized)
            %addlistener(obj.Parent, 'SizeChanged', @obj.onParentResized)
        end
        
        function delete(obj)
            obj.deleteRowControls()
            obj.deleteToolbarComponents()
        end

    end
    
    methods % Set/get methods
        
        
        function set.ShowToolbar(obj, newValue)
            assert(islogical(newValue), 'Value must be logical')
            obj.ShowToolbar = newValue;
            obj.onShowToolbarPropertySet()
        end
        
        function set.Data(obj, newData)
            obj.Data = newData;
            obj.calculateRowPositions()
        end
        
        function numRows = get.NumRows(obj)
            if isempty(obj.Data)
                numRows = 0;
            elseif isa(obj.Data, 'struct') || isobject(obj.Data)
                numRows = numel(obj.Data);
            elseif isa(obj.Data, 'table')
                numRows = size(obj.Data, 1);
            else
                try
                    numRows = numel(obj.Data);
                catch
                    error('Could not determine number of rows')
                end
            end
        end
        
        function numColumns = get.NumColumns(obj)
            if ~isempty(obj.Data)
                if isa(obj.Data, 'struct')
                    numColumns1 = numel(fieldnames(obj.Data));
                elseif isobject(obj.Data)
                    numColumns1 = numel(properties(obj.Data));
                elseif isa(obj.Data, 'table')
                    numColumns1 = size(obj.Data, 2);
                end
            end

            if ~isempty(obj.ColumnNames)
                numColumns2 = numel(obj.ColumnNames);
            end
            
            if ~isempty(obj.ColumnNames) && ~isempty(obj.Data)
                msg = 'The number of column names does not match the number of table columns';
                %assert(numColumns1==numColumns2, msg)
                numColumns = numColumns2;
            elseif ~isempty(obj.Data)
                numColumns = numColumns1;
            elseif ~isempty(obj.ColumnNames)
                numColumns = numColumns2;
            else
                numColumns = 0;
            end
        end
        
        function set.Parent(obj, newParent)
            obj.Parent = newParent;
            obj.setParentBeingDestroyedListener()
        end
        
        function rowData = getRowData(obj, rowNum)
        %getRowData Get rowdata for given row 
        %
        %   Require different indexing methods for structs and tables
        
            if isa(obj.Data, 'struct') || isobject(obj.Data)
                rowData = obj.Data(rowNum);
            elseif isa(obj.Data, 'table')
                rowData = obj.Data(rowNum, :);
            else
                error('Unsupported datatype for table data ("%s")', class(obj.Data))
            end
        end
        
    end
    
    methods (Access = private) % Configuration and construction
        
        function nvPairs = checkForParentArgin(obj, nvPairs)
            
            if isempty(nvPairs);    return;     end
            
            if ~isa(nvPairs{1}, 'char') && isgraphics(nvPairs{1})
                % Todo: test for actual graphics container that can have
                % children...
                obj.Parent = nvPairs{1};
                nvPairs(1) = [];
            end
        end
        
        function nvPairs = assignPropertyValue(obj, nvPairs, propertyName)
        %assignPropertyValue Assign one or more property values
        
            if isempty(nvPairs);    return;     end
            
            % Set all available properties if no name is provided.
            if nargin < 3 || strcmp(propertyName, 'all')
                propertyName = properties(obj);
            end
            
            % Find members of nvPairs that match the propertyName input.
            isMatched = contains(nvPairs(1:2:end), propertyName);
            
            if any(isMatched)
                
                matchedInd = find(isMatched) * 2 - 1;
                
                % Assign property values for all matched property names.
                for i = 1:numel(matchedInd)
                    nameInd = matchedInd(i);
                    valueInd = nameInd + 1;
            
                    thisName = nvPairs{nameInd};
                    obj.(thisName) = nvPairs{valueInd};
                end
                
                nvPairs([matchedInd, matchedInd+1]) = [];
            end
            
            if ~nargout
                clear nvPairs
            end
        end
        
        function setParentBeingDestroyedListener(obj)
            el = listener(obj.Parent, 'ObjectBeingDestroyed', @(s,e) obj.delete);
            obj.ParentDestroyedListener = el;
        end
        
        function autoAssignPosition(obj)
        %autoAssignPosition Assign a default position within parent.    
            
            if numel(obj.TableMargin) == 1
            	tableMargin = [obj.TableMargin, obj.TableMargin];
            else
                tableMargin = obj.TableMargin;
            end
            
            parentPosition = getpixelposition(obj.Parent);
            obj.Position = [ tableMargin(1), tableMargin(2), ...
                                parentPosition(3:4)-tableMargin*2 ];
        end
        
        function configureLayout(obj)
        %configureLayout Configure internal layout of table components    
            
            % Some hardcoded values
            headerTableSpacing = 0;
            columnHeaderPadding = 0;
        
            if obj.ShowColumnHeader
                pos = zeros(1,4);
                
                rowExtent = obj.RowHeight + columnHeaderPadding;
                
                pos(1) = obj.Position(1);                                   % x position
                pos(2) = sum( obj.Position([2,4]) ) - rowExtent;            % y position
                pos(3) = obj.Position(3);                                   % width
                pos(4) = rowExtent;                                         % height
                
                obj.ColumnHeaderPosition = pos;
            else
                obj.ColumnHeaderPosition = zeros(1,4);
            end
            
            obj.TablePanelPosition = obj.Position;
            obj.TablePanelPosition(4) = obj.TablePanelPosition(4) - ...
                obj.ColumnHeaderPosition(4) - headerTableSpacing;

            obj.TablePanelPosition(3) = sum(obj.ColumnWidths) + numel(obj.ColumnWidths)*obj.ColumnSpacing + 20;
            obj.ColumnHeaderPosition(3) = obj.TablePanelPosition(3) - 20;
        end
        
        function deleteRowControls(obj)
            if ~isempty(obj.RowControls)
                fields = fieldnames(obj.RowControls);
                for i = 1:numel(obj.RowControls)
                    for j = 1:numel(fields)
                        delete(obj.RowControls(i).(fields{j}))
                    end
                end
            end
        end
        
        function deleteToolbarComponents(obj)
            hComponents = obj.getToolbarComponents;
                        
            isdeletable = @(x) ~isempty(x) && isvalid(x);

            for i = 1:numel(hComponents)
                if isdeletable( hComponents(i) )
                    delete( hComponents(i) )
                end
            end
        end
        
        function deleteHeader(obj)
            
        end
    end
    
    methods (Access = private, Hidden) % Internal updating
        
        function Y = calculateRowPositions(obj)
        %calculateRowPositions Calculate y-positions for each row
            
            if obj.NumRows == 0
                Y = [];
            else
        
                panelSize = getpixelposition(obj.TablePanel);

                y = 0:obj.NumRows-1;
                y = y .* (obj.RowHeight + obj.RowSpacing);

                % y = y + obj.TableMargin;
                % topMargin = 0;

                if y(end) < (panelSize(4) - obj.RowHeight - obj.RowSpacing)
                    y = y + (panelSize(4) - y(end)) - obj.RowHeight - obj.RowSpacing;
                end

                Y = fliplr(y);

                % Make table scrollable if components exceed panel's size.
                if max(Y) > panelSize(4) - obj.RowHeight - obj.RowSpacing
                    obj.setTableScrolling('on')
                end
            end
            
            if ~nargout
                obj.RowLocations = Y;
                clear Y
            end
        end
        
        function X = calculateColumnPositions(obj)
        %calculateColumnPositions Calculate x-positions of columns    
            
            xSpace = obj.ColumnSpacing;
            
            if isempty(obj.ColumnWidths)
                
                colWidth = (obj.Position(3) - obj.TablePadding*2 ...
                    - (obj.NumColumns-1) * xSpace) / obj.NumColumns;
                
                obj.ColumnWidths = repmat(colWidth, 1, obj.NumColumns);
            end
                
            X = cumsum([0, obj.ColumnWidths]) + ...
                    (0:numel(obj.ColumnWidths)) .* xSpace;
            
            X = X + obj.TablePadding;
        end
        
        function updateRowPositions(obj, rowDisplacements)
        %updateRowPositions Update positions of existing rows
        %
        %   Used when table is resized or if rows are added or removed.
            
            if isempty(obj.RowControls)
                return
            end
        
            % Update positions of existing rows
            rowFields = fieldnames(obj.RowControls);
            
            for i = 1:numel(obj.RowControls)
                dY = rowDisplacements(i);
                for j = 1:numel(rowFields)
                    obj.RowControls(i).(rowFields{j}).Position(2) = ...
                        obj.RowControls(i).(rowFields{j}).Position(2) + dY;
                end
            end
        end
        
    end
    
    methods (Access = protected) % Methods accessible from subclasses
                
        function createTablePanel(obj)
        %createTablePanel Create panel for adding rows to.

            if isempty(obj.TablePanel)
                obj.TablePanel = uipanel(obj.Parent);
            end
            obj.TablePanel.Title = '';
            obj.TablePanel.Units = 'pixel';
            obj.TablePanel.Position = obj.TablePanelPosition;
            obj.TablePanel.BorderType = 'none';
            obj.TablePanel.BackgroundColor = obj.BackgroundColor;
        end

        function createToolbarPanel(obj)
            if isempty(obj.ToolbarPanel)
                obj.ToolbarPanel = uipanel(obj.ToolbarPanel);
            end
            obj.ToolbarPanel.Title = '';
            obj.ToolbarPanel.Units = 'pixel';
            obj.ToolbarPanel.Position = obj.getToolbarPosition;
            obj.ToolbarPanel.BorderType = 'none';
            obj.ToolbarPanel.BackgroundColor = obj.BackgroundColor;
        end
        
        function rowNumber = getComponentRowNumber(obj, h)
        %getComponentRowNumber Find which row the component h belongs to.
        %
        %   Useful for callback functions that need to work on rows in the
        %   original data.
        
            rowFields = fieldnames(obj.RowControls);
            
            for iField = 1:numel(rowFields)
                columnControls = [obj.RowControls.(rowFields{iField})];
                isMatched = ismember(columnControls, h);
                if any(isMatched)
                    rowNumber = find(isMatched);
                end
            end
        end
        
        function createTable(obj)
            
            for i = 1:obj.NumRows
                rowData = obj.getRowData(i);
                obj.createTableRow(rowData, i)
            end
        end
        
        function resetTable(obj)
        %resetTable Remove all rows.
        
            for i = obj.NumRows:-1:1
                obj.removeRow(i)
            end
        end
        
        function createTableRow(obj, rowData, rowNumber)
            
            try
                % This should be a subclass method...
                hRow = obj.createTableRowComponents(rowData, rowNumber);
                
% %             Todo: How to do this when some components does not have
% %             Fontname property 
% %
% %                 %Set common format properties...
% %                 handleArray = struct2cell(hRow);
% %                 handleArray = [handleArray{:}];
% %                 set(handleArray, 'FontName', obj.FontName);
                
                
                if isempty(obj.RowControls)
                    obj.RowControls = hRow;
                else
                    obj.RowControls(rowNumber) = hRow;
                end
                
            catch ME
                rethrow(ME)
            end
        end

        function getColumnPositions(obj, rowNum)

        end
        
        function [x, y, w, h] = getCellPosition(obj, rowNum, columnNum, h)
        %getCellPosition Return position values for cell as variables
            
            if nargin < 4
                h = obj.DEFAULT_COMPONENT_HEIGHT;
            end

            y = obj.RowLocations(rowNum);
            x = obj.ColumnLocations(columnNum);
            w = obj.ColumnWidths(columnNum);
            
            % Update y position so that component is centered on row
            rowExtent = obj.RowHeight + obj.RowSpacing;

            yOffset = ( rowExtent - h ) / 2;
            %y = y + yOffset;
        end
        
        function centerComponent(obj, hComponent, yPos)
            yHeight = obj.RowHeight + obj.RowSpacing;
            
            yOffset = ( yHeight - hComponent.Position(4) ) / 2;
            hComponent.Position(2) = yPos + yOffset;
        end
        
        function onTableRowSelected(obj, src, ~)
        
            iRow = obj.getComponentRowNumber(src);
            hRow = obj.RowControls(iRow);
            
            % Get (or set) selection value of the selection checkbox
            if isequal(src, hRow.CheckboxSelector)
                isSelected = hRow.CheckboxSelector.Value;
            else
                hRow.CheckboxSelector.Value = ~hRow.CheckboxSelector.Value;
                isSelected = hRow.CheckboxSelector.Value;
            end
            
            % Update backgrond color of table row based on selection state
            obj.updateTableRowBackground(iRow, isSelected)

            if isSelected
                % Add row number to list of selected rows
                obj.SelectedRows = [obj.SelectedRows, iRow];
            else
                % Remove row number from list of selected rows
                obj.SelectedRows = setdiff(obj.SelectedRows, iRow, 'stable');
            end
        end
        
        function position = getToolbarPosition(obj)
        %getToolbarPosition Get position of toolbar above main panel.
        
            HEIGHT = 30;
            MARGINS = [3,4]; %x, y
            
            referencePosition = obj.Parent.Position;
            
            % Toolbar is aligned to reference panel in x and above in y
            location = referencePosition(1:2) + [0, referencePosition(4)];
            
            % Add offset based on margin size
            location = location + MARGINS;
            
            size = [referencePosition(3) - 2*MARGINS(1), HEIGHT];
            
            position = [location, size];
        end
        
        function createToolbarComponents(obj, ~)
            % Subclass should override if it implements a toolbar
        end
        
        function toolbarComponents = getToolbarComponents(obj)
            % Subclass should override if it implements a toolbar
            toolbarComponents = [];
        end
        
        function showToolbar(obj)
            % Subclass should override if it implements a toolbar
        end
        
        function hideToolbar(obj)
            % Subclass should override if it implements a toolbar
        end
            
%         function pathStr = getTableRowBackground(obj, varargin)
%         %getTableRowBorder Get path to image containing a table row border    
%             
%         
%         % Todo: Implement with keywords for where border should be and for
%         % background color
%         %
%         % Todo: Find a much smarter way to do this!
%             
%             imageName = strjoin( [{'TableBackground'}, varargin{:}], '_' );
%             
%             % If image already exists, return pathstr
%             if isfield(obj.ImageGraphicPaths, imageName)
%                 pathStr = obj.ImageGraphicPaths.(imageName);
%                 return
%             end
%             
%             % Else: Create and save a temporary image.
%             h = obj.RowHeight + obj.RowSpacing;
%             w = obj.TablePanelPosition(3);
%             
%             if any(strcmp(varargin(1:2:end), 'Selection'))
%                 matchedInd = find( strcmp(varargin(1:2:end), 'Selection') );
%                 matchedValue = varargin{matchedInd*2};
%                 switch matchedValue
%                     case 'on'
%                         bgColor = obj.RowSelectedBackgroundColor;
%                     case 'off'
%                         bgColor = obj.RowBackgroundColor;
%                     otherwise
%                         error('Invalid value for parameter name "Selection"')
%                 end
%             else
%                 bgColor = obj.RowBackgroundColor;
%             end
%             
%             % Create background image.
%             colorData = ones(h,w,3) .* reshape(bgColor, 1, 1, 3);
%             
%             % Add border
%             if  any(strcmp(varargin(1:2:end), 'BorderType'))
%                 matchedInd = find( strcmp(varargin(1:2:end), 'BorderType') );
%                 matchedValue = varargin{matchedInd*2};
%                 switch matchedValue
%                     case 'left'
%                         error('Bordertype is not implemented :(')
%                     case 'right'
%                         error('Bordertype is not implemented :(')
%                     case 'bottom'
%                         colorData(h, :, :) = repmat(obj.TableBorderColor, w, 1);
%                     case 'top'
%                         colorData(1, :, :) = repmat(obj.TableBorderColor, w, 1);
%                     case 'all'
%                         error('Bordertype is not implemented :(')
%                     otherwise
%                         error('Bordertype is not implemented :(')
%                 end
%             end
%             
%             pathStr = [tempname, '.png'];
%             imwrite(colorData, pathStr, 'png', 'Transparency', [1,1,1]);
%             obj.ImageGraphicPaths.(imageName) = pathStr;
%  
%         end
%             
    end
    
    methods (Access = protected) % Callbacks
        
        function onHelpButtonClicked(obj, src, ~)
        %onHelpButtonClicked Show help message using uialert
        
            if isempty(obj.ColumnHeaderHelpFcn);    return;     end
        
            hFigure = ancestor(obj.Parent, 'figure');
            
            msg = obj.ColumnHeaderHelpFcn(src.Tag);
            title = sprintf('Help for %s', src.Tag);
            uialert(hFigure, msg, title, 'Icon', 'info')
        end
        
        function onParentResized(obj, src, evt)
            % Todo: Recall how to do this with uifigures...
            obj.autoAssignPosition()
            obj.configureLayout()
            
            if ~obj.NumColumns == 0
                obj.ColumnLocations = obj.calculateColumnPositions();
            end
            
            if ~obj.NumRows == 0
                obj.RowLocations = obj.calculateRowPositions();
            end
            
            % Update positions:
            for i = 1:obj.NumRows
                for j = 1:obj.NumColumns
                    [x, y, w, h] = obj.getCellPosition(i, j);
                    obj.TableComponentCellArray{i,j}.Position = [x,y,w,h];
                    obj.centerComponent(obj.TableComponentCellArray{i,j}, y)
                end
            end
        end
        
        function onShowToolbarPropertySet(obj)
            
            if ~obj.IsConstructed; return; end
            
            if obj.ShowToolbar
                obj.showToolbar()
            else
                obj.hideToolbar()
            end
        end
    end
    
    methods % Table utility functions
        
        function addRow(obj, rowNumber, rowData)
        %addRow Add a row to the table.
        %
        %   This function first grows the Data and RowControls properties
        %   by appending an entry at the end, then uses indexing to
        %   rearrange the entries in the right order.
        
            % Important: Get this before Data property is changed.
            oldInd = 1:obj.NumRows;
            oldRowLocations = obj.RowLocations;

            % Todo: Make sure this works with tables as well as structs.
            % Todo: Make sure we get right fieldnames and datatype for each
            % field.
            if nargin < 3 || isempty(rowData)
                obj.Data(end+1).Name = '';
            else
                obj.Data(end+1) = rowData;
            end
            
            % Add as last row if no rowNumber is specified
            if nargin < 2 || isempty(rowNumber)
                rowNumber = obj.NumRows;
            end
            
            % Set the order for the rows based on where the new row should
            % be inserted.
            newInd = [oldInd(1:rowNumber-1), obj.NumRows, oldInd(rowNumber:end)];
            obj.Data = obj.Data(newInd);
            
            % Calculate the displacement for existing rows within table
            %obj.RowLocations = obj.calculateRowPositions();
            newRowLocations = obj.RowLocations;
            newRowLocations(rowNumber) = [];
            
            % Update positions of existing rows in the table panel
            obj.updateRowPositions(newRowLocations - oldRowLocations)
            
            % Important: Make space for new row in the RowComponents
            % property before calling the method to create the new row.
            
            if ~isempty(obj.RowControls)
                tempStruct(2) = obj.RowControls(1);
                obj.RowControls(end+1) = tempStruct(1); 
                obj.RowControls = obj.RowControls(newInd);
            end
            
            % Create the new row in the specified row index position
            rowData = obj.getRowData(rowNumber);
            obj.createTableRow(rowData, rowNumber)
        end
        
        function removeRow(obj, rowNumber)
        %removeRow Remove a row from the table.
        
            % Important: Get this before Data property is changed.
            oldRowLocations = obj.RowLocations;
            
            % Remove row at given row number from data
            if isa(obj.Data, 'struct') || isobject(obj.Data)
                obj.Data(rowNumber) = [];
            elseif isa(obj.Data, 'table')
                obj.Data(rowNumber, :) = [];
            end

            % Remove uicomponents from table row
            rowFields = fieldnames(obj.RowControls);
            for iField = 1:numel(rowFields)
                delete(obj.RowControls(rowNumber).(rowFields{iField}))
            end
            obj.RowControls(rowNumber) = [];
            
            
            % Return here if there are no rows left in table
            if obj.NumRows == 0
                %obj.RowLocations = [];
                return
            end
            
            % Update positions of existing rows.
            oldRowLocations(rowNumber) = [];
            %obj.RowLocations = obj.calculateRowPositions();
            
            rowDisplacements = obj.RowLocations - oldRowLocations;
            obj.updateRowPositions(rowDisplacements)
        end

        function updateData(obj, newData)
            
            for i = obj.NumRows:-1:1
                obj.removeRow()
            end
            
            obj.Data = newData;
            obj.createTable()
            
%             for i = 1:numel(newData)
%                 obj.addRow(i, newData(i));
%             end
        end
        
    end

end