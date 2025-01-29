classdef App < uiw.abstract.AppWindow & nansen.mixin.UserSettings & ...
                    applify.HasTheme
% NANSEN - Data manager application with table overviews, dynamic item
% representations, configurable tasks and file integrations.

    % Todo:
    %   [ ] Add a splash screen when this is starting up
    %   [ ] More methods/options for updating statusfield. Timers, progress
    %   [ ] Make sure that project directory is on path on startup or when
    %       project is changed...
    %   [x] Remove vars from table on load if vars are not represented in
    %       tablevar folder. BUT: Not if this is first time initialization
    %   [v] Important: Load task list and start running it if preferences
    %       are set for that, even if gui is not initialized...
    %   [v] Keep track of session objects.
    %   [ ] Delete session objects from list and reset list when changing
    %       project.
    %   [ ] Send session object to task manager as a struct.
    %   [ ] Create a new session object in task manager when a task is
    %       started
    %   [ ] If table is filtered, reset row selection. Also, update custom
    %       table status (updateCustomRowSelectionStatus).

    properties (Constant, Access=protected) % Inherited from uiw.abstract.AppWindow
        AppName char = 'Nansen'
    end
    
    properties (Constant) % Name of pages / modules to include
        % Pages = {'Overview', 'File Viewer', 'Data Viewer', 'Task Processor'}%, 'Figures'}
        Pages = {'Overview', 'File Viewer', 'Task Processor'} %, 'Figures'}
    end
    
    properties (Dependent) % Main program dependables
        CurrentProject % Currently selected project
        CurrentItemType % Name of currently selected table/item type.
        CurrentObjectSelection % Current selection of data objects.
    end

    properties (Access = private) % Page modules
        UiMetaTableSelector nansen.ui.widget.ButtonGroup
        UiMetaTableViewer nansen.MetaTableViewer
        UiFileViewer
        BatchProcessor % UserSession?
        BatchProcessorUI
        UiDataViewer % Work in progress
    end
    
    properties (Access = private)
        UserSession nansen.internal.user.NansenUserSession
        ProjectManager nansen.config.project.ProjectManager % From UserSession
        DataLocationModel nansen.config.dloc.DataLocationModel % From Project
        VariableModel nansen.config.varmodel.VariableModel % From Project
        MetaTable nansen.metadata.MetaTable % From Project
        
        MetaObjectMembers = {}
        MetaObjectList % Todo: should be map/dictionary with a key per table type. File viewer should be available independent of which table is currently active
    end
       
    properties (Access = private) % Auxiliary apps that we need to keep track of
        NotesViewer
        DLModelApp
        VariableModelApp
    end

    properties (Access = private) % App / gui components
        % Heartbeat - Timer that periodically runs internal updates 
        Heartbeat timer

        % MessageDisplay - A message display interface for displaying
        % information to users.
        MessageDisplay (1,1) nansen.MessageDisplay

        % StatusText - A status text interface for displaying status
        % information to users (at bottom of figure). This object is used
        % for updating the content status messages.
        StatusText applify.StatusText

        % SessionTaskMenu - An object for creating and updating a dynamic
        % set of session / items tasks on the main figure menu
        SessionTaskMenu nansen.SessionTaskMenu

        % DiskConnectionMonitor - Monitors disk connections. This is used
        % for nansen to update states for data location indicators.
        DiskConnectionMonitor (1,1) nansen.internal.system.DiskConnectionMonitor

        % Context menu for session table. Todo: Need to generalize this to
        % flexibly update when tables are changed.
        SessionContextMenu matlab.ui.container.ContextMenu
    end

    properties (Access = private)
        ActiveTabModule = [] % Will eventually be an AbstractTabPageModule
        ItemTypes (1,:) string
        ApplicationState nansen.enum.ApplicationState = "Initializing";
        TableIsUpdating (1,1) logical = false
    end

    properties (Constant, Hidden = true) % move to appwindow superclass
        DEFAULT_THEME = nansen.theme.getThemeColors('dark-gray');
    end
    
    properties (Constant, Hidden = true) % Inherited from UserSettings
        USE_DEFAULT_SETTINGS = false % Ignore settings file                      Can be used for debugging/dev or if settings should be consistent.
        DEFAULT_SETTINGS = nansen.App.getDefaultSettings() % Struct with default settings
    end
    
    properties (Hidden, Access = private) % Event listeners
        % WindowKeyPressedListener event.listener 
        TaskInitializationListener event.listener
        SessionTaskMenuUpdatedListener event.listener
    end
    
    methods % Structors

        function app = App(userSession)
            
            nansen.addpath() % Todo: move to user session.
            
            % Call constructor explicitly to provide the nansen.Preferences
            app@uiw.abstract.AppWindow('Preferences', nansen.Preferences, 'Visible', 'off')
            
            setappdata(app.Figure, 'AppInstance', app)
            
            [isAppOpen, hApp] = app.isOpen();
            if isAppOpen
                app = hApp;
                return
            else
                app.Figure.Visible = 'on';
            end

            % % Start app construction
            app.switchJavaWarnings('off')
            app.configureWindow()
           
            app.UserSession = userSession;
            app.ProjectManager = app.UserSession.getProjectManager();

            if isempty( app.CurrentProject )
                app.ProjectManager.uiSelectProject()
            end

            % Todo: This is project dependent, should be set on
            % setProject... Dependent???
            app.DataLocationModel = nansen.DataLocationModel();
            app.VariableModel = nansen.VariableModel();
            
            app.loadMetaTable()
            app.initializeBatchProcessor()
            
            warning('off', 'Nansen:OptionsManager:PresetChanged')
            app.createMenu()
            warning('on', 'Nansen:OptionsManager:PresetChanged')

            app.createLayout()
            app.createComponents()
            
            app.switchJavaWarnings('on')
            
            % Add this callback after every component is made
            app.Figure.SizeChangedFcn = @(s, e) app.onFigureSizeChanged;
            
            app.configFigureCallbacks() % Do this last

            app.initializeHeartbeat()
            app.setIdle()

            if app.settings.General.MonitorDrives
                app.initializeDiskConnectionMonitor()
            end

            if nargout == 0
                clear app
            end
        end
        
        function delete(app)
            
            % Todo: getappdata/setappdata?
            global NoteBookViewer PipelineViewer %#ok<GVMIS>
            if ~isempty(NoteBookViewer)
                delete(NoteBookViewer); NoteBookViewer = [];
            end
            if ~isempty(PipelineViewer)
                delete(PipelineViewer); PipelineViewer = [];
            end

            if ~isempty(app.Heartbeat)
                stop(app.Heartbeat)
                delete(app.Heartbeat)
            end

            if ~isempty(app.DiskConnectionMonitor)
                delete(app.DiskConnectionMonitor)
            end
            
            app.settings.Session.SessionTaskDebug = false; % Reset debugging on quit
            app.saveSettings()

            % Save column view settings to project
            app.saveMetatableColumnSettingsToProject()
            
            if isempty(app.MetaTable)
                return
            end
            
            isdeletable = @(x) ~isempty(x) && isvalid(x);
            
            if isdeletable(app.UiMetaTableViewer)
                delete(app.UiMetaTableViewer)
            end
            
            if isdeletable(app.BatchProcessor)
                delete(app.BatchProcessor)
            end
            
            if app.settings.MetadataTable.AllowTableEdits
                app.saveMetaTable()
            end
            
            if ~isempty(app.Figure) && isvalid(app.Figure)
                app.saveFigurePreferences()
                % delete(app.Figure) % This will trigger onExit again...
            end
        end
        
        function onExit(app, h)
            
            if ~isempty(app.BatchProcessor) && isvalid(app.BatchProcessor)
                doExit = app.BatchProcessor.promptQuit();
                if ~doExit; return; end
            end
            
            if ~app.isIdle() && ~app.isShuttingDown()
                doExit = app.promptQuitIfBusy();
                if ~doExit; return; end
            end
            app.ApplicationState = nansen.enum.ApplicationState.ShuttingDown;

            % This function is called twice if the figure's close button is 
            % pressed. First when pressing the close button, and then when the 
            % figure handle is deleted, because of the way onExit is set up in
            % uiw.abstract.BaseFigure

            app.onExit@uiw.abstract.AppWindow(h);
            % delete(app) % Not necessary, happens in superclass' onExit method
        end
    end
        
    methods % Set/get methods
        function set.MetaTable(app, newTable)
            app.MetaTable = newTable;
            app.onNewMetaTableSet()
            app.updateCurrentTableType()
            app.updateTableItemCount()
        end
    
        function currentProject = get.CurrentProject(obj)
            currentProject = obj.ProjectManager.getCurrentProject();
        end

        function itemType = get.CurrentItemType(app)
            if isempty(app.MetaTable)
                itemType = string(missing); return
            end
            
            % Todo: Rely on one or the other...
            tableType = app.MetaTable.getTableType();

            if ~isempty(app.UiMetaTableSelector)
                itemType = app.UiMetaTableSelector.CurrentSelection;
                itemType = string(itemType); % might be cell
            else
                itemType = tableType;
                % if isempty(app.ItemTypes)
                %     itemType = tableType;
                % else
                %     assert(numel(app.ItemTypes)==1)
                %     itemType = app.ItemTypes;
                % end
            end
            assert(strcmpi(tableType, itemType), ...
                'NANSEN:App:UnexpectedError', ...
                'Expected name for item type to match type of table')
        end
    end
    
    methods (Access = private) % Methods for app creation
        %% Create and configure main window and layout
        function configureWindow(app)
            
            % Place screen on the preferred screen if multiple screens are
            % available.
            MP = get(0, 'MonitorPosition');
            nMonitors = size(MP, 1);
            
            if nMonitors > 1
                screenNumber = app.getPreference('PreferredScreen', 1);
                
                prefScreenPos = app.getPreference('PreferredScreenPosition', [1, 1, 1180, 700]);
                app.Figure.Position = prefScreenPos{screenNumber};
            end

            % Configure figure window to have a minimum allowed size.
            minimumFigureSize = app.getPreference('MinimumFigureSize');
            LimitFigSize(app.Figure, 'min', minimumFigureSize) % FEX
        end
        
        function configFigureCallbacks(app)
            
            app.Figure.WindowButtonDownFcn = @app.onMousePressed;
            app.Figure.WindowButtonMotionFcn = @app.onMouseMotion;
            app.Figure.WindowKeyPressFcn = @app.onKeyPressed;
            app.Figure.WindowKeyReleaseFcn = @app.onKeyReleased;
            
            [~, hJ] = evalc('findjobj(app.Figure)');
            hJ(2).KeyPressedCallback = @app.onKeyPressed;
            hJ(2).KeyReleasedCallback = @app.onKeyReleased;
        end
                
        function createLayout(app)
        
%             app.hLayout.TopBorder = uipanel('Parent', app.Figure);
%             app.hLayout.TopBorder.BorderType = 'none';
%             app.hLayout.TopBorder.BackgroundColor = [0    0.3020    0.4980];
            
            app.hLayout.MainPanel = uipanel('Parent', app.Figure, 'Tag', 'Main Panel');
            app.hLayout.MainPanel.BorderType = 'none';
            
            % Not implemented. 
            % Idea: add a drawer panel on the right side of the app. (nansen.DrawerPanel)
            app.hLayout.SidePanel = uipanel('Parent', app.Figure, 'Tag', 'Side Panel');
            %app.hLayout.SidePanel.BorderType = 'none';
            app.hLayout.SidePanel.Units = 'pixels';
            app.hLayout.SidePanel.Visible = 'off';
            
            app.hLayout.StatusPanel = uipanel('Parent', app.Figure, 'Tag', 'Status Panel');
            app.hLayout.StatusPanel.BorderType = 'none';
            
            app.hLayout.TabGroup = uitabgroup(app.hLayout.MainPanel);
            app.hLayout.TabGroup.Units = 'pixel';
            app.updateLayoutPositions()
        end
        
        function createComponents(app)

            app.createStatusField()
                  
            app.createTabPages()
        end

        %% Create and configure ui menus
        function createMenu(app)
        %createMenu Create menu components for the main gui.

            m = uimenu(app.Figure, 'Text', 'Nansen');
            app.createMenu_Nansen(m)

            m = uimenu(app.Figure, 'Text', 'Metatable');
            app.createMenu_MetaTable(m)

            m = uimenu(app.Figure, 'Text', 'Session');
            app.createMenu_Session(m)

            uimenu(app.Figure, 'Text', '|', 'Enable', 'off'); % Separator

            m = uimenu(app.Figure, 'Text', 'Apps');
            app.createMenu_Apps(m)

            m = uimenu(app.Figure, 'Text', 'Tools');
            app.createMenu_Tools(m)

            uimenu(app.Figure, 'Text', '|', 'Enable', 'off'); % Separator

            app.SessionTaskMenu = nansen.SessionTaskMenu(app);
            app.SessionTaskMenuUpdatedListener = addlistener(...
                app.SessionTaskMenu, 'MenuUpdated', @app.onSessionTaskMenuUpdated);
            
            app.TaskInitializationListener = listener(...
                app.SessionTaskMenu, 'MethodSelected', @app.onSessionTaskSelected);

            % Create a help menu:
            app.createMenu_Help()
            
            % app.createMenu_Figure() - Not implemented
        end

        function createMenu_Nansen(app, hMenu)
            % % % % % % Create PROJECTS menu items  % % % % % %
            mitem = uimenu(hMenu, 'Text','New Project');
            menuSubItem = uimenu( mitem, 'Text', 'Create...');
            menuSubItem.MenuSelectedFcn = @app.menuCallback_NewProject;

            menuSubItem = uimenu( mitem, 'Text', 'Add Existing...');
            menuSubItem.MenuSelectedFcn = @app.menuCallback_NewProject;
            
            app.Menu.ChangeProject = uimenu(hMenu, 'Text','Change Project');
            app.updateProjectList()
            
            mitem = uimenu(hMenu, 'Text','Manage Projects...');
            mitem.MenuSelectedFcn = @app.menuCallback_ManageProjects;
            
            mitem = uimenu(hMenu, 'Text','Open Project Folder', 'Separator', 'on');
            mitem.MenuSelectedFcn = @app.menuCallback_OpenProjectFolder;

            mitem = uimenu(hMenu, 'Text','Change Current Folder');
            mitem = uics.MenuList(mitem, {'Nansen', 'Current Project'}, '', 'SelectionMode', 'none');
            mitem.MenuSelectedFcn = @app.menuCallback_ChangeCurrentFolder;

            % % % % % % CONFIGURATION menu items % % % % % %
            mitem = uimenu(hMenu, 'Text','Configure', 'Separator', 'on', 'Enable', 'on');
            
            menuSubItem = uimenu( mitem, 'Text', 'Datalocations...');
            menuSubItem.MenuSelectedFcn = @(s,e) app.openDataLocationEditor;
            
            % Todo: Update this on project change
            uiSubMenu = uimenu( mitem, 'Text', 'Data Location Roots' );
            app.updateMenu_DatalocationRootConfiguration(uiSubMenu)

            menuSubItem = uimenu(mitem, 'Text', 'Variables...');
            menuSubItem.MenuSelectedFcn = @(s,e) app.openVariableModelEditor;
            
            menuSubItem = uimenu(mitem, 'Text', 'Modules...');
            menuSubItem.MenuSelectedFcn = @(s,e) app.openModuleManager;
        
            menuSubItem = uimenu(mitem, 'Text', 'Create File Adapter...');
            menuSubItem.MenuSelectedFcn = @(s,e) app.menuCallback_CreateFileAdapter;

            menuSubItem = uimenu(mitem, 'Text', 'Watch Folders...', 'Enable', 'off');
            menuSubItem.MenuSelectedFcn = @(s,e) nansen.config.watchfolder.WatchFolderManagerApp;

            mitem = uimenu(hMenu, 'Text', 'Preferences...');
            mitem.MenuSelectedFcn = @(s,e) app.editSettings;
            
            mitem = uimenu(hMenu, 'Text', 'Refresh Menu', 'Separator', 'on');
            mitem.MenuSelectedFcn = @(s,e) app.menuCallback_RefreshSessionMethod;
            
            mitem = uimenu(hMenu, 'Text','Refresh Table');
            mitem.MenuSelectedFcn = @(s,e) app.menuCallback_RefreshTable;
            
            mitem = uimenu(hMenu, 'Text','Refresh Data Locations');
            mitem.MenuSelectedFcn = @app.onDataLocationModelChanged;

            mitem = uimenu(hMenu, 'Text','Clear Memory');
            mitem.MenuSelectedFcn = @app.menuCallback_ClearMemory;

            % % % % % % Create EXIT menu items % % % % % %
            mitem = uimenu(hMenu, 'Text','Close All Figures', 'Separator', 'on');
            mitem.MenuSelectedFcn = @app.menuCallback_CloseAll;
            
            mitem = uimenu(hMenu, 'Text', 'Quit');
            mitem.MenuSelectedFcn = @(s, e) app.delete;
        end

        function createMenu_MetaTable(app, hMenu)
            
            mitem = uimenu(hMenu, 'Text', 'New Metatable...', 'Enable', 'on');
            mitem.MenuSelectedFcn = @app.menuCallback_CreateMetaTable;
            
            mitem = uimenu(hMenu, 'Text','Open Metatable', 'Separator', 'on', 'Tag', 'Open Metatable', 'Enable', 'on');
            app.updateRelatedInventoryLists(mitem)
            app.updateMetaTableMenu(mitem);

            mitem = uimenu(hMenu, 'Text','Make Current Metatable Default');
            mitem.MenuSelectedFcn = @app.menuCallback_SetDefaultMetaTable;
            
            mitem = uimenu(hMenu, 'Text','Reload Metatable');
            mitem.MenuSelectedFcn = @(src, event) app.reloadMetaTable;
            
            mitem = uimenu(hMenu, 'Text','Save Metatable', 'Enable', 'on');
            mitem.MenuSelectedFcn = @(src, event, forceSave) app.saveMetaTable(src, event, true);
            
            mitem = uimenu(hMenu, 'Text','Manage Metatables...', 'Enable', 'off');
            mitem.MenuSelectedFcn = [];
            
            % % % Create menu items for METATABLE loading and saving % % %
            
