classdef App < uiw.abstract.AppWindow & nansen.mixin.UserSettings & ...
                    applify.HasTheme

    % Todo: 
    %   [ ] Make method for figure title name
    %   [ ] More methods/options for updating statusfield. Timers, progress
    %   [ ] Make sure that project directory is on path on startup or when
    %       project is changed...
    %   [ ] Create Menu in separate function.
    %   [ ] Update menu or submenu using call to that function
    %   [x] Remove vars from table on load if vars are not represented in
    %       tablevar folder.
    
    

    properties (Constant, Access=protected) % Inherited from uiw.abstract.AppWindow
        AppName char = 'Nansen'
    end
    
    properties (Constant, Hidden = true) % move to appwindow superclass
        DEFAULT_THEME = nansen.theme.getThemeColors('dark-gray');
    end
    
    properties (Constant)
        Pages = {'Overview', 'File Viewer', 'Data Processing'}
    end
    
    properties % Page modules
        UiMetaTableViewer
        UiFileViewer
        UiProcessor
    end
    
    properties (Constant, Hidden = true) % Inherited from UserSettings
        USE_DEFAULT_SETTINGS = false % Ignore settings file                      Can be used for debugging/dev or if settings should be consistent.
        DEFAULT_SETTINGS = nansen.App.getDefaultSettings() % Struct with default settings
    end 
    
    properties (Hidden, Access = private) % Window
        MinimumFigureSize
        IsIdle
        TaskInitializationListener
    end

    properties
        MetaTablePath = ''
        MetaTable 
        Modules
        SessionTasks matlab.ui.container.Menu
        SessionTaskMenu
        SessionContextMenu
        
        MessagePanel
        MessageBox
    end
    
    properties
        CurrentSelection     % Current selection of data objects.
        WindowKeyPressedListener
        Timer
    end
    
    
    methods % Structors
        function app = App()

            % Call constructor explicitly to provide the nansen.Preferences
            app@uiw.abstract.AppWindow('Preferences', nansen.Preferences)
            
            setappdata(app.Figure, 'AppInstance', app)
            
            %app.loadSettings()
            
            app.loadMetaTable()
            
            
            %Todo: Should be part of project manager...

            % Add project folder to path. 
            projectPath = nansen.localpath('Current Project');
            addpath(genpath(projectPath)) % todo. dont brute force this..
            
            

            app.switchJavaWarnings('off')
            
            app.configureWindow()
            app.configFigureCallbacks()
            
            app.createMenu()
            app.createLayout()
            app.createComponents()
            app.createMessagePanel()
            
            app.switchJavaWarnings('on')
            
            % Add this callback after every component is made
            app.Figure.SizeChangedFcn = @(s, e) app.onFigureSizeChanged;
            
%             app.initialized = true;
            app.setIdle()
            
            if nargout == 0
                clear app
            end
            
        end
        
        function delete(app)
            
            delete(app.UiMetaTableViewer)
            delete(app.UiProcessor)
            
            if app.settings.MetadataTable.AllowTableEdits
                app.saveMetaTable()
            end
            
            if ~isempty(app.Figure) && isvalid(app.Figure)
                app.saveFigurePreferences()
            end
            
        end
        
        function onExit(app, h)
            
%             if ~isempty(app.queueProcessorObj)
%                 if strcmp(app.queueProcessorObj.Status, 'running')
%                     answer = questdlg('Tasks are still running. Are you sure you want to quit?', 'Think Twice', 'Yes', 'No', 'Yes');
%                     switch lower(answer)
%                         case 'no'
%                             return
%                     end
%                 end
%             end

            % Todo: Whis is called twice, because of some weird reason
            % in (uiw.abstract.BaseFigure?)
            
            % Todo: Save settings and inventories...
            % app.saveMetaTable()
            
            app.onExit@uiw.abstract.AppWindow(h);

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
            app.Figure.WindowKeyPressFcn = @app.onKeyPressed;
            app.Figure.WindowKeyReleaseFcn = @app.onKeyReleased;
            
            [~, hJ] = evalc('findjobj(app.Figure)');
            hJ(2).KeyPressedCallback = @app.onKeyPressed;
            hJ(2).KeyReleasedCallback = @app.onKeyReleased;
            
        end
        
        function createMenu(app)
        %createMenu Create menu components for the main gui.
    
        
            % Create a software menu
            m = uimenu(app.Figure, 'Text', 'Nansen');
            
            
            
            % % % % % % Create menu items for PROJECTS % % % % % % 
            
            mitem = uimenu(m, 'Text','New Project');
            uimenu( mitem, 'Text', 'Create New...', 'MenuSelectedFcn', @app.onNewProjectMenuClicked);
            uimenu( mitem, 'Text', 'Add Existing...', 'MenuSelectedFcn', @app.onNewProjectMenuClicked);
            
            mitem = uimenu(m, 'Text','Change Project');
            app.updateProjectList(mitem)
            
            mitem = uimenu(m, 'Text','Manage Projects');
            mitem.MenuSelectedFcn = @app.onManageProjectsMenuClicked;
            

            % % % % % % Create menu items for CONFIGURATION % % % % % % 
            
            mitem = uimenu(m, 'Text','Configure', 'Separator', 'on', 'Enable', 'on');
            uimenu( mitem, 'Text', 'Configure Datalocation', 'MenuSelectedFcn', @(s,e)nansen.config.dloc.DataLocationModelApp);
            uimenu( mitem, 'Text', 'Configure Variables', 'MenuSelectedFcn', [], 'Enable', 'off');
            
            %mitem.MenuSelectedFcn = [];
            
            mitem = uimenu(m, 'Text','Preferences');
            mitem.MenuSelectedFcn = @(s,e) app.editSettings;
            
            
            mitem = uimenu(m, 'Text','Close All Figures', 'Separator', 'on');
            mitem.MenuSelectedFcn = @app.menuCallback_CloseAll;
            
            mitem = uimenu(m, 'Text', 'Quit');
            mitem.MenuSelectedFcn = @(s, e) app.delete;
        

            % Create a "Manage" menu
            m = uimenu(app.Figure, 'Text', 'Manage');
            
            mitem = uimenu(m, 'Text', 'Create New Metatable...', 'Enable', 'off');
            mitem.MenuSelectedFcn = @app.menuCallback_CreateDb;
            
            mitem = uimenu(m, 'Text','Open Metatable', 'Separator', 'on', 'Tag', 'Open Database', 'Enable', 'off');
            %app.updateRelatedInventoryLists(mitem)

            
            % % % Create menu items for METATABLE loading and saving % % %
            
            mitem = uimenu(m, 'Text','Load Metatable...', 'Enable', 'off');
            mitem.MenuSelectedFcn = @app.menuCallback_LoadDb;
            mitem = uimenu(m, 'Text','Refresh Metatable', 'Enable', 'off');
            mitem.MenuSelectedFcn = @(src, event) app.reloadExperimentInventory;
            mitem = uimenu(m, 'Text','Save Metatable', 'Enable', 'off');
            mitem.MenuSelectedFcn = @app.saveExperimentInventory;
            mitem = uimenu(m, 'Text','Save Metatable As', 'Enable', 'off');
            mitem.MenuSelectedFcn = @app.saveExperimentInventory;
            
            mitem = uimenu(m, 'Text','Autodetect sessions', 'Separator', 'on');
            mitem.Callback = @(src, event) app.menuCallback_DetectSessions;

