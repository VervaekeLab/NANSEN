classdef PlaneSwitcher < uim.mixin.assignProperties
    
    properties (Dependent)
        Position (1,4) double
    end
    
    properties (Access = public)
        Visible matlab.lang.OnOffSwitchState = 'on'
        NumPlanes = 1
        CurrentPlane = 1
    end
    
    properties % Appearance
        BackgroundColor = [0.94, 0.94, 0.94];
        ForegroundColor = ones(1,3) * 0.6
        PlaneSwitcherToggleButtonSize = 12;
        
        Callback = []
    end
    
    properties (Access = protected)
        
        ParentApp
        hFigure % Window which figure is located in. % Make dependent...
        hAxes
        
        isAxesInternal
        
        hPlaneSwitcherToggleButton = gobjects(0);
        hPlaneSwitcherSlidebar = gobjects(0);

    end
    
    properties (Access = private) % Widget states and internals
        IsConstructed = false
        isMouseOnButton = false
        isMouseButtonPressed = false
        
        Position_ = [1, 1, 20, 20]; %Initial position
        
        WindowMouseMotionListener
        WindowMouseReleaseListener
        FrameChangedListener
    end
    
    methods % Structor
        
        function obj = PlaneSwitcher(parentGui, hParent, varargin)
                        
            obj.ParentApp = parentGui;
            obj.hFigure = obj.ParentApp.Figure;
            
            obj.resolveParent(hParent)
            
            obj.parseInputs(varargin{:})
            
            obj.IsConstructed = true;
            
            obj.createWidgetComponents()

        end
        
        function delete(obj)
            delete(obj.hPlaneSwitcherToggleButton)
            delete(obj.hPlaneSwitcherSlidebar)
        end
    end
    
    methods % Set/Get
        
        function set.Position(obj, newPos)
            
            assert(isnumeric(newPos) && numel(newPos) == 4, 'Value must be a 4 element vector')
            assert(all(newPos(3:4) > 1), 'This widget does not support normalized position units')
            obj.Position_ = newPos;
        end
        
        function set.Position_(obj, newPosition)
            
            % Check if it was size and/or location that changed.
            isSizeChanged = any(newPosition(3:4) ~= obj.Position_(3:4));
            isLocationChanged = any(newPosition(1:2) ~= obj.Position_(1:2));
                        
            obj.Position_ = newPosition;
            
            % Update size first
            if isSizeChanged
                obj.onSizeChanged()
            end
            
            % Update location second
            if isLocationChanged
                obj.onLocationChanged()
            end
        end

        function pos = get.Position(obj)
            pos = obj.Position_;
        end
        
        function set.Visible(obj, newValue)
            obj.Visible = newValue;
            obj.onVisibleChanged()
        end
        
        function set.NumPlanes(obj, newValue)
            obj.NumPlanes = newValue;
            obj.onNumPlanesChanged()
        end
        
        function set.CurrentPlane(obj, newValue)
            obj.CurrentPlane = newValue;
            obj.onCurrentPlaneChanged()
        end
    end
    
    methods (Access = protected) % Widget creation & updates
        function resolveParent(obj, hParent)
            
            if isa(hParent, 'matlab.graphics.axis.Axes')
                obj.hAxes = hParent;
                obj.isAxesInternal = false;
            else
                obj.createAxes()
                obj.isAxesInternal = true;
            end
        end
        
        function createAxes(obj, hParent)
            obj.hAxes = uim.UIComponentCanvas.createComponentAxes(hParent);
        end
    
        function createWidgetComponents(obj)
           
            obj.drawPlaneSwitcherToggleButton()
            obj.drawPlaneSwitcherSlidebar()
            
        end
        
        function drawPlaneSwitcherToggleButton(obj)
            
            X = obj.Position(1) + obj.Position(3)/2;
            Y = 0;
            
            % Create button or update position.
            if isempty(obj.hPlaneSwitcherToggleButton)
                h = text(obj.hAxes, X, Y, 'Z');
                h.HorizontalAlignment = 'right';
                h.VerticalAlignment = 'middle';
                h.FontSize = 14;
                h.FontWeight = 'bold';
                h.Color = obj.ForegroundColor;
                h.Tag = 'PlaneSwitcherToggleButton';
                h.ButtonDownFcn = @(s, e) obj.onPlaneSwitcherToggleButtonPushed;

                obj.setPointerBehavior(h)

                obj.hPlaneSwitcherToggleButton = h;
                
            else
                obj.hPlaneSwitcherToggleButton.Position(1:2) = [X,Y];
            end
        end
        
        function drawPlaneSwitcherSlidebar(obj)
                        
            args = {'Min', 1, 'Max', obj.NumPlanes, 'nTicks', ...
                obj.NumPlanes-1};
            
            hSlider = uim.widget.slidebar('Parent', obj.ParentApp.Axes.Parent, ...
                    'Position', [0, obj.Position(4)+10, 100, 10], 'Orientation', 'vertical', ...
                    'Units', 'pixel', args{:}, 'Value', obj.CurrentPlane, ...
                    'TextColor', obj.ForegroundColor, 'Padding', [0,9,3,9], ...
                    'Callback', @obj.onPlaneSliderValueChanged, ...
                    'BarColor', ones(1,3)*0.45, 'TickLength', 0, ...
                    'TooltipExpression', 'Z = %d');
            
            obj.hPlaneSwitcherSlidebar = hSlider;
            obj.hPlaneSwitcherSlidebar.Visible = 'off';
            % Todo
        end
    end
    
    methods (Access = private) % User interaction callbacks
        
        function onPlaneSliderValueChanged(obj, src, evt)
            
            newPlaneIdx = src.Value;
            obj.Callback(newPlaneIdx)
            
        end
        
        function onPlaneSwitcherToggleButtonPushed(obj)
            
            % Todo: Toggle rangebar visibility
            if isempty(obj.hPlaneSwitcherSlidebar)
                obj.drawPlaneSwitcherSlidebar()
                return
            end
            
            if numel(obj.CurrentPlane) > 1
                return
            end
                
            if strcmp(obj.hPlaneSwitcherSlidebar.Visible, 'on')
                obj.hPlaneSwitcherSlidebar.Visible = 'off';
            else
                obj.hPlaneSwitcherSlidebar.Visible = 'on';
            end
        end
    end
    
    methods (Access = private) % Property set callbacks
        
        function onVisibleChanged(obj)
            
            if ~obj.IsConstructed; return; end
            
            %obj.hAxes.Visible = obj.Visible;
            
            if obj.Visible
            else
            end
        end

        function onLocationChanged(obj)
            if ~obj.IsConstructed; return; end
            
        end
        
        function onSizeChanged(obj)
            
            if ~obj.IsConstructed; return; end
            
            if obj.isAxesInternal
                obj.hAxes.Position(3:4) = obj.Position_(3:4);
            
                axWidth = obj.hAxes.Position(3);
                axHeight = obj.hAxes.Position(4);

                newYLim = [-1, 1] .* (axHeight/2);
                if ~all( newYLim == obj.hAxes.YLim  )
                    obj.hAxes.YLim = newYLim;
                end

                newXLim = [1, axWidth];
                if ~all( newXLim == obj.hAxes.XLim )
                    obj.hAxes.XLim = newXLim;
                end
            else
                % Do nothing...
            end
        end
        
        function onNumPlanesChanged(obj)
            % Todo: Update sliderbar max value
        end
        
        function onCurrentPlaneChanged(obj)
            % Todo: update slidebar value
            if numel(obj.CurrentPlane) > 1
                return
            else
                obj.hPlaneSwitcherSlidebar.Value = obj.CurrentPlane;
            end
        end
    end
    
    methods (Access = private)
        
        % % % Callbacks for mouseover effects
    
        function setPointerBehavior(obj, h)
        %setPointerBehavior Set pointer behavior of buttons.

            pointerBehavior.enterFcn    = @(s,e,hObj)obj.onMouseEntered(h);
            pointerBehavior.exitFcn     = @(s,e,hObj)obj.onMouseExited(h);
            pointerBehavior.traverseFcn = [];%@obj.moving;
            
            iptSetPointerBehavior(h, pointerBehavior);
            iptPointerManager(ancestor(h, 'figure'));

        end
        
        function onMouseEntered(obj, h, varargin)
        %onMouseEntered Callback for mouse entering button
        
            obj.isMouseOnButton = true;

            if isa(h, 'matlab.graphics.primitive.Text')
                obj.changeButtonAppearance()
            end
            
            obj.hFigure.Pointer = 'hand';
        end
        
        function onMouseExited(obj, h, varargin)
        %onMouseEntered Callback for mouse leaving button
        
            obj.isMouseOnButton = false;

            if isa(h, 'matlab.graphics.primitive.Text')
                obj.changeButtonAppearance()
            end
            
            if ~obj.isMouseButtonPressed
                obj.hFigure.Pointer = 'arrow';
            end
        end
        
        function changeButtonAppearance(obj)
            
            if obj.isMouseOnButton          % Mouse on
                onColor = min( [obj.ForegroundColor+0.15; [1,1,1]] );
                obj.hPlaneSwitcherToggleButton.Color = onColor;
            else                                        % Mouse off
                offColor = obj.ForegroundColor;
                obj.hPlaneSwitcherToggleButton.Color = offColor;
            end
        end
    end
    
    % onNumPlanesChanged
    
    % onPlaneSwitcherToggleButtonPushed
end
