classdef uiwTaskTable < uiw.mixin.AssignPVPairs
%uiwTaskTable Display tasks from the queue processor in a table
%
%   This class provides an interface for displaying a table of tasks from
%   the queueprocessor in a uipanel.
%
%   Also provides method for interacting with tasks from the gui.

    % TODO:
    %  1 Same right click functionality as in info table. E.g. right click
    %    should select new cell and rightclick when many cells are selected
    %    should not deselect..
    %  2 Select the whole row.
    
% Resizing.
%
%   Some tradeoffs with table resizing:
%   - if columnresizepolicy is off, columns does not stretch when
%     table is resized, but they can be made larger than table...
%   - if columnresizepolizy is on, columns stretches, but can not be made
%     larger than table...

    properties
        
        TableMode = 'queue' % Or 'history'
        ColumnNames
        ColumnEditable
        CellEditCallback = []
        KeyPressFcn = []
        
        MouseButtonRightPressCallbackFcn = [] % Callback to use for modifying contextmenus based on the rightclick selection
        
        UIContextMenu
        Parent
        Table
        BackendType
    end
    
    properties (Dependent)
        Position
    end
    
    properties (Dependent)
        selectedRows
    end
   
    methods % Structors
        
        function obj = uiwTaskTable(varargin)
            
            obj.assignPVPairs(varargin{:})
            
            obj.create()
            
            obj.createListeners()
            
        end
        
        function delete(~)
            
        end
    end
    
    methods % Public
        
        function addTask(obj, tableRow, insertAt)
            
            if isempty(obj.Table.Data)
                obj.Table.Data = tableRow{:,:};
            else
                switch insertAt
                    case 'beginning'
                        obj.Table.Data = cat(1,  tableRow{:,:}, obj.Table.Data);
                    case 'end'
                        obj.Table.Data(end+1, :) = tableRow{:,:};
                end
            end
        end
       
        function clearTable(obj)
            obj.Table.Data = cell(0, numel(obj.ColumnNames));
        end
        
        function selectedRows = get.selectedRows(obj)
            switch obj.BackendType
                case 'modern'
                    selectedRows = obj.getModernSelectedRows();
                case 'legacy'
                    selectedRows = obj.Table.SelectedRows;
            end
        end

        function set.selectedRows(obj, selectedRows)
            obj.setSelectedRows(selectedRows)
        end

        function updateLayout(obj)
            obj.updateTablePosition()
        end

        function setSelectedRows(obj, selectedRows)
            switch obj.BackendType
                case 'modern'
                    obj.Table.Selection = selectedRows(:);
                case 'legacy'
                    obj.Table.SelectedRows = selectedRows;
            end
        end

        function setCell(obj, rowIdx, columnIdx, newValue)
            if strcmp(obj.BackendType, 'legacy') && ismethod(obj.Table, 'setCell')
                obj.Table.setCell(rowIdx, columnIdx, newValue)
                return
            end

            tableData = obj.Table.Data;
            tableData(rowIdx, columnIdx) = newValue;
            obj.Table.Data = tableData;
        end

        function setColumnWidths(obj, preferredWidth, minWidth, maxWidth)
            switch obj.BackendType
                case 'modern'
                    obj.Table.ColumnWidth = num2cell(preferredWidth);
                case 'legacy'
                    if nargin >= 4
                        obj.Table.ColumnMaxWidth = maxWidth;
                    end
                    if nargin >= 3
                        obj.Table.ColumnMinWidth = minWidth;
                    end
                    obj.Table.ColumnPreferredWidth = preferredWidth;
            end
        end

        function showContextMenu(obj, event)
            if strcmp(obj.BackendType, 'modern') || isempty(obj.UIContextMenu)
                return
            end

            figurePos = obj.Table.tablepoint2figurepoint(event.Position);
            obj.UIContextMenu.Position(1:2) = figurePos + [0, 40]; % Correct y pos, 40 pixels, no idea why or if it is consistent across systems..
            obj.UIContextMenu.Visible = 'on';
        end

        function setContextMenu(obj, contextMenu)
            obj.UIContextMenu = contextMenu;
            obj.onContextMenuSet()
        end

        function setKeyPressFcn(obj, keyPressFcn)
            obj.KeyPressFcn = keyPressFcn;
            if ~isempty(keyPressFcn) && ~isempty(obj.Table) && ...
                    isvalid(obj.Table) && isprop(obj.Table, 'KeyPressFcn')
                obj.Table.KeyPressFcn = keyPressFcn;
            end
        end
    end
    
    methods %Set/get
        
        function set.Position(obj, pos)
            obj.Table.Position = pos;
        end
        function pos = get.Position(obj)
            pos = obj.Table.Position;
        end

    end
    
    methods (Access = private)
                
        function create(obj)

            [obj.Table, obj.BackendType] = obj.createTableBackend();
            obj.Table.ColumnName = obj.ColumnNames;
            obj.updateTablePosition()

            numColumns = numel(obj.ColumnNames);

            if ~isempty(obj.ColumnEditable)
                obj.Table.ColumnEditable = obj.ColumnEditable;
            else
                obj.Table.ColumnEditable = logical([0,0,0,0,0,1]);
            end

            if strcmp(obj.BackendType, 'modern')
                obj.Table.ColumnFormat = repmat({'char'}, 1, numColumns);
            else
                obj.Table.ColumnFormat = {'char', 'char', 'char', 'char', 'popup', 'char'};
            end

            if strcmp(obj.BackendType, 'legacy')
                % Specify empty data to draw the table with the numbered column
                obj.Table.Data = cell(2, numColumns);

                tablePixelPos = getpixelposition(obj.Table);
                width = tablePixelPos(3);
                obj.Table.ColumnPreferredWidth = arrayfun(...
                    @(i) round(width/numColumns), 1:numColumns, 'uni', 1 );
            end

            obj.clearTable()
        end

        function [tableHandle, backendType] = createTableBackend(obj)
            if nansen.util.useModernUiComponents()
                tableHandle = uitable(obj.Parent, ...
                    'Tag', obj.TableMode, ...
                    'FontSize', 8, ...
                    'FontName', 'avenir next', ...
                    'Units', 'pixels', ...
                    'Position', [0 0 1 1]);

                tableHandle.SelectionType = 'row';
                tableHandle.Multiselect = 'on';
                tableHandle.CellEditCallback = @obj.onCellEdited;
                tableHandle.SelectionChangedFcn = @obj.onModernSelectionChanged;
                if ~isempty(obj.KeyPressFcn) && isprop(tableHandle, 'KeyPressFcn')
                    tableHandle.KeyPressFcn = obj.KeyPressFcn;
                end

                backendType = 'modern';
            else
                tableHandle = uim.widget.StylableTable('Parent', obj.Parent, ...
                'Tag',obj.TableMode,...
                'Editable', true, ...
                'RowHeight', 20, ...
                'FontSize', 8, ...
                'FontName', 'helvetica', ...
                'FontName', 'avenir next', ...
                'SelectionMode', 'discontiguous', ...
                'Sortable', false, ...
                'ColumnResizePolicy', 'subsequent', ...
                'Units','pixels', ...
                'Position',[0 0.0 1 1], ...
                'MouseClickedCallback', @obj.onLegacyMouseClicked);

                tableHandle.CellEditCallback = @obj.onCellEdited;
                if ~isempty(obj.KeyPressFcn) && isprop(tableHandle, 'KeyPressFcn')
                    tableHandle.KeyPressFcn = obj.KeyPressFcn;
                end

                backendType = 'legacy';
            end
        end
        
        function createListeners(obj)
            
            addlistener(obj.Parent, 'ObjectBeingDestroyed', @(s,e) obj.delete);
            addlistener(obj.Parent, 'SizeChanged', @(s,e) obj.onSizeChanged);
        end
        
        function onLegacyMouseClicked(obj, src, event)
        %onLegacyMouseClicked Select row and prepare context menu on right click.

            if ~exist('obj', 'var') || ~isvalid(obj); return; end

            cellNum = event.Cell;
            rowNum = cellNum(1);
            
            if rowNum == 0; return; end
            
            %hFig = ancestor(obj.Parent, 'figure');
            
            switch event.SelectionType
                case {'normal', 'extend'}
                    % Do nothing.

                case 'open'

                case {'alt'}
                    if ~ismember(rowNum, obj.Table.SelectedRows)
                        obj.Table.SelectedRows = rowNum;
                    end
                    
                    if ~isempty(obj.MouseButtonRightPressCallbackFcn)
                        obj.MouseButtonRightPressCallbackFcn(src, event)
                    end
            end
        end
        
        function onSizeChanged(obj, ~, ~)
            
            obj.updateTablePosition()
            
        end

        function updateTablePosition(obj)

            MARGINS = [10, 10];
            parentPos = uim.utility.getContentPixelPosition(obj.Parent);

            contentOrigin = max(parentPos(1:2), [1, 1]);
            tableSize = max(parentPos(3:4) - MARGINS*2, [1, 1]);
            newTablePosition = [contentOrigin + MARGINS - 1, tableSize];
            obj.Table.Position = newTablePosition;
            
        end

        function onContextMenuSet(obj)
            if isempty(obj.Table) || ~isvalid(obj.Table) || isempty(obj.UIContextMenu)
                return
            end

            if strcmp(obj.BackendType, 'modern')
                obj.Table.ContextMenu = obj.UIContextMenu;
                obj.UIContextMenu.ContextMenuOpeningFcn = @obj.onModernContextMenuOpening;
            end
        end

        function onModernContextMenuOpening(obj, ~, ~)
            selectedRowIndices = obj.selectedRows;
            if isempty(selectedRowIndices) || isempty(obj.MouseButtonRightPressCallbackFcn)
                return
            end

            evtData = uiw.event.EventData(...
                'Cell', [selectedRowIndices(1), 1], ...
                'SelectionType', 'alt', ...
                'Button', 3, ...
                'Position', [0, 0]);
            obj.MouseButtonRightPressCallbackFcn(obj.Table, evtData)
        end

        function onModernSelectionChanged(~, ~, ~)
            % Selection is read directly from the native table when needed.
        end

        function onCellEdited(obj, src, evt)
            if isempty(obj.CellEditCallback)
                return
            end

            newValue = obj.getEventValue(evt, {'NewValue', 'NewData'});
            previousValue = obj.getEventValue(evt, {'PreviousValue', 'PreviousData'});
            evtData = uiw.event.EventData(...
                'Indices', evt.Indices, ...
                'NewValue', newValue, ...
                'PreviousValue', previousValue);
            obj.CellEditCallback(src, evtData)
        end

        function rowIndices = getModernSelectedRows(obj)
            selection = obj.Table.Selection;

            if isempty(selection)
                rowIndices = [];
            elseif isvector(selection)
                rowIndices = selection(:).';
            elseif size(selection, 2) == 2
                rowIndices = unique(selection(:,1).', 'stable');
            else
                rowIndices = selection(:).';
            end
        end

        function value = getEventValue(~, evt, propertyNames)
            value = [];

            for i = 1:numel(propertyNames)
                if isprop(evt, propertyNames{i})
                    value = evt.(propertyNames{i});
                    return
                end
            end
        end
        
    end % /methods (Access = private)
    
end