% %             mitem = uimenu(m, 'Text','Import from Excel', 'Separator', 'on', 'Enable', 'on');
% %             mitem.MenuSelectedFcn = @app.menuCallback_ImportTable;
% %             mitem = uimenu(m, 'Text','Export to Excel');
% %             mitem.MenuSelectedFcn = @app.menuCallback_ExportToTable;
            
            

            % Todo: get modules from different packages and assemble in a 
            % struct before creating the menus..
            
            
        
            % Create a "Session" menu
            m = uimenu(app.Figure, 'Text', 'Table');
            app.createSessionInfoMenus(m)


            menuRootPath = fullfile(nansen.rootpath, '+session', '+methods');
            
            app.SessionTaskMenu = nansen.SessionTaskMenu(app);
            
            l = listener(app.SessionTaskMenu, 'MethodSelected', ...
                @app.onSessionTaskSelected);
            app.TaskInitializationListener = l;
            
            
            % app.createMenuFromDir(app.Figure, menuRootPath)
            
            return
            
            m = uimenu(app.UIFigure,'Text', 'Options');

            mitem = uimenu(m, 'Text','Edit Inventory Settings');
            mitem.MenuSelectedFcn = @app.menuCallback_EditSettings;
            mitem = uimenu(m, 'Text','Edit Browser Settings');
            mitem.MenuSelectedFcn = @app.menuCallback_EditSettings;
            mitem = uimenu(m, 'Text','Change Table Layout');
            mitem.MenuSelectedFcn = @app.menuCallback_EditSettings;
            mitem = uimenu(m, 'Text','Edit Search/Filter History');
            mitem.MenuSelectedFcn = @app.menuCallback_EditSettings;
            
        end
        
        function updateProjectList(app, mItem)
        %updateProjectList Update lists of projects in uicomponents
            
            if nargin < 2
                mItem = findobj(app.Figure, 'Type', 'uimenu', '-and', 'Text', 'Change Project');
            end
            
            pm = nansen.ProjectManager;
            names = {pm.Catalog.Name};
            
            if ~isempty(mItem.Children)
                delete(mItem.Children)
            end

            for i = 1:numel(names)
                msubitem = uimenu(mItem, 'Text', names{i});
                msubitem.MenuSelectedFcn = @app.onChangeProjectMenuClicked;
                if strcmp(names{i}, getpref('Nansen', 'CurrentProject'))
                    msubitem.Checked = 'on';
                end
            end

        end
        
        function createSessionInfoMenus(app, hMenu, updateFlag)
            
            import nansen.metadata.utility.getPublicSessionInfoVariables

            if nargin < 3
                updateFlag = false;
            end
            
            if nargin < 2 || isempty(hMenu)
                hMenu = findobj(app.Figure, 'Type', 'uimenu', '-and', 'Text', 'Table');
            end
            
            if updateFlag
                delete(hMenu.Children)
            end
            
            
            mitem = uimenu(hMenu, 'Text','Add New Variable...');
            mitem.MenuSelectedFcn = @(s,e, cls) app.addTableVariable('session');

% %             menuAlternatives = {'Enter values manually...', 'Get values from function...', 'Get values from dropdown...'};
% %             for i = 1:numel(menuAlternatives)
% %                 hSubmenuItem = uimenu(mitem, 'Text', menuAlternatives{i});
% %                 hSubmenuItem.MenuSelectedFcn = @(s,e, cls) app.addTableVariable('session');
% %             end
            
            mitem = uimenu(hMenu, 'Text','Manage Variables...', 'Enable', 'off');
            
            
            mitem = uimenu(hMenu, 'Text', 'Create New Session Method', 'Separator', 'on');
            mitem.MenuSelectedFcn = @app.onCreateSessionMethodMenuClicked;

            mitem = uimenu(hMenu, 'Text', 'Refresh Session Methods');
            mitem.MenuSelectedFcn = @app.onRefreshSessionMethodMenuClicked;

            
            
