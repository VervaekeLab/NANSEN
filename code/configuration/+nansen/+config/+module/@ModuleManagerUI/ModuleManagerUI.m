classdef ModuleManagerUI < handle
    
    properties 
        ModuleManager  % Instance of AddonManager class
    end

    properties (Access = protected) % UI Components
        hParent
        
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

            obj.createUiControls()
            obj.createProjectTable()
        end
        
    end

    methods 
        function selectedModules = getSelectedModules(obj)
            selectedModules = obj.ModuleManager.ModuleList(obj.SelectedRows);
        end
    end

    methods (Access = protected) % Component creation
        
        function createUiControls(obj)
            obj.UIControls.ModuleTable = uitable(obj.hParent);
            %obj.UIControls.ModuleTable.Position = [10,10,530,200];
        end
        
        function createProjectTable(obj)
            
            obj.updateTableData()
            
            obj.UIControls.ModuleTable.ColumnWidth = {75, 200, 'auto'};
            obj.UIControls.ModuleTable.ColumnEditable = [true, false, false];
            
            obj.UIControls.ModuleTable.CellEditCallback = @obj.onTableCellEdited;

            obj.setTablePosition()
        end
        
        function updateTableData(obj)
        %updateProjectTableData Update data in the uitable
        
            if isempty(obj.ModuleManager); return; end
            if ~isfield(obj.UIControls, 'ModuleTable'); return; end
            
            %T = struct2table(obj.ModuleManager.Catalog, 'AsArray', true);
            T = obj.ModuleManager.listModules();
            T = T(:, 1:2);
            T.Properties.VariableNames{1} = 'Module Name';
            T.Properties.VariableNames{2} = 'Description';


            isSelected = false(size(T, 1), 1);

            %isCurrent = strcmp(T.Name, currentProjectName);
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
%                     obj.setRowStyle('Current Project', find(isCurrent))
% 
%                     s = uistyle('FontWeight', 'bold');
%                     addStyle(obj.UIControls.ProjectTable, s, 'row', find(isCurrent));
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
        
        function setTablePosition(obj)
        %setProjectTablePosition Position the table within the UI
        
            margin = 10;
            drawnow
            pause(0.05)

            parentPosition = obj.hParent.InnerPosition;
            %tablePosition = [0,0,parentPosition(3:4)] + [1, 1, -2, -2] * margin;
            tablePosition = [0,0,parentPosition(3:4)+[2,2]];
            obj.UIControls.ModuleTable.Position = tablePosition;
        end
        
        function createTableContextMenu(obj)
            
            cMenu = uicontextmenu(ancestor(obj.hParent, 'figure'));
            
            contextMenuItemNames = {...
                'Set current project', ...
                'Remove project', ...
                'Delete project', ...
                'Update project folder location', ...
                'Open project folder' };
            
            hMenuItem = gobjects(numel(contextMenuItemNames), 1);
            for i = 1:numel(contextMenuItemNames)
                hMenuItem(i) = uimenu(cMenu, 'Text', contextMenuItemNames{i});
                hMenuItem(i).Callback = @obj.onContextMenuItemClicked;
            end
            
            obj.UIControls.ProjectTable.UIContextMenu = cMenu;
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

    methods % Public methods
        function addExternalModule(obj)
            % pass. todo
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
        end

        function onRowUnselected(obj, rowNumber)
            obj.SelectedRows = setdiff(obj.SelectedRows, rowNumber);
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
                    s = uistyle('BackgroundColor', obj.SelectedRowBgColor,...
                        'FontColor', obj.SelectedRowFgColor);
                    addStyle(obj.UIControls.ModuleTable, s, 'row', rowIdx);

                case 'Unselected Row'
                    isStyleForRow = [sConfig.TargetIndex{:}] == rowIdx;
                    removeStyle(obj.UIControls.ModuleTable, find(isStyleForRow))
            end
        end
    end
end