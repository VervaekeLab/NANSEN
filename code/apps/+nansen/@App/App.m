classdef App < uiw.abstract.AppWindow & nansen.mixin.UserSettings & ...
                    applify.HasTheme

    % Todo:
    %   [ ] Add a splash screen when this is starting up
    %   [ ] Make method for figure title name
    %   [ ] More methods/options for updating statusfield. Timers, progress
    %   [ ] Make sure that project directory is on path on startup or when
    %       project is changed...
    %   [ ] Create Menu in separate function.
    %   [ ] Update menu or submenu using call to that function
    %   [x] Remove vars from table on load if vars are not represented in
    %       tablevar folder.
    
    %   [v] Important: Load task list and start running it if preferences
    %       are set for that, even if gui is not initialized...
    %   [v] Keep track of session objects.
    %   [ ] Delete session objects from list and reset list when changing
    %       project.
    %   [ ] Send session object to task manager as a struct.
    %   [ ] Create a new session object in task manager when a task is
    %       started
    %   [ ] Todo: Create quit method
    %   [ ] If table is filtered, reset row selection. Also, update custom
    %       table status (updateCustomRowSelectionStatus).

    properties (Constant, Access=protected) % Inherited from uiw.abstract.AppWindow
        AppName char = 'Nansen'
    end
    
    properties (Constant, Hidden = true) % move to appwindow superclass
        DEFAULT_THEME = nansen.theme.getThemeColors('dark-gray');
    end
    
    properties (Constant)
        %Pages = {'Overview', 'File Viewer', 'Data Viewer', 'Task Processor'}%, 'Figures'}
        Pages = {'Overview', 'File Viewer', 'Task Processor'} %, 'Figures'}

    end
    
    properties % Page modules
        UiMetaTableViewer
        UiMetaTableSelector
        UiFileViewer
        UiDataViewer % Work in progress
        UiProcessor
    end
    
    properties
        NotesViewer % Auxiliary app, that we need to keep track of.
        DLModelApp % Auxiliary app, that we need to keep track of.
        VariableModelApp % Auxiliary app, that we need to keep track of.

        SchemaViewerApp
    end
    
    properties (Constant, Hidden = true) % Inherited from UserSettings
        USE_DEFAULT_SETTINGS = false % Ignore settings file                      Can be used for debugging/dev or if settings should be consistent.
        DEFAULT_SETTINGS = nansen.App.getDefaultSettings() % Struct with default settings
    end
    
    properties (Hidden, Access = private) % Window
        MinimumFigureSize
        IsIdle % todo: make dependent on app.ApplicationState
        TableIsUpdating = false
        TaskInitializationListener
        SessionTaskMenuUpdatedListener
    end

    properties (Access = private)
        MetaObjectMembers = {}
        MetaObjectList % Todo: should be map/dictionary with a key per table type. File viewer should be available independent of which table is currently active
    end

    properties
        MetaTablePath = ''
        MetaTable % Project
        
        BatchProcessor % UserSession?
        BatchProcessorUI
        
        SessionTasks matlab.ui.container.Menu
        SessionTaskMenu
        SessionContextMenu
        
        DataLocationModel % Project
        VariableModel % Project
        
        ProjectManager % UserSession
        
        MessagePanel % Todo: Use HasDisplay mixin...
        MessageBox
        StatusText applify.StatusText
    end
    
    properties
        CurrentSelection     % Current selection of data objects.
        WindowKeyPressedListener
        Timer
        RegularTimer    % Timer that regularly looks for updates
        DiskConnectionMonitor (1,1) nansen.internal.system.DiskConnectionMonitor
    end

    properties (Dependent)
        CurrentProject
    end
    
    properties (Access = private)
        UserSession nansen.internal.user.NansenUserSession
        ActiveTabModule = []
        ApplicationState = 'Uninitialized';
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
                %delete(app); clear app; % Todo: get handle for app.
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
            app.createMessagePanel()
            
            app.switchJavaWarnings('on')
            
            % Add this callback after every component is made
            app.Figure.SizeChangedFcn = @(s, e) app.onFigureSizeChanged;
            
%             app.initialized = true;
            app.configFigureCallbacks() % Do this last

            app.setIdle()
            
            app.initializeTimer()
            app.ApplicationState = 'idle';

            if app.settings.General.MonitorDrives
                app.initDiskConnectionMonitor()
            end

            if nargout == 0
                clear app
            end
        end
        
        function delete(app)
            
            global NoteBookViewer PipelineViewer
            if ~isempty(NoteBookViewer)
                delete(NoteBookViewer); NoteBookViewer = [];
            end
            if ~isempty(PipelineViewer)
                delete(PipelineViewer); PipelineViewer = [];
            end

            if ~isempty(app.SchemaViewerApp)
                delete( app.SchemaViewerApp );
            end

            if ~isempty(app.RegularTimer)
                stop(app.RegularTimer)
                delete(app.RegularTimer)
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
                %delete(app.Figure) % This will trigger onExit again...
            end
        end
        
        function onExit(app, h)
            
            if ~isempty(app.BatchProcessor) && isvalid(app.BatchProcessor)
                doExit = app.BatchProcessor.promptQuit();
                if ~doExit; return; end
            end
            
            if ~app.IsIdle
                doExit = app.promptQuitIfBusy();
                if ~doExit; return; end
            end

            % Todo: This is called twice, because of some weird reason
            % in (uiw.abstract.BaseFigure?)

            app.onExit@uiw.abstract.AppWindow(h);
            %delete(app) % Not necessary, happens in superclass' onExit method
        end
    end
    
    methods (Hidden, Access = private) % Methods for app creation
        
        createSessionTableContextMenu(app) % Function in file...
        
        function createWindow(app)
        %createWindow Create and customize UIFigure
        
            screenSize = getMonitorPosition(app.browserSettings.defaultMonitor);
            
            % Set position values
            if app.browserSettings.useDefaultFigureSize
                figSize = [1180, 700];
            else
                figSize = app.browserSettings.FigureSize;
            end
            
            % Make sure figure size is not bigger than screen
            if figSize(1) > screenSize(3); figSize(1) = screenSize(3); end
            if figSize(2) > screenSize(4); figSize(2) = screenSize(4); end
            
            margins = (screenSize(3:4) - figSize) ./ 2;
            margins = margins + screenSize(1:2);
            
            % Create the figure window
            app.UIFigure = figure('Position', [margins figSize]);
            %app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Position = [margins figSize];
            app.UIFigure.Resize = app.browserSettings.FigureResize.Selection;
            
            app.UIFigure.Name = 'Session Browser';
            app.UIFigure.NumberTitle = 'off';
            app.UIFigure.MenuBar = 'none';
            
            [~, fileName] = fileparts(app.experimentInventoryPath);
            app.UIFigure.Name = sprintf('Session Browser | %s (idle)', fileName);
            
            app.UIFigure.Color = [0.3216    0.3255    0.3333];
            
            % Make sure that plots does not end up in this figure window
            app.UIFigure.NextPlot = 'new'; % Not sure if this works...
            %app.UIFigure.HandleVisibility = 'off';
            
%             app.UIFigure.WindowButtonDownFcn = @app.tableMousePress;
%             app.UIFigure.WindowButtonUpFcn = @app.mouseRelease;

            % Set figure callbacks..
            app.UIFigure.WindowKeyPressFcn = @app.keyboardShortcuts;
            app.UIFigure.CloseRequestFcn = @app.UIFigureCloseRequest;
               
            minWidth = 1180;
            minHeight = 700;
            LimitFigSize(app.UIFigure, 'min', [minWidth, minHeight]) %FEX
            
            % Experimental: Change tooltip appearance in sessionbrowser. Need
            % to know more about how callbacks actually interact in terms of
            % giving focus to a window.