% %             mitem = uimenu(hMenu, 'Text','Edit Table Variable Definition');            
% %             columnVariables = getPublicSessionInfoVariables(app.MetaTable);
% % 
% %             for iVar = 1:numel(columnVariables)
% %                 hSubmenuItem = uimenu(mitem, 'Text', columnVariables{iVar});
% %                 hSubmenuItem.MenuSelectedFcn = @app.editTableVariableDefinition;
% %             end
% %             
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
        
            L = dir(dirPath);
            L = L(~strncmp({L.name}, '.', 1));
            
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
                    if ~isempty(meta.class.fromName(functionName))
                        className = strjoin({packageName, fileName}, '.');
                        methods = findPropertyWithAttribute(className, 'Constant');
                                           
                        iSubMenu = uimenu(hParent, 'Text', name);
                        for j = 1:numel(methods)
                            name = varname2label(methods{j});
                            iMitem = uimenu(iSubMenu, 'Text', name);
                            hfun = str2func(functionName);
                            iMitem.MenuSelectedFcn = @(s, e, h, kwd) app.menuCallback_SessionMethod(hfun, methods{j});
                        
                        end

                    else
                        hfun = str2func(functionName);
                    
                        iMitem = uimenu(hParent, 'Text', name);
                        iMitem.MenuSelectedFcn = @(s, e, h) app.menuCallback_SessionMethod(hfun);
                        
                    end
                    
                    app.SessionTasks(end+1) = iMitem;
                    
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
            app.createSessionInfoMenus([], true)
        end
        
        function createLayout(app)
            
