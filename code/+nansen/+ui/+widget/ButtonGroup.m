classdef ButtonGroup < handle
% A collection of buttons where one or more buttons can be selected

% NB: Work in progress

%   Todo:
%   [ ] Add set width

    properties
        CurrentSelection = 'Button 1'
        Items = {'Button 1', 'Button 2', 'Button 3'}
        SelectionChangedFcn
        SelectionMode % Single, multiple
        MaxSelection = 2
    end

    properties (Dependent)
        Location
    end

    properties
        ItemIcons
        FontName = 'helvetica'
    end
    
    % Todo: ICONS and theme should be settable
    properties (Constant, Hidden = true) % Move to appwindow superclass
        DEFAULT_THEME = nansen.theme.getThemeColors('light');
        ICONS = uim.style.iconSet(nansen.App.getIconPath)
    end
    
    properties (Dependent)
        Position
        Width
        Height
    end

    properties (Access = private)
        Parent
        UIComponentCanvas % Todo: Why is this here?
        Components (1,1) struct % Holds components of this widget Has the following fields: Group, Buttons
        ParentSizeChangedListener (1,:) event.listener
    end
    
    properties (Access = private)
        Padding = [5,0,5,0]
    end

    methods
        function obj = ButtonGroup(hParent, options)
            arguments
                hParent
                options.Items (1,:) cell
            end

            obj.Parent = hParent;
            obj.Items = options.Items;
            obj.createComponent()
        end

        function delete(obj)
            if ~isempty(obj.ParentSizeChangedListener)
                delete(obj.ParentSizeChangedListener)
            end
            if isfield(obj.Components, 'Group') && ~isempty(obj.Components.Group)
                delete(obj.Components.Group)
            end
            if isfield(obj.Components, 'Buttons') && ~isempty(obj.Components.Buttons)
                for i = 1:numel(obj.Components.Buttons)
                    delete(obj.Components.Buttons(i))
                end
            end
            if isfield(obj.Parent.UserData, 'Separator') ...
                    && ~isempty(obj.Parent.UserData.Separator)
                try
                    delete(obj.Parent.UserData.Separator)
                catch
                    % todo: use isvalid instead?
                end
            end
        end
    end

    methods
        function updateLocation(obj)
            obj.Components.Group.updateLocation()
        end

        function updateLineHeight(obj, s, e)
            parentHeight = getpixelposition( obj.Parent );
            obj.Parent.UserData.Separator.Size(2) = parentHeight(4);
        end
    end

    methods
        function w = get.Width(obj)
            w = obj.Components.Group.Width +  sum(obj.Padding([1,3]));
        end

        function set.Location(obj, newValue)
            try
                obj.Components.Group.Location = newValue;
            end
        end

        function value = get.Location(obj)
            value = obj.Components.Group.Location;
        end

        function set.CurrentSelection(obj, value)
            obj.CurrentSelection = value;
            obj.postSetCurrentSelection()
        end
    end

    methods (Access = private)

        function createComponent(obj)
            obj.createToolbar()
            obj.createButtons()

            panelPos = getpixelposition(obj.Parent);
            
            linePos([1,3]) = floor([obj.Width, obj.Width]+2);
            linePos([2,4]) = [1, panelPos(4)];
            
            h = uim.decorator.Line(obj.Parent, ...
                'Position', linePos, ...
                'PositionMode', 'manual', ...
                'SizeMode', 'manual', ...
                'ForegroundColor', obj.DEFAULT_THEME.FigureFgColor);
            obj.Parent.UserData.Separator = h;

            obj.ParentSizeChangedListener = listener(obj.Parent, ...
                'SizeChanged', @obj.onParentSizeChanged);
        end

        function createToolbar(obj)
            width = 110;
            hToolbar = uim.widget.toolbar_(obj.Parent, 'Location', 'northwest', ...
                'Margin', [0,0,0,0],'ComponentAlignment', 'top', ...
                'BackgroundAlpha', 0, 'IsFixedSize', [true, false], ...
                'NewButtonSize', [width, 25], 'Padding', obj.Padding, ...
                'Spacing', 5);
            obj.Components.Group = hToolbar;
        end

        function createButtons(obj)

            xPad = 4;

            hToolbar = obj.Components.Group;
            
            buttonConfig = {'FontSize', 15, 'FontName', obj.FontName, ...
                'Padding', [xPad,2,xPad,2], 'CornerRadius', 7, ...
                'Mode', 'togglebutton', 'Style', uim.style.tabButtonLight, ...
                'IconSize', [14,14], 'IconTextSpacing', 7};
            
            % Bug with toolbar so buttons are created from the bottom up
            counter = 0;
            for i = numel(obj.Items):-1:1
                counter = counter+1;
                
                if any(strcmpi(obj.ICONS.iconNames, obj.Items{i}) )
                    icon = obj.ICONS.(lower(obj.Items{i}));
                else
                    icon = obj.ICONS.tableStrong;
                end

                obj.Components.Buttons(counter) = hToolbar.addButton(...
                    'Text', utility.string.varname2label(obj.Items{i}), 'Icon', icon, ...
                    'Callback', @(s,e,n) obj.onButtonPressed(s,e,i), ...
                    buttonConfig{:} );
                if i == 1
                    obj.Components.Buttons(counter).Value = true;
                end
            end
            obj.Components.Buttons = fliplr(obj.Components.Buttons);
        end
    
        function wasSwitched = switchButtonOn(obj, buttonHandle)
            % Make sure all other buttons than current is off
            for iBtn = 1:numel(obj.Components.Buttons)
                if ~isequal(buttonHandle, obj.Components.Buttons(iBtn))
                    obj.Components.Buttons(iBtn).Value = 0;
                else
                    if ~buttonHandle.Value;
                        buttonHandle.Value = 1;
                        wasSwitched = true;
                    else
                        wasSwitched = false;
                    end
                end
            end
            if ~nargout; clear wasSwitched; end
        end
    end
    
    methods (Access = private)
        function onButtonPressed(obj, src, evt, pageNum)
            
            wasSwitched = obj.switchButtonOn(src);
            obj.CurrentSelection = src.Text;

            % Make sure current button is on (and change page if it was turned on)
            if wasSwitched
                % If button was switch by method above, the user turned the
                % button on and the above method turned the button back on
                % to make this button group function like radiobuttons.
            else
                % If click turned button on, change page!
                if ~isempty(obj.SelectionChangedFcn)
                    obj.SelectionChangedFcn(src, evt)
                end
            end
        end
    
        function onParentSizeChanged(obj, src, evt)
            obj.updateLineHeight()
        end
    end

    methods (Access = private)
        function postSetCurrentSelection(obj)
            isMatchedButton = strcmp(obj.Items, obj.CurrentSelection);
            matchedButton = obj.Components.Buttons(isMatchedButton);
            obj.switchButtonOn(matchedButton)
        end
    end
end