% %             mitem = uimenu(hMenu, 'Text','Load Metatable...', 'Enable', 'off');
% %             mitem.MenuSelectedFcn = @app.menuCallback_LoadDb;
% %             mitem = uimenu(hMenu, 'Text','Refresh Metatable', 'Enable', 'off');
% %             mitem.MenuSelectedFcn = @(src, event) app.reloadExperimentInventory;
% %             mitem = uimenu(hMenu, 'Text','Save Metatable', 'Enable', 'off');
% %             mitem.MenuSelectedFcn = @app.saveExperimentInventory;
% %             mitem = uimenu(hMenu, 'Text','Save Metatable As', 'Enable', 'off');
% %             mitem.MenuSelectedFcn = @app.saveExperimentInventory;
                
            % % Section with menu items for creating table variables

            mitem = uimenu(hMenu, 'Text','New Table Variable', 'Separator', 'on');
            menuSubItem = uimenu( mitem, 'Text', 'Create...');
            menuSubItem.MenuSelectedFcn = @(s,e) app.menuCallback_CreateTableVariable;
            
            menuSubItem = uimenu( mitem, 'Text', 'Import...'); 
            menuSubItem.MenuSelectedFcn = @(s,e) app.menuCallback_ImportTableVariable;
            
            % Menu with submenus for editing table variable definition:
            mitem = uimenu(hMenu, 'Text', 'Edit Table Variable Definition');
            app.updateTableVariableMenuItems(mitem)

            % TODO: Include table variables from a metadata model.
            % TODO: Turn this section for creating a submenu into a function.

            % Get metadata models to include from project preferences
            % metadataModelList = app.CurrentProject.getMetadataModelList(); % This is not implemented yet!
            % metadataModelList = {nanomi.openMINDS}; % Concrete implementation for testing... NOTE: External package.
            
            metadataModelList = {};
            % Get terms to include from metadata model
            for i = 1:numel(metadataModelList)
                % Get name of metadata model
                iMetadataModel = metadataModelList{i};
                mitem = uimenu(hMenu, 'Text', sprintf('Add %s Schema', iMetadataModel.Name));

                % Get list of terms/schemas. QUESTION: Should these names
                % be dependent on the current metatable type? Ideally - yes.
                schemaNames = iMetadataModel.listSchemaNames();

                mItem = uics.MenuList(mitem, schemaNames, '', 'SelectionMode', 'none');
                mItem.MenuSelectedFcn = @(s,e) app.addMetadataSchema(s, iMetadataModel);
            end

            % mItem.MenuSelectedFcn = @app.addOpenMindsSchema;

% % %             for iVar = 1:numel(columnVariables)
% % %                 hSubmenuItem = uimenu(mitem, 'Text', columnVariables{iVar});
% % %                 hSubmenuItem.MenuSelectedFcn = @app.editTableVariableDefinition;
% % %             end
% % %
% %             menuAlternatives = {'Enter values manually...', 'Get values from function...', 'Get values from dropdown...'};
% %             for i = 1:numel(menuAlternatives)
% %                 hSubmenuItem = uimenu(mitem, 'Text', menuAlternatives{i});
% %                 hSubmenuItem.MenuSelectedFcn = @(s,e, cls) app.addTableVariable('session');
% %             end
            
            mitem = uimenu(hMenu, 'Text','Manage Variables...', 'Enable', 'off');
            mitem.MenuSelectedFcn = [];

            % --- Section with menu items for session methods/tasks
            mitem = uimenu(hMenu, 'Text', 'New Table Method...', 'Separator', 'on');
            mitem.MenuSelectedFcn = @(s,e) app.menuCallback_CreateTableMethod;

            % Todo: Import metatable from excel file / table file...
% %             mitem = uimenu(m, 'Text','Import from Excel', 'Separator', 'on', 'Enable', 'on');
% %             mitem.MenuSelectedFcn = @app.menuCallback_ImportTable;
% %             mitem = uimenu(m, 'Text','Export to Excel');
% %             mitem.MenuSelectedFcn = @app.menuCallback_ExportToTable;
        end

        function createMenu_Session(app, hMenu, updateFlag)
            
            if nargin < 3
                updateFlag = false;
            end
            
            if nargin < 2 || isempty(hMenu)
                hMenu = findobj(app.Figure, 'Type', 'uimenu', '-and', 'Text', 'Session');
            end
            
            if updateFlag
                delete(hMenu.Children)
            end

          % --- Section with menu items for session methods/tasks
            mitem = uimenu(hMenu, 'Text', 'New Session Method...');
            mitem.MenuSelectedFcn = @(s,e,type) app.menuCallback_CreateTableMethod('session');
            
            mitem = uimenu(hMenu, 'Text', 'New Data Variable...', 'Enable', 'off');
            mitem.MenuSelectedFcn = [];
            
          % --- Section with menu items for creating pipeline
            mitem = uimenu(hMenu, 'Text', 'New Pipeline...', 'Enable', 'on', 'Separator', 'on');
            mitem.MenuSelectedFcn = @app.menuCallback_CreateNewPipeline;

            mitem = uimenu(hMenu, 'Text', 'Edit Pipeline', 'Enable', 'on');
            app.updateMenu_PipelineItems(mitem)
        
            mitem = uimenu(hMenu, 'Text', 'Configure Pipeline Assignment...', 'Enable', 'on');
            mitem.MenuSelectedFcn = @app.menuCallback_ConfigurePipelineAssignment;

          % --- Section with menu items for creating task lists
            mitem = uimenu(hMenu, 'Text', 'Get Queueable Task List', 'Enable', 'on', 'Separator', 'on');
            mitem.MenuSelectedFcn = @(s, e, mode) app.createBatchList('Queuable');

            mitem = uimenu(hMenu, 'Text', 'Get Manual Task List', 'Enable', 'on');
            mitem.MenuSelectedFcn = @(s, e, mode) app.createBatchList('Manual');
            
          % --- Section with menu item for detecting sessions
            mitem = uimenu(hMenu, 'Text','Detect New Sessions', 'Separator', 'on');
            mitem.Callback = @(src, event) app.menuCallback_DetectSessions;