%             app.hLayout.TopBorder = uipanel('Parent', app.Figure);
%             app.hLayout.TopBorder.BorderType = 'none';
%             app.hLayout.TopBorder.BackgroundColor = [0    0.3020    0.4980];
            
            app.hLayout.MainPanel = uipanel('Parent', app.Figure);
            app.hLayout.MainPanel.BorderType = 'none';
            
            app.hLayout.SidePanel = uipanel('Parent', app.Figure);
            %app.hLayout.SidePanel.BorderType = 'none';
            app.hLayout.SidePanel.Units = 'pixels';
            app.hLayout.SidePanel.Visible = 'off';
            
            app.hLayout.StatusPanel = uipanel('Parent', app.Figure);
            app.hLayout.StatusPanel.BorderType = 'none';
            
            app.hLayout.TabGroup = uitabgroup(app.hLayout.MainPanel);
            app.hLayout.TabGroup.Units = 'pixel';
            app.updateLayoutPositions()
            
        end
        
        function createComponents(app)
                  
            app.createTabPages()

            app.createStatusField()
            
            app.createSidePanelComponents()
            
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
            app.h.StatusField.Position = [0,-0.15,1,1];
            
            app.h.StatusField.String = ' Status : Idle';
            app.h.StatusField.BackgroundColor = ones(1,3).*0.85;
            app.h.StatusField.HorizontalAlignment = 'left';
            
        end
        
        function createTabPages(app)
            
            for i = 1:numel(app.Pages)
                
                pageName = app.Pages{i};
                
                hTab = uitab(app.hLayout.TabGroup);
                hTab.Title = pageName;
                
                switch pageName
                    case 'Overview'
                        app.createMetaTableViewer(hTab)
                        
                        
                    case 'File Viewer'
                        h = nansen.FileViewer(hTab);
                        app.UiFileViewer = h;
                    case 'Data Processing'
                        h = nansen.TaskProcessor('Parent', hTab);
                        app.UiProcessor = h;

                        
                end
            end
            
            % Add a callback function for when tab selection is changed
            app.hLayout.TabGroup.SelectionChangedFcn = @app.onTabChanged;

        end
        
        function createMetaTableViewer(app, hTab)
            
            % Prepare inputs
            S = app.settings.MetadataTable;
            nvPairs = utility.struct2nvpairs(S);
            nvPairs = [{'AppRef', app}, nvPairs];
           
            % Create table + assign to property + set callback
            h = nansen.MetaTableViewer(hTab, app.MetaTable, nvPairs{:});
            app.UiMetaTableViewer = h;
            h.CellEditCallback = @app.onMetaTableDataChanged;
            
            % Add keypress callback to uiw.Table object
            h.HTable.KeyPressFcn = @app.onKeyPressed;
            %h.HTable.MouseMotionFcn = @(s,e) onMouseMotionInTable(h, s, e);
            
            addlistener(h.HTable, 'MouseMotion', @app.onMouseMoveInTable);
            
            h.UpdateColumnFcn = @app.updateTableVariable;
            h.DeleteColumnFcn = @app.removeTableVariable;

            app.createSessionTableContextMenu()
            
        end
        
        function onMouseMoveInTable(app, src, evt)
            
            thisRow = evt.Cell(1);
            thisCol = evt.Cell(2);
            
            if thisRow == 0 || thisCol == 0
                return
            end
            
            colNames = app.UiMetaTableViewer.ColumnModel.getColumnNames;
            thisColumnName = colNames{thisCol};
            
            
            % Todo: This SHOULD NOT be hardcoded like this...
            if contains(thisColumnName, {'Notebook', 'Progress', 'DataLocation'})
                dispFcn = str2func(strjoin({'nansen.metadata.tablevar', thisColumnName}, '.') );
                
                tableRow = app.UiMetaTableViewer.getMetaTableRows(thisRow);
                
                tableValue = app.MetaTable.entries{tableRow, thisColumnName};
                tmpObj = dispFcn(tableValue);
                
                str = tmpObj.getCellTooltipString();
            else
                str = '';
            end

            set(app.UiMetaTableViewer.HTable.JTable, 'ToolTipText', str)
        end
        
        function createSidePanelComponents(app)
            
            uicc = uim.UIComponentCanvas(app.hLayout.SidePanel);

            buttonSize = [21, 51];
            options = {'PositionMode', 'auto', 'SizeMode', 'manual', 'Size', buttonSize, ...
                'HorizontalTextAlignment', 'center', 'Icon', '>', ...
                'Location', 'west', 'Margin', [0, 15, 0, 0], ...
                'Callback', @(s,e) app.hideSidePanel() };
            
            closeButton = uim.control.Button_(app.hLayout.SidePanel, options{:} );
            
        end
    end
    
    methods % Set/get methods
        function set.MetaTable(app, newTable)
            app.MetaTable = newTable;
            app.onNewMetaTableSet()
        end
    end
    
    methods
        
        function changeProject(app, varargin)
            
            app.UiMetaTableViewer.refreshTable(table.empty, true)
            drawnow
            disp('Changing project is a work in progress. Some things might not work as expected.')
            
            app.loadMetaTable()
            drawnow
            
            app.SessionTaskMenu.refresh()
            
            % Make sure project list is displayed correctly
            % Indicating current project
            app.updateProjectList()
            
            % Todo: 
            
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
        
        function metaObjects = getSelectedMetaObjects(app)
                        
            entries = app.getSelectedMetaTableEntries();
            metaObjects = app.tableEntriesToMetaObjects(entries);
            
        end
        
        function metaObjects = tableEntriesToMetaObjects(app, entries)
        %tableEntriesToMetaObjects Create meta objects from table rows
        
            schema = str2func(class(app.MetaTable));
            
            if isempty(entries)
                expression = strjoin({class(app.MetaTable), 'empty'}, '.');
                metaObjects = eval(expression);
            else
                metaObjects = schema(entries);
                addlistener(metaObjects, 'PropertyChanged', @app.onMetaObjectPropertyChanged);
            end
            
        end
        
        function onMetaObjectPropertyChanged(app, src, evt)
            
            % Todo: generalize from session
            % Todo: make method for getting table entry from sessionID
            sessionID = src.sessionID;
            metaTableEntryIdx = find(strcmp(app.MetaTable.members, sessionID));
            app.MetaTable.editEntries(metaTableEntryIdx, evt.Property, evt.NewValue)
            
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
        end
        
        function onTabChanged(app, src, evt)
            
            switch evt.NewValue.Title
                
                case 'File Viewer'
                    entries = getSelectedMetaTableEntries(app);
                    if isempty(entries); return; end
                    app.UiFileViewer.update(entries(1, :))
                    
            end
            
        end
        
        function onMousePressed(app, src, evt)
        end
       
        function onKeyPressed(app, src, evt)
            
            if isa(evt, 'java.awt.event.KeyEvent')
                evt = uim.event.javaKeyEventToMatlabKeyData(evt);
            end
            
            
            switch evt.Key
                
                case 'shift'
                    app.SessionTaskMenu.Mode = 'Preview';
                case 'q'
                    app.SessionTaskMenu.Mode = 'TaskQueue';
                case 'e'
                    app.SessionTaskMenu.Mode = 'Edit';
                    
                case 'w'
                    app.sendToWorkspace()
            end
            
        end
        
        function onKeyReleased(app, src, evt)
            
            if isa(evt, 'java.awt.event.KeyEvent')
                evt = uim.event.javaKeyEventToMatlabKeyData(evt);
            end
            
            switch evt.Key
                case {'shift', 'q', 'e'}
                    app.SessionTaskMenu.Mode = 'Default';
                    
            end

        end
        
        function updateLayoutPositions(app)
            
            figPosPix = getpixelposition(app.Figure);
           
            w = figPosPix(3);
            h = figPosPix(4);
            
            normalizedHeight = 20 / figPosPix(4);
            
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
            
            if app.IsIdle
                status = 'idle';
            else
                status = 'busy';
            end
            
            titleStr = sprintf('%s | %s (%s)', app.AppName, fileName, status);
            app.Figure.Name = titleStr;
        
        end
    
        function setIdle(app)
            app.IsIdle = true;
            app.h.StatusField.String = sprintf(' Status: Idle');
            
            app.updateFigureTitle()
            
            app.Figure.Pointer = 'arrow';
            drawnow
        end
        
        function finishup = setBusy(app, statusStr)
                        
            app.IsIdle = false;
            app.Figure.Pointer = 'watch';
            
            app.updateFigureTitle()
            
            if nargin < 2 || isempty(statusStr)
                S = dbstack();
                runningMethod = strrep(S(2).name, 'sessionBrowser.', '');
                statusStr = sprintf(' Status: Running %s', runningMethod);
            elseif isa(statusStr, 'function_handle')
                methodName = func2str(statusStr);
                methodName = utility.string.varname2label(methodName) ;
                statusStr = sprintf(' Status: Running %s', methodName );
            else
                statusStr = sprintf(' Status: %s', statusStr );
            end
            app.h.StatusField.String = statusStr;

            finishup = onCleanup(@app.setIdle);
            
            drawnow
        end
        
        function updateStatusWhenBusy(app)

            endOfString = app.hStatusField.String(end-3:end);
            
            if contains(endOfString, '...')
                app.h.StatusField.String = app.hStatusField.String(1:end-3);
            else
                app.h.StatusField.String = strcat(app.hStatusField.String, '.');
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
        
        function updateStatusField(app, i, n, methodName)
            
            
            if isa(methodName, 'function_handle')
                methodName = func2str(methodName);
                methodName = utility.string.varname2label(methodName) ;
            end
                        
            % Update statusfield text showing progress.
            if i == 0
                app.h.StatusField.String = strrep(app.h.StatusField.String, ...
                    methodName, sprintf('%s (%d/%d finished)', methodName, i, n));
            else
                app.h.StatusField.String = strrep(app.h.StatusField.String, ...
                    sprintf('(%d/%d finished)', i-1, n), ...
                    sprintf('(%d/%d finished)', i, n));
            end 
            
            drawnow
            
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
            app.h.StatusField.String = 'Status: Idle';
        end
        
    end
    
    methods (Access = private) % Methods for meta table loading and saving
        
        function onMetaTableDataChanged(app, src, evt)
            app.MetaTable.entries(evt.Indices(1), evt.Indices(2)) = {evt.NewValue};
        end
        
        function addTableVariable(app, metadataClass)
        %addTableVariable Opens a dialog where user can add table variable
        %
        %   User gets the choice to create a variable that can be edited
        %   from the table or which is retrieved from a fucntion.
        
        %  Q: This belongs to MetaTableViewer, but was more convenient to
        %  add it here for now. 
        
        % Todo: Use class instead of functions / add class as a third
        % choice. Can make more configurations using a class, i.e class can
        % provides a mouse over effect etc.

    
            % Create a struct to open in a dialog window
            
            if nargin < 2
                error('Missing input')
            end
            
            import nansen.metadata.utility.createFunctionForCustomTableVar
            import nansen.metadata.utility.createClassForCustomTableVar
            
            
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
                answer = questdlg(message, title);
                 
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
            if ~isvarname(S.VariableName); errordlg(msg); error(msg); end
            
            switch S.InputMode
                case 'Enter values manually'
                    createClassForCustomTableVar(S)
                case 'Get values from function'
                    createFunctionForCustomTableVar(S)
                case 'Get values from list'
                    dlgTitle = sprintf('Create list of choices for %s', S.VariableName);
                    selectionList = multiLineListbox({}, 'Title', dlgTitle, ...
                        'ReferencePosition', app.Figure.Position);
                    S.SelectionList = selectionList;
                    createClassForCustomTableVar(S)
            end
            
            % Todo: Add variable to table and table settings....
            initValue = nansen.metadata.utility.getDefaultValue(S.DataType);
            
            app.MetaTable.addTableVariable(S.VariableName, initValue)
            app.UiMetaTableViewer.refreshColumnModel();
            app.UiMetaTableViewer.refreshTable(app.MetaTable)
            
            % Refresh menus that show the variables of the session table...
            app.updateSessionInfoDependentMenus()
        end
        
        function editTableVariableDefinition(app, src, evt)
            
            import nansen.metadata.utility.getTableVariableUserFunctionPath
            
            varName = src.Text;
            filepath = getTableVariableUserFunctionPath(varName, 'session');
            edit(filepath)
            
        end
        
        function updateTableVariable(app, src, evt)
        %updateTableVariable Update a table variable for selected sessions   
        %
        %   This function is a callback for the context menu
        
            if ischar(src) % For manual calls: If the value of src is the name of the variable, evt should be the update mode.
                varName = src;
                updateMode = evt;
            else % If invoked as callback, update selected rows
                varName = src.Text;
                updateMode = 'SelectedRows';
            end

            
            switch updateMode
                case 'SelectedRows'
                    sessionObj = app.getSelectedMetaObjects();
                    rows = app.UiMetaTableViewer.getSelectedEntries();

                    if isempty(sessionObj)
                        error('No sessions are selected'); 
                    end
                    
                case 'AllRows'
                    rows = 1:size(app.MetaTable.entries, 1);
                    sessionObj = app.tableEntriesToMetaObjects(app.MetaTable.entries);
            
            end
            
            numSessions = numel(sessionObj);
            
            if numSessions > 5
                h = waitbar(0, 'Please wait while updating values');
            end
            
            % Create function call for variable:
            updateFcnName = strjoin( {'tablevar', 'session', varName}, '.');
            updateFcn = str2func(updateFcnName);
            
            for iSession = 1:numSessions
                newValue = updateFcn(sessionObj(iSession));
                if isa(newValue, 'nansen.metadata.abstract.TableVariable')
                    if isequal(newValue.Value, newValue.DEFAULT_VALUE)
                        return
                    else
                        newValue = newValue.Value;
                    end
                end
                
                if ischar(newValue); newValue = {newValue}; end % Need to put char in a cell. Should use strings instead, but thats for later
                app.MetaTable.editEntries(rows(iSession), varName, newValue);
                
                if numSessions > 5
                    waitbar(iSession/numSessions, h)
                end
            end
            
            % Need to keep selected entries before refreshing table. 
            selectedEntries = app.UiMetaTableViewer.getSelectedEntries();                    

            app.UiMetaTableViewer.refreshTable(app.MetaTable)
            
            % Make sure selection is preserved.
            app.UiMetaTableViewer.setSelectedEntries(selectedEntries);
            
            if numSessions > 5
                delete(h)
            end
            
        end
        
        function copySessionIdToClipboard(app)
            
            sessionObj = app.getSelectedMetaObjects();
            
            sessionID = {sessionObj.sessionID};
            sessionID = cellfun(@(sid) sprintf('''%s''', sid), sessionID, 'uni', 0);
            sessionIDStr = strjoin(sessionID, ', ');
            sessionIDStr = 
            clipboard('copy', sessionIDStr)

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
            
            answer = questdlg(message, title);
            switch answer
                case {'No', 'Cancel', ''}
                    return
                case 'Yes'
                    % Continue
            end
            
            app.MetaTable.removeTableVariable(varName)
            app.UiMetaTableViewer.refreshTable(app.MetaTable)
            
            % Delete function template in project folder..
            pathStr = nansen.metadata.utility.getTableVariableUserFunctionPath(varName, 'session');
            if isfile(pathStr)
                delete(pathStr);
            end
            
            % Refresh session context menu...
            app.updateSessionInfoDependentMenus()
            

        end
        
        function checkIfMetaTableComplete(app, metaTable)
        %checkIfMetaTableComplete Check if user-defined variables are
        %missing from the table.
        
        % Todo: Add to metatable class? Eller muligens BaseSchema??? Kan
        % man legge inn dynamiske konstante egenskaper?
        
            tableVarNames = app.MetaTable.entries.Properties.VariableNames;
            
            variableAttributes = nansen.metadata.utility.getMetaTableVariableAttributes('session');
            referenceVarNames = {variableAttributes.Name};
            customVarNames = referenceVarNames([variableAttributes.IsCustom]);
        
            app.MetaTable = addMissingVarsToMetaTable(app, app.MetaTable, 'session');
        


