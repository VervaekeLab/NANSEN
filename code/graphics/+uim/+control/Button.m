classdef Button < uim.abstract.virtualContainer & uim.mixin.assignProperties
    
    % todo: subclass from button
    
    % Implement position
    
    % Need default size...
    
    % Implement button switch on release.
    
    % New a getPosition property.
    
    % % NB. Pickable parts of button background is visible, si if the
    % backgroundalpha is set to 0, this interface wont work as intended
    % Implement onVisibleChanged.
    
    % Where did I implement a button which is released when mouse moves
    % away?
    
    properties %(Constant) % Inherited from Component
        Type = 'pushbutton' % push / toggle % Todo: subclasses..
    end
    
    properties
                
        String = ''
        Icon = ''
        Value = 0
        
        Style = uim.style.buttonLightMode
        UseDefaultIcon = false
        AutoWrapText = false % Similar to BarExtensionMode
        
        ButtonAspectRatio = 1 % Do I need?
        FixedAspectRatio = true;

        ButtonDownFcn = []
        HorizontalTextAlignment = 'left' 

        FontName = 'helvetica'
        FontSize = 12
        FontWeight = 'normal'
        
        Tooltip = ''

        ToggleButtonListener event.listener = event.listener.empty
    end
    
    properties (Dependent, Transient)
        aR = 1 % Needed?
        Extent %Needed? Not internally. Does any outside function use it?
    end
    
    
    properties (Access = protected, Transient)
        %%%Toolbar % Parent
        ButtonReleasedListener
        TooltipPosition = [0, 0]

        %hBackground
        hForeground
        
        isButtonDown = false
        isMouseOver = false
        
        buttonContextMenu
    end
    
    properties (Access = private, Dependent)
    end
    
    
    methods
        
        function obj = Button(varargin)
            
            if isa(varargin{1}, 'uim.abstract.virtualContainer') || isa(varargin{1}, 'uim.abstract.Component')
                obj.Parent = varargin{1};
                obj.Canvas = obj.Parent.Canvas;
                varargin = varargin(2:end);
            elseif isa(varargin{1}, 'uim.UIComponentCanvas')
                obj.Parent = varargin{1};
                obj.Canvas = varargin{1};
                varargin = varargin(2:end);
            elseif isa(varargin{1}, 'matlab.graphics.axis.Axes')
                obj.Parent = varargin{1};
                obj.Canvas = struct('Axes', obj.Parent);   
                varargin = varargin(2:end);
            end
                
% %             if isa(obj.Canvas, 'matlab.graphics.axis.Axes')
% %                 obj.Canvas = struct('Axes', obj.Canvas);
% %             end
            
            % Concatenate so that varargin comes last. This way, if the
            % property is supplied as input, that one will be the one which
            % is used.
            varargin = cat(2, {'CornerRadius', 3}, varargin);
            
            obj.parseInputs(varargin{:})
                        
            obj.create()
            
            obj.hBackground.ButtonDownFcn = @obj.onButtonPressed;
            
            
            obj.setTooltipPosition()
            
            setappdata(obj.hBackground, 'InteractiveObject', obj)
            obj.IsConstructed = true;
            
            obj.onStyleChanged()
            obj.autoWrapButtonText()
            obj.updateBackgroundSize()
            
            obj.updateLocation(obj.PositionMode)

            obj.onVisibleChanged()
            obj.onHorizontalTextAlignmentChanged()
            
        end
        
        function delete(obj)
            if ~isempty(obj.hBackground) && isvalid(obj.hBackground)
                delete(obj.hBackground)
            end
            
            if ~isempty(obj.hForeground) && ~isstruct(obj.hForeground) && isvalid(obj.hForeground)
                delete(obj.hForeground)
            end
        end
        
    end % structors
    
    methods( Access = protected )  % Plot and update appearance
    
% %         function onSizeChanged(obj, oldPosition, newPosition)
% %             obj.resize()
% %         end
% %         
% %         function onLocationChanged(obj, oldPosition, newPosition)
% %             obj.relocate(newPosition-oldPosition)
% %         end
        
        function create(obj)
            % Plot background first
            obj.plotBackground()
            
            % Plot foreground on top. Important that foreground will not
            % capture mouseclicks
            obj.plotForeground()
            
            obj.changeAppearance()
            
            % Configure behavior for when pointer enters/leaves button.
            setPointerBehavior(obj)

            %obj.isCreated = true;
        end
        
        function plotBackground(obj)
            % todo: implement corner radius
