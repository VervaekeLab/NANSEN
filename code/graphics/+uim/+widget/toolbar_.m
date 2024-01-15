classdef toolbar_ < uim.abstract.Container
    
    % Check out dropbox paper toolbar.
    
    % todo: 
    %
    %   [x] add separator... I think this is done
    %   [ ] Implement orientation functionality. See uim.widget.toolbar
    %   [ ] Make sure button size is adapted to toolbar size + padding.
    %   [x] Rename BackgroundMode to ContainerMode (move to container?)
    %   [ ] Remove DarkMode property. Use Style
    %   [ ] Move dimL_ and dimS_ to component or container??
    %   [ ] Move spacing to Container
    %   [ ] Move componentAlignment to component? Actually, is this the
    %       same as reference points??? Componentalignment is only relevant
    %       if containermode is "wrap"
    %   [ ] Simplify orientation-related properties. I.e now, there is
    %       IsFixedSize, dimL_, dimS, Orientation. COmment later: YES, this
    %       is confusing!
    %   [ ] Style
    %   [ ] Make it clearer what shiftChildren and repositionButtons do,
    %   and how they are different...
    %   [x] Resolve how to combine backgroundmode 'wrap' and canvasMode 'private'
    
    
    properties (Constant, Transient)
        Type = 'Toolbar'
    end
    
    properties (SetAccess = protected, Transient)
        Children uim.abstract.Component
    end
    
    properties
        Spacing = 8 % move to widget container
        DarkMode = 'on'
        ComponentAlignment = 'left' % %center | 'right'
        Style = []
        BackgroundMode = 'wrap' % vs full...
        BarExtensionMode = 'tight' % vs expanded % Determines if the bar is tight around the buttons or if it is expanded to fill the available length of the container
    end
    
    properties (Dependent)
        Height = 30 % move to widget container
        Width = 30 % move to widget container
        Orientation = ''
    end
    
    properties (Dependent, Transient, Access = private)
        DimL_ (1,1) double  % Long Dimension
        DimS_ (1,1) double  % Short dimension
    end
    
    properties (Access = public)
        NewButtonSize double = 25; % Size of new buttons in pixels (default=40)
        NextButtonPosition (1,4) double = zeros(1,4) % Position (x,y) of next button
        AllButtonPosition = zeros(0,4) % for faster repositioning
        NumButtons (1,1) double = 0
    end
    
    properties (Access = protected, Transient)
        hButtons uim.abstract.Component
        ButtonSizeChangedListener event.listener
    end
    
    
    methods % Structors
                    
        function obj = toolbar_(hParent, varargin)

            obj@uim.abstract.Container(hParent, varargin{:})
            
            % Toolbar specific construction....
            
            obj.IsConstructed = true;
            
            obj.setNextButtonPosition()
            
        end

        function delete(obj)
            % Delete all buttons and separators.
            delete(obj.hButtons)
            delete(obj.ButtonSizeChangedListener)
        end
    end
    
    methods % Methods to add toolbar objects
                
        function hSep = addSeparator(obj, varargin)
        %addSeparator Add separator between buttons
            
            separatorPosition = obj.NextButtonPosition;
            
            % todo: switch orientation...
            separatorPosition(3) = 0;
            
            varargin = [{'Position', separatorPosition, ...
                         'Size', separatorPosition(3:4), ...
                         'PositionMode', 'manual', ...
                         'SizeMode', 'manual'}, varargin, ...
                         'Visible', obj.Visible];
                    
            hSep = uim.decorator.Separator(obj, varargin{:});

            % Add listener for SizeChanged event on button
            el = addlistener(hSep, 'SizeChanged', @obj.onButtonSizeChanged);
            obj.ButtonSizeChangedListener(end+1) = el;
            
            obj.AllButtonPosition(end+1, :) = hSep.Position;
            
            % Todo: Fix this!
            try
                obj.hButtons(end+1) = hSep;
            catch
                obj.hButtons = cat(2, obj.hButtons, hSep);
            end
            
            obj.NumButtons = obj.NumButtons+1;
            
            obj.adjustButtonPositions()
            obj.setNextButtonPosition()
            
            if ~nargout 
                clear hSep
            end
            
        end
        
        function hButton = addButton(obj, varargin)

            % Specify some toolbar defaults for toolbar button.
            varargin = [{'Position', obj.NextButtonPosition, ...
                        'Style', obj.Style}, ...
                        'Size', obj.NextButtonPosition(3:4), ...
                        'Padding', [3,3,3,3], ...
                        'Visible', obj.Visible, varargin, ...
                        'PositionMode', 'manual', ...
                        'Visible', obj.Visible];
            
            % Concatenate with varargin at the end. Input parser will
            % choose the last entry (if there are duplicates) during parsing.
            
            hButton = uim.control.Button_(obj, varargin{:});
            
            % Add listener for SizeChanged event on button
            el = addlistener(hButton, 'SizeChanged', @obj.onButtonSizeChanged);
            obj.ButtonSizeChangedListener(end+1) = el;
            
            obj.AllButtonPosition(end+1, :) = hButton.Position;
            obj.hButtons(end+1) = hButton;
            obj.Children(end+1) = hButton;

            obj.NumButtons = obj.NumButtons+1;
            
            obj.adjustButtonPositions()
            obj.setNextButtonPosition()
           
            if strcmp(obj.BarExtensionMode, 'tight')
                obj.updateSize()
            end
            
            % Update location after buttons are created..
            if strcmp(obj.PositionMode, 'auto')
                %todo: how to do this?
                %obj.updateLocation()
            end
            
            if ~nargout
                clear hButton 
            end
            
        end
        
        function h = getHandle(obj, tagValue)
            
            tags = {obj.hButtons.Tag};
            ind = contains(tags, tagValue);
            h = obj.hButtons(ind);
            
        end
                
        function relocate(obj, shift)
            relocate@uim.abstract.Component(obj, shift)
            obj.shiftChildren(shift)
        end
        
        function onButtonSizeChanged(obj, src, evt)
        %onButtonSizeChanged Update buttonsize and reposition all other buttons
            
            isButton = ismember(obj.hButtons, src);
            obj.AllButtonPosition(isButton, :) = src.Position;
            obj.repositionButtons()
            
        end
        
        function updateLocation(obj, mode)
            if nargin < 2; mode = obj.PositionMode; end
            updateLocation@uim.abstract.Component(obj, mode)
            
            switch obj.BarExtensionMode
                case 'expanded'
                    obj.adjustButtonPositions()
            end
        end
        
        function updateSize(obj, mode)
            if nargin < 2; mode = obj.PositionMode; end
            if ~obj.IsConstructed; return; end
            
            switch obj.BarExtensionMode
                case 'expanded'
                    updateSize@uim.abstract.Component(obj, mode)
                    obj.adjustButtonPositions()

                case 'tight'
                    obj.setBarSizeToTight()
                    
            end
        end
        
    end
    
    methods (Access = protected)

        function setBarSizeToTight(obj)
        % setBarSizeToTight - Make toolbar size tight around buttons.
            
            dimL = obj.DimL_;
            dimS = obj.DimS_;
            
            if obj.NumButtons == 0
                minPositionL = 0;
                maxPositionL = 0;
            else
                minPositionL = min(obj.AllButtonPosition(:, dimL), [], 1);
                maxPositionL = max( sum(obj.AllButtonPosition(:, [dimL, dimL+2]),2), [], 1);
            end

            extent = zeros(1,2);
            extent(dimL) = maxPositionL - minPositionL + sum(obj.Padding([dimL, dimL+2]));
            if obj.NumButtons == 0
                extent(dimS) = obj.CanvasPosition(dimS+2);
            else
                extent(dimS) = max(obj.AllButtonPosition(:, dimS+2), [], 1);
            end

            minPos = zeros(1,2);
            minPos(dimL) = minPositionL - obj.Padding(dimL);
            minPos(dimS) = obj.CanvasPosition(dimS);
            
            obj.Position_(3:4) = extent;

        end
        
        function setNextButtonPosition(obj)
            
            if isempty(obj.AllButtonPosition) % Initialize
                lastButtonPosition = [obj.CanvasPosition(1:2) + obj.Padding(1:2), 0, 0];
            else
                lastButtonPosition = obj.AllButtonPosition(end, :);
            end
            
            i = obj.DimL_;
            j = obj.DimS_;
            
            spacing = obj.Spacing .* double(obj.NumButtons>0);
            
            pos(i) = sum(lastButtonPosition([i,i+2])) + spacing;
            pos(j) = obj.CanvasPosition(j) + obj.Padding(j);
            pos(3:4) = obj.NewButtonSize;
            
            
            obj.NextButtonPosition = pos;
        end
        
        function adjustButtonPositions(obj)
        %adjustButtonPositions Adjust positions of buttons
        %
        %   Use when adding more buttons (i.e if they are centered or 
        %   right-aligned)
        
            if ~obj.IsConstructed; return; end
            if obj.NumButtons == 0; return; end
            
            % Resolve what is the long and short dimension (x=1, y=2)
            dimL = obj.DimL_;
            dimS = obj.DimS_;
            
            shift = [0, 0];

            
            minPosition = min(obj.AllButtonPosition(:, dimL), [], 1);
            maxPosition = max( sum(obj.AllButtonPosition(:, [dimL, dimL+2]),2), [], 1);
            extent = maxPosition - minPosition;
            
            if any( strcmp(obj.ComponentAlignment, {'left', 'top'}) )
                targetPosition = obj.CanvasPosition(dimL) + obj.Padding(dimL);
                offset = targetPosition - minPosition;
            
            elseif any( strcmp(obj.ComponentAlignment, {'center', 'middle'}) )
                centerPosition = obj.CanvasPosition(dimL) + obj.Position(dimL+2)/2;
                offset = centerPosition - (minPosition + extent/2);

