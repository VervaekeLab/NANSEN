classdef searchAutoCompleteInputDlg < handle & uiw.mixin.AssignPVPairs
    
    
% Credit: https://undocumentedmatlab.com/articles/auto-completion-widget
    
    properties
        Parent
        Callback
        
        PromptText = 'Search for item'
        SelectedItems
        
        Style           % uicontrol compatible
        Tag             % uicontrol compatible
        TooltipString
        
        HideOnFocusLost = false
    end
    
    properties (Dependent)
        Items
        Value
        String          % Same as value...
        
        BackgroundColor
        Units
        Position
        
        Visible
    end
    
    properties (Access = private)
        hBorder
    end
    
    properties %(Access = private)
        
        uiPanel
        
        jSearchField
        jComboBox
        
        hContainerComboBox
        hContainerSearchField
        
        lastSearchText
        
    end
    
    properties (Access = private)
        Items_
        IsConstructed
        BackgroundColor_ = [0.94,0.94,0.94]
        Position_ = [10,10,150,22]
        Units_ = 'pixels'
    end
    
    
    methods
        
        function obj = searchAutoCompleteInputDlg(varargin)
            
            if isempty(varargin); return; end

            % Assume first input is a container/figure...
            if ~isa(varargin{1}, 'matlab.ui.Figure') && ...
                    ~isa(varargin{1}, 'matlab.ui.container.Panel') && ...
                        ~isa(varargin{1}, 'matlab.ui.container.Tab')
                hParent = obj.createFigure();
            else
                hParent = varargin{1};
                varargin = varargin(2:end);
            end

            obj.Items_ = varargin{1};
            varargin = varargin(2:end);

            obj.Parent = hParent;
            obj.assignPVPairs(varargin{:})

            % Create components
            warning('off', 'MATLAB:ui:javacomponent:FunctionToBeRemoved')
            obj.createDropDownSelector()
            obj.createSearchInputField()
            warning('on', 'MATLAB:ui:javacomponent:FunctionToBeRemoved')

            obj.IsConstructed = true;
            obj.onUnitsSet()
            obj.onPositionSet()

            addlistener(obj.Parent, 'ObjectBeingDestroyed', @(s, e) obj.delete);

        end
        
        function delete(obj)
            
            % Todo: Delete these components.
%             jSearchField
%             jComboBox
%         
%             hContainerComboBox
%             hContainerSearchField
            
            
        end
        
        
    end
    
    methods
        
        function set.Visible(obj, newValue)
            obj.hContainerComboBox.Visible = newValue;
            obj.hContainerSearchField.Visible = newValue;
            
            if obj.HideOnFocusLost && strcmp(newValue, 'on')
                % Todo: Find out how to give this component focus..
            end
            
        end
        function visible = get.Visible(obj)
            visible = obj.hContainerComboBox.Visible;
        end
        
        % Set/get units
        function set.Units(obj, newUnits)
            obj.Units_ = newUnits;
            obj.onUnitsSet()
        end
        function units = get.Units(obj)
            if obj.IsConstructed
                units = get(obj.hContainerComboBox, 'Units');
            else
                units = obj.Units_;
            end
        end
        
        % Set/get position
        function set.Position(obj, newPosition)
            obj.Position_ = newPosition;
            obj.onPositionSet();
        end
        function pos = get.Position(obj)
            if obj.IsConstructed
                pos = get(obj.hContainerComboBox, 'Position');
            else
                pos = obj.Position_;
            end
        end
                
        % Set/get background color
        function set.BackgroundColor(obj, newColor)
            obj.BackgroundColor_ = newColor;
            obj.onBackgroundColorSet();
        end
        function color = get.BackgroundColor(obj)
            if obj.IsConstructed
                color = get(obj.hContainerComboBox, 'BackgroundColor');
            else
                color = obj.BackgroundColor_;
            end
        end
        
        
        function set.Items(obj, newValue)
            obj.Items_ = newValue;
            obj.jComboBox.setModel(javax.swing.DefaultComboBoxModel(obj.Items_))
        end
        function value = get.Items(obj)
            value = obj.Items_;
        end
            
        function set.Value(obj, newValue)
        	obj.jSearchField.setText(newValue);
        end
        function value = get.Value(obj)
            value = char( obj.jSearchField.getText() );
        end
        
        
        function set.String(obj, newValue)
        	obj.jSearchField.setText(newValue);
            % Todo: add to items.......
        end
        function value = get.String(obj)
            value = char( obj.jSearchField.getText() );
        end
        
        function set.PromptText(obj, newValue)
            obj.PromptText = newValue;
            obj.onPromptTextSet()
        end
        
        
        function answer = getAnswer(obj)
            answer = char(obj.jSearchField.getText());
        end
        
    end
    
    methods (Access = private) % Component creation

        function createDropDownSelector(obj)
                       
            % Note: MJComboBox is better than JComboBox: the popup panel 
            % has more width than the base control if needed
            obj.jComboBox = com.mathworks.mwswing.MJComboBox(obj.Items_); 
            obj.jComboBox.setEditable(true);
           
            % Set color (unfortunately, this only affects editable combos)
            obj.jComboBox.setBackground(java.awt.Color.white); 
           
            [jhComboBox, hContainer1] = javacomponent(obj.jComboBox, [], obj.Parent);
           
            set(hContainer1, 'Units', obj.Units_, 'Position', obj.Position_);
            obj.hContainerComboBox = hContainer1;
            
            set(obj.jComboBox, 'FocusLostCallback', @(h,e) obj.jComboBox.hidePopup);  % hide the popup when another component is selected
            set(obj.jComboBox, 'ActionPerformedCallback', {@obj.updateSearch, 'ComboBox'});
            
        end

        function createSearchInputField(obj)
            
            if isempty(obj.PromptText)
                promtText = 'Search for item';
            end
            
            
            % Create a SearchTextField control on top of the combo-box
            searchField = com.mathworks.widgets.SearchTextField(obj.PromptText);
            obj.jSearchField = searchField.getComponent;
            [~, hContainer2] = javacomponent(obj.jSearchField, [], obj.Parent);
            
            set(hContainer2, 'Units', obj.Units_, 'Position', obj.Position_ + [0,30,0,0]);
            obj.hContainerSearchField = hContainer2;

            %obj.stripUiControl(obj.jSearchField)
            set(obj.jSearchField, 'Opaque', 0)
            % Expand the SearchTextField component to max available width
