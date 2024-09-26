classdef FrameMarker < uim.mixin.assignProperties

    % Todo
    % [ ] Create Interactive frame marker
    % [ ] Property to control axis , i.e x or y
    % [ ]

    properties
        Value = 1
        Minimum
        Maximum
        ValueChangedFcn
    end

    properties % Appearance
        Color
        EdgeColor
        LineWidth = 1;
        MarkerSize = 10; % In length direction (pixel units)
        MarkerSymbol = 'v'
    end

    properties (Access = public)
        Visible matlab.lang.OnOffSwitchState = 'on'
    end

    properties (Access = private)
        ParentFigure
        Axes
        LineHandle
        TopButtonHandle
        BottomButtonHandle
    end

    properties (Access = private)
        IsButtonDown = false
        IsMouseOnButton = false
        IsConstructed = false
        WindowMouseMotionListener
        WindowMouseReleaseListener
    end

    properties (Access = private)
        YMin = 0
        YMax = 1
    end

    methods
        function obj = FrameMarker(hAxes, varargin)
            obj.Axes = hAxes;
            obj.ParentFigure = ancestor(hAxes, 'figure');
            obj.parseInputs(varargin{:})
            obj.drawFrameMarker()
            obj.IsConstructed = true;
        end
    end

    methods % Set/get
        function set.Value(obj, newValue)
            obj.Value = newValue;
            obj.updateFrameMarker()
        end
    end

    methods (Access = private)

        function drawFrameMarker(obj)
            
            obj.LineHandle = plot(obj.Axes, [1, 1], [0, 1], '-', 'HitTest', 'off');
            
            obj.TopButtonHandle = plot(obj.Axes, 1, 1, 'v', ...
                'HitTest', 'on', 'MarkerSize', 10);
            obj.TopButtonHandle.ButtonDownFcn = @obj.knobPressed;

            obj.BottomButtonHandle = plot(obj.Axes, 1, 0, '^', ...
                'HitTest', 'on', 'MarkerSize', 10);
            obj.BottomButtonHandle.ButtonDownFcn = @obj.knobPressed;

            allHandles = [obj.LineHandle, obj.TopButtonHandle, obj.BottomButtonHandle];
            %obj.hlineCurrentFrame(2).LineStyle = '-';
            %obj.hlineCurrentFrame(2).MarkerEdgeColor = [0.2,0.2,0.2];

            set(allHandles, 'Color', ones(1,3) * 0.4, 'MarkerFaceColor', ones(1,3) * 0.4);
            set(allHandles, 'Tag', 'FrameMarker');
            set(allHandles(1), 'Color', [ones(1,3)*0.4, 0.6])
            set(allHandles, 'HandleVisibility', 'off')

            obj.setPointerBehavior(obj.TopButtonHandle)
            obj.setPointerBehavior(obj.BottomButtonHandle)
        end

        function setPointerBehavior(obj, h)
        %setPointerBehavior Set pointer behavior of buttons.

            pointerBehavior.enterFcn    = @(s,e,hObj)obj.onMouseEnterSlider(h);
            pointerBehavior.exitFcn     = @(s,e,hObj)obj.onMouseExitSlider(h);
            pointerBehavior.traverseFcn = [];%@obj.moving;
            
            iptSetPointerBehavior(h, pointerBehavior);
            iptPointerManager(ancestor(h, 'figure'));
        end

        function updateFrameMarker(obj, flag)
        % Update line indicating current frame in plot.
        
            if ~obj.IsConstructed; return; end
            
            xValue = obj.Value;

                %yLim = obj.ax.YAxis(1).Limits;
                        
            allHandles = [obj.LineHandle, obj.TopButtonHandle, obj.BottomButtonHandle];

            yData = {[0,1], 1, 0};
            xData = {[xValue, xValue], xValue, xValue};
            set(allHandles, {'XData'}, xData', {'YData'}, yData')
            set(allHandles, 'LineWidth', 1)
        end

        function resetWindowMouseListeners(obj)
            
            if isvalid(obj) && ~isempty(obj.WindowMouseMotionListener)
                delete(obj.WindowMouseMotionListener)
                obj.WindowMouseMotionListener = [];
            end

            if isvalid(obj) && ~isempty(obj.WindowMouseReleaseListener)
                delete(obj.WindowMouseReleaseListener)
                obj.WindowMouseReleaseListener = [];
            end
        end
    end

    methods

        function onMouseEnterSlider(obj, h, varargin)
        %onMouseEntered Callback for mouse entering button
            if isa(h, 'matlab.graphics.primitive.Patch')
                h.FaceColor = ones(1,3) * 0.8;
            elseif isa(h, 'matlab.graphics.chart.primitive.Line')
                h.MarkerFaceColor = ones(1,3) * 0.5;
                h.MarkerSize = 12;
            end
            
            obj.IsMouseOnButton = true;
            obj.ParentFigure.Pointer = 'hand';
            drawnow
        end
        
        function onMouseExitSlider(obj, h, varargin)
        %onMouseEntered Callback for mouse leaving button
            if isa(h, 'matlab.graphics.primitive.Patch')
                h.FaceColor = ones(1,3) * 0.6;
            elseif isa(h, 'matlab.graphics.chart.primitive.Line')
                if ~obj.IsButtonDown
                    h.MarkerFaceColor = ones(1,3) * 0.4;
                    h.MarkerSize = 10;
                end
            end
            
            obj.IsMouseOnButton = false;
            if ~obj.IsButtonDown
                obj.ParentFigure.Pointer = 'arrow';
            end
        end
        
        % % % Callbacks for the scroller knob

        function knobPressed(obj, src, event)
            
            el = listener(obj.ParentFigure, 'WindowMouseMotion', @obj.knobMoving);
            obj.WindowMouseMotionListener = el;
            
            el = listener(obj.ParentFigure, 'WindowMouseRelease', @obj.knobReleased);
            obj.WindowMouseReleaseListener = el;
            
            obj.IsButtonDown = true;
            
        end
        
        function knobMoving(obj, src, event)
           
            if obj.IsButtonDown % Just in case???
                mousePoint = obj.Axes.CurrentPoint(1);
                xPoint = mousePoint(1);

                %newValue = round( obj.getSliderValue(xPoint) );
                newValue = xPoint;

                if newValue < obj.Minimum; newValue = obj.Minimum; end
                if newValue > obj.Maximum; newValue = obj.Maximum; end
                
                % Call guis changeFrame methods
                % is it better with event notification?
                
                oldValue = obj.Value;
                obj.Value = newValue;
                obj.updateFrameMarker()

                if ~isempty(obj.ValueChangedFcn)
                    evtData = uim.event.ValueChangedEventData(oldValue, newValue);
                    obj.ValueChangedFcn(obj, evtData)
                end
            end
        end
        
        function knobReleased(obj, src, event)
            
            obj.IsButtonDown = false;
            
            obj.resetWindowMouseListeners()
                    
            obj.TopButtonHandle.MarkerFaceColor = ones(1,3) * 0.4;
            obj.TopButtonHandle.MarkerSize = 10;

            if ~obj.IsMouseOnButton
                obj.ParentFigure.Pointer = 'arrow';
            end
        end
    end
end
