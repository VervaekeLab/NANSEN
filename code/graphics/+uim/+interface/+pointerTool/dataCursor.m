classdef dataCursor < uim.interface.abstractPointer
    
    % Todo: 
    %   1) Implement different modes.
    %       I.e should it show data of a line? or an image? or just the
    %       coordinates of the axes...?
    %   2) Implement different plot styles.
    %   3) Should it work on mouseover, or only on button click?
    
    
    
    properties (Constant)
        exitMode = 'default';
    end
    
    
    properties
        xLimOrig
        yLimOrig
        cursorColor = ones(1,3)*0.5
    end
    
    
    properties (Access = private)
        isButtonDown = false
        hCrosshair % Line handle for temporary lines of data cursor crosshair
    end
    
    
    
    methods
        
        
        function obj = dataCursor(hAxes)
            
            obj.hAxes = hAxes;
            obj.xLimOrig = obj.hAxes.XLim;
            obj.yLimOrig = obj.hAxes.YLim;
            
            obj.hFigure = ancestor(hAxes, 'figure');
            
        end
        
        
        function activate(obj)
            activate@uim.interface.abstractPointer(obj)
            obj.plotCrosshair()
            
            set(obj.hCrosshair, 'Visible', 'on')
            obj.isActive = true;
            
        end
        
                
        function suspend(obj)
            suspend@uim.interface.abstractPointer(obj)
            set(obj.hCrosshair, 'Visible', 'off')
        end
        
        
        
        function deactivate(obj)
            deactivate@uim.interface.abstractPointer(obj)
            set(obj.hCrosshair, 'Visible', 'off')
            obj.isActive = false;
        end
        
        
        function setPointerSymbol(obj)
            obj.hFigure.Pointer = 'circle';            
        end
        
        
        function onButtonDown(obj, ~, ~)
            obj.isButtonDown = true;
        end
        
        
        function onButtonMotion(obj, src, evt)

            currentPoint = obj.hAxes.CurrentPoint(1, 1:2);
            
            if ~obj.isPointerInsideAxes(currentPoint); return; end
            if ~obj.isActive; return; end
            
            obj.plotCrosshair(currentPoint)
            
            if ~isempty(obj.buttonMotionCallback)
            	obj.buttonMotionCallback(src, evt)
            end

        end
        
        function onButtonUp(obj, src, evt)
            obj.isButtonDown = false;
        end
        
        
        function set.cursorColor(obj, newColor)
            obj.cursorColor = newColor;
            obj.updateCursorColor()
        end

    end
    
    
    methods (Access = private)
        
        
        function plotCrosshair(obj, center)

            hAx = obj.hAxes;
            
            
            if nargin < 2 && ~obj.isPointerInsideAxes()
                y0 = mean(hAx.YLim);
                x0 = mean(hAx.XLim);
            elseif nargin < 2 && obj.isPointerInsideAxes()
                point = hAx.CurrentPoint(1,1:2);
                x0 = point(1);
                y0 = point(2);
            else
                x0 = center(1);%+1*ps/10;
                y0 = center(2);%+0;
            end            
            
            xdata1 = obj.xLimOrig;
            ydata1 = ones(size(xdata1))*y0;
            
            ydata2 = obj.yLimOrig;
            xdata2 = ones(size(ydata2))*x0;
            
            
            % Plot Line
            if isempty(obj.hCrosshair)
                obj.hCrosshair = gobjects(4,1);
                obj.hCrosshair(1) = plot(hAx, xdata1, ydata1);
                obj.hCrosshair(2) = plot(hAx, xdata2, ydata2);
                obj.hCrosshair(3) = plot(hAx, xdata1, ydata1);
                obj.hCrosshair(4) = plot(hAx, xdata2, ydata2);
                set( obj.hCrosshair(1:2), 'Color', obj.cursorColor)
                set( obj.hCrosshair(1:2), 'LineWidth', 0.5)
                set( obj.hCrosshair(3:4), 'Color', [0,0,0])
                set( obj.hCrosshair(3:4), 'LineWidth', 1)
                
                set(obj.hCrosshair, 'LineStyle', '--')
                set(obj.hCrosshair, 'HitTest', 'off', 'PickableParts', 'none')
              
                obj.hCrosshair(5) = plot(obj.hAxes, x0, y0, '.', 'MarkerSize', 20);
                obj.hCrosshair(5).Color =  obj.cursorColor;
                
            else
%                 set(obj.hCrosshair, {'XData'}, {xdata1,xdata2}', ...
%                                     {'YData'}, {ydata1,ydata2}' )
                set(obj.hCrosshair(1:4), {'XData'}, {xdata1,xdata2,xdata1,xdata2}', ...
                                    {'YData'}, {ydata1,ydata2,ydata1,ydata2}' )
                set(obj.hCrosshair(5), 'XData', x0, 'YData', y0)
            end
            
            
        end
        
        
        function updateCursorColor(obj)
            set( obj.hCrosshair, 'Color', obj.cursorColor)
        end
        
    end
    
    
    
end