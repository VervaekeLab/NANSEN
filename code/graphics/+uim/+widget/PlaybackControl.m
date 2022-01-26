classdef PlaybackControl < uim.mixin.assignProperties
%PlaybackControl Widget with controls playing and scrolling through videos
%
%     This widget provides 3 playback buttons (play/pause, increase speed
%     and decrease speed), a slidebar for changing the current value and a
%     optional rangebar used for selection of an interval of values.
%
%     Added a channel radio button selector. Should be a separate class...
%
%     It should be parented in a figure, panel or tab and it will
%     internally create two axes for drawing of the components. The axes
%     are hidden, and for a reason, so don't mess with them:)


    
    % Notes:
    % 1) Playback buttons are placed within one axes where units are in 
    %    pixels. This axes should always keep its original size to prevent 
    %    buttons from stretch effects during figure resize.
    
    % 2) 
    
    
% - - - - - - - - - - - TODO - - - - - - - - - - - -
%  [ ] Make property for function when playback button state changes
%  [x] Better input handling.... Should be able to set props on
%      construction
%  [x] patch bars using uim.shape.rectangle...

    
% - - - - - - - - - - PROPERTIES - - - - - - - - - - 
    
    properties (Dependent)
        Position (1,4) double
    end
    
    properties (Access = public)
        Visible matlab.lang.OnOffSwitchState = 'on'
        
        Value = 1
        Minimum = 1
        Maximum = 2;
        
        NumChannels = 1;
        
        RangeSelectorEnabled matlab.lang.OnOffSwitchState = 'off'
        ActiveRange = [1, 1]            % For virtual vs memory stacks.
        ActiveRangeChangedFcn = []      % Callback for when active range changes.
        
    end
    
    properties % Appearance
        BackgroundColor = [0.94, 0.94, 0.94];
        ButtonColor = ones(1,3) * 0.6;
        
        BarWidth = 4;
        BarPadding = 10; % In length direction (pixel units)
    end
    
    properties (Dependent)
        CurrentChannels = 1;
        ChannelColors
    end
    
    properties (Access = private) % Widget components
        
        hFigure % Window which figure is located in. % Make dependent...
        
        ParentApp
        SliderAxes  %SliderAxes
        ButtonAxes %ButtonAxes
        
        hBar1
        hBar2
        
        hActiveRangeBar
        hRangeButtons
        
        hChannelIndicator
        channelColors_
        knob
        play
        incr
        decr
        
        tincr
        
        h % Struct for keeping all handles which visibility should be turned on and off
        
    end
    
    properties (Access = private) % Widget states and internals
        IsConstructed = false
        knobDown = false
        isMouseOnButton = false

        Position_ = [1, 1, 20, 200]; %Initial position
        
        WindowMouseMotionListener
        WindowMouseReleaseListener
        FrameChangedListener
    end

