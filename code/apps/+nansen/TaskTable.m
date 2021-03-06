classdef TaskTable < uiw.mixin.AssignPVPairs
    
   
% Some java table properties
%     gridColor
%     intercellSpacing
%     showVerticalLines
%     selectionBackground
%     selectionForeground
%
%       How to change header appearance
        
    
    % TODO:
    %  1 Same right click functionality as in info table. E.g. right click
    %    should select new cell and rightclick when many cells are selected
    %    should not deselect..
    %  2 Select the whole row.
    
    
% Create a basic java table.....  
%             obj.Table = javacomponent('javax.swing.JTable', position, hParent);

    
    
    properties
        
        TableMode = 'queue' % Or 'history'
        
        Parent
        Position
        Table
        jTable
       
        ColumnNames
        ColumnEditable
        
    end
    
    
    properties
        selectedRows
    end
   
   
   
   
    methods
        
        function obj = TaskTable(varargin)
            
            obj.assignPVPairs(varargin{:})
            
            obj.create()
            
        end
       

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
            obj.Table.Data = {}; % Reset Data.
        end
        
        
    end
    
    
    methods (Access = private)
        
                
        function create(obj)
            
            obj.Table = uitable(obj.Parent);

% %             obj.Table = uiw.widget.Table('Parent', obj.Parent, ...
% %                 'Tag',obj.TableMode,...
% %                 'Editable', true, ...
% %                 'RowHeight', 20, ...
% %                 'FontSize', 8, ...
% %                 'FontName', 'helvetica', ...
% %                 'FontName', 'avenir next', ...
% %                 'SelectionMode', 'discontiguous', ...
% %                 'Sortable', false, ...
% %                 'Units','normalized', ...
% %                 'Position',[0 0.0 1 1] );
            
            % Set position
            if isempty(obj.Position)
                obj.Table.Units = 'pixel';
                pixelpos = getpixelposition(obj.Parent);
                obj.Table.Position = [1 0 pixelpos(3:4)];
                obj.Table.Units = 'normalized';
            else
                obj.Table.Position = obj.Position;
            end
            
            obj.Table.ColumnName = obj.ColumnNames;
            
            numColumns = numel(obj.ColumnNames);
            

            obj.Table.ColumnEditable = obj.ColumnEditable;
            
            %logical([0,0,0,0,0,1]);
            
            % Change appearance
            obj.Table.FontName = 'Avenir New';
            obj.Table.FontSize = 10;
            
            
            %obj.Table.CellSelectionCallback = @obj.onCellSelection;

            
            
            % Make some configurations on underlying java object
            jScrollPane = findjobj(obj.Table);
 
            % We got the scrollpane container - get its actual contained table control
            obj.jTable = jScrollPane.getViewport.getComponent(0);
            obj.jTable = handle(obj.jTable, 'CallbackProperties');
            
            set(obj.jTable, 'MousePressedCallback', @obj.tableMousePress);

        
            % Specify empty data to draw the table with the numbered column
            obj.Table.Data = cell(2, numColumns);
            
            % Get size of visible table area.
            javaRect = get(jScrollPane, 'ViewportBorderBounds');
            width = javaRect.getWidth();
            
            % Set columnwidths
            obj.Table.ColumnWidth = arrayfun(@(i) round(width/numColumns), 1:numColumns, 'uni', 0 ); 

            obj.Table.Data = {}; % Reset Data.
        end
        
        
        function tableMousePress(obj, ~, event)
        %tableMousePress Callback for mousepress in table.
        %
        %   This function is primarily used for 
        %       1) Creating an action on doubleclick
        %       2) Selecting cell on right click    

            if ~exist('obj', 'var') || ~isvalid(obj); return; end


            % Get the cell which is clicked using the awt.point and
            % rowAtPoint method. NB! Indexing starts at 0 for java objects
            mousePos = java.awt.Point(event.getX, event.getY);

            i = obj.jTable.rowAtPoint(mousePos);
            j = obj.jTable.columnAtPoint(mousePos);

            hFig = ancestor(obj.Parent, 'figure');
            
            switch hFig.SelectionType
                case {'normal', 'extend'}
                    % Do nothing.

                case 'open'

                    if isequal(get(event, 'button'), 3)
                        return
                    end


                case {'alt'}
                    % Change selection if new session is selected. Skip if
                    % another column is selected.
                    if j == 0 && ~ismember(i+1, obj.selectedRows)
                        obj.jTable.changeSelection(i,0,false,false)  % 3rd = toggle, 4th = extend
    %                         src.changeSelection(i, j, false, false) To select
    %                         different column
                    end

            end
            
        end
        
        

         % Cell selection callback: UITableSessionList 
        function onCellSelection(obj, src, event)
            
            % Is all this necessary for getting row selection??
            
            ii = transpose( unique( event.Indices(:, 1) ) );
            
            numCols = size(obj.Table.Data,2);
            numColsSelected = histcounts(event.Indices(:, 1), 'BinMethod', 'integer', 'BinLimits', [1, numCols]);
            
            isRowSelected = find(numColsSelected == numCols);
            
            
            if all(ismember(ii, isRowSelected))
                disp('debug')
                return 
            end
            
%             return
            
            % Remove deleselected rows.
            isDeselected = ~ismember(obj.selectedRows, ii);
            if sum(isDeselected)>0
                extend = true;
            else
                extend = true;
            end
            
            
            isNew = ~ismember(ii, isRowSelected);
            
            if isempty(isNew)
                isNew = true(size(ii));
            end
            
%             isNew = true(size(ii));

            
            obj.selectedRows(isDeselected) = [];

            if any(isNew)

                for i = ii(isNew)
                    
                    obj.selectedRows(end+1) = i;
                    jjInd = find(event.Indices(:, 1) == i);
%                     jjTmp = 1:numCols;
                    
                    jSelected = event.Indices(jjInd, 2);
                    
%                     if jSelected == 1
%                         jjTmp = [numCols, min([numCols,2])];
%                     else
%                         jjTmp = [numCols, jSelected+1, jSelected-1, 1];
%                     end
%                     
%                     jjTmp = unique(jjTmp);

                    if numel(jSelected) == numCols; continue; end
                    
                    if numel(jSelected) == 1
                        
                        if jSelected ~= 1 && jSelected ~= numCols
                            obj.jTable.changeSelection(i-1, jSelected-1, true, false)
                        end
                        
                    else
                        continue
                                            
                    end
                    
                    jjTmp = setdiff([numCols, 1], jSelected, 'stable');
                    
                    for j = jjTmp
                        obj.jTable.changeSelection(i-1, j-1, false, extend)  % 3rd = toggle, 4th = extend
                        extend = true;
                    end
                end
                
            end
            
            obj.selectedRows = unique(obj.selectedRows);

            
        end
        
        
    end % /methods (Access = private)
    
    
    
    
    
end