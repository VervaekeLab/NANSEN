classdef ConfigurationApp < handle & uiw.mixin.AssignPVPairs
%ConfigurationApp App for user configurations
%
%   Super class for configuration apps in the nansen package

    
    properties (Constant, Hidden)
        DEFAULT_THEME = nansen.theme.getThemeColors('light');
    end
    
    properties (Constant, Abstract)
        AppName
    end
    
    properties
        UIModule cell
        ControllerApp % Another app that can control whether this app is visible or not.
    end
    
    properties (Dependent)
        Visible matlab.lang.OnOffSwitchState
        AllowResize matlab.lang.OnOffSwitchState
    end
    
    properties (Dependent, SetAccess = private)
        Valid
    end
    
    properties (Access = protected) % Layout
        FigureSize =  [699, 229]
        PanelSize = [699, 229];

        IsStandalone = false
    end
    
    properties % Testing: Set to public in order to give as input from external...
        ControlPanels matlab.ui.container.Panel
    end
    
    properties (Access = protected) % UI Components
        Figure matlab.ui.Figure
        LoadingPanel matlab.ui.container.Panel
        LoadingImage
    end
    
    
    methods % Constructor
        % Todo
        
        function delete(app)
            
            isdeletable = @(x) ~isempty(x) && isvalid(x);
            
            for i = 1:numel(app.UIModule)
                if isdeletable( app.UIModule{i} )
                    delete( app.UIModule{i} )
                end
            end
            
            if isdeletable(app.LoadingPanel)
                delete( app.LoadingPanel )
            end
            
            if app.IsStandalone
                if isdeletable(app.Figure)
                    delete( app.Figure )
                end
            end
            
        end
    end
    
    methods
        
        function transferOwnership(app, controllerApp)
        %transferOwnership Transfer ownership of app to another app   
            
        % App (figure) deletion is now controlled by another app. If figure
        % window is closed, the figure is not deleted, just made invisible
        
            app.Figure.CloseRequestFcn = @(s,e) app.hideApp;
            addlistener(controllerApp, 'ObjectBeingDestroyed', @(s,e) app.delete);
            
        end
        
    end
    
    methods % Set/Get methods
        function set.Visible(app, visibleState)
            if isequal(app.Visible, visibleState)
                app.Figure.Visible = 'off';
                drawnow
            end
            app.Figure.Visible = visibleState;
        end
        
        function visibleState = get.Visible(app)
            visibleState = app.Figure.Visible;
        end

        function set.AllowResize(obj, resizeState)
            if resizeState ~= obj.AllowResize
                if resizeState
                    obj.Figure.Resize = 'on';
                    obj.Figure.AutoResizeChildren = 'off';
                    obj.Figure.SizeChangedFcn = @obj.onFigureSizeChanged;
                else
                    obj.Figure.Resize = 'off';
                    obj.Figure.AutoResizeChildren = 'on';
                    obj.Figure.SizeChangedFcn = [];
                end
            end
        end

        function resizeState = get.AllowResize(obj)
            resizeState = obj.Figure.Resize;
        end
        
        function isValid = get.Valid(app)
            isValid = isvalid(app) && isvalid(app.Figure);
        end
        
        function set.ControllerApp(app, newValue)
            app.ControllerApp = newValue;
            app.transferOwnership(newValue)
        end
    end
    
    methods (Access = protected)
        
        function hideApp(app)
            app.Figure.Visible = 'off';
        end
        
        function onFigureClosed(obj, src, evt)
            delete(obj.Figure)
        end

        function createFigure(obj)
            
            obj.Figure = uifigure('Visible', 'off');
            obj.Figure.Position(3:4) = obj.FigureSize; 
            obj.Figure.Resize = 'off';
            uim.utility.centerFigureOnScreen(obj.Figure)

            obj.Figure.Name = obj.AppName; 
            obj.Figure.CloseRequestFcn = @obj.onFigureClosed;
            
            obj.IsStandalone = true;
        end
        
        function createLoadingPanel(obj)
            
            obj.LoadingPanel = uipanel(obj.Figure);
            obj.LoadingPanel.Position = [0,0,obj.Figure.Position(3:4)];
            
            % Create LoadingImage
            uiImage = uiimage(obj.LoadingPanel);
            uiImage.Position(3:4) = [140 140];
            uiImage.ImageSource = fullfile(nansen.toolboxdir, 'resources', 'images', 'loading.gif');
            
            uiText = uilabel(obj.LoadingPanel);
            uiText.Text = 'Composing, just a moment please...';
            uiText.Position(3:4) = [200, 22];
            uiText.HorizontalAlignment = 'center';
            
            % Todo (Does not work as I expected, i.e not at all...):
            %addlistener(obj.LoadingPanel, 'SizeChanged', @obj.onLoadingPanelPositionChanged);
            %addlistener(obj.LoadingPanel, 'LocationChanged', @obj.onLoadingPanelPositionChanged);
            
            obj.LoadingImage = uiImage;
            obj.LoadingImage.UserData.Caption = uiText;
            obj.LoadingPanel.Visible = 'off';
            
            % Use callback to make sure components are positioned correctly in panel:
            obj.onLoadingPanelPositionChanged()
        end
        
        function onLoadingPanelPositionChanged(obj)
            obj.updateLoadPanelComponentPositions()
        end
        
        function updateLoadPanelComponentPositions(obj)
        %updateLoadPanelComponentPositions Update position of components
            parentPosition = getpixelposition(obj.LoadingPanel);
            uim.utility.layout.centerObjectInRectangle(obj.LoadingImage, parentPosition)
            
            % Set position of loading caption
            refPos = obj.LoadingImage.Position;
            currentPos = obj.LoadingImage.UserData.Caption.Position;
            obj.LoadingImage.UserData.Caption.Position(1:2) = ...
                [refPos(1) + (refPos(3)-currentPos(3))/2, refPos(2) ];
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
        
        function resizeChildren(obj)
            obj.resizeControlPanel()
        end

    end
    
    methods (Access = private)
        function onFigureSizeChanged(obj, src, evt)
            obj.resizeChildren()
        end
    end

    methods (Static)
   
        function hPanel = createControlPanel(hParent)
            
            % Todo: Superclass...
            
            panelPosition = [ 20, 20, 699, 229];
            %panelPosition = [20, 20, obj.PanelSize];
            
            hPanel = uipanel(hParent);
            hPanel.Position = panelPosition;
        end 
        
    end
    
end