% %             jframe = getjframe(app.UIFigure);
% %             set(jframe, 'WindowActivatedCallback', @(s, e) app.onWindowActivated())
% %             set(jframe, 'WindowGainedFocusCallback', @(s, e) app.onWindowActivated())
% %             set(jframe, 'MouseEnteredCallback', @(s, e) app.onWindowActivated())
% %
% %             set(jframe, 'WindowDeactivatedCallback', @(s, e) app.onWindowDeactivated())
% %             set(jframe, 'WindowLostFocusCallback', @(s, e) app.onWindowDeactivated())
% %             set(jframe, 'MouseExitedCallback', @(s, e) app.onWindowDeactivated())
        end
        
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
            app.MinimumFigureSize = app.getPreference('MinimumFigureSize');
            minWidth = app.MinimumFigureSize(1);
            minHeight = app.MinimumFigureSize(2);
            LimitFigSize(app.Figure, 'min', [minWidth, minHeight]) % FEX
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
        
        function createMenu(app)
        %createMenu Create menu components for the main gui.
   
        % % % % Create a nansen main menu
            m = uimenu(app.Figure, 'Text', 'Nansen');
            
            % % % % % % Create PROJECTS menu items  % % % % % %
            
            mitem = uimenu(m, 'Text','New Project');
            uimenu( mitem, 'Text', 'Create...', 'MenuSelectedFcn', @app.onNewProjectMenuClicked);
            uimenu( mitem, 'Text', 'Add Existing...', 'MenuSelectedFcn', @app.onNewProjectMenuClicked);
            
            app.Menu.ChangeProject = uimenu(m, 'Text','Change Project');
            app.updateProjectList()
            
            mitem = uimenu(m, 'Text','Manage Projects...');
            mitem.MenuSelectedFcn = @app.onManageProjectsMenuClicked;
            
            mitem = uimenu(m, 'Text','Open Project Folder', 'Separator', 'on');
            mitem.MenuSelectedFcn = @app.onOpenProjectFolderMenuClicked;

            mitem = uimenu(m, 'Text','Change Current Folder');
            mitem = uics.MenuList(mitem, {'Nansen', 'Current Project'}, '', 'SelectionMode', 'none');
            mitem.MenuSelectedFcn = @(s, e) app.onChangeCurrentFolderMenuClicked(s, e);

            % % % % % % Create CONFIGURATION menu items % % % % % %
            
            mitem = uimenu(m, 'Text','Configure', 'Separator', 'on', 'Enable', 'on');
            % Todo: make methods, and use uiwait...
            
            uimenu( mitem, 'Text', 'Datalocations...', ...
                'MenuSelectedFcn', @(s,e) app.openDataLocationEditor )
            
            % Todo: Update this on project change
            uiSubMenu = uimenu( mitem, 'Text', 'Data Location Roots' );
            app.updateDatalocationRootConfigurationSubMenu(uiSubMenu)

            uimenu( mitem, 'Text', 'Variables...', ...
                'MenuSelectedFcn', @(s,e) app.openVariableModelEditor );
            
            uimenu( mitem, 'Text', 'Modules...', ...
                'MenuSelectedFcn', @(s,e) app.openModuleManager );
        
            uimenu( mitem, 'Text', 'Create File Adapter...', ...
                'MenuSelectedFcn', @(s,e) app.onCreateFileAdapterMenuClicked );

            uimenu( mitem, 'Text', 'Watch Folders...', 'MenuSelectedFcn', ...
                @(s,e)nansen.config.watchfolder.WatchFolderManagerApp, ...
                'Enable', 'off');

            mitem = uimenu(m, 'Text','Preferences...');
            mitem.MenuSelectedFcn = @(s,e) app.editSettings;
            
            mitem = uimenu(m, 'Text', 'Refresh Menu', 'Separator', 'on');
            mitem.MenuSelectedFcn = @app.onRefreshSessionMethodMenuClicked;
            
            mitem = uimenu(m, 'Text','Refresh Table');
            mitem.MenuSelectedFcn = @(s,e) app.onRefreshTableMenuItemClicked;
            
            mitem = uimenu(m, 'Text','Refresh Data Locations');
            mitem.MenuSelectedFcn = @app.onDataLocationModelChanged;

            mitem = uimenu(m, 'Text','Clear Memory');
            mitem.MenuSelectedFcn = @app.onClearMemoryMenuClicked;

            % % % % % % Create EXIT menu items % % % % % %

            mitem = uimenu(m, 'Text','Close All Figures', 'Separator', 'on');
            mitem.MenuSelectedFcn = @app.MenuCallback_CloseAll;
            
            mitem = uimenu(m, 'Text', 'Quit');
            mitem.MenuSelectedFcn = @(s, e) app.delete;

        % % % % Create a "MANAGE" menu
            m = uimenu(app.Figure, 'Text', 'Metatable');
            
            mitem = uimenu(m, 'Text', 'New Metatable...', 'Enable', 'on');
            mitem.MenuSelectedFcn = @app.MenuCallback_CreateMetaTable;
            
            mitem = uimenu(m, 'Text','Open Metatable', 'Separator', 'on', 'Tag', 'Open Metatable', 'Enable', 'on');
            app.updateRelatedInventoryLists(mitem)
            app.updateMetaTableMenu(mitem);

            mitem = uimenu(m, 'Text','Make Current Metatable Default');
            mitem.MenuSelectedFcn = @app.onSetDefaultMetaTableMenuItemClicked;
            
            mitem = uimenu(m, 'Text','Reload Metatable');
            mitem.MenuSelectedFcn = @(src, event) app.reloadMetaTable;
            mitem = uimenu(m, 'Text','Save Metatable', 'Enable', 'on');
            mitem.MenuSelectedFcn = @(src, event, forceSave) app.saveMetaTable(src, event, true);
            
            mitem = uimenu(m, 'Text','Manage Metatables...', 'Enable', 'off');
            mitem.MenuSelectedFcn = [];
            
            % % % Create menu items for METATABLE loading and saving % % %
            
% %             mitem = uimenu(m, 'Text','Load Metatable...', 'Enable', 'off');
% %             mitem.MenuSelectedFcn = @app.menuCallback_LoadDb;
% %             mitem = uimenu(m, 'Text','Refresh Metatable', 'Enable', 'off');
% %             mitem.MenuSelectedFcn = @(src, event) app.reloadExperimentInventory;
% %             mitem = uimenu(m, 'Text','Save Metatable', 'Enable', 'off');
% %             mitem.MenuSelectedFcn = @app.saveExperimentInventory;
% %             mitem = uimenu(m, 'Text','Save Metatable As', 'Enable', 'off');
% %             mitem.MenuSelectedFcn = @app.saveExperimentInventory;
                
            % % Section with menu items for creating table variables

            mitem = uimenu(m, 'Text','New Table Variable', 'Separator', 'on');
            uimenu( mitem, 'Text', 'Create...', 'MenuSelectedFcn', @(s,e) app.onCreateTableVariableMenuItemClicked());
            uimenu( mitem, 'Text', 'Import...', 'MenuSelectedFcn', @(s,e) app.importTableVariable());
            
            % Menu with submenus for editing table variable definition:
            mitem = uimenu(m, 'Text','Edit Table Variable Definition');
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
                mitem = uimenu(m, 'Text', sprintf('Add %s Schema', iMetadataModel.Name));

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
            
            mitem = uimenu(m, 'Text','Manage Variables...', 'Enable', 'off');
            mitem.MenuSelectedFcn = [];

% %             mitem = uimenu(m, 'Text','Import from Excel', 'Separator', 'on', 'Enable', 'on');
% %             mitem.MenuSelectedFcn = @app.menuCallback_ImportTable;
% %             mitem = uimenu(m, 'Text','Export to Excel');
% %             mitem.MenuSelectedFcn = @app.menuCallback_ExportToTable;

            % Todo: get modules from different packages and assemble in a
            % struct before creating the menus..
                    
            % Create a "Session" menu
            m = uimenu(app.Figure, 'Text', 'Session');
            app.createSessionMenu(m)

            %m = uimenu(app.Figure, 'Text', 'Apps');

            % Create a separator
            m = uimenu(app.Figure, 'Text', '|', 'Enable', 'off');

            % Create an apps menu
            m = uimenu(app.Figure, 'Text', 'Apps');
            app.createAppsMenu(m)

            % Create a tools menu
            m = uimenu(app.Figure, 'Text', 'Tools');
            app.createToolsMenu(m)

            % Create a separator
            m = uimenu(app.Figure, 'Text', '|', 'Enable', 'off');

            app.SessionTaskMenu = nansen.SessionTaskMenu(app);
            app.SessionTaskMenuUpdatedListener = addlistener(...
                app.SessionTaskMenu, 'MenuUpdated', @app.onSessionTaskMenuUpdated);
            
            l = listener(app.SessionTaskMenu, 'MethodSelected', ...
                @app.onSessionTaskSelected);
            app.TaskInitializationListener = l;

            % Create a help menu:
            app.createHelpMenu()

            % app.createMenuFromDir(app.Figure, menuRootPath)
            
            % In early testing: Add multipart figures...
