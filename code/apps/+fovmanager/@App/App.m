classdef App < handle & applify.mixin.UserSettings
    
    % Todo: fix display of object center coords. Should not show when mouse
    % is pressed on object, should appear when drag operation is started.
    % Alternatively: Show them in the object popup textbox.... 
    
    properties (Constant, Hidden = true)
        DEFAULT_SETTINGS = fovmanager.App.getDefaultSettings()
        USE_DEFAULT_SETTINGS = false;
        ICONS = uim.style.iconSet(fovmanager.App.getIconPath)
        
        PLOTCOLORS = struct('EdgeColor', ones(1,3)*0.2, ...
                            'EdgeColorSelected', 'g')
        
        figureSizeSmall = [440, 580];
        figureMargins = [30, 30, 30, 58];
    end
    
    properties
        
        hFigure
        hAxes
                
        fovDatabase = struct('MouseId', {}, 'HeadbarLabel', {}, ...
            'Windows', fovmanager.mapobject.CranialWindow.empty, ...
            'Injections', fovmanager.mapobject.InjectionSpot.empty)
        
        selectedObject
        
    end

    properties (Access = private)
        
        initialized = false
        isSaved = true
        currentFile = '';
        
        WindowMouseMotionListener
        WindowMouseReleaseListener
        DataCursorToggledListener
        
        % Temp handles...
        mouseListbox
        mouseDropdownMenu

        
        textCoords
        mapCoordinatesMode = 'none'
        hObjectInformation
        
        hCurrentPoint
        hAnnotationAxes
        
        hRegions
        hHighlightedRegion
        
        hInfoBox
        hSlider

        
        pointerManager
        
        tempFovHandles
        prevMousePointAx
        hBg % Background / patch everything outside window...

        resizeRectHandle            % Imrect handle for resizing FoVs.
        
        hMapLabels
        
        % Widgets...
        Toolbar

        msgBox
        
    end
    
    
    methods % Structors
        
        function obj = App(mode)
            
            obj.checkDependencies()
            
            
