classdef zoom < handle
    
    % TODO:
    % [ ] Add switcher to only zoom in x or only zoom in y.
    % [ ] Add plot zoom region here.
    %
    % [ ] Make this super class for both zoom and panning, i.e an
    %     axesDataLimits mixin (abstract) pointer tool...
    
    properties (Abstract)
        zoomFactor
        xLimOrig
        yLimOrig
    end
    
    properties
        zoomFinishedCallback
        % LimitsChangedFcn % Function to run when limits change.
    end

    methods
        
        function shiftView(obj, shift)
        % Move visible portion of axes according to shift
            
            % todo...

            % Get current axes limits
            xlim = get(obj.hAxes, 'XLim');
            ylim = get(obj.hAxes, 'YLim');

            % Convert mouse shift to image shift
            imshift = shift;
            xLimNew = xlim - imshift(1);
            yLimNew = ylim + imshift(2);

            obj.setNewImageLimits(xLimNew, yLimNew)

        end
    
        function imageZoom(obj, direction, speed)
            % Zoom in image

            if nargin < 3; speed = 1; end

            switch direction
                case 'in'
                        zoomF = -obj.zoomFactor .* speed;
                case 'out'
                        zoomF = obj.zoomFactor*2 .* speed;
            end

            xLim = get(obj.hAxes, 'XLim');
            yLim = get(obj.hAxes, 'YLim');
            
            % Get cursor position in figure (in pixels). The point which is
            % clicked should appear under the pointer when zooming in.
            figUnits = obj.hFigure.Units;
            obj.hFigure.Units = 'pixel';
            mp_f = get(obj.hFigure, 'CurrentPoint');
            obj.hFigure.Units = figUnits;

            axUnits = obj.hAxes.Units;
            obj.hAxes.Units = 'pixel';
            mp_a = get(obj.hAxes, 'CurrentPoint');
            obj.hAxes.Units = axUnits;
            mp_a = mp_a(1, 1:2);
            
            axPos = getpixelposition(obj.hAxes, true); % Need axes position in figure

            axLim = axPos + [0, 0, axPos(1), axPos(2)];

            % Check if mousepoint is within axes limits.
            insideImageAx = ~any(any(diff([axLim(1:2); mp_f; axLim(3:4)]) < 0));

            xLimNew = xLim + [-1, 1] * zoomF * diff(xLim);
            yLimNew = yLim + [-1, 1] * zoomF * diff(yLim);

            if insideImageAx
                mp_f = mp_f - [axPos(1), axPos(2)];

                % Correction of 0.25 was found to give precise zooming in and
                % out of a point... Is it the 0.5 offset in image coordinates
                % divided by 2?

                shiftX = (axPos(3)-mp_f(1)+0.25) / axPos(3)               * diff(xLimNew) - (xLim(1) + diff(xLim)/2 + diff(xLimNew)/2 - mp_a(1)) ;
                
                switch obj.hAxes.YDir
                    case 'normal'
                        shiftY = (axPos(4)-mp_f(2)) / axPos(4) * diff(yLimNew) - (yLim(1) + diff(yLim)/2 + diff(yLimNew)/2 - mp_a(2)) ;
                    case 'reverse'
                        shiftY = (axPos(4)-abs(axPos(4)-mp_f(2)-0.25)) / axPos(4) * diff(yLimNew) - (yLim(1) + diff(yLim)/2 + diff(yLimNew)/2 - mp_a(2)) ;
                end
                
                xLimNew = xLimNew + shiftX;
                yLimNew = yLimNew + shiftY;
            end
            
            if diff(xLimNew) > diff(obj.xLimOrig)
                xLimNew = obj.xLimOrig;
            elseif xLimNew(1) <= obj.xLimOrig(1)
                xLimNew = xLimNew - xLimNew(1) + obj.xLimOrig(1);
            elseif xLimNew(2) > obj.xLimOrig(2)
                xLimNew = xLimNew - (xLimNew(2) - obj.xLimOrig(2));
            end

            if diff(yLimNew) > diff(obj.yLimOrig)
                yLimNew = obj.yLimOrig;
            elseif yLimNew(1) <= obj.yLimOrig(1)
                yLimNew = yLimNew - yLimNew(1) + obj.yLimOrig(1);
            elseif yLimNew(2) > obj.yLimOrig(2)
                yLimNew = yLimNew - (yLimNew(2) - obj.yLimOrig(2));
            end

            setNewImageLimits(obj, xLimNew, yLimNew)

        end

        function setNewImageLimits(obj, xLimNew, yLimNew)

            % Todo: Have tests here to prevent setting limits outside of
            % image limits.
            
            pos = getpixelposition(obj.hAxes);
            axAR = pos(3)/pos(4); % Axes aspect ratio.
            
            xRange = diff(xLimNew); yRange = diff(yLimNew);

            % Adjust limits so that the zoomed image fills up the display
            if xRange/yRange > axAR
                yLimNew = yLimNew + [-1, 1] * (xRange/axAR - yRange)/2 ;
            elseif xRange/yRange < axAR
                xLimNew = xLimNew + [-1, 1] * (yRange*axAR-xRange)/2;
            end
    
            if diff(xLimNew) > diff(obj.xLimOrig)
                xLimNew = obj.xLimOrig;
            elseif xLimNew(1) <= obj.xLimOrig(1)
                xLimNew = xLimNew - xLimNew(1) + obj.xLimOrig(1);
            elseif xLimNew(2) > obj.xLimOrig(2)
                xLimNew = xLimNew - (xLimNew(2) - obj.xLimOrig(2));
            end

            if diff(yLimNew) > diff(obj.yLimOrig)
                yLimNew = obj.yLimOrig;
            elseif yLimNew(1) <= obj.yLimOrig(1)
                yLimNew = yLimNew - yLimNew(1) + obj.yLimOrig(1);
            elseif yLimNew(2) > obj.yLimOrig(2)
                yLimNew = yLimNew - (yLimNew(2) - obj.yLimOrig(2));
            end

            set(obj.hAxes, 'XLim', xLimNew, 'YLim', yLimNew)
            %plotZoomRegion(obj, xLimNew, yLimNew)

            if ~isempty(obj.zoomFinishedCallback)
                obj.zoomFinishedCallback()
            end
        end
        
        function setNewXLims(obj, newLimits)
                      
            if nargin == 1 || isempty(newLimits)
                newLimits = obj.xLimOrig;
            end
            
            % Todo: Make sure XLim2 > XLim1
            
            newLimits(1) = max([obj.xLimOrig(1), newLimits(1)]);
            newLimits(2) = min([obj.xLimOrig(2), newLimits(2)]);
            
            % Set new limits
            set(obj.ax, 'XLim', newLimits);

            drawnow limitrate
            
        end
        
        function setNewYLims(obj, newLimits)
            
            % Set new limits
            if nargin == 1 || isempty(newLimits)
                set(obj.ax, 'YLim', obj.YLimExtreme.(obj.ActiveYAxis))
                obj.updateFrameMarker('update_y')
%                 set(obj.ax, 'XLim', [1, obj.tsArray(1).Time(end)])
            else
                set(obj.ax, 'YLim', newLimits);
                obj.updateFrameMarker('update_y')
            end
        end
    end
end