% %             persistent X_ Y_
% %             if isempty(X_)
% %                 %[X_, Y_] = utilities.createBoxCoordinates(round(obj.Size)); %, 'nPointsCurvature', obj.CornerRadius);
% %                 [X_, Y_] = obj.createBoxCoordinates(round(obj.Size));
% %             end
            
            [X_, Y_] = uim.shape.rectangle(round(obj.Size), obj.CornerRadius);
            
            X = X_ + obj.Position(1);
            Y = Y_ + obj.Position(2);
            
            obj.hBackground = patch(obj.Canvas.Axes, X, Y, 'w');
            obj.hBackground.PickableParts = 'all';
            %uistack(obj.hBackground, 'down')

        end
        
        function plotForeground(obj, updateFlag)
        %plotForeground Plot button foreground (Text or icon)
            
            if nargin < 2; updateFlag = false; end
                
            if updateFlag
                delete(obj.hForeground)
                obj.plotIcon();
            else
                if ~isempty(obj.hForeground); return; end

                if ~isempty(obj.Icon) % Give priority
                    obj.plotIcon()
                elseif ~isempty(obj.String)
                    obj.plotText()
                end
            end
            
        end
        
        function updateButtonText(obj)
            obj.hForeground.String = obj.String;
            obj.autoWrapButtonText()
            %obj.updateBackgroundSize()
        end
        
        function plotText(obj)
        %plotText Plot button text
            
            obj.hForeground = text(obj.Canvas.Axes, 0, 0, obj.String);
            obj.hForeground.VerticalAlignment = 'middle';
            obj.hForeground.Color = obj.ForegroundColor;
            
            % Todo: Set position based on toolbar orientation
            obj.hForeground.Position(1) = obj.Position(1) + obj.hForeground.Margin;
            obj.hForeground.Position(2) = obj.Position(2) + obj.Position(4) / 2 + obj.Padding(2);

            obj.hForeground.PickableParts = 'none';
            
% %             pixelWidth = obj.hForeground.Extent(3);
% %             % Todo: Fix this....
% %             obj.aR = pixelWidth ./ obj.Toolbar.Height;
        
        end
        
        function autoWrapButtonText(obj)
            
            if obj.AutoWrapText
                pixelWidth = obj.hForeground.Extent(3);
                obj.Position(3) = pixelWidth + obj.hForeground.Margin*2 + sum(obj.Padding([1,3]));
            end
        end
        
        function plotIcon(obj)
        %plotIcon Plot button icon
        
            if strcmp(obj.Icon, 'x')
                obj.plotSymbol(); 
                return;
            end
            

            obj.hForeground = uim.graphics.imageVector(obj.Canvas.Axes, obj.Icon);

            % Set height of icon based on toolbar height.

