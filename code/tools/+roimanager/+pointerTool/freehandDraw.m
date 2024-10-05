classdef freehandDraw < uim.interface.abstractPointer & ...
        roimanager.pointerTool.RoiDisplayInputHandler
        
    properties (Constant)
        exitMode = 'default';
    end
    
    properties
        
        anchorPoint = [nan, nan]        	% defined in clib.hasDraggableRectangle
        previousPoint = [nan, nan]

        isButtonDown = false
        
    end
    
    properties (Access = protected)
        hTempLine
    end
    
    methods
        
        function obj = freehandDraw(hAxes, hRoiDisplay)
            obj.hAxes = hAxes;
            obj.hFigure = ancestor(hAxes, 'figure');
            
            if nargin >= 2
                obj.RoiDisplay = hRoiDisplay;
            end
        end
        
        function deactivate(obj)
            deactivate@uim.interface.abstractPointer(obj)
            resetTempLine(obj)
        end
        
        function setPointerSymbol(obj)
                                    
            pdata = NaN(16,16);
            pdata(7:10, 7:10) = 2;
            pdata(8:9, 8:9) = 1;
            set(obj.hFigure, 'Pointer', 'custom', 'PointerShapeCData', pdata, 'PointerShapeHotSpot', [8,8])
            
        end
        
        function wasCaptured = onKeyPress(obj, src, event)
            wasCaptured = true;
            
            switch event.Key
                case 'esc'
                    obj.resetTempLine()
                case 'f'
                    obj.finishRoi()
            end
        end
        
        function onButtonDown(obj, src, event)
        %onButtonDown Callback for handling button down events in a roiMap.
                    
            obj.isButtonDown = true;
            %obj.isActive = true;
            
        end
        
        function onButtonMotion(obj, ~, ~)
             
            if obj.isButtonDown
               obj.drawLine('draw')
               drawnow limitrate
            end
        end
        
        function onButtonUp(obj, src, evt)
                   
            obj.isButtonDown = false;
            obj.drawLine('pause')
            
        end
        
        function drawLine(obj, mode)
            
            if nargin < 2; mode = 'draw'; end
        
            point = obj.hAxes.CurrentPoint;

            switch mode
                case 'pause'
                    xNew = [point(1,1), nan];
                    yNew = [point(1,2), nan];
                otherwise
                    xNew = point(1,1);
                    yNew = point(1,2);
            end
            
            if isempty(obj.hTempLine)
                xData = xNew;
                yData = yNew;
            else
                xData = horzcat(obj.hTempLine.XData, xNew);
                yData = horzcat(obj.hTempLine.YData, yNew);
            end

            win = max([1,numel(xData)-4]):numel(xData);
            
            if ~any(isnan(xData(win)))
                xData(win) = smoothdata(xData(win));
                yData(win) = smoothdata(yData(win));
            end
            
            if isempty(obj.hTempLine)
                obj.hTempLine = plot(obj.hAxes, xData, yData, '-', 'LineWidth', 2, 'Color', 'c');
                obj.hTempLine.HitTest = 'off';
                obj.hTempLine.PickableParts = 'None';
            else
                set(obj.hTempLine, 'XData', xData)
                set(obj.hTempLine, 'YData', yData)
            end
        end
    
        function resetTempLine(obj)
            delete(obj.hTempLine)
            obj.hTempLine = [];
        end
        
        function finishRoi(obj)
            
            % Abort if there is no outline
            if isempty(obj.hTempLine)
                return
            end

            x = obj.hTempLine.XData;
            y = obj.hTempLine.YData;
            
            % Abort if outline is very small.
            if numel(x) < 3
                return
            end
            
            divisionPoints = [0, find( isnan(x) )];
            
            xUs = [];
            yUs = [];
            
            for i = 1:numel(divisionPoints)-1
            
                ii = divisionPoints(i) + 1;
                ie = divisionPoints(i+1) - 1;
                
                numPoints = ie-ii+1;
                W = min( [numel(x(ii:ie))-1, 10] );
                
                %xTmp = interp(x(ii:ie), W);
                xTmp = interp1(1:numPoints, x(ii:ie), linspace(1,numPoints,numPoints*10));
                xTmp = round( smoothdata(xTmp, 10) );
                
                %yTmp = interp(y(ii:ie), W);
                yTmp = interp1(1:numPoints, y(ii:ie), linspace(1,numPoints,numPoints*10));
                yTmp = round( smoothdata(yTmp, 10) );
                
                xUs = [xUs, nan, xTmp];
                yUs = [yUs, nan, yTmp];
                
            end
                
            %Todo: Add thickness as input
            obj.RoiDisplay.createFreehandRoi(xUs, yUs);

            obj.resetTempLine()
                
        end
    end
end
