classdef RoiTable < applify.ModularApp & roimanager.roiDisplay & uiw.mixin.HasPreferences

    % TODO:
    %  [x] make setSelectedEntries for uitable, so that selection works
    %      also when rows are sorted
    %  [x] Fix bug when selecting from sorted tables...
    
    
    properties (Constant) % Inherited from applify.HasTheme via ModularApp
        DEFAULT_THEME = nansen.theme.getThemeColors('dark-gray');
    end
    
    properties (Constant ) % Inherited from applify.ModularApp
        AppName = 'Roi Info Table'
    end

    properties
        roiTable        % Keeps a data table with info for all rois
        selectedRois    % List of rois(rows) that are selected in the table
    end
    
    properties (Dependent)
        SelectionMode % can we select multiple: (['single'],'contiguous','discontiguous')
    end
    
    properties (Dependent)
        KeyPressFcn
    end
    
    properties (Access = protected)
        UITable         % Handle to the ui table
    end
    
    
    methods % Structors
        
        function obj = RoiTable(varargin)
        %RoiTable Create an instance of a RoiTable modular app
        
            [h, varargin] = applify.ModularApp.splitArgs(varargin{:});
            obj@applify.ModularApp(h);
            
            roiGroup = varargin{1}; % todo: check arg
            obj@roimanager.roiDisplay(roiGroup)
            
            obj.Panel.Units = 'normalized';
            obj.Figure.Position = obj.initializeFigurePosition();
            
            roiTable = obj.rois2table(roiGroup.roiArray);
            obj.roiTable = roiTable;
            
            nansen.assert('WidgetsToolboxInstalled')
            obj.UITable = nansen.ui.MetaTableViewer(obj.Panel, roiTable);
            
            % Set table properties
            obj.UITable.HTable.hideHorizontalScroller()
            obj.UITable.HTable.hideVerticalScroller()
            obj.UITable.HTable.RowHeight = 18;
            obj.UITable.HTable.CellSelectionCallback = @obj.onTableSelectionChanged;
            obj.UITable.HTable.KeyPressFcn = @obj.onKeyPressed;
            
            if roiGroup.roiCount > 0
                obj.updateRoiLabels()
            end
            
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
            
            delete(obj.UITable)
        end

    end

    
    methods
        
        function addRois(~)
            % This class can not add rois
        end
        
        function removeRois(obj)
            % Todo
        end
        
        function updateRoiLabels(obj)               
            roiLabels = obj.roiGroup.getRoiLabels(1:obj.roiGroup.roiCount);
            obj.roiTable(:, 1) = roiLabels';
            obj.UITable.refreshTable(obj.roiTable)
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
            obj.UITable.HTable.KeyPressFcn = newValue;
        end
        function keyPressFcn = get.KeyPressFcn(obj)
            keyPressFcn = obj.UITable.HTable.KeyPressFcn;
        end
    end
    
    methods (Access = private) 
        
        function onTableSelectionChanged(obj, src, evt)
            
            IND = obj.UITable.getSelectedEntries();

            newlySelectedRois = setdiff(IND, obj.selectedRois);
            unselectedRois = setdiff(obj.selectedRois, IND);
            obj.selectedRois = IND;
            
            if iscolumn(newlySelectedRois); newlySelectedRois = newlySelectedRois'; end
            if iscolumn(unselectedRois); unselectedRois = unselectedRois'; end

            if ~isempty(unselectedRois) && ~isempty(newlySelectedRois)
                selectionInfo = struct;
                selectionInfo.Selected = newlySelectedRois;
                selectionInfo.Deselected = unselectedRois;
                obj.roiGroup.changeRoiSelection(selectionInfo, 'both', [], obj)
                
            elseif ~isempty(unselectedRois)
                obj.roiGroup.changeRoiSelection(unselectedRois, 'unselect', [], obj)
                
            elseif ~isempty(newlySelectedRois)
                obj.roiGroup.changeRoiSelection(newlySelectedRois, 'select', [], obj)

            else
                % pass
            end
            
        end
        
        function roiTable = rois2table(obj, roiArray)
                
            S = roimanager.utilities.roiarray2struct(roiArray);
            
            S = rmfield(S, {'coordinates', 'imagesize', 'boundary', ...
                'connectedrois', 'layer', 'tags', 'enhancedImage'});
            
            % add column with label and number for roi
            [S(:).ID] = deal({''});
            S = orderfields(S, ['ID', setdiff(fieldnames(S), 'ID', 'stable')' ]);
            roiTable = struct2table(S, 'AsArray', true);
            
            
        end
        
        function roiTable = rois2table_old(obj, roiArray)
                
            S = roimanager.utilities.roiarray2struct(roiArray);
            
            S = rmfield(S, {'coordinates', 'imagesize', 'boundary', ...
                'connectedrois', 'layer', 'tags', 'enhancedImage'});
            
            % add column with label and number for roi
            roiTable = struct2table(S, 'AsArray', true);
            
            % Create column for adding ids and prepend to table.
            numRois = numel(roiArray);

            C = cell(repmat({''}, numRois, 1)); % Init to empty strings
            T = cell2table(C, 'VariableNames',{'ID'});
        
            roiTable = [T, roiTable];
            
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

            % Take action for this EventType
            switch lower(evtData.eventType)
                
                case {'initialize', 'append'}
                    T = obj.rois2table(evtData.roiArray);
                    newTable = cat(1, oldTable, T);
                    
                case 'insert'
                    T = obj.rois2table(evtData.roiArray);
                    ind = evtData.roiIndices;
                    newTable = utility.insertRowInTable(oldTable, T, ind);
                    
                case {'modify', 'reshape'}
                    T = obj.rois2table(evtData.roiArray);
                    newTable = oldTable;
                    newTable(evtData.roiIndices, :) = T;
                    
                case 'remove'
                    newTable = obj.roiTable;
                    newTable(evtData.roiIndices,:) = [];  
            end
            
            % Update the values of the roi ids / roi labels
            if obj.roiGroup.roiCount ~= 0 
               
                numRois = obj.roiGroup.roiCount;

                if ~contains(lower(evtData.eventType), {'modify', 'reshape'})
                    roiInd = evtData.roiIndices;
                else
                    roiInd = 1:numRois;
                end
                
                roiLabels = obj.roiGroup.getRoiLabels(roiInd);
                newTable{roiInd,1} = roiLabels';
                
            end
                        
            obj.roiTable = newTable;
            obj.UITable.refreshTable(newTable)
            % Todo: If this happens, the table focus is lost?...
            % Todo: Update cells instead of whole table....
        end
        
        function onRoiSelectionChanged(obj, evtData)
            
            % Use getSelectedEntries and setSelectedEntries because it
            % takes sorting order into consideration.
            
            currentRowSelection = obj.UITable.getSelectedEntries();

            switch evtData.eventType
                case 'unselect'
                    if ischar(evtData.roiIndices) && strcmp(evtData.roiIndices, 'all')
                        evtData.roiIndices = obj.selectedRois;
                        if isempty(obj.selectedRois); return; end
                    end
                    
                    %obj.selectedRois = setdiff(obj.selectedRois, roiIndices);
                    newRowSelection = setdiff(currentRowSelection, evtData.roiIndices);
                case 'select'
                    newRowSelection = union(currentRowSelection, evtData.roiIndices);
                
                case 'both'
                    newRowSelection = union(currentRowSelection, evtData.roiIndices.Selected);
                    newRowSelection = setdiff(newRowSelection, evtData.roiIndices.Deselected);
            end
            
            if iscolumn(newRowSelection); newRowSelection = newRowSelection'; end
            
            
            if isequal(obj, evtData.origin)
                % This is super ad hoc. When selecting quickly from the
                % table, events (or listeners) are not triggered as I expect. 
                % This is an attempt to work around this.
                if ~isequal(obj.selectedRois, newRowSelection)
                    unselectedRois = setdiff(newRowSelection, obj.selectedRois);
                    selectionInfo = struct;
                    selectionInfo.Selected = obj.selectedRois;
                    selectionInfo.Deselected = unselectedRois;
                    obj.roiGroup.changeRoiSelection(selectionInfo, 'both', [], obj)
                    return
                end
            end
            
            
            currentRowSelection = obj.UITable.getSelectedEntries();
            % Only set new selection if its different than current 
            % selection to prevent an infinite loop. Feel like this will
            % come back and bite me hard...
            if isequal( sort(currentRowSelection), sort(newRowSelection) )
                return
            else
                obj.UITable.setSelectedEntries(newRowSelection);
                obj.selectedRois = newRowSelection;
            end
            
        end
        
        function onRoiClassificationChanged(obj, evtData)
            
        end
    end
    
    methods (Access = {?applify.ModularApp, ?applify.DashBoard} )
        
        function onKeyPressed(obj, src, evt)
            % Todo implement...
            % disp(evt.Key)  
  
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