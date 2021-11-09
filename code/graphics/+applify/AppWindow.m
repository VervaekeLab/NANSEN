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
   
    properties (Abstract, Constant, Access=protected)
        AppName char
    end
    
    properties (Abstract, Constant)
        MINIMUM_FIGURE_SIZE
    end
    
    properties (Constant, Hidden = true) % move to appwindow superclass
        MAC_MENUBAR_HEIGHT = 25; % Todo: Is this always constant???
    end
    
    
    properties (Dependent)
        Figure
    end
    
    
    properties (Access = protected)
        hFigure
        jFrame              % Its disappearing any day now! =(
        jWindow
    end
    
    
    methods (Abstract)
        
        setDefaultFigureCallbacks
    
    end
    
    
    methods % Structors
        
        function obj = AppWindow(varargin)
            
        end
        
        function delete(obj)
            
        end
    end
    
    
    methods (Access = protected)
        
        function createFigure(obj)
        
        end
        
        function setFigureName(obj)
            
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

            LimitFigSize(obj.Figure, 'min', [minWidth, minHeight]) % FEX

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
        
            obj.jFrame = get(obj.hFigure, 'JavaFrame'); %#ok<JAVFM>
            obj.jWindow = obj.jFrame.getFigurePanelContainer.getTopLevelAncestor;
            
        end
        
    end
    
    methods
        function [screenSize, screenNum] = getCurrentMonitorSize(obj)
            [screenSize, screenNum] = obj.getMonitorInfo(obj.hFigure);
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
                osMenubarHeight = applify.AppWindow.MAC_MENUBAR_HEIGHT;
            elseif isunix
                osMenubarHeight = 0;
            elseif ispc
                osMenubarHeight = 0;
                %screenSize(2) = screenSize(2) + osMenubarHeight; TODO: CHECK
            end
            
            screenSize(4) = screenSize(4) - osMenubarHeight;

            screenSize(4) = screenSize(4) - titleBarHeight;
            

            if nargout == 2
                screenNum = i;
            end

        end
    
    
    
    end
    
end