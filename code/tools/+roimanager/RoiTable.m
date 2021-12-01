classdef RoiTable < applify.ModularApp & roimanager.roiDisplay

    % TODO:
    %  [x] make setSelectedEntries for uitable, so that selection works
    %      also when rows are sorted
    %  [ ] Fix bug when selecting from sorted tables...
    
    properties (Constant) % Inherited from applify.HasTheme via ModularApp
        DEFAULT_THEME = nansen.theme.getThemeColors('dark-gray');
    end
    
    properties (Constant ) % Inherited from applify.ModularApp
        AppName = 'Signal Viewer'
    end

    
    properties
        roiTable
        selectedRois
    end
    
    properties (Access = protected)
        UITable
    end
    
    
    methods
        
        function obj = RoiTable(varargin)
            
            [h, varargin] = applify.ModularApp.splitArgs(varargin{:});
            obj@applify.ModularApp(h);
            
            roiGroup = varargin{1}; % todo: check arg
            obj@roimanager.roiDisplay(roiGroup)
            
            roiTable = obj.rois2table(roiGroup.roiArray);
            
            
            obj.UITable = nansen.ui.MetaTableViewer(obj.Panel, roiTable);
            
            obj.UITable.HTable.hideHorizontalScroller()
            obj.UITable.HTable.hideVerticalScroller()
            obj.UITable.HTable.RowHeight = 18;
            obj.UITable.HTable.CellSelectionCallback = @obj.onTableSelectionChanged;
            
            obj.isConstructed = true;
        end
        
        function delete(obj)
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
    end
    
    
    methods (Access = private) 
        
        
        function onTableSelectionChanged(obj, src, evt)
            
            IND = obj.UITable.getSelectedEntries();
            
            newlySelectedRois = setdiff(IND, obj.selectedRois);
            unselectedRois = setdiff(obj.selectedRois, IND);
                        
            if iscolumn(newlySelectedRois); newlySelectedRois = newlySelectedRois'; end
            if iscolumn(unselectedRois); unselectedRois = unselectedRois'; end
            
            if ~isempty(unselectedRois)
                obj.roiGroup.changeRoiSelection(unselectedRois, 'unselect')
            end
            
            if ~isempty(newlySelectedRois)
                obj.roiGroup.changeRoiSelection(newlySelectedRois, 'select')
            end

        end
        
        function roiTable = rois2table(obj, roiArray)
                
            S = roimanager.utilities.roiarray2struct(roiArray);
            
            S = rmfield(S, {'coordinates', 'imagesize', 'boundary', ...
                'connectedrois', 'layer', 'tags', 'enhancedImage'});
            
            % add column with label and number for roi
            
            roiTable = struct2table(S, 'AsArray', true);
            
            % Add column in beginning for showing ids.
            numRois = numel(roiArray);
            T = table('Size',[numRois 1], 'VariableNames',{'ID'}, 'VariableTypes', {'string'});
        
            roiTable = [T, roiTable];
            
        end
        
    end
    
    
    methods (Access = protected) % Inherited from applify.ModularApp

        % use for when restoring figure size from maximized
        function pos = initializeFigurePosition(app)
            pos = [100,100,400,600];
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
                
                case {'initialize', 'append', 'insert'}
                    
                    T = obj.rois2table(evtData.roiArray);
                    newTable = cat(1, oldTable, T);

                case {'modify', 'reshape'}
                    newTable = oldTable; %todo
                    
                case 'remove'
                    newTable = obj.roiTable;
                    newTable(evtData.roiIndices,:) = [];  
            end
            
            tags = {obj.roiGroup.roiArray.tag};
            nums = arrayfun(@(i) num2str(i, '%03d'), 1:obj.roiGroup.roiCount, 'uni', 0);
            roiLabels = strcat(tags, nums);
            
            newTable{:,1} = roiLabels';
            
            
            %[table(roiLabels', 'VariableNames', {'ID'}), newTable];
            
            obj.roiTable = newTable;
            obj.UITable.refreshTable(newTable)

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
            end
            
            if iscolumn(newRowSelection); newRowSelection = newRowSelection'; end
            
                        
            % Update selected rois property
            obj.selectedRois = newRowSelection;

            % Only set new selection if its different than current 
            % selection to prevent an infinite loop. Feel like this will
            % come back and bite me hard...
            if isequal( sort(currentRowSelection), sort(newRowSelection) )
                return
            else
                obj.UITable.setSelectedEntries(newRowSelection);
            end
            
        end
        
        function onRoiClassificationChanged(obj, evtData)
            
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