% % %             % Check if any functions are present the tablevar folder, but
% % %             % the corresponding variable is missing from the table.
% % %             missingVarNames = setdiff(customVarNames, tableVarNames);
% % %             
% % %             for iVarName = 1:numel(missingVarNames)
% % %                 thisName = missingVarNames{iVarName};
% % %                 varFunction = nansen.metadata.utility.getCustomTableVariableFcn(thisName);
% % %                 fcnResult = varFunction();
% % %                 if isa(fcnResult, 'nansen.metadata.abstract.TableVariable')
% % %                     defaultValue = fcnResult.DEFAULT_VALUE;
% % %                 else
% % %                     defaultValue = fcnResult;
% % %                 end
% % %                 app.MetaTable.addTableVariable(thisName, defaultValue)
% % %             end
            
            % Also, check if any functions were removed from the tablevar
            % folder while the corresponding variable is still present in
            % the table.
            
            %Get list of default table variables. 
            schemaVarNames = referenceVarNames(~[variableAttributes.IsCustom]);
            
            % Get those variables in the table that are not default
            tableCustomVarNames = setdiff(tableVarNames, schemaVarNames);
            
            % Find the difference between those and the userVarNames
            missingVarNames = setdiff(tableCustomVarNames, customVarNames);
            
            for iVarName = 1:numel(missingVarNames)
                thisName = missingVarNames{iVarName};

                message = sprintf( ['The tablevar definition is missing ', ...
                    'for "%s". Do you want to delete data for this variable ', ...
                    'from the table?'], thisName );
                title = 'Delete Table Data?';
                
                answer = questdlg(message, title);
                
                switch answer
                    case 'Yes'
                        app.MetaTable.removeTableVariable(thisName)
                    case {'Cancel', 'No', ''}
                        
                        % Todo (Is it necessary): Maybe if the variable is
                        % editable...(which we dont know when the definition 
                        % is removed.) Should resolve based on user
                        % feedback/tests
                        
                        % Get table row as struct in order to check data
                        % type. (Some data is within a cell array in the table)
                        tableRow = app.MetaTable.entries(1, :);
                        rowAsStruct = table2struct(tableRow);
                        
                        % Create dummy function
                        S = struct();
                        S.VariableName = thisName;
                        S.MetadataClass = 'session'; % Todo: get current table
                        S.DataType = class(rowAsStruct.(thisName));
                        
                        S.InputMode = '';
                        
                        nansen.metadata.utility.createClassForCustomTableVar(S)
                end
                
            end
                
                % Display a warning to the user if any variables will be
                % removed. If user does not want to removed those variables,
                % create a dummy function for that table var.

        end
        
        function metaTable = addMissingVarsToMetaTable(app, metaTable, metaTableType)
        %addMissingVarsToMetaTable    
        
            % Todo: Lag metatable metode.
            
            if nargin < 3
                metaTableType = 'session';
            end
            
            tableVarNames = metaTable.entries.Properties.VariableNames;
            
            variableAttributes = nansen.metadata.utility.getMetaTableVariableAttributes( metaTableType );
            referenceVarNames = {variableAttributes.Name};
            customVarNames = referenceVarNames([variableAttributes.IsCustom]);
            
            
            % Check if any functions are present the tablevar folder, but
            % the corresponding variable is missing from the table.
            missingVarNames = setdiff(customVarNames, tableVarNames);
            
            for iVarName = 1:numel(missingVarNames)
                thisName = missingVarNames{iVarName};
                varFunction = nansen.metadata.utility.getCustomTableVariableFcn(thisName);
                fcnResult = varFunction();
                if isa(fcnResult, 'nansen.metadata.abstract.TableVariable')
                    defaultValue = fcnResult.DEFAULT_VALUE;
                else
                    defaultValue = fcnResult;
                end
                metaTable.addTableVariable(thisName, defaultValue)
            end

        end
        
        function loadMetaTable(app, loadPath)
            
            if nargin < 2 || isempty(loadPath)
                loadPath = app.getDefaultMetaTablePath();
            end
            
            % Ask user to save current database (if any is open)
            if ~isempty(app.MetaTable)
                app.promptToSaveCurrentMetaTable()
            end
            
            try
                % Load existing or create new experiment inventory 
                if exist(loadPath, 'file') == 2
                    app.MetaTable = nansen.metadata.MetaTable.open(loadPath);
                    %app.experimentInventoryPath = loadPath;
                else % Todo: do i need this...?
                    app.MetaTable = nansen.metadata.MetaTable;
                    %app.experimentInventoryPath = app.experimentInventory.filepath;
                end

                app.checkIfMetaTableComplete()
                