%             switch obj.Parent.Orientation
%                 case 'horizontal'
%                     obj.hForeground.Height = obj.Size(2) - sum(obj.Padding([2,4]));
%                 case 'vertical'
%                     obj.hForeground.Width = obj.Size(1) - sum(obj.Padding([1,3]));
%             end

            % Assuming square button size...
            buttonAr = obj.hForeground.Width / obj.hForeground.Height;
            if buttonAr >= 1
                obj.hForeground.Width = obj.Size(1) - sum(obj.Padding([1,3]));
            else
                obj.hForeground.Height = obj.Size(2) - sum(obj.Padding([2,4]));
            end
            
            % Imagevector are upside down... Should be taken care of
            % somewhere else...
            obj.hForeground.flipud()
            
            % Align icon relative to anchor point.
            obj.hForeground.VerticalAlignment = 'bottom';
            obj.hForeground.HorizontalAlignment = 'left';
            
            % Center icon in middle of button...
            obj.hForeground.Position = obj.Position(1:2) + (obj.Position(3:4)-[obj.hForeground.Width, obj.hForeground.Height]) / 2;

            
            %obj.hForeground.Position = obj.Position(1:2) + obj.Padding(1:2);

            

            % Set color
            if ~obj.UseDefaultIcon
                obj.hForeground.Color = obj.ForegroundColor;
            end
            obj.hForeground.PickableParts = 'none';
            obj.hForeground.HitTest = 'off';
        
            obj.aR = obj.hForeground.Width ./ obj.hForeground.Height;

            if obj.aR ~= 1
                obj.updateBackgroundSize()
            end
        end
        
        function plotSymbol(obj)
            
            assert(any(strcmp({'x', 'o'}, obj.Icon)), 'Invalid symbol for button')
                
            x = obj.Position(1);
            y = obj.Position(2);
            obj.hForeground = plot(obj.Toolbar.Axes, x, y, obj.Icon);
            obj.hForeground.MarkerSize = 12;
            
            obj.hForeground.PickableParts = 'none';
            obj.hForeground.HitTest = 'off';
            
            obj.updateForeground()

        end
        
        function setPointerBehavior(obj)
        %setPointerBehavior Set pointer behavior of background.

            pointerBehavior.enterFcn    = @obj.onMouseEntered;
            pointerBehavior.exitFcn     = @obj.onMouseExited;
            pointerBehavior.traverseFcn = [];%@obj.moving;
            
            iptSetPointerBehavior(obj.hBackground, pointerBehavior);
            iptPointerManager(ancestor(obj.hBackground, 'figure'));

        end
        
        function setTooltipPosition(obj)
        %setTooltipPosition Set position of tooltip on the canvas axes.
            
            if isempty(obj.Tooltip); return; end
            
            centerX = mean(obj.hBackground.XData);
            centerY = mean(obj.hBackground.YData);

            obj.TooltipPosition = [centerX, centerY - 0.5*obj.Size(2)-15];
        end
        
        function setContextMenuPosition(obj)
            if ~isempty(obj.buttonContextMenu)
                obj.buttonContextMenu.Position = obj.Position(1:2);
            end
        end
        
        function changeAppearance(obj)
        %changeAppearance Update button appearance based on state     
            
            %if ~obj.IsConstructed; return; end
            
            if obj.Value
                if obj.isMouseOver
                    newAppearance = 'HighlightedOn';
                else
                    newAppearance = 'On';
                end
            else
                if obj.isMouseOver
                    newAppearance = 'HighlightedOff';
                else
                    newAppearance = 'Off';
                end
            end
            
            obj.ForegroundColor = obj.Style.(newAppearance).ForegroundColor;
            obj.BackgroundColor = obj.Style.(newAppearance).BackgroundColor;
            obj.BackgroundAlpha = obj.Style.(newAppearance).BackgroundAlpha;
            obj.BorderColor = obj.Style.(newAppearance).BorderColor;
            obj.BorderWidth = obj.Style.(newAppearance).BorderWidth;

            if ~isempty(obj.String)
                if isa(obj.hForeground, 'matlab.graphics.primitive.Text')
                    try
                    obj.hForeground.FontWeight = obj.Style.(newAppearance).FontWeight;
                    end
                end
            end
            
            % Maybe use on styleChanged instead?
            if ~obj.UseDefaultIcon
                obj.updateForeground()
            end
            obj.updateBackground()
        end
        
        % Todo: Combine with onStyleChanged
        function updateBackground(obj)
            if isempty(obj.hBackground); return; end
            obj.hBackground.FaceColor = obj.BackgroundColor;
            obj.hBackground.FaceAlpha = obj.BackgroundAlpha;
            obj.hBackground.EdgeColor = obj.BorderColor;
            obj.hBackground.LineWidth = obj.BorderWidth;
            
            
            % Todo: This should be in this function, while above should be in 
            % onStyleChanged 
            [X_, Y_] = uim.shape.rectangle(round(obj.Size), obj.CornerRadius);

            X = X_ + obj.Position(1);
            Y = Y_ + obj.Position(2);
            
            set(obj.hBackground, 'XData', X, 'YData', Y)

        end
        
        function updateForeground(obj)
            if isempty(obj.hForeground); return; end
            obj.hForeground.Color = obj.ForegroundColor;
        end
        
        % Todo: This method is inherited from virtualContainer.
        function updateBackgroundPosition(obj, newPosition)
        %updateBackgroundPosition Update position of background patch 
        
            if isempty(obj.hBackground); return; end
            
            shift = newPosition - obj.Position;
            
            if shift(1) ~= 0
                obj.hBackground.XData = obj.hBackground.XData + shift(1);
            end
            
            if shift(2) ~= 0
                obj.hBackground.YData = obj.hBackground.YData + shift(2);
            end
            
        end
        
        function updateForegroundPosition(obj, newPosition)
            
            if isempty(obj.hBackground); return; end
            
            if isa(obj.hForeground, 'clib.imageVector')
                %obj.hForeground.Position(1:2) = newPosition + obj.Padding(1:2);
                obj.hForeground.Position(1:2) = obj.Position(1:2) + (obj.Position(3:4)-[obj.hForeground.Width, obj.hForeground.Height]) / 2;

            elseif isa(obj.hForeground, 'matlab.graphics.primitive.Text')
                obj.hForeground.Position(1:2) = newPosition;
            end
            
        end
        
        function updateBackgroundSize(obj)
            [X, Y] = uim.shape.rectangle(round(obj.Size), obj.CornerRadius);
            X = X + obj.Position(1);
            Y = Y + obj.Position(2); % Center on y.
            
            obj.hBackground.XData = X;
            obj.hBackground.YData = Y;
        end
        
    end
    
    methods( Access = private ) % Event & other callbacks
        
        function onMouseEntered(obj, hSource, eventData)
            obj.isMouseOver = true;
            obj.changeAppearance()
            if ~isempty(obj.Tooltip)
                obj.Canvas.showTooltip(obj.Tooltip, obj.TooltipPosition)
            end
        end

        function onMouseExited(obj, hSource, eventData)
            obj.isMouseOver = false;
            obj.changeAppearance()
            if ~isempty(obj.Tooltip)
                obj.Canvas.hideTooltip()
            end
        end
        
        function onButtonPressed(obj, ~, event)
        %onButtonPressed Event handler for mouse press on button
            obj.isButtonDown = true;
            
            switch obj.Type
                case 'pushbutton'
                    obj.Value = true;
                case 'togglebutton'
                    obj.Value = ~obj.Value;
            end
            
            if isempty(obj.ButtonReleasedListener)
                hFig = ancestor(obj.hBackground, 'figure');
                el = addlistener(hFig, 'WindowMouseRelease', @obj.onButtonReleased);
                obj.ButtonReleasedListener = el;
            end
            
            obj.changeAppearance()
       
            if ~isempty(obj.ButtonDownFcn)
                obj.ButtonDownFcn(obj, event)
            end
            
        end
        
        function onButtonReleased(obj, src, event)
        % Event handler for mouse release from button
        
            obj.isButtonDown = false;
            
            if strcmp(obj.Type, 'pushbutton')
                obj.Value = false;
            end
            
            obj.changeAppearance()
            
            % Todo: Run callback if it should be activated on button
            % release
            
            delete(obj.ButtonReleasedListener)
            obj.ButtonReleasedListener = [];
            
        end
        
    end
    
    methods( Access = public ) % Event & other callbacks

        function onVisibleChanged(obj, ~)
            if ~obj.IsConstructed; return; end
            
            switch obj.Visible
                case 'on'
                    obj.hBackground.PickableParts = 'all';
                    obj.hBackground.Visible = 'on';
                    obj.hForeground.Visible = 'on';
                case 'off'
                    obj.hBackground.PickableParts = 'visible';
                    obj.hBackground.Visible = 'off';
                    obj.hForeground.Visible = 'off';
            end
        end
        
        
        function onHorizontalTextAlignmentChanged(obj)
            if ~obj.IsConstructed; return; end
            
            if isempty(obj.String); return; end
            
            buttonWidth = obj.Position(3);
            textWidth = obj.hForeground.Extent(3)+obj.hForeground.Margin*2;
            
            switch obj.HorizontalTextAlignment
                
                case 'left'
                    obj.hForeground.Position(1) = obj.Position(1) + obj.hForeground.Margin;
                case 'center'
                    obj.hForeground.Position(1) = obj.Position(1) + obj.hForeground.Margin + (buttonWidth-textWidth)/2;
                case 'right'
                    obj.hForeground.Position(1) = obj.Position(1) + obj.hForeground.Margin + (buttonWidth-textWidth);
                    
            end
            
        end
        
        
        function onStyleChanged(obj)
            
            if ~obj.IsConstructed; return; end
                        
            if ~isempty(obj.Icon) % Give priority
                % Todo: Change foreground colors???
                
            elseif ~isempty(obj.String)
                obj.hForeground.FontName = obj.FontName;
                obj.hForeground.FontSize = obj.FontSize;
                obj.hForeground.FontWeight = obj.FontWeight;
            end
        end
        
    end  % event handlers
    
    methods
    
        function h = getContextMenuHandle(obj)
        %getContextMenuHandle Return context menu handle for button
        %
        %   If context menu does not exist, it is created and placed in the
        %   lower left corner of the button.
        
            if isempty(obj.buttonContextMenu)
                h = uicontextmenu( ancestor(obj.hBackground, 'figure') );
                h.Position = obj.Position(1:2);
                obj.buttonContextMenu = h;
            else
                h = obj.buttonContextMenu;
            end
        end
        
        function relocate(obj, shift)
            
            if obj.IsConstructed
                obj.move(shift(1:2))
            end
        end
        
        function move(obj, shift)
            if shift(1) ~= 0
                obj.hBackground.XData = obj.hBackground.XData+shift(1);
            end
            
            if shift(2) ~= 0
                obj.hBackground.YData = obj.hBackground.YData+shift(2);
            end
            
            if isa(obj.hForeground, 'uim.graphics.imageVector')
                obj.hForeground.translate(shift)
            elseif isa(obj.hForeground, 'matlab.graphics.primitive.Text')
                obj.hForeground.Position(1:2) = obj.hForeground.Position(1:2)+shift;
            end
            
            obj.setTooltipPosition()
            obj.setContextMenuPosition()
            
        end

        function [X, Y] = getNormalizedUnits(obj, X, Y)
            axPos = getpixelposition(obj.Toolbar.Axes);
            X = X./ axPos(3);
            Y = Y./ axPos(4);
        end
        
        function toggleState(obj, ~, event)
            
            if obj.Value ~= event.Value
                obj.Value = event.Value;
                obj.changeAppearance()
            end
            
        end
        
        function addToggleListener(obj, handle, eventName)
           el = listener(handle, eventName, @obj.toggleState);
           obj.ToggleButtonListener = el;
        end
        
        function hideTooltip(obj)
            if ~isempty(obj.Tooltip)
                obj.Canvas.hideTooltip()
            end
        end
        
    end
    
    methods % Set/get
        
        function set.String(obj, value)
            assert(isa(value, 'char'), 'String property of button must be a character vector')
            
            obj.String = value;
            if obj.IsConstructed
                obj.updateButtonText()
            end

        end
        
        function set.Style(obj, newStyle)
            % Todo: consolidate this with onStyleChanged which is doing
            % something slightly different, but should be the same.
            
            obj.Style = newStyle;
            obj.changeAppearance()
        
        end
        
        function set.Icon(obj, value)
