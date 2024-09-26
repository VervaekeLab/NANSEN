classdef selectObject < uim.interface.abstractPointer & ...
        uim.interface.pointerTool.mixin.DraggableRectangle & ...
        roimanager.pointerTool.RoiDisplayInputHandler
    
    properties (Constant)
        exitMode = 'default';
    end
    
    properties
        anchorPoint = [nan, nan]        	% defined in clib.hasDraggableRectangle
        previousPoint = [nan, nan]
        isButtonDown = false
    end
    
    properties
        activeMode = ''       % Used for switching between different behaviors (selecting rois or moving rois) while mouse is pressed
        objectDisplacement = [0,0]
    end
    
    methods
               
        function obj = selectObject(hAxes, hRoiDisplay)
            obj.hAxes = hAxes;
            obj.hFigure = ancestor(hAxes, 'figure');
            
            if nargin >= 2
                obj.RoiDisplay = hRoiDisplay;
            end
        end

        function setPointerSymbol(obj)
            setptr(obj.hFigure, 'arrow');
        end
        
        function wasCaptured = onKeyPress(obj, src, event)
            
            wasCaptured = true;
            
            % Keypress events that should always be handled:
            switch event.Key
                
                case 'a'
                    if contains('command', event.Modifier) || ...
                            contains('control', event.Modifier)
                        numRois = obj.RoiDisplay.RoiGroup.roiCount;
                        obj.RoiDisplay.selectRois(1:numRois, 'extend')
                    else
                        wasCaptured = false;
                    end
                otherwise
                    wasCaptured = false;
                
            end
            
            if wasCaptured
                return
            else % Pass on to roi keypress handler
                wasCaptured = obj.roiKeypressHandler(src, event);
            end
        end
        
        function onButtonDown(obj, src, event)
        %onButtonDown Callback for handling button down events in a roiMap.
                    
            obj.isButtonDown = true;
            obj.isActive = true;

            if isempty(  obj.RoiDisplay ); return; end
            
            [isRoiSelected, roiInd] = obj.RoiDisplay.hittest(src, event);
            
            %hFig = ancestor(obj.hAxes, 'figure');
            %obj.RoiDisplay.selectRois(roiInd, hFig.SelectionType, true)
            
            currentPoint = obj.hAxes.CurrentPoint(1, 1:2);
            obj.anchorPoint = currentPoint;
            obj.previousPoint = currentPoint;
            
            switch obj.hFigure.SelectionType
                
                case {'normal', 'extend'}
            
                    if isRoiSelected
                        obj.activeMode = 'moveObjects';
                    else
                        obj.activeMode = 'selectObjects';
                        obj.plotRectangle()
                    end
                    
                case 'open'
                    if isRoiSelected
                        obj.RoiDisplay.zoomInOnRoi([], true)
                        obj.isActive = false;
                    end
            end
        end
        
        function onButtonMotion(obj, ~, ~)
            if isempty(obj.previousPoint); return; end
            if obj.isButtonDown && obj.isActive
                
                currentPoint = obj.hAxes.CurrentPoint(1, 1:2);

                switch obj.activeMode
                    case 'moveObjects'
                        
                        shift = currentPoint - obj.previousPoint;
                        obj.objectDisplacement = obj.objectDisplacement + shift;
                        obj.RoiDisplay.shiftRoiPlot([shift, 0]);
                        
                    case 'selectObjects'
                    
                    	set(obj.hFigure, 'Pointer', 'crosshair');
                        obj.updateRectangle(currentPoint)
                end
                
                obj.previousPoint = currentPoint;
                
            end
        end
        
        function onButtonUp(obj, src, evt)
            if ~obj.isButtonDown; return; end % Button is released from a different component, i.e a toolbar button

            obj.isButtonDown = false;
            obj.isActive = false;
            
            axRange = mean( [diff(obj.hAxes.XLim), diff(obj.hAxes.YLim) ] );
            
            if all((abs(obj.anchorPoint - obj.previousPoint)) < axRange * 1e-3) % No movement
                obj.RoiDisplay.deselectRois() % Unselect..
                
            else
                
                switch obj.activeMode
                    case 'moveObjects'
                        
                        if any(obj.objectDisplacement ~= 0)
                            obj.RoiDisplay.moveRoi(obj.objectDisplacement);
                            obj.objectDisplacement = [0, 0];
                        end
                
                    case 'selectObjects'
                
                        xBounds = sort( [obj.anchorPoint(1), obj.previousPoint(1)] );
                        yBounds = sort( [obj.anchorPoint(2), obj.previousPoint(2)] );

                        obj.resetRectangle();
                        obj.RoiDisplay.multiSelectRois(xBounds, yBounds);
                end
            end
            
            % Reset active mode.
            obj.activeMode = '';
            
            obj.setPointerSymbol()
            obj.previousPoint = [nan, nan];
        end
    end
end
