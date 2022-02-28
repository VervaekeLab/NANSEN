classdef ModularApp < uim.handle & applify.HasTheme & matlab.mixin.Heterogeneous
%ModularApp An abstract base class for modular apps
%
%   ModularApp() creates the app in a new figure
%
%   ModularApp(hPanel) creates the app in a panel.   
%
%
%   Main functionality:
%
%     - Creates an app which can be placed in a separate figure window or
%       in a panel within a figure. 
%     - Maximize / restore app
%     - Assigns window (mouse/keyboard) callbacks for figures and handle
%       their interaction if multiple modular apps are docked in one figure.
%
%   ABSTRACT PROPERTIES:
%       AppName (Constant)
%
%   ABSTRACT METHODS (protected): Todo: not abstract
%       pos = initializeFigurePosition(app)
%       resizePanel(app, src, evt)



% Questions..


% - - - - - - - - - - TODO LIST - - - - - - - - - - - - - - - - - - - - -
%
% * [ ] Fix units of panel! In standalone mode, units are pixels...
%       What if figure is resized???
%
%   [ ] Methods for mouse leaving or entering app. 
%           - onMouseEnteredApp 
%           - onMouseExitedApp
%
%   [ ] Sort out units of the Panel property. Right now they are pixels
%       based if mode is standalone and normalized if mode is docked. Is
%       this a good idea? Should they instead always be one or the other?
%
%   [ ] Make method for docking/undocking app
%
%   [ ] Make sure mouse/key callbacks from different modules does not
%       interfere with each other.
%
%   [ ] Create panel toolbar (header toolbar with options like
%       maximize, help, settings etc)
%
%   [ ] Add method for finishing up construction. I.e customizeFigure
%       and possibly others that are called in onConstructed.
%
%   [ ] Need to fix the way mouse callbacks are assigned (listeners vs
%       assigning to property values of figure) for standalone figures.
%       Imviewer and structeditor needs these to be set in different
%       ways...


% - - - - - - - - - - PROPERTIES - - - - - - - - - - - - - - - - - - - - -
    
    properties (Constant, Hidden = true) % move to appwindow superclass
        MAC_MENUBAR_HEIGHT = 25; % Todo: Is this always constant???
    end
    
    properties (Abstract, Constant)
        AppName
    end
    
    properties (Hidden) % Layout properties % Abstract?
        %Margins = [0, 0, 0, 0] % Margins (left, bottom, right, top) in pixels
    end
    
    properties 
        Figure matlab.ui.Figure     % Should this be public? 
        Widgets                     % Should this be public? 
        % Visible
    end
    
    properties (Access = protected)
        Parent % Parent handle of apps panel (can be a figure, panel, tab etc)
        Panel matlab.ui.container.Panel
        
        FigureInteractionListeners
        %Widgets
    end
    
    properties (SetAccess = private, Hidden)
        % Todo: Whys is this not a boolean flag? Can add more modes later?
        mode = 'standalone'; % standalone or docked
    end
    
    properties (Access = protected)
        isMatlabPre2018b % This should not be a property!
        isConstructed = false
    end
    
    properties (Access = protected) % Todo: Move to pointermanager. Make pointermanager a property of this class.
        isMouseDown             
        PreviousMouseClickPoint   % Point where mouse was last clicked
        PreviousMousePoint
    end
    
    
