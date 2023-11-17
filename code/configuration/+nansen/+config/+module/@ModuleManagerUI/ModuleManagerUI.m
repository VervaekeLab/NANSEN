classdef ModuleManagerUI < handle
%ModuleManagerUI Provides UI functionality for the ModuleManager class

    % Todo: 
    %  [ ] Create a class wrapping around a table for selecting rows.

    properties 
        ModuleManager  % Instance of ModuleManager class
    end

    properties (Access = protected) % UI Components
        hParent
        UIPanels struct = struct
        UIControls struct = struct
        UILabels struct = struct
    end
    
    properties (Access = protected)
        SelectedRows = []
        SelectedRowBgColor = [74,86,99]/255
        SelectedRowFgColor = [234,236,237]/255
    end

    properties (Hidden)
        ToolbarButtonFontColor = [0.15,0.15,0.15]
        ToolbarButtonBackgroundColor = [0.94,0.94,0.94]
    end
    
    properties (Access = private) % Component appeareance
        ToolbarButtons matlab.ui.control.Button
        GridLayout matlab.ui.container.GridLayout
        HeaderGridLayout matlab.ui.container.GridLayout
    end

    events
        ModuleSelectionChanged
        ModuleAdded
    end

    methods % Constructor
        
        function obj = ModuleManagerUI(hParent, hModuleManager, varargin)

            % Todo: parent might not be given as first input, it might be
            % in the list of name value pairs...
            if nargin < 1 || isempty(hParent)
                return
            else
                obj.hParent = hParent;
            end

            if nargin < 2
                hModuleManager = nansen.config.module.ModuleManager();
            end
            
            % Assign object to ModuleManager property.
            assert(isa(hModuleManager, 'nansen.config.module.ModuleManager'))
            obj.ModuleManager = hModuleManager;

            % Comment this out, but keep in case it will be needed later.
            % The layout was used to also create a dropdown for selecting
            % between a general (required) module. (This will most likely 
            % not be needed)
            %%obj.createLayout()
            obj.createUiControls()
            obj.configureUiTable()
            obj.configureUiDropdown()
        end
        
    end

    methods % Public methods
        function addExternalModule(obj)
            % pass. todo
        end

        function selectedModules = getSelectedModules(obj)
        %getSelectedModules Return a list (struct array) of selected modules
        %
        %   selectedModules = obj.getSelectedModules() returns a list of
        %   the currently selected modules from the table. selectedModules
        %   is a struct array with information about each module.
        
            % Only optional modules are selectable from table
            optionalModules = obj.ModuleManager.listModules('optional');
            selectedData = optionalModules(obj.SelectedRows, :);
            selectedModules = table2struct(selectedData);
        end

        function setSelectedModules(obj, selectedModules)
        %setSelectedModules Set (check) selectedModules in table
        %
        %   setSelectedModules(obj, selectedModules) sets the given modules
        %   as the current selection in the ui. selectedModules should be a 
        %   cell array of module package names
            
            obj.resetSelectedRows()
            if isempty(selectedModules); return; end

            optionalModules = obj.ModuleManager.listModules('optional');
            modulePackages = optionalModules{:, 'PackageName'};
            if iscolumn(modulePackages); modulePackages = modulePackages'; end
            indices = find( ismember(modulePackages, selectedModules) );
            obj.UIControls.ModuleTable.Data{indices, 1} = true;

            obj.onRowSelected(indices)
            obj.setRowStyle('Selected Row', indices)
        end
    end

    methods (Access = protected) % Component creation
        
        function createLayout(obj)

            % Create GridLayout
            obj.GridLayout = uigridlayout(obj.hParent);
            obj.GridLayout.ColumnWidth = {'1x'};
            obj.GridLayout.RowHeight = {70, '1x'};
            obj.GridLayout.RowSpacing = 20;
            obj.GridLayout.Padding = [20, 20, 20, 20];

            % Create panels
            obj.UIPanels.Header = uipanel(obj.GridLayout);
            obj.UIPanels.Header.Layout.Row = 1;
            obj.UIPanels.Header.Layout.Column = 1;

            obj.UIPanels.Main = uipanel(obj.GridLayout);
            obj.UIPanels.Main.Layout.Row = 2;
            obj.UIPanels.Main.Layout.Column = 1;

            obj.UIPanels.Header.Title = "Select core module";
            obj.UIPanels.Main.Title = "Select optional modules"; 

            % Create header layout
            obj.HeaderGridLayout = uigridlayout(obj.UIPanels.Header);
            obj.HeaderGridLayout.ColumnWidth = {'1x'};
            obj.HeaderGridLayout.RowHeight = {'1x'};
            obj.HeaderGridLayout.Padding = [10,10,10,10];

            %obj.UIPanels.Header.BorderType = "None";
            %obj.UIPanels.Main.BorderType = "None";
        end

        function createUiControls(obj)
            obj.UIControls.ModuleTable = uitable(obj.hParent);
            % % % obj.UIControls.ModuleTable = uitable(obj.UIPanels.Main);    
            obj.UIControls.ModuleTable.Position = [0,0,obj.hParent.Position(3:4)];    

            % % % obj.UIControls.CoreModuleDropdown = uidropdown(obj.HeaderGridLayout);
            % % % obj.UIControls.CoreModuleDropdown.Position = [10, 10, 100, 22];
            % % % obj.UIControls.CoreModuleDropdown.Layout.Row = 1;
            % % % obj.UIControls.CoreModuleDropdown.Layout.Column = 1;
        end
        
        function configureUiTable(obj)
            
            obj.updateTableData()
            
            obj.UIControls.ModuleTable.ColumnWidth = {75, 200, 'auto'};
            obj.UIControls.ModuleTable.ColumnEditable = [true, false, false];
            
            obj.UIControls.ModuleTable.CellEditCallback = @obj.onTableCellEdited;

            obj.setTablePosition()
        end

        function configureUiDropdown(obj)
            obj.updateDropdown()
        end
        
        function updateTableData(obj)
        %updateTableData Update data in the uitable
        %
        % Updates uitable data based on available modules from the
        % ModuleManager
        
            if isempty(obj.ModuleManager); return; end
            if ~isfield(obj.UIControls, 'ModuleTable'); return; end
            
            T = obj.ModuleManager.listModules();
            T = T(~T.isCoreModule, :);
            
            T = T(:, 1:2);
            T.Properties.VariableNames{1} = 'Module Name';
            T.Properties.VariableNames{2} = 'Description';

            isSelected = false(size(T, 1), 1);
            tableColumn = table(isSelected, 'VariableNames', {'Selection'});
            
            T = [tableColumn, T];
            
            try
                obj.UIControls.ModuleTable.Data = T;
                
            catch
                obj.UIControls.ModuleTable.Data = table2cell(T);
                obj.UIControls.ModuleTable.ColumnName = T.Properties.VariableNames;
            end
            
            try % Only available in newer matlab versions...