% %             mitem = uimenu(hMenu, 'Text','Remove Table Variable...');
% %
% %             varNames = nansen.metadata.utility.getCustomTableVariableNames();
% %             mc = ?nansen.metadata.schema.generic.Session;
% %             varNames = setdiff(varNames, {mc.PropertyList.Name});
% %
% %             for iVar = 1:numel(varNames)
% %                 hSubmenuItem = uimenu(mitem, 'Text', varNames{iVar});
% %                 hSubmenuItem.MenuSelectedFcn = @app.removeTableVariable;
% %             end
        end
        
        function createMenu_Apps(~, hMenu)
            mitem = uimenu(hMenu, 'Text', 'Imviewer');
            mitem.MenuSelectedFcn = @(s,e) imviewer();

            mitem = uimenu(hMenu, 'Text', 'FovManager');
            mitem.MenuSelectedFcn = @(s,e) fovmanager.App();

            mitem = uimenu(hMenu, 'Text', 'RoiManager');
            mitem.MenuSelectedFcn = @(s,e) roimanager.RoimanagerDashboard();
        end

        function createMenu_Tools(app, hMenu)
            
            if nargin < 2
                hMenu = findobj(app.Figure, 'Type', 'uimenu', '-and', 'Text', 'Tools');
            end

            if ~isempty(hMenu.Children)
                delete(hMenu.Children)
            end

            folderPathList = app.CurrentProject.getMixinFolders('tool');
            app.createMenuFromDir(hMenu, folderPathList)
        end

        function createMenu_Help(app)
            % Create a menu separator
            uimenu(app.Figure, 'Text', '|', 'Enable', 'off', ...
                'Tag', 'Help (Menu Separator)');

            % Create the top level menu
            m = uimenu(app.Figure, 'Text', 'Help', 'Tag', 'Help');

            helpDoc = fullfile(nansen.rootpath, 'code', 'resources', 'docs', 'nansen_app', 'keyboard_shortcuts.html');
            mitem = uimenu(m, 'Text','Show Keyboard Shortcuts');
            mitem.MenuSelectedFcn = @(src, event) applify.SimpleHelp(helpDoc);
            
            mitem = uimenu(m, 'Text','Reactivate All Popup Tips');
            mitem.Enable = 'off';
            % mitem.MenuSelectedFcn = @(src, event) nansen.internal.reactivatePopupTips;

            mitem = uimenu(m, 'Text','Go to NANSEN Wiki Page', 'Separator', 'on');
            mitem.MenuSelectedFcn = @(s, e) web('https://github.com/VervaekeLab/NANSEN/wiki');

            mitem = uimenu(m, 'Text','Create a GitHub Issue...');
            mitem.MenuSelectedFcn = @(s, e) web('https://github.com/VervaekeLab/NANSEN/issues/new');
        end
        
        function createMenu_Figure(app)
        % NOT IMPLEMENTED YET - Add menu for multipart figures.
        
        % Developer notes: 
        %  - The multipart figure functionality needs to be updated and added
        %    to projects.
        %  - This menu must be updated on project change
        
            m = uimenu(app.Figure, 'Text', 'Figure');

            S = app.CurrentProject.listFigures(); % Todo: Implement this

            for i = 1:numel(S)
                mItem = uimenu(m, 'Text', S(i).Name);
                for j = 1:numel(S(i).FigureNames)
                    mSubItem = uimenu(mItem, 'Text', S(i).FigureNames{j});
                    mSubItem.MenuSelectedFcn = ...
                        @(s,e,n1,n2) app.menuCallback_OpenFigure(...
                                        S(i).Name, S(i).FigureNames{j});
                end
            end
        end

        function updateTableVariableMenuItems(app, hMenu)
            
            if nargin < 2
                hMenu = findobj(app.Figure, 'Text', 'Edit Table Variable Definition');
                if ~isempty(hMenu.Children)
                    delete(hMenu.Children)
                end
            end

            tableVariableAttributes = app.CurrentProject.getTable('TableVariable');
            
            % Get names of variables that have update functions.
            getRowsToKeep = @(T) T.HasUpdateFunction & ~T.IsEditable;
            rowsToKeep = getRowsToKeep(tableVariableAttributes);
            columnVariables = tableVariableAttributes{rowsToKeep, 'Name'};
            
            % Create a menu list with items for each variable
            mItem = uics.MenuList(hMenu, columnVariables, '', 'SelectionMode', 'none');
            mItem.MenuSelectedFcn = @app.editTableVariableDefinition;
        end
        
        function updateMenu_PipelineItems(app, hMenu)
            
            if nargin < 2
                hMenu = gobjects(0);
                hMenu(1) = findobj(app.Figure, 'Text', 'Edit Pipeline');
                try
                    hMenu(2) = findobj(app.Figure, 'Text', 'Assign Pipeline');
                catch
                    hMenu(2) = findobj(app.SessionContextMenu, 'Text', 'Assign Pipeline'); 
                end
            end
            
            if nargin == 2 && ischar(hMenu)
                hMenu = findobj(app.Figure, 'Text', hMenu);
            end
            
            plc = nansen.pipeline.PipelineCatalog;
            plNames = plc.PipelineNames;
            
            for i = 1:numel(hMenu)
                
                if isempty(hMenu(i)); continue; end
                
                if ~isempty(hMenu(i).Children)
                    delete(hMenu(i).Children)
                end

                for j = 1:numel(plNames)
                    mSubItem = uimenu(hMenu(i), 'Text', plNames{j});
                    switch hMenu(i).Text
                        case 'Edit Pipeline'
                            mSubItem.MenuSelectedFcn = @app.menuCallback_EditPipelines;
                        case 'Assign Pipeline'
                            mSubItem.MenuSelectedFcn = @app.menuCallback_AssignPipelines;
                    end
                end
                
                if strcmp(hMenu(i).Text, 'Assign Pipeline')
                    mSubItem = uimenu(hMenu(i), 'Text', 'No pipeline', 'Separator', 'on', 'Enable', 'on');
                    mSubItem.MenuSelectedFcn = @app.menuCallback_AssignPipelines;
                    mSubItem = uimenu(hMenu(i), 'Text', 'Autoassign pipeline', 'Enable', 'off');
                    mSubItem.MenuSelectedFcn = @app.menuCallback_AssignPipelines;
                end

                if isempty(plNames)
                    hMenu(i).Enable = 'off';
                else
                    hMenu(i).Enable = 'on';
                end
            end
            
            % Update enable state of a related menu item (Should not be
            % here, but it's related to above):
            hMenuTmp = findobj(app.Figure, 'Text', 'Configure Pipeline Assignment...');
            if ~isempty(hMenuTmp)
                if isempty(plNames)
                    hMenuTmp.Enable = 'off';
                else
                    hMenuTmp.Enable = 'on';
                end
            end
        end
        
        function updateMenu_DatalocationRootConfiguration(app, hMenu)
            
            if nargin < 2
                hMenu = findobj(app.Figure, 'Text', 'Data Location Roots');
                if ~isempty(hMenu.Children)
                    delete(hMenu.Children)
                end
            end

            itemNames = app.DataLocationModel.DataLocationNames;
            mItem = uics.MenuList(hMenu, itemNames, '', 'SelectionMode', 'none');
            mItem.MenuSelectedFcn = @(s, e) app.onConfigureDatalocationRootMenuClicked(s, e);
        end

        function updateProjectList(app)
        %updateProjectList Update lists of projects in uicomponents
            
            names = app.ProjectManager.ProjectNames;
            currentProject = app.ProjectManager.CurrentProject;

            if isfield( app.Menu, 'ProjectList' )
                app.Menu.ProjectList.Items = names;
                app.Menu.ProjectList.Value = currentProject;
            else
                hParent = app.Menu.ChangeProject;
                hMenuList = uics.MenuList(hParent, names, currentProject);
                hMenuList.MenuSelectedFcn = @app.menuCallback_ChangeProject;
                app.Menu.ProjectList = hMenuList;
            end
        end
        
        function updateMetaTableMenu(app, mItem)
            
            if nargin < 2
                mItem = findobj(app.Figure, 'Type', 'uimenu', '-and', 'Text', 'Open Metatable');
            end
            
            if isempty(mItem); return; end
            set(mItem.Children, 'Checked', 'off')

            for i = 1:numel(mItem.Children)
                % Add checkmark if menu item name corresponds with current
                % metatable name.
                mSubItem = mItem.Children(i);
                thisName = strrep(mSubItem.Text, ' (master)', '');
                thisName = strrep(thisName, ' (default)', '');
                
                if strcmp( thisName, app.MetaTable.getName() )
                    mSubItem.Checked = 'on';
                end
            end
        end
        
        function updateMetaTableViewMenu(app, mItem)
            % Todo: (not implemented yet)
            if nargin < 2
                mItem = findobj(app.Figure, 'Type', 'uimenu', '-and', 'Text', 'Change Table View');
            end
                        
            currentProjectName = app.ProjectManager.CurrentProject;
            projectObj = app.ProjectManager.getProjectObject(currentProjectName);

            hCatalog = projectObj.MetaTableViewCatalog;
            names = {hCatalog.Names};

            if ~isempty(mItem.Children)
                delete(mItem.Children)
            end

            for i = 1:numel(names)
                msubitem = uimenu(mItem, 'Text', names{i});
                msubitem.MenuSelectedFcn = @app.onChangeMetaTableViewMenuClicked;
                if strcmp(names{i}, hCatalog.DefaultItem)
                    msubitem.Checked = 'on';
                end
            end
        end

        function updateSessionInfoDependentMenus(app)
            app.SessionContextMenu = app.createSessionTableContextMenu();
            app.createMenu_Session([], true)
        end
        
        function updateRelatedInventoryLists(app, mItem)
        % updateRelatedInventoryLists - Update submenus holding metatable lists   
            if nargin < 2
                mItem(1) = findobj(app.Figure, 'Tag', 'Open Metatable');
                try
                    mItem(2) = findobj(app.Figure, 'Tag', 'Add to Metatable');
                catch
                    mItem(2) = findobj(app.SessionContextMenu, 'Tag', 'Add to Metatable');
                end
            else
            end

            names = app.MetaTable.getAssociatedMetaTables('same_class');
            
            for i = 1:numel(mItem)
                delete(mItem(i).Children)
                
                switch mItem(i).Tag
                    case 'Open Metatable'
                        for j = 1:numel(names)
                            uimenu(mItem(i), 'Text', names{j}, 'Callback', @app.menuCallback_OpenMetaTable)
                        end
                        
                    case 'Add to Metatable'
                        namesTmp = cat(1, {'New Metatable...'}, names);
            
                        for j = 1:numel(namesTmp)
                            if j == 2
                                uimenu(mItem(i), 'Text', namesTmp{j}, 'Callback', @app.menuCallback_AddSessionToMetatable, 'Separator', 'on')
                            else
                                uimenu(mItem(i), 'Text', namesTmp{j}, 'Callback', @app.menuCallback_AddSessionToMetatable)
                            end
                        end
                end
            end
        end

        function createMenuFromDir(app, hParent, dirPath)
        %createMenuFromDir Create menu components from a folder/folder tree
        %
        % Todo: Create a utility function for doing this, and combine with
        % SessionTaskMenu if there are overlaps...
        
        % Requires: varname2label
            import utility.string.varname2label
            import utility.dir.recursiveDir

            L = recursiveDir(dirPath, "RecursionDepth", 1);
            
            for i = 1:numel(L)
                
                if L(i).isdir
                
                    menuName = strrep(L(i).name, '+', '');
                    menuName = varname2label(menuName);
                
                    if strcmp(menuName, 'Abstract')
                        continue
                    end

                    iMenu = uimenu(hParent, 'Text', menuName);
                    app.createMenuFromDir(iMenu, fullfile(L(i).folder, L(i).name))

                else
                    [~, fileName, ext] = fileparts(L(i).name);
                    
                    if ~strcmp(ext, '.m')
                        continue
                    end
                    
                    name = varname2label(fileName);
                                        
                    % Create a function handle from the package hierarchy.
                    splitFolders = strsplit(L(i).folder, filesep);
                    isPackage = strncmp(splitFolders, '+', 1);
                    packageName = strjoin(splitFolders(isPackage), '.');
                    packageName = strrep(packageName, '+', '');
                    
                    functionName = strjoin({packageName, fileName}, '.');
                    
                    % Following is too slow: % But the idea was to bundle
                    % functions as static methods in a class instead of
                    % making a folder with multiple functions. I wanted to
                    % do this where each function call is the same, just
                    % varying by a keyword....
                    % % % if ~isempty(meta.class.fromName(functionName))
                    % % %     className = strjoin({packageName, fileName}, '.');
                    % % %     methods = findPropertyWithAttribute(className, 'Constant');
                    % % %
                    % % %     iSubMenu = uimenu(hParent, 'Text', name);
                    % % %     for j = 1:numel(methods)
                    % % %         name = varname2label(methods{j});
                    % % %         iMitem = uimenu(iSubMenu, 'Text', name);
                    % % %         hfun = str2func(functionName);
                    % % %         iMitem.MenuSelectedFcn = @(s, e, h, kwd) app.menuCallback_SessionMethod(hfun, methods{j});
                    % % %     end
                    % % %
                    % % % else
                    hfun = str2func(sprintf( '@(s,e) %s', functionName) );
                    
                    iMitem = uimenu(hParent, 'Text', name);
                    iMitem.MenuSelectedFcn = hfun;
                    % % % end
                end
            end
        end
        
        %% Create table context menu
        function hContextMenu = createSessionTableContextMenu(app)
        %createSessionTableContextMenu Create a context menu for sessions in table
            
            hContextMenu = uicontextmenu(app.Figure);
            % hContextMenu.ContextMenuOpeningFcn = @(s,e,m) disp('test');%onContextMenuOpening;
        
            % Delete context menu if it exists from before:
            if ~isempty(app.UiMetaTableViewer.TableContextMenu)
                delete(app.UiMetaTableViewer.TableContextMenu)
            end
            app.UiMetaTableViewer.TableContextMenu = hContextMenu;
            
            hMenuItem = gobjects(0);
            c = 1;
            
            % Create a context menu
            hMenuItem(c) = uimenu(hContextMenu, 'Text', 'Open Session Folder');
            
            % Get available datalocations from a session object
            % Todo: Why select the first item of the table? Why not use the
            % DataLocationModel directly?
            if contains('DataLocation', app.MetaTable.entries.Properties.VariableNames )
                if ~isempty(app.MetaTable.entries)
                    dataLocationItem = app.MetaTable.entries{1, 'DataLocation'};
                    dataLocationItem = app.DataLocationModel.expandDataLocationInfo(dataLocationItem);
                    dataLocationNames = {dataLocationItem.Name};
                end

                for i = 1:numel(dataLocationNames)
                    mTmpI = uimenu(hMenuItem(c), 'Text', dataLocationNames{i});
                    mTmpI.Callback = @(s, e, datatype) app.openFolder(dataLocationNames{i});
                end
                % % Todo: Can I use the below, I.w how to pass the data location name? Tags?
                % % mitem = uics.MenuList(hMenuItem(c), dataLocationNames, '', 'SelectionMode', 'none');
                % % mitem.MenuSelectedFcn = @(s, e, datatype) app.openFolder(dataLocationNames{i});
            end
            
            m0 = uimenu(hContextMenu, 'Text', 'Add to Metatable', 'Tag', 'Add to Metatable');
            app.updateRelatedInventoryLists(m0)
            
            c = c + 1;
            hMenuItem(c) = uimenu(hContextMenu, 'Text', 'Create New Note', 'Separator', 'on');
            hMenuItem(c).Callback = @(s, e) app.contextMenuCallback_CreateNoteForItem();
            
            c = c + 1;
            hMenuItem(c) = uimenu(hContextMenu, 'Text', 'View Session Notes');
            hMenuItem(c).Callback = @(s, e) app.contextMenuCallback_ViewSessionNotes();
           
            c = c + 1;
            hMenuItem(c) = uimenu(hContextMenu, 'Text', 'Get Task List', 'Separator', 'on');
            hSubmenuItem = uimenu(hMenuItem(c), 'Text', 'Manual');
            hSubmenuItem.Callback = @(s, e) app.createBatchList('Manual');
            
            hSubmenuItem = uimenu(hMenuItem(c), 'Text', 'Queuable');
            hSubmenuItem.Callback = @(s, e) app.createBatchList('Queuable');
        
            c = c + 1;
            hMenuItem(c) = uimenu(hContextMenu, 'Text', 'Assign Pipeline');
            app.updateMenu_PipelineItems(hMenuItem(c))
            
            c = c + 1;
            hMenuItem(c) = uimenu(hContextMenu, 'Text', 'Update Column Variable');
            
            % Get names of table variables with an update function.
            T = app.CurrentProject.getTable('TableVariable');
            T = T(T.TableType == 'session', :);
            columnVariableNames = T{T.HasUpdateFunction, 'Name'};
            
            % Todo: This needs to be updated when table type changes.
            for iVar = 1:numel(columnVariableNames)
                hSubmenuItem = uimenu(hMenuItem(c), 'Text', columnVariableNames{iVar});
                hSubmenuItem.Callback = @app.updateTableVariable;
            end
        
        % % %     % Todo: This should be conditional, and depend on whether a metadata
        % % %     % model is present as extension and if any schemas are selected
        % % %     c = c + 1;
        % % %     hMenuItem(c) = uimenu(hContextMenu, 'Text', 'View Schema Info');
        % % %     hMenuItem(c).Callback = @(s, e) app.viewSchemaInfo();
        
            c = c + 1;
            hMenuItem(c) = uimenu(hContextMenu, 'Text', 'Copy SessionID(s)', 'Separator', 'on');
            hMenuItem(c).Callback = @(s, e) app.copySessionIdToClipboard;
        
            % hMenuItem(c) = uimenu(hContextMenu, 'Text', 'Copy Value(s)');
            % hMenuItem(c).Callback = @app.copyTableValuesToClipboard;
        
            c = c + 1;
            hMenuItem(c) = uimenu(hContextMenu, 'Text', 'Remove Session', 'Separator', 'on');
            hMenuItem(c).Callback = @(s, e) app.contextMenuCallback_RemoveSession;
        
            % m3 = uimenu(hContextMenu, 'Text', 'Update Session', 'Callback', @app.updateSessionObjects, 'Enable', 'on');
            % m1 = uimenu(hContextMenu, 'Text', 'Remove Session', 'Callback', @app.buttonCallback_RemoveSession, 'Separator', 'on');
        end
        
        function enableSessionContextMenu(app)
            app.UiMetaTableViewer.TableContextMenu = app.SessionContextMenu;
        end

        function disableSessionContextMenu(app)
            app.UiMetaTableViewer.TableContextMenu = [];
        end

        %% Create/initialize subcomponents and modules
        function createStatusField(app)
            
            app.h.StatusField = uicontrol('Parent', app.hLayout.StatusPanel, 'style', 'text');
            app.h.StatusField.Units = 'normalized';
            app.h.StatusField.Position = [0,-0.2,1,1];                      % -0.2: Correct for text being offset towards top of textbox
            
            % app.h.StatusField.FontName = 'avenir next';
            app.h.StatusField.FontSize = 12;
            app.h.StatusField.FontUnits = 'pixels';
            
            app.h.StatusField.String = '';
            app.h.StatusField.BackgroundColor = ones(1,3).*0.85;
            app.h.StatusField.HorizontalAlignment = 'left';
            app.h.StatusField.Enable = 'inactive';

            app.StatusText = applify.StatusText({'ItemCount', 'CustomStatus', 'Status'});
            app.StatusText.UpdateFcn = @app.updateStatusField;
            app.StatusText.Status = 'Status : Idle';
            app.updateTableItemCount()
        end

        function updateStatusField(app, text)
            app.h.StatusField.String = sprintf(' %s', text);
        end
        
        function createTabPages(app)
            
            for i = 1:numel(app.Pages)
                
                pageName = app.Pages{i};
                
                hTab = uitab(app.hLayout.TabGroup);
                hTab.Title = pageName;
                
                switch pageName
                    case 'Overview'
                        app.initializeMetaTableViewer(hTab)
                        
                    case 'File Viewer'
                        app.initializeFileViewer(hTab)

                    case 'Data Viewer'
                        h = nansen.DataViewer(hTab);
                        app.UiDataViewer = h;

                    case 'Task Processor'
                end
            end
            
            % Add a callback function for when tab selection is changed
            app.hLayout.TabGroup.SelectionChangedFcn = @app.onTabChanged;
        end
        
        function initializeMetaTableViewer(app, hTab)
            
            % Prepare inputs
            S = app.settings.MetadataTable;
            S = rmfield(S, 'AutosaveMetaTable'); % Used elsewhere
            S = rmfield(S, 'AutosaveMetadataToDataFolders'); % Used in this class
            nvPairs = utility.struct2nvpairs(S);
            nvPairs = [{'AppRef', app}, nvPairs];
                       
            try
                columnSettings = app.loadMetatableColumnSettingsFromProject();
                % app.UiMetaTableViewer.ColumnSettings = columnSettings;
            catch
                columnSettings = struct.empty;
            end
            nvPairs = [{'ColumnSettings', columnSettings}, nvPairs];

            % Create table + assign to property + set callback
            h = nansen.MetaTableViewer(hTab, app.MetaTable, nvPairs{:});
            app.UiMetaTableViewer = h;
            h.CellEditCallback = @app.onMetaTableDataChanged;
            
            % Add keypress callback to uiw.Table object
            h.HTable.KeyPressFcn = @app.onKeyPressed;
            % h.HTable.MouseMotionFcn = @(s,e) onMouseMotionInTable(h, s, e);
            
            addlistener(h.HTable, 'MouseMotion', @app.onMouseMoveInTable);
            
            h.UpdateColumnFcn = @app.updateTableVariable;
            h.ResetColumnFcn = @app.resetTableVariable;
            h.DeleteColumnFcn = @app.removeTableVariable;
            h.EditColumnFcn = @app.editTableVariableFunction;

            h.GetTableVariableAttributesFcn = @(s,e) app.getTableVariableAttributes();

            h.MouseDoubleClickedFcn = @app.onMouseDoubleClickedInTable;
            
            addlistener(h, 'SelectionChanged', @app.onTableItemSelectionChanged);
            addlistener(h, 'TableUpdated', @(s,e)app.updateTableItemCount);

            app.SessionContextMenu = app.createSessionTableContextMenu();

            % Set background color for tab to match the color of the
            % TabGroup container.
            hTab.BackgroundColor = ones(1,3)*0.91;

            % Create table menu (menu for selecting tables):
            app.initializeMetaTableSelector(hTab)
        end

        function initializeMetaTableSelector(app, hTab)
            
            % Todo: reset and update this on project change
            
            if ~isempty(app.UiMetaTableSelector)
                delete(app.UiMetaTableSelector)
            end

            if nargin < 2
                % Todo: make method or better way of retrieving this
                hTabTitles = {app.hLayout.TabGroup.Children.Title};
                isTableTab = strcmp(hTabTitles, 'Overview');
                hTab = app.hLayout.TabGroup.Children(isTableTab);
            end

            app.updateAvailableTableTypes()

            metatableTypes = app.ItemTypes;
            isSelected = strcmp(metatableTypes, class(app.MetaTable));

            if numel(unique(metatableTypes)) > 1
                metatableTypes = utility.string.getSimpleClassName(cellstr(metatableTypes));
                metaTableTypes = unique(metatableTypes, 'stable');

                buttonGroup = nansen.ui.widget.ButtonGroup(hTab, 'Items', metaTableTypes);
                buttonGroup.updateLocation()
                buttonGroup.SelectionChangedFcn = @app.onMetaTableTypeChanged;
                app.UiMetaTableSelector = buttonGroup;
                app.UiMetaTableSelector.CurrentSelection = metaTableTypes(isSelected);
                app.updateMetaTableViewerPosition()
            end
        end

        function updateMetaTableViewerPosition(app)
        % updateTablePosition - Update position of table
        %
        %   If there is a table selector, this function is used to ensure
        %   the table is positioned left of the table selector menu.

            if isempty(app.UiMetaTableSelector); return; end
            
            w = app.UiMetaTableSelector.Width;
            uiTable = app.UiMetaTableViewer;
            
            % Todo: Get the padding value programmatically
            xPadding = 3;
            
            parentPosition = getpixelposition(uiTable.HTable.Parent);
            panelWidth = parentPosition(3);

            tablePosition = getpixelposition(uiTable.HTable);
            tablePosition(1) = w + xPadding;
            tablePosition(3) = panelWidth - (w + xPadding + 1);
            setpixelposition(uiTable.HTable, tablePosition)
        end

        function initializeFileViewer(app, hTab)
        % initializeFileViewer -  Initialize the file viewer applet

            if nargin < 2
                hTabs = app.hLayout.TabGroup.Children;
                tabIdx = strcmp({hTabs.Title}, 'File Viewer');
                hTab = hTabs(tabIdx);
            end

            dataLocationNames = app.DataLocationModel.DataLocationNames;
            h = nansen.FileViewer(hTab, dataLocationNames);
            
            app.UiFileViewer = h;
            app.UiFileViewer.SessionSelectedFcn = @app.onFileViewerSessionChanged;
            
            rowInd = app.UiMetaTableViewer.DisplayedRows;
            idName = app.MetaTable.SchemaIdName;
            try
                sessionIDs = app.MetaTable.entries{rowInd, idName};
            catch
                % Todo: If the metatable is set up properly, there should
                % be no need for this fallback. Either remove or fall back
                % to something more general, like id?
                sessionIDs = app.MetaTable.entries{rowInd, 'sessionID'};
            end
            app.UiFileViewer.SessionIDList = sessionIDs;
        end

        function initializeBatchProcessor(app)
        %initializeBatchProcessor - Initialize the task processor
        
            propertyNames = fieldnames(app.settings.TaskProcessor);
            propertyValues = struct2cell(app.settings.TaskProcessor);
            pvPairs = [propertyNames'; propertyValues'];
            
            currentProject = app.ProjectManager.getCurrentProject();
            taskListFilepath = currentProject.getDataFilePath('TaskList');

            app.BatchProcessor = nansen.TaskProcessor(taskListFilepath, pvPairs{:});
            addlistener(app.BatchProcessor, 'TaskAdded', @app.onTaskAddedEventTriggered);
            addlistener(app.BatchProcessor, 'Status', 'PostSet', @app.onTaskProcessorStatusChanged);
            
            app.BatchProcessor.updateSessionObjectListeners(app)
        end
        
        function initializeBatchProcessorUI(app, hContainer)
        %initializeBatchProcessorUI Initialize task processor applet in container.
        
            if nargin < 2
                hTabs = app.hLayout.TabGroup.Children;
                hContainer = hTabs(strcmp({hTabs.Title}, 'Task Processor'));
            end
            
            h = nansen.BatchProcessorUI(app.BatchProcessor, hContainer);
            app.BatchProcessorUI = h;
        end
        
        function initializeHeartbeat(app)
            app.Heartbeat = timer('Name', 'Nansen App Timer');
            app.Heartbeat.ExecutionMode = 'fixedRate';
            app.Heartbeat.Period = 30; % Consider setting from preference
            app.Heartbeat.TimerFcn = @(timer, event) app.onHeartbeat();
            start(app.Heartbeat)
        end
    
        function initializeDiskConnectionMonitor(app)
        
            app.DiskConnectionMonitor = nansen.internal.system.DiskConnectionMonitor();
            
            addlistener(app.DiskConnectionMonitor, 'DiskAdded', ...
                @(s,e) app.onAvailableDisksChanged);

            addlistener(app.DiskConnectionMonitor, 'DiskRemoved', ...
                @(s,e) app.onAvailableDisksChanged);
        end
    
        function updateAvailableTableTypes(app)
            metatableTypes = app.CurrentProject.MetaTableCatalog.Table.MetaTableClass;
            metatableTypes = unique(metatableTypes);
            app.ItemTypes = metatableTypes;
        end

        function updateCurrentTableType(app)

        end
    end

    methods (Access = private) % Internal callbacks
            
        function onMouseDoubleClickedInTable(app, ~, evt)
        % onMouseDoubleClickedInTable - Callback for double clicks
        %
        %   Check if the currently selected column has an associated table
        %   variable definition with a double click callback function.

            thisRow = evt.Cell(1); % Clicked row index
            thisCol = evt.Cell(2); % Clicked column index
            
            if thisRow == 0 || thisCol == 0
                return
            end
            
            % Get name of column which was clicked
            thisColumnName = app.UiMetaTableViewer.getColumnNames(thisCol);

            % Use table variable attributes to check if a double click
            % callback function exists for the current table column
            TVA = app.getTableVariableAttributes('HasDoubleClickFunction');
            
            isMatch = strcmp(thisColumnName, {TVA.Name});

            if any( isMatch )
                tableVariableFunctionName = TVA(isMatch).RendererFunctionName;
                if isempty(tableVariableFunctionName); return; end
                
                tableRowIdx = app.UiMetaTableViewer.getMetaTableRows(thisRow); % Visible row to data row transformation
                tableValue = app.MetaTable.entries{tableRowIdx, thisColumnName};
                tableVariableObj = feval(tableVariableFunctionName, tableValue);
                
                tableRowData = app.MetaTable.entries(tableRowIdx,:);
                metaObj = app.tableEntriesToMetaObjects( tableRowData );
                tableVariableObj.onCellDoubleClick( metaObj );
            end
        end
        
        function onMouseMoveInTable(app, ~, evt)
        % onMouseMoveInTable -  Callback for mouse motion
        %
        %   Check if the current (mouseover) column has an corresponding
        %   table variable definition with a tooltip getter function.

            if app.TableIsUpdating; return; end
            
            persistent prevRow prevCol
            
            thisRow = evt.Cell(1); % Motion over row index
            thisCol = evt.Cell(2); % Motion over column index
            
            if thisRow == 0 || thisCol == 0
                return
            end
            
            if isequal(prevRow, thisRow) && isequal(prevCol, thisCol)
                % Skip tooltip update if mouse pointer is still on previous cell
                return
            else
                prevRow = thisRow;
                prevCol = thisCol;
            end
            
            thisColumnName = app.UiMetaTableViewer.getColumnNames(thisCol);

            TVA = app.getTableVariableAttributes('HasRendererFunction');
            isMatch = strcmp(thisColumnName, {TVA.Name});
            
            if any( isMatch )
                tableVariableFunctionName = TVA(isMatch).RendererFunctionName;
                thisRowIdx = app.UiMetaTableViewer.getMetaTableRows(thisRow);
                tableValue = app.MetaTable.entries{thisRowIdx, thisColumnName};
                
                tableVariableObj = feval(tableVariableFunctionName, tableValue);
                str = tableVariableObj.getCellTooltipString();
            else
                str = '';
            end

            set(app.UiMetaTableViewer.HTable.JTable, 'ToolTipText', str)
        end
    
        function onAvailableDisksChanged(app)
            
            returnToIdle = app.setBusy('Disk added, updating data locations'); %#ok<NASGU>
            
            % - [ ] Update volume info in the DataLocationModel
            % volumeInfo = evt.VolumeInfo;

            returnToIdle = app.setBusy('Updating table'); %#ok<NASGU>
            
            app.DataLocationModel.updateVolumeInfo() % volumeInfo;

            % - [ ] Update data location structs
            app.updateDataLocationFromModel()

            % - [ ] Refresh table on these events
            app.refreshTable()
        end

        function onHeartbeat(app)
        %onHeartbeat - Manage periodic internal update 

            % Check that we have the newest version of the metatable
            if ~isempty(app.MetaTable) && ~app.TableIsUpdating
                if ~app.MetaTable.isLatestVersion()
                    stop(app.Heartbeat) % Stop timer while waiting for user's response
                    discardNewest = app.MetaTable.resolveCurrentVersion();
                    if discardNewest
                        app.reloadMetaTable()
                    else
                        app.saveMetaTable([], [], true) % true = force-save current version
                    end
                    start(app.Heartbeat)
                end
            end
        end
    end
    
    methods
    %% Various high-level callbacks
        function grabFocus(app)
            uicontrol(app.h.StatusField)
        end
        
        function promptOpenProject(app, projectName)
            
            question = sprintf('Do you want to open the project "%s"', projectName);
            title = 'Open Project?';
            answer = app.MessageDisplay.ask(question, 'Title', title);
            
            switch answer
                case 'Yes'
                    app.changeProject(projectName)
            end
        end
        
        function changeProject(app, newProjectName)
        %changeProject Change project to specified project
            
            % Ask to save metatable if it has unsaved changes
            if ~app.MetaTable.isClean()
                wasCanceled = app.promptToSaveCurrentMetaTable();
                if wasCanceled; return; end
            end

            % Ask to stop tasks in taskprocessor if tasks are running
            % Todo: Use custom prompt message
            if ~isempty(app.BatchProcessor) && isvalid(app.BatchProcessor)
                doExit = app.BatchProcessor.promptQuit('Abort tasks?', 'Task processor is running. Are you sure you want to change project?');
                if ~doExit; return; end
            end

            % Pre project change
            app.saveMetatableColumnSettingsToProject()

            projectManager = nansen.ProjectManager;
            projectManager.changeProject(newProjectName)

            % Todo: Update session table!
            app.onProjectChanged()
        end
        
        function onProjectChanged(app, varargin)
            app.TableIsUpdating = true;
            returnToIdle = app.setBusy('Changing project'); %#ok<NASGU>
            hDlg = app.MessageDisplay.inform('Please wait, changing project...');
            
            app.BatchProcessor.closeTaskList()

            % Delete current file viewer
            delete(app.UiFileViewer); app.UiFileViewer = [];

            % Todo: Make method:
            app.UiMetaTableViewer.resetTable()
            app.UiMetaTableViewer.refreshTable(table.empty, true)
            try
                columnSettings = app.loadMetatableColumnSettingsFromProject();
                app.UiMetaTableViewer.ColumnSettings = columnSettings;
            catch
                warning('Could not update column settings from project')
            end

            % Todo: Need system on task processor to create session
            % objects..
            app.resetMetaObjectList()
            
            % Need to reassign data location model before loading metatable
            % Todo: Explicitly get models for this project.
            app.DataLocationModel = nansen.DataLocationModel();
            app.VariableModel = nansen.VariableModel();

            app.updateRelatedInventoryLists()

            delete(app.UiMetaTableSelector)
            app.UiMetaTableSelector = nansen.ui.widget.ButtonGroup.empty;

            app.loadMetaTable()

            % Update table selector
            app.initializeMetaTableSelector()

            drawnow
            currentProjectName = app.ProjectManager.CurrentProject;
            currentProject = app.ProjectManager.getProjectObject(currentProjectName);
            app.SessionTaskMenu.CurrentProject = currentProject;

            % Load new project's task list
            taskListFilepath = currentProject.getDataFilePath('TaskList');
            app.BatchProcessor.openTaskList(taskListFilepath)

            % Update menus
            app.SessionTaskMenu.refresh()
            app.SessionContextMenu = app.createSessionTableContextMenu();
            app.updateMenu_PipelineItems()
            app.updateTableVariableMenuItems()
            app.updateMenu_DatalocationRootConfiguration()
            
            % Make sure project list is displayed correctly
            % Indicating current project
            app.updateProjectList()

            % Re-initialize file viewer if tab is open.
            if strcmp(app.hLayout.TabGroup.SelectedTab.Title, 'File Viewer')
                app.initializeFileViewer()
                app.ActiveTabModule = app.UiFileViewer;
            end
                        
            % Close DL Model Editor app if it is open:
            if ~isempty( app.DLModelApp )
                delete(app.DLModelApp); app.DLModelApp = [];
            end
            if ~isempty( app.VariableModelApp )
                delete(app.VariableModelApp); app.VariableModelApp = [];
            end

            app.TableIsUpdating = false;
            delete(hDlg)
            clear returnToIdle
        end
        
        function onDataLocationModelChanged(app, src, ~)
        %onDataLocationModelChanged Event callback for datalocation model
            
            try
                d = src.openProgressDialog('Update Model');
            catch
                warning('Something went wrong')
            end

            app.MetaTable = nansen.manage.updateSessionDatalocations(...
                app.MetaTable, app.DataLocationModel);
            
            app.saveMetaTable()
            try
                close(d)
            catch
                warning('Something went wrong')
            end
        end

        function onVariableModelChanged(app, ~, ~)
            % Reload model.
            app.VariableModel.load();
        end

        function onModuleSelectionChanged(app, ~, evtData)
            % Get current project
            p = app.ProjectManager.getCurrentProject();
            
            % Update the optional modules for the project
            p.setOptionalModules( {evtData.SelectedData.PackageName} )

            app.SessionTaskMenu.CurrentProject = p;
        end
        
    %% Get meta objects from table selections
        function entries = getSelectedMetaTableEntries(app)
        %getSelectedMetaTableEntries Get currently selected meta-entries
        
            entries = [];
            
            % Get indices of selected entries from the table viewer.
            entryIdx = app.UiMetaTableViewer.getSelectedEntries();
            if isempty(entryIdx);    return;    end
            
            % Get selected entries from the metatable.
            entries = app.MetaTable.entries(entryIdx, :);
        end
        
        % % Todo: The following methods could become its own class
        % MetaObjectCache
        function metaObjects = getSelectedMetaObjects(app, useCache)
        %getSelectedMetaObjects Get session objects for the selected table rows
            if nargin < 2; useCache = true; end
            returnToIdle = app.setBusy('Creating session objects...'); %#ok<NASGU>
            entries = app.getSelectedMetaTableEntries();
            if useCache
                metaObjects = app.tableEntriesToMetaObjects(entries);
            else
                metaObjects = app.createMetaObjects(entries, useCache);
            end
        end

        function ids = getObjectId(app, object)
            idName = app.MetaTable.SchemaIdName;
            ids = {object.(idName)};
        end
        
        function metaObjects = tableEntriesToMetaObjects(app, entries)
        %tableEntriesToMetaObjects Create meta objects from table rows
        
            % schema = str2func(class(app.MetaTable));
            % schema = @nansen.metadata.type.Session;
            
            if isempty(entries)
                if isempty(app.MetaTable.ItemClassName)
                    expression = sprintf('%s.empty', class(app.MetaTable));
                else
                    expression = sprintf('%s.empty', app.MetaTable.ItemClassName);
                end
                
                metaObjects = eval(expression);
            else
                % Check if objects already exists:
                idName = app.MetaTable.SchemaIdName;
                ids = entries.(idName);

                if isnumeric(ids)
                    if isnumeric(ids) && numel(ids) == 1
                        ids = num2str(ids);
                        ids = {ids};
                    elseif isnumeric(ids) && numel(ids) > 1
                        ids = arrayfun(@(x) num2str(x), ids, 'UniformOutput', false);
                    end
                    allIds = cellfun(@num2str, app.MetaObjectMembers, 'UniformOutput', false);
                else
                    allIds = app.MetaObjectMembers;
                end
                
                [matchedIds, indInTableEntries, indInMetaObjects] = ...
                    intersect(ids, allIds, 'stable');

                metaObjectsOld = app.MetaObjectList(indInMetaObjects);
                entries(indInTableEntries, :) = []; % Don't need these anymore
                
                % Create meta objects for remaining entries if any
                metaObjectsNew = app.createMetaObjects(entries);

                if isequal(matchedIds, ids)
                    metaObjects = metaObjectsOld;
                elseif ~isempty(matchedIds)
                    metaObjects = utility.insertIntoArray(metaObjectsNew, metaObjectsOld, indInTableEntries);
                else
                    metaObjects = metaObjectsNew;
                end
            end
        end

        function metaObjects = createMetaObjects(app, tableEntries, useCache)
        %createMetaObjects - Create new meta objects from table entries
            
            arguments
                app (1,1) nansen.App
                tableEntries
                useCache = true
            end
            
            % Todo: Should eventually get items directly from the MetaTable object
            try
                itemConstructor = app.MetaTable.getItemConstructor();
            catch
                itemConstructor = @table2struct;
            end

            if isempty(tableEntries)
                try
                    metaObjects = itemConstructor().empty;
                catch
                    % Todo: Error handling
                    metaObjects = [];
                end
                return;
            end

            % Relevant for meta objects that have datalocations:
            % Create list of name value pairs for the current datalocation
            % model and variable model.
            if any(strcmp(tableEntries.Properties.VariableNames, 'DataLocation'))
                nvPairs = {...
                    'DataLocationModel', app.DataLocationModel, ...
                    'VariableModel', app.VariableModel
                    };
            else
                nvPairs = {};
            end

            numItems = height(tableEntries);
            metaObjects = cell(1, numItems);

            for i = 1:numItems
                try
                    metaObjects{i} = itemConstructor(tableEntries(i,:), nvPairs{:});
                catch
                    continue
                end
                try
                    addlistener(metaObjects, 'PropertyChanged', @app.onMetaObjectPropertyChanged);
                    addlistener(metaObjects, 'ObjectBeingDestroyed', @app.onMetaObjectDestroyed);
                catch
                    % Todo: Either throw warning or implement interface for
                    % easily implementing PropertyChanged on any table
                    % class..
                end
            end

            try
                metaObjects = [metaObjects{:}];
            catch
                % Pass. Todo: Error, warning or handle some way?
            end


            if useCache
                % Add newly created metaobjects to the list
                if isempty(app.MetaObjectList)
                    app.MetaObjectList = metaObjects;
                else
                    app.MetaObjectList = [app.MetaObjectList, metaObjects];
                end
                app.updateMetaObjectMembers()
            end
        end

        function updateMetaObjectMembers(app)
        %updateMetaObjectMembers Update list of ids for members of the
        % metaobject list
            idName = app.MetaTable.SchemaIdName;
            app.MetaObjectMembers = {app.MetaObjectList.(idName)};

            if isnumeric(app.MetaObjectMembers)
                app.MetaObjectMembers = cellfun(@num2str, app.MetaObjectMembers, 'UniformOutput', false);
            end
        end
        
        function resetMetaObjectList(app)
        %resetMetaObjectList Delete all meta objects from the list
            for i = numel(app.MetaObjectList):-1:1
                if ismethod(app.MetaObjectList(i), 'isvalid')
                    if ismethod(app.MetaObjectList(i), 'delete')
                        % It's a handle, we might need to delete it
                        if isvalid( app.MetaObjectList(i) )
                            delete( app.MetaObjectList(i) )
                        end
                    end
                end
            end
            app.MetaObjectList = [];
            app.MetaObjectMembers = {};
        end

        function onMetaObjectPropertyChanged(app, src, evt)
            
            % Todo: generalize from session
            % Todo: make method for getting table entry from objectID
            
            if ~isvalid(src); return; end

            objectID = app.getObjectId(src); % sessionID / itemID
            metaTableEntryIdx = find(strcmp(app.MetaTable.members, objectID));
            
            if numel(metaTableEntryIdx) > 1
                metaTableEntryIdx = metaTableEntryIdx(1);
                msg = sprintf('Multiple sessions have the sessionID "%s"', objectID);
                warndlg(msg)
            end
            
            app.MetaTable.editEntries(metaTableEntryIdx, evt.Property, evt.NewValue)
            
            rowIdx = metaTableEntryIdx;
            colIdx = find(strcmp(app.MetaTable.entries.Properties.VariableNames, evt.Property));
            newValue = app.MetaTable.getFormattedTableData(colIdx, rowIdx);
            newValue = table2cell(newValue);
            
            app.UiMetaTableViewer.updateCells(rowIdx, colIdx, newValue)
        end
        
        function onMetaObjectDestroyed(app, src, ~)
            if ~isvalid(app); return; end
            
            idName = app.MetaTable.SchemaIdName;
            objectID = src.(idName);
            
            [~, ~, iC] = intersect(objectID, app.MetaObjectMembers);
            app.MetaObjectList(iC) = [];

            app.updateMetaObjectMembers()
        end

        function onTaskAddedEventTriggered(app, ~, evt) %#ok<INUSD>
        %onTaskAddedEventTriggered Callback for event when task is added to
        % batchProcessor task list
        
            if strcmp( evt.Table, 'History' )
                
                task = evt.Task;
                
                sessionObj = task.args{1};
                fcnName = func2str(task.method);
                
                if strcmp(task.status, 'Completed')
                    if ismethod(sessionObj, 'updateProgress') && numel(sessionObj) == 1
                        sessionObj.updateProgress(fcnName, task.status)
                    end
                end
            end
        end
 
        function onTaskProcessorStatusChanged(app, ~, evt)
        %onTaskProcessorStatusChanged Callback for TaskProcessor Status
            if strcmp( evt.AffectedObject.Status, 'busy' )
                app.setBusy('Initializing task processor...')
            else
                app.setIdle()
            end
        end
    end
    
    methods (Hidden, Access = protected) % Methods for internal app updates
        
        function onThemeChanged(app)
            app.Figure.Color = app.Theme.FigureBackgroundColor;
            app.hLayout.MainPanel.BackgroundColor = app.Theme.FigureBackgroundColor;
            % app.hLayout.StatusPanel.BackgroundColor = app.Theme.FigureBackgroundColor;
            
            % Something like this:
            % app.UiMetaTableViewer.HTable.Theme = uim.style.tableDark;
        end
        
        function onFigureSizeChanged(app)
            app.updateLayoutPositions()
            drawnow
            % Todo: Table position only needs to be updated if the
            % overview/table page is active. Need a flag and a call to
            % updateTablePosition on tab change if the flag is dirty.
            %
            % if strcmp(app.hLayout.TabGroup.SelectedTab.Title, 'Overview')
            app.updateMetaTableViewerPosition()
            % end
        end
        
        function onSessionTaskMenuUpdated(app, ~, ~)
            % Need to recreate the Help menu in order for it to stay to the
            % right of session task menus (uistack is not a good option,
            % god knows why...)
            uiMenuHelp = findobj(app.Figure, 'Type', 'uimenu',  '-and', '-regexp', 'Tag', 'Help', '-depth', 1);
            delete(uiMenuHelp)
            app.createMenu_Help()
        end

        function onTabChanged(app, ~, evt)
            
            switch evt.NewValue.Title
                
                case 'Overview'
                    app.ActiveTabModule = app.UiMetaTableViewer;
                    
                case 'File Viewer'
                    if isempty(app.UiFileViewer) % Create file viewer
                    	thisTab = evt.NewValue;
                        app.initializeFileViewer(thisTab)
                    end
                    
                    % Todo: Remove this when MetaTable is a map with one
                    % key for each table type.
                    if ~strcmpi(app.MetaTable.getTableType, 'session')
                        msgbox('File viewer is only available when viewing the session table', 'Not supported')
                        app.hLayout.TabGroup.SelectedTab = evt.OldValue;
                        return
                    end
                                   
                    app.ActiveTabModule = app.UiFileViewer;

                    rowInd = app.UiMetaTableViewer.DisplayedRows;
                    sessionIDs = app.MetaTable.entries{rowInd, 'sessionID'};
                    app.UiFileViewer.SessionIDList = sessionIDs;
                    
                    entries = getSelectedMetaTableEntries(app);
                    if isempty(entries); return; end
                    
                    metaObj = app.tableEntriesToMetaObjects(entries(1,:));
                    
                    try
                        currentSessionID = app.UiFileViewer.getCurrentObjectId();
                    catch ME
                        switch ME.identifier
                            % This is necessary in case the session object
                            % cache was cleared.
                            case 'MATLAB:class:InvalidHandle'
                                currentSessionID = '';
                        end
                    end

                    if strcmp(metaObj.sessionID, currentSessionID)
                        return
                    else
                        % Note, select first one
                        if size(entries, 1) > 1
                            warning('Multiple sessions are selected, selecting the first item')
                        end

                        app.UiFileViewer.update(metaObj)
                    end

                case 'Data Viewer'
                    app.ActiveTabModule = app.UiDataViewer;
                    
                    selectedSessionObj = app.getSelectedMetaObjects();
                    % if isempty(selectedSessionObj); return; end
                    
                    % Todo: Handle multiple session selected same as file
                    % viewer above.
                    if isempty(selectedSessionObj)
                        app.UiDataViewer.reset()
                    else
                        app.UiDataViewer.update(selectedSessionObj(1))
                    end

                case 'Task Processor'

                    if isempty(app.BatchProcessorUI)
                        app.initializeBatchProcessorUI(evt.NewValue)
                    end

                    app.ActiveTabModule = app.BatchProcessorUI;
                
                otherwise
                    app.ActiveTabModule = [];
            end
        end
        
        function onMousePressed(app, ~, ~)
            
            % Todo: Should figure out why the focuslost callback does not
            % work in certain positions of the figure.
            if ~isempty(app.UiMetaTableViewer.ColumnFilter)
                app.UiMetaTableViewer.ColumnFilter.hideFilters();
            end
        end
        
        function onMouseMotion(app, ~, ~) %#ok<INUSD>
        end
       
        function onKeyPressed(app, src, evt)
            
% % %             persistent lastKeyPressTime
% % %             if isempty(lastKeyPressTime); lastKeyPressTime = tic; end

            if isa(evt, 'java.awt.event.KeyEvent')
                evt = uim.event.javaKeyEventToMatlabKeyData(evt);
            end

            if ~isempty(app.ActiveTabModule)
                if nansen.util.ismethod(app.ActiveTabModule, 'onKeyPressed')
                    wasCaptured = app.ActiveTabModule.onKeyPressed(src, evt);
                    if wasCaptured; return; end
                end
            end
            
            switch evt.Key
        
                case {'shift', 'q', 'e', 'r', 'h'}

% % %                     timeSinceLastPress = toc(lastKeyPressTime);
% % %                     timeSinceLastPress
% % %                     if timeSinceLastPress < 0.1
% % %                         lastKeyPressTime = tic;
% % %                         return;
% % %                     end

                    switch evt.Key
                        case 'shift'
                            app.SessionTaskMenu.Mode = 'Preview';
                        case 'q'
                            app.SessionTaskMenu.Mode = 'TaskQueue';
                        case 'e'
                            app.SessionTaskMenu.Mode = 'Edit';
                        case 'r'
                            app.SessionTaskMenu.Mode = 'Restart';
                        case 'h'
                            app.SessionTaskMenu.Mode = 'Help';
                    end

% % %                     lastKeyPressTime = tic;

                case 'w'
                    app.sendToWorkspace()
            end
        end
        
        function onKeyReleased(app, ~, evt)

            if isa(evt, 'java.awt.event.KeyEvent')
                evt = uim.event.javaKeyEventToMatlabKeyData(evt);
            end
            
            switch evt.Key
                case {'shift', 'q', 'e', 'r', 'h'}
                    app.SessionTaskMenu.Mode = 'Default';
            end
        end
        
        function updateLayoutPositions(app)
            
            figPosPix = getpixelposition(app.Figure);
           
            w = figPosPix(3);
            h = figPosPix(4);
            
            normalizedHeight = 25 / figPosPix(4);
            
            app.hLayout.StatusPanel.Position = [0, 0, 1, normalizedHeight];
            app.hLayout.MainPanel.Position = [0, normalizedHeight, 1, 1-normalizedHeight];
            
            if strcmp(app.hLayout.SidePanel.Visible, 'on')
                app.hLayout.SidePanel.Position = [w-250, 20, 250, h-20];
            else
                app.hLayout.SidePanel.Position = [w, 20, 250, h-20];
            end
            
%             app.hLayout.TopBorder.Position(2) = 1-normalizedHeight;
%             app.hLayout.TopBorder.Position(4) = normalizedHeight;
            
            app.hLayout.TabGroup.Position = [10,6,figPosPix(3)-20,figPosPix(4)-30];
        end
        
    %%% Methods for updating statusfield (Q: Should this be a separate class?)

        function updateFigureTitle(app)
            fileName = app.MetaTable.getName();

            if app.isIdle()
                status = 'idle';
            else
                status = 'busy';
            end
            
            projectName = app.ProjectManager.CurrentProject;
            titleStr = sprintf('%s | Project: %s | Metatable: %s (%s)', app.AppName, projectName, fileName, status);
            app.Figure.Name = titleStr;
        end
    
        function tf = isInitialized(app)
            tf = app.ApplicationState ~= nansen.enum.ApplicationState.Initializing;
        end

        function tf = isIdle(app)
            tf = app.ApplicationState == nansen.enum.ApplicationState.Idle;
        end

        function tf = isShuttingDown(app)
            tf = app.ApplicationState == nansen.enum.ApplicationState.ShuttingDown;
        end

        function setIdle(app)
            app.ApplicationState = nansen.enum.ApplicationState.Idle;
            app.StatusText.Status = sprintf('Status: Idle');
            app.updateFigureTitle()
            
            app.Figure.Pointer = 'arrow';
            drawnow
        end
        
        function finishup = setBusy(app, statusStr)
                        
            app.ApplicationState = nansen.enum.ApplicationState.Busy;
            app.Figure.Pointer = 'watch';
            drawnow
            
            app.updateFigureTitle()
            
            if nargin < 2 || isempty(statusStr)
                S = dbstack();
                runningMethod = strrep(S(2).name, 'sessionBrowser.', '');
                statusStr = sprintf('Status: Running %s', runningMethod);
            elseif isa(statusStr, 'function_handle')
                methodName = func2str(statusStr);
                methodName = utility.string.varname2label(methodName) ;
                statusStr = sprintf('Status: Running %s', methodName );
            else
                statusStr = sprintf('Status: %s', statusStr );
            end
            app.StatusText.Status = statusStr;
            
            if nargout
                finishup = onCleanup(@app.setIdle);
            end
            
            drawnow
        end
        
        function updateStatusWhenBusy(app)

            endOfString = app.StatusText.Status(end-3:end);
            
            if contains(endOfString, '...')
                app.StatusText.Status = app.StatusText.Status(1:end-3);
            else
                app.StatusText.Status = strcat(app.StatusText.Status, '.');
            end
  
%             if contains(endOfString, '...')
%                 app.hStatusField.String = strrep(app.hStatusField.String, '...', '');
%             elseif contains(endOfString, '..')
%                 app.hStatusField.String = strrep(app.hStatusField.String, '..', '...');
%             elseif contains(endOfString, '.')
%                 app.hStatusField.String = strrep(app.hStatusField.String, '.', '..');
%             else
%                 app.hStatusField.String = strcat(app.hStatusField.String, '.');
%             end

            drawnow limitrate
        end
        
        function updateStatusText(app, i, n, methodName)
            
            if isa(methodName, 'function_handle')
                methodName = func2str(methodName);
                methodName = utility.string.varname2label(methodName) ;
            end
                        
            % Update statusfield text showing progress.
            if i == 0
                app.StatusText.Status = strrep(app.StatusText.Status, ...
                    methodName, sprintf('%s (%d/%d finished)', methodName, i, n));
            else
                app.StatusText.Status = strrep(app.StatusText.Status, ...
                    sprintf('(%d/%d finished)', i-1, n), ...
                    sprintf('(%d/%d finished)', i, n));
            end
            
            drawnow
        end
        
        function updateTableItemCount(app, numItemsTotal, numItemsSelected)
            if ~isempty(app.StatusText)
                if nargin < 2 || isempty(numItemsTotal)
                    if isempty(app.UiMetaTableViewer)
                        numItemsTotal = size(app.MetaTable.entries, 1);
                    else
                        numItemsTotal = size(app.UiMetaTableViewer.HTable.Data, 1);
                    end
                end

                if numItemsTotal == 0
                    app.StatusText.ItemCount = "No items available";
                    return
                end

                if nargin < 3 || isempty(numItemsSelected)
                    if isempty(app.UiMetaTableViewer)
                        numItemsSelected = 0;
                    else
                        numItemsSelected = numel(app.UiMetaTableViewer.HTable.SelectedRows);
                    end
                end

                itemName = lower(app.CurrentItemType);
                if numItemsTotal > 1 
                    itemName = itemName + "s"; % plural
                end
                
                if numItemsSelected > 0
                    str = sprintf('Selected %d/%d %s', numItemsSelected, numItemsTotal, itemName);
                else
                    str = sprintf('%d %s', numItemsTotal, itemName);
                end

                app.StatusText.ItemCount = str;
            end
        end

        function updateCustomRowSelectionStatus(app)
            projectName = app.CurrentProject.Name;
            % Todo: Consider adding this to the tablevar package, and
            % potentially also having functions per table type...
            functionName = sprintf('%s.getCustomRowSelectionStatus', projectName);
            try
                selectedRows = app.UiMetaTableViewer.getSelectedEntries();
                str = feval(functionName, app.MetaTable.entries, selectedRows);
            catch
                str = '';
            end
            app.StatusText.CustomStatus = str;
        end

        function clearStatusIn(app, n)
             t = timer('ExecutionMode', 'singleShot', 'StartDelay', n);
             t.TimerFcn = @(myTimerObj, thisEvent) app.clearStatus(t);
             start(t)
        end
        
        function clearStatus(app, t)
            
            % Check validity in case this function is fired off after the
            % sessionBrowser has been closed.
            if ~isvalid(t); return; end
            
            stop(t)
            delete(t)
            
            if ~isvalid(app); return; end
            app.StatusText.Status = 'Status: Idle';
        end
    end
    
    methods (Access = private) % Methods for meta table loading and saving
        
        function onMetaTableTypeChanged(app, src, ~)
            metaTableType = src.Text;
            app.resetMetaObjectList()
            app.openMetaTable(metaTableType)
            app.SessionTaskMenu.CurrentItemType = metaTableType;
            if strcmpi(metaTableType, 'session')
                app.enableSessionContextMenu()
            else
                app.disableSessionContextMenu()
            end
        end

        function onTableItemSelectionChanged(app, src, evt)
        %onTableItemSelectionChanged Callback for meta table
            numItemsSelected = numel(evt.SelectedRows);
            numItemsTotal = size(src.HTable.Data, 1);
            
            app.updateTableItemCount(numItemsTotal, numItemsSelected)
            app.updateCustomRowSelectionStatus()
        end

        function onMetaTableDataChanged(app, ~, evt)
            
            % Todo: Can this be put somewhere else?? I.e the Date table variable definition...
            if isa(evt.NewValue, 'datetime')
                evt.NewValue.TimeZone = '';
            end
            
            % Todo: make this more robust. I.e What are the rules/
            % conditions for when a cell can be put directly into the table
            % versus when it needs to be put into a cell of the table?
            try
                app.MetaTable.entries(evt.Indices(1), evt.Indices(2)) = {evt.NewValue};
            catch
                app.MetaTable.entries{evt.Indices(1), evt.Indices(2)} = {evt.NewValue};
            end
            % The following is hopefully a temporary solution. If user
            % ticks the ignore checkbox for a session, and the settings are
            % set to hide ignored sessions, the table should be updated and
            % the session should disappear. However, there is some delays,
            % when refreshing the table and in the meantime the user could
            % go on and select more sessions to ignore. Since the visible
            % table in this small delay will not match the table model, the
            % wrong session could be ticked for ignoring. To avoid this,
            % the table is temporarily made un-editable.

            if strcmp(app.MetaTable.getVariableName(evt.Indices(2)), 'Ignore')
                if ~app.settings.MetadataTable.ShowIgnoredEntries
                    % Make table temporarily uneditable
                    allowTableEdits = app.UiMetaTableViewer.AllowTableEdits;
                    if allowTableEdits
                        app.UiMetaTableViewer.AllowTableEdits = false;
                    end
                    app.UiMetaTableViewer.refreshTable(app.MetaTable)
                    if allowTableEdits
                        app.UiMetaTableViewer.AllowTableEdits = true;
                    end
                end
            end

            % Save changes as json to data folders
            if app.settings.MetadataTable.AutosaveMetadataToDataFolders
                % Todo: Make separate method for this. Potentially in the
                % metatable class itself? Although then it needs access to
                % the data location model.

                tableType = app.CurrentItemType;
                for iRow = evt.Indices(1)
                    id = app.MetaTable.entries{iRow, app.MetaTable.SchemaIdName};
                    data = table2struct( app.MetaTable.entries(iRow, :) );
    
                    dataFolders = app.DataLocationModel.listDataFolders(...
                        'all', 'FolderType', tableType, 'Identifier', id);
    
                    for i = 1:numel(dataFolders)
                        filePath = fullfile(dataFolders{i}, sprintf('%s_info.json', lower(tableType)));
                        utility.filewrite(filePath, jsonencode(data, 'PrettyPrint', true))
                    end
                end
            end
        end

        function createTableVariable(app)
        %createTableVariable Open a dialog where user can add table variable
        %
        %   User gets the choice to create a variable that can be edited
        %   from the table or one which is retrieved from a function.
        
        % Todo: Use class instead of functions / add class as a third
        % choice. Can make more configurations using a class, i.e class can
        % provides a mouse over effect etc.
    
            % Create a struct to open in a dialog window
            
            import nansen.metadata.utility.createFunctionForCustomTableVar
            import nansen.metadata.utility.createClassForCustomTableVar
            
            metadataClass = lower( app.MetaTable.getTableType() ); % Lowercase needed?

            inputModeSelection = {...
                'Enter values manually', ...
                'Get values from function', ...
                'Get values from list' };
            
            % Create a struct for opening in the structeditor dialog
            S = struct();
            S.VariableName = '';
            S.DataType = 'numeric';
            S.DataType_ = {'numeric', 'text', 'logical'};
            S.InputMode = inputModeSelection{1};
            S.InputMode_ = inputModeSelection;
            
            S = tools.editStruct(S, '', 'New Variable', ...
                'ReferencePosition', app.Figure.Position);
            
            if isempty(S.VariableName); return; end
            
            % Make sure variable does not already exist
            currentVars = app.MetaTable.entries.Properties.VariableNames;
            if any(strcmp( S.VariableName, currentVars ))
                
                question = sprintf(['The variable "%s" already exists in this table. ', ...
                    'Do you want to modify this variable? ', ...
                    'Note: The old variable definition will be lost.'], S.VariableName);
                title = 'Confirm Variable Modification';
                answer = app.MessageDisplay.ask(question, 'Title', title);

                switch answer
                    case 'Yes'
                        % Proceed
                    case {'No', 'Cancel'}
                        return
                end
            end
        
            % Add the metadata class to s. An idea is to also select this
            % on creation.
            S.MetadataClass = metadataClass;

            % Make sure the variable name is valid
            msg = sprintf('%s is not a valid variable name', S.VariableName);
            if ~isvarname(S.VariableName); app.MessageDisplay.alert(msg); return; end
            
            switch S.InputMode
                case 'Enter values manually'
                    createClassForCustomTableVar(S)
                case 'Get values from function'
                    createFunctionForCustomTableVar(S)
                case 'Get values from list'
                    dlgTitle = sprintf('Create list of choices for %s', S.VariableName);
                    selectionList = uics.multiLineListbox({}, 'Title', dlgTitle, ...
                        'ReferencePosition', app.Figure.Position);
                    S.SelectionList = selectionList;
                    createClassForCustomTableVar(S)
            end
            
            % Add variable to table and table settings:
            initValue = nansen.metadata.utility.getDefaultValue(S.DataType);
            
            app.MetaTable.addTableVariable(S.VariableName, initValue)
            app.UiMetaTableViewer.refreshColumnModel();
            app.UiMetaTableViewer.refreshTable(app.MetaTable)
            
            % Refresh menus that show the variables of the session table...
            app.updateSessionInfoDependentMenus()
        end
        
        function importTableVariable(app)
        %importTableVariable Import a table variable definition (.m file)
            
            [filename, folder] = uigetfile('*.m', 'Select a Table Variable File');
            if isequal(filename, 0); return; end
            
            % Copy selected file into the table variable package
            filePath = fullfile(folder, filename);

            % Detect class of imported table variable from folder name
            [~, packageName] = fileparts(fileparts(filePath));
            importedTableType = strrep(packageName, '+', '');

            % Todo: Check that the selected m-file actually contains a valid
            % table variable class definition.
            
            currentTableType = lower( app.MetaTable.getTableType() );
            try
                assert(isequal(importedTableType, currentTableType), ...
                    ['Can not import table variable because the selected ', ...
                    'file is a table variable for a "%s" table, whereas the ', ...
                    'active table is a "%s" table.'], importedTableType, currentTableType)
            catch ME
                titleStr = 'Could not import table variable';
                app.MessageDisplay.alert(ME.message, 'Title', titleStr)
                % Todo: add explanation?
                return
            end
            rootPathTarget = app.CurrentProject.getProjectPackagePath('Table Variables');
            fcnTargetPath = fullfile(rootPathTarget, ['+', lower(currentTableType)] );
            if ~isfolder(fcnTargetPath); mkdir(fcnTargetPath); end

            copyfile(filePath, fullfile(fcnTargetPath, filename))

            % Does the variable exist in the table from before?
            [~, variableName] = fileparts(filename);
           
            fcnName = utility.path.abspath2funcname(fullfile(fcnTargetPath, filename));
            tableVarMetaClass = meta.class.fromName(fcnName);

            if ~app.MetaTable.isVariable( variableName )
                % Add a new table column to the table for new variable
                
                % Determine default value of this variable.
                if isempty(tableVarMetaClass)
                    tablevarFcn = str2func(fcnName);
                    initValue = tablevarFcn();
                else
                    tablevarFcn = strjoin({fcnName, 'DEFAULT_VALUE'}, '.');
                    initValue = eval( tablevarFcn );
                end

                [~, variableName] = fileparts(filename);
                app.MetaTable.addTableVariable(variableName, initValue)

                app.UiMetaTableViewer.refreshColumnModel();
                app.UiMetaTableViewer.refreshTable(app.MetaTable)
            else
                if ~isempty(tableVarMetaClass)
                    clear(fcnName) % clear class
                    rehash
                end

                % Table variable exists, so we only need to reformat the
                % table column and refresh

                % This should ideally be done in a better way. It is not
                % this app's responsibility to do this, but unfortunate side
                % effect of having decided to set metatable of
                % metatableviewer to type table...
                columnIndex = app.MetaTable.getColumnIndex(variableName);
                columnData = app.MetaTable.getFormattedTableData(columnIndex);
                app.UiMetaTableViewer.updateFormattedTableColumnData(variableName, columnData)

                app.UiMetaTableViewer.refreshColumnModel();
                app.UiMetaTableViewer.refreshTable([])
                drawnow
            end

            % Refresh menus that show the variables of the session table...
            app.updateSessionInfoDependentMenus()
        end
        
        function editTableVariableDefinition(app, src, ~)
                        
            varName = src.Text;
            
            % Todo: Conditional, other variables does not have a function
            app.editTableVariableFunction(varName)
        end
        
        function editTableVariableFunction(app, tableVariableName) %#ok<INUSD>
                    
            import nansen.metadata.utility.getTableVariableUserFunctionPath
            % Todo, support multiple table types
            varName = tableVariableName;
            metaTableType = app.CurrentItemType;
            filepath = getTableVariableUserFunctionPath(varName, metaTableType);
            edit(filepath)
        end
        
        function addMetadataSchema(app, src, metadataModel)
            import nansen.metadata.utility.createClassForCustomTableVar

            schemaName = src.Text;
            schemaInstanceNames = metadataModel.listSchemaInstances(schemaName);
            
            S = struct();
            S.VariableName = schemaName;
            S.MetadataClass = 'session';
            S.DataType = 'text';
            S.InputMode = 'Get values from list';

            % S.DataType_ = {'numeric', 'text', 'logical'};
            S.SelectionList = schemaInstanceNames;
            createClassForCustomTableVar(S)

             % Todo: Add variable to table and table settings....
            initValue = nansen.metadata.utility.getDefaultValue(S.DataType);
            
            app.MetaTable.addTableVariable(S.VariableName, initValue)
            app.UiMetaTableViewer.refreshColumnModel();
            app.UiMetaTableViewer.refreshTable(app.MetaTable)
            
            % Refresh menus that show the variables of the session table...
            app.updateSessionInfoDependentMenus()
        end

        function S = getTableVariableAttributes(app, condition)
        % getTableVariableAttributes - Get table variable attributes
        %
        %   Return the list attributes for all table variables or for a
        %   subset subject to a specified condition (optional). Condition
        %   must be one of the logical flag attributes. See
        %   nansen.metadata.abstract.TableVariable.getDefaultTableVariableAttribute
        %   for a list of attributes.

            if nargin < 2; condition = ''; end

            % Todo: get specific table type...
            currentProject = app.ProjectManager.getCurrentProject();
            T = currentProject.getTable('TableVariable');
            
            if ~isempty(condition)
                varNames = T.Properties.VariableNames;
                assert( any(strcmp(varNames, condition)), 'Invalid condition')
                T = T(T.(condition), :);
            end
 
            S = table2struct(T);
        end

        function resetTableVariable(app, src, evt)
            app.updateTableVariable(src, evt, true)
        end
        
        function updateTableVariable(app, src, evt, reset)
        %updateTableVariable Update a table variable for selected items/objects
        %
        %   This function is a callback for the context menu
        
            if nargin < 4
                reset = false;
            end
        
            if ischar(src) % For manual calls: If the value of src is the name of the variable, evt should be the update mode.
                varName = src;
                updateMode = evt;
            else % If invoked as callback, update selected rows
                varName = src.Text;
                updateMode = 'SelectedRows';
            end

            % Todo: Add case for all rows that are empty
            % Todo: Add case for all visible rows...
            
            switch updateMode
                case 'SelectedRows'
                    app.assertSessionSelected()

                    sessionObj = app.getSelectedMetaObjects();
                    rows = app.UiMetaTableViewer.getSelectedEntries();

                case 'AllEmptyRows'
                    % Todo. Should find all rows where the value has not
                    % been updated, i.e were the value is still the
                    % null/default value

                case 'AllRows' % All visible rows
                    rows = app.UiMetaTableViewer.DisplayedRows;
                    sessionObj = app.tableEntriesToMetaObjects(app.MetaTable.entries(rows,:));
            end
            
            numSessions = numel(sessionObj);
            
            if numSessions > 5 && ~reset
                h = waitbar(0, 'Please wait while updating values');
            end
            
            % Todo: This function call is different for preprogrammed
            % table variables, i.e data location.
            
            % Todo: This should be a property and it should be updated when
            % tablevariables are created or modified... (What this??)

            tableType = lower(app.CurrentItemType);

            T = app.CurrentProject.getTable('TableVariable');
            T = T(T.TableType==tableType, :);
            S = table2struct(T);
            
            isMatch = strcmp({S.Name}, varName);
            updateFcnName = S(isMatch).UpdateFunctionName;
            
            % Create function call for variable:
            updateFcn = str2func(updateFcnName);
            defaultValue = updateFcn();
            expectedDataType = class(defaultValue);

            updatedValues = cell(numSessions, 1);
            skippedRowInd = [];
            
            if reset
                [updatedValues{:}] = deal(updateFcn());
            else
                
                wasWarned = false;

                for iSession = 1:numSessions
                    try % Todo: Use error handling here. What if some conditions can not be met...
                        newValue = updateFcn(sessionObj(iSession));

                        if isa(newValue, 'nansen.metadata.abstract.TableVariable')
                            if isequal(newValue.Value, newValue.DEFAULT_VALUE)
                                return
                            else
                                newValue = newValue.Value;
                            end
                        end

                        if isa(newValue, 'string'); newValue = char(newValue); end % Table does not accept strings
                        % if ischar(newValue); newValue = {newValue}; end % Need to put char in a cell. Should use strings instead, but that's for later

                        % Currently, only three data types are accepted,
                        % numerics, cell array of character vector and
                        % logicals

                        isValid = false;

                        if isa(defaultValue, 'double')
                            if isnumeric(newValue)
                                updatedValues{iSession} = newValue;
                                isValid = true;
                            end
                        elseif isa(defaultValue, 'logical')
                            if islogical(newValue)
                                updatedValues{iSession} = newValue;
                                isValid = true;
                            end
                        elseif isequal(defaultValue, {'N/A'}) || isequal(defaultValue, {'<undefined>'}) % Character vectors should be in a scalar cell
                            expectedDataType = 'character vector or a scalar cell containing a character vector';
                            if iscell(newValue) && numel(newValue)==1 && ischar(newValue{1})
                                updatedValues{iSession} = newValue{1};
                                isValid = true;
                            elseif isa(newValue, 'char')
                                updatedValues{iSession} = newValue;
                                isValid = true;
                            end
                        elseif isa(defaultValue, 'struct')
                            if isstruct(newValue)
                                updatedValues{iSession} = newValue;
                                isValid = true;
                            end
                        elseif isa(defaultValue, 'categorical')
                            if  isa(newValue, 'categorical')
                                updatedValues{iSession} = newValue;
                                isValid = true;
                            end

                        else
                            % Invalid;
                        end

                        if ~isValid
                            skippedRowInd = [skippedRowInd, iSession]; %#ok<AGROW>
                            if ~wasWarned
                                warningMessage = sprintf('The table variable function returned something unexpected.\nPlease make sure that the table variable function for "%s" returns a %s.', varName, expectedDataType);
                                app.MessageDisplay.warn(warningMessage, 'Title', 'Update failed')
                                wasWarned = true;
                                ME = MException('Nansen:TableVar:WrongType', warningMessage);
                            end
                        end

                    catch ME
                        skippedRowInd = [skippedRowInd, iSession]; %#ok<AGROW>
                    end

                    if numSessions > 5
                        waitbar(iSession/numSessions, h)
                    end
                end
            end
            
            updatedValues(skippedRowInd) = [];
            rows(skippedRowInd) = [];
            
            if ~isempty(skippedRowInd)
                objectIDs = app.getObjectId(sessionObj(skippedRowInd));
                objectIDsAsText = strjoin(objectIDs, newline);
                messageStr = sprintf( 'Failed to update %s for the following %ss:\n\n%s\n', varName, lower(tableType), objectIDsAsText);
                errorMessage = sprintf('\nThe following error message was caught:\n%s', ME.message);
                app.MessageDisplay.alert([messageStr, errorMessage], "Title", 'Update failed')
            end
            
            if isempty(rows); return; end
            
            % Update values in the metatable..
            app.MetaTable.editEntries(rows, varName, updatedValues);

            % Need to keep selected entries before refreshing table.
            if numSessions < 20
                % Unfortunately, this is very slow for many rows.
                colIdx = find(strcmp(app.MetaTable.entries.Properties.VariableNames, varName));

                % Need to insert formatted table data in the MetaTable
                % viewer
                updatedValuesDisplay = app.MetaTable.getFormattedTableData(colIdx, rows);
                updatedValuesDisplay = table2cell(updatedValuesDisplay);
                app.UiMetaTableViewer.updateCells(rows, colIdx, updatedValuesDisplay)
                
            else % Update whole table
                selectedEntries = app.UiMetaTableViewer.getSelectedEntries();
            
                app.UiMetaTableViewer.refreshTable(app.MetaTable)
            
                % Make sure selection is preserved.
                app.UiMetaTableViewer.setSelectedEntries(selectedEntries);
            end

            if numSessions > 5 && ~reset
                delete(h)
            end
        end

        function copySessionIdToClipboard(app)
            itemObject = app.getSelectedMetaObjects();
            itemID = app.getObjectId(itemObject);
            
            itemID = cellfun(@(id) sprintf('''%s''', id), itemID, 'uni', 0);
            itemIDStr = strjoin(itemID, ', ');
            clipboard('copy', itemIDStr)
        end

        function copyTableValuesToClipboard(app, ~, ~)
            % Not implemented yet.
            %
            % Not clear how to get the selected column index, as this is
            % currently not accessible from any property.
            selectedEntries = app.UiMetaTableViewer.getSelectedEntries(); %#ok<NASGU>
        end

        function removeSessionFromTable(app)
            selectedEntries = app.UiMetaTableViewer.getSelectedEntries();
            app.MetaTable.removeEntries(selectedEntries)
            app.UiMetaTableViewer.refreshTable(app.MetaTable)
        end

        function openDataLocationEditor(app)
        %openDataLocationEditor Open editor app for datalocation model.
                    
            args = {'DataLocationModel', app.DataLocationModel};
    
            % Open app by creating new instance or showing previous
            if isempty(app.DLModelApp) || ~app.DLModelApp.Valid
                hApp = nansen.config.dloc.DataLocationModelApp(args{:});
                hApp.transferOwnership(app)
                app.DLModelApp = hApp;
                
                addlistener(hApp, 'DataLocationModelChanged', ...
                    @app.onDataLocationModelChanged);
                
            else
                app.DLModelApp.Visible = 'on';
            end
        end

        function openVariableModelEditor(app)
        %openVariableModelEditor Open editor app for variable model.
                    
            args = {'VariableModel', app.VariableModel, ...
                'DataLocationModel', app.DataLocationModel};
    
            % Open app by creating new instance or showing previous
            if isempty(app.VariableModelApp) || ~app.VariableModelApp.Valid
                hApp = nansen.config.varmodel.VariableModelApp(args{:});
                hApp.transferOwnership(app)
                app.VariableModelApp = hApp;
                
                % Add listener for when the model is changed.
                addlistener(hApp, 'VariableModelChanged', ...
                    @app.onVariableModelChanged);
                
            else
                % app.VariableModel.load()
                app.VariableModelApp.Visible = 'on';
            end
        end

        function openModuleManager(app)

            % Get current project
            p = app.ProjectManager.getCurrentProject();
            dataModules = p.Preferences.DataModule;

            persistent hApp
            if isempty(hApp) || ~isvalid(hApp) || ~hApp.Valid
                hApp = nansen.config.module.ModuleManagerApp(dataModules);
                hApp.transferOwnership(app)
                % hApp.changeWindowStyle('modal')
                addlistener(hApp, 'ModuleSelectionChanged', @app.onModuleSelectionChanged);
            else
                hApp.setSelectedModules(dataModules)
                hApp.Visible = 'on';
            end
        end

        function onConfigureDatalocationRootMenuClicked(app, src, ~)
            
            import nansen.dataio.dialog.editDataLocationRootDeviceName
            
            % - Get selected item from data location model
            dataLocationName = src.Text;
            dlIdx = app.DataLocationModel.getItemIndex(dataLocationName);
            rootConfig = app.DataLocationModel.Data(dlIdx).RootPath;

            % - Update data location model
            updatedRootConfig = editDataLocationRootDeviceName(rootConfig);
            app.DataLocationModel.modifyDataLocation(dataLocationName, ...
                'RootPath', updatedRootConfig);
            app.DataLocationModel.save()
            
            % - Update data location structs
            app.updateDataLocationFromModel()

            % - Refresh table on these events
            app.refreshTable()
        end

        function removeTableVariable(app, src, ~)
        %removeTableVariable Remove variable from the session table
            
            if ischar(src)
                varName = src;
            else
                varName = src.Text;
            end

            question = sprintf( ['This will delete the data of column ', ...
                '%s from the table. The associated tablevar function ', ...
                'will also be deleted. Are you sure you want to continue?'], ...
                varName );
            title = 'Delete data?';
            answer = app.MessageDisplay.ask(question, 'Title', title);

            switch answer
                case {'No', 'Cancel', ''}
                    return
                case 'Yes'
                    % Continue
            end
            
            app.MetaTable.removeTableVariable(varName)
            app.UiMetaTableViewer.refreshTable(app.MetaTable)

            tableType = app.MetaTable.getTableType();
            
            % Delete function template in project folder..
            pathStr = nansen.metadata.utility.getTableVariableUserFunctionPath(varName, tableType);
            if isfile(pathStr)
                % Make sure deleted table variable functions end up in the
                % recycling bin. No fun to permanently (accidentally)
                % delete an advanced table variable!
                state = recycle('on');
                delete(pathStr);
                recycle(state)
            end
            
            % Refresh session context menu...
            app.updateSessionInfoDependentMenus()
        end
        
        function refreshTable(app)
            returnToIdle = app.setBusy('Updating table'); %#ok<NASGU>
            hDlg = app.MessageDisplay.inform('Please wait, updating table...');
            resetView = false;
            app.UiMetaTableViewer.resetTable(resetView)
            app.onNewMetaTableSet()
            if isvalid(hDlg); delete(hDlg); end
        end
        
        function onMetaTableModifiedChanged(app, ~, evt)
            if app.settings.MetadataTable.AutosaveMetaTable
                if evt.AffectedObject.IsModified
                    app.saveMetaTable()
                end
            end
        end
        
        function metaTable = updateDataLocationFromModel(app, metaTable)
        %updateDataLocationFromModel Update dataLocations in meta table
        %
        % Make sure all data location entries in the metatable matches the
        % configurations in the data location model.
            if nargin < 2
                metaTable = app.MetaTable;
            end

            if any(strcmp(metaTable.entries.Properties.VariableNames, 'DataLocation'))
                dataLocationStructs = metaTable.entries.DataLocation;
                dataLocationStructs = app.DataLocationModel.validateDataLocationPaths(dataLocationStructs);
                metaTable.entries.DataLocation = dataLocationStructs;
                metaTable.markClean() % This change does not make the table dirty.
            end

            if nargin < 2 && ~nargout
                app.MetaTable = metaTable;
                clear metaTable
            end
        end
        
        function openMetaTable(app, metaTableName)
        % openMetaTable - Open a metatable with the given name

            % Get selected metatable item from the metatable catalog
            MTC = app.CurrentProject.MetaTableCatalog;
            mtItem = MTC.getEntry(metaTableName);

            % Create metatable filepath
            rootDir = fileparts(MTC.FilePath);
            mtFilePath = fullfile(rootDir, mtItem.FileName);
            
            if ~contains(mtFilePath, '.mat')
                mtFilePath = strcat(mtFilePath, '.mat');
            end
            
            returnToIdle = app.setBusy('Opening table...'); %#ok<NASGU>

            app.loadMetaTable(mtFilePath)
        end

        function loadMetaTable(app, loadPath)
            
            if nargin < 2 || isempty(loadPath)
                MTC = app.CurrentProject.MetaTableCatalog;
                loadPath = MTC.getDefaultMetaTablePath();

                subjectTableExists = app.checkIfSubjectTableExists(MTC);
                if ~subjectTableExists
                    nansen.config.initializeSubjectTable(MTC)
                end
            end
            
            if isempty(loadPath)
                projectName = app.ProjectManager.CurrentProject;
                if app.isInitialized()
                    message = sprintf('The configuration of the current project (%s) is not completed (metatable is missing)', projectName);
                    title = 'Aborted';
                    app.MessageDisplay.alert(message, 'Title', title)
                else
                    delete(app)
                end
                error('Nansen:ProjectNotConfigured:MetatableMissing', ...
                    'Can not start nansen because project "%s" is not configured.', projectName)
            end
            
            % Ask user to save current database (if any is open)
            if ~isempty(app.MetaTable)
                wasCanceled = app.promptToSaveCurrentMetaTable();
                if wasCanceled; return; end
            end
            
            try
                % Load existing or create new experiment inventory
                if isfile(loadPath)
                    metaTable = nansen.metadata.MetaTable.open(loadPath);
                else % Todo: do i need this...?
                    metaTable = nansen.metadata.MetaTable;
                end
                
                % Checks if metatable matches with custom table variables
                metaTable.checkIfMetaTableComplete("MessageDisplay", app.MessageDisplay)

                
                % Temp fix. Todo: remove
                metaTable = nansen.metadata.temp.fixMetaTableDataLocations(metaTable, app.DataLocationModel);
                metaTable = nansen.metadata.temp.fixDataLocationSubfolders(metaTable);

                % Temp fix. Todo: remove
                if any(strcmp(metaTable.entries.Properties.VariableNames, 'Data'))
                    metaTable.removeTableVariable('Data')
                end
                
                % Update data location paths based on the local
                % DataLocation model and make sure paths are according to
                % operating system.
                metaTable = app.updateDataLocationFromModel(metaTable);

                app.MetaTable = metaTable;

                addlistener(app.MetaTable, 'IsModified', 'PostSet', ...
                    @app.onMetaTableModifiedChanged);
                                
% %                 if app.isInitialized() % Todo: implement this
% %                     app.updateRelatedInventoryLists()
% %                 end
            catch ME
                titleStr = 'Could Not Load Session Table'; % Todo: generalize string, i.e session should depend on current table type
                app.MessageDisplay.alert(ME.message, "Title", titleStr)
                disp(getReport(ME, 'extended'))
            end
            
            % Add name of loaded inventory to figure title
            if ~isempty(app.Figure)
                app.updateFigureTitle();
            end
            
            app.updateMetaTableMenu()
        end
        
        function saveMetaTable(app, ~, ~, forceSave)
            
            if nargin < 4; forceSave = false; end

            if app.settings.MetadataTable.AllowTableEdits
                wasSaved = app.MetaTable.save(forceSave);
                
                if wasSaved
                    app.StatusText.Status = sprintf('Status: Saved metadata table to %s', app.MetaTable.filepath);
                    app.clearStatusIn(5)
                end
            else
                error('Can not save metatable because access is read only')
            end
        end
        
        function reloadMetaTable(app)
            currentTablePath = app.MetaTable.filepath;
            app.loadMetaTable(currentTablePath)
        end
        
        function metatable = createMetaTable(app, ~, ~)
            
            metatable = [];
            currentTableClass = class(app.MetaTable);
            if ~strcmp(currentTableClass, 'nansen.metadata.type.Session') %#ok<STISA>
                errordlg(sprintf('This operation is not supported for tables with "%s" items yet...', currentTableClass))
                return
            end

            S = struct();
            S.MetaTableName = '';
            S.MakeDefault = false;
            S.AddSelectedSessions = true;
            S.OpenMetaTable = true;
            
            [S, wasAborted] = tools.editStruct(S, [], 'New Metatable Collection', 'Prompt', 'Configure new metatable');
            if wasAborted; return; end
            
            if isempty(S.MetaTableName)
                errordlg('Please enter a name to create a new metatable...')
                return
            end

            S_ = struct;
            S_.MetaTableName = S.MetaTableName;
            S_.IsDefault = S.MakeDefault;
            S_.IsMaster = false;
            S_.SavePath = app.CurrentProject.getProjectPackagePath('Metadata Tables');
                        
            metaTableCatalog = app.CurrentProject.MetaTableCatalog;
            catalogTable = metaTableCatalog.Table;
            isMaster = catalogTable.IsMaster;
            
            S_.MetaTableIdVarname = catalogTable{isMaster, 'MetaTableIdVarname'}{1};
            S_.MetaTableKey = catalogTable{isMaster, 'MetaTableKey'}{1};
            S_.MetaTableClass = catalogTable{isMaster, 'MetaTableClass'}{1};
            
            metatable = nansen.metadata.MetaTable();
            metatable.archive(S_)
            
            if S.AddSelectedSessions
                sessionEntries = app.getSelectedMetaObjects;
                if ~isempty(sessionEntries)
                    metatable.addEntries(sessionEntries)
                    metatable.save()
                end
            end
            
            if S.OpenMetaTable
                app.loadMetaTable(metatable.filepath)
            end
            
            app.updateRelatedInventoryLists()
            
            if ~nargout
                clear metatable
            end
        end

        function tf = checkIfSubjectTableExists(~, metaTableCatalog)
            % Todo: should not be a nansen.App method, project level...
            existingClasses = unique( metaTableCatalog.Table.MetaTableClass );
            % Todo: generalize, i.e are there subclasses (project specific subject definitions?)
            tf = any(strcmp(existingClasses, 'nansen.metadata.type.Subject'));
        end
    end
    
    methods (Access = protected) % Callbacks

        % onSettingsChanged Callback for change of fields in settings
        function onSettingsChanged(app, name, value)
            
            switch name
                
                case 'ShowIgnoredEntries'
                    app.settings_.MetadataTable.(name) = value;
                    
                    selectedEntries = app.UiMetaTableViewer.getSelectedEntries();
                    app.UiMetaTableViewer.ShowIgnoredEntries = value;
                    
                    % Make sure selection is preserved.
                    app.UiMetaTableViewer.setSelectedEntries(selectedEntries);
                    
                case 'AllowTableEdits'
                    app.settings_.MetadataTable.(name) = value;
                    app.UiMetaTableViewer.AllowTableEdits = value;
                    
                case {'TimerPeriod', 'RunTasksWhenQueued', 'RunTasksOnStartup'}
                    app.settings_.TaskProcessor.(name) = value;
                    app.BatchProcessor.(name) = value;

                case 'TableFontSize'
                    try
                        app.UiMetaTableViewer.TableFontSize = value;
                        app.settings_.MetadataTable.(name) = value;
                    catch
                        % Need to reset value in structeditor.
                    end
            end
        end
        
        function onNewMetaTableSet(app)
            if isempty(app.UiMetaTableViewer);    return;    end
            app.UiMetaTableViewer.refreshColumnModel()
            if ~strcmpi(app.UiMetaTableViewer.MetaTableType, app.MetaTable.getTableType())
                % If table type is changed, use the flush option.
                app.UiMetaTableViewer.refreshTable(app.MetaTable, true)
            else
                app.UiMetaTableViewer.refreshTable(app.MetaTable)
            end
        end
        
        function onFileViewerSessionChanged(app, sessionID)
            
            % Row index for session.

            isRow = strcmp( app.MetaTable.entries.sessionID, sessionID);
            
            entry =  app.MetaTable.entries(isRow, :);
            metaObj = app.tableEntriesToMetaObjects(entry);
            app.UiFileViewer.update(metaObj)
        end

        function onSessionTaskSelected(app, ~, evt)
        %onSessionTaskSelected Callback for event on session task menu.
        %
        % This function prepares tasks to run based on the selected method
        % from the session task menu, the selected sessions from the
        % session table and the selected mode for running the task.
        %
        %
        %   Supported modes:
        %       q   - add task(s) the the task processor's queue.
        %       e   - edit session method function
        %       ... - preview options for method

            % Todo: Implement saving or errors to a log file. (right now,
            % in most cases it is available in the task processor's
            % history)
            
            % If the edit mode was selected, open the function file for
            % editing and return.
            if strcmp(evt.Mode, 'Edit')
                edit( evt.TaskAttributes.FunctionName )
                app.SessionTaskMenu.Mode = 'Default'; % Reset menu mode
                return
            elseif strcmp(evt.Mode, 'Help')
                help(evt.TaskAttributes.FunctionName)
                applify.helpDialog(evt.TaskAttributes.FunctionName)
                return
            end

            if strcmp(evt.Mode, 'Preview')
                if isempty( app.UiMetaTableViewer.getSelectedEntries )
                    % Just edit options for this method.
                    % optsName = evt.OptionsSelection;
                    optsManager = evt.TaskAttributes.OptionsManager;
                    optsManager.editOptions()
                    return
                end
            end
            
            % Throw error if no sessions are selected.
            app.assertSessionSelected()
            
            % Note: If the task(s) should be added to the queue, the
            % session objects need to be uncached. This is because the
            % cache can be cleared, and when the cache is cleared the
            % session objects will become invalid. Thus the tasks in the
            % task list would also be corrupt/unrunnable.
            if strcmp(evt.Mode, 'TaskQueue')
                useSessionObjectCache = false;
            else
                useSessionObjectCache = true;
            end
            
            % Get the session objects that are selected in the metatable
            sessionObj = app.getSelectedMetaObjects(useSessionObjectCache);

            % Get the function name
            functionName = evt.TaskAttributes.FunctionName;
            returnToIdle = app.setBusy(functionName); %#ok<NASGU>
                           
            app.SessionTaskMenu.Mode = 'Default'; % Reset menu mode
            drawnow

            % Check if session task should be run in serial or batch
            isSerial = strcmp(evt.TaskAttributes.BatchMode, 'serial');
            
            % Place session objects in a cell array based on batch mode. If
            % mode is serial, each cell holds one session, and if mode is
            % batch, one cell holds all session objects
            if isSerial
                sessionObj = arrayfun(@(sObj) sObj, sessionObj, 'uni', 0);
            else
                sessionObj = {sessionObj};
            end

            % Todo: Add attribute for maximum number of sessions and check
            % if the maximum number of sessions for this method is exceeded.

            % Get the correct optionsSet if a preset optionsSet was
            % selected. If evt.OptionsSelection is empty, the default is
            % retrieved
            optsName = evt.OptionsSelection;
            optsManager = evt.TaskAttributes.OptionsManager;
            [opts, optsName] = optsManager.getOptions(optsName);
            
            % Prepare a struct holding task configurations.
            taskConfiguration = struct;
            taskConfiguration.Method = evt.TaskAttributes.FunctionHandle;
            taskConfiguration.Mode = evt.Mode;
            taskConfiguration.SessionObject = [];
            taskConfiguration.Options = opts;
            taskConfiguration.OptionsName = optsName;
            taskConfiguration.Alternative = evt.Alternative;
            taskConfiguration.Restart = strcmp(evt.Mode, 'Restart');
            taskConfiguration.TaskAttributes = evt.TaskAttributes;
            
            % Go through cell array of session objects and initialize tasks
            numTasks = numel(sessionObj);

            % Only edit options once when multiple sessions are selected if
            % this is specified in preferences.
            if strcmp(evt.Mode, 'Preview') && numTasks > 1 && ...
                   strcmp( app.settings.Session.OptionEditMode, 'Only once' )
                optsManager = evt.TaskAttributes.OptionsManager;
                [optsName, optsStruct, wasAborted] = optsManager.editOptions();
                if wasAborted; return; end
                taskConfiguration.Options = optsStruct;
                taskConfiguration.OptionsName = optsName;
                evt.Mode = 'Default';
                taskConfiguration.Mode = 'Default';
            end

            for i = 1:numTasks

                % Update the status field
                app.updateStatusText(i-1, numTasks, taskConfiguration.Method)

                taskConfiguration.SessionObject = sessionObj{i};

                % Call the appropriate method based on the selected mode
                switch evt.Mode
                    case {'Default', 'Restart'}
                        app.runTasksWithDefaults(taskConfiguration)
    
                    case 'Preview'
                        app.runTasksWithPreview(taskConfiguration)
    
                    case 'TaskQueue'
                        app.addTasksToQueue(taskConfiguration)
                end
            end
        end
        
        function runTasksWithDefaults(app, taskConfiguration)
        %runTasksWithDefaults Run session method with default options
            
        %    Method         : Function handle of method to run
        %    SessionObject  : Array of session objects;
        %    Options        : Struct of options to use
        %    OptionsName    : Name of options
        %    Alternative    : Optional, for methods with multiple alternatives
        %    Restart        : Boolean flag, true if method should be restarted

            % Unpack variables from input struct:
            sessionMethod = taskConfiguration.Method;
            sessionObj = taskConfiguration.SessionObject;
            opts = taskConfiguration.Options;

            taskName = app.createTaskName( sessionObj );

            newTask = app.BatchProcessor.createTaskItem(taskName, ...
                sessionMethod, 0, {sessionObj}, 'Default', 'Command window task');

            % cleanupObj makes sure temp logfile is deleted later
            [cleanUpObj, logfile] = app.BatchProcessor.initializeTempDiaryLog(); %#ok<ASGLU>
            
            newTask.timeStarted = datetime("now");

            % Prepare arguments for the session method
            % app.prepareSessionMethodArguments() % Todo: Create prepareSessionMethodArguments function
            
            methodArgs = {sessionObj, opts};
            if ~isempty(taskConfiguration.Alternative)
                methodArgs = [methodArgs, {'Alternative', taskConfiguration.Alternative}];
            end

            % Run the task
            if app.settings.Session.SessionTaskDebug % make debug mode instead of having it as a preference?
                sessionMethod(methodArgs{:});
            else
                taskType = taskConfiguration.TaskAttributes.TaskType;
                try
                    switch taskConfiguration.Mode
                        case 'Default'
                            sessionMethod(methodArgs{:});
                        case 'Restart'
                            app.runTaskWithReset(sessionMethod, taskType, methodArgs)
                        case 'Preview'
                            % Todo: Add
                    end

                    if numel(sessionObj) == 1 && ismethod(sessionObj, 'updateProgress')
                        % Methods which accept multiple session are not
                        % (should not) be included in pipelines...
                        sessionObj.updateProgress(sessionMethod, 'Completed')
                    end

                    newTask.status = 'Completed';
                    diary off
                    newTask.Diary = fileread(logfile);
                    app.BatchProcessor.addCommandWindowTaskToHistory(newTask)

                catch ME
                    newTask.status = 'Failed';
                    diary off
                    newTask.Diary = fileread(logfile);
                    newTask.ErrorStack = ME;
                    app.BatchProcessor.addCommandWindowTaskToHistory(newTask)
                    app.throwSessionMethodFailedError(ME, taskName, ...
                        func2str(sessionMethod))
                end
            
                clear cleanUpObj
            end
        end

        function runTaskWithReset(~, sessionMethod, taskType, methodArgs)

            switch taskType
                case 'class'
                    sMethod = sessionMethod(methodArgs{:});
                    sMethod.RedoIfCompleted = true;
                    sMethod.runMethod()
                case 'function'
                    sessionMethod(methodArgs{:});
                    warning('Session method does not have reset mode')
            end
        end

        function runTasksWithPreview(app, taskConfiguration)
            
            % Todo: Move some of this to a separate method, similar to
            % runTaskWithReset. Can get rid of some duplicate code, and
            % also add as task to the taskprocessor using the
            % runTasksWithDefaults method...

            % Unpack variables from input struct:
            sessionMethod = taskConfiguration.Method;
            sessionObj = taskConfiguration.SessionObject;
            opts = taskConfiguration.Options;
            optsName = taskConfiguration.OptionsName;
            
            taskType = taskConfiguration.TaskAttributes.TaskType;
            functionName = taskConfiguration.TaskAttributes.FunctionName;

            try
                taskName = app.createTaskName( sessionObj );
                % Open the options / method in preview mode
                if strcmp(taskType, 'class')
                    sMethod = sessionMethod(sessionObj);
                    sMethod.usePreset(optsName)

                    isSuccess = sMethod.preview();
                    wasAborted = ~isSuccess;
                    
                    if isSuccess
                        sMethod.run()
                    else
                        return
                    end

                    % Update session task menu (in case new options were defined...)
                    app.SessionTaskMenu.refresh()
                        
                    % functionName = taskConfiguration.TaskAttributes.FunctionName;
                    % app.SessionTaskMenu.refreshMenuItem(functionName) % todo
    
                    % Todo: Only refresh this submenu.
                    % Todo: Only refresh if options sets were added.

                elseif strcmp(taskType, 'function')
                    
                    if isempty(fieldnames(opts))
                        message = 'This method does not have any parameters';
                        app.MessageDisplay.warn(message)
                        wasAborted = true;
                    else
                        optManager = taskConfiguration.TaskAttributes.OptionsManager;
                        % optManager = nansen.manage.OptionsManager(functionName, opts, optsName);
                        [~, opts, wasAborted] = optManager.editOptions(optsName, opts);
                    end

                    if ~wasAborted
                        methodArgs = {sessionObj, opts};
                        if ~isempty(taskConfiguration.Alternative)
                            methodArgs = [methodArgs, ...
                                {'Alternative', taskConfiguration.Alternative}];
                        end
                        sessionMethod(methodArgs{:});
                    else
                        return
                    end
                end

                if numel(sessionObj) == 1 && ~wasAborted
                    % Methods which accept multiple session are not
                    % (should not) be included in pipelines...
                    if ismethod(sessionObj, 'updateProgress')
                        sessionObj.updateProgress(sessionMethod, 'Completed')
                    end
                end

            catch ME
                app.throwSessionMethodFailedError( ME, taskName, ...
                    functionName )
            end
        end
        
        function addTasksToQueue(app, taskConfiguration)
            
            % Todo:
            %   [ ] try/catch
            %   [ ] if session method - should run a "validation" method

            if isempty(app.BatchProcessor)
                app.BatchProcessor = nansen.TaskProcessor;
            end
                        
            % Unpack variables from input struct:
            sessionMethod = taskConfiguration.Method;
            sessionObj = taskConfiguration.SessionObject;
            opts = taskConfiguration.Options;
            optsName = taskConfiguration.OptionsName;

            % Get/create task name
            taskName = app.createTaskName( sessionObj );
            
            % Todo: Make preliminary test to check if method will run,
            % i.e check required variables
            
            % Prepare input args for function (session object and
            % options)
            
            methodArgs = {sessionObj, opts};
            if ~isempty(taskConfiguration.Alternative)
                methodArgs = [methodArgs, {'Alternative', taskConfiguration.Alternative}];
            end

            % Add task to the queue / submit the job
            app.BatchProcessor.submitJob(taskName,...
                            sessionMethod, 0, methodArgs, optsName )
        end

        function taskName = createTaskName(app, sessionObjects)
                
            if numel(sessionObjects) > 1
                taskName = 'Multisession';
            else
                taskName = app.getObjectId(sessionObjects);
            end
        end

        function createBatchList2(app, mode)
            
            figName = sprintf( 'List of %s Tasks', mode);
            f = figure('MenuBar', 'none', 'Name', figName, 'NumberTitle', 'off', 'Visible', 'off');
            % h = nansen.TaskProcessor('Parent', f)
            
            h = nansen.uiwTaskTable('Parent', f, ...
                'ColumnNames', {'SessionID', 'MethodName', 'Parameters', 'Comment'}, ...
                'ColumnEditable', [false, false, false, true] );
            
            sessionObjects = app.getSelectedMetaObjects();
            count = 0;
            
            for i = 1:numel(sessionObjects)
                
                pipelineObj = nansen.pipeline.Pipeline(sessionObjects(i).Progress);
                
                taskList = pipelineObj.getTaskList(mode);
                
                for j = 1:numel(taskList)
                    
                    newTaskDisplay = struct();
                    newTaskDisplay.SessionID = sessionObjects(i).sessionID;
                    newTaskDisplay.MethodName = taskList(j).TaskName;
                    newTaskDisplay.Parameters = taskList.OptionsName;
                    newTaskDisplay.Comment = '';
                    newTaskDisplay = struct2table(newTaskDisplay, 'AsArray', true);
                    
                    % Add the task to the uitable.
                    h.addTask(newTaskDisplay, 'end')
                    
                    count = count+1;
                    if count == 1
                        f.Visible = 'on';
                    end
                end
            end
            
            if count == 0
                close(f)
                message = 'No tasks were found';
                app.MessageDisplay.inform(message)
            end
        end
        
        function createBatchList(app, mode)
            
            sessionObjects = app.getSelectedMetaObjects();
            
            taskList = struct.empty;
            
            for i = 1:numel(sessionObjects)

                thisTaskList = nansen.pipeline.getPipelineTaskList(...
                    sessionObjects(i).Progress, mode);
                
                if isempty(thisTaskList)
                    continue;
                end
                
                [thisTaskList(:).SessionID] = deal( sessionObjects(i).sessionID );
                [thisTaskList(:).Comment] = deal( '' );
                
                if isempty(taskList)
                    taskList = thisTaskList;
                else
                    taskList = cat(1, taskList, thisTaskList);
                end
            end
            
            if ~isempty(taskList)
                h = nansen.pipeline.TaskBatchViewer(taskList, sessionObjects);
                if strcmp(mode, 'Queuable')
                    h.BatchProcessor = app.BatchProcessor;
                    h.Margins = [15,60,15,15];
                    h.SelectionMode = 'discontiguous';
                end
                uim.utility.layout.centerObjectInRectangle(h, app.Figure)
            else
                message = 'No tasks were found';
                app.MessageDisplay.inform(message)
            end
        end
        
        function openFolder(app, dataLocationName)
            
            sessionObj = app.getSelectedMetaObjects();

            for i = 1:numel(sessionObj)
                folderPath = sessionObj(i).getSessionFolder(dataLocationName);
                utility.system.openFolder(folderPath)
            end
        end
        
        function sendToWorkspace(app)
                    
            sessionObj = app.getSelectedMetaObjects();

            if ~isempty(sessionObj) % Todo: Resolve varName more flexibly
                if strcmp( app.UiMetaTableSelector.CurrentSelection, 'Session' )
                    varName = app.settings.Session.SessionObjectWorkspaceName;
                else
                    varName = app.UiMetaTableSelector.CurrentSelection;
                end

                assignin('base', lower(varName), sessionObj)
            end
        end
    end
    
    methods (Access = private) % Menu Callbacks
        %% Menu callbacks - Project
        function menuCallback_NewProject(app, src, ~)
        % Menu callback to let user add a new project
            import nansen.config.project.ProjectManagerUI

            switch src.Text
                case 'Create...'
                    % Todo: open setup from create project page
                    
                    question = ['This will close the current app and open ', ...
                        'nansen setup. Do you want to continue?'];
                    answer = app.MessageDisplay.ask(question, ...
                        'Title', 'Close and continue?');

                    switch answer
                        case 'Yes'
                            app.onExit(app.Figure)
                            nansen.app.setup.SetupWizard(["ProjectTab", "ModulesTab", "DataLocationsTab", "FolderHierarchyTab", "MetadataTab", "VariablesTab"])
                            return
                        otherwise
                            % Do nothing
                    end
                    
                case 'Add Existing...'
                    [success, projectName] = ProjectManagerUI().addExistingProject();
                    
                    if success
                        app.ProjectManager.loadCatalog() % reload
                        app.promptOpenProject(projectName)
                    end
            end
            
            app.updateProjectList()
        end

        function menuCallback_ChangeProject(app, src, ~)
        % Menu callback to let user change current project
            app.changeProject(src.Text)
        end
        
        function menuCallback_ManageProjects(app, ~, ~)
                       
            import nansen.config.project.ProjectManagerUI

            % Create the ProjectManagerApp
            hFigure = uifigure;
            hFigure.Position(3:4) = [699,229];
            hFigure.Name = 'Project Manager';
            uim.utility.layout.centerObjectInRectangle(hFigure, app.Figure)
            
            hProjectManagerUI = ProjectManagerUI(hFigure); %#ok<NASGU>
            
            listener(app.ProjectManager, 'CurrentProjectSet', @app.onProjectChanged);
            hFigure.WindowStyle = 'modal';
            uiwait(hFigure)
            
            % Note: Change to addlistener if not using uiwait.
            app.updateProjectList()
        end
        
        function menuCallback_OpenProjectFolder(app, ~, ~)
            project = app.ProjectManager.getProject(app.ProjectManager.CurrentProject);
            utility.system.openFolder(project.Path)
        end

        function menuCallback_ChangeCurrentFolder(app, src, ~)
            
            switch src.Text
                case 'Current Project'
                    cd(app.CurrentProject.FolderPath)
                case 'Nansen'
                    cd(nansen.toolboxdir)
            end
        end

        function menuCallback_CloseAll(app, ~, ~)
            state = get(app.Figure, 'HandleVisibility');
            set(app.Figure, 'HandleVisibility', 'off')
            close all
            set(app.Figure, 'HandleVisibility', state)
        end

        %% Menu callbacks - Metatable
        function menuCallback_DetectSessions(app, ~, ~)

            % Default to use the first datalocation or all?
            % dataLocationName = app.DataLocationModel.Data(1).Name;
            dataLocationName = 'all';
            newSessionObjects = nansen.manage.detectNewSessions(app.MetaTable, dataLocationName);
            
            if isempty(newSessionObjects)
                app.MessageDisplay.inform('No sessions were detected')
                return
            end
            
            % Initialize a MetaTable using the given session schema and the
            % detected session folders.
            tmpMetaTable = nansen.metadata.MetaTable.new(newSessionObjects);
            tmpMetaTable.addMissingVarsToMetaTable('session');
            
            % Find all that are not part of existing metatable
            app.MetaTable.appendTable(tmpMetaTable.entries)
            app.MetaTable.save()
            
            app.UiMetaTableViewer.refreshTable(app.MetaTable)
            
            message = sprintf('%d sessions were successfully added', numel(newSessionObjects));
            app.MessageDisplay.inform(message, 'Title', 'Success')
            % Display sessions that were added on the commandline
            fprintf('The following sessions were added: \n%s\n', strjoin({newSessionObjects.sessionID}, '\n'))
        
            MTC = app.CurrentProject.MetaTableCatalog;
            nansen.manage.updateSubjectTable(MTC);
        end

        function menuCallback_AddSessionToMetatable(app, src, ~)
            
            % Find session ids of currently highlighted rows
            sessionEntries = app.getSelectedMetaObjects;
            
            switch src.Text
                
                case 'New Metatable...'
                    % Add session to new database
                    metaTable = app.createMetaTable();
                    if isempty(metaTable); return; end % User canceled
                otherwise
                    MTC = app.CurrentProject.MetaTableCatalog;
                    metaTable = MTC.getMetaTable(src.Text);
            end

            metaTable.addEntries(sessionEntries)
            metaTable.save()
            
            if isvalid(src) % Might get deleted in MenuCallback_CreateMetaTable
                if strcmp( src.Text, 'New Metatable...')
                    app.updateRelatedInventoryLists()
                end
            end
        end

        function menuCallback_CreateMetaTable(app, ~, ~)
            app.createMetaTable();
        end
        
        function menuCallback_OpenMetaTable(app, src, ~)
            
            metaTableName = src.Text;
            app.openMetaTable(metaTableName)
        end

        function menuCallback_SetDefaultMetaTable(app, ~, ~)
            app.MetaTable.setDefault()
            app.updateRelatedInventoryLists()
        end
                
        function menuCallback_RefreshTable(app, ~, ~)
            app.refreshTable()
        end

        %% Menu callbacks - Session / item object
        function menuCallback_AddNewPipelineTask(app, ~, ~) %#ok<INUSD>
            
            % Open uidialog for creating new task
            %   name input
            %   function name input (search among all functions that are session methods...)
            %   options (update dropdown when function name is selected.
            
            % Get task catalog (from props?) and add new task

            % Make sure task catalog is up to date in other parts of app.
        end
        
        function menuCallback_CreateNewPipeline(app, ~, ~)
            % Open uidialog for creating new pipeline
            hUi = nansen.pipeline.uiCreatePipeline();
            if isempty(hUi); return; end
            
            uiwait(hUi.Figure)
            
            app.updateMenu_PipelineItems()
            
            % Todo: uiwait, and update pipeline names in menu for editing
            % pipelines.
        end
        
        function menuCallback_EditPipelines(app, src, ~)
        %menuCallback_EditPipelines - Lets user edit pipeline
            
            pipelineName = src.Text;
            pipelineModel = nansen.pipeline.PipelineCatalog();
            pipelineItemOrig = pipelineModel.getItem(pipelineName);
            hEditor = nansen.pipeline.uiEditPipeline(pipelineName);
            
            uiwait(hEditor)

            % Check if any changes were made.
            pipelineModel = nansen.pipeline.PipelineCatalog();
            pipelineItemNew = pipelineModel.getItem(pipelineName);
            if isequal(pipelineItemOrig, pipelineItemNew); return; end
            
            % Get the modified pipeline template.
            pipelineTemplate = pipelineModel.getPipelineForSession(pipelineName);
            
            % Get all pipeline structs from the metatable and update
            pipelineStructs = app.MetaTable.entries{:, 'Progress'};
            
            pipelineStructs = nansen.pipeline.updatePipelinesFromPipelineTemplate(...
                pipelineStructs, pipelineTemplate);
            
            % Update metatable entries
            app.MetaTable.editEntries(':', 'Progress', pipelineStructs)
            
            % Update uitable
            app.UiMetaTableViewer.refreshTable(app.MetaTable)
        end
        
        function menuCallback_ConfigurePipelineAssignment(app, ~, ~) %#ok<INUSD>
            nansen.pipeline.PipelineAssignmentModelApp()
        end

        function menuCallback_CreateTableMethod(app, metaTableType)
        % Menu callback for interactively creating a new table method.
            
            import nansen.session.methods.template.createNewSessionMethod
            
            % Get currently active table type if input is not specified
            if nargin < 2 || isempty(metaTableType)
                metaTableType = app.CurrentItemType;
            end
            
            groupNames = app.SessionTaskMenu.getRootLevelMenuNames();
            windowReferencePosition = app.Figure.Position;
            
            wasSuccess = createNewSessionMethod(metaTableType, ...
                "GroupNames", groupNames, ...
                "WindowReferencePosition", windowReferencePosition);
            
            % Update session menu!
            if wasSuccess
                app.SessionTaskMenu.refresh()
            end
        end

        function menuCallback_CreateFileAdapter(app)
            currentProject = app.ProjectManager.getCurrentProject();
            targetPath = currentProject.getFileAdapterFolder();
            
            [S, wasAborted] = nansen.module.uigetFileAdapterAttributes();
            if wasAborted
                return
            else
                nansen.module.createFileAdapter(targetPath, S)
            end
            % Todo: Trigger update?
        end
        
        function menuCallback_RefreshSessionMethod(app)
            app.SessionTaskMenu.refresh()
        end
        
        function menuCallback_CreateTableVariable(app)
            app.createTableVariable()
        end
        
        function menuCallback_ImportTableVariable(app)
            app.importTableVariable();
        end

        function menuCallback_ClearMemory(app, ~, ~)
            app.resetMetaObjectList()
        end
        
        function menuCallback_AssignPipelines(app, src, ~)
        %menuCallback_AssignPipelines Session context menu callback
            sessionObj = app.getSelectedMetaObjects();
            if strcmp(src.Text, 'No pipeline')
                sessionObj.unassignPipeline()
            elseif strcmp(src.Text, 'Autoassign pipeline')
                sessionObj.assignPipeline() % No input = pipeline is autoassigned
            else
                sessionObj.assignPipeline(src.Text)
            end
        end
        
        function contextMenuCallback_CreateNoteForItem(app)
        % Lets user interactively add a note for the currently selected item
            metaObject = app.getSelectedMetaObjects();
            itemID = app.getObjectId(itemObject);

            itemType = lower(app.CurrentItemType);
            noteObj = nansen.notes.Note.uiCreate(itemType, itemID);
            
            metaObject.addNote(noteObj)
        end

        function contextMenuCallback_ViewSessionNotes(app)
            
            sessionObj = app.getSelectedMetaObjects();
            
            noteArray = cat(2, sessionObj.Notebook );
            
            if isempty(app.NotesViewer) || ~app.NotesViewer.Valid
            % Todo: Save notesApp in nansen...
                hApp = nansen.notes.NoteViewerApp(noteArray);
                hApp.transferOwnership(app)
                
                app.NotesViewer = hApp;
            else
                app.NotesViewer.Visible = 'on';
                noteBook = nansen.notes.NoteBook(noteArray);
                app.NotesViewer.Notebook = noteBook;
            end

            % Todo: Add listeners??
        end
        
        function contextMenuCallback_RemoveSession(app)
            app.removeSessionFromTable()
        end

        %% Menu callbacks - Other
        function menuCallback_OpenFigure(app, packageName, figureName)
            
            % Create function call...
            fcn = figurePackage2Function(packageName, figureName);
            hFigure = fcn();
            
            tabNames = {app.hLayout.TabGroup.Children.Title};
            isFigureTab = strcmp(tabNames, 'Figures');
            hFigure.reparent(app.hLayout.TabGroup.Children(isFigureTab))
        end
    end
    
    methods (Access = private) % Saving/loading app states on exit
        
        function saveFigurePreferences(app)
                
                MP = get(0, 'MonitorPosition');
                nMonitors = size(MP, 1);
                
                if nMonitors > 1
                    ML = uim.utility.pos2lim(MP); % Monitor limits
                    figureLocation = app.Figure.Position(1:2);
                    
                    isOnScreen = all( figureLocation > ML(:, 1:2) & figureLocation < ML(:, 3:4) , 2);
                    currentScreenNum = find(isOnScreen);
                    
                    if ~isempty(currentScreenNum)
                        app.setPreference('PreferredScreen', currentScreenNum)
                    else
                        return;
                    end
                    
                    % Save the current position to the PreferredScreenPosition
                    prefScreenPos = app.getPreference('PreferredScreenPosition');
                    prefScreenPos{currentScreenNum} = app.Figure.Position;
                    app.setPreference('PreferredScreenPosition', prefScreenPos)
                else
                    prefScreenPos = app.getPreference('PreferredScreenPosition');
                    prefScreenPos{1} = app.Figure.Position;
                    app.setPreference('PreferredScreenPosition', prefScreenPos)
                end
                
                % Save preferences
                app.savePreferences();
            end
        
        function saveMetatableColumnSettingsToProject(app)
            if isempty(app.UiMetaTableViewer); return; end
            columnSettings = app.UiMetaTableViewer.ColumnSettings;
            currentProjectName = app.ProjectManager.CurrentProject;
            projectObj = app.ProjectManager.getProjectObject(currentProjectName);

            projectObj.saveData('MetatableColumnSettings', columnSettings, 'SaveToJson', true)
        end

        function columnSettings = loadMetatableColumnSettingsFromProject(app)

            currentProjectName = app.ProjectManager.CurrentProject;
            projectObj = app.ProjectManager.getProjectObject(currentProjectName);

            columnSettings = projectObj.loadData('MetatableColumnSettings', "LoadFromJson", true);
        end
    end

    methods (Access = private) % Methods for information, warning and error messages
        %% User dialog - Asking user for choice or confirmation
        function wasCanceled = promptToSaveCurrentMetaTable(app)
        %promptToSaveCurrentMetaTable Ask user to save current metatable
        %
        %   wasCanceled = promptToSaveCurrentMetaTable(app)
        
            wasCanceled = false;
            
            % Return if there are no unsaved changes
            if app.MetaTable.isClean
                return
            end
            
            currentProjectName = app.ProjectManager.CurrentProject;

            % Prepare inputs for the question dialog
            question = sprintf(['The session table for project "%s" has ', ...
                'unsaved changes. Do you want to save changes to the ', ...
                'table?'], currentProjectName);

            answer = app.MessageDisplay.ask(question, ...
                'Title', 'Save changes to table?', ...
                'Alternatives', {'Save', 'Don''t Save', 'Cancel'}, ...
                'DefaultAnswer', 'Save');

            switch answer
                case 'Save'
                    app.saveMetaTable()
                case 'Don''t Save'
                    % Continue without saving (mark as clean to avoid
                    % entering current method again, i.e when changing
                    % project)
                    app.MetaTable.markClean()
                otherwise % Cancel or no answer.
                    wasCanceled = true;
                    return
            end
        end
        
        function doExit = promptQuitIfBusy(app)
            
            % Prepare inputs for the question dialog
            question = 'The app is busy with something. Do you want to quit anyway?';
            title = 'Confirm Quit?';

            answer = app.MessageDisplay.ask(question, ...
                'Title', title, ...
                'Alternatives', {'Yes', 'No'}, ...
                'DefaultAnswer', 'Yes');

            doExit = strcmp(answer, 'Yes');
        end
        
        %% User dialog - Display information, warning and error messages
        function throwSessionMethodFailedError(app, ME, taskName, methodName)
        % throwSessionMethodFailedError - Display error message if task fails
            if iscell(taskName)
                taskName = taskName{1};
            end
            errorMessage = sprintf([...
                'Method ''%s'' failed for session ''%s'', with the ', ...
                'following error:\n\n %s'], methodName, taskName, ME.message);
            
            app.MessageDisplay.alert(errorMessage)
            
            % Display error stack in command window to support debugging
            disp(getReport(ME, 'extended'))
        end
    
        %% Assertions
        function assertSessionSelected(app)
            entryIdx = app.UiMetaTableViewer.getSelectedEntries();
            
            if isempty(entryIdx)
                message = 'No sessions are selected. Select one or more sessions for this operation.';                                
                app.MessageDisplay.inform(message, 'Title', 'Session Selection Required')
            end
        end
    end
       
    methods (Access=protected) % Override display methods
        %% Display Customization
        function propGroup = getPropertyGroups(app) %#ok<MANU>
            
            titleTxt = ['Nansen Properties: '...
                '(<a href = "matlab: helpPopup nansen.App">'...
                'Nansen Documentation</a>)'];
            thisProps = {
                'AppName'
                'Theme'
                'Modules'
                };
            propGroup = matlab.mixin.util.PropertyGroup(thisProps, titleTxt);
            
        end %function
    end
 
    methods (Static)
            
        S = getDefaultSettings() % Defined in external file

        function [tf, hApp] = isOpen()
        %ISOPEN Check if app figure is open bring to focus if it is.
        %
        %
            hApp = [];

            openFigures = findall(0, 'Type', 'Figure');
            if isempty(openFigures)
                tf = false;
            else
                figMatch = contains({openFigures.Name}, 'Nansen |');
                if any(figMatch)
                    matchedFigure = openFigures(figMatch);
                    hApp = getappdata(matchedFigure, 'AppInstance');
                    figure(matchedFigure) % Bring figure into focus
                    tf = true;
                else
                    tf = false;
                end
            end
        end

        function quit()
            openFigures = findall(0, 'Type', 'Figure');
            if isempty(openFigures)
                return
            else
                figMatch = contains({openFigures.Name}, 'Nansen |');
                if any(figMatch)
                    matchedFigure = openFigures(figMatch);
                    hApp = getappdata(matchedFigure, 'AppInstance');
                    hApp.onExit(matchedFigure)
                end
            end
        end

        function switchJavaWarnings(newState)
        %switchJavaWarnings Turn warnings about java functionality on/off
            warning(newState, 'MATLAB:ui:javaframe:PropertyToBeRemoved')
            warning(newState, 'MATLAB:ui:javacomponent:FunctionToBeRemoved')
        end

        function pathStr = getIconPath()
            % Set system dependent absolute path for icons.
            rootDir = utility.path.getAncestorDir(mfilename('fullpath'), 2);
            pathStr = fullfile(rootDir, 'resources', 'icons');
        end
    end

    methods (Static) % Not implemented
        function [jLabel, C] = showSplashScreen()
        % showSplashScreen - Show a splash window
            filepath = fullfile(nansen.toolboxdir, 'resources', ...
                'images', 'nansen_splash.png');

            if isfile(filepath)
                [~, jLabel, C] = nansen.ui.showSplashScreen(filepath, ...
                    'NAnSEn', 'Initializing nansen...');
            else
                error('Splashscreen is not implemented yet')
            end
        end
    end
end