% %             m = uimenu(app.Figure,'Text', 'Figure');
% %
% %             pmObj = nansen.config.project.ProjectManager;
% %             S = pmObj.listFigures;
% %
% %             for i = 1:numel(S)
% %                 mItem = uimenu(m, 'Text', S(i).Name);
% %
% %                 for j = 1:numel(S(i).FigureNames)
% %                     mSubItem = uimenu(mItem, 'Text', S(i).FigureNames{j});
% %                     mSubItem.MenuSelectedFcn = ...
% %                         @(s,e,n1,n2)app.onOpenFigureMenuClicked(...
% %                                         S(i).Name, S(i).FigureNames{j});
% %                 end
% %             end
            
            return
            
        end
        
        function updateProjectList(app, hParent)
        %updateProjectList Update lists of projects in uicomponents
            
            names = app.ProjectManager.ProjectNames;
            currentProject = app.ProjectManager.CurrentProject;

            if isfield( app.Menu, 'ProjectList' )
                app.Menu.ProjectList.Items = names;
                app.Menu.ProjectList.Value = currentProject;
            else
                hParent = app.Menu.ChangeProject;
                hMenuList = uics.MenuList(hParent, names, currentProject);
                hMenuList.MenuSelectedFcn = @app.onChangeProjectMenuClicked;
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
            % todo (not implemented yet)
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

        function createSessionMenu(app, hMenu, updateFlag)
            
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
            mitem.MenuSelectedFcn = @app.onCreateSessionMethodMenuClicked;
            
            mitem = uimenu(hMenu, 'Text', 'New Data Variable...', 'Enable', 'off');
            mitem.MenuSelectedFcn = [];
            
          % --- Section with menu items for creating pipeline
            mitem = uimenu(hMenu, 'Text', 'New Pipeline...', 'Enable', 'on', 'Separator', 'on');
            mitem.MenuSelectedFcn = @app.onCreateNewPipelineMenuItemClicked;

            mitem = uimenu(hMenu, 'Text', 'Edit Pipeline', 'Enable', 'on');
            app.updatePipelineItemsInMenu(mitem)
        
            mitem = uimenu(hMenu, 'Text', 'Configure Pipeline Assignment...', 'Enable', 'on');
            mitem.MenuSelectedFcn = @app.onConfigPipelineAssignmentMenuItemClicked;

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
        
        function createAppsMenu(~, hMenu)
            mitem = uimenu(hMenu, 'Text', 'Imviewer');
            mitem.MenuSelectedFcn = @(s,e) imviewer();

            mitem = uimenu(hMenu, 'Text', 'FovManager');
            mitem.MenuSelectedFcn = @(s,e) fovmanager.App();

            mitem = uimenu(hMenu, 'Text', 'RoiManager');
            mitem.MenuSelectedFcn = @(s,e) roimanager.RoimanagerDashboard();
        end

        function createToolsMenu(app, hMenu)
            
            if nargin < 2
                hMenu = findobj(app.Figure, 'Type', 'uimenu', '-and', 'Text', 'Tools');
            end

            if ~isempty(hMenu.Children)
                delete(hMenu.Children)
            end

            folderPathList = app.CurrentProject.getMixinFolders('tool');
            app.createMenuFromDir(hMenu, folderPathList)
        end

        function createHelpMenu(app)
            
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
            %mitem.MenuSelectedFcn = @(src, event) nansen.internal.reactivatePopupTips;

            mitem = uimenu(m, 'Text','Go to NANSEN Wiki Page', 'Separator', 'on');
            mitem.MenuSelectedFcn = @(s, e) web('https://github.com/VervaekeLab/NANSEN/wiki');

            mitem = uimenu(m, 'Text','Create a GitHub Issue...');
            mitem.MenuSelectedFcn = @(s, e) web('https://github.com/VervaekeLab/NANSEN/issues/new');
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
        
        function updatePipelineItemsInMenu(app, hMenu)
            
            if nargin < 2
                hMenu = gobjects(0);
                hMenu(1) = findobj(app.Figure, 'Text', 'Edit Pipeline');
                hMenu(2) = findobj(app.Figure, 'Text', 'Assign Pipeline');
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
                            mSubItem.MenuSelectedFcn = @app.onEditPipelinesMenuItemClicked;
                        case 'Assign Pipeline'
                            mSubItem.MenuSelectedFcn = @app.onAssignPipelinesMenuItemClicked;
                    end
                end
                
                if strcmp(hMenu(i).Text, 'Assign Pipeline')
                    mSubItem = uimenu(hMenu(i), 'Text', 'No pipeline', 'Separator', 'on', 'Enable', 'on');
                    mSubItem.MenuSelectedFcn = @app.onAssignPipelinesMenuItemClicked;
                    mSubItem = uimenu(hMenu(i), 'Text', 'Autoassign pipeline', 'Enable', 'off');
                    mSubItem.MenuSelectedFcn = @app.onAssignPipelinesMenuItemClicked;
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
        
        function updateDatalocationRootConfigurationSubMenu(app, hMenu)
            
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

        function createMenuFromDir(app, hParent, dirPath)
        %createMenuFromDir Create menu components from a folder/folder tree
        %
        % Purpose: Create a folder called SessionTasks with different
        % packages, all with functions that can be called with sessionIDs.
        % These functions will be organized in the menu according the the
        % packages within the root folder.
        %
        % See also app.menuCallback_SessionMethod
        
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
                    
                    %app.SessionTasks(end+1) = iMitem;
                end
            end
        end
        
        function refreshMenuLabels(app, modifier)
                         
             for i = 1:numel(app.SessionTasks)
                 
                 switch modifier
                     case ''
                         app.SessionTasks(i).Text = strrep(app.SessionTasks(i).Text, '...', '');
                         app.SessionTasks(i).Text = strrep(app.SessionTasks(i).Text, ' (q)', '');
                     case 'shift'
                         app.SessionTasks(i).Text = [app.SessionTasks(i).Text, '...'];
                     case 'alt'
                         app.SessionTasks(i).Text = [app.SessionTasks(i).Text, ' (q)'];
                 end
             end
        end
        
        function updateSessionInfoDependentMenus(app)
            app.createSessionTableContextMenu()
            app.createSessionMenu([], true)
        end
        
        function createLayout(app)
        
%             app.hLayout.TopBorder = uipanel('Parent', app.Figure);
%             app.hLayout.TopBorder.BorderType = 'none';
%             app.hLayout.TopBorder.BackgroundColor = [0    0.3020    0.4980];
            
            app.hLayout.MainPanel = uipanel('Parent', app.Figure, 'Tag', 'Main Panel');
            app.hLayout.MainPanel.BorderType = 'none';
            
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
            
            %app.createSidePanelComponents()
        end
        
        function createMessagePanel(app)
            
