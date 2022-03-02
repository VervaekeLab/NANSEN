classdef DataLocationModelApp < nansen.config.abstract.ConfigurationApp
%DataLocationModelApp Create an app for the data location model
%

% Todo:
%   [ ] Program this using traditional gui figure for backwards
%       compatibility and more responsive figure.
%   [v] Make superclass
%   [ ] Save changes from GUI to data location model
%   [v] Method/button for selecting default datalocation
%   [v] Set read/write or read only for datalocation  
%   [v] Add control for adding multiple rootpaths for datalocations


%   [ ] Need to reload datalocationmodel if project is changed. Later
%   comment: Not sure if this is something that should be controlled from
%   this app. At best, att a method for reloading default model (i.e
%   current project's model)

%   [ ] Set method for DataLocationModel and method to make sure all UIs
%       are updated accordingly
%
%   [ ] Improve the way model changes are detecting when closing the app.
%   Use the backup of the model which is added to property on construction
%   and compare the current model to that when a close request is made.
%   
%   [ ] Important todo related to above: Need to update the backup version
%   if the model is saved, because if the app is not properly closed, just
%   put into "hibernation", the backup would not reflect the current model
%   if the app is brought back online.
    
    
    properties (Constant)
        AppName = 'Configure Data Locations'
    end
    
    properties (Constant)
        MODULE_NAMES = {'DataLocations', 'FolderOrganization', 'MetadataInit'}
        PAGE_TITLES = { 'Manage Data Locations', ...
                        'Folder Organization', ...
                        'Metadata Initialization' };
    end
    
    properties
        DataLocationModel
    end
    
    properties (Access = private)
        DataBackup % Todo: move to datalocation model.
    end
    
    properties (Access = public)
       TabGroup matlab.ui.container.TabGroup
       TabList matlab.ui.container.Tab
       
       %ControlPanels matlab.ui.container.Panel
    end
    
    properties (Dependent)
        PageTitles
    end
    
    properties (Access = private)
        IsPageCreated = false(1,3)
    end
    
    
    methods % Constructor & Destructor
        
        function obj = DataLocationModelApp(varargin)
            
            [nvPairs, varargin] = utility.getnvpairs(varargin{:});
            obj.assignPVPairs(nvPairs{:})            
            
            % Todo: Should be possible to give as input...
            if isempty(obj.DataLocationModel)
                obj.DataLocationModel = nansen.config.dloc.DataLocationModel;
            end
            obj.DataBackup = obj.DataLocationModel.Data;
            
            if isempty(varargin) && isempty(obj.TabGroup)
                
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
                obj.Figure = ancestor(obj.TabGroup, 'figure');
                obj.createLoadingPanel();

            end
            
            % Assign pv pairs...
            % obj.assignPVPairs(nvPairs{:})
            
            if ~nargout; clear obj; end
            
            %obj@applify.ModularApp
            % Create tabs
            %obj.isConstructed = true;
        end
        
        function delete(obj)
            
            % Todo: Need to create a policy or uidialog for whether changes
            % should be saved or not...
        end
    end
    
    methods (Access = public)

        function createUIModules(obj, moduleNumber, varargin)
        %createUIModules create specified ui module.
        
            if nargin < 2
                moduleNumber = 1:numel(obj.MODULE_NAMES);
            end
            
            obj.LoadingPanel.Visible = 'on';
            
            for i = moduleNumber
            
                obj.LoadingPanel.Parent = obj.TabList(i);
                
                switch i

                    case {1, 'DataLocations'}
                        obj.createDataLocationUI(varargin{:})
                        
                    case {2, 'FolderHierarchy'}
                        obj.createFolderOrganizationUI(varargin{:})
                        
                    case {3, 'MetadataInit'}
                        obj.createMetadataInitializationUI(varargin{:})
                        
                end
                obj.IsPageCreated(i) = true;
            end
            
            obj.LoadingPanel.Visible = 'off';
        end
        
        function success = setActiveModule(obj, moduleName)
        %setActiveModule Handle activation (and deactivation) of uimodules
        
            success = false; 
            
            % Get name and index of current module.
            selectedTabTitle = obj.Tabgroup.SelectedTab.Title;
            moduleIdx = find(strcmp(obj.PageTitles, selectedTabTitle)); 
            currentModuleName = obj.MODULE_NAMES{moduleIdx};
            
            % Abort if the current module is selected
            if strcmp(currentModuleName, moduleName); return; end
            
            % Step 1: Check that current module is completed.            
            [allowChangeModule, msg] = obj.UIModule{moduleIdx}.isTableCompleted();
            
            if ~allowChangeModule
                uialert(obj.Figure, msg, 'Information is missing', 'Icon', 'info')
                return
            end
            
            
            switch currentModuleName
                case ''
%                 {'DataLocations', 'FolderOrganization', 'MetadataInit'}
%                     PAGE_TITLES = { 'Manage Data Locations', ...
%                            'Folder Organization', ...
%                            'Metadata Initialization' };
            
            end
            
            switch moduleName
                
                case 'DataLocations'
                    
                case 'FolderHierarchy'
            
                case 'MetadataInit'
                    
            end

        end
        
    end
    
    methods % Get methods
        function pageTitles = get.PageTitles(obj)
            if isempty(obj.TabGroup)
                pageTitles = '';
            else
                pageTitles = {obj.TabGroup.Children.Title};
            end
        end
    end
    
    methods (Access = protected)
        
        function onFigureClosed(obj, src, evt)
        %onFigureClosed Callback for when figure is closed.    
            doAbort = promptSaveChanges(obj);
            
            if doAbort
                return
            else
                delete(obj.Figure)
            end
            
        end
        
        % Override superclass (ConfigurationApp) method
        function hideApp(obj)
        %hideApp Make app invisible. Similar to closing app, but app
        %remains in memory.

            doAbort = obj.promptSaveChanges();
            
            if doAbort
                return
            else
                if ~isempty(obj.UIModule{2})
                    obj.UIModule{2}.closeFolderListViewer()
                end
                hideApp@nansen.config.abstract.ConfigurationApp(obj)
            end
            
        end
        
        % Override applyTheme from HasTheme mixin
        function applyTheme(obj)
        % Apply theme % Todo: Superclass 
        
            S = nansen.theme.getThemeColors('deepblue');
            
            %hTabs = obj.TabGroup.Children;
            %set(hTabs, 'BackgroundColor', S.FigureBgColor)
            
            set(obj.ControlPanels, 'BackgroundColor', S.ControlPanelsBgColor)
        
        end
       
    end

    methods (Access = private) % Methods for app creation
        
        function createTabGroup(obj)
            
            hTabGroup = uitabgroup(obj.Figure);
            hTabGroup.Position = [0, 0, obj.Figure.Position(3:4)];

            numTabs = numel(obj.PAGE_TITLES);
            hTabs = gobjects(numTabs, 1);
            
            for i = 1:numTabs
                hTabs(i) = uitab(hTabGroup, 'Title', obj.PAGE_TITLES{i});
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
            obj.updateLoadPanelComponentPositions()

        end
            

        function createDataLocationUI(obj, varargin)
            
            i = 1;
            h = obj.DataLocationModel;

            % Create components for the DataLocationModel configuration
            args = [varargin, {'Parent', obj.ControlPanels(i)}];
            
            if obj.IsStandalone 
                args = [args, 'RootPathComponentType', 'uidropdown'];
            end
            
            obj.UIModule{i} = nansen.config.dloc.DataLocationModelUI(h, args{:});

        end
        
        function createFolderOrganizationUI(obj, varargin)
           
            i = 2;
            h = obj.DataLocationModel;

            % Create components for the Folder Organization configuration
            args = [varargin, { 'Parent', obj.ControlPanels(i) } ];
            obj.UIModule{i} = nansen.config.dloc.FolderOrganizationUI(h, args{:});
            
            % Todo: Make adjustable using properties...
            obj.UIModule{i}.hideAdvancedOptions()
        end
        
        function createMetadataInitializationUI(obj, varargin)
            
            i = 3;
            h = obj.DataLocationModel;
            
            % Create components for the Metadata Initialization configuration
            args = [varargin, {'Parent', obj.ControlPanels(i)} ];
            obj.UIModule{i} = nansen.config.dloc.MetadataInitializationUI(h, args{:});
            % Todo: Make adjustable using properties...
            obj.UIModule{i}.hideAdvancedOptions()
                        
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
            obj.exitTab( evt.OldValue )
            
            obj.enterTab( evt.NewValue )
            
        end

        
        function enterTab(obj, uiTab)
            % Prepare new tab on selection
            
            switch uiTab.Title
                
                case 'Manage Data Locations'
                
                case 'Folder Organization'
                    
                case 'Metadata Initialization'
                
            end
            
        end
        
        function exitTab(obj, uiTab)
            % Clean up tab on deselection
            
            switch uiTab.Title
                
                case 'Manage Data Locations'
                
                case 'Folder Organization'
                    if isvalid(obj.UIModule{2}) && obj.UIModule{2}.IsDirty
                        obj.UIModule{2}.updateDataLocationModel()
                    end
                    
                case 'Metadata Initialization'
                
            end
        end
    end
    
    methods (Access = private) 
        
        function doAbort = promptSaveChanges(obj)
        %promptSaveChanges Prompt user if UI changes should be saved.
        
            % Initialize output (assume user is not going to abort)
            doAbort = false;    
            
            % Todo: Should compare to a backup of model instead!
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

                selection = uiconfirm(obj.Figure, message, title, ...
                    'Options', {'Yes', 'No', 'Cancel'}, ...
                    'DefaultOption', 1, 'CancelOption', 3);
                
                switch selection
                    case 'Yes'
                        for i = 2:3
                            if ~isempty(obj.UIModule{i})
                                obj.UIModule{i}.updateDataLocationModel()
                                obj.UIModule{i}.markClean()
                            end
                        end
                        obj.DataLocationModel.save()
                        obj.UIModule{1}.markClean()

                    case 'No'
                        obj.DataLocationModel.restore(obj.DataBackup)
                        
                    otherwise
                        doAbort = true; % User decided to abort.
                        return
                end
            end
        end
        
    end
    
end