%                 if any(isCurrent)
%                     obj.setRowStyle('Selection', find(isCurrent))
% 
%                     s = uistyle('FontWeight', 'bold');
%                     addStyle(obj.UIControls.ModuleTable, s, 'row', find(isCurrent));
%                 end
                if isempty(obj.UIControls.ModuleTable.UIContextMenu)
                    %obj.createTableContextMenu()
                end
            catch
                warning('Some features of the table are not created properly. Matlab 2018b or newer is required.')
            end
            
            if isempty(obj.UIControls.ModuleTable.CellSelectionCallback)
                %obj.UIControls.ModuleTable.CellSelectionCallback = @obj.onTableCellSelected;
            end
        end
        
        function updateDropdown(obj)
            
            T = obj.ModuleManager.listModules();
            T = T(T.isCoreModule, :);
            
            numRows = size(T, 1);
            options = arrayfun( @(row) sprintf('%s (%s)', T{row, 'Name'}, T{row, 'Description'}), 1:numRows, 'uni', 0); 
            
            obj.UIControls.CoreModuleDropdown.Items = options;
            obj.UIControls.CoreModuleDropdown.Value = options{1};
        end

        function setTablePosition(obj)
        %setTablePosition Position the table within the UI
        
            margin = 10;
            drawnow
            pause(0.05)

            parentPosition = obj.hParent.InnerPosition;
            %parentPosition = obj.UIPanels.Main.InnerPosition;
            %tablePosition = [0,0,parentPosition(3:4)] + [1, 1, -2, -2] * margin;
            tablePosition = [10,10,parentPosition(3:4)-20];
            obj.UIControls.ModuleTable.Position = tablePosition;
        end
        
        function createTableContextMenu(obj)
            % Not implemented
            cMenu = uicontextmenu(ancestor(obj.hParent, 'figure'));
            
            contextMenuItemNames = {...
                'N/A' };
            
            hMenuItem = gobjects(numel(contextMenuItemNames), 1);
            for i = 1:numel(contextMenuItemNames)
                hMenuItem(i) = uimenu(cMenu, 'Text', contextMenuItemNames{i});
                hMenuItem(i).Callback = @obj.onContextMenuItemClicked;
            end
            
            obj.UIControls.ModuleTable.UIContextMenu = cMenu;
        end

    end
    
    methods % Set/get
        
        function set.ToolbarButtonFontColor(obj, newValue)
            try
                obj.onToolbarButtonFontColorSet(newValue)
                obj.ToolbarButtonFontColor = newValue;
            catch ME
                throw(ME)
            end
        end

        function set.ToolbarButtonBackgroundColor(obj, newValue)
            try
                obj.onToolbarButtonBackgroundColorSet(newValue)
                obj.ToolbarButtonBackgroundColor = newValue;
            catch ME
                throw(ME)
            end
        end
    end
    
    methods (Access = private) % Uicontrol callbacks

        function onTableCellEdited(obj, src, evt)
            
            rowIdx = evt.Indices(1); colIdx = evt.Indices(2);

            if colIdx == 1
                if evt.NewData
                    obj.onRowSelected(rowIdx)
                    obj.setRowStyle('Selected Row', rowIdx)
                else
                    obj.onRowUnselected(rowIdx)
                    obj.setRowStyle('Unselected Row', rowIdx)
                end
            else
                error('Could not update data in column %d', colIdx)
            end
        end
        
    end
    
    methods (Access = private) % Actions
        function onRowSelected(obj, rowNumber)
            obj.SelectedRows = unique([obj.SelectedRows, rowNumber]);
            obj.triggerModuleSelectionChangedEvent()
        end

        function onRowUnselected(obj, rowNumber)
            obj.SelectedRows = setdiff(obj.SelectedRows, rowNumber);
            obj.triggerModuleSelectionChangedEvent()
        end

        function triggerModuleSelectionChangedEvent(obj)
            % Only optional modules are selectable from table
            optionalModules = obj.ModuleManager.listModules('optional');
            selectedData = optionalModules(obj.SelectedRows, :);
            selectedData = table2struct(selectedData);
            evtData = nansen.config.module.SelectionChangedEventData(selectedData);
            obj.notify('ModuleSelectionChanged', evtData)
        end
    
        function resetSelectedRows(obj)
            selectedRows = find(obj.UIControls.ModuleTable.Data{:,1});
            obj.UIControls.ModuleTable.Data{:, 1} = false;
            for i = 1:numel(selectedRows)
                obj.setRowStyle('Unselected Row', selectedRows(i))
            end
        end
    end

    methods (Access = private) % Style components (Todo, move to superclass)
        
        function onToolbarButtonBackgroundColorSet(obj, newValue)
            set(obj.ToolbarButtons, 'BackgroundColor', newValue)
        end

        function onToolbarButtonFontColorSet(obj, newValue)
            set(obj.ToolbarButtons, 'FontColor', newValue)
        end
    end

    methods (Access = private) % Table styling
        function setRowStyle(obj, styleType, rowIdx)
        %setRowStyle Set style on row according to type
        %
        %
        %   Only one style of each type are allowed at any time, so if the
        %   style already exists it is removed before it is added again.
        
            % Remove this style type if it exists on another row
            sConfig = obj.UIControls.ModuleTable.StyleConfigurations;
            
            switch styleType
                case 'Selected Row'
                    for i = 1:numel(rowIdx)
                        s = uistyle('BackgroundColor', obj.SelectedRowBgColor,...
                            'FontColor', obj.SelectedRowFgColor);
                        addStyle(obj.UIControls.ModuleTable, s, 'row', rowIdx(i));
                    end

                case 'Unselected Row'
                    isStyleForRow = [sConfig.TargetIndex{:}] == rowIdx;
                    removeStyle(obj.UIControls.ModuleTable, find(isStyleForRow))
            end
        end
    end
end