classdef toolbar < uim.abstract.virtualContainer & uim.mixin.assignProperties
    
    % Check out dropbox paper toolbar.
    % Add flag for whether container border should wrap contents or not.
    
    % todo: add separator...
    
    % Todo: Make sure button size is adapted to toolbar size + padding.
    
    % Todo: If the toolbar background mode is wrap, should recalculate
    % size, i.e should not use full size...!
    
    properties
        Spacing = 8 % move to widget container
        DarkMode = 'on'
        ComponentAlignment = 'left' % %center | 'right'
        Style = []
        BackgroundMode = 'wrap' % vs full...
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
        hButtons uim.abstract.virtualContainer
        ButtonSizeChangedListener event.listener
    end
    
    
    methods % Structors
                    
        function obj = toolbar(hParent, varargin)

            %obj@uim.abstract.virtualContainer(hParent)

            el = listener(hParent, 'SizeChanged', ...
                @obj.onParentContainerSizeChanged);
            obj.ParentContainerSizeChangedListener = el;
            
            obj.Parent = hParent;
            obj.Canvas = hParent;
            obj.hAxes = obj.Canvas.Axes;
            
            
            obj.parseInputs(varargin{:})

            obj.createBackground()

            obj.IsConstructed = true;

            
            % Todo: This is not perfect. Sometimes size depends on
            % location...
            
            % Check if position was set different than default. if so, mode is manual
            
            % Call updateSize to trigger size update (call before location)
            obj.updateSize('auto')
            
            % Call updateLocation to trigger location update
            obj.updateLocation('auto')
            
            obj.onStyleChanged()
            
            
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
            
            
            separatorPosition = obj.NextButtonPosition;
            % todo: switch orientation...
            separatorPosition(3) = 0;
            
            varargin = [{'Position', separatorPosition, ...
                        'Size', separatorPosition(3:4) }, varargin];
                    
            hSep = uim.control.toolbarSeparator(obj, varargin{:});

            % Add listener for SizeChanged event on button
            el = addlistener(hSep, 'SizeChanged', @obj.onButtonSizeChanged);
            obj.ButtonSizeChangedListener(end+1) = el;
            
            obj.AllButtonPosition(end+1, :) = hSep.Position;
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
                        'PositionMode', 'manual'];
            % Concatenate with varargin at the end. Input parser will
            % choose the last entry (if there are duplicates) during parsing.
            
            hButton = uim.control.Button(obj, varargin{:});
            
            % Add listener for SizeChanged event on button
            el = addlistener(hButton, 'SizeChanged', @obj.onButtonSizeChanged);
            obj.ButtonSizeChangedListener(end+1) = el;
            
            obj.AllButtonPosition(end+1, :) = hButton.Position;
            obj.hButtons(end+1) = hButton;
            obj.NumButtons = obj.NumButtons+1;
            obj.adjustButtonPositions()
            obj.setNextButtonPosition()
            
            if isempty(obj.Children)
                obj.Children = hButton;
            else
                obj.Children(end+1) = hButton;
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
            relocate@uim.abstract.virtualContainer(obj, shift)
            obj.shiftChildren(shift)
        end
        
        function onButtonSizeChanged(obj, src, evt)
            
            isButton = ismember(obj.hButtons, src);
            obj.AllButtonPosition(isButton, :) = src.Position;
            obj.repositionButtons()
            
        end
        
        function updateLocation(obj, mode)
            if nargin < 2; mode = obj.PositionMode; end
            updateLocation@uim.abstract.virtualContainer(obj, mode)
            obj.adjustButtonPositions()
        end
        
        function updateSize(obj, mode)
            if nargin < 2; mode = obj.PositionMode; end
            updateSize@uim.abstract.virtualContainer(obj, mode)
            obj.adjustButtonPositions()
        end
        
        function onVisibleChanged(obj, newValue)
            obj.hBackground.Visible = newValue;
            for i = 1:obj.NumButtons
                obj.hButtons(i).Visible = newValue;
            end
        end
        
    end
    
    methods (Access = protected)
               
        function parseInputs(obj, varargin)
            S = obj.getToolbarDefaults;
            
            propNames = varargin(1:2:end);
            propValues = varargin(2:2:end);
            
            for i = 1:numel(propNames)
                S.(propNames{i}) = propValues{i};
            end
            
            C = cat(1, fieldnames(S)', struct2cell(S)');
            C = C(:)';
            
            parseInputs@uim.mixin.assignProperties(obj, C{:})
        end 
    end
    
    methods (Access = protected)

        function setNextButtonPosition(obj)
            
            if isempty(obj.AllButtonPosition)
                lastButtonPosition = [obj.Position(1:2)+obj.Padding(1:2),0,0];
            else
                lastButtonPosition = obj.AllButtonPosition(end, :);
            end
            
            i = obj.DimL_;
            j = obj.DimS_;
            
            spacing = obj.Spacing .* double(obj.NumButtons>0);
            
            pos(i) = sum(lastButtonPosition([i,i+2])) + spacing;
            pos(j) = obj.Position(j) + obj.Padding(j);
            pos(3:4) = obj.NewButtonSize;
            
