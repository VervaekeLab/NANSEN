classdef DataLocationModelApp < handle % applify.ModularApp & 
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
    
    
    properties (Constant, Hidden)
        DEFAULT_THEME = nansen.theme.getThemeColors('light'); 
    end
    
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
        UIModule
    end
    
    
    properties (Access = private)
       Figure
       TabGroup matlab.ui.container.TabGroup
       TabList matlab.ui.container.Tab
       
       ControlPanels matlab.ui.container.Panel
       LoadingPanel matlab.ui.container.Panel
       LoadingImage
    end
    
    properties (Access = private)
        IsPageCreated = false(1,3)
    end
    
    
    methods
        
        function obj = DataLocationModelApp(varargin)
            
            if isempty(varargin)
                
                obj.createFigure()

                % Create tabgroup
                obj.createTabGroup();
                obj.createLoadingPanel();

                setLayout(obj)
                obj.Figure.Visible = 'on';
            else
                
            end
            
            uim.utility.centerFigureOnScreen(obj.Figure)
            
            obj.createControlPanels()
            obj.applyTheme()
            
            % Todo: Should be possible to give as input...
            obj.DataLocationModel = nansen.config.dloc.DataLocationModel;
            
            
            obj.createUIModules(1)
            
            obj.LoadingPanel.Visible = 'off';
            
            if ~nargout; clear obj; end
            
            %obj@applify.ModularApp
            % Create tabs
            %obj.isConstructed = true;
        end

    end

    methods (Access = private)
        
        function createFigure(obj)
            
            % Create figure
            obj.Figure = uifigure('Visible', 'off');
            obj.Figure.Position(3:4) = [699, 229]; 
            obj.Figure.Resize = 'off';
            uim.utility.centerFigureOnScreen(obj.Figure)
            
            % Set figure name.
            obj.Figure.Name = obj.AppName;

        end
        
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
            obj.UIModule{i} = nansen.config.dloc.DataLocationModelUI(h, args{:});
            
            % Todo: This should happen on construciton of UiModule
            obj.UIModule{i}.createAddNewDataLocationButton(obj.TabList(i))
            
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
        
        function createLoadingPanel(obj)
            
            obj.LoadingPanel = uipanel(obj.Figure);
            
            
            % Create LoadingImage
            uiImage = uiimage(obj.LoadingPanel);
            uiImage.Position = [326 146 140 142];
            uiImage.ImageSource = 'loading.gif';
            
            uim.utility.layout.centerObjectInRectangle(uiImage, obj.LoadingPanel)
            
            obj.LoadingImage = uiImage;
        end
        
        function showLoadingPanel(obj)
            
        end
        
        function hideLoadingPanel(obj)
            
        end
    end
    
    methods (Access = private) % Callbacks

        function onTabSelectionChanged(obj, src, evt)
            
            currentTitle = obj.TabGroup.SelectedTab.Title;
            pageNum = find(strcmp(obj.PageTitles, currentTitle));

            if ~obj.IsPageCreated(pageNum)
                obj.createUIModules(pageNum)
            end
               
            switch evt.OldValue.Title
                
                case 'Folder Organization'
                    if obj.UIModule{2}.IsDirty
                        obj.UIModule{2}.updateDataLocationModel()
                    end
            end
            
            switch obj.TabGroup.SelectedTab.Title
                
                case 'Folder Organization'
                    dataLocInd = 1; %Todo...
                    obj.UIModule{2}.DataLocation = obj.DataLocationModel.Data(dataLocInd);
                    
                case 'Metadata Initialization'
                    obj.UIModule{3}.DataLocations = obj.DataLocationModel;
                    obj.UIModule{3}.onModelSet()
                
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
    
    methods (Static)
   
        function hPanel = createControlPanel(hParent)
            
            % Todo: Superclass...
            
            panelPosition = [ 20, 20, 699, 229];
            
            hPanel = uipanel(hParent);
            hPanel.Position = panelPosition;
            
        end 
        
    end
    

end