classdef multiSelectionDropDown <  uim.handle & uiw.mixin.AssignPVPairs
%multiSelectionDropDown Implements a dropdown menu with multiselection
%
%   This class is based on the listbox uicontrol, but some of the
%   underlying java-object's properties are modified so that the listbox
%   appears and disappears like a dropdown menu
    
    % Todo List:
    %
    % [ ] Implement maxHeight and vertical scrollbar.
    %
    % [ ] Place in a panel. Could even create an axes, and patch a custom
    % panel appearance. (Access java object, and make it transparent, then 
    % patch the shape in the axes, and place the listbox on top of the axes 
    % with no borders and same background color).
    %
    % [ ] Improve value change callback? I.e, it should not be necessary to
    % have a set-method for callback, instead create internal callback
    % handler that calls callback function if it is assigned.
    
    
    properties
        
        Parent = []
        
        String = {}
        Visible = 'off'
        
        Location = []
        Position = []
        
        MinimumWidth = 70;
        MinimumHeight = 100;
        
        BackgroundColor = ones(1,3) * 0.2
        ForegroundColor = ones(1,3) * 0.8
        BorderColor = ones(1,3) * 0.5
        
        Callback = []
    end
      
    properties (Dependent)
        Value = []
    end
    
    properties (Access = private, Transient)
        hUiControl
        jUiControl
        
        hFigure
        
        ParentContainerDestroyedListener
        ParentContainerSizeChangedListener event.listener % not used...
        ParentContainerLocationChangedListener event.listener % not used...
        IsConstructed = false
    
    end
    
    
    methods
        
        function obj = multiSelectionDropDown(varargin)
                       
            applify.AppWindow.switchJavaWarnings('off')

            obj.assignPVPairs(varargin{:})
            createListbox(obj)
            
            applify.AppWindow.switchJavaWarnings('on')

            addlistener(obj.Parent, 'ObjectBeingDestroyed', @(s, e) obj.delete);
            
            obj.Visible = 'on';
            obj.IsConstructed = true;
        end
        
        function delete(obj)
            delete(obj.hUiControl)
            delete(obj)
        end
        
    end
    
    methods (Access = private)
        
        function createListbox(obj)

            h = uicontrol(obj.Parent, 'style', 'listbox', 'String', obj.String, ...
                'BackgroundColor', obj.BackgroundColor, ...
                'ForegroundColor', obj.ForegroundColor);
            
            if ~isempty(obj.Parent)
                %h.Parent = obj.Parent;
                obj.hFigure = ancestor(obj.Parent, 'figure');
            end
            
            h.Max = 2;
            h.String = obj.String;
            h.BackgroundColor = obj.BackgroundColor;
            h.ForegroundColor = obj.ForegroundColor;
            h.Position(1:2) = obj.Location;
            
            % Get java handle to the listbox panel
            j = findjobj(h);
            
            h.ButtonDownFcn = @obj.onButtonPressed;
            h.KeyPressFcn = @obj.onKeypressed;
            h.Callback = @obj.Callback;

            % Get java handle to the listbox viewport
            jViewport =  j.getComponent(0);

            rgbBg = obj.BackgroundColor;
            rgbFg = obj.ForegroundColor;

            bgColor = java.awt.Color(rgbBg(1), rgbBg(2), rgbBg(3));
            fgColor = java.awt.Color(rgbFg(1), rgbFg(2), rgbFg(3));

            jViewport.setBackground( bgColor )

            
            % Get the java handle for the listbox component
            jList =  jViewport.getComponent(0);
            jList.setBackground( bgColor )
            jList.setForeground( fgColor )

            
            jList = handle(jList, 'CallbackProperties');
            set(jList, 'FocusLostCallback', @(s,e) obj.hide)
            set(jList, 'MouseClickedCallback', @obj.onMouseClicked)

            % Make custom border
            mRgb = obj.BorderColor;
            borderColor = java.awt.Color(mRgb(1), mRgb(2), mRgb(3));
            tableBorder = javax.swing.border.LineBorder(borderColor, 1, 0); % color, thickness, rounded corners (tf)
            j.setBorder(tableBorder)
            
            %j.setBorder(javax.swing.BorderFactory.createRaisedBevelBorder());

            % Get java handle for vertical scroller
            %jVScroller = j.getComponent(1);
            %set(jVScroller, 'PreferredSize', java.awt.Dimension(0, 50) );
