classdef autoDetect < uim.interface.abstractPointer
    
    % TODO: Fix so that crosshairs are plotted based on the maximum
    % size/limits of the parent axes.
    
    properties (Constant)
        exitMode = 'default';
    end
    
    
    properties 
        xLimOrig
        yLimOrig
        
        hObjectMap
        hImageStack
        hImage
        
        defaultRadius = 6       % I.e footprint for detection.
        extendedRadius = 6 + 5 % todo: make this part of settings.
        mode = 1
    end
    
    
    properties (Access = private) % Properties related to displaying circle during creation
        circleToolCoords
        hCircle
        hCircleExtended
        hCrosshair % Line handle for temporary lines of roi circle
        timerFcn = []
        scrollerTimerFcn = []
        isAltDown = false
        isControlDown = false
        keyReleaseListener
        scrollListener
        hTempRoi
        
    end
    
    
    methods
               
        function obj = autoDetect(hAxes)
            obj.hAxes = hAxes;
            obj.hFigure = ancestor(hAxes, 'figure');
                       
            obj.xLimOrig = obj.hAxes.XLim;
            obj.yLimOrig = obj.hAxes.YLim;
            
            obj.hImage = findobj(obj.hAxes, 'type', 'image');

        end
        
        
        function activate(obj)
            activate@uim.interface.abstractPointer(obj)
            showCircle(obj)
            hideCircle(obj)
            obj.plotCrosshair()
            set(obj.hCrosshair, 'Visible', 'on')
            set(obj.hCrosshair(1:2), 'Visible', 'on')
            set(obj.hTempRoi, 'Visible', 'on')
            obj.updateRoi()
            obj.keyReleaseListener = listener(obj.hFigure, 'WindowKeyRelease', @obj.onKeyRelease);
            obj.scrollListener = listener(obj.hFigure, 'WindowScrollWheel', @obj.onMouseScroll);
            obj.isActive = true;
            
            if obj.mode == 4            
                obj.hCircleExtended.Visible = 'on';
            end
        end
        
        
        function deactivate(obj)
            deactivate@uim.interface.abstractPointer(obj)
            hideCircle(obj)
            obj.hCircleExtended.Visible = 'off';
            set(obj.hCrosshair, 'Visible', 'off')
            set(obj.hTempRoi, 'Visible', 'off')
            delete(obj.keyReleaseListener)
            delete(obj.scrollListener)
            obj.isActive = false;
        end

        
        function suspend(obj)
            suspend@uim.interface.abstractPointer(obj)
            hideCircle(obj)
            set(obj.hCrosshair, 'Visible', 'off')
        end
        
        
        function setPointerSymbol(obj)
            %obj.hFigure.Pointer = 'cross';
            switch obj.mode
                case 1
                    pdata = NaN(16,16);
                    pdata(7:10, 7:10) = 2;
                    pdata(8:9, 8:9) = 1;
                case {2, 3, 4}
                    pdata = NaN(16,16);
                    pdata(6:11, 8:9) = 2;
                    pdata(8:9, 6:11) = 2;
                    isWhite = imdilate(pdata==2, ones(3,3)) & ~(pdata==2);
                    pdata(isWhite)=1;
            end
            
            obj.hFigure.Pointer = 'custom';
            obj.hFigure.PointerShapeCData = pdata;
            obj.hFigure.PointerShapeHotSpot = [8,8];
            
        end
        
        
        function onButtonDown(obj, src, evt)
            
            %obj.isActive = true;
            
            if strcmp(obj.hFigure.SelectionType, 'alt')
                return
            end
            

            currentPoint = obj.hAxes.CurrentPoint(1, 1:2);
            
            x = currentPoint(1);
            y = currentPoint(2);
            r = obj.circleToolCoords(3);
            r(2) = obj.extendedRadius;

            % Todo: Call a buttonDownFcn instead. 
            isRoiSelected = obj.hObjectMap.hittest(src, evt);
            obj.hObjectMap.autodetectRoi(x, y, r, obj.mode, isRoiSelected);

        end
        
        
        function onButtonMotion(obj, src, evt)
           
            if ~obj.isPointerInsideAxes; return; end
            if ~obj.isActive; return; end
            

            currentPoint = obj.hAxes.CurrentPoint(1, 1:2);
            
            % Todo: Call a mouseMotionFcn instead. instead. 
            if ~isempty(obj.hTempRoi) && strcmp(obj.hTempRoi.Visible, 'on')
            	obj.updateRoi(currentPoint)
            end
            
            tmpCoords = [currentPoint, obj.circleToolCoords(3)];
            
            obj.plotCircleTool(tmpCoords);
            obj.plotCrosshair(tmpCoords(1:2))
        end
        
        
        function onButtonUp(obj, src, event)
            %obj.isActive = false;
        end
        
        
        function onMouseScroll(obj, src, event)
            if obj.mode == 4 && obj.isAltDown && obj.isControlDown
                n = event.VerticalScrollCount;
                obj.changeExtendedCircleRadius(n*0.1)
                obj.updateRoi()
                
            elseif obj.isAltDown
                n = event.VerticalScrollCount;
                obj.changeCircleRadius(n*0.1)
                obj.updateRoi()

            else
                if isempty(obj.scrollerTimerFcn)
                    obj.deactivateWhenScrolling()
                else
                    stop(obj.scrollerTimerFcn)
                    delete(obj.scrollerTimerFcn)
                    obj.deactivateWhenScrolling()
                end
            end
        end
        
        
        function wasCaptured = onKeyPress(obj, src, event)
            wasCaptured = true;
            
            switch event.Key
                
                case 'leftbracket' % probe
                    if isempty(obj.hTempRoi)
                        obj.updateRoi()
                    elseif ~isempty(obj.hTempRoi) && strcmp(obj.hTempRoi.Visible, 'on')
                        obj.hTempRoi.Visible = 'off';
                    elseif ~isempty(obj.hTempRoi) && strcmp(obj.hTempRoi.Visible, 'off')
                        obj.updateRoi()
                    end
                    
                case {'1', '2', '3', '4'}
                    obj.mode = str2double(event.Key);
                    obj.setPointerSymbol()
                    if obj.mode == 4
                        set(obj.hCircleExtended, 'Visible', 'on')
                    else
                        set(obj.hCircleExtended, 'Visible', 'off')
                    end

                case 'c'
                    if ~isempty(obj.hCircle) && strcmp(obj.hCircle.Visible, 'off')
                        showCircle(obj)
                    elseif ~isempty(obj.hCircle) && strcmp(obj.hCircle.Visible, 'on')
                        hideCircle(obj)
                    end

                
                case {'g', 'h'}
                    if ~isempty(obj.hCircle) && strcmp(obj.hCircle.Visible, 'off')
                        obj.showCircle()
                        obj.hideCircleIn(2, true)
                    else
                        if ~isempty(obj.timerFcn)
                            stop(obj.timerFcn)
                            delete(obj.timerFcn)
                            obj.hideCircleIn(2, true)
                        end
                    end
                    
                    if contains('shift', event.Modifier)
                        deltaR = 1;
                    else
                        deltaR = 0.5;
                    end
                    
                    if isequal(event.Key, 'h')
                        deltaR = -1*deltaR;
                    end
                    
                    changeCircleRadius(obj, deltaR)
                    obj.updateRoi()

                    
                case 'alt'
                    obj.isAltDown = true;
                    wasCaptured = false; % Should not be captured!

                case 'control'    
                    obj.isControlDown = true;

                otherwise
                    wasCaptured = false;
            end
        end
        
        
        function onKeyRelease(obj, src, event)
            switch event.Key
                case 'alt'
                    obj.isAltDown = false;
                case 'control'    
                    obj.isControlDown = false;
            end
        end
        
        
        function updateRoi(obj, currentPoint)
            
            if nargin < 2
                currentPoint = obj.hAxes.CurrentPoint(1, 1:2);
            end
            
            if ~obj.isPointerInsideAxes(currentPoint); return; end
            
            
            x = currentPoint(1);
            y = currentPoint(2);
            r = obj.circleToolCoords(3);
            
            r(2) = obj.extendedRadius;
            
            newRoi = obj.hObjectMap.autodetectRoi(x, y, r, obj.mode, false);
            
            obj.plotTempRoi(newRoi)
        end
        
    end
    
    methods
        
        function showCircle(obj)
            if isempty(obj.hCircle)
                obj.plotCircleTool()
            end
            obj.hCircle.Visible = 'on';
        end
        
        
        function hideCircle(obj, doFade)
            
            if nargin < 2; doFade = false; end
            
            if doFade
                alphaLevels = fliplr(linspace(0, 0.15, 20));
                for i = 1:20
                    obj.hCircle.FaceAlpha = alphaLevels(i);
                    pause(0.03)
                end
            end
            
            obj.hCircle.Visible = 'off';
            obj.hCircle.FaceAlpha = 0.15;
            
        end
        
        
        function changeCircleRadius(obj, deltaR)
            tmpCoords = obj.circleToolCoords;
            tmpCoords(3) = tmpCoords(3) + deltaR;
            obj.plotCircleTool(tmpCoords)
            obj.plotCrosshair()
        end
        
        function changeExtendedCircleRadius(obj, deltaR)
            obj.extendedRadius = obj.extendedRadius + deltaR;
            obj.plotCircleTool(obj.circleToolCoords)
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
                obj.hCircle = patch(obj.hAxes, xData, yData, 'w');
                obj.hCircle.FaceAlpha = 0.2;
                obj.hCircle.PickableParts = 'none';
                obj.hCircle.HitTest = 'off';
            else
                set(obj.hCircle, 'XData', xData, 'YData', yData)
            end
            
            % Plot line for extended circle. Added later, hence the
            % patchwork.
            xData = (r+obj.extendedRadius) * cos(th) + x;
            yData = (r+obj.extendedRadius) * sin(th) + y;
            if isempty(obj.hCircleExtended)
                obj.hCircleExtended = patch(obj.hAxes, xData, yData, 'w', 'LineStyle', '--');
                obj.hCircleExtended.FaceAlpha = 0.1;
                obj.hCircleExtended.PickableParts = 'none';
                obj.hCircleExtended.HitTest = 'off';
                obj.hCircleExtended.Visible = 'off';
            else
                set(obj.hCircleExtended, 'XData', xData, 'YData', yData)
            end
            
            
            
        end
        
        
        function plotCrosshair(obj, center)
