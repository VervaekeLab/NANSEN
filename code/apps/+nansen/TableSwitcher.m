classdef TableSwitcher < handle

    properties
        CurrentSelection = 'Subject'
        Items = {'Subject', 'Session', 'Cells'}
        SelectionChangedFcn
        SelectionMode % Single, multiple
        MaxSelection = 2
    end

    properties
        ItemIcons
        FontName = 'helvetica'
    end
    
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
        UIComponentCanvas
        UIToolbar
        TabButtonGroup
    end
    
    properties (Access = private)
        Padding = [5,0,5,0]
    end

    methods 
        function obj = TableSwitcher(hParent)
            
            obj.Parent = hParent;
            obj.createComponent()
        end
    end

    methods
        function updateLocation(obj)
            obj.TabButtonGroup.Group.updateLocation()
        end
    end

    methods 
        function w = get.Width(obj)
            w = obj.TabButtonGroup.Group.Width +  sum(obj.Padding([1,3]));
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
        end

        function createToolbar(obj)
            width = 100;
            hToolbar = uim.widget.toolbar_(obj.Parent, 'Location', 'northwest', ...
                'Margin', [0,0,0,0],'ComponentAlignment', 'top', ...
                'BackgroundAlpha', 0, 'IsFixedSize', [true, false], ...
                'NewButtonSize', [width, 25], 'Padding', obj.Padding, ...
                'Spacing', 5);
            obj.TabButtonGroup.Group = hToolbar;
        end

        function createButtons(obj)

            xPad = 4;

            hToolbar = obj.TabButtonGroup.Group;
            
            buttonConfig = {'FontSize', 15, 'FontName', obj.FontName, ...
                'Padding', [xPad,2,xPad,2], 'CornerRadius', 7, ...
                'Mode', 'togglebutton', 'Style', uim.style.tabButtonLight, ...
                'IconSize', [12,12], 'IconTextSpacing', 7};
            
            % Bug with toolbar so buttons are created from the bottom up
            counter = 0;
            for i = numel(obj.Items):-1:1
                counter = counter+1;
                
                if any(strcmpi(obj.ICONS.iconNames, obj.Items{i}) )
                    icon = obj.ICONS.(lower(obj.Items{i}));
                else
                    icon = obj.ICONS.tableStrong;
                end

                obj.TabButtonGroup.Buttons(counter) = hToolbar.addButton(...
                    'Text', utility.string.varname2label(obj.Items{i}), 'Icon', icon, ...
                    'Callback', @(s,e,n) obj.onTabButtonPressed(s,e,i), ...
                    buttonConfig{:} );
                if i == 1
                    obj.TabButtonGroup.Buttons(counter).Value = true;
                end
            end
        end 
    end
    
    methods (Access = private)
        function onTabButtonPressed(obj, src, evt, pageNum)
            
            % Make sure all other buttons than current is off
            for iBtn = 1:numel(obj.TabButtonGroup.Buttons)
                if ~isequal(src, obj.TabButtonGroup.Buttons(iBtn))
                    obj.TabButtonGroup.Buttons(iBtn).Value = 0;
                end
            end

            % Make sure current button is on (and change page if it was turned on)
            if src.Value
                % If click turns button on, change page!
                if ~isempty(obj.SelectionChangedFcn)
                    obj.SelectionChangedFcn(src, evt)
                end
            else
                % If click turns button off, turn it back on!
                src.Value = true;
            end 
        end
    end
end
