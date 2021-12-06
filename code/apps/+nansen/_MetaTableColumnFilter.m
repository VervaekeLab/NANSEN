classdef MetaTableColumnFilter < handle
    
    
    properties
        AppReference
        ComponentPanel 
        
        hColumnFilterPopups
        
        columnFilterType
        isColumnFilterActive
        isColumnFilterDirty 
        
    end
    
    properties (SetAccess = private) %?
        % Question: Is this the MetaTable object or the metatable table???
        MetaTable   % The MetaTable to use for retrieving column layouts.
        MetaTableUi
    end
    
    properties (Access = private, Hidden)
        MetaTableChangedListener
    end
    
    
    methods
        
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
        
        function onMetaTableChanged(obj)
        %onMetaTableChanged Make necessary updates to property values.
        
            % Get the variable names of the metatable
            varNames = obj.MetaTableUi.MetaTable.Properties.VariableNames;
            numColumns = numel(varNames);
            
            % Assign the cell array version of meta table to property
            obj.MetaTable = obj.MetaTableUi.MetaTableCell;
            
            if ~isempty(obj.hColumnFilterPopups)
                cellfun(@(c) delete(c), obj.hColumnFilterPopups)
            end
            
            obj.hColumnFilterPopups = cell(numColumns,1);
            
            obj.columnFilterType = repmat({'N/A'}, numColumns, 1);
            obj.isColumnFilterActive = false(numColumns,1);
            obj.isColumnFilterDirty = false(numColumns,1);
            
        end
        
        function openFilterControl(obj, columnIdx)
            
            if ~isempty(obj.hColumnFilterPopups{columnIdx})
                if obj.isColumnFilterDirty(columnIdx)
                    obj.refreshFilterControls(columnIdx)
                    obj.isColumnFilterDirty(columnIdx) = false;
                end
                obj.hColumnFilterPopups{columnIdx}.Visible = 'on';
            else
                obj.initializeColumnFilterControl(columnIdx);
            end
        end
        
        
        function initializeColumnFilterControl(obj, columnIdx)
            
            % Need table column data.
            columnData = obj.MetaTable(:, columnIdx);
                        
            switch class(columnData{1})
                case 'char'
                    
                    uniqueColumnData = unique(columnData);

                    if numel(uniqueColumnData) < numel(columnData)
                        
                        filterChoices = cat(1, 'Show All', uniqueColumnData);
                        
                        obj.createListboxSelector(filterChoices, columnIdx)
                        obj.columnFilterType{columnIdx} = 'multiSelection';

                    else % Todo: Create a auto-search input dlg.
                        
                    end
                    
                case 'double'
                   

            
            end
            
        end
        
        function refreshFilterControls(obj, columnIdx)

            % Need table column data.
            columnData = obj.MetaTable(:, columnIdx);
            
            switch obj.columnFilterType{columnIdx}
                case 'multiSelection'
                    uniqueColumnData = unique(columnData);

                    if numel(uniqueColumnData) < numel(columnData)
                        filterChoices = cat(1, 'Show All', uniqueColumnData);
                        obj.hColumnFilterPopups{columnIdx}.String = filterChoices;
                        obj.hColumnFilterPopups{columnIdx}.Value = 1;
                    end
            end
        end
        
        function onColumnFilterUpdated(obj, src, evt, columnIdx)
        %onColumnFilterUpdated Update table data when column filter changes
            
        
        % Todo: Update the row subset selection and then call the
        % updateTableView method
        
            %colInd = obj.getCurrentColumnSelection();
            T = obj.MetaTable;
            
            [numRows, numColumns] = size(T);
            
            % Initialize the filter matrix if this is the first time.
            if isempty(obj.MetaTableUi.DataFilterMap)
                obj.MetaTableUi.DataFilterMap = true(numRows, numColumns);
            end
            
            % Get column data for current columns
            columnData = T(:, columnIdx);            
            
            switch obj.columnFilterType{columnIdx}
                
                case 'multiSelection'
                    
                    h = obj.hColumnFilterPopups{columnIdx};
                    currentSelection = h.String(h.Value);
                    
                    if strcmp(currentSelection{1}, 'Show All')
                        obj.isColumnFilterActive(columnIdx) = false;
                        obj.MetaTableUi.DataFilterMap(:, columnIdx) = true;
                        h.Value = 1;
                        %obj.hColumnLabels(columnIdx).Color = ones(1,3)*0.8;
                    else
                        obj.isColumnFilterActive(columnIdx) = true;
                        TF = contains(columnData, currentSelection);
                        obj.MetaTableUi.DataFilterMap(:, columnIdx) = TF;
                        %obj.hColumnLabels(columnIdx).Color = obj.tableSettings.columnSpecialColor;
                        %obj.hColumnLabels(columnIdx).FontWeight = 'bold';
                    end
                    
                case 'searchField'
                    
                case 'dateIntervalSelector'
                    
                case 'numericRangeSelector'
                    
            end
            
            obj.MetaTableUi.updateTableView()
            
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
        
    end
    
    
end