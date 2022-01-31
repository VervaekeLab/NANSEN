classdef DataLocationModelApp < nansen.config.abstract.ConfigurationApp
%DataLocationModelApp Create an app for the data location model
%

% Todo:
%   [ ] Program this using traditional gui figure for backwards
%       compatibility and more responsive figure.
%   [ ] Make superclass 
%   [ ] Save changes from GUI to data location model
%   [ ] Method/button for selecting default datalocation
%   [ ] Set read/write or read only for datalocation  
%   [ ] Add control for adding multiple rootpaths for datalocations


%   [ ] Need to reload datalocationmodel if project is changed
%   [ ] Set method for DataLOcationModel and medthod to make sure all UIs
%       are updated accordingly
    
    
    properties (Constant)
        AppName = 'Configure Data Locations'
    end
    
    properties (Constant)
        ModuleNames = {'DataLocations', 'FolderOrganization', 'MetadataInit'}
        PageTitles = { 'Manage Data Locations', ...
                       'Folder Organization', ...
                       'Metadata Initialization' };
    end
    
    properties
        DataLocationModel
    end
    
    properties (Access = private)
        DataBackup
    end
    
    properties (Access = private)
       TabGroup matlab.ui.container.TabGroup
       TabList matlab.ui.container.Tab
       
       %ControlPanels matlab.ui.container.Panel
    end
    
    properties (Access = private)
        IsPageCreated = false(1,3)
    end
    
    
    methods
        
        function obj = DataLocationModelApp(varargin)
            
            
            % Todo: Should be possible to give as input...
            obj.DataLocationModel = nansen.config.dloc.DataLocationModel;
            obj.DataBackup = obj.DataLocationModel.Data;
            
            
            if isempty(varargin)
                
                obj.createFigure()

                % Create tabgroup
                obj.createTabGroup();
                obj.createLoadingPanel();

                setLayout(obj)
                obj.Figure.Visible = 'on';
                
                uim.utility.centerFigureOnScreen(obj.Figure)
            
                obj.createControlPanels()
                obj.applyTheme()
                
                obj.UIModule{3} = [];
                obj.createUIModules(1)
                
            else
                
                
                
            end
            
            
            if ~nargout; clear obj; end
            
            %obj@applify.ModularApp
            % Create tabs
            %obj.isConstructed = true;
        end
        
    end

    methods (Access = protected)
        
        function onFigureClosed(obj, src, evt)
            
            % Check if any modules have made changes to the model
            isDirty = false(1,3);
            for i = 1:numel(obj.UIModule)
                if ~isempty(obj.UIModule{i})
                    isDirty(i) = obj.UIModule{i}.IsDirty;
                end
            end
            
            % Ask user if changes should be saved
            if any(isDirty)
                
                message = 'Save changes to Data Locations?';
                title = 'Confirm Save';

                selection = uiconfirm(src, message, title, 'Options', ...
                    {'Yes', 'No', 'Cancel'}, 'DefaultOption', 1, ...
                    'CancelOption', 3);
                
                switch selection
                    
                    case 'Yes'
                        for i = 2:3
                            if ~isempty(obj.UIModule{i})
                                obj.UIModule{i}.updateDataLocationModel()
                            end
                        end
                        obj.DataLocationModel.save()
                        
                    case 'No'
                        obj.DataLocationModel.restore(obj.DataBackup)
                    otherwise
                        return
                end

            end
            
            delete(obj.Figure)

