classdef axisZoom < uim.interface.abstractPointer
%
%   Tool for changing limits of axis (XLim or YLim) by dragging the axis.

%   TODO:
%       [ ] Inherit from a zoom class
%       [ ] Options for constraining zoom to original limits (implement)
%       [ ] Options for syncing two axis (if axes has dual axis along the
%           dimensions)

    properties (Constant)
        exitMode = 'previous';
    end
    
    properties
        xLimOrig
        yLimOrig
        
        constrainX = true;
        constrainY = true;
                
        CurrentAxis = ''
        
        previousPoint (1,2) double = [nan, nan] % Todo: Should be property of pointermanager, or at least super class...???
        isButtonDown (1,1) logical = false
        
        isMouseDown
        PreviousMouseClickPoint   % Point where mouse was last clicked
        PreviousMousePoint
    
    end
    
    methods
            
        function obj = pan(hAxes)
            obj.hAxes = hAxes;
            obj.xLimOrig = obj.hAxes.XLim;
            obj.yLimOrig = obj.hAxes.YLim;
            
            obj.hFigure = ancestor(hAxes, 'figure');
        end

        function setPointerSymbol(obj)
            switch obj.CurrentAxis
                case 'y'
                    obj.hFigure.Pointer = 'top';
                case 'x'
                    obj.Figure.Pointer = 'left';
                otherwise
                    % Should be manages elsewhere
            end
        end
        
        function onButtonDown(obj, ~, evt)
            
            if evt.Button == 3; return; end
            
            if strcmp(obj.Figure.SelectionType, 'normal')
                obj.isMouseDown = true;
                obj.PreviousMouseClickPoint = obj.Figure.CurrentPoint;
                obj.PreviousMousePoint = obj.Figure.CurrentPoint;
            end
            
            obj.isActive = true;
            
        end
        
        function onButtonMotion(obj, ~, ~)
            
            persistent isBusy
            if isempty(isBusy); isBusy=false; end
            
            if obj.isButtonDown
                if isBusy
                    return
                end
                isBusy = true;
                currentPoint = obj.hFigure.CurrentPoint;
                shift = currentPoint - obj.previousPoint;
                
                if ~isempty(obj.buttonMotionCallback)
                    obj.buttonMotionCallback(shift)
                else
                    moveAxes(obj, shift)
                end
                
                %moveAxes(obj, shift)

                obj.previousPoint = currentPoint;
                isBusy = false;

            end
        end
        
        function onButtonUp(obj, src, evt)
            obj.isMouseDown = false;
            obj.PreviousMouseClickPoint = [];
            obj.isActive = false;
        end
        
        function changeAxisLimits(obj, shift)
        % Move image in ax according to shift

        end
                
        function dragYLimits(obj, location)
            
            currentPoint = obj.Figure.CurrentPoint;

            currentYAxisLocation = obj.ax.YAxisLocation;
            switchYAxis = ~strcmp(currentYAxisLocation, location);

            if switchYAxis
                yyaxis(obj.ax, location)
            end

            deltaY = currentPoint(2) - obj.PreviousMousePoint(2);
            deltaY = deltaY / obj.ax.Position(4);

            yLimRange = range(obj.ax.YLim);
            yLimDiff = yLimRange .* deltaY;

            newYLim = [obj.ax.YLim(1)-yLimDiff, obj.ax.YLim(2)+yLimDiff];
            obj.setNewYLims(newYLim)

% %             if switchYAxis % Switch back...
% %                 yyaxis(obj.ax, currentYAxisLocation)
% %                 currentYAxisLocation
% %             end
                    
        end
        
        function dragXLimits(obj)
            
            currentPoint = obj.hFigure.CurrentPoint;
            deltaX = currentPoint(1) - obj.PreviousMousePoint(1);
            deltaX = deltaX / obj.hAxes.Position(3);

            xLimRange = range(obj.hAxes.XLim);
            xLimDiff = xLimRange .* deltaX;

            newXLim = [obj.hAxes.XLim(1)-xLimDiff, obj.hAxes.XLim(2)+xLimDiff];
            obj.setNewXLims(newXLim)
        end
    end
end