%             if obj.isOpen()
%                 clear obj; return
%             end
            
            if ~ispref('fovmanager') % 1st time initialization only
                obj.setDefaultPreferences()
            end
            
            if nargin < 1 || mode == 1
                obj.initializeGui()
                obj.createAxesContextMenu()
                
            elseif mode == 2
                obj.initializeGuiSimple()
            end
            
            obj.pointerManager = uim.interface.pointerManager(obj.hFigure, ...
                obj.hAxes, {'zoomIn', 'zoomOut', 'pan', 'dataCursor'});

            hDataCursor = obj.pointerManager.pointers.dataCursor;
            hDataCursor.buttonMotionCallback = @obj.onMouseOver;

            el = listener(hDataCursor, 'ToggledPointerTool', @obj.onDataCursorToggled);
            obj.DataCursorToggledListener = el;
            
            
            % Create UIComponentCanvas for drawing uicontrols and widget on
            uicc = uim.UIComponentCanvas(obj.hFigure);
            setappdata(obj.hFigure, 'UIComponentCanvas', uicc);
                      
            obj.addComponents()
            obj.addToolbar()
            
            obj.setAppearance()

            
            
            obj.hFigure.Visible = 'on';
            
            % load settings
            obj.loadSettings();
            
            obj.initialized = true;
            obj.isSaved = true;
            
            if ~nargout
                clear obj
            end
        end
        
        function delete(obj)
            
        end
        
        function quit(obj)
            
            if obj.initialized

                % Save database
                if ~obj.isSaved
                    answer = questdlg('Do you want to save changes to the fov inventory?');
                    switch lower(answer)
                        case 'yes'
                            obj.saveFovDatabase()
                        case 'cancel'
                            return
                    end
                end
                
                % Save settings
                obj.saveSettings()
                
                
                setpref('fovmanager', 'figureLocation', obj.hFigure.Position(1:2));   

            end
            
            % Delete windows to get rid of listeners before deleting obj.
            for i = 1:numel(obj.fovDatabase)
                delete(obj.fovDatabase(i).Windows)
                delete(obj.fovDatabase(i).Injections)
            end
            
            % Close figure
            closereq
            
            % Delete obj
            delete(obj)

        end
        
    end
    
    
    methods (Access = protected, Hidden) % Gui Construction
        
        function onSettingsChanged(obj, fieldname, value)
           switch fieldname
                case 'showGrayscaleImages'
                    if value
                        for i = 1:numel(obj.fovDatabase)
                            hIm = findobj(obj.fovDatabase(i).Windows.guiHandle, 'Tag', 'Brain Surface Image');
                            for j = 1:numel(hIm)
                                hIm.CData = stack.makeuint8(repmat(mean(hIm.CData, 3), 1,1,3));
                            end
                        end
                    end
                    
                case 'showInjections'
                    obj.changeSelectedMouse() % Refresh current mouse
                    
                case 'hemisphereToLabel'
                    if ~isempty(obj.hMapLabels)
                       
                        txtPos = cat(1, obj.hMapLabels.Position);
                       
                        switch value
                            case 'left'
                                txtPos(:,1) =  -1 * abs( txtPos(:, 1) );
                            case 'right'
                                txtPos(:,1) = abs( txtPos(:, 1) );
                        end
                        
                        txtPos = arrayfun(@(i) txtPos(i,:), 1:numel(obj.hMapLabels), 'uni', 0);
                        
                        set(obj.hMapLabels, {'Position'}, txtPos' )
                   end
                   
           end
        end
        
        function toggleResize(obj, src, ~)
            
            switch src.Tooltip
                case 'Maximize Figure'
                    src.Icon = obj.ICONS.minimize;
                    src.Tooltip = 'Restore Figure';
                    screenSize = get(0, 'ScreenSize');
                    setpref('fovmanager', 'figureLocation', obj.hFigure.Position(1:2));   

                    height = screenSize(4)-80;
                    width = height .* obj.hFigure.Position(3)./obj.hFigure.Position(4);
                    newPosition = [(screenSize(3)-width)/2, 5, width, height];
                    obj.hFigure.Position = newPosition;
                    
                    obj.Toolbar.Spacing = 12;
                    obj.setAxesPosition()
                    
                case 'Restore Figure'
                    src.Icon = obj.ICONS.maximize2;
                    src.Tooltip = 'Maximize Figure';
                    
                    figureLocation = getpref('fovmanager', 'figureLocation');            
                    figurePosition = [figureLocation, obj.figureSizeSmall];                    
                    obj.hFigure.Position = figurePosition;
                    obj.Toolbar.Spacing = 7;
                    obj.setAxesPosition()
            end
            
            obj.hAnnotationAxes.XLim = [1, obj.hAnnotationAxes.Position(3)];
            obj.hAnnotationAxes.YLim = [1, obj.hAnnotationAxes.Position(4)];
            
            obj.setMouseSelectorPosition()
            obj.msgBox.resetAxesPosition()
        
        end
        
        function setAppearance(obj, newAppearance)
            
            if nargin < 2
                newAppearance = getpref('fovmanager', 'appearance');
            else
                setpref('fovmanager', 'appearance', newAppearance);
            end
            
            S = obj.getAppearance(newAppearance);

            % Set colors of figure and axes
            obj.hFigure.Color = S.FigureBackgroundColor;
            obj.hAxes.Color = S.AxesBackgroundColor;
            obj.hAxes.XAxis.Color = S.AxesForegroundColor;
            obj.hAxes.YAxis.Color = S.AxesForegroundColor;
            obj.hAxes.GridColor = S.AxesForegroundColor;
            obj.hAxes.GridAlpha = S.AxesGridAlpha;
            
            obj.hAxes.MinorGridColor = S.AxesForegroundColor;
            obj.hAxes.MinorGridAlpha = S.AxesGridAlpha / 2;
            
            % Change appearance of toolbar
            obj.Toolbar.BackgroundAlpha = S.ToolbarAlpha;
            obj.Toolbar.DarkMode = S.ToolbarDarkMode;
            
            obj.hSlider.TextColor = S.AxesForegroundColor; 
            
            % Set color of data cursor
            hDataCursor = obj.pointerManager.pointers.dataCursor;
            hDataCursor.cursorColor = S.AxesForegroundColor;
            
            % Set color of map boundary (Region 31) % TODO: Should not be
            % hardcoded...
            hRegions = findobj(obj.hAxes, 'type', 'polygon');
            hRegions = flipud(hRegions);
            hRegions(31).FaceColor = S.AxesForegroundColor;
            set(hRegions, 'FaceAlpha', S.MapAlpha)
            
        
        end
        

        function setDefaultPreferences(obj)
        %setDefaultPreferences Set default preferences on first time startup    
            
            % Todo: Add more defaults...
            setpref('fovmanager', 'figureLocation', [200, 100])
            setpref('fovmanager', 'appearance', 'light')
            setpref('fovmanager', 'recentFiles', repmat({''}, 9,1))

        end
        
        
        
% % % %  Methods for setting up the gui

        function initializeGui(obj)
            
            obj.createFigure()
            obj.createMenu()
            
            obj.createAxes()
            obj.plotMap()
            
            
            obj.createAnnotationAxes()
            
            % Disable newer matlab axes interactivity...
            matlabVersion = version;
            ind = strfind(matlabVersion, '.');
            matlabVersionNumber = str2double(strrep(matlabVersion(1:ind(2)+1), '.', ''));
            if matlabVersionNumber >= 950
                addToolbarExplorationButtons(obj.hFigure)
                obj.hAxes.Toolbar.Visible = 'off';
                 disableDefaultInteractivity(obj.hAxes)
            end

            
            obj.msgBox = uim.widget.messageBox(obj.hAxes, 'Units', 'pixel', ...
                            'MinSize', [300, 50]);
            
            
            % Define slider position and add slidebar
            sliderSize = [100, 15];
            sliderPosX = sum(obj.hAxes.Position([1,3])) - sliderSize(1) - 5;
            sliderPosY = sum(obj.hAxes.Position([2,4])) - sliderSize(2) - 20;
            
            obj.hSlider = uim.widget.slidebar('Parent', obj.hFigure, 'Units', 'pixel');
            %obj.hSlider.Units = 'pixel';
            obj.hSlider.Position = [sliderPosX, sliderPosY, sliderSize];
            obj.hSlider.Visible = 'off';
            
            
            % Textbox for showing coordinates on map
            obj.textCoords = text(obj.hAxes, 0,0, '0, 0', 'BackgroundColor', 'w', 'EdgeColor', 'k');
            obj.textCoords.VerticalAlignment = 'bottom';
            obj.textCoords.FontSize = 14;
            obj.textCoords.Visible = 'off';

            
            % Textbox for showing object information when selected
            obj.hObjectInformation = text(obj.hAxes, 0,0, '');
            obj.hObjectInformation.BackgroundColor = 'w';
            obj.hObjectInformation.EdgeColor = ones(1,3)*0.2;
            obj.hObjectInformation.Visible = 'off';
            obj.hObjectInformation.Tag = 'Info Text';

% %             % Create textbox to reference the map
% %             annotation(obj.hFigure,'textbox',...
% %                 [0.20 0.093 0.48 0.040],...
% %                 'Color',[0.3 0.3 0.3],...
% %                 'String',' Kirkcaldie et al. Straightening out the mouse neocortex',...
% %                 'LineStyle','none',...
% %                 'FitBoxToText','off');

        end   
        
        function initializeGuiSimple(obj)
            
            [obj.hFigure, obj.hAxes] = fovmanager.showMap();
            obj.hFigure.Name = 'Cortex Dorsal Map';
            obj.hFigure.MenuBar             = 'none';

            set(obj.hAxes.Children, 'HitTest', 'off', 'PickableParts', 'none')
            obj.hAxes.ButtonDownFcn = @obj.mousePressAxes;

            obj.hFigure.UserData.App = obj;
            
            % Textbox for showing object information when selected
            obj.hObjectInformation = text(obj.hAxes, 0,0, '');
            obj.hObjectInformation.BackgroundColor = 'w';
            obj.hObjectInformation.EdgeColor = ones(1,3)*0.2;
            obj.hObjectInformation.Visible = 'off';
            obj.hObjectInformation.Tag = 'Info Text';
        end
        
        function createFigure(obj)
              
            % Get position from preferences
            figureLocation = getpref('fovmanager', 'figureLocation');            
            figurePosition = [figureLocation, obj.figureSizeSmall];
            
            obj.hFigure = figure('Visible', 'off');
            obj.hFigure.MenuBar             = 'none';
            obj.hFigure.Resize              = 'off';
            obj.hFigure.Position            = figurePosition;
            obj.hFigure.FileName            = '';
            obj.hFigure.NumberTitle         = 'off';
            obj.hFigure.Name                = 'FOV Manager';
            obj.hFigure.WindowKeyPressFcn   = @obj.keyPress;
            obj.hFigure.CloseRequestFcn     = @(src, event) obj.quit;
                        
        end
        
        function createMenu(obj)
            
            mItem(1) = uimenu(obj.hFigure, 'Text', 'File');
            mSubItem(1) = uimenu(mItem(1), 'Text', 'Open Recent Fov Inventory');
            
            % todo update when new inventories are loaded, not just on
            % startup
            obj.setSubMenuRecentFiles(mSubItem(1))
            
            mSubItem(2) = uimenu(mItem(1), 'Text', 'Load Fov Inventory', 'Separator', 'on');
            mSubItem(2).Callback = @(src, evt) obj.loadFovDatabase;
            mSubItem(2).Accelerator = 'l';
            mSubItem(3) = uimenu(mItem(1), 'Text', 'Save Fov Inventory');
            mSubItem(3).Callback = @(src, evt) obj.saveFovDatabase;
            mSubItem(3).Accelerator = 's';
            mSubItem(4) = uimenu(mItem(1), 'Text', 'Export Map As...', 'Separator', 'on');
            
            mSubItem(5) = uimenu(mSubItem(4), 'Text', 'Image (Png)', 'Enable', 'off');
            mSubItem(6) = uimenu(mSubItem(4), 'Text', 'Image (Eps)', 'Enable', 'off');

            
            mItem(2) = uimenu(obj.hFigure, 'Text', 'Edit');
            mSubItem(3) = uimenu(mItem(2), 'Text', 'Undo', 'Enable', 'off');
            mSubItem(3).Accelerator = 'z';
            mSubItem(3) = uimenu(mItem(2), 'Text', 'Redo', 'Enable', 'off');
            mSubItem(3).Accelerator = 'y';
            mSubItem(4) = uimenu(mItem(2), 'Text', 'Copy', 'Separator', 'on', 'Enable', 'off');
            mSubItem(4).Accelerator = 'c';
            mSubItem(5) = uimenu(mItem(2), 'Text', 'Paste', 'Enable', 'off');
            mSubItem(5).Accelerator = 'v';
            mSubItem(6) = uimenu(mItem(2), 'Text', 'Delete', 'Separator', 'on', 'Enable', 'off');
            mSubItem(6).Accelerator = char(8);
            
            mItem(5) = uimenu(obj.hFigure, 'Text', 'Inventory');
            mSubItem(1) = uimenu(mItem(5), 'Text', 'Add New Mouse');
            mSubItem(1).Callback = @obj.addMouse;
            mSubItem(1).Accelerator = 'n';
            mSubItem(2) = uimenu(mItem(5), 'Text', 'Edit Mouse Id');
            mSubItem(2).Callback = @obj.renameMouse;
            mSubItem(3) = uimenu(mItem(5), 'Text', 'Edit Headbar Label');
            mSubItem(3).Callback = @obj.renameMouse;
            mSubItem(4) = uimenu(mItem(5), 'Text', 'Delete Mouse Entry', 'Separator', 'on');
            mSubItem(4).Callback = @obj.deleteMouse;
            mSubItem(5) = uimenu(mItem(5), 'Text', 'Sort Mice by Name', 'Separator', 'on', 'Enable', 'off');
            mSubItem(5).Callback = [];
            
            
            mItem(6) = uimenu(obj.hFigure, 'Text', 'Map Objects');
            mSubItem(1) = uimenu(mItem(6), 'Text', 'Add Cranial Window');
            mSubItem(1).Callback = @(src, event) obj.addObjectToMouse('window');
            mSubItem(1).Accelerator = 'w';
            mSubItem(2) = uimenu(mItem(6), 'Text', 'Set Cranial Window Position', 'Enable', 'off');
            mSubItem(2).Callback = [];
            mSubItem(3) = uimenu(mItem(6), 'Text', 'Add Field of View');
            mSubItem(3).Separator = 'on';
            mSubItem(3).Callback = @(src, event) obj.addFov();
            mSubItem(3).Accelerator = 'f';
            mSubItem(4) = uimenu(mItem(6), 'Text', 'Add Session to Field of View', 'Enable', 'off');
            mSubItem(4).Callback = [];
            mSubItem(5) = uimenu(mItem(6), 'Text', 'Add RoIs to Session/FoV', 'Enable', 'off');
            mSubItem(5).Callback = [];
            
            mSubItem(6) = uimenu(mItem(6), 'Text', 'Add Injection(s)', 'Separator', 'on');
            mSubItem(6).Callback = @(src, event) obj.addObjectToMouse('injection');
            mSubItem(6).Accelerator = 'i';
            
            mSubItem(7) = uimenu(mItem(6), 'Text', 'Add Annotation(s)', 'Separator', 'on', 'Enable', 'off');
            mSubItem(7).Callback = @(src, event) obj.addObjectToMouse('annotation');
            
 
            mItem(3) = uimenu(obj.hFigure, 'Text', 'Show');
            mSubItem(2) = uimenu(mItem(3), 'Text', 'Show All FoVs');
            mSubItem(2).Callback = @obj.showAllFovs;
            mSubItem(3) = uimenu(mItem(3), 'Text', 'Show Map Labels');
            mSubItem(3).Callback = @obj.showMapLabels;
            mSubItem(4) = uimenu(mItem(3), 'Text', 'Show Fine Grid', 'Separator', 'on');
            mSubItem(4).Callback = @obj.showMinorGrid;         
            mSubItem(4).Accelerator = 'g';
            mSubItem(5) = uimenu(mItem(3), 'Text', 'Show Transparency Slider');
            mSubItem(5).Callback = @obj.showTransparencySlider;
            mSubItem(5).Accelerator = 't';

                        
            mItem(4) = uimenu(obj.hFigure, 'Text', 'More');
            mSubItem(4) = uimenu(mItem(4), 'Text', 'Set Current Inventory as Default', 'Enable', 'off');
            %mSubItem(4).Callback = @(s,e,h)obj.setDefaultDatabase(obj);
            %Todo: make method.
            
            
            mSubItem(1) = uimenu(mItem(4), 'Text', 'Set Appeareance');
            mSubItem(2) = uimenu(mSubItem(1), 'Text', 'Light');
            mSubItem(2).Callback = @(s,e,a) obj.setAppearance('light');
            mSubItem(3) = uimenu(mSubItem(1), 'Text', 'Dark');
            mSubItem(3).Callback = @(s,e,a) obj.setAppearance('dark');
        end
        
        function setSubMenuRecentFiles(obj, hMenu)
        %setSubMenuRecentFiles List recent files in submenu
        
            if nargin < 2
                hMenu = findobj(obj.hFigure, 'Text', 'Open Recent Fov Inventory');
            end
            
            if ~isempty(hMenu.Children)
                delete(hMenu.Children)
            end
            
            recentFiles = getpref('fovmanager', 'recentFiles');
            for i = 1:numel(recentFiles)
                
                filePath = recentFiles{i};
                if isempty(filePath); continue; end
                
                [~, fileName] = fileparts(filePath);
                
                mSubItemTmp = uimenu(hMenu, 'Text', fileName);
                mSubItemTmp.Callback = @(src, evt, p) obj.loadFovDatabase(filePath);
                mSubItemTmp.Accelerator = num2str(i);
            end 
            
        end
        
        function createAxes(obj)
        %createAxes Create and configure axes for plotting map and objects 
        
            obj.hAxes = axes();
            obj.hAxes.Units = 'pixel';
            obj.setAxesPosition()
            
            hold(obj.hAxes, 'on')
            
            % Todo: set these dependent on which map is opened. Currently
            % only paxinos..
            xLim = [-6,6];
            yLim = [-9,7];
            
            setappdata(obj.hAxes, 'XLimOrig', xLim)
            setappdata(obj.hAxes, 'YLimOrig', yLim)

            obj.hAxes(1).XLim = xLim;
            obj.hAxes(1).YLim = yLim;
            obj.hAxes(1).XTick = xLim(1):xLim(2);
            obj.hAxes(1).YTick = yLim(1):yLim(2);
            obj.hAxes(1).DataAspectRatio = [1 1 1];
            obj.hAxes(1).DataAspectRatioMode = 'manual';

            obj.hAxes.GridLineStyle = '-';
            obj.hAxes.MinorGridLineStyle = '-';

            obj.hAxes.XGrid = 'on';
            obj.hAxes.YGrid = 'on';
            obj.hAxes.XMinorTick = 'on';
            obj.hAxes.YMinorTick = 'on';
            obj.hAxes.Box = 'on';
            
            obj.hAxes.ButtonDownFcn = @obj.mousePressAxes;
            
        end
        
        function setAxesPosition(obj)
        %setAxesPosition Set axes position based on figure height & map AR
        
            figurePosition = getpixelposition(obj.hFigure);
            
            % Calculate axes size and set position.
            axesHeight = figurePosition(4) - sum(obj.figureMargins([2,4]));
            axesWidth = axesHeight .* 12 / 16; % Todo: Replace with map AR
            axesLocation = obj.figureMargins(1:2);
            obj.hAxes.Units = 'pixel';
            obj.hAxes.Position = [axesLocation, axesWidth, axesHeight];
            
            % Adjust figure width so that figure wraps around axes.
            figureWidth = axesWidth + sum(obj.figureMargins([1,3]));
            obj.hFigure.Position(3) = figureWidth;
        end
        
        function plotMap(obj)
        %plotMap Plot map from region definitions saved in file
        
            %rootDir = fileparts(mfilename('fullpath'));
            %rootDir = utility.path.getAncestorDir(mfilename('fullpath'), 2);
            rootDir = fovmanager.localpath('brain_atlas');
            
            loadDir = fullfile(rootDir, 'paxinos');
            loadPath = fullfile(loadDir, 'dorsal_map_polyshapes.mat');
            
            S = load(loadPath, 'mapRegions');
            mapRegions = S.mapRegions;
            
            hold(obj.hAxes, 'on')
            
            hRegions = plot(obj.hAxes, cat(1, mapRegions.Shape) );
            set(hRegions, 'PickableParts', 'none', 'HitTest', 'off' )
            set(hRegions, 'FaceAlpha', 1, 'EdgeColor', 'none')
            set(hRegions, {'FaceColor'}, {mapRegions.FaceColor}' )
            set(hRegions, {'Tag'}, {mapRegions.Tag}' )
            
        end

        function addToolbar(obj)
        %ADDTOOLBAR Add toolbar with tools to the map axes

            % Calculate the position of the toolbar.
            toolbarHeight = 30;
            
% %             axPosition = getpixelposition(obj.hAxes);
% % 
% %             initPosition(1) = axPosition(1);
% %             initPosition(2) = sum(axPosition([2,4])) + toolbarHeight - 10;
% %             initPosition(3) = axPosition(3);
% %             initPosition(4) = toolbarHeight;

            uicc = getappdata(obj.hFigure, 'UIComponentCanvas');
            
            padX = sum(obj.mouseDropdownMenu.Position([1,3])) + 8;
            
            % Create toolbar
            hToolbar = uim.widget.toolbar(uicc, ...
                'Margin', [0,0,0,0],      'ComponentAlignment', 'left', ...
                'BackgroundAlpha', 0.7,     'DarkMode', 'off', ...
                'BackgroundColor', 'k',     'BackgroundMode', 'full', ...
                'Padding', [padX,4,8,4],       'NewButtonSize', 22, ...
                'Spacing', 8);
            
            hToolbar.addSeparator()
            hToolbar.addButton('Icon', obj.ICONS.zoomIn, 'Type', 'togglebutton', 'Tag', 'zoomIn', 'Tooltip', 'Zoom In (q)', 'Style', uim.style.buttonDarkMode)%, 'CornerRadius', 0, 'Style', uim.style.buttonLightMode')
            hToolbar.addButton('Icon', obj.ICONS.zoomOut, 'Type', 'togglebutton', 'Tag', 'zoomOut', 'Tooltip', 'Zoom Out (w)', 'Style', uim.style.buttonDarkMode)%, 'Style', uim.style.buttonLightMode2)
            %hToolbar.addButton('Icon', obj.ICONS.resetZoom, 'Type', 'pushbutton', 'Tag', 'resetZoom', 'Tooltip', 'Reset Zoom', 'ButtonDownFcn', @obj.resetZoom)
            hToolbar.addButton('Icon', obj.ICONS.hand4, 'Type', 'togglebutton', 'Tag', 'pan', 'Tooltip', 'Pan (y)')
            hToolbar.addButton('Icon', obj.ICONS.cursor, 'Type', 'togglebutton', 'Tag', 'dataCursor', 'Tooltip', 'Info Cursor (x)')

            hToolbar.addSeparator()
            hToolbar.addButton('Icon', obj.ICONS.grid, 'Type', 'togglebutton', 'Tag', 'grid', 'Tooltip', 'Show Grid', 'ButtonDownFcn', @obj.showGrid)
            hToolbar.addButton('Icon', obj.ICONS.maximize, 'Type', 'pushbutton', 'Tag', 'maximize', 'Tooltip', 'Maximize Figure', 'ButtonDownFcn', @obj.toggleResize)
            hToolbar.addSeparator()
            hToolbar.addButton('Icon', obj.ICONS.preferences, 'Type', 'pushbutton', 'Tag', 'Settings', 'Tooltip', 'Preferences (cmd-p)', 'ButtonDownFcn', @(s, e) obj.editSettings)
            hToolbar.addButton('Icon', obj.ICONS.question, 'Type', 'pushbutton', 'Tag', 'Help', 'Tooltip', 'Help (shift-h)', 'ButtonDownFcn', @(s, e) obj.showHelp)
            
            obj.Toolbar = hToolbar;
            
            % Get handle for pointerManager interface
            hPm = obj.pointerManager;

            % Add listeners for toggling of modes from the pointertools to the
            % buttons. Also connect to buttonDown to toggling of the pointer
            % tools.
            pointerModes = {'zoomIn', 'zoomOut', 'pan', 'dataCursor'};

            for i = 1:numel(pointerModes)
                hBtn = hToolbar.getHandle(pointerModes{i});
                hBtn.ButtonDownFcn = @(s,e,h,str) togglePointerMode(hPm, pointerModes{i});
                hBtn.addToggleListener(hPm.pointers.(pointerModes{i}), 'ToggledPointerTool')
            end

            
% %             % Add toolbar to the widget property.
% %             obj.uiwidget.Toolbar = hToolbar;
% %             obj.uiwidget.Toolbar.Visible = 'off';

        end
        
        function addComponents(obj)
            
            xPosition = 5;
            yPosition = obj.hFigure.Position(4) - 25 - 5;
            
           % Create SelectbyMouseDropDown
            obj.mouseDropdownMenu = uicontrol('Parent', obj.hFigure);
            obj.mouseDropdownMenu.Style = 'popup';
            obj.mouseDropdownMenu.String = {'No Selection'};
            obj.mouseDropdownMenu.Callback = @(src, event) obj.hFigure;
            obj.mouseDropdownMenu.Position = [xPosition, yPosition 135 25]; 
            obj.mouseDropdownMenu.Callback = @obj.onMouseSelectionChanged;
            obj.mouseDropdownMenu.FontSize = 13;
            
            happy = false;
            while ~happy
                if obj.mouseDropdownMenu.Extent(4) > 23
                    obj.mouseDropdownMenu.FontSize = obj.mouseDropdownMenu.FontSize - 1;
                else
                    happy = true;
                end
            end
            
            obj.setMouseSelectorPosition()
        end
        
        function setMouseSelectorPosition(obj)
            
            componentHeight = obj.mouseDropdownMenu.Extent(4);
            obj.mouseDropdownMenu.Position(4) = componentHeight;
            obj.mouseDropdownMenu.Position(2) = obj.hFigure.Position(4) - ...
                componentHeight - 3;
            
            x = obj.mouseDropdownMenu.Position(1) + 15;
            y = obj.mouseDropdownMenu.Position(2) - 15;
            tooltipStr = 'Mouse Selection';
            
            uicc = getappdata(obj.hFigure, 'UIComponentCanvas');
            mouseEnterFcn = @(s,e,str,pos) uicc.showTooltip(tooltipStr, [x,y]);
            
            jHandle = findjobj_fast(obj.mouseDropdownMenu);
            
            set(jHandle, 'MouseEnteredCallback', mouseEnterFcn)
            set(jHandle, 'MouseExitedCallback', @(s, e) uicc.hideTooltip)

        end

        function createAxesContextMenu(obj)
            
            m = uicontextmenu(obj.hFigure);
            
            mitem = uimenu(m, 'Text', 'Add Cranial Window...');
            mitem.Callback = @(src, event) obj.addObjectToMouse('window');
            
            mitem = uimenu(m, 'Text', 'Add Injections Spots...');
            mitem.Callback = @(src, event) obj.addObjectToMouse('injection');
            
            mitem = uimenu(m, 'Text', 'Add Annotation...');
            mitem.Callback = @(src, event) obj.addObjectToMouse('annotation');
            
% %             mitem = uimenu(m, 'Text', 'Show Map Labels');
% %             mitem.Callback = @obj.showMapLabels;
            
            obj.hAxes.UIContextMenu = m;
            
        end
        
        
    end
    
    
    methods
        
        function S = getFovOrientation(obj)
            % Translate fieldnames from settings file to fieldnames for
            % orientation property in FoV class definition.
            S.isMirroredX = obj.settings.fovOrientation.flipHorizontal;
            S.isMirroredY = obj.settings.fovOrientation.flipVertical;
            S.theta = obj.settings.fovOrientation.rotationAngle;
        end
        
        
        function createAnnotationAxes(obj)
            
            %Todo: Remove this. Move some things as widget to ui component
            %axes. Ie, the tooltip/datacursor info textbox
            
            obj.hAnnotationAxes = axes(obj.hFigure);
            obj.hAnnotationAxes.Units = 'pixel';
            obj.hAnnotationAxes.Position = obj.hAxes.Position;
            obj.hAnnotationAxes.XLim = [1, obj.hAnnotationAxes.Position(3)];
            obj.hAnnotationAxes.YLim = [1, obj.hAnnotationAxes.Position(4)];
            obj.hAnnotationAxes.Tag = 'Annotation Axes'; 
            
            hLink = linkprop([obj.hAxes, obj.hAnnotationAxes], 'Position');
            setappdata(obj.hAnnotationAxes, 'LinkObject', hLink)
            
            obj.hAnnotationAxes.Visible = 'off';
            obj.hAnnotationAxes.HandleVisibility = 'off';
            
            %obj.plotCurrentPoint()
            obj.plotInfoBox()
            
            obj.hHighlightedRegion = patch([1,1,1,1], [1,1,1,1], 'c', 'Parent', obj.hAxes);
            obj.hHighlightedRegion.PickableParts = 'none';
            obj.hHighlightedRegion.HitTest = 'off';
            
        end
        
        
        function plotCurrentPoint(obj)
            
            mode = 'crosshair'; %smallcross | blob
            
            switch mode
                case 'crosshair'
                    xLim = obj.hAnnotationAxes.XLim;
                    yLim = obj.hAnnotationAxes.YLim;
                    
                    obj.hCurrentPoint = plot(xLim, [0, 0], '--', 'Color', ones(1,3)*0.5);
                    obj.hCurrentPoint(2) = plot([0, 0], yLim, '--', 'Color', ones(1,3)*0.5);
                    
                case 'smallcross'
                    obj.hCurrentPoint = plot(0, 0, '+');
                    obj.hCurrentPoint.Color = 'k';
                    obj.hCurrentPoint.LineWidth = 1;
                    
                case 'blob'
                    coords = obj.getCurrentPointCoords();
                    obj.hCurrentPoint = patch(coords(:,1), coords(:,2), 'k');
                    obj.hCurrentPoint.EdgeColor = 'k';
                    obj.hCurrentPoint.FaceAlpha = 0.3;
            end
            
            
            set(obj.hCurrentPoint, 'Parent', obj.hAnnotationAxes)
            set(obj.hCurrentPoint, 'PickableParts', 'none')
            set(obj.hCurrentPoint, 'HitTest', 'off')

            
        end
        
        
        function plotInfoBox(obj)
            
            obj.hInfoBox = text(obj.hAnnotationAxes, 0,0, ''); 
            
            obj.hInfoBox(1).Color = ones(1,3)*0.9;
            obj.hInfoBox(1).VerticalAlignment = 'bottom';
            obj.hInfoBox(1).Margin = 5;
            obj.hInfoBox(1).FontSize = 12;
            x = obj.hInfoBox(1).Extent([1,1,3,3]);
            y = obj.hInfoBox(1).Extent([1,4,4,1]);
            
            obj.hInfoBox(2) = patch(obj.hAnnotationAxes, x, y, 'k', 'FaceAlpha', 0.5); 
            obj.hInfoBox(2).Clipping = 'off';
            uistack(obj.hInfoBox(1), 'up')
            set(obj.hInfoBox, 'Visible', 'off');
        end
        
        
        function updateInfoBox(obj, msg)
            
            if isempty(obj.hInfoBox); return; end
            
            coords = get(obj.hAnnotationAxes, 'CurrentPoint');
            
            obj.hInfoBox(1).String = msg;
            obj.hInfoBox(1).Position(1:2) = coords(1, 1:2) + [10, 10];
            
            % todo: update size only when text changes. otherwise, just
            % apply shift.
            
            x = obj.hInfoBox(1).Extent([1,1,1,1]) + obj.hInfoBox(1).Extent([3,3,3,3]) .* [0,0,1,1] + [-1,-1,1,1].*2.5;
            y = obj.hInfoBox(1).Extent([2,2,2,2]) + obj.hInfoBox(1).Extent([4,4,4,4]) .* [0,1,1,0] + [-1,1,1,-1].*2.5;
            
            obj.hInfoBox(2).XData = x;
            obj.hInfoBox(2).YData = y;
            
        end
        
        
        function updateCurrentPoint(obj)
            
            if isempty(obj.hCurrentPoint); return; end
            
            coords = get(obj.hAnnotationAxes, 'CurrentPoint');
            if numel(obj.hCurrentPoint) == 1
                obj.hCurrentPoint.XData = obj.hCurrentPoint.XData - mean(obj.hCurrentPoint.XData) + coords(1, 1);
                obj.hCurrentPoint.YData = obj.hCurrentPoint.YData - mean(obj.hCurrentPoint.YData) + coords(1, 2);
            else % Todo: use the modes from plotCurrentPoint instead of this quick solution
                obj.hCurrentPoint(1).YData = obj.hCurrentPoint(1).YData - mean(obj.hCurrentPoint(1).YData) + coords(1, 2);
                obj.hCurrentPoint(2).XData = obj.hCurrentPoint(2).XData - mean(obj.hCurrentPoint(2).XData) + coords(1, 1);
            end
        end
   
        
        function showGraphicalHandle(~, handle)
            if ~isempty(handle) && isequal( handle(1).Visible, 'off')
                set(handle, 'Visible', 'on')
            end
        end
        
        
        function hideGraphicalHandle(~, handle)
            if ~isempty(handle) && isequal( handle(1).Visible, 'on')
                set(handle, 'Visible', 'off')
            end
        end
        
        
        function coords = getCurrentPointCoords(~)
            
            theta = deg2rad( linspace(1, 359, 180) );
            rho = ones(size(theta)) * 5;
            
            [x, y] = pol2cart(theta, rho);
            coords = [x', y'];

        end
        
        
        function decolorMap(obj)
            hPoly = findobj(obj.hAxes, 'Type', 'Polygon');
            
            for i = 1:numel(hPoly)
                newC = repmat(mean(hPoly(i).FaceColor), 1, 3)*1.2;
                newC(newC<0) = 0;
                newC(newC>1) = 1;
                hPoly(i).FaceColor = newC;
            end
            
        end
        
% % % %  Methods for loading and saving database

        function saveFovDatabase(obj, savePath, forceSave)
            
            if nargin < 2
                savePath = '';
            end
            
            if nargin < 3 
                forceSave = false;
            end
            
            % Determine which path is starting point
            if isempty(obj.currentFile)
                initPath = obj.settings.defaultFilePath;
            else
                initPath = obj.currentFile;
            end
            
            % Determine if default path should be used for saving
            if isempty(savePath)
                if obj.settings.useDefaultPath && ~isempty(obj.currentFile)
                    if strcmp(obj.settings.defaultFilePath, obj.currentFile)
                        savePath = obj.settings.defaultFilePath;
                    else
                        answer = questdlg('It seems like you are trying to overwrite the default fov database file with another file. Is this what you want to do?');
                        switch lower(answer)
                            case 'yes'
                                savePath = obj.settings.defaultFilePath;
                            otherwise
                                % Continue to next if block
                        end
                    end
                end
            end

            % Get savePath from user if the default is not to be used.
            if ~exist('savePath', 'var') || isempty(savePath)
                [filename, folder] = uiputfile({'*.mat'}, '', initPath);
                savePath = fullfile(folder, filename);
                if isempty(filename) || isequal(filename, 0)
                    return
                end
            end
            
            fovDb = obj.fovDatabase;
            
            dbFields = fieldnames(fovDb);
            
            % Clean database before saving, i.e remove plot handles...
            for i = 1:numel(fovDb)
                for j = 1:numel(dbFields)
                    if isa(fovDb(i).(dbFields{j}), 'fovmanager.mapobject.BaseObject')
                        fovDb(i).(dbFields{j}) = fovDb(i).(dbFields{j}).toStruct();
                    end
                end
% %                 fovDb(i).Windows = fovDb(i).Windows.toStruct();
% %                 fovDb(i).Injections = fovDb(i).Injections.toStruct();
            end
            
            save(savePath, 'fovDb')
            obj.isSaved = true;
            
            obj.updateRecentFilesList(savePath)
            
            % Its a little bit funny if something like this does not
            % already exist for printing output on 80 chars per line.
            msg = sprintf('FoV Inventory saved to "%s"', savePath);
            newStr = '';
            lineLength = 78;
            for ii = 1:lineLength:numel(msg)
                ie = ii+lineLength-1;
                if ie > numel(msg); ie = numel(msg); end
                newStr = sprintf('%s%s\n', newStr, msg(ii:ie) );
            end
            fprintf('%s', newStr)
            
        end
        
        
        function loadFovDatabase(obj, loadPath)
            
            % Todo: Add or replace mice in list and plot windows, fovs etc.        
            if ~isempty(obj.fovDatabase)
                answer = questdlg('This will remove all the existing entries. Do you want to continue?');
                if isempty(answer); answer = 'cancel'; end
                
                switch lower(answer)
                    case 'yes'
                        obj.resetGui()
                    case {'no', 'cancel'}
                        return
                end
            end 
            
            % Get file to load, from settings or user input
            if isempty(obj.currentFile)
                initPath = obj.settings.defaultFilePath;
            else
                initPath = obj.currentFile;
            end
           
            if nargin < 2 || isempty(loadPath)
            
                if obj.settings.useDefaultPath
                    loadPath = obj.settings.defaultFilePath;
                else
                    obj.msgBox.displayMessage('Pick a file with a FoV Inventory...')
                    pause(0.7)
                    [filename, folder] = uigetfile({'*.mat'}, '', initPath);
                    loadPath = fullfile(folder, filename);
                    if isempty(filename) || isequal(filename, 0); obj.msgBox.clearMessage();  return; end
                end
                
                
            else
                if ~exist(loadPath, 'file')
                    obj.msgBox.displayMessage('File does not exist, removing from list.', 2)
                    obj.updateRecentFilesList(loadPath, 'remove')
                    return
                end
            end
            
            obj.msgBox.displayMessage('Please wait while loading file...')
            C = onCleanup(@() obj.msgBox.clearMessage);
            
            S = load(loadPath, 'fovDb');
            obj.currentFile = loadPath;
            
            [~, fileName] = fileparts(loadPath);
            obj.hFigure.Name = sprintf('FOV Manager (%s)', fileName);
            
            
            % Add mouse entries to listbox.
            for i = 1:numel(S.fovDb)
                obj.mouseDropdownMenu.String{i+1} = obj.getMouseLabel(S.fovDb(i));
            end
            
%             mouseNames = cellfun(@(mId) sprintf('mouse %s', mId), {S.fovDb.MouseId}, 'uni', 0);
%             obj.mouseDropdownMenu.String = cat(1, {'None'}, mouseNames');

            % Reset selection of mouse to default (i.e No Selection)
            obj.changeSelectedMouse(0)
            
            % Todo: Save struct db as property
            % Todo: Make method for plotting entry on request. I.e forst
            % time mouse is selected...
            for i = 1:numel(S.fovDb)

                obj.fovDatabase(i).MouseId = S.fovDb(i).MouseId;
                if isfield(S.fovDb(i), 'HeadbarLabel')
                    obj.fovDatabase(i).HeadbarLabel = S.fovDb(i).HeadbarLabel;
                else
                    obj.fovDatabase(i).HeadbarLabel = '';
                end
                obj.fovDatabase(i).Windows = fovmanager.mapobject.CranialWindow.empty;
                obj.fovDatabase(i).Injections = fovmanager.mapobject.InjectionSpot.empty;
                obj.fovDatabase(i).Annotations = fovmanager.mapobject.Annotation.empty;

                obj.changeSelectedMouse(i)

                for j = 1:numel(S.fovDb(i).Windows)
                    hWindow = fovmanager.mapobject.CranialWindow(obj, S.fovDb(i).Windows(j));
                    obj.addObjectToMouse(hWindow)
                    obj.selectedObject = hWindow;

                    for k = 1:numel(S.fovDb(i).Windows(j).fovArray)
                        hFov = fovmanager.mapobject.FoV(obj, S.fovDb(i).Windows(j).fovArray(k));
                        obj.addFov(hFov)
                    end
                end
                
                if isfield(S.fovDb(i), 'Injections')
                    for j = 1:numel(S.fovDb(i).Injections)
                        hInjection = fovmanager.mapobject.InjectionSpot(obj, S.fovDb(i).Injections(j));
                        obj.addObjectToMouse(hInjection)
                    end
                end
                
                if isfield(S.fovDb(i), 'Annotations')
                    for j = 1:numel(S.fovDb(i).Annotations)
                        hAnnotation = fovmanager.mapobject.Annotation(obj, S.fovDb(i).Annotations(j));
                        obj.addObjectToMouse(hAnnotation)
                    end
                end
                
            end

            % Set the mouse selection to "No Selection" (index 0)
            obj.changeSelectedMouse(0)
            obj.isSaved = true;
            
            %obj.msgBox.clearMessage()
            uistack(obj.hObjectInformation, 'top')

            obj.updateRecentFilesList(loadPath)
        end
        
        
        function updateRecentFilesList(obj, newPath, action)
        %updateRecentFilesList Update list of recent files.

            if nargin < 3; action = 'add'; end
            
            recentFiles = getpref('fovmanager', 'recentFiles');
            
            if strcmp(action, 'add')
                % Place current file at the beginning of list of recent files
                if ~contains(recentFiles, newPath)
                    recentFiles = cat(1, {newPath}, recentFiles(1:8));
                else
                    keep = ~contains(recentFiles, newPath);
                    recentFiles = cat(1, {newPath}, recentFiles(keep));
                end
                
            elseif strcmp(action, 'remove')
                keep = ~contains(recentFiles, newPath);
                recentFiles = cat(1, recentFiles(keep), {});
            end
            
            setpref('fovmanager', 'recentFiles', recentFiles);
            
            obj.setSubMenuRecentFiles()
            
        end
        
% % % % Method for saving current view of map to file

        function saveCurrentDisplay(obj)
            
            % Get filepath to folder with gui files
            path = mfilename('fullpath');
            
            % Create a folder for saving screendumps
            saveDir = fullfile(fileparts(path), 'screendump');
            if ~exist(saveDir, 'dir'); mkdir(saveDir); end
            
            % Set axes units to pixels and get pixel size
            axUnits = obj.hAxes.Units;
            obj.hAxes.Units = 'pixel';
            axPos = obj.hAxes.Position;

            % Define a rectangular box around the axes.
            margll = 15;
            margur = 5;
            rect = [-margll, -margll, axPos(3)+margll+margur, axPos(4)+margll+margur];
            
            % Set background color temporarily to white.
            defColor = obj.hFigure.Color;
            obj.hFigure.Color = 'w';
            
            % Get the image
            im = frame2im(getframe(obj.hAxes, rect));
              
            % Reset axes units and figure color
            obj.hAxes.Units = axUnits;
            obj.hFigure.Color = defColor;

            % Create a filename for the image
            mouseName = obj.mouseDropdownMenu.String{obj.mouseDropdownMenu.Value};
            if strcmp(mouseName, 'No Selection')
                mouseName = 'fov';
            end
            fileName = sprintf('%s_%s_%s.png', ...
                                    datestr(now, 'yyyy_mm_dd_HHMMSS'), ...
                                        mouseName, ...
                                           'brainMap' );
            
            imwrite(im, fullfile(saveDir, fileName), 'PNG')
            
        end
        
        
% % % % Mouse and keyboard callbacks

        function onDataCursorToggled(obj, src, evtData)
            if evtData.Value
                obj.showGraphicalHandle(obj.hInfoBox)
                %obj.showGraphicalHandle(obj.hCurrentPoint)
            else
                obj.hideGraphicalHandle(obj.hInfoBox)
                obj.hHighlightedRegion.Vertices = ones(1,2);
                obj.hHighlightedRegion.Faces = 1;
                %obj.hideGraphicalHandle(obj.hCurrentPoint)
            end
        end

        function onMouseOver(obj, src, evt)
            
            % Todo: Debug, updating of textbox size might be a bit slow.
            
            pointerCoords = get(obj.hAxes, 'CurrentPoint');
            
            if obj.isPointerOnAxes(pointerCoords(1, 1:2))
                
                %obj.updateCurrentPoint()
                %obj.showGraphicalHandle(obj.hCurrentPoint)
                
                [regionInd, regionName] = fovmanager.utility.atlas.getRegionAtPoint(pointerCoords(1, 1:2));
                
                hPatch = findobj(obj.hAxes, 'Type', 'Polygon');
                hPatch = flipud(hPatch);
                
                info = sprintf('x = %.2f, y = %.2f', pointerCoords(1,1), pointerCoords(1,2) );
                
                
                if regionInd >= 31; regionInd = regionInd+1; end
                
                if ~isempty(hPatch) && regionInd ~= 0
                    
                    currentPatch = hPatch(regionInd);
                    vertices = currentPatch.Shape.Vertices;
                    
                    if currentPatch.Shape.NumHoles == 1
                        whereIsNan = find(isnan(vertices(:,1)));
                        vertices = vertices(1:whereIsNan-1, :);
                        f = 1:whereIsNan-1;
                    else
                        f=1:length(vertices);
                    end
                    
                    % Update the patch to lay on top of the region which is
                    % currently under the mouse pointer and make it
                    % white and semi-transparent
                    
                    obj.hHighlightedRegion.Vertices = vertices;
                    obj.hHighlightedRegion.Faces = f;
                    
                    obj.hHighlightedRegion.EdgeColor = 'none';
                    obj.hHighlightedRegion.FaceColor = 'w';
                    obj.hHighlightedRegion.FaceAlpha = 0.3;
                    
                    info = sprintf('%s\nRegion: %s', info, regionName);
%                     currentPatch.EdgeColor = 'k';
%                     currentPatch.EdgeColor = currentPatch.FaceColor * 0.8;
%                     currentPatch.LineWidth = 2;
                else
                    obj.hHighlightedRegion.Vertices = ones(1,2);
                    obj.hHighlightedRegion.Faces = 1;
                end
                
                obj.updateInfoBox(info)
                obj.showGraphicalHandle(obj.hInfoBox)

                
            else
                obj.hideGraphicalHandle(obj.hCurrentPoint)
                obj.hideGraphicalHandle(obj.hInfoBox)
            end
            
            drawnow limitrate
            
        end
        
        
        function tf = isPointerOnAxes(obj, coords)
            
            tf = false;
            xLim = obj.hAxes.XLim; yLim = obj.hAxes.YLim;
            
            if coords(1) > xLim(1) && coords(1) < xLim(2)
                if coords(2) > yLim(1) && coords(2) < yLim(2)
                    tf = true;
                end
            end
            
        end
        

        function mousePressAxes(obj, src, event)
            
            if ~isempty(obj.pointerManager.currentPointerTool)
                return
            end
            
            if ~isempty(obj.selectedObject)
                obj.unselectObject()
                
                obj.hSlider.Visible = 'off';
                obj.hSlider.Callback = [];
            end
            
        end
        
        
        function keyPress(obj, src, event)
            
            
            wasCaptured = obj.pointerManager.onKeyPress([], event);
            
            switch event.Key
                
                case 's'
                    if isempty(event.Modifier)
                        obj.saveCurrentDisplay()
                    end
                case 'backspace'
                    obj.selectedObject.delete()
                    
                case 'h'
                    if any(contains(event.Modifier, {'shift'}))
                        obj.showHelp()
                    end
                    
                case 'p'
                    if any(contains(event.Modifier, {'command', 'control'}))
                        obj.editSettings()
                    end
                    
                case {'uparrow', 'downarrow'}
                    if any(contains(event.Modifier, {'alt'}))
                        if strcmp(event.Key, 'uparrow')
                            obj.changeSelectedMouse('prev')
                        else
                            obj.changeSelectedMouse('next')
                        end
                    end
                    
% %                 case 'tab'
% %                     

                case 'w'
                    if any(contains(event.Modifier, {'shift'}))
                        obj.resetZoom()
                    end
            end
            
        end
        

        function keyPressObject(obj, src, event)
            
            wasCaptured = obj.pointerManager.onKeyPress([], event);
            
            tmpH = obj.selectedObject;
            if isempty(obj.selectedObject); return; end
            
            switch event.Key
                case 'h'
                    try
                        tmpH.fliplr();
                        obj.isSaved = false;
                    catch ME
                        obj.msgBox.displayMessage(ME.message, 3)
                    end
                    
                case 'v'
                    try
                        tmpH.flipud();
                        obj.isSaved = false;
                    catch ME
                        obj.msgBox.displayMessage(ME.message, 3)
                    end
                    
                case 'r'
                    theta = 90; % Cw rotation

                    if contains({'control'}, event.Modifier)
                        theta = theta/90;
                    end

                    if contains({'shift'}, event.Modifier)
                        theta = -1*theta;
                    end

                    tmpH.rotate(theta)
                    
                    obj.isSaved = false;
                    
                case {'uparrow', 'downarrow', 'leftarrow', 'rightarrow'}  % Move object...

                    switch event.Key
                        
                       case 'uparrow'
                            shift = [0, 0.01];
                       case 'downarrow'
                            shift = [0, -0.01];
                       case 'leftarrow'
                            shift = [-0.01, 0];
                       case 'rightarrow'
                            shift = [0.01, 0];
                    end
                    
                    if contains({'shift'}, event.Modifier)
                        shift = shift*10;
                    end
                    
                    obj.selectedObject.move(shift);
                    obj.showMapCoordinates('centerPoint')
                    obj.updateMapCoordinates([], [])
                    obj.textCoords.Visible = 'on';
                    pause(0.5)
                    obj.hideMapCoordinates('centerPoint')
                    obj.isSaved = false;
                    
                case 's'
                    if isempty(event.Modifier)
                        obj.saveCurrentDisplay()
                    end
                    
                case 'return'
                    if isa(tmpH, 'fovmanager.mapobject.FoV') && ~isempty(obj.resizeRectHandle)
                        obj.finishResizeFov()
                    end
                    
                case 'backspace'
                    if obj.settings.askBeforeDelete
                        obj.selectedObject.requestdelete()
                    else
                        obj.selectedObject.delete()
                    end
                    
                case 'w'
                    if any(contains(event.Modifier, {'shift'}))
                        obj.resetZoom()
                    end
                    
                    
            end
            
            
        end
        
        
% % % % Methods for requesting user input


        function pos = selectMapPosition(obj)
            % Interactive selection of position in map (x, y)
            
            pos = [];
            
            obj.showMapCoordinates('mousePoint')
            
            hImpoint = impoint(obj.hAxes);
            if ~isempty(hImpoint)
                pos = getPosition(hImpoint);
                delete(hImpoint)
            end
            
            pos = round(pos, 1);
            
            obj.hideMapCoordinates('mousePoint')

        end

        
        function sessionIDs = requestSessionIds(obj)
                
            sessionIDs = inputdlg('Enter sessionID');
            if isempty(sessionIDs); return; end

            sessionIDs = strsplit(sessionIDs{1}, ','); % Split by comma (if list was given)
            sessionIDs = strsplit(sessionIDs{1}, ' '); % Split by comma (if list was given)
            sessionIDs = strrep(sessionIDs, '''', ''); % Remove extra apostrophes
            sessionIDs = strrep(sessionIDs, ' ', ''); % Remove extra spaces
            
            % Todo: Sort by valid string.
            
            isValid = cellfun(@(sid) strcmp(strfindsid(sid), sid), sessionIDs);
            
            if any(~isValid)
                msg = sprintf( ['%d/%d of the sessionIDs were not \n',...
                        'valid and will be ignored'], sum(~isValid), numel(isValid));
                obj.msgBox.displayMessage(msg)
                pause(2)
                obj.msgBox.clearMessage()
            end
            
            sessionIDs = sessionIDs(isValid);
            
        end
        
        
        function [mId, hbLabel] = requestMouseInfo(obj, token)
            
            % todo: take current values as input and add as default values
            % in inputdlg.
            
            mId = '';
            hbLabel = '';
            
            % Use input dlg to get info from user
            switch token
                case 'Mouse Id'
                    answer = inputdlg('Enter Mouse ID');
                    if isempty(answer); return; end
                    mId = answer{1};
                case 'Headbar Label'
                    answer = inputdlg('Enter Headbar Label');
                    if isempty(answer); return; end
                    hbLabel = answer{1};
                case 'Mouse Id + Headbar Label'
                    answer = inputdlg({'Enter Mouse Id', 'Enter Headbar Label (optional)'});
                    if isempty(answer); return; end
                    mId = answer{1};
                    hbLabel = answer{2};
            end
            
            % Dont accept anything but a 4 digit mouse ID
            if ~isempty(mId)
                if ~any(numel(mId) == [3,4]) || isnan(str2double(mId))
                    obj.msgBox.displayMessage('Error: Mouse ID must consist of 4 numbers')
                    pause(2)
                    obj.msgBox.clearMessage()
                    mId = '';
                    return
                end
            end
            
        end
        
        
% % % % Database / FOV List methods

        function addMouse(obj, ~, ~)
            
            infoRequest = 'Mouse Id + Headbar Label';
            [mouseId, headbarLabel] = obj.requestMouseInfo(infoRequest);
            
            if isempty(mouseId); return; end

            % Todo: Check if mouse is already in list
            
            % Add mouse info to database
            obj.fovDatabase(end+1).MouseId = mouseId;
            obj.fovDatabase(end).HeadbarLabel = headbarLabel;
            obj.fovDatabase(end).Windows = fovmanager.mapobject.CranialWindow.empty;
            obj.fovDatabase(end).Injections = fovmanager.mapobject.InjectionSpot.empty;
            obj.fovDatabase(end).Annotations = fovmanager.mapobject.Annotation.empty;
            obj.isSaved = false;
            
            obj.mouseDropdownMenu.String{end+1} = obj.getMouseLabel(obj.fovDatabase(end));
            
            % Select the newly created mouse entry. The dropdown menu list
            % has n+1 entries so subtract 1.
            newMouseIndex = numel(obj.mouseDropdownMenu.String) - 1;
            obj.changeSelectedMouse(newMouseIndex)
        end
        
        
        function mLabel = getMouseLabel(~, dbEntry)
            
            mLabel = sprintf('mouse %s', dbEntry.MouseId);
            
            if isfield(dbEntry, 'HeadbarLabel') && ~isempty(dbEntry.HeadbarLabel)
                mLabel = sprintf('%s (%s)', mLabel, dbEntry.HeadbarLabel);
            end
            
        end
        

        function renameMouse(obj, src, ~)

            mInd = obj.getCurrentMouseSelection();
            if mInd == 0 
                obj.msgBox.displayMessage('Hint: No mouse is selected'); 
                pause(1); 
                obj.msgBox.clearMessage;
                return; 
            end
                        
            switch src.Text
                case 'Edit Mouse Id'
                    [mId, ~] = obj.requestMouseInfo('Mouse Id');
                    if isempty(mId); return; end
                    obj.fovDatabase(mInd).MouseId = mId;

                case 'Edit Headbar Label'
                    [~, hbLabel] = obj.requestMouseInfo('Headbar Label');
                    if isempty(hbLabel); return; end
                    obj.fovDatabase(mInd).HeadbarLabel = hbLabel;
            end
            
            mLabel = obj.getMouseLabel(obj.fovDatabase(mInd));
            % Note: +1 because dropdown menu items is length numMice + 1
            obj.mouseDropdownMenu.String{ mInd+1 } = mLabel;
            
        end
        
        
        function deleteMouse(obj, ~, ~)
            mInd = obj.getCurrentMouseSelection();
            if mInd == 0 
                obj.msgBox.displayMessage('Hint: No mouse is selected'); 
                pause(1); 
                obj.msgBox.clearMessage;
                return; 
            end
             
            answer = questdlg('Are you sure? There is way back...'); 
            switch answer
                case 'Yes'
                    delete(obj.fovDatabase(mInd).Windows)
                    obj.fovDatabase(mInd) = [];
                    obj.mouseDropdownMenu.String(mInd+1) = [];
                    obj.changeSelectedMouse(0) % Reset selection
            end
        end

        
        function addObjectToMouse(obj, objectOrType)
            
            currentMouseInd = obj.getCurrentMouseSelection();
            
            if currentMouseInd == 0
                obj.msgBox.displayMessage('Hint: No mouse is selected'); 
                pause(1); obj.msgBox.clearMessage; return; 
            end
            
            if isa(objectOrType, 'char')
                switch objectOrType
                    case 'window'
                        hObject = createWindow(obj);
                    case 'injection'
                        hObject = createInjectionSpots(obj);
                    case 'annotation'
                        hObject = createAnnotation(obj);
                end
            elseif isa(objectOrType, 'fovmanager.mapobject.BaseObject')
                hObject = objectOrType;
            else
                error('Unknown input')
            end
            
            if isempty(hObject); return; end
            
            switch class(hObject)
                case 'fovmanager.mapobject.CranialWindow'
                    dbField = 'Windows';
                case 'fovmanager.mapobject.InjectionSpot'
                    dbField = 'Injections';
                case 'fovmanager.mapobject.Annotation'
                    dbField = 'Annotations';
            end
                        
            % Add callbacks on selection of the window in the gui
            % Should add newWindow as input here.. Then I can avoid putting
            % the windowHandle in the UserData of the plotHandle.
            for i = 1:numel(hObject)
                if ~isfield(obj.fovDatabase(currentMouseInd), dbField)
                    obj.fovDatabase(currentMouseInd).(dbField) = hObject.empty;
                end
                
                obj.fovDatabase(currentMouseInd).(dbField)(end+1) = hObject(i);
                hObject(i).guiHandle.ButtonDownFcn = {@obj.selectObject, hObject(i)};
                
                clearFun = @(src,evt) cleanDatabase(obj, class(hObject(i)));
                addlistener(hObject(i), 'ObjectBeingDestroyed', clearFun );
            end
            
            obj.isSaved = false;
            
            uistack(obj.textCoords, 'top') % NB: Can this be done easier?
            
        end
        
        
        function newWindow = createWindow(obj)

            newWindow = [];
            
            % Check that mouse is selected
            currentMouseInd = obj.getCurrentMouseSelection;
            if isempty(currentMouseInd) || currentMouseInd == 0; errordlg('No mouse is selected'); return; end

            % Request window shape and position from user
            windowShape = fovmanager.mapobject.CranialWindow.requestShape();
            if isempty(windowShape); return; end
            
            pos = obj.selectMapPosition();
            if isempty(pos); return; end

            % Create a new window handle object
            newWindow = fovmanager.mapobject.CranialWindow(obj, pos, windowShape);
            
        end
        
        
        function addWindow(obj, hWindow)
                        
            currentMouseInd = obj.getCurrentMouseSelection(); %NB: First element of lb is none
            
            if currentMouseInd == 0
                obj.msgBox.displayMessage('Hint: No mouse is selected'); 
                pause(1); obj.msgBox.clearMessage; return; 
            end
            
            if nargin < 2
                hWindow = createWindow(obj);
                if isempty(hWindow); return; end
            end
            
            % Add to database
            obj.fovDatabase(currentMouseInd).Windows(end+1) = hWindow;
            
            % Add callbacks on selection of the window in the gui
            % Should add newWindow as input here.. Then I can avoid putting
            % the windowHandle in the UserData of the plotHandle.
            hWindow.guiHandle.ButtonDownFcn = {@obj.selectObject, hWindow};
            
            addlistener(hWindow, 'ObjectBeingDestroyed', @(src,evt) cleanDatabase(obj, 'window'));
            
            obj.isSaved = false;
            
            % NB: Can this be done easier?
            uistack(obj.textCoords, 'top')

        end
        
        
        function newInjections = createInjectionSpots(obj)

            newInjections = [];
            answers = fovmanager.mapobject.InjectionSpot.requestVirusInfo();
            
%             answers = inputdlg({'Enter Number of Injections', 'Enter Name of Virus', 'Enter Volume (nL, can change later)', 'Enter Depth (um, optional)', 'Spread (radius in um, optional)'});
            if isempty(answers); return; end
            
            nInjections = str2double(answers{1});
            virusName = answers{2};
            volume = str2double(answers{3});
            depth = answers{4};
            spread = str2double(answers{5});
            
%             virusName = fovmanager.mapobject.InjectionSpot.requestVirusName();
            
            newInjections = fovmanager.mapobject.InjectionSpot.empty;
            
            for i = 1:nInjections
                pos = obj.selectMapPosition();
                if isempty(pos); return; end

                % Create a new injection handle object
                newInjections(end+1) = fovmanager.mapobject.InjectionSpot(obj, pos, virusName, volume, depth, spread);
                uistack(obj.textCoords, 'top')
            end
            
        end
        
        
        function newAnnotation = createAnnotation(obj)
            newAnnotation = [];
            
            S = fovmanager.mapobject.Annotation.interactiveDialog();
            if S.radius == 0; return; end
            
            pos = obj.selectMapPosition();
            if isempty(pos); return; end

            S.center = pos;
            
            newAnnotation = fovmanager.mapobject.Annotation(obj, S);
            
        end
        
        
        function addInjections(obj, hInjection)
                   
            currentMouseInd = obj.getCurrentMouseSelection();
            if currentMouseInd == 0; obj.msgBox.displayMessage('Hint: No mouse is selected'); pause(1); obj.msgBox.clearMessage; return; end
            
            if nargin < 2
                hInjection = createInjectionSpots(obj);
                if isempty(hInjection); return; end
            end
            
            % Add to database
            currentMouseInd = obj.getCurrentMouseSelection();
            obj.fovDatabase(currentMouseInd).Injections(end+1:end+numel(hInjection)) = hInjection;
            
            % Add callbacks on selection of the window in the gui
            % Should add newWindow as input here.. Then I can avoid putting
            % the windowHandle in the UserData of the plotHandle.
            for i = 1:numel(hInjection)
                hInjection(i).guiHandle.ButtonDownFcn = {@obj.selectObject, hInjection(i)};
                addlistener(hInjection(i), 'ObjectBeingDestroyed', @(src,evt) cleanDatabase(obj, 'injection'));
            end
            
            obj.isSaved = false;
            
            % NB: Can this be done easier?
            uistack(obj.textCoords, 'top')
            
        end
        

        function newFoV = createFov(obj)
            
            newFoV = [];
            
            % Request window shape and position from user
            fovSize = fovmanager.mapobject.FoV.getSize();
            if isempty(fovSize); return; end
            fovCenter = obj.selectMapPosition();
            if isempty(fovCenter); return; end
            
            % Create a new window handle object
            fOr = obj.getFovOrientation();
            newFoV = fovmanager.mapobject.FoV(obj, fovCenter, fovSize/1000, 'orientation', fOr);

            % NB: Can this be done easier?
            uistack(obj.textCoords, 'top')
        end
        
        
        function newFoV = createFovFromSession(obj, sessionID)
            % Todo: Combine this with create Fov
            
            newFoV = [];
            
            if nargin < 2
                sessionID = obj.requestSessionIds();
                if isempty(sessionID); return; end
                sessionID = sessionID{1};
            end
            
            obj.msgBox.displayMessage('Loading data for session')
            data = fovmanager.fileio.getdata(sessionID, ...
                {'fovImage', 'roiArray', 'fovDepth', 'fovSize'});
            obj.msgBox.clearMessage()
            
            fovCenter = obj.selectMapPosition();

            % Create a new window handle object
            fOr = obj.getFovOrientation();
            newFoV = fovmanager.mapobject.FoV(obj, fovCenter, data.fovSize, 'orientation', fOr);
            % Todo add these as struct or name value to initializer...
            newFoV.depth = data.fovDepth;
            newFoV.fovImage = data.fovImage;
            newFoV.nRois = numel(data.roiArray);
            newFoV.showImage()
            newFoV.currentSession = sessionID;
            
            sessionObject = struct;
            sessionObject.sessionID = sessionID;
            sessionObject.depth = data.fovDepth;
            sessionObject.nRois = numel(data.roiArray);
            sessionObject.fovImage = data.fovImage;
            
            newFoV.addSessionObject(sessionObject)

            obj.addFov(newFoV)
            
        end
        
        
        function addFov(obj, hFov)
            
            % Add to current window.
            if isempty(obj.selectedObject) || ~isa(obj.selectedObject, 'fovmanager.mapobject.CranialWindow')
                msgStr = 'Please select a window to add the FOV to';
                obj.msgBox.displayMessage(msgStr, 2)
                return
            end
            
            if nargin < 2
                hFov = createFov(obj);
                if isempty(hFov); return; end
            end
            
            
            currentWindow = obj.selectedObject;
            
            
            hFov.guiHandle.Parent = currentWindow.guiHandle;
            hFov.guiHandle.ButtonDownFcn = {@obj.selectObject, hFov};
            
            if isempty(currentWindow.fovArray)
                hTmp = findobj(currentWindow.guiHandle.UIContextMenu, 'Text', 'Hide Fovs In Window');
                if ~isempty(hTmp)
                    hTmp.Enable = 'on';
                end
            end
            currentWindow.fovArray(end+1) = hFov;
            
            addlistener(hFov, 'ObjectBeingDestroyed', @(src,evt) cleanDatabase(obj, 'fov'));
            obj.isSaved = false;
            
        end
        
        
        function sessionObjects = createSessionObjects(obj, sessionIDs)
            %The idea of having this as a separate method is that some time
            %I want to replace it with the real session object...
            
            sessionObjects = struct.empty;
            
            % Add sessionID, fovImage, roiArray and depth to session struct
            for i = 1:numel(sessionIDs)
                
                sessionObjects(end+1).sessionID = sessionIDs{i};
                try
                    data = fovmanager.fileio.getdata(sessionIDs{i}, {'roiArray', 'fovDepth', 'fovImage'});
                    sessionObjects(end).nRois = numel(data.roiArray);
                    sessionObjects(end).depth = data.fovDepth;
                    sessionObjects(end).fovImage = data.fovImage;
                catch
                    sessionObjects(end).nRois = [];
                    sessionObjects(end).depth = [];
                    sessionObjects(end).fovImage = obj.selectedObject.image;
                end
                    
            end

        end
        
        
        function addSession(obj, sessionIDs)
            % Todo: Do I need the same method in the FoV Class?
            
            if nargin < 2
                sessionIDs = obj.requestSessionIds();
            end
            
            if isempty(sessionIDs); return; end
            
            % Add to current Fov.
            currentFov = obj.selectedObject;
            assert(isa(currentFov, 'fovmanager.mapobject.FoV'), 'Cannot add sessions to the selected object, because it is not a FoV')

            % Ignore sessions that are already part of the FoV
            ignore = currentFov.containsSession(sessionIDs);
            sessionIDs = sessionIDs(~ignore);
            
            obj.msgBox.displayMessage('Loading data for session(s)')
            sessionObjects = obj.createSessionObjects(sessionIDs);
            obj.msgBox.clearMessage()

            currentFov.addSessionObject(sessionObjects)
            currentFov.changeSession(sessionIDs{end})
            
        end
        
        
        function removeSession(obj, sessionIDs)
            
            % Request sessionIDs from user if no sessionID is provided.
            if nargin < 2
                % Remove from current Fov.
                currentFov = obj.selectedObject;
                currentSessionIDs = {currentFov.listOfSessions.sessionID};
            
                [IND, ~] = listdlg('ListString', currentSessionIDs, ...
                                    'SelectionMode', 'multi', ...
                                    'ListSize', [250, 200], ...
                                    'Name', 'Select Sessions');

                if isempty(IND); return; end
                sessionIDs = currentSessionIDs(IND);
            end
            
            currentFov.removeSession(sessionIDs)
            
        end
        
        
        function cleanDatabase(obj, objectClass)
            % Remove elements from database when they are deleted from gui.
            
            % Assuming the deleted object is always the selected one.
            % NB! This could change in the future
            if ~isvalid(obj); return; end
            
            if ~isempty(obj.selectedObject) && ~isvalid(obj.selectedObject)
                obj.selectedObject = [];
            end
            
                        
            mInd = obj.getCurrentMouseSelection();
            if mInd == 0; return; end
            
            switch objectClass 
                case {'window', 'fovmanager.mapobject.CranialWindow'}
                    isDeletedWindow = ~isvalid(obj.fovDatabase(mInd).Windows);
                    obj.fovDatabase(mInd).Windows(isDeletedWindow) = [];
                case {'fov', 'fovmanager.mapobject.FoV'}
                    for i = 1:numel(obj.fovDatabase(mInd).Windows)
                        isDeletedFov = ~isvalid(obj.fovDatabase(mInd).Windows(i).fovArray);
                        if any(isDeletedFov)
                            obj.fovDatabase(mInd).Windows(i).fovArray(isDeletedFov) = [];
                        end
                    end
                case {'injection', 'fovmanager.mapobject.InjectionSpot'}
                    isDeletedInjection = ~isvalid(obj.fovDatabase(mInd).Injections);
                    obj.fovDatabase(mInd).Injections(isDeletedInjection) = [];
                case {'annotation', 'fovmanager.mapobject.Annotation'}
                    isDeletedAnnot = ~isvalid(obj.fovDatabase(mInd).Annotations);
                    obj.fovDatabase(mInd).Annotations(isDeletedAnnot) = [];
            end
            
            obj.isSaved = false;

        end 
        
        
        function clearDatabase(obj)
            
            for i = 1:numel(obj.fovDatabase)
                delete(obj.fovDatabase(i).Windows)
                delete(obj.fovDatabase(i).Injections)
                delete(obj.fovDatabase(i).Annotations)
            end

            obj.fovDatabase=[];
        end 
        
        
        function resetGui(obj)
        %resetGui Reset app by clearing database, mouse list and plot handles 
        
            obj.clearDatabase()
            obj.changeSelectedMouse(0) % Reset mouse selection
            obj.mouseDropdownMenu.String(2:end) = [];
            delete(obj.tempFovHandles); obj.tempFovHandles = [];
        
            if ~isempty(obj.resizeRectHandle)
                finishResizeFov(obj)
            end
            
        end
        
% % % % Display coordinates of map position

        function showMapCoordinates(obj, pointToDisplay)
            obj.textCoords.Visible = 'on';
            obj.mapCoordinatesMode = pointToDisplay;
            
            % this is a bit hacky, but thats unfortunately how it is.
            % Assign mouse motion listener if it is empty. It will not be
            % empty if map object was selected. Then the startDrag assigns
            % moveObject to mousemotion event, and moveObject already calls
            % the updateCoordinatesMethod.
            if isempty(obj.WindowMouseMotionListener)
                el = listener(obj.hFigure, 'WindowMouseMotion', @obj.updateMapCoordinates);
                obj.WindowMouseMotionListener = el(1);
            end
            
            if strcmp(pointToDisplay, 'centerPoint')
                h = findobj(obj.selectedObject.guiHandle, 'Tag', 'CenterPoint', '-depth', 1);
                h.Visible = 'on';
            end
        end
        
        
        function hideMapCoordinates(obj, point)
            obj.textCoords.Visible = 'off';
            obj.mapCoordinatesMode = 'none';

            if ~isempty(obj.WindowMouseMotionListener)
                delete(obj.WindowMouseMotionListener)
                obj.WindowMouseMotionListener = [];
            end
            
            if strcmp(point, 'centerPoint')
                h = findobj(obj.selectedObject.guiHandle, 'Tag', 'CenterPoint', '-depth', 1);
                h.Visible = 'off';
            end
            
        end
        
        
        function updateMapCoordinates(obj, ~, ~)
            
            mousePoint = obj.hAxes.CurrentPoint(1, 1:2);
            x = round(mousePoint(1), 2);
            y = round(mousePoint(2), 2);

            xLim = obj.hAxes.XLim; yLim = obj.hAxes.YLim;
            axLim = [xLim(1), yLim(1), xLim(2), yLim(2)];

            % Check if mousepoint is within axes limits.
            if ~any(any(diff([axLim(1:2); [x, y]; axLim(3:4)]) < 0))
                
                switch obj.mapCoordinatesMode
                    case 'mousePoint' 
                        obj.textCoords.Position(1:2) = [x,y] + [0.2, 0.2];
                        obj.textCoords.String = sprintf('x=%.1f, y=%.1f', x, y);
                    
                    case 'centerPoint' % Plot coordinates of center point of object.
                        x = obj.selectedObject.center(1);
                        y = obj.selectedObject.center(2);
                        obj.textCoords.Position(1:2) = [x, y] + [0.3, 0.3];
                        obj.textCoords.String = sprintf('x=%.2f, y=%.2f', x, y);
                        
                end
                    
            else
                obj.textCoords.Visible = 'off';
            end
            
        end
        
        
% % % % Callbacks for interaction with objects (fov and window)

        function selectObject(obj, src, event, object)
            
            % adaptstion to easily use pointertools without major
            % modifications
            if ~isempty(obj.pointerManager.currentPointerTool)
                obj.pointerManager.currentPointerTool.onButtonDown(src, event)
                return
            end
            
            % Zoom in or out of object on doubleclick.
            if strcmp(obj.hFigure.SelectionType, 'open') && event.Button == 1
                obj.zoomOnDoubleClick(src, object)
                return
            end
            
            % Unselect old handle
            if ~isequal(obj.selectedObject, object)
                if ~isempty(obj.selectedObject)
                    obj.unselectObject()
                end
            end
            
            % Make Outline White
            hTmp = findobj(src, '-regexp', 'Tag', 'Outline', '-depth', 1);
            
            if isa(hTmp, 'matlab.graphics.chart.primitive.Line')
                hTmp.Color = obj.PLOTCOLORS.EdgeColorSelected;
            else
                hTmp.EdgeColor = obj.PLOTCOLORS.EdgeColorSelected;
            end
            
            if isa(object, 'fovmanager.mapobject.BaseObject') && ~isa(object, 'fovmanager.mapobject.CranialWindow')
                object.showInfo()
            end
            
% % %                 uistack(object.guiHandle, 'top')
% % %                 infoStr = object.getInfoText();
% % %                 if ~isempty(infoStr)
% % %                     infoPos = object.getInfoPosition();
% % %                     obj.hObjectInformation.String = infoStr;
% % %                     obj.hObjectInformation.Position = infoPos;
% % %                     obj.hObjectInformation.Visible = 'on';
% % %                 end
% % %             end
            

            obj.selectedObject = object;

            obj.startDrag(src, event, object)

            if isa(object, 'fovmanager.mapobject.BaseObject')
                obj.hFigure.WindowKeyPressFcn = @obj.keyPressObject;
            end

            % Unselect all other handles... % Todo: Make unselect a method.
            
            % Add object to transparency slider callback
            if isa(object, 'fovmanager.mapobject.CranialWindow') || isa(object, 'fovmanager.mapobject.FoV') || isa(object, 'fovmanager.mapobject.Annotation')
                obj.hSlider.Callback = @object.setImageAlpha;
            end
        end
        
        
        function unselectObject(obj)
            
            if isa(obj.selectedObject, 'fovmanager.mapobject.BaseObject') && ~isa(obj.selectedObject, 'fovmanager.mapobject.CranialWindow')
                obj.selectedObject.hideInfo()
            end
% % %                 obj.hObjectInformation.String = '';
% % %                 obj.hObjectInformation.Position = [0,0];
% % %                 obj.hObjectInformation.Visible = 'off';
% % %             end
            
            hTmp = findobj(obj.selectedObject.guiHandle, '-regexp', 'Tag', 'Outline', '-depth', 1);
            if isa(hTmp, 'matlab.graphics.chart.primitive.Line')
                hTmp.Color = 'none';
            else
                hTmp.EdgeColor = obj.PLOTCOLORS.EdgeColor;
                hTmp.EdgeColor = obj.selectedObject.boundaryColor;
            end
                    
            obj.selectedObject=[];
            obj.hFigure.WindowKeyPressFcn = @obj.keyPress;

            obj.hSlider.Value = 0.5;
            
        end
        
        
        function startDrag(obj, ~, event, object)
            
            % NB: Call this before assigning moveObject callback. Update
            % coordinates callback is activated in the moveObject
            % function..
            
            el(1) = listener(obj.hFigure, 'WindowMouseMotion', @(src, event) obj.moveObject(object));
            el(2) = listener(obj.hFigure, 'WindowMouseRelease', @(src, event) obj.stopDrag);
            obj.WindowMouseMotionListener = el(1);
            obj.WindowMouseReleaseListener = el(2);
            
% %             obj.showMapCoordinates('centerPoint')
% %             obj.updateMapCoordinates() % important to call this here, because the textobject might contain coords from another previously selected object.

            x = event.IntersectionPoint(1);
            y = event.IntersectionPoint(2);
            obj.prevMousePointAx = [x, y];
            
        end
        
        
        function moveObject(obj, h)
        %moveObject Execute when mouse is dragging a selected object    
        
            % Update center coords
            if strcmp(obj.textCoords.Visible, 'off')
                obj.showMapCoordinates('centerPoint')
            end
            
            obj.updateMapCoordinates()

            obj.isSaved = false;
            
            newMousePointAx = obj.hAxes.CurrentPoint(1, 1:2);            
            shift = newMousePointAx - obj.prevMousePointAx;
            
            % Selected object. Force move if shift-click
            h.move(shift, strcmp(obj.hFigure.SelectionType, 'extend'));

            obj.prevMousePointAx = newMousePointAx;
                
        end
        
        
        function stopDrag(obj)
        %stopDrag Execute when mouse is released from a selected object

            delete(obj.WindowMouseMotionListener)
            delete(obj.WindowMouseReleaseListener)
            obj.WindowMouseMotionListener = [];
            obj.WindowMouseReleaseListener = [];
            
            obj.hideMapCoordinates('centerPoint')
            
        end
        
        
% %         function setDefaultWindowButtonCallbacks(obj)
% %             
% %             obj.hFigure.WindowButtonMotionFcn = [];%@obj.onMouseOver;
% %             obj.hFigure.WindowButtonUpFcn = [];
% %             
% %         end
        
        
        function startResizeFov(obj, ~, ~)
            
            if ~isempty(obj.resizeRectHandle)
                msg = sprintf('You have to finish the \n current resize operation.');
                obj.msgBox.displayMessage(msg, 3)
                return
            end
            
            thisFov = obj.selectedObject;
            assert(isa(thisFov, 'fovmanager.mapobject.FoV') || isa(thisFov, 'fovmanager.mapobject.Annotation'), 'Object to resize is not a FoV. Something has gone wrong.')
           
            % Create an imrect object
% %             rcc = thisFov.edge;
% %             fovPosition = [ min(rcc), range(rcc) ];
            
            % Find coordinates from the plotted outline, since this can
            % vary from the actual coordinates. Why the fuck...
            h = findobj(thisFov.guiHandle, '-regexp', 'Tag', 'Outline');
            xCoords = h.XData; yCoords = h.YData;
            objPosition = [min(xCoords), min(yCoords), range(xCoords), range(yCoords)];
            
            obj.resizeRectHandle = imrect(obj.hAxes, objPosition);           
            obj.resizeRectHandle.addNewPositionCallback(@(pos) thisFov.resize(pos));
            
            % Edit the context menu of the rectangle. TODO: Add customs..
            hComp = findobj(obj.resizeRectHandle, 'Type', 'line', '-or', 'Type', 'patch');
            hCMenu = hComp(1).UIContextMenu;

            delete(hCMenu.Children([1,3,4])) % Delete items from the menu, but keep the option to fix aspect ratio.
            
            mitem = uimenu(hCMenu,'Label', 'Finish');
            mitem.Callback = {@(src, event) obj.finishResizeFov};
            
        end
        
        
        function finishResizeFov(obj)
            delete(obj.resizeRectHandle);
            obj.resizeRectHandle = [];
        end
        
        
        function zoomOnDoubleClick(obj, plotHandle, object)
                
                % Find the objects outline.
                hTmp = findobj(plotHandle, 'Type', 'Patch', '-depth', 1);
                
                % Simple version...
%                     obj.hAxes.XLim = [min(hTmp.XData), max(hTmp.XData)];
%                     obj.hAxes.YLim = [min(hTmp.YData), max(hTmp.YData)];
                
                % Get axes limits
                xLim = obj.hAxes.XLim;
                yLim = obj.hAxes.YLim;
                   
                % Calculate aspect ratio of axes and object 
                arAxes = range(xLim) / range(yLim);
                arObject = range(hTmp.XData) / range(hTmp.YData);
                
                % Get center of object
                centerX = min(hTmp.XData) + range(hTmp.XData)/2;
                centerY = min(hTmp.YData) + range(hTmp.YData)/2;
                
                % Zoom Factor. @ 1, the object will occupy the whole zoomed
                % in view. @ 2, the object will occupy the half of the 
                % zoomed in view.
                zF = 1.1; zF = zF/2;
                
                objectZoomXLim = centerX + [-zF, zF] .* range(hTmp.XData);
                objectZoomYLim = centerY + [-zF, zF] .* range(hTmp.YData);

                if objectZoomYLim(1) < -9 || objectZoomYLim(2) > 7 
                    obj.resetZoom(); return
                end
                                
                
                if arAxes < arObject % Width of x-axis is limiting factor
                    if isequal(xLim, objectZoomXLim) % zoom out
                        if isa(object, 'fovmanager.mapobject.CranialWindow') || ...
                                isa(object, 'fovmanager.mapobject.InjectionSpot') || ...
                                    isa(object, 'fovmanager.mapobject.Annotation') % Show whole map
                            obj.resetZoom()

                        elseif isa(object, 'fovmanager.mapobject.FoV') % Show window
                            % Find parent plot handle
                            pTmp = findobj(plotHandle.Parent, 'Type', 'Patch', '-depth', 1);
                            if ~isempty(pTmp)
                                obj.zoomOnDoubleClick(pTmp, fovmanager.mapobject.CranialWindow.empty)
                            else
                                obj.resetZoom()
                            end
                        end
                    else % zoom in
                        
                        obj.hAxes.XLim = objectZoomXLim; % [min(hTmp.XData), max(hTmp.XData)].*1.5;
                        newYrange = range(objectZoomXLim)./arAxes;
                        obj.hAxes.YLim = centerY + [-0.5, 0.5] .* newYrange;
                        %obj.hAxes.GridAlpha = 0;
                        obj.hAxes.Layer = 'top';    
                    end
                    
                else % Width of y-axis is limiting factor
                    if isequal(yLim, objectZoomYLim) % zoom out
                        if isa(object, 'fovmanager.mapobject.CranialWindow') || isa(object, 'fovmanager.mapobject.InjectionSpot') % Show whole map
                            obj.resetZoom()
                        elseif isa(object, 'fovmanager.mapobject.FoV') % Show window
                            % Find parent plot handle
                            pTmp = findobj(plotHandle.Parent, 'Type', 'Patch', '-depth', 1);
                            obj.zoomOnDoubleClick(pTmp, fovmanager.mapobject.CranialWindow.empty)
                        end
                    else % zoom in
                        obj.hAxes.YLim = objectZoomYLim;
                        newXrange = range(objectZoomYLim).*arAxes;
                        obj.hAxes.XLim = centerX + [-0.5, 0.5] .* newXrange;
                        %obj.hAxes.GridAlpha = 0;
                        obj.hAxes.Layer = 'top';                    
                    end
                end
                drawnow
        end
        
        
        function resetZoom(obj, ~, ~)
            
            % Todo. Set limits based on map limits. When multiple maps are
            % available.
            
            obj.hAxes.XLim = [-6, 6];
            obj.hAxes.YLim = [-9, 7];

        end
        

% % % % Callback Methods
        
        function onMouseSelectionChanged(obj, src, ~)
        %onMouseSelectionChanged Callback on listbox/popupmenu selection
            % NB! To make life easy, I added an element to the top of the
            % list called None. The actual mouse index is therefore the
            % listbox value - 1.
        
            newMouseIndex = src.Value-1;
            obj.changeSelectedMouse(newMouseIndex)
            
        end
        
        function currentMouseInd = getCurrentMouseSelection(obj)
        %getCurrentMouseSelection Get current mouse selection
        %
        %   Note: This method corrects for the fact that the mouse
        %   selection control contains one more entry then the number of
        %   mice (i.e the No Selection option)
            if isvalid(obj.mouseDropdownMenu)
                currentMouseInd = obj.mouseDropdownMenu.Value-1;
            else
                currentMouseInd = [];
            end

        end
        
        function setCurrentMouseSelection(obj, currentMouseInd)
            % Make sure value of dropdown selection menu is updated.
            if currentMouseInd ~= obj.mouseDropdownMenu.Value + 1
                obj.mouseDropdownMenu.Value = currentMouseInd + 1;
            end
        end
        
        
        function changeSelectedMouse(obj, currentMouseInd)

            % Hide windows for other mice and show window for this mouse
            
            % Todo: Generalize, so that I can add more fovmanager.mapobject.BaseObjects and have
            % this code take care of that automatically. i.e loop over
            % fields in the fovDatabase....
            
            % If no number is supplied, just run a refresh on the current
            % selection.
            if nargin < 2
                currentMouseInd = obj.getCurrentMouseSelection();
            end
            
            if isa(currentMouseInd, 'char')
                switch currentMouseInd
                    case 'prev'
                        currentMouseInd = obj.getCurrentMouseSelection();
                        currentMouseInd = currentMouseInd - 1;

                    case 'next'
                        currentMouseInd = obj.getCurrentMouseSelection();
                        currentMouseInd = currentMouseInd + 1;
                end
            end
            
            % Return if mouse selection is outside of selection range
            if currentMouseInd < 0 || currentMouseInd > numel(obj.fovDatabase)
                return
            end
            
            
            for i = 1:numel(obj.fovDatabase)
                if ~isempty(obj.fovDatabase(i).Windows)
                    tmpH = [obj.fovDatabase(i).Windows(:).guiHandle];
                    
                    if i == currentMouseInd
                        set(tmpH, 'Visible', 'on')
                        set(tmpH, 'HandleVisibility', 'on')
                    else
                        set(tmpH, 'Visible', 'off')
                        set(tmpH, 'HandleVisibility', 'off')

                    end
                end
                
                
                if ~isempty(obj.fovDatabase(i).Injections)
                    tmpH = [obj.fovDatabase(i).Injections(:).guiHandle];
                    
                    if i == currentMouseInd && obj.settings.showInjections
                        set(tmpH, 'Visible', 'on')
                        set(tmpH, 'HandleVisibility', 'on')
                    else
                        set(tmpH, 'Visible', 'off')
                        set(tmpH, 'HandleVisibility', 'off')
                    end
                end
                
                
                if isfield(obj.fovDatabase(i), 'Annotations') && ~isempty(obj.fovDatabase(i).Annotations)
                    tmpH = [obj.fovDatabase(i).Annotations(:).guiHandle];
                    
                    if i == currentMouseInd % && obj.settings.showAnnotations
                        set(tmpH, 'Visible', 'on')
                        set(tmpH, 'HandleVisibility', 'on')
                    else
                        set(tmpH, 'Visible', 'off')
                        set(tmpH, 'HandleVisibility', 'off')
                        
                        for j = 1:numel(tmpH)
                            if isfield(tmpH(j).UserData, 'isPersistent') && tmpH(j).UserData.isPersistent
                                set(tmpH(j), 'Visible', 'on')
                                set(tmpH(j), 'HandleVisibility', 'on')
                            end
                        end
                        
                    end
                end
                
            end
            
            % Make sure value of dropdown selection menu is updated.
            obj.setCurrentMouseSelection(currentMouseInd)
            
            
            obj.makeBackgroundOpaque()
            
        end
        
        
        function showTransparencySlider(obj, ~, ~)
            obj.hSlider.Visible = 'on';
        end
        
        
        function showFovsInWindow(obj, src, ~)
            
            switch src.Text
                case 'Hide Fovs In Window'
                    src.Text = 'Show Fovs In Window';
                    visibleState = 'off';
                case 'Show Fovs In Window'
                    src.Text = 'Hide Fovs In Window';
                    visibleState = 'on';
            end
            
            mInd = obj.getCurrentMouseSelection();
            windowH = obj.fovDatabase(mInd).Windows(1);
            
            tmpH = findobj(windowH.guiHandle, 'DisplayName', 'FoV');
            set(tmpH, 'Visible', visibleState)
            
        end
        
        
% % % % Methods for displaying 

        function showAllFovs(obj, src, ~)
        
            
            if strcmp(src.Text, 'Show All FoVs')
            
                nFovs = numel(findall(obj.hAxes, 'DisplayName', 'FoV'));
                nFovs = nFovs / 2; % If fovs are already copied to axes, 
                                                % there are twice as many
                
                % Set the mouse selection to no selection (index 0) 
                obj.changeSelectedMouse(0)
                                                
                if isempty(obj.tempFovHandles) || nFovs ~= numel(obj.tempFovHandles)

                    obj.msgBox.displayMessage('Please wait, this may take a minute...')
                    drawnow

                    if ~isempty(obj.tempFovHandles)
                        delete(obj.tempFovHandles)
                    end

                    % "Turn off" edge color of selected fovs 
                    if isa(obj.selectedObject, 'fovmanager.mapobject.FoV')
                        hTmp = findobj(obj.selectedObject.guiHandle, 'Type', 'Patch', '-depth', 1);
                        hTmp.EdgeColor = obj.PLOTCOLORS.EdgeColor;
                    end

                    fovH = findall(obj.hAxes, 'DisplayName', 'FoV');
                    obj.tempFovHandles = copyobj(fovH, obj.hAxes);

                    for i = 1:numel(obj.tempFovHandles)
                        h = findobj(obj.tempFovHandles(i), 'Tag', 'Roi Centers');
                        if ~isempty(h); delete(h); end
                    end

                    % Recolor selected fov.
                    if exist('hTmp', 'var')
                        hTmp.EdgeColor = obj.PLOTCOLORS.EdgeColorSelected;
                    end
                    
                    obj.msgBox.clearMessage()

                end
            end
            
            switch src.Text
                
                case 'Show All FoVs'
                    set(obj.tempFovHandles, 'Visible', 'on')
                    src.Text = 'Hide All FoVs';
                case 'Hide All FoVs'
                    set(obj.tempFovHandles, 'Visible', 'off')
                    src.Text = 'Show All FoVs';
            end
                
        end
        
        
        function showGrid(obj, src, ~)
            
            S = obj.getAppearance();
            
            if src.Value
                obj.hAxes.Layer = 'top';
                src.Tooltip = 'Hide Grid';
                obj.hAxes.GridAlpha = S.AxesGridAlpha;
                obj.hAxes.MinorGridAlpha = S.AxesGridAlpha/2;
            else
                obj.hAxes.Layer = 'bottom';
                src.Tooltip = 'Show Grid';
                obj.hAxes.GridAlpha = 0;
                obj.hAxes.MinorGridAlpha = 0;
            end
            
            if isa(src, 'struct')
                
                btnH = findobj(obj.hFigure, 'Tag', 'Show Grid');
                if ~isempty(btnH)
                    btnH.String = src.String;
                end
            end
                
        end
        
        
        function showMinorGrid(obj, src, ~)
            % Todo...

            switch src.Text
                case 'Show Fine Grid'
                    src.Text = 'Hide Fine Grid';
                    obj.hAxes.XMinorGrid = 'on';
                    obj.hAxes.YMinorGrid = 'on';
                
                case 'Hide Fine Grid'
                    src.Text = 'Show Fine Grid';
                    obj.hAxes.XMinorGrid = 'off';
                    obj.hAxes.YMinorGrid = 'off';
            end
            
            
        end
        
        
        function showInfoCursor(obj, src, ~)
            
            if isempty(obj.hFigure.WindowButtonMotionFcn)
                obj.showGraphicalHandle(obj.hInfoBox)
                obj.showGraphicalHandle(obj.hCurrentPoint)
            else
                obj.hideGraphicalHandle(obj.hInfoBox)
                obj.hideGraphicalHandle(obj.hCurrentPoint)
            end
        end
        
        function showMapLabels(obj, src, ~)
            
            switch src.Text
                case 'Show Map Labels'
                    if isempty(obj.hMapLabels)
                        obj.msgBox.displayMessage('Just a second...')

                        leftOrRight = obj.settings.hemisphereToLabel();            
                        obj.hMapLabels = fovmanager.utility.atlas.showBrainMapLabels(obj.hAxes, leftOrRight);
                        
                        obj.msgBox.clearMessage()

                    else
                        set(obj.hMapLabels, 'Visible', 'on')
                    end
                    src.Text = 'Hide Map Labels';
                    
                case 'Hide Map Labels'
                    set(obj.hMapLabels, 'Visible', 'off')
                    src.Text = 'Show Map Labels';
            end
            
        end
        
        
% % % % Plot methods
        
        function makeBackgroundOpaque(obj)
                        
            obj.resetBackground()
            
            if ~obj.settings.opaqueBackground; return; end
            
            mInd = obj.getCurrentMouseSelection(); %NB: First element of lb is none
            if mInd == 0; return; end
            
            
            if ~isempty(obj.fovDatabase(mInd).Windows)
                winH = findobj(obj.fovDatabase(mInd).Windows(:).guiHandle, 'Tag', 'Window Outline');
                obj.hBg = obj.makeMapOpaque(obj.hAxes, winH);
            end
            
        end
        

        function resetBackground(obj)
            if ~isempty(obj.hBg) && isvalid(obj.hBg)
                delete(obj.hBg)
            end
        end
        
        
    end
    
    
    
    methods (Static)
        
        function checkDependencies(obj)
            
            try
                uimVersion = uim.version();
            catch
                uimVersion = 0;
            end
            
%             if uimVersion < 738130
%                 errordlg('Functions-Library (branch, eivind-mess-in-progress) is not up to date.')
%                 error('vlab:fovmanager:oldversion', 'Functions-Library has updates which are required')
%             end
            
        end
        
        function tf = isOpen()
            openFigures = findall(0, 'Type', 'Figure');
            if isempty(openFigures)
                tf = false;
            else
                figMatch = strcmp({openFigures.Name}, 'FOV Manager');
                if any(figMatch)
                    figure(openFigures(figMatch))
                    tf = true;
                else
                    tf = false;
                end
            end
        end
        
        function pathStr = getIconPath()
            % Set system dependent absolute path for icons.
%             rootDir = utility.path.getAncestorDir(mfilename('fullpath'), 2);
%             pathStr = fullfile(rootDir, 'resources', 'icons');
            
            pathStr = fovmanager.localpath('toolbar_icons');
            
        end
        
        function S = getSettings()
            
            path = mfilename('fullpath');
            settingsPath = strcat(path, '_settings.mat');

            if exist(settingsPath, 'file') % Load settings from file
                S = load(settingsPath, 'settings');
                S = S.settings;
            else
                S = struct.empty;
            end
            
        end
        
        function S = getAppearance(appearanceName)
            
            if nargin < 1
                appearanceName = getpref('fovmanager', 'appearance');
            end
            
            lightMode = struct();
            lightMode.FigureBackgroundColor = ones(1,3)*0.94;
            lightMode.AxesBackgroundColor = [1, 1, 1];
            lightMode.AxesForegroundColor = ones(1,3) .* 0.15;
            lightMode.AxesGridAlpha = 0.15;
            lightMode.MapAlpha = 1;
            lightMode.ToolbarAlpha = 0.7;
            lightMode.ToolbarDarkMode = 'off';
            lightMode.SliderTextColor = ones(1,3) .* 0.15;
            
            darkMode = struct();
            darkMode.FigureBackgroundColor = ones(1,3)*0.12;
            darkMode.AxesBackgroundColor = ones(1,3) .* 0.15;
            darkMode.AxesForegroundColor = ones(1,3) .* 0.85;
            darkMode.AxesGridAlpha = 0.5;
            darkMode.MapAlpha = 0.8;
            darkMode.ToolbarAlpha = 0.2; 
            darkMode.ToolbarDarkMode = 'on';
            
            
            switch lower(appearanceName)
                case 'light'
                    S = lightMode;

                case 'dark'
                    S = darkMode;

            end
            
        end

        
        function setDefaultDatabase(pathStr)
            
            path = mfilename('fullpath');
            settingsPath = strcat(path, '_settings.mat');
                        
            S = load(settingsPath, 'settings');
            S.settings.defaultFilePath = pathStr;
            
            save(settingsPath, '-struct', 'S')
        end
        
        
        % % % Methods to get things out of the default database
        
        function Db = getDefaultDatabase()
            S = fovmanager.getSettings();
            if ~isempty(S)
                if ~isempty(S.defaultFilePath) && exist(S.defaultFilePath, 'file')
                    S2 = load(S.defaultFilePath);
                    Db = S2.fovDb;
                end
            end
        end
        
        
        function Db = getDatabase(dbPath)
            S2 = load(dbPath);
            Db = S2.fovDb;
        end
        
        
        function fovArray = findFovFromSession(sessionIDs, database)

            fovArray = [];
%            fovArray = fovmanager.mapobject.FoV.empty(numel(sessionIDs), 0);
            % Load settings file and get default fov database
            if nargin < 2 || isempty(database)
                database = fovmanager.getDefaultDatabase;
            end
            
            if isa(database, 'struct'); database = {database}; end
            if isa(sessionIDs, 'char'); sessionIDs = {sessionIDs}; end %ad hoc to accept char and cell array of sessionIDs
                        
            for iSession = 1:numel(sessionIDs)
            
                sessionID = sessionIDs{iSession};
                
                for iDb = 1:numel(database)
                    fovDb = database{iDb};

                    currentMId = sessionID(2:5);

                    miceIDs = cellfun(@(s) sprintf('%04d', str2double(s)), {fovDb.MouseId}, 'uni', 0);
                    mInd = contains(miceIDs, currentMId);

                    if sum(mInd)==0; continue; end
                    
                    wInd = 1; % Assume there is only one window (NB!)

                    fInd = [];
                    for iFov = 1:numel(fovDb(mInd).Windows(wInd).fovArray)
                        sList = fovDb(mInd).Windows(wInd).fovArray(iFov).listOfSessions;
                        if isempty(sList)
                            continue
                        else
                            tf = any(contains({sList.sessionID}, sessionID));
                            if tf
                                fInd = iFov;
                                break
                            end
                        end
                    end

                    if ~isempty(fInd)
                        % Find mouse and fov from sessionID
                        thisFov = fovDb(mInd).Windows(wInd).fovArray(fInd);
                       %fovArray(iSession) = thisFov;
                        fovArray = cat(2, fovArray, thisFov);
%                         break % if we got this far
                    end

                end
                
            end
            
        end
        
        
        function mapCoords = getRoiMapCoordinates(sessionID, fovDb)

            thisFov = fovmanager.findFovFromSession(sessionID(1:end-4), fovDb);
            
            % Turn into object
            if ~isa(thisFov, 'fovmanager.mapobject.FoV')
                thisFov = FoV(thisFov);
            end
            
            % Call FoVs getRoiPosition method
            mapCoords = thisFov.getRoiMapCoordinates([], sessionID);
            
        end
        
        
        function fovCenter = getFovCenter(sessionID)
            
            sessionID = validateSessionID(sessionID, 'any');
            numSessions = numel(sessionID);
            
            fovCenter = nan(numSessions, 2);
            
            thisFov = fovmanager.findFovFromSession(sessionID);
            if isempty(thisFov); return; end
            
            fovCenter = cat(1, thisFov.center);
            
        end
        
        
        function fovLabel = getFovLabel(sessionID)
            
            % Todo: Merge this with another function.
            
            sessionID = validateSessionID(sessionID, 'any');
            numSessions = numel(sessionID);
            
            fovLabel = cell(numSessions, 1);

            allFovs = fovmanager.findFovFromSession(sessionID);
            if isempty(allFovs); return; end
            
            
            tmpFig = brainmap.paxinos.open('invisible');

            h = findobj(tmpFig, 'Type', 'Polygon');
            h(31) = [];
            
            ax = findobj(tmpFig, 'type', 'Axes');
            xMin = ax.XLim(1);
            yMin = ax.YLim(1);
            xRange = range(ax.XLim);
            yRange = range(ax.YLim);
            m = 100;

            
            for iSession = 1:numSessions
            
                thisFov = allFovs(iSession);
                
                % Make masks to find overlap
                fovX = (thisFov.edge(:,1) - xMin) .* 100;
                fovY = (thisFov.edge(:,2) - yMin) .* 100;
                fovMask = poly2mask(fovX, fovY, yRange*m, xRange*m);
                fovArea = bwarea(fovMask);

                overlap = zeros(numel(h), 1);

                for i = 1:numel(h)
                    % Find center of mass for placement of text.
                   edge = h(i).Shape.Vertices;
                   x = (edge(:,1) - xMin)*m;
                   y = (edge(:,2) - yMin)*m;

                   x(isnan(x))=[];
                   y(isnan(y))=[];

                   BW = poly2mask(x, y, yRange*m, xRange*m);

                   overlap(i) = bwarea(BW & fovMask) / fovArea;

                end

                [sorted, sInds] = sort(overlap, 'descend');

                keep = sorted > 0.1;

                sInds = sInds(keep);
                if numel(sInds) > 2; sInds = sInds(1:2); end

                areaLabels = {h(sInds).Tag};
                areaLabels = areaLabels(~isempty(areaLabels));

                thisFovLabel = strjoin(areaLabels, ' - ');
                thisFovLabel = sprintf('%s (AP: %.2fmm, ML: %.2fmm)', thisFovLabel, thisFov.center(2), thisFov.center(1));
    %             if ~isempty(thisFov.depth)
    %                 fovLabel = strrep(fovLabel, ')', sprintf(', Depth: %d um)', round(thisFov.depth)) );
    %             end
    
                fovLabel{iSession} = thisFovLabel;
            end
            
            if numSessions == 1
                fovLabel = fovLabel{1};
            end
        end
        
        
        function thisWindow = getWindow(sessionID, varargin)
            
            param = struct('dbPath', 'default');
            param = parsenvpairs(param, [], varargin);
            
            if strcmp(param.dbPath, 'default')
                fovDb = fovmanager.getDefaultDatabase;
            else
                fovDb = fovmanager.getDatabase(param.dbPath);
            end
            
            currentMId = sessionID(2:5);
            
            miceIDs = cellfun(@(s) sprintf('%04d', str2double(s)), {fovDb.MouseId}, 'uni', 0);
            mInd = contains(miceIDs, currentMId);
            
            % Load settings file and get default fov database
            wInd = 1; % Assume there is only one window (NB!)
            thisWindow = fovDb(mInd).Windows(wInd);
            
        end
        
        
        function windowCoords = getWindowCoords(sessionID)
            thisWindow = fovmanager.getWindow(sessionID);
            windowCoords = thisWindow.edge;
        end
        
        
        function showHelp()
            
            S = fovmanager.App.getAppearance();
            
            % Create a figure for showing help text
            helpfig = figure('Position', [100,200,500,500], 'Visible', 'off');
            helpfig.Resize = 'off';
            helpfig.Color = S.FigureBackgroundColor;
            helpfig.MenuBar = 'none';
            helpfig.NumberTitle = 'off';
            helpfig.Name = 'Help for fovmanager';
            
            % Create an axes to plot text in
            ax = axes('Parent', helpfig, 'Position', [0,0,1,1]);
            ax.Visible = 'off';
            hold on

            % Specify messages. \b is custom formatting for bold text
            messages = {...
                'Click >here< to go to fovmanager Wiki (under construction)\n', ...
                ...
                '\bGet Started', ...
                [char(1161), '   Add new mice using the "+" button in the upper right corner'], ...
                [char(1161), '   Add new cranial windows or injections spots by right clicking the map'], ...
                [char(1161), '   Add FoVs by right clicking an existing window'], ...
                [char(1161), '   Right click objects for additional options'], ...
                ...
                '\n\bKey Shortcuts' ...
                's : Save a snapshot of the brainmap to\n "..fovmanager/screendump"', ...
                ['\nThe following keys work if an object is selected \n', ...
                 'and the position of that object is unlocked\n'], ...
                 'arrowkeys : Move an object in 0.01 mm (10 um) steps', ...
                 'shift + arrowkeys : Move an object in 0.1 mm (100 um) steps', ...
                 'r / shift-r : Rotate an object 90 degrees CW / CCW', ...
                 'ctrl-r / ctrl-shift-r : Rotate an object 1 degree CW / CCW', ...
                 'v : Flip image vertically', ...
                 'h : Flip image horizontally', ...
                 'x : Toggle (on/off) coordinate cursor point'};


            % Plot messages from bottom top. split messages by colon and
            % put in different xpositions.
            hTxt = gobjects(0, 1);
            y = 0.1;
            x1 = 0.05;
            x2 = 0.3;
            
            for i = numel(messages):-1:1
                nLines = numel(strfind(messages{i}, '\n'));
                y = y + nLines*0.03;
                
                makeBold = contains(messages{i}, '\b');
                messages{i} = strrep(messages{i}, '\b', ''); 
                
                if contains(messages{i}, ':')
                    msgSplit = strsplit(messages{i}, ':');
                    hTxt(end+1) = text(x1, y, sprintf(msgSplit{1}));
                    hTxt(end+1) = text(x2, y, sprintf([': ', msgSplit{2}]));
                else
                    hTxt(end+1) = text(0.05, y, sprintf(messages{i}));
                end
                
                if makeBold; hTxt(end).FontWeight = 'bold'; end
                
                y = y + 0.05;
            end

            set(hTxt, 'FontSize', 14, 'Color', S.AxesForegroundColor, 'VerticalAlignment', 'top')
            
            
            hTxt(end).ButtonDownFcn = @(s,e) fovmanager.App.openWiki;
         
            % Adjust size of figure to wrap around text.
            % txtUnits = get(hTxt(1), 'Units');
            set(hTxt, 'Units', 'pixel')
            extent = cell2mat(get(hTxt, 'Extent'));
            % set(hTxt, 'Units', txtUnits)
            
            maxWidth = max(sum(extent(:, [1,3]),2));
            helpfig.Position(3) = maxWidth./0.9; %helpfig.Position(3)*0.1 + maxWidth;
            helpfig.Position(4) = helpfig.Position(4) - (1-y)*helpfig.Position(4);
            helpfig.Visible = 'on';
            
            % Close help window if it loses focus
            jframe = getjframe(helpfig);
            set(jframe, 'WindowDeactivatedCallback', @(s, e) delete(helpfig))

        end
        
        
        function openWiki()
            web('https://github.uio.no/VervaekeLab/fovmanager/wiki', '-browser')
        end
        
        
        
        % Methods to plot the brain map and 
        
        
        function [fig, ax] = showMap(varargin)
        %fovmanager.App.showMap Plot the paxinos dorsal surface map
        %
        %   fovmanager.showMap() open a new figure with the dorsal brain
        %   surface map.
        %
        %   fovmanager.showMap(ax) creates the map in the in the axes 
        %   specified by ax
        %
        %   fovmanager.showMap(ax, Name, Value, ...) creates the map with
        %   additional name value pair arguments:
        %
        %   Name, Value pair arguments:
        %       
        %       'Grayscale'  (logical)    : Show map in grayscale or color
        %       'ShowLabels' (logical)    : Show region text labels on the map
        %       'LabelHemisphere' (char)  : 'left' | 'right' Hemisphere to label
        
            def = struct(...
                'Grayscale', false, ...
                'ShowLabels', false, ...
                'LabelHemisphere', 'right' );
            
            % Open the figure with the brain map
            fig = brainmap.paxinos.open('Invisible');
            ax = findobj(fig, 'Type', 'axes');
            
            % Check if axes is given as input and make figure and axes if not.
            if ~isempty(varargin) && isa(varargin{1}, 'matlab.graphics.axis.Axes')
                axIn = varargin{1};
                
                % Copy the map regions to the input axes.
                for i = 1:numel(ax.Children)
                    copyobj(ax.Children(i), axIn)
                end
                
                % Configure axis.
                axis(axIn, 'equal')
                axIn.XLim = ax.XLim;
                axIn.YLim = ax.YLim;
                
                close(fig)
                
                ax = axIn;
                varargin = varargin(2:end);

            else
                fig.Color = [1,1,1];
                ax.Position(1) = 0.115;
                fig.Visible = 'on';
            end
            
            % Get parameters given as input
            opt = parsenvpairs(def, [], varargin);

            ax.GridAlpha = 0.15;
            ax.Layer = 'top';
            

            % Make black and white
            if opt.Grayscale
                hPoly = findobj(ax, 'Type', 'Polygon');
                for i = 1:numel(hPoly)
                    newC = repmat(mean(hPoly(i).FaceColor), 1, 3)*1.2;
                    newC(newC<0) = 0;
                    newC(newC>1) = 1;
                    hPoly(i).FaceColor = newC;
                end
            end

            
            % Add labels for regions
            if opt.ShowLabels
                fovmanager.utility.atlas.showBrainMapLabels(ax, opt.LabelHemisphere);
            end
            
            
            if ~nargout
                clear fig ax
            end
            
        end
        
        
        function hWin = plotWindow(ax, sessionID, varargin)
        
            def = struct('MakeMapOpaque', false, 'Opaqueness', 0, 'ShowImage', false);
            opt = parsenvpairs(def, [], varargin);
            
            
            % Plot window
            thisWindow = fovmanager.getWindow(sessionID);
            
            hold(ax, 'on')
            hWin = fovmanager.mapobject.CranialWindow(ax, thisWindow);
            hWin.setWindowAlpha(0)
            
            if opt.ShowImage
                hWin.showImage()
            end
            
            h = findobj(hWin.guiHandle, 'type', 'patch');
            h.LineWidth = 1;
            
%             if opt.MakeMapOpaque
%                 hBg = fovmanager.makeMapOpaque(ax, h);
%                 set(hBg, 'FaceAlpha', opt.Opaqueness)
%             end
            
        end
        
        
        function h = plotFov(ax, sessionID, varargin)
        
            
            def = struct('FovShape', 'square');
            opt = parsenvpairs(def, [], varargin);
            
            
            % Plot window
            if isa(sessionID, 'char')
                sessionID = {sessionID};
            end
            
            assert(isa(sessionID, 'cell'), 'Invalid 2nd argument. Should be a sessionID or a cell array of sessionIDs')
            
            numSessions = numel(sessionID);
            
            h = gobjects(numSessions, 1);
            
            for i = 1:numSessions
                
                thisFov = fovmanager.findFovFromSession(sessionID{i}(1:end-4)); % Todo: might exclude last part of sessionID

                xCoords = thisFov.edge(:, 1); 
                yCoords = thisFov.edge(:, 2);
                
                if strcmp( opt.FovShape, 'circle' )
                    rho = mean([range(xCoords), range(yCoords) ]) ./ 2;
                    theta = deg2rad(1:360);
                    rho = ones(size(theta)) * rho;
                    [xCoords, yCoords] = pol2cart(theta, rho);
                    xCoords = xCoords + thisFov.center(1);
                    yCoords = yCoords + thisFov.center(2);
                end
            
                hold(ax, 'on')
                h(i) = patch(ax, xCoords, yCoords, ones(1,3)*0.5);

            end
            
            set(h, 'FaceAlpha', 0.7, 'EdgeColor', ones(1,3)*0.3, ...
                   'LineWidth', 1 )
            
        end
        
        
        function hBg = makeMapOpaque(ax, winH, varargin)
            
            origXLim = ax.XLim;
            origYLim = ax.YLim;
            
            ax.XLim = origXLim + range(origXLim) .* [-0.1, 0.1];
            ax.YLim = origYLim + range(origYLim) .* [-0.1, 0.1];

            imageVertices = [ax.XLim([1,1,2,2]); ax.YLim([2,1,1,2])];
            imageVertices = imageVertices';
            
            pgon = polyshape(imageVertices(:,1), imageVertices(:,2));
            
            warning('off', 'MATLAB:polyshape:repairedBySimplify')

            winCoordinates = arrayfun(@(w) [w.XData, w.YData], winH, 'uni', 0);

            for i = 1:numel(winCoordinates)
                winshape = polyshape(winCoordinates{i}(:,1), winCoordinates{i}(:,2));
                pgon = subtract(pgon, winshape);
            end
            
            hBg = plot(ax, pgon, 'FaceColor', 'w', 'FaceAlpha', 0.4, 'EdgeColor', 'none');

            warning('on', 'MATLAB:polyshape:repairedBySimplify')
        
            ax.XLim = origXLim;
            ax.YLim = origYLim;
            
            ax.XLim = origXLim + range(origXLim) .* [-0.01, 0.01];
            ax.YLim = origYLim + range(origYLim) .* [-0.01, 0.01];
            
        end
        
    end
    
    methods (Static)
        S = getDefaultSettings()
    end
    
end