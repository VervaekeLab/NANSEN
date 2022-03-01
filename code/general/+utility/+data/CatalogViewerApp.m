classdef CatalogViewerApp < applify.AppWindow
%CatalogViewerApp An app for viewing instances of the StorableCatalog    
%    
%   hApp = utility.data.CatalogViewerApp(catalog) opens an app to view the
%   provided catalog object
%

    % Created from PipelineBuilderUI. Should create a general table from
    % these two apps...
    
    % Todo: 
    %   [ ] Create functionality for inspecting cells that are structs, i.e
    %       open a new catalog, or a structeditor when doubleclicking cells.
    %   [ ] Button or tab for preferences. Save fig size and column widths
    %       to a "hidden" field in preferences?
    
    
    properties (Constant)
        AppName = 'Catalog Viewer'
    end
    
    properties 
        Catalog  % A catalog instance
    end
    
    properties (Access = protected)
        UITable
        TableContextMenu
    end
    
    
    methods % Constructor
        
        function obj = CatalogViewerApp(catalog)
           
            obj@applify.AppWindow()
            
            if ~nargin; return; end
            obj.Catalog = catalog;
            
            obj.createTable()
            obj.setComponentLayout()
            obj.createContextMenu()
            
            obj.setFigureName()
            obj.IsConstructed = true;
            
            if ~nargout
                clear obj
            end
            
        end
        
    end
    
    methods (Access = protected) % Override methods from applify.AppWindow
        
        function assignDefaultSubclassProperties(obj)
            obj.DEFAULT_FIGURE_SIZE = [760 420];
        end
        
        function setComponentLayout(obj)

            obj.UITable.Position(1:2) = obj.Margins(1:2);
            obj.UITable.Position(3:4) = obj.CanvasSize;
            
% %             % Todo:
% %             [~, colWidth] = uim.utility.layout.subdividePosition(1, ...
% %                 totalWidth, [60, 150, 1, 150], 0);
% %             obj.UITable.ColumnPreferredWidth = colWidth;
        end
        
        function setFigureName(obj)
            obj.Figure.Name = sprintf('%s (%s)', ...
                obj.AppName, class(obj.Catalog));
        end
        
    end
    
    methods (Access = private) % Create app components
        
        function createTable(obj)
                   
            % Create table
            obj.UITable  = uim.widget.StylableTable('Parent', obj.Figure, ...
                        'RowHeight', 25, ...
                        'FontSize', 8, ...
                        'FontName', 'helvetica', ...
                        'FontName', 'avenir next', ...
                        'Theme', uim.style.tableLight, ...
                        'Units', 'pixels' );
                    
            %obj.UITable.CellEditCallback = @obj.onTableCellEdited;
            %obj.UITable.CellSelectionCallback = @obj.onTableCellSelected;

            obj.UITable.MouseClickedCallback = @obj.onTableCellClicked;
            obj.UITable.KeyPressFcn = @obj.onKeyPressedInTable;
            
            if ~isempty(obj.Catalog)
                try
                    obj.UITable.DataTable = obj.Catalog.TabularData;
                catch
                    cellTable = table2cell( obj.Catalog.TabularData );
                    isStructCell = cellfun(@isstruct, cellTable);
                    
                    displayStr = @(c) sprintf('%dx%d %s', size(c,1), size(c,2), class(c));
                    
                    cellTable(isStructCell) = cellfun(@(c) displayStr(c), cellTable(isStructCell), 'uni', 0);
                    
                    obj.UITable.Data = cellTable;
                    obj.UITable.ColumnName = obj.Catalog.TabularData.Properties.VariableNames;
                end
            end
        end
        
        function createContextMenu(obj)
        
            obj.TableContextMenu = uicontextmenu(obj.Figure);
            mitem = uimenu(obj.TableContextMenu, 'Text', sprintf('Remove %s', obj.Catalog.ITEM_TYPE));
            mitem.Callback = @obj.onRemoveTaskMenuItemClicked;

        end
        
        function openTableContextMenu(obj, x, y)
            
            if isempty(obj.TableContextMenu); return; end
                        
            % Set position and make menu visible.
            obj.TableContextMenu.Position = [x, y];
            obj.TableContextMenu.Visible = 'on';
            
        end
        
    end

    methods (Access = protected) % Interactive callbacks
        
        function onTableCellClicked(obj, src, evt)
  
            if evt.Button == 3 || strcmp(evt.SelectionType, 'alt')
                obj.onMouseRightClickedInTable(src, evt)
            end
            
        end
        
        function onMouseRightClickedInTable(obj, src, evt)
            
            % Get row where mouse press ocurred.
            row = evt.Cell(1);

            % Select row where mouse is pressed if it is not already
            % selected
            if ~ismember(row, obj.UITable.SelectedRows)
                obj.UITable.SelectedRows = row;
            end

            % Open context menu for table
            figurePoint = obj.UITable.tablepoint2figurepoint(evt.Position);

            if ~isempty(obj.TableContextMenu)
                obj.openTableContextMenu(figurePoint(1), figurePoint(2));
            end
            
        end
        
        function onRemoveTaskMenuItemClicked(obj, src, evt)
            rowNumber = obj.UITable.SelectedRows;
            if ~isempty(rowNumber)
                item = obj.Catalog.getItem(rowNumber);

                obj.Catalog.removeItem(rowNumber)
                obj.UITable.DataTable(rowNumber,:) = [];
                fprintf('Removed item %s\n', obj.Catalog.getItemName(item))

            end
        end
    
    end
    
end