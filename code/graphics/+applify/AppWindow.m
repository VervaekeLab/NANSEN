classdef AppWindow < uim.handle
    
    % This class relies on the undocumented JavaFrame property, which will
    % be removed in a future version of Matlab. Until then....
    
    
%   ABSTRACT PROPERTIES:
%       AppName (Constant,Access=protected) : Name of app    
%       MINIMUM_FIGURE_SIZE (Constant)  : Minimum size of figure
%
%
%   ABSTRACT METHODS:
%       setDefaultFigureCallbacks
%
   
    properties (Abstract, Constant)
        AppName char
    end
    
    properties (Constant, Hidden = true) % move to appwindow superclass
        MAC_MENUBAR_HEIGHT = 25; % Todo: Figure out if this is the same across systems and screens...
    end
    
    properties (SetAccess = protected, Hidden) % Layout
        DEFAULT_FIGURE_SIZE = [560 420] % Should be considered constant, i.e only set on construction...
        MINIMUM_FIGURE_SIZE = [560 420] % Should be considered constant, i.e only set on construction...
        
        Margins = [20, 20, 20, 20]
    end
    
    properties
        Figure
    end

    properties (Dependent, SetAccess = private)
        CanvasSize
    end
    
    
    properties (Access = protected) % Graphical components
        jFrame              % Its disappearing any day now! =(
        jWindow
    end
    
    properties (Access = protected) % State
        IsConstructed = false;
    end
    
    
    methods % Structors
        
        function obj = AppWindow(varargin)
            
            obj.assignDefaultSubclassProperties()
            % Todo: assignPvPairs...
            obj.createFigure()
            
        end
        
        function delete(obj)
            
        end
    end
    
    methods 
        function set.IsConstructed(obj, newValue)
            assert(islogical(newValue), 'Value must be logical')
            if ~obj.IsConstructed
                obj.IsConstructed = newValue;
                obj.onConstructedSet()
            end
        end
        
        function sz = get.CanvasSize(obj)
            sz = obj.Figure.Position(3:4) - sum( obj.Margins([1,2;3,4]) );
        end
        
    end
    
    methods (Access = protected)
        
        function assignDefaultSubclassProperties(obj)
            % Subclass may override. 
        end
        
        function setDefaultFigureCallbacks(obj)
            % Todo.
            obj.Figure.SizeChangedFcn = @(s,e) obj.setComponentLayout;
            % Subclasses may override
        end
        
        function setComponentLayout(obj)
            % Subclasses may override
        end
        
        function createFigure(obj)
            obj.Figure = figure('MenuBar', 'none');
            obj.Figure.NumberTitle = 'off';
            obj.Figure.Position(3:4) = obj.DEFAULT_FIGURE_SIZE();
            uim.utility.centerFigureOnScreen(obj.Figure)

            obj.getFigureJavaHandles()
            obj.setMinimumFigureSize()

            obj.setFigureName()
        end
        
        function setFigureName(obj)
            obj.Figure.Name = obj.AppName;
        end
        
        function onConstructedSet(obj)
            obj.setDefaultFigureCallbacks()
            uim.utility.centerFigureOnScreen(obj.Figure)
        end
        
        function configureWindow(obj)
            
            obj.switchJavaWarnings('off')
            
            % Place screen on the preferred screen if multiple screens are
            % available.
            MP = get(0, 'MonitorPosition');
            nMonitors = size(MP, 1);
            
            if nMonitors > 1
                screenNumber = obj.getPreference('PreferredScreen', 1);
                
                prefScreenPos = obj.getPreference('PreferredScreenPosition', [1, 1, 1180, 700]);
                obj.Figure.Position = prefScreenPos{screenNumber};
            end
            
            obj.getFigureJavaHandles()
            
            obj.setMinimumFigureSize()
            
            
            obj.switchJavaWarnings('on')

            
        end
        
        function setMinimumFigureSize(obj)
            
            minWidth = obj.MINIMUM_FIGURE_SIZE(1);
            minHeight = obj.MINIMUM_FIGURE_SIZE(2);

            obj.switchJavaWarnings('off')
            LimitFigSize(obj.Figure, 'min', [minWidth, minHeight]) % FEX
            obj.switchJavaWarnings('on')
        end
        
        function setFigureWindowBackgroundColor(obj, newColor)
        
            if nargin < 2
                newColor = [13,13,13] ./ 255;
            end

            rgb = num2cell(newColor);

            warning('off', 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
            warning('off', 'MATLAB:ui:javaframe:PropertyToBeRemoved')


            javaColor = javax.swing.plaf.ColorUIResource(rgb{:});
            set(obj.jWindow, 'Background', javaColor)

            warning('on', 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
            warning('on', 'MATLAB:ui:javaframe:PropertyToBeRemoved')

        end
        
        function getFigureJavaHandles(obj)
            
            obj.switchJavaWarnings('off')
            obj.jFrame = get(obj.Figure, 'JavaFrame'); %#ok<JAVFM>
            obj.jWindow = obj.jFrame.getFigurePanelContainer.getTopLevelAncestor;
            obj.switchJavaWarnings('on')

        end
        
    end
    
    methods
        function [screenSize, screenNum] = getCurrentMonitorSize(obj)
            [screenSize, screenNum] = obj.getMonitorInfo(obj.Figure);
        end
    end

    methods (Static)
        
        function switchJavaWarnings(newState)
        %switchJavaWarnings Turn warnings about java functionality on/off
            warning(newState, 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
            warning(newState, 'MATLAB:ui:javaframe:PropertyToBeRemoved')
            warning(newState, 'MATLAB:ui:javacomponent:FunctionToBeRemoved')
        end
        
        
        function [screenSize, screenNum] = getMonitorInfo(hFigure)
        %getMonitorInfo Get size and number of monitor containing figure.
        %
        %   Note: Size is the area of the screen available for the figure,
        %   OS menubars and figure header is excluded.

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
                screenNum = 1;
            else
                [screenSize, screenNum] = uim.utility.getCurrentScreenSize(hFigure);
            end
            
            if ismac
                osMenubarHeight = applify.AppWindow.MAC_MENUBAR_HEIGHT;
            elseif isunix
                osMenubarHeight = 0;
            elseif ispc
                osMenubarHeight = 0;
                %screenSize(2) = screenSize(2) + osMenubarHeight; TODO: CHECK
            end
            
            screenSize(4) = screenSize(4) - osMenubarHeight;
            screenSize(4) = screenSize(4) - titleBarHeight;

            if nargout < 2
                clear screenNum
            end

        end
    
    
    
    end
    
end