%             set(jVScroller, 'AdjustmentValueChangedCallback', ...
%                 @app.onVerticalScrollerValueChanged)


            % Make sure listbox is invisible
            %h.Visible = 'off';

            obj.hUiControl = h;
            obj.jUiControl = jList;
            
        end

    end
    
    methods
        
        function set.Position(obj, newPosition)
            obj.onPositionChanged(newPosition)
        end
        
        function position = get.Position(obj)
            position = obj.hUiControl.Position;
        end
        
        function set.Visible(obj, newValue)
            % Todo: Add assertion
            obj.Visible = newValue;
            obj.onVisibleChanged()
        end
        
        function set.String(obj, newValue)
            
            assert(isa(newValue, 'cell'), 'String Property must be a cell array')
            obj.String = newValue;
            
            obj.onStringUpdated()
        end
        
        function set.Value(obj, newValue) % Note: dependent
            obj.hUiControl.Value = newValue;
            %obj.onValueUpdated(newValue)
        end
        
        function set.Callback(obj, newValue)
            
           %assert isa function handle
           obj.Callback = newValue;
           obj.onCallbackChanged()
            
        end
        
        function val = get.Value(obj)
            val = obj.hUiControl.Value;
        end
    end
    
    methods
        function hide(obj)
            if isvalid(obj)
                obj.Visible = 'off';
            end
        end
        
        function show(obj)
            obj.Visible = 'on';
            obj.giveFocus()
        end
        
        function giveFocus(obj)
            uicontrol(obj.hUiControl)
        end

        function reset(obj)
            obj.Value = 1;
        end
    end
    
    
    methods
        
        function onKeypressInListbox(obj, ~, evt)
            switch evt.Key
                case 'return'
                    obj.Visible = 'off';
            end
        end

        function onVisibleChanged(obj)
            
            if ~isempty(obj.hUiControl) && ~isvalid(obj.hUiControl); return; end
            
            obj.hUiControl.Visible = obj.Visible;

            if strcmp(obj.Visible, 'on')
                obj.giveFocus()                
            end
            
        end
        
        function onPositionChanged(obj, newPosition)
            obj.hUiControl.Position = newPosition;
        end
        
        function onStringUpdated(obj)
           
            % Make sure all entries are visible? Would prefer not to have a  
            % scrollbar visible...
            if ~obj.IsConstructed; return; end

            obj.hUiControl.String = obj.String;
            obj.hUiControl.Position(3) = max(obj.hUiControl.Extent(3)+5, obj.MinimumWidth)+15;
            obj.hUiControl.Position(4) = 200;%max(obj.hUiControl.Extent(4), obj.MinimumHeight);
            
            rgbBg = obj.BackgroundColor;
            rgbFg = obj.ForegroundColor;

            bgColor = java.awt.Color(rgbBg(1), rgbBg(2), rgbBg(3));
            fgColor = java.awt.Color(rgbFg(1), rgbFg(2), rgbFg(3));
            
            obj.jUiControl.setBackground( bgColor )
            obj.jUiControl.setForeground( fgColor )
            
            obj.jUiControl.background = bgColor;
            obj.jUiControl.repaint()
            
        end
        
%         function onValueUpdated()
%             obj.hUiControl.Value = obj.Value;
%         end
        
        function onKeypressed(obj, src, evt)

            switch evt.Key
                case {'return', 'escape'}
                    obj.hide()
            end

            % todo: Trigger value changed....
        end
        
        function onMouseClicked(obj, src, evt)

            switch obj.hFigure.SelectionType
                case 'open'
                    obj.hide()
            end
            
        end

        function onValueChanged(obj, src, evt)
        end
        
        function onCallbackChanged(obj)
            obj.hUiControl.Callback = obj.Callback;
        end
        
    end
    
end