% %                 if app.initialized % todo
% %                     app.updateRelatedInventoryLists()
% %                 end
            catch ME
                errordlg(ME.message)
            end
            
            % Add name of loaded inventory to figure title
            if ~isempty(app.Figure)
                app.updateFigureTitle();
            end
            
        end
        
        function saveMetaTable(app, src, ~)
            
            if app.settings.MetadataTable.AllowTableEdits
                app.MetaTable.save()
                
                app.h.StatusField.String = sprintf('Status: Saved metadata table to %s', app.MetaTable.filepath);
                app.clearStatusIn(5)
            end

        end
        
        function promptToSaveCurrentMetaTable(app)
        %promptToSaveCurrentMetaTable Ask user to save current metatable
        
            % Return if there are no unsaved changes
            if app.MetaTable.isClean
                return 
            end
            
            % Prepare inputs for the question dialog
            qstring = sprintf('Save changes to the current metatable (%s)?', ...
                                app.MetaTable.getName());
            title = 'Current metatable has unsaved changes';
            alternatives = {'Save', 'Don''t Save', 'Cancel'};
            default = 'Save';
            
            answer = questdlg(qstring, title, alternatives{:}, default);
            
            switch answer
                case 'Save'
                    app.saveMetaTable()
                case 'Don''t Save'
                    % continue without saving
                otherwise % Cancel or no answer.
                    return
            end
            
        end

    end
    
    methods (Access = protected) % Callbacks

        function menuCallback_DetectSessions(app, src, evtData)
            
            newSessionObjects = nansen.manage.detectNewSessions(app.MetaTable, 'Rawdata');
            
            if isempty(newSessionObjects)
                msgbox('No sessions were detected')
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
            
            msgbox(sprintf('%d sessions were successfully added', numel(newSessionObjects)))

        end
        
        %onSettingsChanged Callback for change of fields in settings
        function onSettingsChanged(app, name, value)    
            
            
            switch name
                
                case 'ShowIgnoredEntries'
                    app.settings.MetadataTable.(name) = value;
                    
                    selectedEntries = app.UiMetaTableViewer.getSelectedEntries();
                    app.UiMetaTableViewer.ShowIgnoredEntries = value;
                    
                    % Make sure selection is preserved.
                    app.UiMetaTableViewer.setSelectedEntries(selectedEntries);
                    
                    
                case 'AllowTableEdits'
                    app.settings.MetadataTable.(name) = value;
                    app.UiMetaTableViewer.AllowTableEdits = value;

            end
            
        end
        
        function onNewMetaTableSet(app)
            if isempty(app.UiMetaTableViewer);    return;    end
            app.UiMetaTableViewer.refreshColumnModel()
            app.UiMetaTableViewer.refreshTable(app.MetaTable)
        end
        
        function onSessionTaskSelected(app, ~, evt)
            
            % Todo: Implement error handling.
            
            sessionObj = app.getSelectedMetaObjects();
            numSessions = numel(sessionObj);
            
            if strcmp(evt.Mode, 'Edit')
                edit(func2str(evt.MethodFcn))
                return
            end
            
            
            if numSessions == 0
                msg = 'No sessions are selected';
                msgbox(msg)
                return
            end
            
            functionName = func2str(evt.MethodFcn);
            returnToIdle = app.setBusy(functionName); %#ok<NASGU>
                           
            app.SessionTaskMenu.Mode = 'Default';

            % Get configuration attributes for session method. 
            try
                % Call with no inputs should give configuration struct
                mConfig = evt.MethodFcn();

                if isa(mConfig, 'struct')
                    % Add an options manager to the mConfig struct
                    mConfig.OptionsManager = nansen.manage.OptionsManager(..., 
                        functionName, mConfig.DefaultOptions);
                    
                elseif isa(mConfig, 'nansen.session.SessionMethod')
                    % Pass
                    
                else
                    %TODO: create proper exception
                    error('%s is not a valid SessionMethod')
                end

            catch ME
                throwAsCaller(ME)
                rethrow(ME)
            end
            
            
            % Check if session task should be run in serial or batch
            isSerial = strcmp(mConfig.BatchMode, 'serial');
            
            % Todo: What if session method is just a function handle???
            % Should add as ExternalFcn in a SessionMethod instance (make 
            % subclass for such cases....)
            
            % Place session objects in a cell array based on batch mode.
            if isSerial
                sessionObj = arrayfun(@(sObj) sObj, sessionObj, 'uni', 0);
            else
                sessionObj = {sessionObj};
            end
            
            sessionMethod = evt.MethodFcn; 
            
            % Todo: What if there is a keyword???
            optsName = evt.OptionsSelection;
            opts = mConfig.OptionsManager.getOptions(optsName);
                
            switch evt.Mode
                case 'Default'
                    app.runTasksWithDefaults(sessionMethod, sessionObj, opts, optsName)

                case 'Preview'
                    app.runTasksWithPreview(sessionMethod, sessionObj, opts, optsName)

                case 'TaskQueue'
                    app.addTasksToQueue(sessionMethod, sessionObj, opts, optsName)

            end
              
            % Clear the statusfield
        
            % Todo: update the session object in the session table if
            % changes were made...?
            
            
        end
        
        function sendToWorkspace(app)
                    
            sessionObj = app.getSelectedMetaObjects();
            if ~isempty(sessionObj)
                assignin('base', 'sessionObjects', sessionObj)
            end
            
        end
        
        function runTasksWithDefaults(app, sessionMethod, sessionObj, opts, ~)
        %runTasksWithDefaults Run session method with default options
            
            % Get task name
            taskName = nansen.session.SessionMethod.getMethodName(sessionMethod);
                        
            % Todo: Check if there is a maximum number of tasks for this
            % method.
            
            numTasks = numel(sessionObj);
            for i = 1:numTasks
                
                % Update the status field
                app.updateStatusField(i-1, numTasks, sessionMethod)
                
                % Run the task
                try
                    sessionMethod(sessionObj{i}, opts)
                catch ME
                    
                    errorMessage = sprintf('Session method ''%s'' failed for session ''%s''.\n', ...
                        taskName, sessionObj{i}.sessionID);
                    errordlg([errorMessage, ME.message])
                    rethrow(ME)
                end
                %pause(2)
                
            end
            
        end
        
        function runTasksWithPreview(app, sessionMethod, sessionObj, opts, optsName)
            % Get default options
            % Get task name

            % Use normcorre as an example: how to open the preview mode 
            % i.e open the image stack in imviewer and open the normcorre
            % plugin? 
            %
            % While still retaining the functionality for session methods
            % implemented through functions??
            
            numTasks = numel(sessionObj);
            for i = 1:numTasks
                
                sMethod = sessionMethod();
                
                % Open the options / method in preview mode
                if isa(sMethod, 'nansen.session.SessionMethod')
                    sMethod = sessionMethod(sessionObj{i});
                    sMethod.usePreset(optsName)
                    
                    isSuccess = sMethod.preview();

                    if isSuccess
                        sMethod.run()
                    end
                    
                    % Update session task menu (in case new options were defined...)
                    app.SessionTaskMenu.refresh()
                    % Todo: Only refresh this submenu.
                    % Todo: Only refresh if options sets were added. 
                    
                else
                    fcnName = func2str(sessionMethod);
                    optManager = nansen.manage.OptionsManager(fcnName, opts);
                    
                    [~, opts, wasAborted] = optManager.editOptions();
                    
                    if ~wasAborted
                        sessionMethod(sessionObj{i}, opts)
                    end
                end

            end

        end
        
        function addTasksToQueue(app, sessionMethod, sessionObj, opts, optsName)

            % Add tasks to the queue
            numTasks = numel(sessionObj);
            for i = 1:numTasks

                % Get/create task name
                if numel(sessionObj{i}) > 1
                    taskId = 'Multiple sessions';
                else
                    taskId = sessionObj{i}.sessionID;
                end
                
                % Prepare input args for function (session object and 
                % options)
                
                methodArgs = {sessionObj{i}, opts};
                
                % Add task to the queue / submit the job
                app.UiProcessor.submitJob(taskId,...
                                sessionMethod, 0, methodArgs, optsName )
            end
        end
        
        function openFolder(app, dataLocationName)
            
            sessionObj = app.getSelectedMetaObjects();

            for i = 1:numel(sessionObj)
                folderPath = sessionObj(i).DataLocation.(dataLocationName);
                utility.system.openFolder(folderPath)
            end

        end
        
    end
    
    
    methods (Access = protected) % Menu Callbacks
        
        function onNewProjectMenuClicked(app, src, evt)
        %onNewProjectMenuClicked Let user add a new project
        
            import nansen.config.project.ProjectManagerUI

            switch src.Text
                case 'Create New...' 
                    % Todo: open setup from create project page
                    
                    msg = 'This will close the current app and open nansen setup. Do you want to continue?';
                    answer = questdlg(msg, 'Close and continue?');
                    
                    switch answer
                        case 'Yes'
                            app.onExit(app.Figure)
                            nansen.setup
                            return
                        otherwise
                            % Do nothing
                    end

                    
                case 'Add Existing...'
                    ProjectManagerUI().addExistingProject()
            end
            
            app.updateProjectList()

        end
        
        function onChangeProjectMenuClicked(app, src, evt)
        %onChangeProjectMenuClicked Let user change current project
        
            projectManager = nansen.ProjectManager;
            projectManager.changeProject(src.Text)
            
            % Todo: Update session table!
            app.changeProject()
            
        end
        
        function onManageProjectsMenuClicked(app, src, evt)
            
            % Todo: Create the ProjectManagerApp
            import nansen.config.project.ProjectManagerUI

            hFigure = uifigure;
            hFigure.Position(3:4) = [699,229];
            uim.utility.layout.centerObjectInRectangle(hFigure, app.Figure)
            
            hProjectManager = ProjectManagerUI(hFigure);
            listener(hProjectManager, 'ProjectChanged', @app.changeProject)
            hFigure.WindowStyle = 'modal';
            uiwait(hFigure)
            
            app.updateProjectList()
            
        end
            
        function onUpdateSessionListMenuClicked(app, src, evt)
            
            import nansen.dataio.session.listSessionFolders
            import nansen.dataio.session.matchSessionFolders
    
            %sessionSchema = @nansen.metadata.schema.vlab.TwoPhotonSession;
            
            % % Use the folder structure to detect session folders.
            sessionFolders = listSessionFolders(dataLocationModel, 'all');
            sessionFolders = matchSessionFolders(dataLocationModel, sessionFolders);
    
            if isempty(sessionFolders)
                return
            end

            % Create a list of session metadata objects
            numSessions = numel(sessionFolders);
            sessionArray = cell(numSessions, 1);
            for i = 1:numSessions
                sessionArray{i} = sessionSchema(sessionFolders(i));
            end

            sessionArray = cat(1, sessionArray{:});
            
            foundSessionIds = {sessionArray.sessionID};
            currentSessionIds = app.MetaTable{:, 'sessionID'};
            
            [~, iA] = setdiff( foundSessionIds, currentSessionIds, 'stable' );
            
            newSessionObjects = sessionArray(iA);
            
            % Find all that are not part of existing metatable
            app.MetaTable.addEntries(newSessionObjects)
            
            app.UiMetaTableViewer.refreshTable(app.MetaTable)

        end
        
        function onCreateSessionMethodMenuClicked(app, src, evt)

            nansen.session.methods.template.createNewSessionMethod(app);
            
            % Update session menu!
            
        end
        
        function onRefreshSessionMethodMenuClicked(app, src, evt)
            app.SessionTaskMenu.refresh()
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
   
    
    methods (Static)
        
        function pathStr = getDefaultMetaTablePath()
            
            pathStr = nansen.metadata.MetaTableCatalog.getDefaultMetaTablePath();
            
        end
        
        function switchJavaWarnings(newState)
        %switchJavaWarnings Turn warnings about java functionality on/off
            warning(newState, 'MATLAB:ui:javaframe:PropertyToBeRemoved')
            warning(newState, 'MATLAB:ui:javacomponent:FunctionToBeRemoved')
        end
        
    end
        
    
    methods (Static) % Method defined in separate file
        S = getDefaultSettings()
    end
end
