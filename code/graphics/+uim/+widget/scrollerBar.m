classdef scrollerBar < uim.handle
%scrollerBar A very simple scrollerbar that can be made to look awesome.
%
%   h = clib.widgets.scrollerBar(hParent) creates a scrollbar in hParent.
%   hParent should be a panel exclusively made for the scrollerbar. The
%   scrollerbar will fill the panel, so the panel position determines the
%   size and location of the scrollerbar.
%
%   h = clib.widgets.scrollerBar(hParent, Name, Value) creates the
%   scrollbar and specifies one or more scrollbar property names and 
%   corresponding values. All properties of the scrollbar can be set.
%
%   Written by Eivind Hennestad | Vervaeke Lab


    % Todo: 
    %   [x] Fix scroller so that its not jumpy/jittery when reaching the
    %       end. Done. But it might still be glitchy when turning around...?
    %
    %   [x] Make sure bar stays in right position when the barlength is
    %       updated. Done. (Need to properly debug)
    %
    %   [ ] Redraw scrollbar when container resizes. 
    %   [ ] Change /xlim(horz) or ylim/ver only when maximum changes...


    properties 
        Orientation = 'vertical' %Todo: Resolve automatically based on pos
        Position = [0,0,1,1]
        Units = 'normalized'
        
%         Minimum = 0               % Minimum scrollbar value (Default = 0) % Note not implemented yet
        Maximum = 1                 % Maximum scrollbar value (Default = 1)
        Value = 0                   % Initial scrollbar value (Default = 0)
        VisibleAmount = 0.5         % Fraction of scrollbar that is visible

        BarWidth = 6;
        BarColor = ones(1,3)*0.65;  % Color of the bar
        TrackColor = ones(1,3)*0.4; % Color of the track which the bar slides on
        
        Callback = []               % Callback function for when bar is moving.
        StopMoveCallback = []       % Callback function for when bar stops moving.
        Visible = 'on'
    end % /properties
    
    
    properties (Access = private)
        hParent
        hScrollbarAxes
        hScrollbar
        figureCallbackStore
        isInitialized = false
        
        scrollHistory = zeros(5,1)
        moveStartPosition = [];
        barInitialCoords = [];
        
        isCursorOnTrack = false
        isCursorOnBar = false
        
        isTrackVisible = false;
        
    end % /properties (private)

    
    properties (Dependent, Access = private)
        barPosition
    end
    
    
    methods
        
        function obj = scrollerBar(parentContainer, varargin)
        %scrollerBar Create a scrollerbar in a specified panel.
        
            % make assertions, e.g. check that its a valid figure/panel.
            obj.hParent = parentContainer;
            
            
            % Assign name value pairs to object.
            for i = 1:2:numel(varargin)
                obj.(varargin{i}) = varargin{i+1};
            end
            
            obj.createScrollbar;
            obj.setPointerBehavior()
            
            obj.isInitialized = true;
            obj.redraw()

            
            % Unwrap varargin
            
            % scrollerDirection: 'horizontal' | 'vertical'
            % scrollerWidthPixel
            % slider
            % track
            % chamfer...
            

        end % /scrollerBar
        

        function redraw(obj)
        %redraw Redraw scrollbar.    
            obj.updateBarLength()
            drawnow
        end % /redraw
        
        
        function set.Value(obj, newValue)
        %set.Value Set Value property and update bar position.

            if newValue ~= obj.Value
                obj.Value = newValue;
                obj.updateBarPosition()
                obj.onValueChanged()
            end

        end % /set.Value
        
        function set.Maximum(obj, newValue)
            obj.Maximum = newValue;
            obj.redraw()
        end
        
        function set.VisibleAmount(obj, value)
        %set.VisibleAmount Set visibleAmount property and update barheight.
        
            if obj.VisibleAmount ~= value
                obj.VisibleAmount = value;
                obj.updateBarLength()
                obj.onVisibleChanged()
            end
        end % /set.VisibleAmount
        
        function set.TrackColor(obj, newValue)
            obj.hScrollbar(1).FaceColor = newValue;
        end
        
        function set.Visible(obj, newValue)
            
            assert(contains(newValue, {'on', 'off'}), 'Visible must be ''on'' or ''off''')
            
            obj.Visible = newValue;
            obj.onVisibleChanged()

        end
        
        function set.Position(obj, newValue)
            obj.Position = newValue;
            obj.onPositionChanged()
        end
        
        function showTrack(obj)
        %showTrack Show the track which the scrollbar slides on top.
            obj.hScrollbar(1).Visible = 'on';
            obj.isTrackVisible = true;
        end % /showTrack
        
        function hideTrack(obj)
        %hideTrack Hide the track which the scrollbar slides on top.
            obj.hScrollbar(1).Visible = 'off';
            obj.isTrackVisible = false;
        end % /hideTrack
        
        function show(obj)
            if obj.VisibleAmount < obj.Maximum
                if obj.isTrackVisible
                    obj.hScrollbar(1).Visible = 'on';
                end
                obj.hScrollbar(2).Visible = 'on';
            else
                obj.hScrollbar(1).Visible = 'off';
                obj.hScrollbar(2).Visible = 'off';
            end
        end
        
        function hide(obj)
            
            if obj.isTrackVisible
                obj.hScrollbar(1).Visible = 'off';
            end
            obj.hScrollbar(2).Visible = 'off';
            
        end
        
        function setPointerBehavior(obj)
        %setPointerBehavior Set pointer behavior of background.

            pointerBehavior.enterFcn    = @(s,e)obj.highlightBar;
            pointerBehavior.exitFcn     = @(s,e)obj.lowlightBar;
            pointerBehavior.traverseFcn = [];%@obj.moving;
            
            iptSetPointerBehavior(obj.hScrollbar(2), pointerBehavior);
            iptPointerManager(ancestor(obj.hScrollbar(2), 'figure'));

        end
      
        function highlightBar(obj)
        %highlightBar Change the barcolor (make lighter).
            %obj.hScrollbar(2).FaceColor = obj.BarColor*1.2;
            obj.hScrollbar(2).FaceAlpha = 0.8;
        end % /highlightBar
        
        function lowlightBar(obj)
        %lowlightBar Change the barcolor (make default color).
            obj.hScrollbar(2).FaceColor = obj.BarColor;   
            obj.hScrollbar(2).FaceAlpha = 0.6;
        end % /lowlightBar
        
        function hittest(obj, h)
        %hittest Will change appearance and cursor mode if scrollbar is "hit".    
            
            if isequal(h, obj.hScrollbar(1))
                if ~obj.isCursorOnTrack
                    obj.isCursorOnTrack = true;
                    hFig = ancestor(obj.hScrollbar(1), 'figure');
                    hFig.Pointer = 'hand';
                    obj.hScrollbar(1).EdgeColor = obj.hScrollbar(1).FaceColor*1.5;
                end
                
            else
                if obj.isCursorOnTrack
                    obj.isCursorOnTrack = false;
                    hFig = ancestor(obj.hScrollbar(1), 'figure');
                    hFig.Pointer = 'arrow';
                    obj.hScrollbar(1).EdgeColor = 'none';
                end
            end
            
            if isequal(h, obj.hScrollbar(2))
                if ~obj.isCursorOnBar
                    obj.highlightBar()
                    obj.isCursorOnBar = true;
                    hFig = ancestor(obj.hScrollbar(1), 'figure');
                    hFig.Pointer = 'hand';
                end
            else
                if obj.isCursorOnBar
                    obj.lowlightBar()
                    obj.isCursorOnBar = false;
                    if ~obj.isCursorOnTrack
                        hFig = ancestor(obj.hScrollbar(2), 'figure');
                        hFig.Pointer = 'arrow';
                    end
                end
            end

            
        end % /hittest
        
        function change = checkMoveLimits(obj, change, currentPosition)
        %checkMoveLimits Check that bar will stay in range when moved
        
            if currentPosition + change < 0 % Todo: Change to obj.Minimum
                change = -currentPosition;
            elseif currentPosition + change >= obj.Maximum - obj.VisibleAmount
                change = obj.Maximum - obj.VisibleAmount - currentPosition;
            else
                % All is good
            end
            
        end
        
        function startScrollbarMove(obj, src, ~)
        %startScrollbarMove Prepare for scrollbar movement.
        
            hFig = ancestor(src, 'figure');
            
            obj.hScrollbar(2).FaceColor = ones(1,3)*0.65;

            % Get current mouse position, and save it to obj
            mousePointAx = get(obj.hScrollbarAxes, 'CurrentPoint');
            
            
            switch lower(obj.Orientation)
                case 'horizontal'
                    obj.moveStartPosition = mousePointAx(1, 1);
                    obj.barInitialCoords = get(obj.hScrollbar(2), 'XData');
                case 'vertical'
                    obj.moveStartPosition = mousePointAx(1, 2);
                    obj.barInitialCoords = get(obj.hScrollbar(2), 'YData');
            end
            
            obj.figureCallbackStore.WindowButtonMotionFcn = hFig.WindowButtonMotionFcn;
            obj.figureCallbackStore.WindowButtonUpFcn = hFig.WindowButtonUpFcn;
            
            hFig.WindowButtonMotionFcn = @obj.moveScrollbar;
            hFig.WindowButtonUpFcn = @obj.stopScrollbarMove;
            
        end % /startScrollbarMove
        
        function moveScrollbar(obj, ~, event)
        %moveScrollbar Callback to handle interactive movement of bar.
        
            % Todo: Make this more intuitive....

            
            if isa(event, 'matlab.ui.eventdata.WindowMouseData')
                
                newMousePointAx = get(obj.hScrollbarAxes, 'CurrentPoint');

                switch lower(obj.Orientation)
                    case 'horizontal'
                        newPosition = newMousePointAx(1, 1);
                    case 'vertical'
                        newPosition = newMousePointAx(1, 2);
                end
                
                change = newPosition - obj.moveStartPosition;
                barInitialPosition = min(obj.barInitialCoords);

                
                
            elseif isa(event, 'matlab.ui.eventdata.ScrollWheelData')
                
                switch lower(obj.Orientation)
                    case 'horizontal'
                        initialCoords = obj.hScrollbar(2).XData;
                    case 'vertical'
                        initialCoords = obj.hScrollbar(2).YData;
                end
                barInitialPosition = min(initialCoords);

                                
                % Use the scrollHistory to avoid "glitchy" scrolling. For small
                % movements on a mousepad, scroll values can come in as 0, 1, 1,
                % -1, 1, 1 even if fingers are moving in on direction.
                obj.scrollHistory = cat(1, obj.scrollHistory(2:5), event.VerticalScrollCount);

                if event.VerticalScrollCount > 0 && sum(obj.scrollHistory) > 0 
                    change = event.VerticalScrollCount .* obj.Maximum ./ 20;    %Todo: Scroll increment should be a property.
                elseif event.VerticalScrollCount < 0  && sum(obj.scrollHistory) < 0
                    change = event.VerticalScrollCount .* obj.Maximum ./ 20;
                else
                    return;
                end
                
            end
            
            change = obj.checkMoveLimits(change, barInitialPosition);

            % Update scrollbar value
            newValue = barInitialPosition + change;
            
            if newValue ~= obj.Value
                obj.Value = newValue;
            end
            

        end % /moveScrollbar
        
        function stopScrollbarMove(obj, src, ~)
        %stopScrollbarMove Callback for when bar stops moving.
 
            hFig = ancestor(src, 'figure');

            % Restore original figure interactivity callbacks.
            hFig.WindowButtonMotionFcn = obj.figureCallbackStore.WindowButtonMotionFcn;
            hFig.WindowButtonUpFcn = obj.figureCallbackStore.WindowButtonUpFcn;
            
            % Reset the scrollbar color.
            obj.hScrollbar(2).FaceColor = obj.BarColor;
            drawnow
            
            % Get shift of scroller
            newMousePointAx = get(obj.hScrollbarAxes, 'CurrentPoint');
            
            switch lower(obj.Orientation)
                case 'horizontal'
                    newPosition = newMousePointAx(1, 1);
                case 'vertical'
                    newPosition = newMousePointAx(1, 2);
            end
            
            change = newPosition - obj.moveStartPosition;            

            barInitialPosition = min(obj.barInitialCoords);
            change = obj.checkMoveLimits(change, barInitialPosition);
            
            
            % Todo: Make change part of an eventdata object.
            if ~isempty(obj.StopMoveCallback)
                obj.StopMoveCallback(obj, change./obj.Maximum) % Todo: Change this, (e.g. add both change and maximum to eventdata... Update dependent apps)
            end
            
            obj.barInitialCoords = [];

        end % /stopScrollbarMove
        
        function jumpToNewValue(obj, ~, ~)
        %jumpToNewValue Callback for when mouse is pressed on track.
        %
        %   This method will update the bar position based on mousepress on
        %   the scroller track. The bar will jump to a new position.
        
            % Get change of scroller
            newMousePointAx = get(obj.hScrollbarAxes, 'CurrentPoint');
            
            switch lower(obj.Orientation)
                case 'horizontal'
                    newPosition = newMousePointAx(1, 1);
                    currentPosition = min(obj.hScrollbar(2).XData);
                case 'vertical'
                    newPosition = newMousePointAx(1, 2);
                    currentPosition = min(obj.hScrollbar(2).YData);
            end

            change = newPosition - currentPosition;
            change = obj.checkMoveLimits(change, currentPosition);

            % Update scrollbar value
            newValue = currentPosition + change;
            obj.Value = newValue;

            % Todo: Make change part of an eventdata object.
            if ~isempty(obj.StopMoveCallback)
                obj.StopMoveCallback(obj, change./obj.Maximum)
            end

        end % /jumpToNewValue
        
    end % /methods
    
    
    methods
        
        function position = get.barPosition(obj)
            
            if isempty(obj.barInitialCoords)
                switch lower(obj.Orientation)
                    case 'horizontal'
                        scrollerData = obj.hScrollbar(2).XData;
                    case 'vertical'
                        scrollerData = obj.hScrollbar(2).YData;
                end
            else
                scrollerData = obj.barInitialCoords;
            end

            position = min(scrollerData);

        end
        
    end
    
    methods (Access = private)
        
        
        function createScrollbar(obj)
        %createScrollbar Initialize the scrollbar graphical objects.

            if ~isvalid(obj.hParent); return; end
        
            % Create an axes object to plot the scrollbar in
            obj.hScrollbarAxes = axes('Parent', obj.hParent);
            obj.hScrollbarAxes.Units = obj.Units;
            obj.hScrollbarAxes.Position = obj.Position;
            obj.hScrollbarAxes.Tag = 'Scrollbar Axes';

            % Set axes limits to "normalized" units.
            obj.hScrollbarAxes.Visible = 'off';
            hold(obj.hScrollbarAxes, 'on')
            obj.hScrollbarAxes.XLim = [0,1];
            obj.hScrollbarAxes.YLim = [0,1];
            
            obj.hScrollbarAxes.YDir = 'reverse'; % Scroll from top to bottom
            
            % Determine if scroller should be horizontal or vertical
            axPixelPos = getpixelposition(obj.hScrollbarAxes);
            AR = axPixelPos(3)/axPixelPos(4);
            if AR > 1
                obj.Orientation = 'horizontal';
            else
                obj.Orientation = 'vertical';
            end
            
            switch lower(obj.Orientation)
                case 'horizontal'
                    xDataTrack = [0,1,1,0];
                    yDataTrack = [0,0,1,1];
                    xDataBar = [0,0,0,0];
                    yDataBar = [0.35,0.35,0.65,0.65];
                case 'vertical'
                    xDataTrack = [0.3,0.3,0.7,0.7];
                    yDataTrack = [1,0,0,1];
                    xDataBar = [0.35,0.35,0.65,0.65];
                    yDataBar = [0,0,0,0];
            end
            
            % Plot the "scroller track" and the scrollerbar
            obj.hScrollbar = gobjects(2,1);
            obj.hScrollbar(1) = patch(xDataTrack, yDataTrack, obj.TrackColor);
            obj.hScrollbar(2) = patch(xDataBar, yDataBar, obj.BarColor);
            obj.hScrollbar(2).FaceAlpha = 0.6;
            set(obj.hScrollbar, 'Parent', obj.hScrollbarAxes)
            set(obj.hScrollbar, 'Visible', obj.Visible)

            % Tag scroller handles
            obj.hScrollbar(1).Tag = 'Sidebar';
            obj.hScrollbar(2).Tag = 'Scrollbar';
            
            % Assign methods for when scroller handles are pressed.
            obj.hScrollbar(1).ButtonDownFcn = @obj.jumpToNewValue;
            obj.hScrollbar(2).ButtonDownFcn = @obj.startScrollbarMove;
            
            obj.hScrollbar(1).Visible = 'off';
            obj.hScrollbar(2).Visible = obj.Visible;
            set(obj.hScrollbar, 'EdgeColor', 'none')
            obj.updateBarLength()
            
        end % /createScrollbar
        
        
        function onValueChanged(obj)
        %onValueChanged Execute callback on Value change (bar is moved).
            if ~isempty(obj.Callback)
                obj.Callback(obj, [])
            end
        end % /onValueChanged
        
        
        function onPositionChanged(obj)
            if obj.isInitialized
                if any( obj.hScrollbarAxes.Position(3:4) ~=  obj.Position(3:4))
                    obj.redraw()
                end
                obj.hScrollbarAxes.Position = obj.Position;
            end
        end
        
        
        function onVisibleChanged(obj)
            
            if obj.isInitialized
                switch obj.Visible
                    case 'on'
                        obj.show()
                    case 'off'
                        obj.hide()
                end
            end
            
        end
        
        
        function updateBarLength(obj)
        %updateBarLength Update scrollerbar height.
        
            if ~obj.isInitialized; return; end
        
            axSize = getpixelposition(obj.hScrollbarAxes);
            axSize = axSize(3:4);
            
            if obj.VisibleAmount == inf
                obj.VisibleAmount = 0;
            end
            
            % Todo: Implement obj.Minimum
            newAxesLimits = [0, obj.Maximum]; % + [-1, 1] .* obj.VisibleAmount/2;
            axesRange = obj.Maximum; % + obj.VisibleAmount;
            
            switch lower(obj.Orientation)
                case 'horizontal'
                    isDim = [0, 1];
                    obj.hScrollbarAxes.XLim = newAxesLimits;
                    barLength = axSize(1) .* obj.VisibleAmount ./ axesRange;
                    barSize = round( [barLength, obj.BarWidth] );
                case 'vertical'
                    isDim = [1, 0];
                    obj.hScrollbarAxes.YLim = newAxesLimits;
                    barLength = axSize(2) .* obj.VisibleAmount ./ obj.Maximum;
                    barSize = round( [obj.BarWidth, barLength] );
            end
            
            obj.updateTrackLimits() % since axes limits was changed...
            
            % Get coordinates for scrollbar patch.
            [edgeX, edgeY] = uim.shape.rectangle(barSize, obj.BarWidth/2);
            coords = uim.utility.px2du(obj.hScrollbarAxes, [edgeX', edgeY']);
            
            % Correct so that minimum is at (0,0)
            coords = coords - min(coords);
            
            % Center on shortest dimension
            coords = coords + (1-range(coords(:, :)))/2 .* isDim;
            
            % Set new coordinates of scrollbar patch
            set(obj.hScrollbar(2), 'XData', coords(:,1), 'YData', coords(:,2));
            obj.updateBarPosition()
            drawnow limitrate
            
        end % /updateBarLength
    

        function updateBarPosition(obj)
        %updateBarPosition Update scrollerbar position
        %
        % Mostly relevant if value is change from external source...
        
            if obj.isInitialized

                if isempty(obj.barInitialCoords)
                    switch lower(obj.Orientation)
                        case 'horizontal'
                            scrollerData = obj.hScrollbar(2).XData;
                        case 'vertical'
                            scrollerData = obj.hScrollbar(2).YData;
                    end
                else
                    scrollerData = obj.barInitialCoords;
                end

                scrollerPos = min(scrollerData);

                % Get shift of scroller
                change = obj.Value - scrollerPos;

                % Make sure scroller stays within bar range
                change = obj.checkMoveLimits(change, scrollerPos); 
                
                % Update the position of the scrollbar
                switch lower(obj.Orientation)
                    case 'horizontal'
                        obj.hScrollbar(2).XData =  scrollerData + change;
                    case 'vertical'
                        obj.hScrollbar(2).YData =  scrollerData + change;
                end
                
            end
            
        end % /updateBarPosition
        

        function updateTrackLimits(obj)

            
            switch lower(obj.Orientation)
                case 'horizontal'
                    xDataTrack = obj.hScrollbarAxes.XLim([1,2,2,1]);
                    obj.hScrollbar(1).YData = xDataTrack;

                case 'vertical'
                    yDataTrack = obj.hScrollbarAxes.YLim([2,1,1,2]);
                    obj.hScrollbar(1).YData = yDataTrack;
            end
            
        end

        
    end % /methods (private)
    
    
end % /classdef