%             switch obj.orientation
%                 case 'horizontal'
%                     pos(1) = sum(lastButtonPosition([1,3])) + obj.Spacing;
%                     pos(2) = obj.Margin(2);
%                 case 'vertical'
%                     pos(2) = sum(lastButtonPosition([2,4])) + obj.Spacing;
%                     pos(1) = obj.Margin(1);
%             end
            
            obj.NextButtonPosition = pos;
        end
        
        function adjustButtonPositions(obj)
        % Use when adding more buttons (i.e if they are centered ro right-aligned)
            if ~obj.IsConstructed; return; end
            if obj.NumButtons == 0; return; end
            shift = [0, 0];
            
            minPosition = min(obj.AllButtonPosition(:, obj.DimL_), [], 1);
            maxPosition = max( sum(obj.AllButtonPosition(:, [obj.DimL_, obj.DimL_+2]),2), [], 1);
            extent = maxPosition - minPosition;
            
            if strcmp(obj.ComponentAlignment, 'left') || strcmp(obj.ComponentAlignment, 'top')
                targetPosition = obj.Position(obj.DimL_) + obj.Padding(obj.DimL_);
                offset = targetPosition - minPosition;
            
            elseif strcmp(obj.ComponentAlignment, 'center') || strcmp(obj.ComponentAlignment, 'middle')
                centerPosition = obj.Position(obj.DimL_) + obj.Position(obj.DimL_+2)/2;
                offset = centerPosition - (minPosition + extent/2);

            end
            
            if strcmp(obj.ComponentAlignment, 'right') || strcmp(obj.ComponentAlignment, 'bottom')
                targetPosition = sum(obj.Position([obj.DimL_,obj.DimL_+2])) - obj.Padding(obj.DimL_+2) - extent;
                offset = targetPosition-minPosition;
            end
            
            shift(obj.DimL_) = offset;
            shift(obj.DimS_) = obj.Position(obj.DimS_) - obj.AllButtonPosition(1, obj.DimS_) + obj.Padding(obj.DimS_);
            obj.shiftChildren(shift)
            
            if strcmp(obj.BackgroundMode, 'wrap')
                obj.updateBackground()
            end
            
            obj.setNextButtonPosition()
            
        end
        
        function repositionButtons(obj)
        % Use when one or more button sizes change               
            if ~obj.IsConstructed; return; end
            if obj.NumButtons == 0; return; end
            
            buttonExtents = sum(obj.AllButtonPosition(:, obj.DimL_+2), 1);
                        
            toolbarLocation = obj.Position(obj.DimL_) + obj.Padding(obj.DimL_);
            toolbarSize = obj.Position(obj.DimL_+2) - obj.Padding(obj.DimL_) - obj.Padding(obj.DimL_+2);
            
            if strcmp(obj.ComponentAlignment, 'left') || strcmp(obj.ComponentAlignment, 'top')
                anchorPoint = toolbarLocation;
            elseif strcmp(obj.ComponentAlignment, 'center') || strcmp(obj.ComponentAlignment, 'middle')
                anchorPoint = toolbarLocation + toolbarSize/2 - buttonExtents/2;
            elseif strcmp(obj.ComponentAlignment, 'right') || strcmp(obj.ComponentAlignment, 'bottom')
                anchorPoint = toolbarLocation + toolbarSize - buttonExtents;
            end
            
            % Start replacing buttons starting from left/top
            for i = 1:numel(obj.hButtons)
                obj.hButtons(i).Position(obj.DimL_) = anchorPoint;
                obj.AllButtonPosition(i,obj.DimL_) = anchorPoint;
                anchorPoint = anchorPoint + obj.hButtons(i).Position(obj.DimL_+2) + obj.Spacing;
            end
            
            if strcmp(obj.BackgroundMode, 'wrap')
                obj.updateBackground()
            end
            
            setNextButtonPosition(obj)
            
        end
        
        function changeSpacing(obj, deltaSpacing)
            
            if ~obj.IsConstructed; return; end
            
            shifts = zeros(obj.NumButtons, 2);
            shifts(:, obj.DimL_) = deltaSpacing .* (0:obj.NumButtons-1);
            
            for i = 1:obj.NumButtons
                obj.hButtons(i).Position(1:2) = obj.hButtons(i).Position(1:2) + shifts(i,:);
                obj.AllButtonPosition(i,:) = obj.hButtons(i).Position;
            end
    
            if strcmp(obj.BackgroundMode, 'wrap')
                obj.updateBackground()
            end
            
        end
        
        function shiftChildren(obj, shift)
            
            for i = 1:obj.NumButtons
                obj.hButtons(i).Position(1:2) = obj.hButtons(i).Position(1:2) + shift(1:2);
                obj.AllButtonPosition(i,:) = obj.hButtons(i).Position;
            end
        end
    
        function updateBackground(obj)
            
            if ~isempty(obj.hBackground) && obj.IsConstructed
                
                %S = struct('nPointsCurvature', obj.CornerRadius);
                
                switch obj.BackgroundMode
                    case 'full'
                        [X, Y] = obj.createBoxCoordinates(obj.Size, obj.CornerRadius);
                        X = X + obj.Position(1);
                        Y = Y + obj.Position(2);
                    case 'wrap'
                        minPositionL = min(obj.AllButtonPosition(:, obj.DimL_), [], 1);
                        maxPositionL = max( sum(obj.AllButtonPosition(:, [obj.DimL_, obj.DimL_+2]),2), [], 1);

                        extent = zeros(1,2);
                        extent(obj.DimL_) = maxPositionL - minPositionL + sum(obj.Padding([obj.DimL_, obj.DimL_+2]));
                        extent(obj.DimS_) = obj.Position(obj.DimS_+2);
                        
                        minPos = zeros(1,2);
                        minPos(obj.DimL_) = minPositionL - obj.Padding(obj.DimL_);
                        minPos(obj.DimS_) = obj.Position(obj.DimS_);
                        
                        [X, Y] = obj.createBoxCoordinates(extent, obj.CornerRadius);
                        X = X + minPos(1);
                        Y = Y + minPos(2);
                    otherwise
                        
                end
                
                set(obj.hBackground, 'XData', X, 'YData', Y)

                
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
                obj.changeSpacing(deltaSpacing);
                obj.Spacing = newValue;
            end
            
        end
        
        function set.ComponentAlignment(obj, newValue)
            if ~isequal(newValue, obj.ComponentAlignment)
                obj.ComponentAlignment = newValue;
                obj.adjustButtonPositions()
            end
        end
        
        function set.BackgroundMode(obj, newValue)
            
            validatestring(newValue, {'full', 'wrap'});
            
            if ~isequal(newValue, obj.BackgroundMode)
                obj.BackgroundMode = newValue;
                obj.updateBackground()
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
        function S = getToolbarDefaults()
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