classdef MenuList < uiw.mixin.AssignPVPairs
% Class to represent a list in a menu or a submenu.

% About selection mode:
%   none: similar to a push button, the callback is triggered, with source
%         and event as input args
%   single: similar to toggle button, the callback is triggered, the menu
%         item is checked and the menus value property is updated
%   multiple: allows multiple menu items to be selected/checked simultaneously.

    properties
        Items                    % Cell array of chars (names) to place in the menu list
        Value                    % Char or cell array of selected items from Items list
        % SelectionMode - Whether menu items will be selected or not.
        SelectionMode = 'single' % none, single or multiple
        MenuSelectedFcn
    end

    properties (Access = private)
        %ParentFigure
        ParentMenu
        MenuListItems
    end
    
    properties (Constant, Access = private)
        VALID_SELECTIONMODE = {'none', 'single', 'multiple'}
    end

    methods % Constructor
        
        function obj = MenuList(hMenu, items, value, varargin)
        %
        %   obj = MenuList(hMenu, items, value)
        %
        %   obj = MenuList(hMenu, items, value, Name, Value)

            if nargin < 3
                value = items{1};
            end
            
            % Assign property values.
            obj.ParentMenu = hMenu;
            obj.Items = items;
            obj.Value = value;
            
            obj.assignPVPairs(varargin{:})
            
        end
    end

    methods % Set/get

        function set.MenuSelectedFcn(obj, newValue)
            assert(isa(newValue, 'function_handle'))
            obj.MenuSelectedFcn = newValue;
        end

        function set.Items(obj, itemNames)
            obj.Items = itemNames;
            obj.onItemsSet()
        end

        function set.Value(obj, itemNames)
            obj.Value = itemNames;
            obj.onValueSet()
        end

        function set.SelectionMode(obj, newMode)
            newMode = validatestring(newMode, obj.VALID_SELECTIONMODE);
            obj.SelectionMode = newMode;
            obj.onSelectionModeSet()
        end
    end
    
    methods (Access = private)
            
        function createMenuList(obj)
            
            numItems = numel(obj.Items);

            obj.MenuListItems = gobjects(1, numItems);
            for i = 1:numItems
                msubitem = uimenu(obj.ParentMenu, 'Text', obj.Items{i});
                msubitem.MenuSelectedFcn = @obj.onMenuSelected;
                if any(strcmp(obj.Items{i}, obj.Value))
                    msubitem.Checked = 'on';
                end
                obj.MenuListItems(i) = msubitem;
            end
        end

        function onMenuSelected(obj, src, evt)
            
            switch obj.SelectionMode
                case 'none'
                    % do nothing
                    obj.Value = [];
                case 'single'
                    if strcmp(src.Text, obj.Value)
                        return
                    else
                        obj.Value = src.Text;
                    end

                case 'multiple'
                    if any(strcmp(obj.Value, src.Text))
                        obj.Value = setdiff(obj.Value, src.Text);
                    else
                        obj.Value = union(obj.Value, src.Text);
                    end
            end

            if ~isempty(obj.MenuSelectedFcn)
                obj.MenuSelectedFcn(src, evt)
            end
        end

        function onMenuSelectedFcnSet(obj)
            % Set callback function for all the menu items.
            set(obj.MenuListItems, 'MenuSelectedFcn', obj.MenuSelectedFcn);
        end

        function onItemsSet(obj)
                 
            if ~isempty(obj.ParentMenu.Children)
                delete(obj.ParentMenu.Children)
            end

            obj.createMenuList()
        end

        function onValueSet(obj)
            
            if isempty( obj.MenuListItems )
                return
            else
                set(obj.MenuListItems, 'Checked', 'off')
            end

            [~, itemInd] = intersect(obj.Items, obj.Value);
            set(obj.MenuListItems(itemInd), 'Checked', 'on')
        end

        function onSelectionModeSet(obj)
            if strcmp(obj.SelectionMode, 'none')
                set(obj.MenuListItems, 'Checked', 'off')
                obj.Value = [];
            end
        end
    end
end
