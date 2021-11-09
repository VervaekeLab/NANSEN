classdef rangeslider < uim.abstract.virtualContainer & uim.mixin.assignProperties
    
    % todo: add orientation vertical
    
    properties (Dependent)
        Min = 0                 % Minimum slider value
        Max = 1                 % Maximum slider value
        Low = 0
        High = 1
    end
    
    properties
        NumTicks = 100
        
        TrackWidth = 2  % width of the slider track
        TrackColor = ones(1,3)*0.75;
        KnobSize = 15
        KnobMarkerStyle = 'round' % only round available shoud implement line/bar
               
        % Todo: move to uim.style definition....
        KnobEdgeColorInactive = ones(1,3)*0.7;
        KnobEdgeColorActive = [0.1195    0.6095    0.5395]; % ones(1,3)*0.3; %;
        KnobFaceColorInactive = ones(1,3)*0.8;
        KnobFaceColorActive = ones(1,3)*0.65;
           
        TickLength = 5
        
        TextColor = ones(1,3)*0.8;
        TextBackgroundColor = 'none';
        
        ShowLabel = true;

        Callback = []
        
    end
    
    properties (Access = private, Transient = true)
        StepSize
        Min_ = -inf
        Max_ = inf
        Low_ = -inf
        High_ = inf
    end
    
    properties (Access = private, Transient)

        hTrack
        hSliderKnob
        hText
        hTicks
        
        IsKnobPressed = false
        
        WindowButtonUpListener
        WindowMouseMotionListener
        
    end
    
    
    
    methods
        
        function obj = rangeslider(hParent, varargin)

            if isa(hParent, 'matlab.graphics.axis.Axes')
            
                
                obj.Parent = hParent;
                obj.Canvas = struct('Axes', hParent);
                obj.hAxes = hParent;
                
            else
                
                %obj@uim.abstract.virtualContainer(hParent)
                el = listener(hParent, 'SizeChanged', ...
                    @obj.onParentContainerSizeChanged);
                obj.ParentContainerSizeChangedListener = el;

                obj.Parent = hParent;
                obj.Canvas = hParent;
                obj.hAxes = obj.Canvas.Axes;
                
            end

            obj.parseInputs(varargin{:})
            obj.IsFixedSize = [1, 1]; % No floating!
            
            obj.createSlider()
            
            obj.IsConstructed = true;
            
            % Call updateSize to trigger size update (call before location)
            obj.updateSize('auto')
            
            % Call updateLocation to trigger location update
            obj.updateLocation('auto')
            
            obj.onVisibleChanged()

            
        end
        
        
        function delete(obj)
            delete(obj.hTrack)
            delete(obj.hSliderKnob)
            delete(obj.hText)
        end
        
    end
    
    
    methods (Access = private) % Component construction
        
        function createSlider(obj)
                       
            obj.createBackground()
            
            % Slider and especially the slider track is thin, and its easy
            % to miss when pressing it. Patch background so that
            % mousepresses are still captured by this widget on close miss.
            obj.hBackground.HitTest = 'on';
            obj.hBackground.PickableParts = 'all';

            obj.plotTrack()
            obj.plotKnobs()
            obj.plotText()
            %obj.plotTicks()
            
            % Set visibility of subcomponents.
            obj.hTrack.Visible = obj.Visible;
            set(obj.hSliderKnob, 'Visible', obj.Visible);
            
        end
        
        function plotTrack(obj)
                       
            % Plot the track as a line
            [xCoords, yCoords] = obj.getTrackCoordinates();
            
            if isempty(obj.hTrack)
                obj.hTrack = plot(obj.Canvas.Axes, xCoords, yCoords);

                obj.hTrack.LineWidth = obj.TrackWidth;
                obj.hTrack.HitTest = 'on';
                obj.hTrack.PickableParts = 'visible';
                obj.hTrack.Color = obj.TrackColor;
                obj.hTrack.Tag = 'Slider Track';
            
                obj.hBackground.ButtonDownFcn = @(src, event) obj.onSliderMoved(src);
                obj.hTrack.ButtonDownFcn = @(src, event) obj.onSliderMoved(src);
            else
                set(obj.hTrack, 'XData', xCoords, 'YData', yCoords)
            end
            
        end
        
        function plotTicks(obj)
           
            x1 = obj.Position(1)+obj.Padding(1);
            x2 = sum(obj.Position([1,3]))-obj.Padding(3);

            y1 = obj.Position(2) + obj.Padding(2);
            y2 = y1 + obj.TickLength;
            
            numTicks = 10;
            x = linspace(x1,x2,numTicks);
            x = repmat(x, 3, 1);
            x(3,:) = nan;
           
            y = repmat([y1;y2;nan], 1, numTicks);
            
            obj.hTicks = plot(obj.Canvas.Axes,x,y, obj.TrackColor);
            
        end
        
        function plotKnobs(obj)
            
            % Patch the slider knob using aspect ratio adjusted coords.
            [xCoordsLow, yCoordsLow] = obj.getKnobCoordinates('low');
            [xCoordsHigh, yCoordsHigh] = obj.getKnobCoordinates('high');
            
            if isempty(obj.hSliderKnob)
                h1 = patch(obj.Canvas.Axes, xCoordsLow, yCoordsLow, 'k');
                h2 = patch(obj.Canvas.Axes, xCoordsHigh, yCoordsHigh, 'k');
                
                h1.Tag = 'Range Slider Low';
                h2.Tag = 'Range Slider High';
                
                obj.hSliderKnob = [h1, h2];
                
                set(obj.hSliderKnob, 'LineWidth', 1)
                set(obj.hSliderKnob, 'Clipping', 'off')

                set(obj.hSliderKnob, 'FaceColor', obj.KnobFaceColorInactive)
                set(obj.hSliderKnob, 'EdgeColor', obj.KnobEdgeColorInactive)
                set(obj.hSliderKnob, 'ButtonDownFcn', @obj.onSliderKnobPressed);
                
                setPointerBehavior(obj, obj.hSliderKnob(1))
                setPointerBehavior(obj, obj.hSliderKnob(2))
                
            else
                set(obj.hSliderKnob(1), 'XData', xCoordsLow, 'YData', yCoordsLow)
                set(obj.hSliderKnob(2), 'XData', xCoordsHigh, 'YData', yCoordsHigh)
            end
        
        end
        
        function plotText(obj, whichSlider)
            % Create a text object for displaying the current value when
            % the slider is active.
            
            if nargin < 2; whichSlider = 'low'; end
            
            [xCoords, yCoords] = obj.getTextCoordinates(whichSlider);
            
            if isempty(obj.hText)
                obj.hText = text(obj.hAxes, xCoords, yCoords, '');
                obj.hText.VerticalAlignment = 'Bottom';
                obj.hText.HorizontalAlignment = 'left';
                obj.hText.Color = obj.TextColor;
                obj.hText.Visible = 'off';
            else
                obj.hText.Position(1:2) = [xCoords, yCoords];
            end
            
        end
        
    end
    
    methods (Access = protected)
        
        function updateBackground(obj)
            
            if ~isempty(obj.hBackground) && obj.IsConstructed
                [X, Y] = obj.createBoxCoordinates(obj.Size, obj.CornerRadius);
                X = X + obj.Position(1);
                Y = Y + obj.Position(2);
                set(obj.hBackground, 'XData', X, 'YData', Y)
            end
        end
        
    end
    
    
    methods (Access = private) % Internal updating
        
        function [xCoords, yCoords] = getTextCoordinates(obj, whichKnob)
            
            xRangeSlider = obj.Max - obj.Min;

            switch lower(whichKnob)
                case 'low'
                    xRelativePosition = (obj.Low - obj.Min) ./ xRangeSlider;
                case 'high' 
                    xRelativePosition = (obj.High - obj.Min) ./ xRangeSlider;
            end
            
            xRangeAxes = obj.Position(3) - sum( obj.Padding([1,3]) );
            xCoords = obj.Position(1) + obj.Padding(1) + ...
                xRangeAxes .* xRelativePosition;
            yCoords = obj.Position(2) + obj.Position(4) .* 0.85;
        
        end
        
        function [xCoords, yCoords] = getKnobCoordinates(obj, whichKnob)

            sliderSize = obj.KnobSize;
            theta = linspace(0, 2*pi, 200);

            
            rho = ones(size(theta)) .* 0.5 .* sliderSize;
            [xCoords, yCoords] = pol2cart(theta, rho);

            xRange = obj.Max - obj.Min;
            
            switch lower(whichKnob)
                case 'low'
                    xRelativePosition = (obj.Low - obj.Min) ./ xRange;
                case 'high' 
                    xRelativePosition = (obj.High - obj.Min) ./ xRange;
            end
            
            xRelativePosition = double(xRelativePosition);
            
            xCoords = xCoords + obj.Position(1) + obj.Padding(1) + ...
                (obj.Position(3)-sum(obj.Padding([1,3]))) .* xRelativePosition;
            yCoords = yCoords + obj.Position(2) + obj.Position(4)/2;

        end
        
        function [xCoords, yCoords] = getTrackCoordinates(obj)

            xCoords = [obj.Position(1)+obj.Padding(1); ...
                            sum(obj.Position([1,3]))-obj.Padding(3)];
            
            yCoords = ones(2,1) .* obj.Position(2) + obj.Position(4) / 2;
        end
        
        
        function [xCoords, yCoords] = getTickCoordinates(obj)
            
            % Todo....
            
            x1 = obj.Position(1)+obj.Padding(1);
            x2 = sum(obj.Position([1,3]))-obj.Padding(3);

            % Correct for linewidth
            x1 = x1+2;
            x2 = x2-2;
            
            y1 = obj.Position(2) + obj.Position(4) / 2;
            y2 = y1 - obj.TickLength;
            
            if strcmp(obj.TickMode, 'both')
               y1 = y1+obj.TickLength/2;
               y2 = y2+obj.TickLength/2;
            elseif strcmp(obj.TickMode, 'over')
                y1 = y1+obj.TickLength;
                y2 = y2+obj.TickLength;
            elseif strcmp(obj.TickMode, 'underx2')
                y1 = y1-obj.TickLength;
                y2 = y2-obj.TickLength;
            end
            
            numTicks = 9;
            xCoords = linspace(x1,x2,numTicks);
            xCoords = repmat(xCoords, 3, 1);
            xCoords(3,:) = nan;
           
            yCoords = repmat([y1;y2;nan], 1, numTicks);
            
        end
        
        
        function updateValuetipString(obj, whichKnob)
            [xCoords, ~] = obj.getTextCoordinates(whichKnob);
            obj.hText.Position(1) = xCoords;
            
            switch whichKnob
                case 'low'
                    value = obj.Low;
                case 'high'
                    value = obj.High;
            end
            
            if mod(obj.StepSize, 1) < 1e-6
                obj.hText.String = num2str(value, '%.d');
            else
                obj.hText.String = num2str(value, '%.2f');
            end
        end
        
        function setPointerBehavior(obj, h)
        %setPointerBehavior Set pointer behavior of buttons.

            pointerBehavior.enterFcn    = @(s,e,hObj)obj.onMouseEnterKnob(h);
            pointerBehavior.exitFcn     = @(s,e,hObj)obj.onMouseExitKnob(h);
            pointerBehavior.traverseFcn = [];%@obj.moving;
            
            iptSetPointerBehavior(h, pointerBehavior);
            iptPointerManager(ancestor(h, 'figure'));

        end
        
    end
    
    
    methods % Slider Interaction Callbaks

        
        function onSliderKnobPressed(obj, src, ~)
            
            obj.IsKnobPressed = true;
            
            hFigure = ancestor(obj.Parent, 'figure');
            el1 = listener( hFigure, 'WindowMouseRelease', ...
                                @(s,e) obj.onSliderKnobReleased(src) );
            el2 = listener( hFigure, 'WindowMouseMotion', ...
                                @(s,e) obj.onSliderMoved(src, e));
           
            obj.WindowButtonUpListener = el1;
            obj.WindowMouseMotionListener = el2;

            switch src.Tag
                case 'Range Slider Low'
                    obj.updateValuetipString('low')
                    ind = 1;
                case 'Range Slider High'
                    obj.updateValuetipString('high')
                    ind = 2;
            end

            % todo: use button scheme for changing this
            obj.hSliderKnob(ind).FaceColor = obj.KnobFaceColorActive;
            obj.hSliderKnob(ind).EdgeColor = obj.KnobEdgeColorActive;
            
            if obj.ShowLabel
                obj.hText.Visible = 'on';
            end
            
        end
        
        function onSliderMoved(obj, src, ~)
            
            mousePoint = obj.hAxes.CurrentPoint(1, 1:2);

            % Calculate value based on position in axes and relative range
            % of axes.
            xRange = obj.Max-obj.Min;
            
            newValue = (mousePoint(1) - obj.Position(1) - obj.Padding(1)) / ...
                (obj.Position(3)-sum(obj.Padding([1,3]))) .* xRange + obj.Min;
            
            % Round to nearest point...
            newValue = round(newValue/obj.StepSize) * obj.StepSize;
            
            switch src.Tag
                case 'Range Slider Low'
                    obj.onValueChanging(newValue, 'low')
                    obj.updateValuetipString('low')
                case 'Range Slider High'
                    obj.onValueChanging(newValue, 'high')
                    obj.updateValuetipString('high')
                otherwise
                    % Move the know which is closest to where the track was
                    % pressed
                    if newValue <= obj.Low
                        whichValue = 'low';
                    elseif newValue >= obj.High
                        whichValue = 'high';
                    else
                        if abs(newValue-obj.Low) > abs(newValue-obj.High)
                            whichValue = 'high';
                        else
                            whichValue = 'low';
                        end
                    end
                    
                    obj.onValueChanging(newValue, whichValue)
                    obj.updateValuetipString(whichValue)  
                    
            end
            
        end
        
        function onSliderKnobReleased(obj, src, event)

            obj.IsKnobPressed = false;

            
            delete(obj.WindowButtonUpListener)
            delete(obj.WindowMouseMotionListener)
            obj.WindowButtonUpListener = [];
            obj.WindowMouseMotionListener = [];
            
            switch src.Tag
                case 'Range Slider Low'
                    ind = 1;
                case 'Range Slider High'
                    ind = 2;
            end

            % todo: use button scheme for changing this
            obj.hSliderKnob(ind).FaceColor = obj.KnobFaceColorInactive;
            obj.hSliderKnob(ind).EdgeColor = obj.KnobEdgeColorInactive;
            
            if obj.ShowLabel
                obj.hText.Visible = 'off';
            end
            
        end
        
        function updateLocation(obj, mode)
            if ~obj.IsConstructed; return; end

            if nargin < 2; mode = obj.PositionMode; end
            updateLocation@uim.abstract.virtualContainer(obj, mode)
            obj.plotTrack()
            obj.plotKnobs()
            obj.plotText()
            obj.updateBackground()
        end
        
        function updateSize(obj, mode)
            if ~obj.IsConstructed; return; end
            
            if nargin < 2; mode = obj.PositionMode; end
            updateSize@uim.abstract.virtualContainer(obj, mode)
            obj.plotTrack()
            obj.plotKnobs()
        end
        
        function onVisibleChanged(obj, newValue)
            
            if ~obj.IsConstructed; return; end
            
            % Set visibility of subcomponents.
            obj.hTrack.Visible = obj.Visible;
            set(obj.hSliderKnob, 'Visible', obj.Visible);
                        
            switch obj.Visible
                case 'on'
                    obj.hBackground.PickableParts = 'all';
                case 'off'
                    obj.hBackground.PickableParts = 'none';
            end
            
        end
         
        function onValueChanging(obj, newValue, whichValue)
            
            % Keep value within limits and range...
            
            if newValue <= obj.Min; newValue = obj.Min; end
            if newValue >= obj.Max; newValue = obj.Max; end
            
            switch lower(whichValue)
                case 'low'
                    if newValue >= obj.High; newValue = obj.High; end
                    obj.Low = newValue;
                case 'high'
                    if newValue <= obj.Low; newValue = obj.Low; end
                    obj.High = newValue;
            end
                    
        end
        
        function onValueChanged(obj, src, event)
            if obj.IsConstructed
                obj.plotKnobs()
                
                if ~isempty(obj.Callback)
                    evtData = struct('Low', obj.Low, 'High', obj.High);
                    obj.Callback(obj, evtData)
                end
                
            end

        end
        
        function onMouseEnterKnob(obj, hSource, evtData)
            
            if ~obj.IsKnobPressed
                hSource.FaceColor = ones(1,3) * 0.95;
            end
        end
        
        function onMouseExitKnob(obj, hSource, evtData)
            if ~obj.IsKnobPressed
                hSource.FaceColor = ones(1,3) * 0.8;
            end
        end
        
    end
    
    
    methods
        
        function set.Min(obj, newMin)
            assert(newMin < obj.Max_, 'Slider lower limit must be smaller than slider upper limit')
            obj.Min_ = newMin;
            
            if obj.IsConstructed
                obj.plotKnobs()
            end
            
            if obj.Min_ > obj.Low_
                obj.Low = obj.Min_;
            end
        end
        
        function min = get.Min(obj)
            min = obj.Min_;
        end
        
        function set.Max(obj, newMax)
            assert(newMax > obj.Min_, 'Slider upper limit must be larger than slider lower limit')
            obj.Max_ = newMax;
            
            if obj.IsConstructed
                obj.plotKnobs()
            end
            
            if obj.Max_ < obj.High_
                obj.High = obj.Max_;
            end
        end
        
        function max = get.Max(obj)
            max = obj.Max_;
        end
        
        function set.Low(obj, newLow)
            %newLow = obj.Min_;
            assert(newLow >= obj.Min_, 'Slider lower value must be greater than slider lower limit')
            assert(newLow <= obj.High_, 'Slider lower value must be smaller than slider upper value')
            
            if newLow ~= obj.Low_
                obj.Low_ = newLow;
                obj.onValueChanged()
            end
            
        end
        
        function low = get.Low(obj)
            low = obj.Low_;
        end
        
        function set.High(obj, newHigh)
            assert(newHigh <= obj.Max_, 'Slider upper value must be smaller than slider upper limit')
            assert(newHigh >= obj.Low_, 'Slider upper value must be larger than slider lower value')
                        
            if newHigh ~= obj.High_
                obj.High_ = newHigh;
                obj.onValueChanged()
            end
            
        end
        
        function high = get.High(obj)
            high = obj.High_;
        end
        
% %         function set.NumTicks(obj, newValue)
% %             
% %         end
        
        function stepSize = get.StepSize(obj)
            stepSize = (obj.Max-obj.Min) / obj.NumTicks;
        end
        
        
        
    end
    
    
    
end