% %             app.MessagePanel = uipanel(app.Figure, 'units', 'pixels');
% %             app.MessagePanel.Position(3:4) = [400, 100];
% %             app.MessagePanel.Visible = 'off';
% %             app.MessagePanel.BorderType = 'line';
% %             referencePosition =  [1,1,app.Figure.Position(3:4)];
% %             uim.utility.layout.centerObjectInRectangle(app.MessagePanel, referencePosition)
% %             app.MessageBox = uim.widget.messageBox(app.MessagePanel);
        end
        
        function createStatusField(app)
            
            app.h.StatusField = uicontrol('Parent', app.hLayout.StatusPanel, 'style', 'text');
            app.h.StatusField.Units = 'normalized';
            app.h.StatusField.Position = [0,-0.2,1,1];                      % -0.2: Correct for text being offset towards top of textbox
            
            %app.h.StatusField.FontName = 'avenir next';
            app.h.StatusField.FontSize = 12;
            app.h.StatusField.FontUnits = 'pixels';
            
            app.h.StatusField.String = '';
            app.h.StatusField.BackgroundColor = ones(1,3).*0.85;
            app.h.StatusField.HorizontalAlignment = 'left';
            app.h.StatusField.Enable = 'inactive';

            app.StatusText = applify.StatusText({'Sessions', 'CustomStatus', 'Status'});
            app.StatusText.UpdateFcn = @app.updateStatusField;
            app.StatusText.Status = 'Status : Idle';
            app.updateSessionCount()
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
                       
            try %#ok<TRYNC>
                columnSettings = app.loadMetatableColumnSettingsFromProject();
                %app.UiMetaTableViewer.ColumnSettings = columnSettings;
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
            %h.HTable.MouseMotionFcn = @(s,e) onMouseMotionInTable(h, s, e);
            
            addlistener(h.HTable, 'MouseMotion', @app.onMouseMoveInTable);
            
            h.UpdateColumnFcn = @app.updateTableVariable;
            h.ResetColumnFcn = @app.resetTableVariable;
            h.DeleteColumnFcn = @app.removeTableVariable;
            h.EditColumnFcn = @app.editTableVariableFunction;

            h.GetTableVariableAttributesFcn = @(s,e) app.getTableVariableAttributes();

            h.MouseDoubleClickedFcn = @app.onMouseDoubleClickedInTable;
            
            addlistener(h, 'SelectionChanged', @app.onSessionSelectionChanged);
            addlistener(h, 'TableUpdated', @(s,e)app.updateSessionCount);

            app.createSessionTableContextMenu()

            % Set background color for tab to match the color of the
            % TabGroup container.
            hTab.BackgroundColor = ones(1,3)*0.91;

            % Create table menu (menu for selecting tables):
            metatableTypes = app.CurrentProject.MetaTableCatalog.Table.MetaTableClass;
            isSelected = strcmp(metatableTypes, class(app.MetaTable));

            if numel(unique(metatableTypes)) > 1
                metatableTypes = utility.string.getSimpleClassName(metatableTypes);
                metaTableTypes = unique(metatableTypes, 'stable');

                buttonGroup = nansen.ui.widget.ButtonGroup(hTab, 'Items', metaTableTypes);
                buttonGroup.updateLocation()
                buttonGroup.SelectionChangedFcn = @app.onMetaTableTypeChanged;
                app.UiMetaTableSelector = buttonGroup;
                app.UiMetaTableSelector.CurrentSelection = metaTableTypes(isSelected);
                app.updateTablePosition()
            end
        end
        
        function updateTablePosition(app)
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
        
        function createSidePanelComponents(app)
            % Not implemented
            uicc = uim.UIComponentCanvas(app.hLayout.SidePanel);

            buttonSize = [21, 51];
            options = {'PositionMode', 'auto', 'SizeMode', 'manual', 'Size', buttonSize, ...
                'HorizontalTextAlignment', 'center', 'Icon', '>', ...
                'Location', 'west', 'Margin', [0, 15, 0, 0], ...
                'Callback', @(s,e) app.hideSidePanel() };
            
            closeButton = uim.control.Button_(app.hLayout.SidePanel, options{:} );
        end
    
        function initializeTimer(app)
            app.RegularTimer = timer('Name', 'Nansen App Timer');
            app.RegularTimer.ExecutionMode = 'fixedRate';
            app.RegularTimer.Period = 30; % Consider setting from preference
            app.RegularTimer.TimerFcn = @(timer, event) app.regularCheckup();
            start(app.RegularTimer)
        end
    
        function initDiskConnectionMonitor(app)
        
            app.DiskConnectionMonitor = nansen.internal.system.DiskConnectionMonitor();
            
            addlistener(app.DiskConnectionMonitor, 'DiskAdded', ...
                @app.onAvailableDisksChanged);

            addlistener(app.DiskConnectionMonitor, 'DiskRemoved', ...
                @app.onAvailableDisksChanged);

        end
    end

    methods (Access = private) % Internal callbacks
            
        function onMouseDoubleClickedInTable(app, src, evt)
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
                
                tableRowIdx = app.UiMetaTableViewer.getMetaTableRows(thisRow); % Visible row to data row transformation
                tableValue = app.MetaTable.entries{tableRowIdx, thisColumnName};
                tableVariableObj = feval(tableVariableFunctionName, tableValue);
                
                tableRowData = app.MetaTable.entries(tableRowIdx,:);
                metaObj = app.tableEntriesToMetaObjects( tableRowData );
                tableVariableObj.onCellDoubleClick( metaObj );
            end
        end
        
        function onMouseMoveInTable(app, src, evt)
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
    
        function onAvailableDisksChanged(app, src, evt)
            
            returnToIdle = app.setBusy('Disk added, updating data locations'); %#ok<NASGU>
            
            % - [ ] Update volume info in the DataLocationModel
            % volumeInfo = evt.VolumeInfo;

            returnToIdle = app.setBusy('Updating table'); %#ok<NASGU>
            
            app.DataLocationModel.updateVolumeInfo() % volumeInfo;

            % - [ ] Update data location structs
            app.updateDataLocationFromModel()

            % - [ ] Refresh table on these events
            app.onRefreshTableMenuItemClicked()
        end

        function regularCheckup(app)
        %regularCheckup Timer callback
            
            % Check that we have the newest version of the metatable
            if ~isempty(app.MetaTable) && ~app.TableIsUpdating
                if ~app.MetaTable.isLatestVersion()
                    stop(app.RegularTimer) % Stop timer while waiting for user's response
                    discardNewest = app.MetaTable.resolveCurrentVersion();
                    if discardNewest
                        app.reloadMetaTable()
                    else
                        app.saveMetaTable([], [], true) % true = force save current version
                    end
                    start(app.RegularTimer)
                end
            end
        end
    end

    methods % Set/get methods
        function set.MetaTable(app, newTable)
            app.MetaTable = newTable;
            app.onNewMetaTableSet()
            app.updateSessionCount()
        end
    
        function currentProject = get.CurrentProject(obj)
            currentProject = obj.ProjectManager.getCurrentProject();
        end
    end
    
    methods
        
        function grabFocus(app)
            uicontrol(app.h.StatusField)
        end
        
        function promptOpenProject(app, projectName)
            
            prompt = sprintf('Do you want to open the project "%s"', projectName);
            title = 'Open Project?';
            answer = app.openQuestionDialog(prompt, title);
            
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
            
            app.BatchProcessor.closeTaskList()

            % Delete current file viewer
            delete(app.UiFileViewer); app.UiFileViewer = [];

            % Todo: Make method:
            app.UiMetaTableViewer.resetTable()
            app.UiMetaTableViewer.refreshTable(table.empty, true)
            try
                columnSettings = app.loadMetatableColumnSettingsFromProject();
                app.UiMetaTableViewer.ColumnSettings = columnSettings;
            end

            % Todo: Need system on task processor to create session
            % objects..
            app.resetMetaObjectList()
            
            % Need to reassign data location model before loading metatable
            % Todo: Explicitly get models for this project.
            app.DataLocationModel = nansen.DataLocationModel();
            app.VariableModel = nansen.VariableModel();

            app.updateRelatedInventoryLists()
            app.loadMetaTable()

            drawnow
            currentProjectName = app.ProjectManager.CurrentProject;
            currentProject = app.ProjectManager.getProjectObject(currentProjectName);
            app.SessionTaskMenu.CurrentProject = currentProject;

            % Load new project's task list
            taskListFilepath = currentProject.getDataFilePath('TaskList');
            app.BatchProcessor.openTaskList(taskListFilepath)

            % Update menus
            app.SessionTaskMenu.refresh()
            app.createSessionTableContextMenu()
            app.updatePipelineItemsInMenu()
            app.updateTableVariableMenuItems()
            app.updateDatalocationRootConfigurationSubMenu()
            
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
        end
        
        function onDataLocationModelChanged(app, src, evt)
        %onDataLocationModelChanged Event callback for datalocation model
            
            try
                d = src.openProgressDialog('Update Model');
            end

            app.MetaTable = nansen.manage.updateSessionDatalocations(...
                app.MetaTable, app.DataLocationModel);
            
            app.saveMetaTable()
            try
                close(d)
            end
        end

        function onVariableModelChanged(app, src, evt)
            % Reload model.
            app.VariableModel.load();
        end

        function onModuleSelectionChanged(app, src, evtData)
            % Get current project
            p = app.ProjectManager.getCurrentProject();
            
            % Update the optional modules for the project
            p.setOptionalModules( {evtData.SelectedData.PackageName} )

            app.SessionTaskMenu.CurrentProject = p;
        end
        
    % % Get meta objects from table selections
        
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
        
        function metaObjects = tableEntriesToMetaObjects(app, entries)
        %tableEntriesToMetaObjects Create meta objects from table rows
        
            %schema = str2func(class(app.MetaTable));
            %schema = @nansen.metadata.type.Session;
            
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
        %createMetaObjects Create new meta objects from table entries
            
            if nargin < 3 || isempty(useCache); useCache = true; end

            % Todo: Need to apply this fix when migrating projects
            if isempty(app.MetaTable.ItemClassName)
                %schema = str2func(class(app.MetaTable));
                schema = @table2struct;
            else
                schema = str2func(app.MetaTable.ItemClassName);
            end

            if isempty(tableEntries)
                try
                    metaObjects = schema().empty;
                catch
                    metaObjects = [];
                end
                return;
            end

            % Relevant for meta objects that have datalocations:
            % Create list of name value pairs for the current datalocation
            % model and variable model.
            if any(strcmp(tableEntries.Properties.VariableNames, 'DataLocation'))
                nvPairs = {'DataLocationModel', app.DataLocationModel, ...
                            'VariableModel', app.VariableModel};
            else
                nvPairs = {};
            end

            metaObjects = schema(tableEntries, nvPairs{:});

            try
                addlistener(metaObjects, 'PropertyChanged', @app.onMetaObjectPropertyChanged);
                addlistener(metaObjects, 'ObjectBeingDestroyed', @app.onMetaObjectDestroyed);
            catch
                % Todo: Either throw warning or implement interface for
                % easily implementing PropertyChanged on any table
                % class..
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
        %metaobject list
            idName = app.MetaTable.SchemaIdName;
            app.MetaObjectMembers = {app.MetaObjectList.(idName)};

            if isnumeric(app.MetaObjectMembers)
                app.MetaObjectMembers = cellfun(@num2str, app.MetaObjectMembers, 'UniformOutput', false);
            end
        end
        
        function resetMetaObjectList(app)
        %resetMetaObjectList Delete all meta objects from the list
            for i = numel(app.MetaObjectList):-1:1
                if isvalid( app.MetaObjectList(i) )
                    delete( app.MetaObjectList(i) )
                end
            end
            app.MetaObjectList = [];
            app.MetaObjectMembers = {};
        end

        function onMetaObjectPropertyChanged(app, src, evt)
            
            % Todo: generalize from session
            % Todo: make method for getting table entry from sessionID
            
            if ~isvalid(src); return; end
            
            sessionID = src.sessionID;
            metaTableEntryIdx = find(strcmp(app.MetaTable.members, sessionID));
            
            if numel(metaTableEntryIdx) > 1
                metaTableEntryIdx = metaTableEntryIdx(1);
                msg = sprintf('Multiple sessions have the sessionID "%s"', sessionID);
                warndlg(msg)
            end
            
            app.MetaTable.editEntries(metaTableEntryIdx, evt.Property, evt.NewValue)
            
            rowIdx = metaTableEntryIdx;
            colIdx = find(strcmp(app.MetaTable.entries.Properties.VariableNames, evt.Property));
            newValue = app.MetaTable.getFormattedTableData(colIdx, rowIdx);
            newValue = table2cell(newValue);
            
            app.UiMetaTableViewer.updateCells(rowIdx, colIdx, newValue)
            
            % Update table (only data update)
            % Todo: update specific rows and columns
            % app.UiMetaTableViewer.replaceTable( app.MetaTable );
        end
        
        function onMetaObjectDestroyed(app, src, evt)
            if ~isvalid(app); return; end
            
            idName = app.MetaTable.SchemaIdName;
            objectID = src.(idName);
            
            [~, ~, iC] = intersect(objectID, app.MetaObjectMembers);
            app.MetaObjectList(iC) = [];

            app.updateMetaObjectMembers()
        end

        function onTaskAddedEventTriggered(app, src, evt)
        %onTaskAddedEventTriggered Callback for event when task is added to
        %batchProcessor task list
        
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
 
        function onTaskProcessorStatusChanged(app, src, evt)
        %onTaskProcessorStatusChanged Callback for TaskProcessor Status
            if strcmp( evt.AffectedObject.Status, 'busy' )
                app.setBusy('Initializing task processor...')
            else
                app.setIdle()
            end
        end
        
    %%% Methods for side panel
        
        function showSidePanel(app)
            figPosPix = getpixelposition(app.Figure);
           
            w = figPosPix(3);
            app.hLayout.SidePanel.Visible = 'on';
            for i = 25
                app.hLayout.SidePanel.Position(1) = w-10*i;
                pause(0.01)
            end
        end
        
        function hideSidePanel(app)
            
            figPosPix = getpixelposition(app.Figure);
           
            w = figPosPix(3);
            h = figPosPix(4);
            
            for i = 0
                app.hLayout.SidePanel.Position(1) = w-10*i;
                pause(0.01)
            end
            app.hLayout.SidePanel.Visible = 'off';
        end
    end
    
    methods (Hidden, Access = protected) % Methods for internal app updates
        
        function onThemeChanged(app)
            app.Figure.Color = app.Theme.FigureBackgroundColor;
            app.hLayout.MainPanel.BackgroundColor = app.Theme.FigureBackgroundColor;
            %app.hLayout.StatusPanel.BackgroundColor = app.Theme.FigureBackgroundColor;
            
            % Something like this:
            %app.UiMetaTableViewer.HTable.Theme = uim.style.tableDark;
        end
        
        function onFigureSizeChanged(app)
            app.updateLayoutPositions()
            drawnow
            % Todo: Table position only needs to be updated if the
            % overview/table page is active. Need a flag and a call to
            % updateTablePosition on tab change if the flag is dirty.
            %
            % if strcmp(app.hLayout.TabGroup.SelectedTab.Title, 'Overview')
            app.updateTablePosition()
            % end
        end
        
        function onSessionTaskMenuUpdated(app, ~, ~)
            % Need to recreate the Help menu in order for it to stay to the
            % right of session task menus (uistack is not a good option,
            % god knows why...)
            uiMenuHelp = findobj(app.Figure, 'Type', 'uimenu',  '-and', '-regexp', 'Tag', 'Help', '-depth', 1);
            delete(uiMenuHelp)
            app.createHelpMenu()
        end

        function onTabChanged(app, src, evt)
            
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
                    if ~strcmp(app.MetaTable.getTableType, 'session')
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
                    %if isempty(selectedSessionObj); return; end
                    
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
        
        function onMousePressed(app, src, evt)
            
            % Todo: Should figure out why the focuslost callback does not
            % work in certain positions of the figure.
            if ~isempty(app.UiMetaTableViewer.ColumnFilter)
                app.UiMetaTableViewer.ColumnFilter.hideFilters();
            end
        end
        
        function onMouseMotion(app, src, evt)
            
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
        
        function onKeyReleased(app, src, evt)

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
            [~, fileName] = fileparts(app.MetaTable.filepath);
            fileName = app.MetaTable.getName();

            if app.IsIdle
                status = 'idle';
            else
                status = 'busy';
            end
            
            projectName = app.ProjectManager.CurrentProject;
            titleStr = sprintf('%s | Project: %s | Metatable: %s (%s)', app.AppName, projectName, fileName, status);
            app.Figure.Name = titleStr;
        end
    
        function setIdle(app)
            app.IsIdle = true;
            app.StatusText.Status = sprintf('Status: Idle');
            app.updateFigureTitle()
            
            app.Figure.Pointer = 'arrow';
            drawnow
        end
        
        function finishup = setBusy(app, statusStr)
                        
            app.IsIdle = false;
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
        
        function updateSessionCount(app, numSessionsTotal, numSessionsSelected)
            if ~isempty(app.StatusText)
                
                elementName = 'sessions';

                if nargin < 2 || isempty(numSessionsTotal)
                    if isempty(app.UiMetaTableViewer)
                        numSessionsTotal = size(app.MetaTable.entries, 1);
                    else
                        numSessionsTotal = size(app.UiMetaTableViewer.HTable.Data, 1);
                    end
                end

                if nargin < 3 || isempty(numSessionsSelected)
                    if isempty(app.UiMetaTableViewer)
                        numSessionsSelected = 0;
                    else
                        numSessionsSelected = numel(app.UiMetaTableViewer.HTable.SelectedRows);
                    end
                end

                if numSessionsSelected > 0
                    str = sprintf('Selected %d/%d %s', numSessionsSelected, numSessionsTotal, elementName);
                else
                    str = sprintf('%d %s', numSessionsTotal, elementName);
                end

                app.StatusText.Sessions = str;
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
        
        function onSessionSelectionChanged(app, src, evt)
        %onSessionSelectionChanged Callback for session table
            numSessionsSelected = numel(evt.SelectedRows);
            numSessionsTotal = size(src.HTable.Data, 1);
            
            app.updateSessionCount(numSessionsTotal, numSessionsSelected)
            app.updateCustomRowSelectionStatus()
        end

        function onMetaTableDataChanged(app, src, evt)
            
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
                tableType = utility.string.getSimpleClassName( class(app.MetaTable) );
                
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

        function onCreateTableVariableMenuItemClicked(app)
            app.createTableVariable()
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
            
            metadataClass = app.MetaTable.getTableType();

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
                
                message = sprintf(['The variable "%s" already exists in this table. ', ...
                    'Do you want to modify this variable? ', ...
                    'Note: The old variable definition will be lost.'], S.VariableName);
                title = 'Confirm Variable Modification';
                %answer = questdlg(message, title);
                answer = app.openQuestionDialog(message, title);

                switch answer
                    case 'Yes'
                        % Proceed
                    case {'No', 'Cancel'}
                        return
                end
