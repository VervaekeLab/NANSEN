classdef gobjectTransporter < uim.handle
    
    % TODO: 
    %
    % [ ] Rename to InteractiveGraphObject 
    % [ ] Work on style changes. Keep original style in objects userdata
    % [ ] Style changes for different object, i.e patch, line, image etc.
    
    properties
        MouseOverEffect matlab.lang.OnOffSwitchState = 'on'
        TransportFcn = []
        StopDragFcn = []
    end
    
    properties (Access = protected)
        hFigure
        hAxes
        
        isMouseDown
        
        mouseOnHandle = gobjects(0)
        
        currentHandle
        previousMousePointAxes
        WindowMouseMotionListener
        WindowMouseReleaseListener
    end

    methods
        function obj = gobjectTransporter(hAxes)
            obj.hFigure = ancestor(hAxes, 'figure');
            obj.hAxes = hAxes;

            if isempty(obj.hFigure.WindowButtonMotionFcn)
                obj.hFigure.WindowButtonMotionFcn = @(s,e,x) isempty([]);
            end
        end
        
        function delete(obj)
            if ~isempty(obj.WindowMouseMotionListener)
                obj.resetInteractiveFigureListeners()
            end
            
            delete(obj)
        end

        function startDrag(obj, src, event)

            % NB: Call this before assigning moveObject callback. Update
            % coordinates callback is activated in the moveObject
            % function..
            obj.isMouseDown = true;

            obj.currentHandle = src;

            el(1) = listener(obj.hFigure, 'WindowMouseMotion', @(src, event) obj.moveObject);
            el(2) = listener(obj.hFigure, 'WindowMouseRelease', @(src, event) obj.stopDrag);
            obj.WindowMouseMotionListener = el(1);
            obj.WindowMouseReleaseListener = el(2);

            x = event.IntersectionPoint(1);
            y = event.IntersectionPoint(2);
            obj.previousMousePointAxes = [x, y];
            
            obj.currentHandle.FaceAlpha = 0.6;
        end

        function moveObject(obj)
        %moveObject Execute when mouse is dragging a selected object    

            % Get current coordinates
            newMousePointAx = obj.hAxes.CurrentPoint(1, 1:2);            
            shift = newMousePointAx - obj.previousMousePointAxes;

            h = obj.currentHandle;

            if ~isempty(obj.TransportFcn)
                obj.TransportFcn(h, shift)

            else
                % Selected object. Force move if shift-click
                switch class(h)
                    case 'matlab.graphics.primitive.Text'
                        h.Position(1:2) = h.Position(1:2) + shift;

                    case {'matlab.graphics.chart.primitive.Line', ...
                            'matlab.graphics.primitive.Patch'}

                        h.XData = h.XData + shift(1);
                        h.YData = h.YData + shift(2);
                end
            end

            obj.previousMousePointAxes = newMousePointAx;
        end

        function stopDrag(obj)
        %stopDrag Execute when mouse is released from a selected object

            obj.isMouseDown = false;
            obj.resetInteractiveFigureListeners()
            
            
            if ~any(ismember(obj.mouseOnHandle, obj.currentHandle))
                obj.currentHandle.LineWidth = 1;
                hFig = obj.hFigure;
                hFig.Pointer = 'arrow';
            end

            if ~isempty(obj.StopDragFcn)
                obj.StopDragFcn()
            end
            
            obj.currentHandle.FaceAlpha = 0.4;
            obj.currentHandle = [];
        end

        function resetInteractiveFigureListeners(obj)

            delete(obj.WindowMouseMotionListener)
            delete(obj.WindowMouseReleaseListener)
            obj.WindowMouseMotionListener = [];
            obj.WindowMouseReleaseListener = [];
        end

        function setPointerBehavior(obj, h)
        %setPointerBehavior Set pointer behavior of background.

            pointerBehavior.enterFcn    = @(s,e,hObject) obj.onMouseEnteredMarker(h);
            pointerBehavior.exitFcn     = @(s,e,hObject) obj.onMouseExitedMarker(h);
            pointerBehavior.traverseFcn = [];%@obj.moving;
            
            try % Use try/catch because this reqiures image processing toolbox.
                iptPointerManager(ancestor(h, 'figure'));
                iptSetPointerBehavior(h, pointerBehavior);
            catch
                disp('failed to set pointerbehavior')
            end
        end
        
        function onMouseEnteredMarker(obj, hSource)
            
            if ~isvalid(obj); return; end
            
            obj.mouseOnHandle(end+1) = hSource;
            
            hFig = obj.hFigure;
            hFig.Pointer = 'hand';
            
            hSource.LineWidth=2;
        end

        function onMouseExitedMarker(obj, hSource)
            
            % Need this here in case the obj was deleted while the pointer
            % was still on it.
            if ~isvalid(obj); return; end
            
            hFig = obj.hFigure;
            
            if ~obj.isMouseDown
                hFig.Pointer = 'arrow';
                hSource.LineWidth=1;
            end
            
            throw = ismember(obj.mouseOnHandle, hSource);
            obj.mouseOnHandle(throw) = [];
        end
    end
end
        