classdef ConfigurationApp < handle
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
    end
    
    properties (Access = protected) % Layout
        FigureSize =  [699, 229]
        IsStandalone = false
    end
    
    properties (Access = protected) % UI Components
        Figure matlab.ui.Figure
        ControlPanels matlab.ui.container.Panel
        LoadingPanel matlab.ui.container.Panel
        LoadingImage
    end
    
    
    methods % Constructor
        % Todo
    end
    
    
    methods (Access = protected)
        
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
            uiImage.ImageSource = 'loading.gif';
            
            % Todo (Does not work as I expected...):
            addlistener(obj.LoadingPanel, 'SizeChanged', @obj.onLoadingPanelPositionChanged);
            
            parentPosition = getpixelposition(obj.LoadingPanel);
            uim.utility.layout.centerObjectInRectangle(uiImage, parentPosition)
            
            obj.LoadingImage = uiImage;
        end
        
        function onLoadingPanelPositionChanged(obj)
            
            parentPosition = getpixelposition(obj.LoadingPanel);
            uim.utility.layout.centerObjectInRectangle(obj.LoadingImage, parentPosition)
            
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