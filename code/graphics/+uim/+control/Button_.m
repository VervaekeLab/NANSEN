classdef Button_ < uim.abstract.Control
    
    % Todo:
    %   [x] How to best implement push and toggle buttons. Mech. action...
    %   [ ] Maybe also have a mode prop which can be push and toggle...
    %   [ ] Setting Location prop at construction does not work.
    %   [ ] Need to update mouseover effect if button is moved when
    %   pressed.
    %   [x] Plot both icon and text
    %   [x] Implement extra appearances for when mouse is pressed and
    %       released. Should not depend on value...
    %   [ ] Allow icon to be filepath or raster-image
    %   [ ] Work more on icon/text placement
    %   [ ] Implement stylechange on button text & icon
    %   [ ] Tooltip
    %   [ ] implement togglebuttonlistener.... What was that about.
    %   [ ] Why does margin not work when button is places south or
    %       north...
    %   [ ] Fix horizontal and vertical text aligning.
    
    % Should icon resize when button resizes? yes...
    % Should there be property to scale icon to fit within button?
    % Should button automatically resize to fit text/icon?
    
    properties (Constant) % Inherited from Component
        Type = 'Button' % push / toggle % Todo: subclasses..
    end
    
    properties
                
        Text = ''
        Icon = ''
        Value = false
        
        Mode = 'pushbutton'
        MechanicalAction = 'Switch when released' % Switch when pressed, Switch until released, Switch when released
        % Switch = togglebutton, Latch = pushbutton
        
        Style = uim.style.buttonDarkMode
        
        UseDefaultIcon = false %Todo: Rename or reconsider...
        AutoWrapText = false % Similar to BarExtensionMode
        IconAlignment = 'left';
        IconSize = [nan, nan];
        IconTextSpacing = 5;
        
        FixedAspectRatio = true; % Do I need this?? Maybe sometime...
        
        %ButtonDownFcn = []
        %ButtonReleasedFcn = []
        
        % These properties should be moved to another class?
        HorizontalTextAlignment = 'left'
        VerticalTextAlignment = 'middle'
        
        FontName = 'helvetica'
        FontSize = 12
        FontWeight = 'normal'
        
        ToggleButtonListener event.listener = event.listener.empty
    end
    
    properties (Dependent)
        String string = '' %#ok<MDEPIN>
    end
    
    properties (Dependent, Transient)
        Extent % Needed? Not internally. Does any outside function use it?
    end
    
    properties (Access = protected, Transient)

        hForeground % Todo: remove
        
        hButtonIcon = gobjects(0,1)
        hButtonText = gobjects(0,1)
        buttonContextMenu % Move to control.
    end
    
    properties (Access = private, Dependent, Transient)
        MechanicalAction_ % Until I figure out a better solution for mode + mechanical action properties
    end
        
    methods % Structors
        
        function obj = Button_(varargin)
            
            obj@uim.abstract.Control( varargin{:} )

            % Create button foreground, i.e plot text label or icon.
            obj.create() % Todo...
            % Create will set up button foreground. This must happen after
            % all position based properties are set.
            
            obj.IsConstructed = true; % IsConstructed will trigger the drawing of the component....
            
            % Configure button interactive behavior.
            obj.hBackground.ButtonDownFcn = @obj.onMousePressed;
            obj.hBackground.HitTest = 'on';
            obj.hBackground.PickableParts = 'all';
            
            % Todo ... This should be done in a resize method...
            obj.autoWrapButtonText()
            obj.updateTextLocation() % Should happen in onConstructed...

            obj.changeAppearance()
            % This should be a parent class method
            obj.onVisibleChanged()
            obj.onFontStyleChanged()
            
        end
        
        function delete(obj)

            if ~isempty(obj.hButtonText) && isvalid(obj.hButtonText)
                delete(obj.hButtonText)
            end
            
            if ~isempty(obj.hButtonIcon) && isvalid(obj.hButtonIcon)
                delete(obj.hButtonIcon)
            end
            
            if ~isempty(obj.ToggleButtonListener)
                delete(obj.ToggleButtonListener)
            end
        end
    end
    
    methods (Hidden, Access = protected)
            
        function create(obj)
            
            obj.plotForeground()
            
        end
        
        function plotForeground(obj, updateFlag)
        %plotForeground Plot button foreground (Text or icon)
            
            % Todo:
        
            if nargin < 2; updateFlag = false; end
                
            if updateFlag
                delete(obj.hForeground)
                obj.plotButtonIcon();
            else
                if ~isempty(obj.hForeground); return; end
                
                if ~isempty(obj.Icon) % Give priority
                    obj.plotButtonIcon()
                end
                
                if ~isempty(obj.Text)
                    obj.plotButtonText()
                end
            end
        end
        
        function plotButtonText(obj)
        %plotButtonText Plot button text
            
            obj.hButtonText = text(obj.CanvasAxes, 0, 0, obj.Text);
            obj.hButtonText.VerticalAlignment = 'bottom';
            obj.hButtonText.Color = obj.ForegroundColor;
            obj.hButtonText.Interpreter = 'none';
            obj.hButtonText.FontUnits = 'pixels';
            obj.hButtonText.FontSize = obj.FontSize;
            obj.hButtonText.PickableParts = 'none';
            obj.hButtonText.HitTest = 'off';

            obj.updateTextLocation()
        end
        
        function updateButtonText(obj)
            if isempty(obj.hButtonText)
                obj.plotButtonText()
            else
                obj.hButtonText.String = obj.Text;
            end
            %obj.autoWrapButtonText()
            %obj.updateBackgroundSize()
        end
        
        function updateTextLocation(obj)
        %updateTextLocation Update location of the text within the button
            
            if ~obj.IsConstructed; return; end
        
            if isempty(obj.hButtonText); return; end
            
            % Todo (UI4) Create dependent properties for innerpostion
            buttonTextWidth = obj.hButtonText.Extent(3);
            buttonInnerWidth = obj.Position(3);
            
            buttonTextHeight = obj.hButtonText.Extent(4);
            buttonInnerHeight = obj.Position(4) - sum(obj.Padding([2,4]));
            
            % Align text horizontally within button:
            switch obj.HorizontalTextAlignment
                case 'left'
                    dX = obj.Padding(1);
                case 'center'
                    dX = (buttonInnerWidth - buttonTextWidth) / 2;
                case 'right'
                    dX = obj.Position(3) - obj.Padding(3) - buttonTextWidth;
            end
            
            % Align text vertically within button:
            switch obj.VerticalTextAlignment
                case 'bottom'
                    dY = obj.Padding(2);
                case 'middle'
                    dY = (obj.Position(4) - obj.hButtonText.Extent(4))/2;
                case 'top'
                    dY = obj.Position(4) - obj.Padding(4) - obj.hButtonText.Extent(4);
            end
            
            % Todo: Expand to more cases...
            if ~isempty(obj.Icon)
                dX = dX + obj.hButtonIcon.Width + obj.IconTextSpacing;
            end
            
            obj.hButtonText.Position(1:2) = obj.Position(1:2) + [dX, dY];
            
        end
        
        function autoWrapButtonText(obj)
            
            if obj.AutoWrapText
                pixelWidth = obj.hButtonText.Extent(3);
                obj.Position(3) = pixelWidth + obj.hButtonText.Margin*2 + sum(obj.Padding([1,3]));
            end
        end
        
        function plotButtonIcon(obj)
        %plotButtonIcon Plot button icon
        
            if strcmp(obj.Icon, 'x') ||  strcmp(obj.Icon, '>')
                obj.plotSymbol();
                return;
            end
            
            % Delete icon graphics if it already exists.
            if ~isempty(obj.hButtonIcon) && isvalid(obj.hButtonIcon)
                delete(obj.hButtonIcon)
            end
            
            % Use the imageVector to plot the icon
            obj.hButtonIcon = uim.graphics.imageVector(obj.Canvas.Axes, obj.Icon);

            % Imagevector are upside down... Should be taken care of
            % somewhere else...
            obj.hButtonIcon.flipud()

            % Prevent it from capturing clicks
            obj.hButtonIcon.PickableParts = 'none';
            obj.hButtonIcon.HitTest = 'off';

            obj.updateIconSize()

            % Align icon relative to anchor point.
            obj.hButtonIcon.VerticalAlignment = 'bottom';
            obj.hButtonIcon.HorizontalAlignment = 'left';

            obj.updateIconLocation()