% - - - - - - - - - - METHODS - - - - - - - - - - - - - - - - - - - - -

    methods (Access = protected)
                
        % use for when restoring figure size from maximized
        function pos = initializeFigurePosition(~)
            screenCoords = get(0, 'ScreenSize');
            figureSize = [560, 420];
            figureLocation = screenCoords(1:2) + (figureSize - screenCoords(3:4)) / 2;
            
            pos = [figureLocation, figureSize];
        end
           
        function resizePanel(app, src, evt)
            % Subclass may implement
        end
        
    end
    
    methods
    
        function reparent(app, parentHandle, newMode)
                        
            if nargin < 3; mode = 'standalone'; end
    
            app.mode = newMode;

        end
        
        
    end
    
    methods
        
        function app = ModularApp(hPanel)
            
            if nargin == 0
                app.mode = 'standalone';
            elseif app.isValidPanel(hPanel)
                app.mode = 'docked';
            else
                app.mode = 'standalone';
            end
            
            
            % Initialize figure and panel properties based on mode
            switch app.mode
                case 'docked'
                    app.Figure = ancestor(hPanel, 'figure');
                    app.createAppPanel(hPanel)
                case 'standalone'
                    app.createAppWindow()
                    app.createAppPanel(app.Figure)

            end
            
            % Why not set this in createAppPanel?
            app.Panel.SizeChangedFcn = @app.resizePanel;

            
            % Check version of matlab.
            app.matlabVersionCheck()
            
        end
        
        
    end
    
    methods %Set/Get
        function set.isConstructed(obj, newValue)
           
            assert(islogical(newValue), 'isConstructed must be logical')
            
            obj.isConstructed = newValue;
            obj.onConstructed()
            
        end
    end
    
    methods 
        function tf = isMouseInApp(app)
        
            tf = false;
            
            if ~app.Parent.Visible
                %return
            end
            
            if strcmp( app.Parent.Visible, 'off' )
                return
            end
            
            if strcmp( app.Panel.Visible, 'off' )
                return
            end
            
            if ~isvalid(app.Panel)
                return
            end
            
            xy = app.Figure.CurrentPoint;
            panelPos = getpixelposition(app.Panel, true);

            panelLim = uim.utility.pos2lim(panelPos);

            tf = ~any(any(diff([panelLim(1:2); xy; panelLim(3:4)]) < 0));

        end
        
        function tf = isStandalone(app)
            tf = strcmp(app.mode, 'standalone');
        end
    end
    
    methods (Access = protected)
        
        function matlabVersionCheck(app)

            VERSION_REFERENCE = [9, 5, 0];

            matlabVersion = version();
            versionSplit = strsplit(matlabVersion, '.');
            versionVector = cellfun(@(c) str2double(c), versionSplit(1:3));
            
            if all( versionVector >= VERSION_REFERENCE) 
                app.isMatlabPre2018b = false;
            else
                app.isMatlabPre2018b = true;
            end 
        end % Todo: system function....
        
        function assignPanelFromArgin(app, hPanel)
            app.Panel = hPanel;
            app.Figure = ancestor(app.Panel, 'figure');
        end
        
        function createAppWindow(app)
            % Create the figure window
            hFig = figure('Visible', 'off');
            app.Figure = hFig;
            
            app.Figure.Name = app.AppName;
            app.Figure.NumberTitle = 'off';
            app.Figure.MenuBar = 'none';
            app.Figure.ToolBar = 'none';
            
            set(app.Figure, 'DefaultAxesCreateFcn', @app.onAxesCreated)

        end
        
        function onAxesCreated(app, src, evt)
            % TODO: Does this actually make a difference...
            persistent removeAxToolbar
            if isempty(removeAxToolbar)
                matlabVersion = version();
                versionSplit = strsplit(matlabVersion, '.');
                versionVector = cellfun(@(c) str2double(c), versionSplit(1:3));
                removeAxToolbar = all( versionVector >= [9,5,0] );
            end
            
            if removeAxToolbar
                disableDefaultInteractivity(src)
                src.Interactions = [];
                src.Toolbar = [];
            end
            
        end
        
        function createAppPanel(app, target)
            
            if nargin < 2
                target = app.Figure;
            end
            
            app.Parent = target;
            
            % Create a panel in the figure
            app.Panel = uipanel(target, 'Visible', 'off');
            app.Panel.BorderType = 'none';
            app.Panel.Position = [0,0,1,1];
            app.Panel.Tag = 'App Content Panel';

            if strcmp(app.mode, 'standalone') 
                app.Panel.Units = 'pixel'; % todo....
            end
            
            %set(app.Panel, 'DefaultAxesCreateFcn', @app.onAxesCreated)
            %app.Panel.BackgroundColor = app.Figure.Color;

        end
        
        function toggleResize(app, src, ~)

            switch src.Tooltip

                case 'Maximize Window'

                    switch app.mode
                        case 'standalone'
                            app.resizeWindow(src, [], 'maximize')
                        case 'docked'
                            app.resizePanel(app.hPanel, false, 'maximize')
                    end

                    src.Icon = app.ICONS.minimize;
                    src.Tooltip = 'Restore Window';
                    %app.hFigure.Resize = 'on';
                case 'Restore Window'

                    switch app.mode
                        case 'standalone'
                            app.resizeWindow(src, [], 'restore')
                        case 'docked'
                            app.resizePanel(app.hPanel, false, 'restore')

                    end

                    src.Icon = app.ICONS.maximize;
                    src.Tooltip = 'Maximize Window';
                    %app.hFigure.Resize = 'off';
            end

        end

        function maximizeWindow(app, src, evt)

            MP = get(0, 'MonitorPosition');
            xPos = app.hFigure.Position(1);
            yPos = app.hFigure.Position(2);

            % Get screenSize for monitor where figure is located.
            for i = 1:size(MP, 1)
                if xPos > MP(i, 1) && xPos < sum(MP(i, [1,3]))
                    if yPos > MP(i, 2) && yPos < sum(MP(i, [2,4]))
                        screenSize = MP(i,:);
                        break
                    end
                end
            end

            set(app.hFigure, 'Resize', 'on')

            jFrame = get(app.hFigure, 'JavaFrame');
    %         jWindow = jFrame.getFigurePanelContainer.getTopLevelAncestor;
    %         jWindow.setFullScreen(false)

            newFigurePos = screenSize;
            app.hPanel.SizeChangedFcn = [];

            app.hPanel.Units = 'pixel';
            app.hFigure.Position = newFigurePos;

            newPanelPos = app.hFigure.InnerPosition + [10, 10, -20, -20];


            app.hPanel.Position = newPanelPos;
            app.hPanel.Units = 'normalized';
            app.hPanel.BorderType = 'etchedin';
            app.hPanel.HighlightColor = [0.1569    0.1569    0.1569]; 

            app.uiaxes.imdisplay.Position = [1,1,newPanelPos(3:4)-2];

            app.uiaxes.textdisplay.Visible = 'off';
        end

    end
    
    
    methods (Access = protected) % Configurations (Subclasses may override)
        
        function setDefaultFigureCallbacks(obj, hFig)

            if nargin < 2 || isempty(hFig)
                hFig = obj.Figure;
            end
            
            if strcmp(obj.mode, 'docked'); return; end

            if strcmp(obj.mode, 'standalone')
                % Need to set these instead of listeners to prevent each
                % keypress to go back to the matlab command line

                hFig.WindowKeyPressFcn = @obj.onKeyPressed;
                hFig.WindowKeyReleaseFcn = @obj.onKeyReleased;
                
                % Todo: Resolve whether to use listeners or callback for
                % mouse actions. Does not work in imviewer with the current
                % pointertool setup to use figure callback properties..
                
                obj.FigureInteractionListeners.WindowMousePress = addlistener(...
                    hFig, 'WindowMousePress', @obj.onMousePressed);

                obj.FigureInteractionListeners.WindowMouseMotion = addlistener(...
                    hFig, 'WindowMouseMotion', @obj.onMouseMotion);

                obj.FigureInteractionListeners.WindowMouseRelease = addlistener(...
                    hFig, 'WindowMouseRelease', @obj.onMouseReleased);

                obj.FigureInteractionListeners.WindowScrollWheel = addlistener(...
                    hFig, 'WindowScrollWheel', @obj.onMouseScrolled);
                
                %hFig.WindowScrollWheelFcn = @obj.onMouseScrolled;
                %hFig.WindowButtonDownFcn = @obj.onMousePressed;
                %hFig.WindowButtonMotionFcn = @obj.onMouseMotion;
                %hFig.WindowButtonUpFcn = @obj.onMouseReleased;
                
            elseif strcmp(obj.mode, 'docked')
                
                % Todo: Probably can remove, but need to test more properly
                
                % Not this is done differently, by having the dashboard
                % that these modules are placed in invoke the interactive
                % callback functions if the pointer is over the module...
                
                % Use listeners so that this module does not occupy the
                % WindowKeyPressFcn & WindowKeyReleaseFcn properties.

                obj.FigureInteractionListeners.WindowButtonDown = addlistener(...
                    hFig, 'KeyPress', @obj.onKeyPressed);

                obj.FigureInteractionListeners.WindowButtonDown = addlistener(...
                    hFig, 'KeyRelease', @obj.onKeyReleased);
                
                obj.FigureInteractionListeners.WindowMousePress = addlistener(...
                    hFig, 'WindowMousePress', @obj.onMousePressed);

                obj.FigureInteractionListeners.WindowMouseMotion = addlistener(...
                    hFig, 'WindowMouseMotion', @obj.onMouseMotion);

                obj.FigureInteractionListeners.WindowMouseRelease = addlistener(...
                    hFig, 'WindowMouseRelease', @obj.onMouseReleased);

                obj.FigureInteractionListeners.WindowScrollWheel = addlistener(...
                    hFig, 'WindowScrollWheel', @obj.onMouseScrolled);
                
            end

        end
        
    end
    
    methods (Access = protected) % Internal Callbacks
        
        function onConstructed(obj)
            
            obj.setDefaultFigureCallbacks()
            obj.onThemeChanged()

            if strcmp(obj.mode, 'standalone')
                obj.Figure.Visible = 'on';
            end
            
            obj.Panel.Visible = 'on';

        end
        
        function onThemeChanged(obj)
            
            S = obj.Theme;
            if ~obj.isConstructed; return; end
            
            %obj.setFigureWindowBackgroundColor(S.FigureBgColor)

            if strcmp(obj.mode, 'standalone')
                obj.Figure.Color = S.FigureBgColor;
            end
            
            obj.Panel.BackgroundColor = S.FigureBgColor;
            
        end
        
    end
    
    methods (Access = {?applify.ModularApp, ?applify.DashBoard} ) % Event / interactive Callbacks

        function onKeyPressed(obj, src, evt)
            % Subclass can implement this
        end
        
        function onKeyReleased(obj, src, evt)
            % Subclass can implement this
        end
        
        function onMousePressed(obj, src, evt)
            % Subclass can implement this
        end
        
        function onMouseReleased(obj, src, evt)
            % Subclass can implement this
        end
        
        function onMouseMotion(obj, src, evt)
            % Subclass can implement this
        end
        
        function onMouseScrolled(obj, src, evt)
            % Subclass can implement this
        end
        
    end
    
    methods (Static)
    
        function [screenSize, screenNum] = getCurrentMonitorSize(hFigure)
        % Todo: Method of nansen.app superclass

            persistent titleBarHeight
            if isempty(titleBarHeight)
                if nargin < 1
                    f = figure('Menubar', 'none', 'Visible', 'off');
                    titleBarHeight = f.OuterPosition(4) - f.Position(4);
                    close(f)
                else
                    titleBarHeight = hFigure.OuterPosition(4) - hFigure.Position(4);
                end
            end

            if nargin < 1
                screenSize = get(0, 'ScreenSize');

            else

                figurePosition = hFigure.Position;

                MP = get(0, 'MonitorPosition');
                xPos = figurePosition(1);
                yPos = figurePosition(2) + figurePosition(4);

                % Get screenSize for monitor where figure is located.
                for i = 1:size(MP, 1)
                    if xPos >= MP(i, 1) && xPos <= sum(MP(i, [1,3]))
                        if yPos >= MP(i, 2) && yPos <= sum(MP(i, [2,4]))
                            screenSize = MP(i,:);
                            break
                        end
                    end
                end
            end

            if ismac
                menubarHeight = applify.ModularApp.MAC_MENUBAR_HEIGHT;
            elseif ispc
                menubarHeight = 0;
            end
            
            % Todo: For menubar offset, i.e on window when menubar is on
            % bottom..
            screenSize(4) = screenSize(4) - menubarHeight;


            screenSize(4) = screenSize(4) - titleBarHeight;

            if nargout == 2
                screenNum = i;
            end

        end

        function figPos = assertWindowOnScreen(figPos, screenPos)
        
            % Make sure figure is not above available screen space
            if sum(figPos([1,3])) > sum(screenPos([1,3]))
                figPos(1) = sum(screenPos([1,3])) - figPos(3);
            end

            if sum(figPos([2,4])) > sum(screenPos([2,4]))
                figPos(2) = screenPos(2) + (screenPos(4) - figPos(4))/2;
            end

            % Make sure figure is not above available screen space
            figPos(1:2) = max( [screenPos(1:2); figPos(1:2)] );            

        end

        function [h, varargin] = splitArgs(varargin)
        %splitArgs Pop possible panel arg from varargin
        
            h = []; 
            
            if isempty(varargin)
                return
            end
            
            % Check if first arg is a panel and assign to h if yes.
            if isa(varargin{1}, 'matlab.ui.container.Panel')
                h = varargin{1};
                varargin(1) = [];
            end
            
        end
        
        function tf = isValidPanel(hPanel)
                 
            tf = false; % Need to prove it is valid
            
            % Change our mind only if a valid panel is given.
            if isa(hPanel, 'matlab.ui.container.Panel')
                
                if numel(hPanel) == 1 && isvalid(hPanel)
                    tf = true;
                end

            end
            
        end
    end
    
    
end