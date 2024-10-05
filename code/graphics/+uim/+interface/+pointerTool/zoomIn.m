classdef zoomIn < uim.interface.abstractPointer & uim.interface.zoom & ...
        uim.interface.pointerTool.mixin.DraggableRectangle
    
    properties (Constant)
        exitMode = 'previous';
    end
    
    properties % Tool specific
        zoomInCallback
        rectangularZoomCallback
        runDefault = false;
    end
    
    properties % Implement abstract properties from zoom
        zoomFactor = 0.25
        xLimOrig
        yLimOrig
    end
    
    properties % Implement abstract properties hasDraggableRectangle
        anchorPoint = [nan, nan]
        isButtonDown = false
    end
    
    methods
        
        function obj = zoomIn(hAxes)
            
            obj.hAxes = hAxes;
            obj.xLimOrig = obj.hAxes.XLim;
            obj.yLimOrig = obj.hAxes.YLim;
            
            obj.hFigure = ancestor(hAxes, 'figure');
        end

        function setPointerSymbol(obj)
            setptr(obj.hFigure, 'glassplus');
        end
        
        function onButtonDown(obj, ~, evt)
            
            if evt.Button==3; return; end
            
            obj.isButtonDown = true;
            obj.isActive = true;

            obj.anchorPoint = obj.hAxes.CurrentPoint(1, 1:2);
            
            obj.plotRectangle()
            
            set(obj.hFigure, 'Pointer', 'crosshair');
        end
        
        function onButtonMotion(obj, ~, ~)
            if obj.isButtonDown
                obj.updateRectangle()
            end
        end
        
        function onButtonUp(obj, src, evt)
            if ~obj.isButtonDown; return; end % MouseDown happened before tool was activated
            
            obj.isButtonDown = false;
            obj.isActive = false;

            currentPoint = get(obj.hAxes, 'CurrentPoint');
            currentPoint = currentPoint(1, 1:2);
            
            deltaErr = mean( [diff(obj.hAxes.XLim),diff(obj.hAxes.YLim) ] ) / 100;

            if all((abs(obj.anchorPoint - currentPoint)) < deltaErr) % No movement
                if ~isempty(obj.zoomInCallback)
                    if obj.runDefault
                        obj.imageZoom('in')
                    end
                    obj.zoomInCallback()
                else
                    obj.imageZoom('in')
                end
                %obj.buttonUpCallback();
            else
                newXLim = sort( [obj.anchorPoint(1), currentPoint(1)] );
                newYLim = sort( [obj.anchorPoint(2), currentPoint(2)] );

                obj.resetRectangle();
                
                if ~isempty( obj.rectangularZoomCallback )
                    if obj.runDefault
                        obj.setNewImageLimits(newXLim, newYLim)
                    end
                    obj.rectangularZoomCallback(newXLim, newYLim);
                else
                    obj.setNewImageLimits(newXLim, newYLim)
                    % obj.buttonUpCallback(newXLim, newYLim);
                end
                
%                 obj.imageZoomRect(); % Set new limits based on new and old point
            end
            
            obj.setPointerSymbol()

        end
    end
end
