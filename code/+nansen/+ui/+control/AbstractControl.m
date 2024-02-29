% This abstract control replicates MATLAB's uicontrol component and adds
% some custom features.  


classdef (Abstract) AbstractControl < ...
                        nansen.ui.mixin.HasPropertyArgs & ...
                            nansen.ui.mixin.IsStylable & ... 
                                nansen.ui.mixin.IsArrangeable


% Uses matlab.ui.control.UIControl internally
% Todo: 
%  [ ] Customize display
%  [ ] Consider constant property or abstract method for fields to ignore
%      for specific subclass control
%  [ ] Add listener to UIControl and delete this object if uicontrol is
%  deleted

    properties (Dependent)
        % Type of Control
        Style
        Value
        %Max
        %Min
        %SliderStep
        %ListboxTop

        % Text and Styling
        String
        ForegroundColor
        BackgroundColor
        CData

        % Font
        FontName
        FontSize
        FontWeight
        FontAngle
        FontUnits

        % Interactivity
        Visible
        Enable
        Tooltip
        ContextMenu

        %Position
        Position
        InnerPosition
        OuterPosition
        Extent
        Units
        HorizontalAlignment

        %Callbacks
        Callback
        ButtonDownFcn
        KeyPressFcn
        KeyReleaseFcn
        CreateFcn
        DeleteFcn
       
        % Callback Execution Control
        Interruptible
        BusyAction
        BeingDeleted
        HitTest

        % Parent/Child
        Parent
        Children
        HandleVisibility

        % Identifiers
        Type
        Tag
        UserData
    end

    properties (Access = protected) % Internal store for uicontrol property values that needs custom handling
        Callback_
    end
    
    properties (Access = protected)
        UIControl
    end
    
    methods % Constructor 
        function obj = AbstractControl(options)
            arguments
                %options.?nansen.ui.control.AbstractControl
                options.?matlab.ui.control.UIControl
            end

            options = obj.preprocessOptions(options);
            
            obj.createControl()

            obj.assignPropertyArguments(options)

            if ~nargout; clear obj; end
        end

        function delete(obj)
            % if ~isempty(obj.UIControl) && isvalid(obj.UIControl)
            %     delete(obj.UIControl)
            % end
        end
    end
    
    methods (Abstract, Access = protected)
        createControl(obj)
    end

    methods (Access = protected) % IsStylable method
        function hControl = getStylableControl(obj)
            hControl = obj.UIControl;
        end
    end

    methods (Access = protected)
        function options = preprocessOptions(~, options)
            % Subclasses may implement
            fieldsToIgnore = {'Style'};
            isPresentField = isfield(options, fieldsToIgnore);

            if any(isPresentField)
                fieldsToIgnore = fieldsToIgnore(isPresentField);
                options = rmfield(options, fieldsToIgnore);
            end
        end
    end

    methods % Set/get methods

        function set.Style(~, ~)
            error('NANSEN:UIControl:ReadOnlyProperty', ...
                'Can not set value for ''Style'' property of uicontrol')
        end
        function value = get.Style(obj)
            value = obj.UIControl.Style;
        end
        
        function set.Value(obj, value)
            obj.UIControl.Value = value;
        end
        function value = get.Value(obj)
            value = obj.UIControl.Value;
        end
        
        % function set.Max(obj, value)
        %     obj.UIControl.Max = value;
        % end
        % function value = get.Max(obj)
        %     value = obj.UIControl.Max;
        % end
        % 
        % function set.Min(obj, value)
        %     obj.UIControl.Min = value;
        % end
        % function value = get.Min(obj)
        %     value = obj.UIControl.Min;
        % end
        
        % function set.SliderStep(obj, value)
        %     obj.UIControl.SliderStep = value;
        % end
        % function value = get.SliderStep(obj)
        %     value = obj.UIControl.SliderStep;
        % end
        % 
        % function set.ListboxTop(obj, value)
        %     obj.UIControl.ListboxTop = value;
        % end
        % function value = get.ListboxTop(obj)
        %     value = obj.UIControl.ListboxTop;
        % end
        
        function set.String(obj, value)
            obj.UIControl.String = value;
        end
        function value = get.String(obj)
            value = obj.UIControl.String;
        end
        
        function set.ForegroundColor(obj, value)
            obj.UIControl.ForegroundColor = value;
        end
        function value = get.ForegroundColor(obj)
            value = obj.UIControl.ForegroundColor;
        end
        
        function set.BackgroundColor(obj, value)
            obj.UIControl.BackgroundColor = value;
        end
        function value = get.BackgroundColor(obj)
            value = obj.UIControl.BackgroundColor;
        end
        
        function set.CData(obj, value)
            obj.UIControl.CData = value;
        end
        function value = get.CData(obj)
            value = obj.UIControl.CData;
        end
        
        function set.FontName(obj, value)
            obj.UIControl.FontName = value;
        end
        function value = get.FontName(obj)
            value = obj.UIControl.FontName;
        end
        
        function set.FontSize(obj, value)
            obj.UIControl.FontSize = value;
        end
        function value = get.FontSize(obj)
            value = obj.UIControl.FontSize;
        end
        
        function set.FontWeight(obj, value)
            obj.UIControl.FontWeight = value;
        end
        function value = get.FontWeight(obj)
            value = obj.UIControl.FontWeight;
        end
        
        function set.FontAngle(obj, value)
            obj.UIControl.FontAngle = value;
        end
        function value = get.FontAngle(obj)
            value = obj.UIControl.FontAngle;
        end
        
        function set.FontUnits(obj, value)
            obj.UIControl.FontUnits = value;
        end
        function value = get.FontUnits(obj)
            value = obj.UIControl.FontUnits;
        end

        function set.Visible(obj, value)
            obj.UIControl.Visible = value;
        end
        function value = get.Visible(obj)
            value = obj.UIControl.Visible;
        end
        
        function set.Enable(obj, value)
            obj.UIControl.Enable = value;
        end
        function value = get.Enable(obj)
            value = obj.UIControl.Enable;
        end
        
        function set.Tooltip(obj, value)
            obj.UIControl.Tooltip = value;
        end
        function value = get.Tooltip(obj)
            value = obj.UIControl.Tooltip;
        end
        
        function set.ContextMenu(obj, value)
            obj.UIControl.ContextMenu = value;
        end
        function value = get.ContextMenu(obj)
            value = obj.UIControl.ContextMenu;
        end
        
        function set.Position(obj, value)
            obj.UIControl.Position = value;
        end
        function value = get.Position(obj)
            value = obj.UIControl.Position;
        end
        
        function set.InnerPosition(obj, value)
            obj.UIControl.InnerPosition = value;
        end
        function value = get.InnerPosition(obj)
            value = obj.UIControl.InnerPosition;
        end
        
        function set.OuterPosition(obj, value)
            obj.UIControl.OuterPosition = value;
        end
        function value = get.OuterPosition(obj)
            value = obj.UIControl.OuterPosition;
        end
        
        function set.Extent(obj, value)
            obj.UIControl.Extent = value;
        end
        function value = get.Extent(obj)
            value = obj.UIControl.Extent;
        end
        
        function set.Units(obj, value)
            obj.UIControl.Units = value;
        end
        function value = get.Units(obj)
            value = obj.UIControl.Units;
        end
        
        function set.HorizontalAlignment(obj, value)
            obj.UIControl.HorizontalAlignment = value;
        end
        function value = get.HorizontalAlignment(obj)
            value = obj.UIControl.HorizontalAlignment;
        end
        
        function set.Callback(obj, value)
            assert(isempty(value) || isa(value, 'function_handle'))
            obj.Callback_ = value;
            obj.onCallbackSet()
        end
        function value = get.Callback(obj)
            %value = obj.UIControl.Callback;
            value = obj.Callback_;
        end
        
        function set.ButtonDownFcn(obj, value)
            obj.UIControl.ButtonDownFcn = value;
        end
        function value = get.ButtonDownFcn(obj)
            value = obj.UIControl.ButtonDownFcn;
        end
        
        function set.KeyPressFcn(obj, value)
            obj.UIControl.KeyPressFcn = value;
        end
        function value = get.KeyPressFcn(obj)
            value = obj.UIControl.KeyPressFcn;
        end
        
        function set.KeyReleaseFcn(obj, value)
            obj.UIControl.KeyReleaseFcn = value;
        end
        function value = get.KeyReleaseFcn(obj)
            value = obj.UIControl.KeyReleaseFcn;
        end
        
        function set.CreateFcn(obj, value)
            obj.UIControl.CreateFcn = value;
        end
        function value = get.CreateFcn(obj)
            value = obj.UIControl.CreateFcn;
        end
        
        function set.DeleteFcn(obj, value)
            obj.UIControl.DeleteFcn = value;
        end
        function value = get.DeleteFcn(obj)
            value = obj.UIControl.DeleteFcn;
        end    
        
        function set.Interruptible(obj, value)
            obj.UIControl.Interruptible = value;
        end
        function value = get.Interruptible(obj)
            value = obj.UIControl.Interruptible;
        end
        
        function set.BusyAction(obj, value)
            obj.UIControl.BusyAction = value;
        end
        function value = get.BusyAction(obj)
            value = obj.UIControl.BusyAction;
        end
        
        function set.BeingDeleted(obj, value)
            obj.UIControl.BeingDeleted = value;
        end
        function value = get.BeingDeleted(obj)
            value = obj.UIControl.BeingDeleted;
        end
        
        function set.HitTest(obj, value)
            obj.UIControl.HitTest = value;
        end
        function value = get.HitTest(obj)
            value = obj.UIControl.HitTest;
        end
        
        function set.Parent(obj, value)
            obj.UIControl.Parent = value;
        end
        function value = get.Parent(obj)
            value = obj.UIControl.Parent;
        end
        
        function set.Children(obj, value)
            obj.UIControl.Children = value;
        end
        function value = get.Children(obj)
            value = obj.UIControl.Children;
        end
        
        function set.HandleVisibility(obj, value)
            obj.UIControl.HandleVisibility = value;
        end
        function value = get.HandleVisibility(obj)
            value = obj.UIControl.HandleVisibility;
        end
        
        function set.Type(obj, value)
            obj.UIControl.Type = value;
        end
        function value = get.Type(obj)
            value = obj.UIControl.Type;
        end
        
        function set.Tag(obj, value)
            obj.UIControl.Tag = value;
        end
        function value = get.Tag(obj)
            value = obj.UIControl.Tag;
        end
        
        function set.UserData(obj, value)
            obj.UIControl.UserData = value;
        end
        function value = get.UserData(obj)
            value = obj.UIControl.UserData;
        end
    end
    
    methods (Access = protected) % callbacks for property set events 
        function onCallbackSet(obj)
            obj.UIControl.Callback = obj.Callback_;
        end
    end

    methods
        function tf = isa(obj, typeName)
            if strcmp(typeName, 'matlab.ui.control.UIControl')
                tf = true;
            else
                tf = builtin('isa', obj, typeName);
            end
        end
    end
end