%                 if strcmp(obj.CanvasMode, 'private') % Todo: Debug
%                     offset = offset/2;
%                 end
            end
            
            if  any( strcmp(obj.ComponentAlignment, {'right', 'bottom'}) )
                targetPosition = sum(obj.CanvasPosition([dimL, dimL+2])) - obj.Padding(dimL+2) - extent;
                offset = targetPosition-minPosition;
            end
            
            shift(dimL) = offset;
            shift(dimS) = obj.CanvasPosition(dimS) - obj.AllButtonPosition(1, dimS) + obj.Padding(dimS);
            
            if any(shift ~= 0) 
                obj.shiftChildren(shift)
            end
            
            %shift
            
            obj.setNextButtonPosition()

            % todo: take care of when backgroundmode is wrap
            
            switch obj.CanvasMode
                case 'shared'
                    
                    if strcmp(obj.BackgroundMode, 'wrap')
                        obj.redrawBackground()
                    end
                    
                    %obj.setNextButtonPosition()

                case 'private' 
                    
                    axPosition = getpixelposition(obj.CanvasAxes);
                    axPosition(1:2) = axPosition(1:2) + shift;
                    setpixelposition(obj.CanvasAxes, axPosition);
            end
            
            
        end
        
        function repositionButtons(obj)
        % Use when one or more button sizes change               
            if ~obj.IsConstructed; return; end
            if obj.NumButtons == 0; return; end
            
            buttonExtents = sum(obj.AllButtonPosition(:, obj.DimL_+2), 1);
                        
            toolbarLocation = obj.Position(obj.DimL_) + obj.Padding(obj.DimL_);
            toolbarSize = obj.Position(obj.DimL_+2) - obj.Padding(obj.DimL_) - obj.Padding(obj.DimL_+2);
            
            anchorPoint = toolbarLocation;
            
            if any( strcmp(obj.ComponentAlignment, {'left', 'top'}) )
                % Pass
            elseif any( strcmp(obj.ComponentAlignment, {'center', 'middle'}) )
                anchorPoint = anchorPoint + toolbarSize/2 - buttonExtents/2;
            elseif any( strcmp(obj.ComponentAlignment, {'right', 'bottom'}) )
                anchorPoint = anchorPoint + toolbarSize - buttonExtents;
            end
            
            
            % Start replacing buttons starting from left/top
            for i = 1:numel(obj.hButtons)
                obj.hButtons(i).Position(obj.DimL_) = anchorPoint;
                obj.AllButtonPosition(i,obj.DimL_) = anchorPoint;
                anchorPoint = anchorPoint + obj.hButtons(i).Position(obj.DimL_+2) + obj.Spacing;
            end
            
            if strcmp(obj.BackgroundMode, 'wrap')
                obj.redrawBackground()
            end
            
            setNextButtonPosition(obj)
            
        end
        
        function onSpacingChanged(obj, deltaSpacing)
            
            if ~obj.IsConstructed; return; end
            
            shifts = zeros(obj.NumButtons, 2);
            shifts(:, obj.DimL_) = deltaSpacing .* (0:obj.NumButtons-1);
            
            for i = 1:obj.NumButtons
                obj.hButtons(i).Position(1:2) = obj.hButtons(i).Position(1:2) + shifts(i,:);
                obj.AllButtonPosition(i,:) = obj.hButtons(i).Position;
            end
    
            if strcmp(obj.BackgroundMode, 'wrap')
                obj.redrawBackground()
            end
            
        end
        
        function shiftChildren(obj, shift)
            
            for i = 1:obj.NumButtons
                obj.hButtons(i).Position(1:2) = obj.hButtons(i).Position(1:2) + shift(1:2);
                obj.AllButtonPosition(i,:) = obj.hButtons(i).Position;
            end
        end
    
        function redrawBackground(obj)
            
            if ~isempty(obj.hBackground) && obj.IsConstructed
                redrawBackground@uim.abstract.Component(obj)
                return
            
                switch obj.BackgroundMode
                    case 'full'
                        redrawBackground@uim.abstract.Component(obj)
                        