%             jSize = java.awt.Dimension(9999, 30);
%             jInputField.getComponent(0).setMaximumSize(jSize);
%             jInputField.getComponent(0).setPreferredSize(jSize);
%             

            % Set callback for mousepress on cancel button
            hjCancelButton = handle(obj.jSearchField.getComponent(1), 'CallbackProperties');
            set(hjCancelButton, 'MousePressedCallback', {@obj.updateSearch, 'cancelButton'});
%             set(hjCancelButton, 'KeyPressedCallback', {@obj.updateSearch, 'cancelButton'});
            
            % Set callback for mousepress on search button
            hjSearchButton = handle(obj.jSearchField.getComponent(0), 'CallbackProperties');
            set(hjSearchButton, 'MousePressedCallback', {@obj.updateSearch, 'searchButton'});
%             set(hjSearchButton, 'KeyPressedCallback', {@obj.updateSearch, 'searchButton'});

            % Set callback for mousepress or keypress on search input field
            set(obj.jSearchField, 'KeyPressedCallback', {@obj.updateSearch, 'searchField'});
            set(obj.jSearchField, 'MousePressedCallback', {@obj.updateSearch, 'searchField'});
            
            
            if obj.HideOnFocusLost
                set(obj.jSearchField, 'FocusLostCallback', @(h,e) obj.hide);  % hide the popup when another component is selected
            else
                set(obj.jSearchField, 'FocusLostCallback', @(h,e) obj.resetScroll);  % hide the popup when another component is selected
            end
            

            
        end
        
        function stripUiControl(obj, jControl)
           
            try
                bgColor = obj.Parent.BackgroundColor;
            catch
                bgColor = obj.Parent.Color;
            end
            javacolor = @javax.swing.plaf.ColorUIResource; 
            
            %set(jControl, 'Focusable', 1)
            set(jControl, 'Opaque', 0)
            set(jControl, 'Border', []);
            
        end
        
        function hide(obj)
            obj.Visible = 'off';
        end
        
    end
    
    methods (Access = private)
        function onPositionSet(obj)
            if obj.IsConstructed
                set(obj.hContainerComboBox, 'Position', obj.Position_)
                set(obj.hContainerSearchField, 'Position', obj.Position_)% + [0,30,0,0])
            end
        end
        
        function onUnitsSet(obj)
            if obj.IsConstructed
                set(obj.hContainerComboBox, 'Units', obj.Units_)
                set(obj.hContainerSearchField, 'Units', obj.Units_)
            end
        end
        
        function onBackgroundColorSet(obj)
            if obj.IsConstructed
                set(obj.hContainerComboBox, 'BackgroundColor', obj.BackgroundColor_)
                set(obj.hContainerSearchField, 'BackgroundColor', obj.BackgroundColor_)
            end
        end
        
        function onPromptTextSet(obj)
            if obj.IsConstructed
                try
                    obj.jSearchField.setPromptText(obj.PromptText);
                catch
                    obj.jSearchField.setToolTipText(obj.PromptText);                    
                end
            end
        end
    end
    
    methods (Access = private)
        
        function resetScroll(obj)
            set(obj.jSearchField, 'ScrollOffset', 1)
        end
        
        function updateSearch(obj, ~, event, sourceName)
            
            searchText = '';

            if isa(event, 'java.awt.event.MouseEvent')
                obj.jComboBox.showPopup()
            end
            
            switch sourceName
                
                % When something happens on combobox, get the current item
                % and put it on the searchfield.
                case 'ComboBox'
                    if ~isa(event, 'java.awt.event.KeyEvent')
                        newItem = get(obj.jComboBox, 'SelectedItem');
                        try
                            obj.jSearchField.setText(newItem)
                        catch
                            obj.jSearchField.setName(newItem)
                        end
                            %obj.Value = newItem;
                        
                        if ~isempty(obj.Callback)
                            obj.SelectedItems = newItem;
                            obj.Callback(obj, event)
                        end
                    end
                    
                % If the search button is clicked, reset the dropdown list
                % of selections and show the dropdown (popup)
                case 'searchButton'
                    obj.jComboBox.setModel(javax.swing.DefaultComboBoxModel(obj.Items_));
                    obj.jComboBox.showPopup;  
                    try
                        set(obj.jSearchField, 'ScrollOffset', 1)
                    catch
                        %todo: what is the effect?
                    end
                    obj.SelectedItems = obj.Items_;
                    if ~isempty(obj.Callback)
                        obj.Callback(obj, event)
                    end

                % If the cancel button is clicked, reset the dropdown list
                % of selections, but do not show the dropdown (popup)
                case 'cancelButton'
                    obj.jComboBox.setModel(javax.swing.DefaultComboBoxModel(obj.Items_));
                    obj.SelectedItems = obj.Items_;
                    
                    if ~isempty(obj.Callback)
                        obj.Callback(obj, event)
                    end
            end
            
            
            % If there is textinput, catch the text on the search field and
            % use it to search in the current dropdown list. If some
            % special characters are pressed, do something else..
            if isa(event, 'java.awt.event.KeyEvent')
            	searchText = obj.jSearchField.getText();
                searchText = char(searchText);
                
                keyCode = get(event, 'KeyCode');

                switch keyCode
                    case 10 % enter/return
                        newItem = get(obj.jComboBox, 'SelectedItem');
                        obj.jSearchField.setText(newItem)
                        obj.jComboBox.hidePopup;
                        return
                    case 38 % uparrow
                        currentSelection = get(obj.jComboBox, 'SelectedIndex');
                        if currentSelection - 1 >= 0
                            obj.jComboBox.setSelectedIndex(currentSelection-1)
                        end
                        return
                    case 40 %downarrow
                        currentSelection = get(obj.jComboBox, 'SelectedIndex');
                        nItems = get(obj.jComboBox, 'ItemCount');
                        if currentSelection + 1 < nItems
                            obj.jComboBox.setSelectedIndex(currentSelection+1)
                        end
                        return
                end
            end
                        
            if isempty(searchText); return; end
            
            searchText = strrep(char(searchText), '*', '.*');  % turn into a valid regexp
            if strcmp(obj.lastSearchText, searchText); return; end

            % If we got this far, it means the user is typing something
            % into the search field. Look for search string in the list of
            % choices and update the dropdown selection list.
            matchInd = ~cellfun('isempty', regexpi(obj.Items_, searchText));

            
             % Compute the filtered names
            newNames = obj.Items_(matchInd);
 
            % Redisplay the updated combo-box popup panel
            if ~isempty(newNames)
                obj.jComboBox.setModel(javax.swing.DefaultComboBoxModel(newNames));
                obj.jComboBox.showPopup;
            else
                obj.jComboBox.setModel(javax.swing.DefaultComboBoxModel({''}))
                obj.jComboBox.hidePopup;
            end
            
            obj.lastSearchText = searchText;
            
            obj.SelectedItems = newNames;
            if ~isempty(obj.Callback)
                obj.Callback(obj, event)
            end
            
        end
        
    end
    
    methods (Static)
        
        function hFigure = createFigure()
            
            hFigure = figure('Position', [400,400,320,500]);
            hFigure.MenuBar = 'none';
            hFigure.Name = 'Find Name';
            hFigure.NumberTitle = 'off';
            
        end
        
    end
    
    
end