% %             for i = 1:3
% %                 if ~isempty(obj.UIModule{i})
% %                     delete(obj.UIModule{i})
% %                 end
% %             end
            
        end
        
    end
    
    methods (Access = private)
        
        function createTabGroup(obj)
            
            hTabGroup = uitabgroup(obj.Figure);
            hTabGroup.Position = [0, 0, obj.Figure.Position(3:4)];

            
            numTabs = numel(obj.PageTitles);
            hTabs = gobjects(numTabs, 1);
            
            for i = 1:numTabs
                hTabs(i) = uitab(hTabGroup, 'Title', obj.PageTitles{i});
            end
            
            obj.TabGroup = hTabGroup;
            obj.TabList = hTabs;
            
            obj.TabGroup.SelectionChangedFcn = @obj.onTabSelectionChanged;

        end
 
        function createControlPanels(obj)
            
            for i = 1:numel(obj.TabList)
                hPanel = obj.createControlPanel( obj.TabList(i) );
                obj.ControlPanels(i) = hPanel;
            end
            
        end
        
        function setLayout(obj)
            % Make sure inner position is : [699,229]
            
            % Todo: Make this part of abstract method... Adjust size if a
            % tabgroup is added....
            
            targetPosition = [699, 229] + [0, 40] + [40, 40];
            
            pos = obj.TabList(1).Position;
            
            deltaSize = targetPosition - pos(3:4);
            
            % Resize components
            obj.Figure.Position(3:4) = obj.Figure.Position(3:4) + deltaSize;
            obj.TabGroup.Position(3:4) = obj.TabGroup.Position(3:4) + deltaSize;
            
            obj.LoadingPanel.Position = [1,1,obj.TabGroup(1).Position(3:4)];
            uim.utility.layout.centerObjectInRectangle(obj.LoadingImage, obj.LoadingPanel)

        end
            
        function createUIModules(obj, moduleNumber)

            if nargin < 2
                moduleNumber = 1:numel(obj.ModuleNames);
            end
            
            obj.LoadingPanel.Visible = 'on';
            
            for i = moduleNumber
            
                obj.LoadingPanel.Parent = obj.TabList(i);
                
                switch i

                    case {1, 'DataLocations'}
                        obj.createDataLocationUI()
                        
                    case {2, 'FolderHierarchy'}
                        obj.createFolderOrganizationUI()
                        
                    case {3, 'MetadataInit'}
                        obj.createMetadataInitializationUI()
                        
                end
                
                obj.IsPageCreated(i) = true;
                
            end

            
            obj.LoadingPanel.Visible = 'off';
        end
        
        function createDataLocationUI(obj)
            
            i = 1;
            h = obj.DataLocationModel;

            % Create components for the DataLocationModel configuration
            args = {'Parent', obj.ControlPanels(i)};
            
            if obj.IsStandalone 
                args = [args, 'RootPathComponentType', 'uidropdown'];
            end
            
            obj.UIModule{i} = nansen.config.dloc.DataLocationModelUI(h, args{:});
            
            % Todo: This should happen on construciton of UiModule
            obj.UIModule{i}.createAddNewDataLocationButton(obj.TabList(i))
            obj.UIModule{i}.createDefaultDataLocationSelector(obj.TabList(i))
        end
        
        function createFolderOrganizationUI(obj)
           
            i = 2;
            h = obj.DataLocationModel;

            % Create components for the Folder Organization configuration
            args = { 'Parent', obj.ControlPanels(i) };
            obj.UIModule{i} = nansen.config.dloc.FolderOrganizationUI(h, args{:});
            obj.UIModule{i}.hideAdvancedOptions()
            obj.UIModule{i}.createToolbar(obj.TabList(i))
            obj.UIModule{i}.updateDataLocationSelector()
        end
        
        function createMetadataInitializationUI(obj)
            
            i = 3;
            h = obj.DataLocationModel;
            
            % Create components for the Metadata Initialization configuration
            args = {'Parent', obj.ControlPanels(i)};
            obj.UIModule{i} = nansen.config.dloc.MetadataInitializationUI(h, args{:});
            obj.UIModule{i}.hideAdvancedOptions()
                       
            obj.UIModule{i}.createAdvancedOptionsButton(obj.TabList(i))
            
        end
        
    end
    
    methods (Access = private) % Callbacks

        function onTabSelectionChanged(obj, src, evt)
        %onTabSelectionChanged Take care of tab change
        
            currentTitle = obj.TabGroup.SelectedTab.Title;
            pageNum = find(strcmp(obj.PageTitles, currentTitle));

            if ~obj.IsPageCreated(pageNum)
                obj.createUIModules(pageNum)
            end
            
            % Clean up old tab
            switch evt.OldValue.Title
                case 'Folder Organization'
                    if isvalid(obj.UIModule{2}) && obj.UIModule{2}.IsDirty
                        obj.UIModule{2}.updateDataLocationModel()
                    end
            end
            
            % Prepare new tab
            switch obj.TabGroup.SelectedTab.Title
                
                case 'Folder Organization'
                    
                case 'Metadata Initialization'
                
            end
            
        end
        
    end
    
    
    methods (Access = protected)
       
        function applyTheme(obj)
        % Apply theme % Todo: Superclass 
        
            S = nansen.theme.getThemeColors('deepblue');
            
            %hTabs = obj.TabGroup.Children;
            %set(hTabs, 'BackgroundColor', S.FigureBgColor)
            
            set(obj.ControlPanels, 'BackgroundColor', S.ControlPanelsBgColor)
        
        end
       
    end
    
    

end