% %                 error('Variable with name %s already exists in this table', ...
% %                     S.VariableName )
            end
        
            % Add the metadata class to s. An idea is to also select this
            % on creation.
            S.MetadataClass = metadataClass;

            % Make sure the variable name is valid
            msg = sprintf('%s is not a valid variable name', S.VariableName);
            if ~isvarname(S.VariableName); app.openErrorDialog(msg); return; end
            
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
            
            currentTableType = app.MetaTable.getTableType();
            try
                assert(isequal(importedTableType, currentTableType), ...
                    ['Can not import table variable because the selected ', ...
                    'file is a table variable for a "%s" table, whereas the ', ...
                    'active table is a "%s" table.'], importedTableType, currentTableType)
            catch ME
                app.openErrorDialog( ME.message, 'Could not import table variable')
                return
            end

            rootPathTarget = nansen.localpath('Custom Metatable Variable', 'current');
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
        
        function editTableVariableDefinition(app, src, evt)
                        
            varName = src.Text;
            
            % Todo: Conditional, other variables does not have a function
            app.editTableVariableFunction(varName)
        end
        
        function editTableVariableFunction(app, tableVariableName)
                    
            import nansen.metadata.utility.getTableVariableUserFunctionPath
            % Todo, support multiple table types
            varName = tableVariableName;
            filepath = getTableVariableUserFunctionPath(varName, 'session');
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

            %S.DataType_ = {'numeric', 'text', 'logical'};
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

        function viewSchemaInfo(app, src, evt)
            
            if isempty(app.SchemaViewerApp)
                app.SchemaViewerApp = schemaViewer;
            else
                app.SchemaViewerApp.Visible = 'on';
            end
            
            s = app.getSelectedMetaObjects();
            s = s(1);

            % Todo: Get schema type...
            % Todo: Get schema name
            
            s = getSchemaItem(schemaName, instance);

            app.SchemaViewerApp.Schema = s;
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
        %updateTableVariable Update a table variable for selected sessions
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

            % Todo: add case for all rows that are empty
            % Todo: add case for all visible rows...
            
            switch updateMode
                case 'SelectedRows'
                    app.assertSessionSelected()

                    sessionObj = app.getSelectedMetaObjects();
                    rows = app.UiMetaTableViewer.getSelectedEntries();

                case 'AllEmptyRows'
                    % Todo....
                    
                case 'AllRows'
                    rows = 1:size(app.MetaTable.entries, 1);
                    sessionObj = app.tableEntriesToMetaObjects(app.MetaTable.entries);
            end
            
            numSessions = numel(sessionObj);
            
            if numSessions > 5 && ~reset
                h = waitbar(0, 'Please wait while updating values');
            end
            
            % Todo: This function call is different for preprogrammed
            % table variables, i.e data location.
            
            % Todo: This should be a property and it should be updated when
            % tablevariables are created or modified...

            % Todo: Support multiple table types

            T = app.CurrentProject.getTable('TableVariable');
            T = T(T.TableType=='session', :);
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
                        %if ischar(newValue); newValue = {newValue}; end % Need to put char in a cell. Should use strings instead, but that's for later

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
                                app.openMessageBox(warningMessage, 'Update failed')
                                wasWarned = true;
                                ME = MException('TableVar:WrongType', warningMessage);
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
                sessionIDs = strjoin({sessionObj(skippedRowInd).sessionID}, newline);
                messageStr = sprintf( 'Failed to update %s for the following sessions:\n\n%s\n', varName, sessionIDs);
                errorMessage = sprintf('\nThe following error message was caught:\n%s', ME.message);
                app.openMessageBox([messageStr, errorMessage], 'Update failed')
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
            
            sessionObj = app.getSelectedMetaObjects();
            
            sessionID = {sessionObj.sessionID};
            sessionID = cellfun(@(sid) sprintf('''%s''', sid), sessionID, 'uni', 0);
            sessionIDStr = strjoin(sessionID, ', ');
            clipboard('copy', sessionIDStr)
        end

        function copyTableValuesToClipboard(app, src, evt)
            % Not implemented yet.
            %
            % Not clear how to get the selected column index, as this is
            % currently not accessible from any property.
            selectedEntries = app.UiMetaTableViewer.getSelectedEntries();
        end

        function removeSessionFromTable(app)
            selectedEntries = app.UiMetaTableViewer.getSelectedEntries();
            app.MetaTable.removeEntries(selectedEntries)
            app.UiMetaTableViewer.refreshTable(app.MetaTable)
        end
        
        function onAssignPipelinesMenuItemClicked(app, src, ~)
        %onAssignPipelinesMenuItemClicked Session context menu callback
            sessionObj = app.getSelectedMetaObjects();
            if strcmp(src.Text, 'No pipeline')
                sessionObj.unassignPipeline()
            elseif strcmp(src.Text, 'Autoassign pipeline')
                sessionObj.assignPipeline() % No input = pipeline is autoassigned
            else
                sessionObj.assignPipeline(src.Text)
            end
        end
        
        function onCreateNoteSessionContextMenuClicked(app)

            sessionObj = app.getSelectedMetaObjects();
            sessionID = sessionObj.sessionID;
            noteObj = nansen.notes.Note.uiCreate('session', sessionID);
            
            sessionObj.addNote(noteObj)
        end

        function onRemoveSessionMenuClicked(app)
            app.removeSessionFromTable()
        end
        
        function onViewSessionNotesContextMenuClicked(app)
            
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
                %app.VariableModel.load()
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
                %hApp.changeWindowStyle('modal')
                addlistener(hApp, 'ModuleSelectionChanged', @app.onModuleSelectionChanged);
            else
                hApp.setSelectedModules(dataModules)
                hApp.Visible = 'on';
            end
        end

        function onConfigureDatalocationRootMenuClicked(app, src, evt)
            
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
            app.onRefreshTableMenuItemClicked()
        end

        function removeTableVariable(app, src, evt)
        %removeTableVariable Remove variable from the session table
            
            if ischar(src)
                varName = src;
            else
                varName = src.Text;
            end

            % Create a dialog here.
            message = sprintf( ['This will delete the data of column ', ...
                '%s from the table. The associated tablevar function ', ...
                'will also be deleted. Are you sure you want to continue?'], ...
                varName );
            title = 'Delete data?';
            
            %answer = questdlg(message, title);
            answer = app.openQuestionDialog(message, title);

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
        
        function metaTable = checkIfMetaTableComplete(app, metaTable)
        %checkIfMetaTableComplete Check if user-defined variables are
        %missing from the table.
        
        % Todo: Add to metatable class? Eller muligens BaseSchema??? Kan
        % man legge inn dynamiske konstante egenskaper?
        
            if nargin < 2
                metaTable = app.MetaTable;
            end

            if isempty(metaTable.entries); return; end
    
            tableType = metaTable.getTableType();
            metaTable = app.addMissingVarsToMetaTable(metaTable, tableType);
        
            metaTable = app.removeMissingVarsFromMetaTable(metaTable, tableType);

            if nargin < 2; app.MetaTable = metaTable; end
            if ~nargout; clear metaTable; end
        end
        
        function metaTable = addMissingVarsToMetaTable(app, metaTable, metaTableType)
        %addMissingVarsToMetaTable Add variable to table if it is missing.
        %
        %   If a table is present in the table variable definitions, but
        %   missing from the table, this functions adds a new variable to
        %   the table and initializes with the default value based on the
        %   table variable definition.
        
            % Question: Should this be a metatable method.
            
            if nargin < 3
                metaTableType = 'session';
            end
            
            tableVarNames = metaTable.entries.Properties.VariableNames;
            
            refVariableAttributes = app.CurrentProject.getTable('TableVariable');
            refVariableAttributes(refVariableAttributes.TableType ~= metaTableType, :) = [];

            isCustom = refVariableAttributes.IsCustom;
            customVariableNames = refVariableAttributes{isCustom, 'Name'};
            
            % Check if any variable is present in the table variable list, but
            % the corresponding variable is missing from the table.
            missingVarNames = setdiff(customVariableNames, tableVarNames);
            
            getRowIndex = @(T, varName) find( strcmp(T.Name, varName) );

            for iVarName = 1:numel(missingVarNames)
                thisName = missingVarNames{iVarName};
                thisRowIndex = getRowIndex(refVariableAttributes, thisName);

                if refVariableAttributes{thisRowIndex, 'HasUpdateFunction'}
                    fcnName = refVariableAttributes{thisRowIndex, 'UpdateFunctionName'}{1};
                    fcnResult = feval(fcnName);
                    if isa(fcnResult, 'nansen.metadata.abstract.TableVariable')
                        defaultValue = fcnResult.DEFAULT_VALUE;
                    else
                        defaultValue = fcnResult;
                    end
                    metaTable.addTableVariable(thisName, defaultValue)
                end
            end
        end
        
        function metaTable = removeMissingVarsFromMetaTable(app, metaTable, metaTableType)
        %removeMissingVarsFromMetaTable Remove variable from table if it is missing.
        %
        %   If a table is missing from the table variable definitions, but
        %   is present in the table, this functions asks the user if the variable
        %   should be removed from the table.
        %
        %   If the user selects "Yes" the variable is deleted from the
        %   table. If the user selects no, the a non-editable dummy
        %   variable is placed in the table variable folder for the current
        %   project.

            import nansen.metadata.utility.createClassForCustomTableVar
            
            tableVarNames = metaTable.entries.Properties.VariableNames;
            
            variableAttributes = app.CurrentProject.getTable('TableVariable');
            variableAttributes(variableAttributes.TableType ~= metaTableType, :) = [];
            
            % Get custom (user-defined) and default table variables
            isCustom = variableAttributes.IsCustom;
            customVariableNames = variableAttributes{isCustom, 'Name'};
            defaultVariableNames = variableAttributes{~isCustom, 'Name'};
            
            % Get those variables present in the table that are not default
            customVariablesInTable = setdiff(tableVarNames, defaultVariableNames);
            
            % Find the difference between those and the user-defined
            % variables, i.e if the user-defined variables were removed
            % from the table variable folders.
            missingVarNames = setdiff(customVariablesInTable, customVariableNames);
            
            % Display a prompt to the user if any table variables have been
            % removed. If user does not want to removed those variables,
            % create a dummy function for that table var.
            
            for iVarName = 1:numel(missingVarNames)
                thisName = missingVarNames{iVarName};

                message = sprintf( ['The tablevar definition is missing ', ...
                    'for "%s". Do you want to delete data for this variable ', ...
                    'from the table?'], thisName );
                title = 'Delete Table Data?';
                
                %answer = questdlg(message, title);
                answer = app.openQuestionDialog(message, title);

                switch answer
                    case 'Yes'
                        metaTable.removeTableVariable(thisName)
                        metaTable.save()
                    case {'Cancel', 'No', ''}
                        
                        % Todo (Is it necessary): Maybe if the variable is
                        % editable...(which we dont know when the definition
                        % is removed.) Should resolve based on user
                        % feedback/tests
                        
                        % Get table row as struct in order to check data
                        % type. (Some data is within a cell array in the table)
                        tableRow = metaTable.entries(1, :);
                        rowAsStruct = table2struct(tableRow);
                        
                        % Create dummy function
                        S = struct();
                        S.VariableName = thisName;
                        S.MetadataClass = metaTableType;
                        S.DataType = class(rowAsStruct.(thisName));
                        
                        S.InputMode = '';
                        
                        targetFolderPath = app.CurrentProject.getTableVariableFolder();
                        createClassForCustomTableVar(S, targetFolderPath)
                end
            end
        end

        function onMetaTableModifiedChanged(app, src, evt)
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
                if ~strcmp(app.ApplicationState, 'Uninitialized')
                    message = sprintf('The configuration of the current project (%s) is not completed (metatable is missing)', projectName);
                    title = 'Aborted';
                    app.openMessageBox(message, title)
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
                metaTable = app.checkIfMetaTableComplete(metaTable);
                
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
                                