% %             % Set color
% %             if ~obj.UseDefaultIcon
% %                 obj.hForeground.Color = obj.ForegroundColor;
% %             end
            
        end
        
        function updateIconSize(obj)
        %updateIconSize Update size of the icon within the button
        
            % Get aspect ratios of icon and button...
            iconAr = obj.hButtonIcon.Width / obj.hButtonIcon.Height;
            buttonAr = (obj.Position(3) - sum(obj.Padding([1,3]))) / ...
                            (obj.Position(4) - sum(obj.Padding([2,4])));
                        
            if all(~isnan(obj.IconSize))
                if iconAr > 1
                    obj.hButtonIcon.Width = obj.IconSize(1);
                else
                    obj.hButtonIcon.Height = obj.IconSize(2);
                end
            else
                %... in order to scale icon to fit within button
                if iconAr >= buttonAr
                    obj.hButtonIcon.Width = obj.Size(1) - sum(obj.Padding([1,3]));
                else
                    obj.hButtonIcon.Height = obj.Size(2) - sum(obj.Padding([2,4]));
                end
            end
        end
        
        function updateIconLocation(obj)
        %updateIconLocation Update location of the icon within the button
            
            if isempty(obj.hButtonIcon); return; end

            try
                iconSize = [obj.hButtonIcon.Width, obj.hButtonIcon.Height];
            catch
                iconSize = [obj.hButtonIcon.MarkerSize, obj.hButtonIcon.MarkerSize];
            end
            
            % Calculate offset deltaX
            switch obj.IconAlignment
                case 'left'
                    deltaX = obj.Padding(1);
                case 'center'
                    deltaX = (obj.Position(3) - iconSize(1)) / 2;
                case 'right'
                    deltaX = obj.Position(3) - obj.Padding(3) - iconSize(1);
            end
            
            % Calculate offset deltaY
            deltaY = (obj.Position(4) - iconSize(2)) / 2;
            
            obj.hButtonIcon.Position = obj.Position(1:2) + [deltaX, deltaY];
        end
        
        function plotSymbol(obj)
            
            assert(any(strcmp({'x', 'o', '>'}, obj.Icon)), 'Invalid symbol for button')
                
            x = obj.Position(1) + obj.Size(1)/2;
            y = obj.Position(2) + obj.Size(2)/2;
            
            obj.hButtonIcon = plot(obj.Canvas.Axes, x, y, obj.Icon);
            obj.hButtonIcon.MarkerSize = 12;
            obj.hButtonIcon.Color = obj.ForegroundColor;
            obj.hButtonIcon.LineWidth = 2;
            
            obj.hButtonIcon.PickableParts = 'none';
            obj.hButtonIcon.HitTest = 'off';
            
            %obj.updateForeground()

        end
        
        function changeAppearance(obj)
        %changeAppearance Update button appearance based on state
            
            %if ~obj.IsConstructed; return; end
            
            % 4 states:
            %   Mouse is over or not
            %   Button is activated or not.
            
            if obj.Value
                if obj.IsMouseOver && obj.IsMousePressed
                    newAppearance = 'HighlightedOn';
                elseif obj.IsMouseOver
                    newAppearance = 'HighlightedOn';
                else
                    newAppearance = 'On';
                end
            else
                if obj.IsMouseOver && obj.IsMousePressed
                    newAppearance = 'HighlightedOn';
                elseif obj.IsMouseOver
                    newAppearance = 'HighlightedOff';
                else
                    newAppearance = 'Off';
                end
            end
            
            % newAppearance
            
            obj.ForegroundColor = obj.Style.(newAppearance).ForegroundColor;
            obj.BackgroundColor = obj.Style.(newAppearance).BackgroundColor;
            obj.BackgroundAlpha = obj.Style.(newAppearance).BackgroundAlpha;
            obj.BorderColor = obj.Style.(newAppearance).BorderColor;
            obj.BorderWidth = obj.Style.(newAppearance).BorderWidth;

            if isfield(obj.Style.(newAppearance), 'FontWeight')
                obj.FontWeight = obj.Style.(newAppearance).FontWeight;
            end
            
            % Maybe use on styleChanged instead?
