classdef DraggableRectangle < handle
    
    properties
        rectanglePlotHandle = gobjects(0);
        rectangleReleaseCallback = [];
    end
    
    properties (Abstract)
        anchorPoint
        hAxes
    end
    
    methods
        
        function plotRectangle(obj)
            
            if isempty(obj.rectanglePlotHandle)
                obj.rectanglePlotHandle = plot(obj.hAxes, nan, nan);
                obj.rectanglePlotHandle.Color = 'white';
                obj.rectanglePlotHandle.Color = ones(1,3)*0.5;
                obj.rectanglePlotHandle.LineWidth = 1;
                obj.rectanglePlotHandle.PickableParts = 'none';
                obj.rectanglePlotHandle.HitTest = 'off';
                obj.rectanglePlotHandle.Tag = 'Rectangular Selection Outline';
            else
                set(obj.rectanglePlotHandle, 'XData', nan, 'Ydata', nan)
            end
            
            if ~isempty(obj.rectanglePlotHandle)
                set(obj.rectanglePlotHandle, 'Visible', 'on')
            end
        end
        
        function updateRectangle(obj, currentPoint)
            
            if isempty(obj.rectanglePlotHandle); return; end
            
            % Set rectangle vertex coordinates
            x1 = obj.anchorPoint(1);
            y1 = obj.anchorPoint(2);
            
            if nargin < 2 || isempty(currentPoint)
                currentPoint = obj.hAxes.CurrentPoint(1, 1:2);
            end
            
            x2 = currentPoint(1);
            y2 = currentPoint(2);
            
            % Make sure rectangle does not exceed axes limits.
            xLim = obj.hAxes.XLim;
            yLim = obj.hAxes.YLim;
            
            if      x2 < xLim(1);   x2 = xLim(1);
            elseif  x2 > xLim(2);   x2 = xLim(2);
            end

            if      y2 < yLim(1);   y2 = yLim(1);
            elseif  y2 > yLim(2);   y2 = yLim(2);
            end
                        
            % Assign rectangle vertex coordinates to plot handle
            if ~isempty(obj.rectanglePlotHandle)
                obj.rectanglePlotHandle.XData = [x1, x1, x2, x2, x1];
                obj.rectanglePlotHandle.YData = [y1, y2, y2, y1, y1];
            end
        end
        
        function resetRectangle(obj)
            delete(obj.rectanglePlotHandle)
            obj.rectanglePlotHandle = [];
            
            % % % set(obj.rectanglePlotHandle, 'XData', nan, 'Ydata', nan)
            % % % set(obj.rectanglePlotHandle, 'Visible', 'off')
        end
    end
end