% %                 if app.initialized % todo
% %                     app.updateRelatedInventoryLists()
% %                 end
            catch ME
                app.openErrorDialog(ME.message, 'Could Not Load Session Table')
                disp(getReport(ME, 'extended'))
            end
            
            % Add name of loaded inventory to figure title
            if ~isempty(app.Figure)
                app.updateFigureTitle();
            end
            
            app.updateMetaTableMenu()
        end
        
        function saveMetaTable(app, src, ~, forceSave)
            
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
        
        function tf = checkIfSubjectTableExists(app, metaTableCatalog)
            existingClasses = unique( metaTableCatalog.Table.MetaTableClass );
            % Todo: generalize, i.e are there subclasses (project specific subject definitions?)
            tf = any(strcmp(existingClasses, 'nansen.metadata.type.Subject'));
        end

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
            qstring = sprintf(['The session table for project "%s" has ', ...
                'unsaved changes. Do you want to save changes to the ', ...
                'table?'], currentProjectName);
            
            title = 'Save changes to table?';
            alternatives = {'Save', 'Don''t Save', 'Cancel'};
            default = 'Save';
            
            %answer = questdlg(qstring, title, alternatives{:}, default);
            answer = app.openQuestionDialog(qstring, title, alternatives{:}, default);
            
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
            qstring = 'The app is busy with something. Do you want to quit anyway?';
            
            title = 'Confirm Quit?';
            alternatives = {'Yes', 'No'};
            default = 'Yes';
            
            %answer = questdlg(qstring, title, alternatives{:}, default);
            answer = app.openQuestionDialog(qstring, title, alternatives{:}, default);
            doExit = strcmp(answer, 'Yes');
        end
    end
    
    methods (Access = protected) % Callbacks

        %onSettingsChanged Callback for change of fields in settings
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
            if ~strcmp(app.UiMetaTableViewer.MetaTableType, app.MetaTable.getTableType())
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
            [cleanUpObj, logfile] = app.BatchProcessor.initializeTempDiaryLog(); %#ok<ASGLU,NASGU>
            
            newTask.timeStarted = datetime(now,'ConvertFrom','datenum');

            % Prepare arguments for the session method
            %app.prepareSessionMethodArguments() %todo
            
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
                            % Todo
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
                        
                    %functionName = taskConfiguration.TaskAttributes.FunctionName;
                    %app.SessionTaskMenu.refreshMenuItem(functionName) % todo
    
                    % Todo: Only refresh this submenu.
                    % Todo: Only refresh if options sets were added.

                elseif strcmp(taskType, 'function')
                    
                    if isempty(fieldnames(opts))
                        app.openMessageBox('This method does not have any parameters')
                        wasAborted = true;
                    else
                        optManager = taskConfiguration.TaskAttributes.OptionsManager;
                        %optManager = nansen.manage.OptionsManager(functionName, opts, optsName);
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

        function taskName = createTaskName(~, sessionObjects)
                
            if numel(sessionObjects) > 1
                taskName = 'Multisession';
            else
                try % Todo: Use metatable class to determine variablename of id
                    taskName = sessionObjects.sessionID;
                catch
                    taskName = sessionObjects.id;
                end
            end
        end

        function createBatchList2(app, mode)
            
            figName = sprintf( 'List of %s Tasks', mode);
            f = figure('MenuBar', 'none', 'Name', figName, 'NumberTitle', 'off', 'Visible', 'off');
            %h = nansen.TaskProcessor('Parent', f)
            
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
                app.openMessageBox('No tasks were found')
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
                app.openMessageBox('No tasks were found')
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
        
        % Todo: Make a setting to specify which session definition to use
        % for creating a session object.
        function ndiSessionObj = getNdiSessionObj(app, sessionObj)
            dataLocation = sessionObj.getDataLocation('Rawdata');
            dirPath = dataLocation.RootPath;
            
            ndiSessionObj = ndi.session.dir('ts_exper', dirPath);
        end
    end
    
    methods (Access = protected) % Menu Callbacks

        function menuCallback_DetectSessions(app, src, evtData)

            % Default to use the first datalocation or all?
            %dataLocationName = app.DataLocationModel.Data(1).Name;
            dataLocationName = 'all';
            newSessionObjects = nansen.manage.detectNewSessions(app.MetaTable, dataLocationName);
            
            if isempty(newSessionObjects)
                app.openMessageBox('No sessions were detected')
                return
            end
            
            % Initialize a MetaTable using the given session schema and the
            % detected session folders.
            tmpMetaTable = nansen.metadata.MetaTable.new(newSessionObjects);
            tmpMetaTable = app.addMissingVarsToMetaTable(tmpMetaTable, 'session');
            
            % Find all that are not part of existing metatable
            app.MetaTable.appendTable(tmpMetaTable.entries)
            app.MetaTable.save()
            
            app.UiMetaTableViewer.refreshTable(app.MetaTable)
            
            app.openMessageBox(sprintf('%d sessions were successfully added', numel(newSessionObjects)))
            % Display sessions that were added on the commandline
            fprintf('The following sessions were added: \n%s\n', strjoin({newSessionObjects.sessionID}, '\n'))
        
            MTC = app.CurrentProject.MetaTableCatalog;
            nansen.manage.updateSubjectTable(MTC);
        end
        
        function onNewProjectMenuClicked(app, src, evt)
        %onNewProjectMenuClicked Let user add a new project
        
            import nansen.config.project.ProjectManagerUI

            switch src.Text
                case 'Create...'
                    % Todo: open setup from create project page
                    
                    msg = 'This will close the current app and open nansen setup. Do you want to continue?';
                    %answer = questdlg(msg, 'Close and continue?');
                    answer = app.openQuestionDialog(msg, 'Close and continue?');
                    
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
        
        function onChangeProjectMenuClicked(app, src, ~)
        %onChangeProjectMenuClicked Let user change current project
            app.changeProject(src.Text)
        end
        
        function onManageProjectsMenuClicked(app, src, evt)
            
            % Todo: Create the ProjectManagerApp
            import nansen.config.project.ProjectManagerUI

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
        
        function onOpenProjectFolderMenuClicked(app, src, evt)
            project = app.ProjectManager.getProject(app.ProjectManager.CurrentProject);
            utility.system.openFolder(project.Path)
        end

        function onChangeCurrentFolderMenuClicked(app, src, evt)
            
            switch src.Text
                case 'Current Project'
                    cd(app.CurrentProject.FolderPath)
                case 'Nansen'
                    cd(nansen.toolboxdir)
            end
        end

        function MenuCallback_CloseAll(app, ~, ~)
            state = get(app.Figure, 'HandleVisibility');
            set(app.Figure, 'HandleVisibility', 'off')
            close all
            set(app.Figure, 'HandleVisibility', state)
        end
        
        function updateRelatedInventoryLists(app, mItem)
            
            if nargin < 2
                mItem(1) = findobj(app.Figure, 'Tag', 'Open Metatable');
                mItem(2) = findobj(app.Figure, 'Tag', 'Add to Metatable');
            else
                
            end

            names = app.MetaTable.getAssociatedMetaTables('same_class');
            
            for i = 1:numel(mItem)
                delete(mItem(i).Children)
                
                switch mItem(i).Tag
                    case 'Open Metatable'
                        for j = 1:numel(names)
                            uimenu(mItem(i), 'Text', names{j}, 'Callback', @app.MenuCallback_OpenMetaTable)
                        end
                        
                    case 'Add to Metatable'
                        namesTmp = cat(1, {'New Metatable...'}, names);
            
                        for j = 1:numel(namesTmp)
                            if j == 2
                                uimenu(mItem(i), 'Text', namesTmp{j}, 'Callback', @app.addSessionToMetatable, 'Separator', 'on')
                            else
                                uimenu(mItem(i), 'Text', namesTmp{j}, 'Callback', @app.addSessionToMetatable)
                            end
                        end
                end
            end
        end
        
        function addSessionToMetatable(app, src, ~)
            
            % Find session ids of currently highlighted rows
            sessionEntries = app.getSelectedMetaObjects;
            
            switch src.Text
                
                case 'New Metatable...'
                    % Add session to new database
                    metaTable = app.MenuCallback_CreateMetaTable();
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

        function metatable = MenuCallback_CreateMetaTable(app, src, evt)
            
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
            isMaster = catalogTable.IsMaster; %#ok<PROP>
            
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
        
        function MenuCallback_OpenMetaTable(app, src, ~)
            
            metaTableName = src.Text;
            app.openMetaTable(metaTableName)
        end
        
        function onMetaTableTypeChanged(app, src, evt)
            metaTableName = src.Text;
            app.resetMetaObjectList()
            app.openMetaTable(metaTableName)
        end

        function onSetDefaultMetaTableMenuItemClicked(app, src, evt)
            app.MetaTable.setDefault()
            app.updateRelatedInventoryLists()
        end
        
        function onUpdateSessionListMenuClicked(app, src, evt)

        end
        
        function onAddNewPipelineTaskMenuItemClicked(obj, src, event)
            
            % Open uidialog for creating new task
            %   name input
            %   function name input (search among all functions that are session methods...)
            %   options (update dropdown when function name is selected.
            
            % Get task catalog (from props?) and add new task

            % Make sure task catalog is up to date in other parts of app.
            
        end
        
        function onCreateNewPipelineMenuItemClicked(app, src, event)
            % Open uidialog for creating new pipeline
            hUi = nansen.pipeline.uiCreatePipeline();
            if isempty(hUi); return; end
            
            uiwait(hUi.Figure)
            
            app.updatePipelineItemsInMenu()
            
            % Todo: uiwait, and update pipeline names in menu for editing
            % pipelines.
        end
        
        function onEditPipelinesMenuItemClicked(app, src, event)
        %onEditPipelinesMenuItemClicked Lets user edit pipeline
            
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
        
        function onConfigPipelineAssignmentMenuItemClicked(app, src, event)
            nansen.pipeline.PipelineAssignmentModelApp
        end

        function onCreateSessionMethodMenuClicked(app, src, evt)
        %onCreateSessionMethodMenuClicked Menu callback
            import nansen.session.methods.template.createNewSessionMethod
            
            wasSuccess = createNewSessionMethod(app);
            
            % Update session menu!
            if wasSuccess
                app.SessionTaskMenu.refresh()
            end
        end

        function onCreateFileAdapterMenuClicked(app)
        %onCreateFileAdapterMenuClicked Menu callback

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
        
        function onRefreshSessionMethodMenuClicked(app, src, evt)
            app.SessionTaskMenu.refresh()
        end
        
        function onRefreshTableMenuItemClicked(app, ~, ~)
             
            returnToIdle = app.setBusy('Updating table'); %#ok<NASGU>
            %uipopup(app.Figure, 'Updating table')
            resetView = false;
            app.UiMetaTableViewer.resetTable(resetView)
            onNewMetaTableSet(app)
        end

        function onClearMemoryMenuClicked(app, ~, ~)
            app.resetMetaObjectList()
        end
        
        function onOpenFigureMenuClicked(app, packageName, figureName)
            
            % Create function call...
            fcn = figurePackage2Function(packageName, figureName);
            hFigure = fcn();
            
            tabNames = {app.hLayout.TabGroup.Children.Title};
            isFigureTab = strcmp(tabNames, 'Figures');
            hFigure.reparent(app.hLayout.TabGroup.Children(isFigureTab))
        end
    end
    
    methods (Hidden, Access = private) % Internal methods for app deletion
        
        function saveFigurePreferences(app)
                
                MP = get(0, 'MonitorPosition');
                nMonitors = size(MP, 1);
                
                if nMonitors > 1
                    ML = uim.utility.pos2lim(MP); % Monitor limits
                    figureLocation = app.Figure.Position(1:2);
                    
                    isOnScreen = all( figureLocation > ML(:, 1:2) & figureLocation < ML(:, 3:4) , 2);
                    currentScreenNum = find(isOnScreen);
                    
                    if ~isempty(currentScreenNum)
                        app.setPreference('PreferredScreen', currentScreenNum) %#ok<FNDSB>
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

            projectObj.saveData('MetatableColumnSettings', columnSettings)
        end

        function columnSettings = loadMetatableColumnSettingsFromProject(app)

            currentProjectName = app.ProjectManager.CurrentProject;
            projectObj = app.ProjectManager.getProjectObject(currentProjectName);

            columnSettings = projectObj.loadData('MetatableColumnSettings');
        end
    end
    
    % Display Customization
    methods (Access=protected)
        
        function propGroup = getPropertyGroups(obj)
            
            titleTxt = ['Nansen Properties: '...
                '(<a href = "matlab: helpPopup nansen.App">'...
                'Nansen Documentation</a>)'];
            thisProps = {
                'AppName'
                'Theme'
                'Modules'
                };
            propGroup = matlab.mixin.util.PropertyGroup(thisProps,titleTxt);
            
        end %function
    end

    methods (Access = private) % Assertions

        function assertSessionSelected(app)

            entryIdx = app.UiMetaTableViewer.getSelectedEntries();
            
            if isempty(entryIdx)
                msg = 'No sessions are selected. Select one or more sessions for this operation.';
                app.openMessageBox(msg, 'Session Selection Required')
                error('NansenApp:SessionSelectionRequired', msg)
            end
        end
    end
   
    methods (Access = private) % Open dialog windows. Todo: make separate class
        
        function openMessageBox(app, messageStr, titleStr)
            
            % Todo: Specify icons in inputs...
            
            messageStr = app.getFormattedMessage(messageStr);
            opts = app.getDialogOptions();
            
            if nargin < 3
                msgbox(messageStr, opts)
            elseif nargin == 3
                msgbox(messageStr, titleStr, opts)
            end
        end
        
        function answer = openQuestionDialog(app, varargin)
        %openQuestionDialog Open a question dialog window
        %
        %   app.openQuestionDialog(message)
        
            messageStr = app.getFormattedMessage(varargin{1});
            varargin = varargin(2:end);
            opts = app.getDialogOptions();
            
            if numel(varargin) > 1
                if contains(varargin{end}, varargin)
                    opts.Default = varargin{end};
                    varargin(end) = [];
                else
                    error('Invalid inputs for openQuestionDialog')
                end
            else
                opts.Default = 'Yes';
            end
            answer = questdlg(messageStr, varargin{:}, opts);
        end
        
        function openInputDialog()
            
        end
        
        function openErrorDialog(app, messageStr, titleStr)
                    
            if nargin < 3
                titleStr = 'Error';
            end
            
            messageStr = app.getFormattedMessage(messageStr);
            opts = app.getDialogOptions();
            errordlg(messageStr, titleStr, opts)
        end
        
        function formattedMessage = getFormattedMessage(~, message)
            formattedMessage = strcat('\fontsize{14}', message);
            
            % Fix some characters that are interpreted as tex markup
            formattedMessage = strrep(formattedMessage, '_', '\_');
        end
        
        function opts = getDialogOptions(~)
            opts = struct('WindowStyle', 'modal', 'Interpreter', 'tex');
        end
        
        function throwSessionMethodFailedError(app, ME, taskName, methodName)
            
            % Todo: Use a messagebox widget to show error message
            
            errorMessage = sprintf('Method ''%s'' failed for session ''%s'', with the following error:\n', ...
                methodName, taskName);
            
            % Show error message in user dialog
            app.openErrorDialog(sprintf('%s\n%s', errorMessage, ME.message))
            
            % Display error stack for better chance at debugging
            disp(getReport(ME, 'extended'))
        end
    end
    
    methods (Static)
    
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
    
    methods (Static) % Method defined in separate file
        S = getDefaultSettings()
    end

    methods (Static)

        function [jLabel, C] = showSplashScreen()
            error('not implemented yet')
% %             jLabel = simpleLogger;
% %             C = []; return

            filepath = fullfile(nansen.toolboxdir, 'resources', ...
                'images', 'nansen_splash.png'); % NB nansen_splash does not exist yet
            [~, jLabel, C] = nansen.ui.showSplashScreen(filepath, ...
                'NAnSEn', 'Initializing nansen...');
        end
    end
end