%             if ~obj.UseDefaultIcon
%                 obj.updateForeground()
%             end
            obj.onStyleChanged()
            %obj.updateBackground()
        end
        
        function onFontStyleChanged(obj)
            
            if ~obj.IsConstructed; return; end
            
            if ~isempty(obj.hButtonText)
                obj.hButtonText.FontName = obj.FontName;
                obj.hButtonText.FontSize = obj.FontSize;
                obj.hButtonText.FontWeight = obj.FontWeight;
                
                obj.updateTextLocation()
            end
        end
        
        function onMousePressed(obj, ~, event)
        %onMousePressed Callback to handle user button press
        
            onMousePressed@uim.abstract.Control(obj)
            
            switch obj.MechanicalAction_
                
                case 'Switch when pressed'
                    obj.Value = ~obj.Value;
                    obj.invokeCallback(event)
                    
                case 'Switch until released'
                    obj.Value = ~obj.Value;
                    obj.invokeCallback(event)
                    
                case 'Latch when pressed'
                    obj.Value = true;
                    obj.invokeCallback(event)
                    obj.Value = false;
                    
            end
        end
        
        function onMouseReleased(obj, ~, event)
        %onMouseReleased Callback to handle user button release
        
            onMouseReleased@uim.abstract.Control(obj)
                        
            switch obj.MechanicalAction_
                            
                case 'Switch until released'
                    obj.Value = ~obj.Value;
                    obj.invokeCallback(event)
                    
                case 'Switch when released'
                    obj.Value = ~obj.Value;
                    if obj.IsMouseOver
                        obj.invokeCallback(event)
                    end
                    
                case 'Latch when released'
                    obj.Value = true;
                    if obj.IsMouseOver
                        obj.invokeCallback(event)
                    end
                    
                    if isvalid(obj) % In those weird cases where this is an exit button
                        obj.Value = false;
                    end
            end
        end
        
        function invokeCallback(obj, event)
            
            if ~isempty(obj.Callback)
                obj.Callback(obj, event)
            end
        end
        
        function onVisibleChanged(obj, ~)
            if ~obj.IsConstructed; return; end
            
            % Change interactive behavior of background.
            switch obj.Visible
                case 'on'
                    obj.hBackground.PickableParts = 'all';
                case 'off'
                    obj.hBackground.PickableParts = 'visible';
            end
            
            % Set visibility of graphics components.
            obj.hBackground.Visible =  obj.Visible;

            if ~isempty(obj.hButtonIcon) && isa(obj.hButtonIcon, 'uim.graphics.imageVector')
                obj.hButtonIcon.Visible = obj.Visible;
            end
            if ~isempty(obj.hButtonText) && isgraphics(obj.hButtonText)
                obj.hButtonText.Visible = obj.Visible;
            end
        end
    end
    
    methods (Access = protected)
        
        function onStyleChanged(obj)
            onStyleChanged@uim.abstract.Component(obj)
            
            if obj.IsConstructed
                
                if ~isempty(obj.hButtonIcon) && isa(obj.hButtonIcon, 'uim.graphics.imageVector')
                    obj.hButtonIcon.Color = obj.ForegroundColor;
                end
                
                if ~isempty(obj.hButtonText) && isgraphics(obj.hButtonText)
                    obj.hButtonText.Color = obj.ForegroundColor;
                end
                
                if ~isempty(obj.hButtonText)
                    obj.hButtonText.FontWeight = obj.FontWeight;
                end
            end
        end
         
        function onSizeChanged(obj, oldPosition, newPosition)
            onSizeChanged@uim.abstract.Control(obj, oldPosition, newPosition);
            obj.updateTextLocation()
            obj.updateIconLocation()
       end
    end
    
    methods % Public

        function addToggleListener(obj, handle, eventName)
           el = listener(handle, eventName, @obj.toggleState);
           obj.ToggleButtonListener = el;
        end
        
        function relocate(obj, shift)
            relocate@uim.abstract.Component(obj, shift)
            
            if ~isempty(obj.hButtonIcon) && isa(obj.hButtonIcon, 'uim.graphics.imageVector')
                obj.hButtonIcon.translate(shift(1:2))
            elseif ~isempty(obj.hButtonIcon) && isa(obj.hButtonIcon, 'matlab.graphics.chart.primitive.Line')
                obj.hButtonIcon.XData = obj.hButtonIcon.XData + shift(1);
                obj.hButtonIcon.YData = obj.hButtonIcon.YData + shift(2);
            end
            
            if ~isempty(obj.hButtonText) && isa(obj.hButtonText, 'matlab.graphics.primitive.Text')
                obj.updateTextLocation()
                %obj.hButtonText.Position(1:2) = obj.hButtonText.Position(1:2)+shift(1:2);
            end
            
            obj.setTooltipPosition()
            
        end
        
        function toggleState(obj, ~, event)
        %toggleState Toggle the state (value) of the button.
        
        % Todo: make sure mechanical action is switch type...

            if obj.Value ~= event.Value
                obj.Value = event.Value;
                obj.changeAppearance()
            end
        end
    end
    
    methods % Set/Get
        
        function set.String(obj, value)
            obj.Text = value;
        end
        
        function value = get.String(obj)
            value = obj.Text;
        end
        
        function value = get.Extent(obj)
            
            if ~isempty(obj.hButtonText)
                offset = obj.hButtonText.Position(1:2) - obj.Position(1:2);
                extent = obj.hButtonText.Extent(3:4) + obj.Padding(3:4);
                value = [obj.Position(1:2), offset + extent];
                value(3:4) = max([obj.Position(3:4), value(3:4)]);
            elseif ~isempty(obj.hButtonIcon)
                
                error('Not implemented')
                
            end
        end
        
        function set.Text(obj, value)
            
            errMsg = 'Text property of button must be a character vector';
            assert(isa(value, 'char'), errMsg)
            
            obj.Text = value;
            
            if obj.IsConstructed
                obj.updateButtonText()
            end
        end
        
        function set.Icon(obj, value)
            
            errMsg1 = 'Icon property of button must be a pathstr';
            errMsg2 = 'Icon file was not found';
            