%             drawnow limitrate
%             drawnow
            
            hAx = obj.hAxes;
            
            
            % Todo: Have these sizes as internal property?
% %             axLimOrig = [1,obj.hObjectMap.displayApp.imWidth; ...
% %                 1,obj.hObjectMap.displayApp.imHeight];
% %             ps = 10 / axLimOrig(2a) * range(hAx.XLim); 
            
            
            %imSize = size(obj.hImage.CData);
            axLimOrig = [obj.xLimOrig; obj.yLimOrig];
            
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
            ps = obj.circleToolCoords(3);
            
            
            xdata1 = [0, x0-ps, nan, x0+ps, axLimOrig(1,2)];
            ydata1 = ones(size(xdata1))*y0;
            
            ydata2 = [0, y0-ps, nan, y0+ps, axLimOrig(2,2)];
            xdata2 = ones(size(ydata2))*x0;
            
            
            % Plot Line
            if isempty(obj.hCrosshair)
                obj.hCrosshair = gobjects(4,1);
                obj.hCrosshair(1) = plot(hAx, xdata1, ydata1);
                obj.hCrosshair(2) = plot(hAx, xdata2, ydata2);
                obj.hCrosshair(3) = plot(hAx, xdata1, ydata1);
                obj.hCrosshair(4) = plot(hAx, xdata2, ydata2);
                set( obj.hCrosshair(1:2), 'Color', [0.5,0.5,0.5])
                set( obj.hCrosshair(1:2), 'LineWidth', 2)
                set( obj.hCrosshair(3:4), 'Color', [0,0,0])
                set( obj.hCrosshair(3:4), 'LineWidth', 1)
            else
                
                set(obj.hCrosshair, {'XData'}, {xdata1,xdata2,xdata1,xdata2}', ...
                                    {'YData'}, {ydata1,ydata2,ydata1,ydata2}' )

            end
            
            
        end
        
        
        function plotTempRoi(obj, hRoi)
            
            if isempty(hRoi)
                B = {[nan, nan]};
            else
                %B = bwboundaries(hRoi);
                B = hRoi.Boundary{1};
            end
            
% %             % Standardize output B, so that boundary property is a cell of two
% %             % column vectors, where the first is y-coordinates and the seconds
% %             % is x-coordinates. Should ideally be an nx2 matrix of x and y.
% %             if numel(B) > 1
% %                 B = cellfun(@(b) vertcat(b, nan(1,2)), B, 'uni', 0);
% %                 B = vertcat(B{:});
% %                 B(end, :) = []; % Just remove the last nans...
% %             elseif isempty(B)
% %                 B = [nan, nan];
% %             else
% %                 B = B{1};
% %             end
            
            X = B(:, 2);
            Y = B(:, 1);
            
            if isempty(obj.hTempRoi)
                obj.hTempRoi = patch(obj.hAxes, X, Y, 'w');
                obj.hTempRoi.PickableParts = 'none';
                obj.hTempRoi.HitTest = 'off';
                obj.hTempRoi.FaceAlpha = 0.15;
            else
                set(obj.hTempRoi, 'XData', X, 'YData', Y)
                obj.hTempRoi.FaceAlpha = 0.15;
            end
            obj.hTempRoi.Visible = 'on';
        end
        
        
        function deactivateWhenScrolling(obj)
            t = timer('ExecutionMode', 'singleShot', 'StartDelay', 0.3);
            t.TimerFcn = @(myTimerObj, thisEvent, tf) obj.reactivateAfterScrolling(t);
            start(t)
            obj.isActive = false;
            obj.scrollerTimerFcn = t;
        end
        
        
        function reactivateAfterScrolling(obj, t)
            % Return if gui has been deleted
            if ~isvalid(obj); return; end
            
            if nargin >=2 && ~isempty(t) && isvalid(t)
                stop(t)
                delete(t)
                obj.scrollerTimerFcn = [];
            end
            obj.isActive = true;
        end
        
        
        function hideCircleIn(obj, n, doFade)
            if nargin < 2; doFade = false; end
            t = timer('ExecutionMode', 'singleShot', 'StartDelay', n);
            t.TimerFcn = @(myTimerObj, thisEvent, tf) obj.hideCircleByTimer(t, doFade);
            start(t)
            obj.timerFcn = t;
        end
        
        
        function hideCircleByTimer(obj, t, doFade)
            
            % Return if gui has been deleted
            if ~isvalid(obj); return; end
            
            if nargin >=2 && ~isempty(t) && isvalid(t)
                stop(t)
                delete(t)
                obj.timerFcn = [];
            end
            
            obj.hideCircle(doFade)
            
        end
        
        
    end
    
    
    
end