%                         [X, Y] = uim.shape.rectangle(obj.Size, obj.CornerRadius);
%                         X = X + obj.Position(1);
%                         Y = Y + obj.Position(2);
                    case 'wrap'
                        
                        if obj.NumButtons == 0
                            minPositionL = 0;
                            maxPositionL = 0;
                        else
                            minPositionL = min(obj.AllButtonPosition(:, obj.DimL_), [], 1);
                            maxPositionL = max( sum(obj.AllButtonPosition(:, [obj.DimL_, obj.DimL_+2]),2), [], 1);
                        end
                        
                        
                        extent = zeros(1,2);
                        extent(obj.DimL_) = maxPositionL - minPositionL + sum(obj.Padding([obj.DimL_, obj.DimL_+2]));
                        extent(obj.DimS_) = obj.CanvasPosition(obj.DimS_+2);
                        
                        minPos = zeros(1,2);
                        minPos(obj.DimL_) = minPositionL - obj.Padding(obj.DimL_);
                        minPos(obj.DimS_) = obj.CanvasPosition(obj.DimS_);
                        
                        [X, Y] = uim.shape.rectangle(extent, obj.CornerRadius);
                        X = X + minPos(1);
                        Y = Y + minPos(2);
                        
                        set(obj.hBackground, 'XData', X, 'YData', Y)

                    otherwise
                        error('This should not happen!')
                        
                end
                
            end
            
            %drawnow limitrate
            
        end
        
        function updateButtonStyle(obj)
            
            if ~obj.IsConstructed; return; end
            
            switch obj.DarkMode
                case 'on'
                    style = uim.style.buttonDarkMode;
                case 'off'
                    style = uim.style.buttonLightMode2;
            end
            
            for i = 1:numel(obj.hButtons)
                if isa(obj.hButtons(i), 'uim.control.Button')
                    obj.hButtons(i).Style = style;
                end
            end
            
        end
        
        function updateBackgroundAppearance(obj)
            
            switch obj.DarkMode
                case 'on'
                    obj.BackgroundAlpha = 0.2;
                    obj.BackgroundColor = 'k';
                case 'off'
                    obj.BackgroundAlpha = 0.7;
                    obj.BackgroundColor = 'w';
            end
            
            obj.hBackground.FaceAlpha = obj.BackgroundAlpha;
            obj.hBackground.FaceColor = obj.BackgroundColor;
        end
        
        function onVisibleChanged(obj, newValue)
            obj.hBackground.Visible = newValue;
            for i = 1:obj.NumButtons
                obj.hButtons(i).Visible = newValue;
            end
        end    
        
    end
    
    methods % Set/get
        
        function style = get.Style(obj)
            switch obj.DarkMode
                case 'on'
                    style = uim.style.buttonDarkMode;
                case 'off'
                    style = uim.style.buttonLightMode;
            end
        end
        
        function set.DarkMode(obj, newValue)
            validatestring(newValue, {'on', 'off'}, 'Value must be on or off');
            obj.DarkMode = newValue;
            obj.updateBackgroundAppearance()
            obj.updateButtonStyle()
        end
        
        function set.Spacing(obj, newValue)
            
            if newValue ~= obj.Spacing
                deltaSpacing = newValue - obj.Spacing;
                obj.onSpacingChanged(deltaSpacing);
                obj.Spacing = newValue;
            end
            
        end
        
        function set.ComponentAlignment(obj, newValue)
            if ~isequal(newValue, obj.ComponentAlignment)
                obj.ComponentAlignment = newValue;
                obj.adjustButtonPositions()
            end
        end
        
        function set.BarExtensionMode(obj, newValue)
            validatestring(newValue, {'tight', 'expanded'});
            obj.BarExtensionMode = newValue;
            obj.updateLocation(obj.PositionMode)
            obj.updateSize()
        end
        
        function set.BackgroundMode(obj, newValue)
            
            validatestring(newValue, {'full', 'wrap'});
            
            if ~isequal(newValue, obj.BackgroundMode)
                obj.BackgroundMode = newValue;
                obj.redrawBackground()
            end
        end
        
        function set.Height(obj, newValue)
            obj.Size(2) = newValue;
        end
        
        function height = get.Height(obj)
            height = obj.Size(2);
        end
        
        function set.Width(obj, newValue)
            obj.Size(1) = newValue;
        end
        
        function width = get.Width(obj)
            width = obj.Size(1);
        end
        
        function value = get.DimL_(obj)
            if obj.IsFixedSize(1) && ~obj.IsFixedSize(2) % X is fixed
                value = 2;
            elseif obj.IsFixedSize(2) && ~obj.IsFixedSize(1) % Y is fixed
                value = 1;
            else
                error('Something is wrong with toolbar configuration')
            end
        end
        
        function value = get.DimS_(obj)
            if obj.IsFixedSize(2) && ~obj.IsFixedSize(1) % Y is fixed
                value = 2;
            elseif obj.IsFixedSize(1) && ~obj.IsFixedSize(2) % X is fixed
                value = 1;
            else
                error('Something is wrong with toolbar configuration')
            end
        end
        
        function set.Orientation(obj, newValue)
            switch newValue
                case 'horizontal'
                    obj.IsFixedSize = [false, true];
                case 'vertical'
                    obj.IsFixedSize = [true, false];
            end
        end
        
        function value = get.Orientation(obj)
            longDim = obj.DimL_;
            if longDim == 1 % x
                value = 'horizontal';
            elseif longDim == 2 % y 
                value = 'vertical';
            end
        end
        
    end
    
    methods (Static)
        function S = getTypeDefaults()
            S.PositionMode = 'auto';
            S.Location = 'northwest';
            S.Margin = [0, 0, 0, 0];
            
            S.IsFixedSize = [false, true];
            S.Size = [30, 30];

            S.HorizontalAlignment = 'left';
            S.VerticalAlignment = 'bottom';

            S.Padding = [10, 3, 10, 3];

            S.MinimumSize = [30, 30];
            S.MaximumSize = [inf, inf];
            
            S.BackgroundColor = 'k';
            S.BackgroundAlpha = 0.2;
        end
    end
    
    
end