%             assert(isa(value, 'char'), errMsg1)
%             assert(exist(value, 'file')==2, errMsg2)
            
            obj.Icon = value;
            if obj.IsConstructed
                obj.plotButtonIcon()
            end
        end
        
        function set.Value(obj, newValue)
            obj.Value = newValue;
            obj.changeAppearance()
            % todo: Run callback???
        end
        
        function set.FontName(obj, value)
        	obj.FontName = value;
            obj.onFontStyleChanged()
        end
        
        function set.FontSize(obj, value)
            obj.FontSize = value;
            obj.onFontStyleChanged()
        end
        
        function set.FontWeight(obj, value)
            obj.FontWeight = value;
            obj.onFontStyleChanged()
        end
        
        function set.HorizontalTextAlignment(obj, value)
            value = validatestring(value, {'left', 'center', 'right'});
            obj.HorizontalTextAlignment = value;
            obj.updateTextLocation()
        end
        
        function set.VerticalTextAlignment(obj, value)
            value = validatestring(value, {'top', 'middle', 'bottom'});
            obj.VerticalTextAlignment = value;
            obj.updateTextLocation()
        end
        
        function set.IconTextSpacing(obj, value)
            % Todo: Validate number (integer)...
            obj.IconTextSpacing = value;
            obj.updateTextLocation()
        end
        
        function mechanicalAction = get.MechanicalAction_(obj)
        % Mode (toggle/push) takes precedent over mechanical action...
            
            mechanicalAction = obj.MechanicalAction;
            if strcmp(obj.Mode, 'pushbutton')
                mechanicalAction = strrep(mechanicalAction, 'Switch', 'Latch');
            elseif strcmp(obj.Mode, 'togglebutton')
                mechanicalAction = strrep(mechanicalAction, 'Latch', 'Switch');
            end
        end
    end
    
    methods (Static)
            
        function S = getTypeDefaults()
            S.CornerRadius = 3;
            S.IsFixedSize = [true, true];
            %S.PositionMode = 'manual';
            S.BackgroundColor = 'k';
            
        end
    end
end
