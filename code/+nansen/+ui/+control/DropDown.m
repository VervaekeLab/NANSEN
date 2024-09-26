classdef DropDown < nansen.ui.control.AbstractControl %& nansen.ui.mixin.IsStylableDropDown
% DropDown - A dropdown control with (optional) "action" options
%
% This dropdown is based on the old uicontrol, but adds the Items and
% ItemsData properties to also mimic the uidropdown control.
%
% Additionally it is possible to set AllowNoSelection to true, and add a
% CreateNewItemFcn. This will populate the dropdown with extra options that
% will be handled separately from selecting a "standard" option.

% Todo: 
%   [ ] Ensure items are unique?
%   [ ] Allow arbitrary actions and action callbacks. Could be managed
%       through a dictionary...
%   [ ] Add a placeholder string if items and string is empty...
%   [ ] Todo how to represent values and value changed when one of the
%       actions have been selected...?

    properties
        Items (1,:) string
        ItemsData (1,:) cell
        ItemName (1,1) string = missing

        AllowNoSelection (1,1) matlab.lang.OnOffSwitchState = 'off'
        %SortItems = false; % Todo
        
        % CreateNewItemFcn - A function handle for a function that accepts
        % (1) items or (2) items and itemsData as inputs and returns 
        % (1) newItem or (2) newItem and newItemsData as outputs. If the 
        % ItemData property is empty, the first form should be used,
        % otherwise the second form should be used.
        CreateNewItemFcn % Function handle

        %CustomActions dictionary Dictionary of name and function handles.
    end

    properties (Access = private)
        ActionItems (1,:) string
    end

    properties (Access = private)
        ItemSelectedFcn = [] % Todo: callback new uicontrol style
        UserCallbackFcn = []
    end

    methods % Constructor
        
        function obj = DropDown(superclassOptions, options)
            arguments
                superclassOptions.?matlab.ui.control.UIControl
                options.Items (1,:) string = []
                options.ItemsData (1,:) cell = {}
                options.ItemName (1,1) string = missing
                options.CreateNewItemFcn (1,1) function_handle = []
                options.AllowNoSelection (1,1) matlab.lang.OnOffSwitchState = 'off'
            end
    
            % This control has custom callback routines, so the callback 
            % is not passed to the superclass constructor
            if isfield(superclassOptions, 'Callback')
                callbackFcn = superclassOptions.Callback;
                superclassOptions = rmfield(superclassOptions, 'Callback');
            else
                callbackFcn = [];
            end
            
            superclassOptions = namedargs2cell(superclassOptions);
            obj = obj@nansen.ui.control.AbstractControl(superclassOptions{:});
            %obj = obj@nansen.ui.mixin.IsStylableDropDown()
            
            % Update items if items was given as input (will take 
            % precedence over the string property)
            if ~isempty(options.Items)
                obj.setItemsOnConstruction(options.Items)
            end
            options = rmfield(options, 'Items');
            
            obj.assignPropertyArguments(options)
            
            % Set up the internal handling of callback
            obj.UserCallbackFcn = callbackFcn;
            obj.UIControl.Callback = @obj.onValueChanged;
            
            if ~nargout; clear obj; end
        end
    end
    
    methods
        function selectedValue = getSelectedValue(obj)            
            if obj.Value <= numel(obj.ActionItems)
                selectedValue = '';
            else
                selectedValue = obj.String{obj.Value};
            end
        end
    end

    methods % Set/get
       function set.Items(obj, value)
            obj.Items = value;
            obj.onItemsSet();
        end
        
        function set.ItemsData(obj, value)
            obj.ItemsData = value;
            obj.onItemsDataSet();
        end
        
        function set.ItemName(obj, value)
            obj.ItemName = value;
            obj.onItemNameSet();
        end

        function set.AllowNoSelection(obj, value)
            obj.AllowNoSelection = value;
            obj.onAllowNoSelectionSet()
        end

        function set.CreateNewItemFcn(obj, value)
            assert(isa(value,'function_handle'), ...
                'Value must be a function handle')
            obj.CreateNewItemFcn = value;
            obj.onCreateNewItemFcnSet()
        end
    end

    methods (Access = protected)
        function createControl(obj)
            obj.UIControl = uicontrol('Style', 'popupmenu');
        end
    end

    methods (Access = protected) % callbacks for property set events 
        function onCallbackSet(obj)
            % Set up the internal handling of callback
            obj.UserCallbackFcn = obj.Callback_;
            obj.UIControl.Callback = @obj.onValueChanged;
        end
    end

    methods (Access = private)
        function onValueChanged(obj, src, evt)
            
            value = src.Value;
            
            if value <= numel(obj.ActionItems)
                action = obj.ActionItems(value);
            else
                action = string.empty;
            end

            if action == "Create"
                if ~isempty(obj.CreateNewItemFcn)
                    obj.createNewItem()
                    return
                end

            end

            % Todo: Need a good way to provide a value change event where
            % the src.String{src.Value} does not yield the "action item"
            
            %if ~isempty(action); return; end
            
            if ~isempty(obj.UserCallbackFcn)
                obj.UserCallbackFcn(obj, evt)
            end
        end
    end

    methods (Access = private)

        function onItemsSet(obj)
        % onItemsSet - Do something when Items property is set
            obj.updateString()
        end
        
        function onItemsDataSet(obj)
        % onItemsDataSet - Do something when ItemsData property is set
            % Todo: Make sure items data is the same size as items.
        end
        
        function onItemNameSet(obj)
        % onItemNameSet - Do something when ItemName property is set
            
            if isempty(obj.Items) && ~isempty(obj.String)
                warning('Setting ''ItemsName'' has no effect when ''Items'' are empty')
                return
            end
            obj.updateString()
        end

        function onAllowNoSelectionSet(obj)
            %if isempty(obj.Items); return; end
            
            newValue = obj.Value;

            if obj.AllowNoSelection
                if isempty(obj.ActionItems) || ~contains(obj.ActionItems, "Select")
                    obj.ActionItems = ["Select", obj.ActionItems];
                    newValue = obj.Value+1;
                end
            else
                if contains(obj.ActionItems, "Select")
                    obj.ActionItems = setdiff(obj.ActionItems, "Select", 'stable');
                    newValue = obj.Value-1;
                end
            end
            obj.updateString()
            if ~isempty(newValue) && ~(newValue < numel(obj.String) || newValue > numel(obj.String))
                obj.Value = newValue;
            end
        end

        function onCreateNewItemFcnSet(obj)
            %if isempty(obj.Items); return; end
            
            newValue = obj.Value;

            if isempty(obj.CreateNewItemFcn)
                if contains(obj.ActionItems, "Create")
                    obj.ActionItems = setdiff(obj.ActionItems, "Create", 'stable');
                    newValue = obj.Value-1;
                end
            else
                if isempty(obj.ActionItems) || ~contains(obj.ActionItems, "Create")
                    obj.ActionItems = [obj.ActionItems, "Create"];
                    newValue = obj.Value+1;
                end
            end
            obj.updateString()
            if ~isempty(newValue) && ~(newValue < numel(obj.String) || newValue > numel(obj.String))
                obj.Value = newValue;
            else
                obj.Value = 1;
            end
        end
    end

    methods (Access = private)

        function updateString(obj)
        % updateString - Add labels for actions to uicontrol's String property
            
            if isempty(obj.Items) && isempty(obj.ActionItems); return; end
            
            stringValue = obj.Items;

            actionItemLabels = arrayfun(@(str) obj.getPlaceholderString(str), obj.ActionItems);
            if ~isempty(actionItemLabels)
                stringValue = [actionItemLabels, stringValue];
            end

            obj.UIControl.String = cellstr(stringValue);
        end

        function setItemsOnConstruction(obj, items)
            
            if ~isempty(obj.String)
                warning('NANSEN:UIControl:DropDown', ...
                    ['When setting both ''String'' property and ''Items'' ', ...
                     'property of DropDown control, ''Items'' property ', ...
                     'takes precedence.'] )
            end

            obj.Items = items;
        end

        function str = getPlaceholderString(obj, actionWord)
            
            if nargin < 2; actionWord = "Select"; end

            if ismissing( obj.ItemName ) || obj.ItemName == ""
                itemName = "Option";
            else
                itemName = obj.ItemName;
            end

            % Select article
            startsWithVowelPattern = '^[aeiouAEIOU].*';
            if ~isempty(regexp(itemName, startsWithVowelPattern, 'once'))
                article = "an";
            else
                article = "a";
            end

            str = sprintf("<%s %s %s>", actionWord, article, itemName);
            % I.e "<Select an Option>"

            if isempty(obj.Items); return; end
            if isequal(obj.Items, ""); return; end

            if obj.Items{end}(1) == lower( obj.Items{end}(1) )
                str = lower(str);
            end
        end
    
        function throwInvalidCreateNewItemFcnError(obj)

            if ~isempty(obj.ItemsData)
                errMessage = 'Expected ''CreateNewItemFcn'' to return exactly two values, one new item and one new itemData respectively.';
            else
                if ~isempty(obj.Items)
                    errMessage = 'Expected ''CreateNewItemFcn'' to return exactly one value, representing a new item.';
                else
                    error('Something unexpected happened')
                end
            end

            ME = MException('NANSEN:UIDropDown:CreateNewItemFcn', errMessage);
            throwAsCaller(ME)
        end    
    
        function createNewItem(obj)
        % 
            try
                if ~isempty(obj.ItemsData)
                    [newItem, newItemData] = obj.CreateNewItemFcn(obj.Items, obj.ItemsData);
                else
                    newItem = obj.CreateNewItemFcn(obj.Items);
                    newItemData = {};
                end
                if isempty(newItem); return; end
                
                % Add new item to items.
                obj.addNewItem(newItem, newItemData)

            catch ME
                if strcmp( ME.identifier, 'MATLAB:maxlhs' )
                    obj.throwInvalidCreateNewItemFcnError()
                else
                    rethrow(ME)
                end
            end
        end

        function addNewItem(obj, newItem, newItemData)
            
            if ~isempty(obj.ItemsData)
                obj.ItemsData{end+1} = newItemData;
            end
                
            obj.Items(end+1) = newItem;
            obj.Value = find(strcmp(obj.String, newItem));

            % Todo: This needs the proper eventdata
            if ~isempty(obj.UserCallbackFcn)
                obj.UserCallbackFcn(obj, [])
            end
        end
    end

    methods (Access = protected) % IsStylable method
        function hControl = getStylableControl(obj)
            hControl = obj.UIControl;
        end
    end
end
