classdef circleSelect < uim.interface.abstractPointer & ...
        roimanager.pointerTool.RoiDisplayInputHandler
    
    
    properties (Constant)
        exitMode = 'default';
    end

    properties % Properties related to displaying circle during creation
        circleToolCoords
        hCircle        % Line handle for temporary lines of roi circle
        defaultRadius = 6 
    end
    
    
    methods
               
        function obj = circleSelect(hAxes)
            obj.hFigure = ancestor(hAxes, 'figure');
            obj.hAxes = hAxes;
        end
        
        function activate(obj)
            activate@uim.interface.abstractPointer(obj)
            showCircle(obj)
        end
        
        function deactivate(obj)
            deactivate@uim.interface.abstractPointer(obj)
            hideCircle(obj)
        end
        
        function suspend(obj)
            suspend@uim.interface.abstractPointer(obj)
            hideCircle(obj)
        end
        
        function setPointerSymbol(obj)
            obj.hFigure.Pointer = 'crosshair';
        end
        
        function onButtonDown(obj, src, evt)

            if strcmp(obj.hFigure.SelectionType, 'alt')
                return
            end
            
            obj.isActive = true;
            
            currentPoint = obj.hAxes.CurrentPoint(1, 1:2);
            x = currentPoint(1);
            y = currentPoint(2);
            r = obj.circleToolCoords(3);
            
            obj.RoiDisplay.createCircularRoi(x, y, r);
            
        end
        
        
        function onButtonMotion(obj, src, evt)
            
            persistent prevValue
            if isempty(prevValue); prevValue = 0; end
            
            currentPoint = obj.hAxes.CurrentPoint(1, 1:2);
            
            % Hide circle tool if pointer is not in a "valid" position.
            x = round(currentPoint(1)); y = round(currentPoint(2));            
            tf = obj.RoiDisplay.isPointValid(x, y);
            
            if tf == 0 && prevValue ~= 0
                obj.hideCircle()
            elseif tf ~= 0 && prevValue == 0
                obj.showCircle()
            end
            prevValue = tf;

            
            tmpCoords = [currentPoint, obj.circleToolCoords(3)];
            obj.plotCircleTool(tmpCoords);
        end
        
        
        function onButtonUp(obj, src, event)
            obj.isActive = false;
        end
        
        
        function wasCaptured = onKeyPress(obj, src, event)
            wasCaptured = true;
            
            switch event.Key
                case {'g', 'h'}
                    if contains('shift', event.Modifier)
                        deltaR = 0.5;
                    else
                        deltaR = 1;
                    end
                    
                    if isequal(event.Key, 'h')
                        deltaR = -1*deltaR;
                    end
                    
                    changeCircleRadius(obj, deltaR)
                otherwise
                    wasCaptured = false;
            end
            
            if wasCaptured
                return
            else % Pass on to roi keypress handler
                wasCaptured = obj.roiKeypressHandler(src, event);
            end
        end

    end
    
    methods
        
       function showCircle(obj)
            if isempty(obj.hCircle)
                obj.plotCircleTool()
            end
            
            obj.hCircle.Visible = 'on';
        end
        
        
        function hideCircle(obj)
            obj.hCircle.Visible = 'off';
        end
        
        
        function changeCircleRadius(obj, deltaR)
            
            tmpCoords = obj.circleToolCoords;
            tmpCoords(3) = tmpCoords(3) + deltaR;
            obj.plotCircleTool(tmpCoords)
            
        end
        
         
        
    end
    
    
    
    methods (Access = protected)
        
        function plotCircleTool(obj, coords)
            
            if nargin < 2 && ~obj.isPointerInsideAxes()
                if isempty(obj.circleToolCoords)
                    x = obj.hAxes.XLim(1) + range(obj.hAxes.XLim)/2;
                    y = obj.hAxes.YLim(1) + range(obj.hAxes.YLim)/2;
                    r = obj.defaultRadius;
                    obj.circleToolCoords = [x, y, r];
                else
                    x = obj.circleToolCoords(1); y = obj.circleToolCoords(2); 
                    r = obj.circleToolCoords(3);
                end
                
            elseif nargin < 2 && obj.isPointerInsideAxes()
                point = obj.hAxes.CurrentPoint;
                x = point(1,1);
                y = point(1,2);
                if isempty(obj.circleToolCoords)
                    r = obj.defaultRadius;
                else
                    r = obj.circleToolCoords(3);
                end
            else
                x = coords(1); y = coords(2); r = coords(3);            
            end
            
            if r <= 0
                return
            else
                obj.circleToolCoords = [x, y, r];
            end
            
            
            % Create circular line
            th = 0:pi/50:2*pi;
            xData = r * cos(th) + x;
            yData = r * sin(th) + y;
            
            % Plot Line
            if isempty(obj.hCircle)
                circColor = ones(1,3)*0.5;
                obj.hCircle = patch(obj.hAxes, xData, yData, 'w', 'EdgeColor', circColor);
                obj.hCircle.FaceAlpha = 0.15;
                obj.hCircle.PickableParts = 'none';
                obj.hCircle.HitTest = 'off';
            else
                set(obj.hCircle, 'XData', xData, 'YData', yData)
            end
        end

    end
    
    
    
end