%             assert(isa(value, 'char'), 'Icon property of button must be a pathstr')
%             assert(exist(value, 'file')==2, 'Icon file was not found')
            
            obj.Icon = value;
            if obj.IsConstructed
                obj.plotForeground(true)
            end
        end
        
        function set.FontName(obj, value)
        	obj.FontName = value;
            obj.onStyleChanged()
        end
        
        function set.FontSize(obj, value)
            obj.FontSize = value;
            obj.onStyleChanged()
        end
        
        function set.FontWeight(obj, value)
            obj.FontWeight = value;
            obj.onStyleChanged()
        end
        
        function set.HorizontalTextAlignment(obj, value)
            
            obj.HorizontalTextAlignment = value;
            obj.onHorizontalTextAlignmentChanged()
            
        end
        
        function set.Value(obj, newValue)

            obj.Value = newValue;
            obj.changeAppearance()
        end
    
%         function set.Position(obj, value)
%             
%             assert(isnumeric(value) && numel(value == 2), ...
%                 'Value must be a 2 element vector of numeric type')
%             
%             obj.updateBackgroundPosition(value)
%             obj.updateForegroundPosition(value)
%             
%             obj.Position = value;
%             
%         end
        
%         function size = get.Size(obj)
%            size = obj.Toolbar.Height .* [obj.aR, 1]; 
%            size(1) = size(1);% + obj.InnerMargin*2;
%         end
        
        function extent = get.Extent(obj)
            extent = [0,0,obj.Size];
        end
        
        function aR = get.aR(obj)
            if isempty(obj.hForeground)
                aR = 1;
            else
                switch class(obj.hForeground)
                    case 'matlab.graphics.primitive.Text'

                        axPosPix = getpixelposition(obj.Toolbar.Axes);
                        pixelWidth = obj.hForeground.Extent(3);% .* axPosPix(3);
                        aR = (pixelWidth + sum(obj.Padding([1,3]))) ./ obj.Toolbar.Height;

                    case 'clib.imageVector'
%                         axPosPix = getpixelposition(obj.Toolbar.Axes);
%                         aR = obj.hForeground.Width*axPosPix(3) ./ (obj.hForeground.Height*axPosPix(4));

                          aR = ( obj.hForeground.Width + sum(obj.Padding([1,3])) ) / ...
                              ( obj.hForeground.Height + sum(obj.Padding([2,4])) );

                    otherwise
                        aR = 1;
                end
            end
        end
            
        function set.aR(obj, newValue)
        end
            
%         function set.BackgroundColor(obj, newValue)
%             obj.BackgroundColor = newValue;
%             obj.updateBackground()
%         end
%         
%         function set.BackgroundAlpha(obj, newValue)
%             obj.BackgroundAlpha = newValue;
%             obj.updateBackground()
%         end
    end
    
    
end