classdef RoiTable < applify.ModularApp & roimanager.roiDisplay & uiw.mixin.HasPreferences
%RoiTable A table showing roi information
    
    % Inherited properties
    %
    % SelectedRois    % List of rois (rows) that are selected in the table

    
    properties (Constant) % Inherited from applify.HasTheme via ModularApp
        DEFAULT_THEME = nansen.theme.getThemeColors('dark-gray');
    end
    
    properties (Constant ) % Inherited from applify.ModularApp
        AppName = 'Roi Info Table'
    end

    properties
        roiTable        % Keeps a data table with info for all rois
    end
    
    properties (Dependent) % Depends on uiw.widget.Table
        SelectionMode % can we select multiple: (['single'],'contiguous','discontiguous')
    end
    
    properties
        AllowRowDeletion = true % todo..
        KeyPressFcn
    end
    
    properties (Access = protected)
        UITable         % Handle to the ui table
    end
    
    properties (Access = private)
        WindowMousePressListener
        TableUpdatedListener
    end
    
    methods % Structors
        
        function obj = RoiTable(varargin)
        %RoiTable Create an instance of a RoiTable modular app
        
            [h, varargin] = applify.ModularApp.splitArgs(varargin{:});
            obj@applify.ModularApp(h);
            
            roiGroup = varargin{1}; % todo: check arg
            obj@roimanager.roiDisplay(roiGroup)
            
            obj.Panel.Units = 'normalized';
            
            if strcmp(obj.mode, 'standalone')
                obj.Figure.Position = obj.initializeFigurePosition();
            end
            
            roiTable = obj.rois2table(roiGroup.roiArray);
            obj.roiTable = roiTable;
            
            nansen.assert('WidgetsToolboxInstalled')
            obj.UITable = nansen.MetaTableViewer(obj.Panel, roiTable, 'MetaTableType', 'Roi');
            
            % Set table properties
            obj.UITable.HTable.hideHorizontalScroller()
            obj.UITable.HTable.hideVerticalScroller()
            obj.UITable.HTable.RowHeight = 18;
            obj.UITable.HTable.CellSelectionCallback = @obj.onTableSelectionChanged;
            obj.UITable.HTable.KeyPressFcn = @obj.onKeyPressedInTable;
            
            if roiGroup.roiCount > 0
                obj.updateRoiLabels()
            end
            
            obj.WindowMousePressListener = listener(obj.Figure, ...
                'WindowMousePress', @obj.onMousePressedInFigure);
            obj.TableUpdatedListener = listener(obj.UITable, ...
                'TableUpdated', @obj.onTableUpdated);
            
            obj.isConstructed = true;
        end
        
        function delete(obj)
            
            if strcmp(obj.mode, 'standalone') 
                if isvalid(obj.Figure)
                    % Save figure position to preferences
                    obj.setPreference('Position', obj.Figure.Position);
                    obj.savePreferences();
                end
            end
            
            if ~isempty(obj.WindowMousePressListener)
                delete(obj.WindowMousePressListener)
            end
            if ~isempty(obj.TableUpdatedListener)
                delete(obj.TableUpdatedListener)
            end
            
            delete(obj.UITable)
        end

    end

    
    methods
        
        function addRois(~)
            % This class can not add rois
        end
        
        function removeRois(obj)
        %removeRois
            
            if ~obj.AllowRowDeletion; return; end
            
            roiIdxToRemove = obj.SelectedRois;
            
            obj.UITable.HTable.Enable = 'off';
            obj.RoiGroup.changeRoiSelection([], [])
            
            obj.RoiGroup.removeRois(roiIdxToRemove);
            newSelection = obj.UITable.getSelectedEntries();
            obj.RoiGroup.changeRoiSelection([], newSelection)
            obj.UITable.HTable.JTable.requestFocus()
                        
            obj.UITable.HTable.Enable = 'on';

        end
        
        function updateRoiLabels(obj)
        %updateRoiLabels Update the roi ID labels in first table column    
            roiLabels = obj.RoiGroup.getRoiLabels(1:obj.RoiGroup.roiCount);
            obj.roiTable(:, 1) = roiLabels';
            obj.UITable.refreshTable(obj.roiTable)
        end
        
        function resetTableFilters(obj)
            if ~ all(obj.UITable.DataFilterMap(:))
                obj.UITable.resetColumnFilters()
            end
        end
    end
    
    methods % Set/get
        
        function set.SelectionMode(obj, newMode)
            if ~isempty(obj.UITable.HTable)
                obj.UITable.HTable.SelectionMode = newMode;
            end            
        end
        
        function mode = get.SelectionMode(obj)
            if ~isempty(obj.UITable.HTable)
                mode = obj.UITable.HTable.SelectionMode;
            else
                mode = '';
            end
        end
        
        function set.KeyPressFcn(obj, newValue)
            assert(isempty(newValue) || isa(newValue, 'function_handle'), ...
                'Value must be a function handle')
            obj.KeyPressFcn = newValue;
        end
        
    end
    
    methods (Access = private) 
        
        function onMousePressedInFigure(obj, src, evt)
            % Hide filter if mouse is pressed anywhere in figure.
            if ~isempty(obj.UITable.ColumnFilter)  
                obj.UITable.ColumnFilter.hideFilters();
            end
        end
        
        function onTableSelectionChanged(obj, src, evt)
        %onTableSelectionChanged Callback for if table selection changed
        %
        %   Get selected table rows and call the changeRoiSelection of
        %   roigroup to broadcast to all listeners.
        
        %   Todo: What if subset of table is visible. Need to convert table
        %   rows into roi indices...
        
            oldSelection = obj.SelectedRois;
            newSelection = obj.UITable.getSelectedEntries();
            
            obj.RoiGroup.changeRoiSelection(oldSelection, newSelection);
            
        end
        
        function onTableUpdated(obj, src, evt)            
            obj.RoiGroup.changeVisibleRois(evt.RowIndices, evt.Type);
        end
        
        function onKeyPressedInTable(obj, src, evt)
            
            switch evt.Key
                case {'↓', '↑', '←', '→', 'leftarrow', 'rightarrow', ...
                        'uparrow', 'downarrow'} % arrowkeys
                    if isempty(evt.Modifier) || ~strcmp(evt.Modifier, 'alt')
                        return % Reserved for moving up and down in table
                    end
                    
                case '⌫'
                    obj.removeRois()
                    return
            end
            
            if ~isempty(obj.KeyPressFcn)
                obj.KeyPressFcn(src, evt)
            end
            
        end
        
        function roiTable = rois2table(obj, roiArray)
                
            S = roimanager.utilities.roiarray2struct(roiArray);
            
            S = rmfield(S, {'coordinates', 'imagesize', 'boundary', ...
                'connectedrois', 'layer', 'tags', 'enhancedImage', ...
                'pixelweights'} );
            
            % add column with label and number for roi
            [S(:).ID] = deal({''});
            S = orderfields(S, ['ID', setdiff(fieldnames(S), 'ID', 'stable')' ]);
            
            if ~isempty(roiArray)
                roiStats = getappdata(roiArray, 'roiStats');
                if ~isempty(roiStats)
                    S = utility.struct.mergestruct(S, roiStats);
                end
            end
            
            roiTable = struct2table(S, 'AsArray', true);
        end
        
        function updateTableRow(obj, rowIdx, tableRowData)
                        
            % Get the roi id from the current table and replace:
            tableRowData(1, 1) = obj.roiTable(rowIdx, 1);
            obj.roiTable(rowIdx, :) = tableRowData;
            
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
            obj.UITable.updateCells(rowIdx, colIdx, newData)
                        
        end
        
    end
    
    methods (Access = protected) % Inherited from applify.ModularApp

        % use for when restoring figure size from maximized
        function pos = initializeFigurePosition(obj)
            initPos = initializeFigurePosition@applify.ModularApp(obj);
            pos = obj.getPreference('Position', initPos);
        end

        function resizePanel(obj, src, evt)
            
            parentPosition = getpixelposition(obj.Panel);
            obj.UITable.HTable.Units = 'pixel';
            obj.UITable.HTable.Position(1:2) = [5,5];
            obj.UITable.HTable.Position(3) = parentPosition(3)-10;
            if strcmp(obj.mode, 'standalone')
                obj.UITable.HTable.Position(4) = parentPosition(4)-10;
            else
                obj.UITable.HTable.Position(4) = parentPosition(4)-20;
            end
            
            
        end
        
    end
    
    methods (Access = protected) % Inherited from roimanager.roiDisplay
        
        function onRoiGroupChanged(obj, evtData)
            
            oldTable = obj.roiTable;

            % fprintf('Index event listener callback 1: %d\n', evtData.roiIndices) % debug 

            % Take action for this EventType
            switch lower(evtData.eventType)
                
                case {'initialize', 'append'}
                    T = obj.rois2table(evtData.roiArray);
                    if isempty(oldTable)
                        newTable = T;
                    else
                        newTable = cat(1, oldTable, T);
                    end
                    
                case 'insert'
                    T = obj.rois2table(evtData.roiArray);
                    ind = evtData.roiIndices;
                    newTable = utility.insertRowInTable(oldTable, T, ind);
                    
                case {'modify', 'reshape'}
                    T = obj.rois2table(evtData.roiArray);
                    
                    % Update cells of modified entries.
                    if numel(evtData.roiIndices) == 1
                        obj.updateTableRow( evtData.roiIndices, T );
                        return
                    elseif numel(evtData.roiIndices) == 0
                        return
                    end
                    
                    newTable = oldTable;
                    newTable(evtData.roiIndices, :) = T;
                    
                case 'remove'
                    newTable = obj.roiTable;
                    newTable(evtData.roiIndices,:) = [];
                    
            end
            
            % Update the values of the roi ids / roi labels
            if obj.RoiGroup.roiCount ~= 0 

                if contains(lower(evtData.eventType), {'modify', 'reshape'})
                    roiInd = evtData.roiIndices;
                else
                    % Need to update all labels if rois were added/removed
                    roiInd = 1:obj.RoiGroup.roiCount;
                end
                
                roiLabels = obj.RoiGroup.getRoiLabels(roiInd);
                nRow = size(newTable, 1); % Roigroup might update faster than table if rois are added quickly...
                newTable{roiInd(1:nRow), 1} = roiLabels(1:nRow)';
            end
             
            % Update table data and uitable.
            obj.roiTable = newTable;
            obj.UITable.refreshTable(newTable)
            
        end
        
        function onRoiSelectionChanged(obj, evtData)
        %onRoiSelectionChanged "RoiSelectionChanged" event callback
        %
        %   Update the table selection when roi selection changed.    
        %   Use getSelectedEntries and setSelectedEntries because it
        %   takes sorting order into consideration.
            
            % Todo: Implement row to roi when table filtering is
            % implemented.
            
            currentRowSelection = obj.UITable.getSelectedEntries();
            newRowSelection = evtData.NewIndices;
            
            % Only set new selection if its different than current 
            % selection to prevent an infinite loop. Feel like this will
            % come back and bite me hard...
            if ~isequal( sort(currentRowSelection), sort(newRowSelection) )
                
                
                obj.UITable.setSelectedEntries(newRowSelection);
                obj.SelectedRois = newRowSelection;
            else
                obj.SelectedRois = newRowSelection;
            end
            
        end
        
        function onVisibleRoisChanged(obj, evtData)
            
            if isempty(obj.UITable); return; end
            
            obj.VisibleRois = evtData.NewVisibleInd;
            if ~strcmp(evtData.Type, 'RoiTableFilter')
                obj.UITable.updateVisibleRows(obj.VisibleRois)
            end
            
        end

        function onRoiClassificationChanged(obj, evtData)
            
        end
        
    end
    
    methods (Access = {?applify.ModularApp, ?applify.DashBoard} )
        
        function onKeyPressed(obj, src, evt)
            % Todo implement...
            obj.onKeyPressedInTable(src, evt)
        end
        
    end
    
    methods (Access = protected) 
        
        function onThemeChanged(obj) % Override superclass implementation
            
            onThemeChanged@applify.ModularApp(obj)
            S = obj.Theme;
            
            obj.UITable.HTable.BackgroundColor = S.HeaderBgColor;
            obj.UITable.HTable.Theme = S.TableTheme;
        end
        
    end

end