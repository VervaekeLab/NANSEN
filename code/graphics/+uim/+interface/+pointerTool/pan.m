classdef pan < uim.interface.abstractPointer

    properties (Constant)
        exitMode = 'previous';
    end
    
    
    properties
        xLimOrig
        yLimOrig
                
        previousPoint (1,2) double = [nan, nan]
        isButtonDown (1,1) logical = false
    end
    
    
    
    
    methods
            
        function obj = pan(hAxes)
            obj.hAxes = hAxes;
            obj.xLimOrig = obj.hAxes.XLim;
            obj.yLimOrig = obj.hAxes.YLim;
            
            obj.hFigure = ancestor(hAxes, 'figure');
        end
        

        function setPointerSymbol(obj)
            setptr(obj.hFigure, 'hand');
        end

        
        function onButtonDown(obj, ~, evt)
            
            if evt.Button == 3; return; end 
            
            obj.isButtonDown = true;
            obj.isActive = true;
            
            obj.previousPoint = obj.hFigure.CurrentPoint;
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
                    %moveAxes(obj, shift)
                end
                
                %moveAxes(obj, shift)

                obj.previousPoint = currentPoint;
                isBusy = false;

            end
        end
        
        
        function onButtonUp(obj, src, evt)
            obj.isButtonDown = false;
            obj.isActive = false;
        end
        
        
        
        function moveAxes(obj, shift)
        % Move image in ax according to shift
            
            % Get ax position in figure coordinates
            axPos = getpixelposition(obj.hAxes);
        
            if strcmp(obj.hAxes.YDir, 'reverse') 
                shift(2) = -1 * shift(2);
            end
            
            % Get current axes limits
            xlim = obj.hAxes.XLim;
            ylim = obj.hAxes.YLim;
            
            % Convert mouse shift to image shift
            imshift = shift ./ axPos(3:4) .* [diff(xlim), diff(ylim)];
            xlim = xlim - imshift(1);
            ylim = ylim - imshift(2);

            % Dont move outside of image boundaries..
            if xlim(1) > obj.xLimOrig(1) && xlim(2) < obj.xLimOrig(2)
                set(obj.hAxes, 'XLim', xlim);
%                 plotZoomRegion(obj, xlim, obj.hAxes.YLim)

            end
            
            if ylim(1) > obj.yLimOrig(1) && ylim(2) < obj.yLimOrig(2)
                set(obj.hAxes, 'YLim', ylim);
%                 plotZoomRegion(obj, obj.hAxes.XLim, ylim)
            end
        end

        
    end
    
end