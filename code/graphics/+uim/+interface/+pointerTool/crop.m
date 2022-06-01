classdef crop < uim.interface.abstractPointer

    properties (Constant)
        exitMode = 'previous';
    end
    
    
    properties
        plotColor = [32, 32, 32]./255;
        textColor = ones(1,3)*0.8;
        xLimOrig
        yLimOrig
        
        currentXLim = []
        currentYLim = []
        
    end
    
    properties
        hImrect
        hCroppedBoundaryPatch
        hInitialCornerText
        hRectangleSizeText
    end
    
    events
        CropLimitChanged
    end
    

    methods
        
        function obj = crop(hAxes)
            obj.hAxes = hAxes;
            obj.xLimOrig = obj.hAxes.XLim;
            obj.yLimOrig = obj.hAxes.YLim;
            
            obj.hFigure = ancestor(hAxes, 'figure');
            obj.hRectangleSizeText = text(obj.hAxes, 'Color', obj.textColor);
        end
        
        function activate(obj)
            activate@uim.interface.abstractPointer(obj)
            obj.hRectangleSizeText.Visible = 'on';
            obj.selectRectangularRoi()
            obj.updateInitialCornerText()
        end
        
        function deactivate(obj)
            
            deactivate@uim.interface.abstractPointer(obj)
            uiresume(obj.hFigure)
            
            if ~isempty(obj.hImrect)
                
                if isvalid(obj.hImrect)
                    if exist('drawrectangle', 'file')
                        rcc = round(obj.hImrect.Position);
                    else
                        rcc = round(obj.hImrect.getPosition);
                    end
                    
                else
                    rcc = [];
                end
                                
                delete(obj.hImrect);
                obj.hImrect = [];

            else
                rcc = [];
            end
            
            obj.hRectangleSizeText.Visible = 'off';
            if isempty(rcc); return; end

            obj.makeCroppedRegionSemiOpaque(rcc)
            obj.updateLimits(rcc)
            
            evtData = uiw.event.EventData('XLim', obj.currentXLim, 'YLim', obj.currentYLim);
            obj.notify('CropLimitChanged', evtData)
        end

    end
    
    
        
    methods 
        
        function setPointerSymbol(obj)
        end
        function onButtonDown(obj, src, event)
        end
        function onButtonMotion(obj, src, event)
            % Update rectangle size text
        end
        function onButtonUp(obj, src, event)
        end
        
    end
    
    
    methods (Access = private)
        
        function updateInitialCornerText(obj)
            
        end
        
        function selectRectangularRoi(obj)
            
            rccInit = obj.getRectangleInitCoordinates;
            
            % Move to non-class function
            if exist('drawrectangle', 'file')
                if ~isempty(rccInit)
                    hrect = drawrectangle(obj.hAxes, 'Position', rccInit);
                else
                    hrect = drawrectangle(obj.hAxes);
                end
                addlistener(hrect, 'MovingROI', @obj.onRectangleSizeChanged);
                obj.updateRectangleContextMenu(hrect)
                
                hrect.LineWidth = 1;
                hrect.Color = obj.plotColor;
                hrect.StripeColor = ones(1,3)*0.8;
                hrect.DrawingArea = [1, 1, obj.xLimOrig(2)-1, obj.yLimOrig(2)-1];
                
            else
                hrect = imrect(obj.hAxes, rccInit); %#ok<IMRECT>
                hrect.setColor(obj.plotColor)
                restrainCropSelection = makeConstrainToRectFcn('imrect', obj.xLimOrig, obj.yLimOrig);
                hrect.setPositionConstraintFcn( restrainCropSelection );
            end
            
            obj.hImrect = hrect;
            uiwait(obj.hFigure)
            
            obj.deactivate();
        end
        
        function makeCroppedRegionSemiOpaque(obj, rcc)
            
            % Create an alphamask for image, where cropped part is in focus
            vertexX = rcc(1) + [0, rcc(3), rcc(3), 0];
            vertexY = rcc(2) + [0, 0, rcc(4), rcc(4)];

            hImage = findobj(obj.hAxes, 'Type', 'Image');

            if numel(hImage) > 1
                hImage = hImage(end); % Pick the first one that was added.
            end

            imSize = size(hImage.CData);
            imSize = imSize(1:2);
            imSizeXY = fliplr(imSize);
            
            imSizeXY = [obj.xLimOrig(2), obj.yLimOrig(2)];

        %             mask = double(poly2mask(vertexX, vertexY, imSizeXY(2), imSizeXY(1)));
        %             mask(~mask) = 0.4;
        %             hImage.AlphaData = mask;

            outerBoxX = [0, imSizeXY(1)+1, imSizeXY(1)+1, 0, 0];
            innerBoxX = [vertexX, vertexX(1)];
            outerBoxY = [imSizeXY(2)+1, imSizeXY(2)+1, 0, 0, imSizeXY(2)+1];
            innerBoxY = [vertexY, vertexY(1)];
            
            if isempty(obj.hCroppedBoundaryPatch)
                h = patch(obj.hAxes, [outerBoxX, innerBoxX], [outerBoxY, innerBoxY], 'k');
                h.FaceAlpha = 0.3;
                h.EdgeColor = 'none';
                h.Tag = 'Crop Outline';
                obj.hCroppedBoundaryPatch = h;
            else
                h = obj.hCroppedBoundaryPatch;
                set(h, 'XData', [outerBoxX, innerBoxX], 'YData',  [outerBoxY, innerBoxY] )
            end
            
        end
    
        function rccInit = getRectangleInitCoordinates(obj)
            xLim = obj.currentXLim;
            yLim = obj.currentYLim;

            if isequal(xLim, [1,inf]) && isequal(yLim, [1,inf])
                rccInit = [];
            elseif isempty(xLim) && isempty(yLim)
                rccInit = [];
            else
                rccInit = zeros(1,4);
                rccInit([1,3]) = [xLim(1), xLim(2)-xLim(1)];
                rccInit([2,4]) = [yLim(1), yLim(2)-yLim(1)];
            end
        end
        
        function updateRectangleContextMenu(obj, hRect)
            
            hCMenu = hRect.ContextMenu;
            delete(hCMenu.Children(1))
            
            hMenuItem = uimenu(hCMenu, 'Text', 'Reset Crop');
            hMenuItem.Callback = @obj.resetCrop;

        end
        
        function updateLimits(obj, rcc)
            obj.currentXLim = [rcc(1), rcc(1) + rcc(3) - 1];
            obj.currentYLim = [rcc(2), rcc(2) + rcc(4) - 1];
        end
        
        function onRectangleSizeChanged(obj, src, evt)
            
            if isempty(obj.hRectangleSizeText)
                obj.hRectangleSizeText = text(obj.hAxes);
                obj.hRectangleSizeText.Color = ones(1,3)*0.8;
            end
            
            size = round( evt.CurrentPosition(3:4) );
            
            x = sum(evt.CurrentPosition([1,3]));
            y = sum(evt.CurrentPosition([2,4]));
           
            obj.hRectangleSizeText.Position(1:2) = [x,y] + 5;
            obj.hRectangleSizeText.String = sprintf('(%d, %d)', size(1), size(2));
        end
        
        function resetCrop(obj, src, evt)
            
            rcc = zeros(1,4);
            rcc(1:2) = 1;
            rcc(3:4) = floor([obj.xLimOrig(2), obj.yLimOrig(2)]);
            obj.hImrect.Position = rcc;
            drawnow
            obj.deactivate()
        end
        
    end
    
    
end