% - - - - - - - - - - - METHODS - - - - - - - - - - 

    methods % Structors
        
        function obj = PlaybackControl(parentGui, parentHandle, varargin)
            
            obj.ParentApp = parentGui;
            obj.hFigure = obj.ParentApp.Figure;
            
            el = addlistener(obj.ParentApp, 'currentFrameNo', 'PostSet', @obj.changeValue);
            obj.FrameChangedListener = el;

            obj.parseInputs(varargin{:})
            
            obj.createAxes(parentHandle)
            
            % Change construction flag here.
            obj.IsConstructed = true;

            obj.createWidgetComponents()
            
            if ~nargout
                clear obj
            end
            
        end
        
        function delete(obj)
            
            obj.resetWindowMouseListeners()

            delete(obj.FrameChangedListener)
            delete(obj.SliderAxes)
            delete(obj.ButtonAxes)
        end
        
    end
    
    methods (Access = public)
        
        function switchPlayPauseIcon(obj, mode)
        %switchPlayPauseIcon Switch icon of play button on play/pause
            
            buttonPosition = 10;
            buttonHeight = 11;
            switch mode
                case 'play'
                    obj.play.Tag = 'Play';
                    obj.play.XData = buttonPosition + [0, 0, 10];
                    obj.play.YData = [1, -1, 0] .* buttonHeight/2;
                case 'pause'
                    obj.play.Tag = 'Pause';
                    obj.play.XData = [0, 5;  2.5, 7.5; 2.5, 7.5;  0, 5] + buttonPosition;
                    obj.play.YData = [1,1; 1,1; -1,-1; -1,-1] .* buttonHeight/2;
            end
        end
        
        function changeValue(obj, ~, ~)
            newFrame = obj.ParentApp.currentFrameNo;
            obj.Value = newFrame;
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
                        
            obj.Position_= newPosition;
            
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
            if ~obj.IsConstructed
                pos = obj.Position_;
            else
                pos(1:2) = obj.ButtonAxes.Position(1:2);
                pos(3:4) = [obj.ButtonAxes.Position(3) + ...
                    obj.SliderAxes.Position(3), obj.SliderAxes.Position(4)];
            end
        end
        
        function set.Visible(obj, newValue)
            obj.Visible = newValue;
            obj.onVisibleChanged()
        end
        
        function set.RangeSelectorEnabled(obj, newValue)
            obj.RangeSelectorEnabled = newValue;
            obj.onRangeSelectorEnabledStateChanged()
        end
        
        function set.ActiveRange(obj, newValue)
            obj.ActiveRange = newValue;
            obj.drawActiveRangeBar()
            obj.drawRangeButtons() 
        end
        
        function set.BackgroundColor(obj, newValue)
           obj.BackgroundColor = newValue;
           obj.onBackgroundColorSet()
        end
        
        function set.Minimum(obj, newValue)
            obj.Minimum = newValue;
            obj.redrawSliderComponents()
        end
        
        function set.Maximum(obj, newValue)
            obj.Maximum = newValue;
            obj.redrawSliderComponents()
        end
        
        function set.Value(obj, newValue)
            obj.Value = newValue;
            obj.drawSliderButton()
            obj.drawIndicatorBar()
        end
        
        function set.CurrentChannels(obj, newValue)
        	obj.hChannelIndicator.CurrentChannels = newValue;
        end
        
        function set.ChannelColors(obj, newValue)
            if ~isempty(obj.hChannelIndicator)
                obj.hChannelIndicator.ChannelColors = newValue;
            else
                obj.channelColors_ = newValue;
            end
        end
        
        function chColors = get.ChannelColors(obj)
            if ~isempty(obj.hChannelIndicator)
                chColors = obj.hChannelIndicator.ChannelColors;
            else
                chColors = obj.channelColors_;
            end
        end
        
        
        function set.NumChannels(obj, newValue)
            
            obj.NumChannels = newValue;
            obj.onNumChannelsChanged()
            
        end
    end
    
    methods (Access = private) % Widget creation & updates
        
        function createAxes(obj, parentHandle)
            
            if isa(parentHandle, 'matlab.graphics.axis.Axes')
                %hAxes(2) = parentHandle;
                obj.SliderAxes = parentHandle;
                
                offsetPx = 80;
                if strcmp(obj.SliderAxes.Units, 'normalized')
                    axPosition = getpixelposition(obj.SliderAxes);
                    axWidthPx = axPosition(3);
                    offset = offsetPx/axWidthPx;
                else
                    offset = offsetPx;
                end
                
                obj.ButtonAxes = axes('Parent', parentHandle.Parent);
                
                warning('not quite supported')
            else
                matlabVersion = version('-release');
                doDisableToolbar = str2double(matlabVersion(1:4))>2018 || ...
                                       strcmp(matlabVersion, '2018b');
                
                if doDisableToolbar
                    args = {'Toolbar', []};
                else
                    args = {};
                end
                
                hAxes = gobjects(1,2);
                
                for i = 1:2
                    hAxes(i) = axes('Parent', parentHandle, args{:});
                    if doDisableToolbar
                        disableDefaultInteractivity(hAxes(i))
                    end
                end

                obj.ButtonAxes = hAxes(1);
                obj.SliderAxes = hAxes(2);
                
            end
            
            hold(obj.SliderAxes, 'on')
            hold(obj.ButtonAxes, 'on')

            set(hAxes, 'XTick', [], 'YTick', [])
            set(hAxes, 'Units', 'pixels')

            % Force update of axes position
            obj.IsConstructed = true;
            obj.onLocationChanged()
            obj.onSizeChanged()
            obj.IsConstructed = false;

            set([hAxes.XAxis, hAxes.YAxis], 'Visible', 'off')
            set(hAxes, 'HandleVisibility', 'off')

            obj.SliderAxes.Tag = 'Playback Widget (Slider Axes)';
            obj.ButtonAxes.Tag = 'Playback Widget (Button Axes)';
            
        end
        
        function createWidgetComponents(obj)
           
            obj.drawPlaybackButtons()
            
            obj.drawSliderBar()
            obj.drawIndicatorBar()

            obj.drawActiveRangeBar()
            obj.drawRangeButtons()
            
            if ~obj.RangeSelectorEnabled
                obj.onRangeSelectorEnabledStateChanged()
            end
            
            % Draw this last to place on top
            obj.drawSliderButton()
            
            if obj.NumChannels > 1
                obj.onNumChannelsChanged()
            end
        end
        
    % % % Methods for drawing the components

        function redrawSliderComponents(obj)
            
            if isempty(obj.knob) % Return if components are not created yet
                return
            end
            
            if ~obj.IsConstructed; return; end
            
            obj.drawSliderButton()
            obj.drawSliderBar()
            obj.drawIndicatorBar()
            
            if obj.RangeSelectorEnabled
                obj.drawActiveRangeBar()
            end
        end
    
        function drawPlaybackButtons(obj)
            
            % Todo: Set sizes using properties..
            buttonHeightA = 11;
            buttonHeightB = 7;
            
            buttonXPos = 10 + [0, 17, 34, 50];
            
            % Specify patch coordinates for drawing buttons
            xPlay = buttonXPos(1) + [0, 0, 10];
            yPlay = [1, -1, 0] .* buttonHeightA/2;

            xDecr = buttonXPos(2) + [5.5, 11; 5.5, 11;  0, 5.5];
            xIncr = buttonXPos(3) + [0, 5.5;  0, 5.5;  5.5, 11];
            [yDecr, yIncr] = deal( [1,1; -1,-1; 0,0] .* buttonHeightB/2 );

            if ~isempty(obj.play) % Buttons already exist
                set(obj.play, 'XData', xPlay, 'YData', yPlay);
                set(obj.decr, 'XData', xDecr, 'YData', yDecr);
                set(obj.incr, 'XData', xIncr, 'YData', yIncr);
                obj.tincr.Position(1) = buttonXPos(4);
                return
            end
            
            % Create buttons using patch objects
            obj.play = patch(obj.ButtonAxes, xPlay, yPlay, obj.ButtonColor);
            obj.decr = patch(obj.ButtonAxes, xDecr, yDecr, obj.ButtonColor);
            obj.incr = patch(obj.ButtonAxes, xIncr, yIncr, obj.ButtonColor);

            obj.play.Tag = 'Play';
            obj.decr.Tag = 'Decr';
            obj.incr.Tag = 'Incr';

            % Create text label to indicate playback speed
            obj.tincr = text(obj.ButtonAxes, buttonXPos(4), 1, '');
            obj.tincr.VerticalAlignment = 'middle';
            obj.tincr.HorizontalAlignment = 'left';
            obj.tincr.Color = [0.5,0.5,0.5];
            obj.tincr.FontUnits = 'pixel';
            
            % Set some common button (patch) properties
            hButtons = [obj.play, obj.incr, obj.decr];
            set(hButtons, 'FaceAlpha', 1, 'EdgeColor', 'none', ...
                'ButtonDownFcn', @obj.onPlaybackButtonPressed )
            
            % Assign handles to the h property
            obj.h.playButton = obj.play;
            obj.h.nextButton = obj.incr;
            obj.h.prevButton = obj.decr;
            obj.h.speedLabel = obj.tincr;
            
            % Set pointerbehavior to give patches a "button" feel @
            % mouseover
            setPointerBehavior(obj, obj.play)
            setPointerBehavior(obj, obj.incr)
            setPointerBehavior(obj, obj.decr)
            
        end
        
        function drawSliderButton(obj)
            
            if ~obj.IsConstructed; return; end
            
            sliderButtonShape = 'disk'; % disk vs diamond
            
            switch sliderButtonShape
                case 'disk'
                    [X, Y] = uim.shape.circle(6);
                    X = X + obj.getSliderXposition(obj.Value - obj.Minimum) - 6;
                    Y = Y - 6;
                case 'diamond'
                    X = obj.getSliderXposition(obj.Value - obj.Minimum);
                    Y = 0;
            end
            
            if ~isempty(obj.knob)
                set(obj.knob, 'XData', X, 'YData', Y); return
            end
            
            knobColor = [0.6,0.6,0.6];
            
            switch sliderButtonShape
                case 'disk'
                    obj.knob = patch(obj.SliderAxes, X, Y, knobColor);
                    obj.knob.FaceAlpha = 1;
                    obj.knob.EdgeColor = [0.1,0.1,0.1];

                case 'diamond'
                    obj.knob = plot(obj.SliderAxes, X, Y, 'Color', knobColor);
                    obj.knob.Marker = 'd';
                    obj.knob.MarkerFaceColor = [0.8,0.8,0.8];
                    obj.knob.MarkerEdgeColor = [0.2,0.2,0.2];
                    obj.knob.MarkerSize = 7;
            end
            
            obj.knob.LineWidth = 1;
            obj.knob.ButtonDownFcn = @obj.knobPressed;
            obj.knob.Clipping = 'off';     
            obj.knob.Tag = 'Button';
            
            setPointerBehavior(obj, obj.knob)
            obj.h.SliderButton = obj.knob;

        end
        
        function drawSliderBar(obj)
        %createSliderBar Create bar which sliderbutton can slide on
            
            if ~obj.IsConstructed; return; end
            
            [X, Y] = obj.getBarCoordinates('SliderBar');
            
            if isfield(obj.h, 'scrollBar1') % Bar already exists
                set(obj.h.scrollBar1, 'XData', X, 'YData', Y)
                return
            end

            trackColor = [0.3,0.3,0.3];

            obj.h.scrollBar1 = patch(obj.SliderAxes, X, Y, trackColor);
            obj.h.scrollBar1.FaceAlpha = 0.6;
            obj.h.scrollBar1.EdgeColor = 'none';
            obj.h.scrollBar1.Tag = 'Scrollbar';
            obj.h.scrollBar1.ButtonDownFcn = @obj.onPlaybackButtonPressed;
            obj.h.scrollBar1.Clipping = 'off';     

        end
        
        function drawIndicatorBar(obj)
        %createIndicatorBar Create bar indicating current position
            if ~obj.IsConstructed; return; end

            barColor = [0.8,0.8,0.8];
            
            [X, Y] = obj.getBarCoordinates('IndicatorBar');
            
            if isfield(obj.h, 'scrollBar2') % Bar already exists
                set(obj.h.scrollBar2, 'XData', X, 'YData', Y)
                return
            end
            
            obj.h.scrollBar2 = patch(obj.SliderAxes, X, Y, barColor);
            
            obj.h.scrollBar2.FaceAlpha = 0.5;
            obj.h.scrollBar2.EdgeColor = 'none';
            obj.h.scrollBar2.Clipping = 'off';     
            obj.h.scrollBar2.HitTest = 'off';
            obj.h.scrollBar2.PickableParts = 'none';
        end
        
        function drawActiveRangeBar(obj)
        %createIndicatorBar Create bar indicating current position
            if ~obj.IsConstructed; return; end

            [X, Y] = obj.getBarCoordinates('ActiveRangeBar');
            
            if ~isempty(obj.hActiveRangeBar) % Bar already exists
                set(obj.hActiveRangeBar, 'XData', X, 'YData', Y)
                return
            end
            
            obj.hActiveRangeBar = patch(obj.SliderAxes, X, Y, 'g');
            
            obj.hActiveRangeBar.FaceAlpha = 0.5;
            obj.hActiveRangeBar.EdgeColor = 'none';
            obj.hActiveRangeBar.HitTest = 'off';
            obj.hActiveRangeBar.PickableParts = 'none';            
            
            obj.h.ActiveRangeBar = obj.hActiveRangeBar;
        end
        
        function drawRangeButtons(obj)
            
            for i = 1:2
                X = obj.getSliderXposition(obj.ActiveRange(i));
                
                if numel(obj.hRangeButtons) == 2
                    set(obj.hRangeButtons(i), 'XData', X);
                else
                    hBtn = plot(obj.SliderAxes, X, 0, 'ow');
                    hBtn.Visible = 'off';
                    hBtn.PickableParts = 'all';
                    hBtn.ButtonDownFcn = @(s,e, h) obj.rangeButtonPressed(hBtn);
                    obj.setPointerBehaviorActiveRangeSlider(hBtn)

                    obj.hRangeButtons(i) = hBtn;
                end

            end
            
        end
        
        
    % % % Methods for getting coordinates of components
        
        function [X, Y] = getBarCoordinates(obj, barName)
            
            w = obj.BarWidth;
            dx = obj.BarPadding;
            
            switch barName
                
                case 'ActiveRangeBar'
                    
                    barRange = max(obj.ActiveRange) - min(obj.ActiveRange);
                    
                    l = obj.getSliderXposition( barRange );
                    dx = obj.getSliderXposition( min(obj.ActiveRange) - 1 );
                case 'SliderBar'
                    l = obj.getSliderXposition( obj.Maximum - obj.Minimum );
                case 'IndicatorBar'
                    l = obj.getSliderXposition( obj.Value - obj.Minimum );
            end
            
            % Need to subtract bar padding because the getSliderXposition
            % adds that to the xposition. I guess I'm slightly misusing the
            % getSliderXposition methods for getting the lengths...
            
            l = l - obj.BarPadding;
            
            [X, Y] = uim.shape.rectangle([l, w], w/2);
            X = X + dx;
            Y = Y - w/2;
            
        end
       
        function x = getSliderXposition(obj, sliderValue)
        %getSliderXposition Get pixel position from slider value
            
            axLength = obj.SliderAxes.Position(3);
            sliderLengthPix = axLength - obj.BarPadding*2;
            sliderLengthVal = obj.Maximum - obj.Minimum;

            x = sliderLengthPix / sliderLengthVal .* (sliderValue);
            
            % Offset x coordinates according to padding value of slider
            % within axes.
            x = x + obj.BarPadding;

        end
        
        function val = getSliderValue(obj, xPosition)
            
            % Correct for padding offset
            xPosition = xPosition - obj.BarPadding;
            
            axLength = obj.SliderAxes.Position(3);
            sliderLengthPix = axLength - obj.BarPadding*2;
            sliderLengthVal = obj.Maximum - obj.Minimum;
            
            val = xPosition / sliderLengthPix .* sliderLengthVal;
            val = val + obj.Minimum;

        end
        
    end
    
    methods (Access = private) % User interaction callbacks
        
        
    % % % Callbacks for playback buttons

        function onPlaybackButtonPressed(obj, src, event)
           
            if ~strcmp(src.Tag, 'Scrollbar')
                src.FaceColor = 'w';
                pause(0.1)
                src.FaceColor = [0.6,0.6,0.6];
            end
           
            switch src.Tag
                case 'Play'
                    obj.play.Tag = 'Pause';
                    obj.switchPlayPauseIcon('pause')
                    obj.ParentApp.playVideo([], []);
                   
                case 'Pause'
                    obj.play.Tag = 'Play';
                    obj.ParentApp.isPlaying = false;
                    obj.switchPlayPauseIcon('play')
                   
                case 'Incr'
                    obj.ParentApp.playbackspeed = obj.ParentApp.playbackspeed * 2;
                    if obj.ParentApp.playbackspeed == 1
                        obj.tincr.String = '';
                    else
                        if mod(obj.ParentApp.playbackspeed, 1) == 0
                            obj.tincr.String = sprintf( '%dx', obj.ParentApp.playbackspeed);
                        else
                            obj.tincr.String = sprintf( '%.1fx', obj.ParentApp.playbackspeed);
                        end
                    end
                   
                case 'Decr'
                    obj.ParentApp.playbackspeed = obj.ParentApp.playbackspeed / 2;
                    if obj.ParentApp.playbackspeed == 1
                        obj.tincr.String = '';
                    else
                        if mod(obj.ParentApp.playbackspeed, 1) == 0
                            obj.tincr.String = sprintf( '%dx', obj.ParentApp.playbackspeed);
                        else
                            obj.tincr.String = sprintf( '%.1fx', obj.ParentApp.playbackspeed);
                        end
                    end
                case 'Next'
                   
                case 'Prev'
                   
                case 'Scrollbar'
                    mousePoint = get(obj.SliderAxes, 'CurrentPoint');
                    xPoint = mousePoint(1);
                    
                    newValue = round( obj.getSliderValue(xPoint) );
                    
                    if newValue < obj.Minimum; newValue = obj.Minimum; end
                    if newValue > obj.Maximum; newValue = obj.Maximum; end
                    
                    obj.ParentApp.changeFrame(struct('String', newValue), [], 'jumptoframe');
            end 
           
        end
        
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
            if isa(h, 'matlab.graphics.primitive.Patch')
                h.FaceColor = ones(1,3) * 0.8;
            elseif isa(h, 'matlab.graphics.chart.primitive.Line')
                h.MarkerFaceColor = ones(1,3)*0.9;
                h.MarkerSize = 8;
            end
            
            obj.isMouseOnButton = true;
            obj.hFigure.Pointer = 'hand';
        end
        
        function onMouseExited(obj, h, varargin)
        %onMouseEntered Callback for mouse leaving button
            if isa(h, 'matlab.graphics.primitive.Patch')
                h.FaceColor = ones(1,3) * 0.6;
            elseif isa(h, 'matlab.graphics.chart.primitive.Line')
                if ~obj.knobDown
                    h.MarkerFaceColor = ones(1,3)*0.8;
                    h.MarkerSize = 7;
                end
            end
            
            obj.isMouseOnButton = false;
            if ~obj.knobDown
                obj.hFigure.Pointer = 'arrow';
            end
            
        end
        
    % % % Callbacks for mouseover effects on active range slider
    
        function setPointerBehaviorActiveRangeSlider(obj, h)
        %setPointerBehavior Set pointer behavior of buttons.

            pointerBehavior.enterFcn    = @(s,e,hObj)obj.onMouseEnteredRangeButton(h);
            pointerBehavior.exitFcn     = @(s,e,hObj)obj.onMouseExitedRangeButton(h);
            pointerBehavior.traverseFcn = [];%@obj.moving;
            
            iptSetPointerBehavior(h, pointerBehavior);
            iptPointerManager(ancestor(h, 'figure'));

        end

        function onMouseEnteredRangeButton(obj, h, varargin)
        %onMouseEntered Callback for mouse entering button
            obj.isMouseOnButton = true;
            obj.hFigure.Pointer = 'left';
        end
        
        function onMouseExitedRangeButton(obj, h, varargin)
        %onMouseEntered Callback for mouse leaving button
            obj.isMouseOnButton = false;
            if ~obj.knobDown
                obj.hFigure.Pointer = 'arrow';
            end
        end
        
    % % % Callbacks for the scroller knob

        function knobPressed(obj, src, event)
            
            el = listener(obj.ParentApp.Figure, 'WindowMouseMotion', @obj.knobMoving);
            obj.WindowMouseMotionListener = el;
            
            el = listener(obj.ParentApp.Figure, 'WindowMouseRelease', @obj.knobReleased);
            obj.WindowMouseReleaseListener = el;
            
            obj.knobDown = true;
            
        end
        
        function knobMoving(obj, src, event)
           
            if obj.knobDown % Just in case???
                mousePoint = obj.SliderAxes.CurrentPoint(1);
                xPoint = mousePoint(1);

                newValue = round( obj.getSliderValue(xPoint) );
                
                if newValue < obj.Minimum; newValue = obj.Minimum; end
                if newValue > obj.Maximum; newValue = obj.Maximum; end
                
                % Call guis changeFrame methods
                % is it better with event notification?
                
                obj.ParentApp.changeFrame(struct('Value', newValue), [], 'slider');
                
            end
            
        end
        
        function knobReleased(obj, src, event)
            
            obj.knobDown = false;
            
            obj.resetWindowMouseListeners()
                    
            obj.knob.MarkerFaceColor = ones(1,3)*0.8;
            obj.knob.MarkerSize = 7;

            if ~obj.isMouseOnButton
                obj.hFigure.Pointer = 'arrow';
            end
        end
        
    % % % Callbacks for the range button

        function rangeButtonPressed(obj, hBtn)
            
            el = listener(obj.ParentApp.Figure, ...
                'WindowMouseMotion', @(s,e,h) obj.rangeButtonMoving(hBtn));
            obj.WindowMouseMotionListener = el;
            
            el = listener(obj.ParentApp.Figure, ...
                'WindowMouseRelease', @(s,e,h) obj.rangeButtonReleased());
            obj.WindowMouseReleaseListener = el;
            
            obj.knobDown = true;
            
        end
        
        function rangeButtonMoving(obj, hBtn)
            
            if obj.knobDown % Just in case???
                mousePoint = obj.SliderAxes.CurrentPoint(1);
                xPoint = mousePoint(1);
                
                newValue = round( obj.getSliderValue(xPoint) );
                
                if newValue < obj.Minimum; newValue = obj.Minimum; end
                if newValue > obj.Maximum; newValue = obj.Maximum; end
                
                ind = find(ismember(obj.hRangeButtons, hBtn));
                obj.ActiveRange(ind) = newValue;
                
                set(hBtn, 'XData', xPoint)
                obj.drawActiveRangeBar()
                    
            end

        end
        
        function rangeButtonReleased(obj)
            
            obj.knobDown = false;
            obj.resetWindowMouseListeners()
            
            if ~obj.isMouseOnButton
                obj.hFigure.Pointer = 'arrow';
            end
            
            % Activate callback function for when active range changed
            if ~isempty(obj.ActiveRangeChangedFcn)
                newRange = obj.ActiveRange;
                % Todo. make real eventdata...
                evtData = struct('NewRange', newRange);
                obj.ActiveRangeChangedFcn(obj, evtData)
            end
        end
        
    % % % Housekeeping
        
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
    
    methods (Access = private) % Property set callbacks
    
        function onBackgroundColorSet(obj)
            if ~obj.IsConstructed; return; end
            obj.SliderAxes.Color = obj.BackgroundColor;
            obj.ButtonAxes.Color = obj.BackgroundColor;
        end
        
        function onVisibleChanged(obj)
            
            if ~obj.IsConstructed; return; end
            
            comps = struct2cell(obj.h);
            set([comps{:}], 'Visible', obj.Visible)
            
            obj.SliderAxes.Visible = obj.Visible;
            obj.ButtonAxes.Visible = obj.Visible;
            
            if obj.Visible
                obj.RangeSelectorEnabled = obj.RangeSelectorEnabled;
            else
                set(obj.hRangeButtons, 'PickableParts', 'none')
            end
        end
        
        function onRangeSelectorEnabledStateChanged(obj)
            
            if ~obj.IsConstructed; return; end
            
            if obj.RangeSelectorEnabled
                obj.drawActiveRangeBar()
                obj.drawRangeButtons()
                
                obj.hActiveRangeBar.Visible = 'on';
                
                set(obj.hRangeButtons, 'PickableParts', 'all')
            else
                if ~isempty(obj.hActiveRangeBar)
                    obj.hActiveRangeBar.Visible = 'off';
                    set(obj.hRangeButtons, 'PickableParts', 'none')
                end
            end
        end
        
        function onPositionChanged(obj, newPos)
            % Not used!
            offsetPx = 80;
            if strcmp(obj.SliderAxes.Units, 'normalized')
                obj.SliderAxes.Units = 'pixel';
                axWidthPx = obj.SliderAxes.Position(3);
                obj.SliderAxes.Units = 'normalized';
                offset = offsetPx/axWidthPx;
            else
                offset = offsetPx;
            end   

            obj.SliderAxes.Position = newPos;
            
            obj.Position = newPos;
            
        end
        
        function onLocationChanged(obj)
            if ~obj.IsConstructed; return; end
            
            dx = 80;

            if obj.NumChannels > 1 && ~isempty(obj.hChannelIndicator)
                dx = dx + obj.BarPadding + obj.hChannelIndicator.Position(3);
            end
            
            obj.ButtonAxes.Position(1:2) = obj.Position_(1:2);
            obj.SliderAxes.Position(1:2) = obj.Position_(1:2) + [dx, 0];

        end
        
        function onSizeChanged(obj)
            
            if ~obj.IsConstructed; return; end
            
            dx = 80;
            
            if obj.NumChannels > 1 && ~isempty(obj.hChannelIndicator)
                dx = dx + obj.BarPadding + obj.hChannelIndicator.Position(3);
            end
            
            % Set axes positions in pixels
            obj.ButtonAxes.Position(3) = dx;
            obj.ButtonAxes.Position(4) = obj.Position_(4);
            
            obj.SliderAxes.Position(1) = dx;
            obj.SliderAxes.Position(3) = max([0, obj.Position_(3) - dx + 1]);
            obj.SliderAxes.Position(4) = obj.Position_(4);
            
            % Set axes limits to correspond with pixel sizes of axes
            axHeight = obj.Position_(4);
            
            newYLim = [-1, 1] .* (axHeight/2);
            if ~all( newYLim == obj.ButtonAxes.YLim  )
                set([obj.ButtonAxes, obj.SliderAxes], 'YLim', newYLim);
            end
           
            newXLimA = [1, dx];
            if ~all( newXLimA == obj.ButtonAxes.XLim )
                obj.ButtonAxes.XLim = newXLimA;
            end
            
            newXLimB = [1, obj.SliderAxes.Position(3)];
            if ~all( newXLimB == obj.SliderAxes.XLim )
                obj.SliderAxes.XLim = newXLimB;
            end

            % Update component coordinates
            obj.redrawSliderComponents()
            
        end
        
        function onNumChannelsChanged(obj)
            if ~obj.IsConstructed; return; end
            
            if obj.NumChannels == 1
                if isempty(obj.hChannelIndicator)
                    return
                else
                    delete(obj.hChannelIndicator)
                    obj.hChannelIndicator=[];
                    obj.onSizeChanged()
                    return
                end
            end
            
            % Todo: make method...
            if isempty(obj.hChannelIndicator)
                
                pos = [80+obj.BarPadding, obj.Position_(2), 10, obj.Position_(4)];
                
                params = {...
                    'Position', pos, ...
                    'NumChannels', obj.NumChannels, ...
                    'Callback', @(ind) obj.ParentApp.changeChannel(ind) };
                
                if ~isempty(obj.ChannelColors)
                    params = [params, {'ChannelColors', obj.ChannelColors}];
                end

                obj.hChannelIndicator = uim.widget.ChannelIndicator( ...
                    obj.ParentApp, obj.ButtonAxes, params{:});
            else
                obj.hChannelIndicator.NumChannels = obj.NumChannels;
            end
            
            % Resize axes...
            obj.onSizeChanged()
            
        end
        
    end

end