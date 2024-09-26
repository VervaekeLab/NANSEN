classdef searchAutoCompleteInputDlg < handle
    
    properties (Access = private)
        
        uiPanel
        
        jSearchField
        jComboBox
        
        lastSearchText
        listOfChoices
        
    end
    
    methods
        
        function obj = searchAutoCompleteInputDlg(varargin)
            
                if isempty(varargin); return; end
            
                % Assume first input is a container/figure...
                if ~isa(varargin{1}, 'matlab.ui.Figure')
                    parentHandle = figure('Position', [400,400,320,500]);
                    parentHandle.MenuBar = 'none';
                    parentHandle.Name = 'Find Name';
                    parentHandle.NumberTitle = 'off';
                else
                    parentHandle = varargin{1};
                    varargin = varargin(2:end);
                end
                
                listOfChoices = varargin{1};
                varargin = varargin(2:end);
                
                obj.uiPanel = uipanel('Parent', parentHandle);
                obj.uiPanel.Position = [0,0,1,1];
                obj.uiPanel.BorderType = 'none';
                
                if any(contains(varargin(1:2:end), 'Position'))
                    ind = find(contains(varargin(1:2:end), 'Position'));
                    posArg = varargin{(ind-1)*2 + 2};
                    obj.uiPanel.Position = posArg;
                end
                
                obj.createDropDownSelector(listOfChoices)
                
                if any(contains(varargin(1:2:end), 'TextPrompt'))
                    ind = find(contains(varargin(1:2:end), 'TextPrompt'));
                    txtArg = varargin{(ind-1)*2 + 2};
                else
                    txtArg = '';
                end
                
                obj.createSearchInputField(txtArg)

        end
        
        function createDropDownSelector(obj, listOfChoices)
                       
            % Note: MJComboBox is better than JComboBox: the popup panel
            % has more width than the base control if needed
            obj.jComboBox = com.mathworks.mwswing.MJComboBox(listOfChoices);
            obj.jComboBox.setEditable(true);
           
            % Set color (unfortunately, this only affects editable combos)
            obj.jComboBox.setBackground(java.awt.Color.white);
           
            [jhComboBox, hContainer1] = javacomponent(obj.jComboBox, [], obj.uiPanel);
%             set(jhComboBox, 'ActionPerformedCallback', []);
           
            set(hContainer1, 'Units', 'normalized', 'Position',[0,0,1,1]);
           
% %             jhComboBox = handle(obj.jComboBox, 'CallbackProperties');
% %             set(jhComboBox, 'MousePressedCallback', @(src, event) disp('mousepress on jhComboBox'))
% %
% % %             obj.jComboBox.getComponent(0) - Combobox Button
% %             set(obj.jComboBox.getComponent(0), 'MousePressedCallback', @(src, event) disp('mousepress on combobox button'))
% % %             obj.jComboBox.getComponent(1) - Cell Renderer Pane
% %             set(obj.jComboBox.getComponent(1), 'MousePressedCallback', @(src, event) disp('mousepress on cell renderer pane'))
% % %             obj.jComboBox.getComponent(2) - Textfield
% %             set(obj.jComboBox.getComponent(2), 'MousePressedCallback', @(src, event) disp('mousepress on textfield'))

            set(obj.jComboBox, 'FocusLostCallback', @(h,e)obj.jComboBox.hidePopup);  % hide the popup when another component is selected
            set(obj.jComboBox, 'ActionPerformedCallback', {@obj.updateSearch, 'ComboBox'});
            obj.listOfChoices = listOfChoices;
            
        end
        
        function createSearchInputField(obj, txtArg)
            
            % Create a SearchTextField control on top of the combo-box
            searchField = com.mathworks.widgets.SearchTextField(txtArg);
            obj.jSearchField = searchField.getComponent;
            [~, hContainer2] = javacomponent(obj.jSearchField, [], obj.uiPanel);
            
            set(hContainer2, 'Units', 'normalized', 'Position',[0,0,1,1]);

            % Expand the SearchTextField component to max available width
%             jSize = java.awt.Dimension(9999, 20);
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
            
            set(obj.jSearchField, 'FocusLostCallback', @(h,e)obj.resetScroll);  % hide the popup when another component is selected
            
        end
        
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
                        obj.jSearchField.setText(newItem)
                    end
                    
                % If the search button is clicked, reset the dropdown list
                % of selections and show the dropdown (popup)
                case 'searchButton'
                    obj.jComboBox.setModel(javax.swing.DefaultComboBoxModel(obj.listOfChoices));
                    obj.jComboBox.showPopup;
                    set(obj.jSearchField, 'ScrollOffset', 1)

                % If the cancel button is clicked, reset the dropdown list
                % of selections, but do not show the dropdown (popup)
                case 'cancelButton'
                    obj.jComboBox.setModel(javax.swing.DefaultComboBoxModel(obj.listOfChoices));

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

            % If we got this far, it measn the user is typing something
            % into the search field. Look for search string in the list of
            % choices and update the dropdown selection list.
            matchInd = ~cellfun('isempty', regexpi(obj.listOfChoices, searchText));
            
             % Compute the filtered names
            newNames = obj.listOfChoices(matchInd);
 
            % Redisplay the updated combo-box popup panel
            if ~isempty(newNames)
                obj.jComboBox.setModel(javax.swing.DefaultComboBoxModel(newNames));
                obj.jComboBox.showPopup;
            else
                obj.jComboBox.setModel(javax.swing.DefaultComboBoxModel({''}))
                obj.jComboBox.hidePopup;
            end
            
            obj.lastSearchText = searchText;
            
        end
        
        function answer = getAnswer(obj)
            answer = char(obj.jSearchField.getText());
        end
    end
end
