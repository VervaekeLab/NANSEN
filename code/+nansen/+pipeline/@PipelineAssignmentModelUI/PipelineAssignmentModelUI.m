classdef PipelineAssignmentModelUI < applify.apptable
% Class interface for creating pipeline assignment model in a uifigure


% TODO:
%   [ ] Add third button to buttongroup, where user can write an expression
%       or a function handle (1 or 2 buttons?). This is particularly
%       relevant for variables that are numeric, I.e you want to select
%       values in an interval. But also useful in order to to logical
%       operations like and/or.


    properties
        PipelineModel
        MetaTable
        SessionVariableNames
        SessionVariableNamesFree        % Those that are not used yet.
    end

    properties
        IsDirty = false;
        IsAdvancedView = true
    end
    
    properties (Access = protected) % Toolbar Components
        SelectPipelineDropDownLabel
        SelectPipelineDropDown
        UIButton_AddSessionVar
        ButtonSizeSmall = [22, 22]
    end
    
    properties (Access = protected)
        StringFormat = cell(1, 4);
    end
    
    properties % Toolbar
        AdvancedOptionsButton 
    end
    
    
    methods % Structors
        function obj = PipelineAssignmentModelUI(varargin)
        %FolderOrganizationUI Construct a FolderOrganizationUI instance
                        
            obj@applify.apptable(varargin{:})
           
            obj.onModelSet()
        end
        
    end
    
    methods % Set/get methods
       
        function set.MetaTable(obj, value)
            
            obj.MetaTable = value;
            obj.onMetaTableSet();
        end
        
        
        
    end
    

    methods (Access = protected) % Methods for creation
        
        function assignDefaultTablePropertyValues(obj)

            obj.ColumnNames = {'', 'Variable name', 'Selection Mode', 'Input'};
            obj.ColumnHeaderHelpFcn = @nansen.setup.getHelpMessage;
            obj.ColumnWidths = [22, 200, 150, 200];
            obj.RowSpacing = 20;   
            obj.ColumnSpacing = 25;
        end
        
        function hRow = createTableRowComponents(obj, rowData, rowNum)
        
            hRow = struct();
            
            
        % % Create variable name 
            i = 1;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            
            hRow.RemoveRowButton = uibutton(obj.TablePanel);
            hRow.RemoveRowButton.Position = [xi y wi h];
            hRow.RemoveRowButton.Text = '';
            hRow.RemoveRowButton.Icon = 'minus.png';
            obj.centerComponent(hRow.RemoveRowButton, y)
            hRow.RemoveRowButton.ButtonPushedFcn = ...
                @obj.onRemoveSessionVariableButtonPushed;
            
            
        % % Create variable name dropdown
            i = 2;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);

            hRow.VariableNameDropdown = uidropdown(obj.TablePanel);
            hRow.VariableNameDropdown.BackgroundColor = [1 1 1];
            hRow.VariableNameDropdown.Position = [xi y wi h];
            hRow.VariableNameDropdown.FontName = obj.FontName;
            hRow.VariableNameDropdown.ValueChangedFcn = @obj.onVariableNameSelectionChanged;
            obj.centerComponent(hRow.VariableNameDropdown, y)
            
            obj.updateVariableNameDropdown(rowNum, ...
                hRow.VariableNameDropdown)

            
        % % Create Togglebutton group for selecting string detection mode
            i = 3;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            
            % Create button group
            hRow.SelectionModeButtonGroup = uibuttongroup(obj.TablePanel);
            hRow.SelectionModeButtonGroup.BorderType = 'none';
            hRow.SelectionModeButtonGroup.BackgroundColor = [1 1 1];
            hRow.SelectionModeButtonGroup.Position = [xi y wi h];
            hRow.SelectionModeButtonGroup.FontName = obj.FontName;
            obj.centerComponent(hRow.SelectionModeButtonGroup, y)
            
            hRow.SelectionModeButtonGroup.SelectionChangedFcn = ...
                @obj.onSelectionModeButtonGroupValueChanged;
            
            % Create ModeButton1
            ModeButton1 = uitogglebutton(hRow.SelectionModeButtonGroup);
            ModeButton1.Text = 'Matches';
            ModeButton1.Position = [1 1 62 22];
            ModeButton1.Value = true;

            % Create ModeButton2
            ModeButton2 = uitogglebutton(hRow.SelectionModeButtonGroup);
            ModeButton2.Text = 'Contains';
            ModeButton2.Position = [62 1 62 22];
            
            obj.updateSelectionModeButtonGroup(rowNum, ...
                hRow.SelectionModeButtonGroup)


        % % Create Editbox for string input
            i = 4;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);

            hRow.VariableValueInputField = uieditfield(obj.TablePanel, 'text');
            hRow.VariableValueInputField.Position = [xi y wi h];
            hRow.VariableValueInputField.FontName = obj.FontName;
            hRow.VariableValueInputField.ValueChangedFcn = @obj.onVariableValueChanged;
            
            obj.centerComponent(hRow.VariableValueInputField, y)
            
            
        % % Create dropdown for selection...
            hRow.VariableValueDropdown = uidropdown(obj.TablePanel);
            hRow.VariableValueDropdown.Position = [xi y wi h];
            hRow.VariableValueDropdown.FontName = obj.FontName;
            hRow.VariableValueDropdown.ValueChangedFcn = @obj.onVariableValueChanged;
            hRow.VariableValueDropdown.Items = {};
            
            obj.centerComponent(hRow.VariableValueDropdown, y)
            hRow.VariableValueDropdown.Editable = 'on';
            
            % Update value...
            obj.updateVariableValueField(rowNum, hRow)

        end
        
        function createAddNewSessionVariableButton(obj, hPanel)
        
            % Todo: implement as toolbar...
            
            % Assumes obj.Parent has same parent as hPanel given as input
            tablePanelPosition = obj.Parent.Position;
            buttonSize = obj.ButtonSizeSmall;
            
            % Determine where to place button:
            SPACING = [3,3];
            
            location = tablePanelPosition(1:2) + tablePanelPosition(3:4) - [1,0] .* buttonSize + [-1, 1] .* SPACING;

            obj.UIButton_AddSessionVar = uibutton(hPanel, 'push');
            obj.UIButton_AddSessionVar.ButtonPushedFcn = @(s, e) obj.onAddNewSessionVariableButtonPushed;
            obj.UIButton_AddSessionVar.Position = [location buttonSize];
            obj.UIButton_AddSessionVar.Text = '';
            obj.UIButton_AddSessionVar.Icon = 'plus.png';
            obj.UIButton_AddSessionVar.Tooltip = 'Add New Session Variable';
            
        end
        
    end
    
    methods (Access = private) % Methods for updating component values
        
        function updateVariableNameDropdown(obj, rowNum, hDropdown)
        %updateVariableNameDropdown Update component items and values.   
            if nargin < 3
                hDropdown = obj.RowControls(rowNum).VariableNameDropdown;
            end
            
            hDropdown.Items = [{'Select variable name'}, obj.SessionVariableNames];

            if ~isempty(obj.Data(rowNum).VariableName)
                try
                    hDropdown.Value = obj.Data(rowNum).VariableName;
                catch
                    hDropdown.Value = 'Select variable name';
                end
            end

            obj.updateVariableNameDropdownItems(rowNum, hDropdown)

        end
        
        function updateSelectionModeButtonGroup(obj, rowNum, hButtonGroup)
        %updateSelectionModeButtonGroup    
            if nargin < 3
                hButtonGroup = obj.hRowControls(rowNum).SelectionModeButtonGroup;
            end
            
            rowData = obj.Data(rowNum);
            
            if isempty(rowData.Mode) % initialize...
                rowData.Mode = 'match';
                obj.Data(rowNum).Mode = 'match';
            end
            
            switch lower( rowData.Mode )
                case 'match'
                    hButtonGroup.SelectedObject = hButtonGroup.Children(2);
                case 'contains'
                    hButtonGroup.SelectedObject = hButtonGroup.Children(1);
            end
            
        end
            
        function updateVariableValueField(obj, rowNum, hRow)

            if nargin < 3
                hRow = obj.RowControls(rowNum);
            end
            
            rowData = obj.Data(rowNum);
            
            % Set visibility:
            if strcmp( rowData.Mode, 'match')
                hRow.VariableValueInputField.Visible = 'off';
            elseif strcmp( rowData.Mode, 'contains')
                hRow.VariableValueDropdown.Visible = 'off';
            else
                hRow.VariableValueInputField.Visible = 'off';
            end
            
            % Update values for dropdown
            if ~isempty(rowData.VariableName)
                values = obj.MetaTable.entries.(rowData.VariableName);
                uniqueValues = unique(values);

                % todo...
                if islogical(uniqueValues(1))
                    % Convert to char...
                    uniqueValues = {'true', 'false'};

                elseif isnumeric(uniqueValues(1))
                    uniqueValues = arrayfun(@(x) sprintf('%d', x), uniqueValues, 'uni', 0);
                end
                
                if isempty(uniqueValues)
                    uniqueValues = {''};
                end

                hDropdown = hRow.VariableValueDropdown;
                hDropdown.Items = uniqueValues;

                if ~isempty(rowData.Expression)
                    try
                        hDropdown.Value = rowData.Expression;
                    catch
                        hDropdown.Value = hDropdown.Items{1};
                    end
                end

            end

            % Update values for edit field
            hRow.VariableValueInputField.Value = rowData.Expression;

        end

    end
    
    methods (Access = private)
        
        function name = getCurrentPipelineName(obj)
            name = obj.SelectPipelineDropDown.Value;
        end
        
        function getVariableName(obj, rowNum)
            % Necessary?
        end
        
        function mode = getSelectionMode(obj, rowNum)
            
            hBtnGroup = obj.hControls(rowNum).SelectionModeButtonGroup;
       
            switch hBtnGroup.SelectedObject.Text
                
                case 'Matches'
                    mode = 'match';
                case 'Contains'
                    mode = 'contains';
            end
            
        end
        
        function getVariableValueExpression(obj, rowNum)
            % Necessary?
        end
        
    end % Get component values (note implemented)
    
    methods (Access = private) %Callbacks for userinteraction with components
        
        function onPipelineSelectionChanged(obj,src, evt)
            
            % Update model data for current pipeline.
            pipelineName = evt.PreviousValue;
            obj.updateModel(pipelineName)
             
            % Reset table
            obj.resetTable()

            % Get data for selected pipeline and assign to ui
            selectedPipeline = obj.PipelineModel.getItem(evt.Value);
            obj.Data = selectedPipeline.SessionProperties;
            
            
            
            % Update controls with values from session property fields...
            obj.createTable()

        end
        
        function onAddNewSessionVariableButtonPushed(obj, src, evt)

            rowData = nansen.pipeline.PipelineCatalog.getSessionMetaVariables();
            
            numRows = obj.NumRows;
            obj.addRow(numRows+1, rowData)
            
            % Update selection dropdown with remaining session variable
            % names.
            
            % If 
            
            
        end
        
        function onRemoveSessionVariableButtonPushed(obj, src, evt)
            
            i = obj.getComponentRowNumber(src);
            obj.removeRow(i)
            
            obj.updateVariableNameDropdownItems(1:obj.NumRows)
            
        end
        
        function onVariableNameSelectionChanged(obj, src, ~)
        %onVariableNameSelectionChanged Callback fro dropdown
        
            rowNumber = obj.getComponentRowNumber(src);
            if strcmp( src.Value, 'Select variable name' )
                obj.Data(rowNumber).VariableName = '';
            else
                obj.Data(rowNumber).VariableName = src.Value;
            end
            obj.updateVariableValueField(rowNumber)
            
            % Todo: Make sure other dropdowns don't show this variable as
            % option
            obj.updateVariableNameDropdownItems(1:obj.NumRows)

        end
        
        function onSelectionModeButtonGroupValueChanged(obj, src, evt)
            
            % Get row which user pushed button from
            rowNumber = obj.getComponentRowNumber(src);
            hRow = obj.RowControls(rowNumber);
            
            switch src.SelectedObject.Text
                
                case 'Matches'
                    hRow.VariableValueInputField.Visible = 'off';
                    hRow.VariableValueDropdown.Visible = 'on';
                    obj.Data(rowNumber).Mode = 'match';
                    obj.Data(rowNumber).Expression = hRow.VariableValueDropdown.Value;
                case 'Contains'
                    hRow.VariableValueInputField.Visible = 'on';
                    hRow.VariableValueDropdown.Visible = 'off';
                    obj.Data(rowNumber).Mode = 'contains';
                    obj.Data(rowNumber).Expression = hRow.VariableValueInputField.Value;
            end
            
        end

        function onVariableValueChanged(obj, src, ~)
            rowNumber = obj.getComponentRowNumber(src);
            obj.Data(rowNumber).Expression = src.Value;
        end
    end
    
    methods % Methods for updating
        
        function createToolbar(obj, ~)
        %createToolbar Create components of toolbar acompanying table
        
            import uim.utility.layout.subdividePosition
            hPanel = obj.Parent.Parent;

            toolbarPosition = obj.getToolbarPosition();
            
            labelWidth = 85;
            dropdownWidth = 100;
                        
            Wl_init = [labelWidth, dropdownWidth];
            
            % Get component positions for the components on the left
            [Xl, Wl] = subdividePosition(toolbarPosition(1), ...
                toolbarPosition(3), Wl_init, 10);
            
            Y = toolbarPosition(2);
            
            % Create SelectPipelineDropDownLabel
            obj.SelectPipelineDropDownLabel = uilabel(hPanel);
            obj.SelectPipelineDropDownLabel.Position = [Xl(1) Y Wl(1) 22];
            obj.SelectPipelineDropDownLabel.Text = 'Select pipeline:';

            % Create SelectPipelineDropDown
            obj.SelectPipelineDropDown = uidropdown(hPanel);
            obj.SelectPipelineDropDown.ValueChangedFcn = @obj.onPipelineSelectionChanged;
            obj.SelectPipelineDropDown.Position = [Xl(2) Y Wl(2) 22];
            
            obj.SelectPipelineDropDown.Items = obj.PipelineModel.PipelineNames;
            obj.SelectPipelineDropDown.Value = obj.SelectPipelineDropDown.Items{1};
            
            obj.createAddNewSessionVariableButton(hPanel)
        end
        
        function S = getUpdatedTableData(obj, currentPipelineName)
            
            if nargin < 2
                currentPipelineName = obj.getCurrentPipelineName();
            end
            
            idx = obj.PipelineModel.getItemIndex(currentPipelineName);
            
            S = obj.PipelineModel.Data;
            
            tableData = obj.Data;
            
            % Remove rows where name is empty
            isEmpty = cellfun(@isempty, {tableData.VariableName});
            tableData = tableData(~isEmpty);
            
            S(idx).SessionProperties = tableData;
            
        end
        
        function updateModel(obj, pipelineName)
        %updateModel Update model with changes from UI   
        
            % Update the data for the pipeline with the given name
            S = obj.getUpdatedTableData(pipelineName);
            obj.PipelineModel.setModelData(S)
        
        end
        
        function onModelSet(obj)
        %onModelSet Callback for when DatalocationModel is set/reset
        %
            
        end
        
        function onMetaTableSet(obj)
        %onMetaTableSet Callback for property value set.
        
            % Find variable names from metatable.
            varNames = obj.MetaTable.entries.Properties.VariableNames;
            
            % Only pick values that are char, numeric and logical
            C = table2cell(obj.MetaTable.entries(1,:));
            isValidType = @(x) ischar(x) || isnumeric(x) || islogical(x);
            validVariables = cellfun(isValidType, C);
            
            varNames = varNames(validVariables);
                     
            % But ignore sessionID:
            varNames = setdiff(varNames, {'sessionID', 'Ignore'}, 'stable');
            
            % Assign to properties.
            obj.SessionVariableNames = varNames;
            
        end

    end
    
    methods (Access = private) % Internal updating
        
        function updateFreeSessionVariableNames(obj)
            
            usedVariableNames = {obj.Data.VariableName};
            obj.SessionVariableNamesFree = ...
                setdiff(obj.SessionVariableNames, usedVariableNames, 'stable');
            
        end
        
        function updateVariableNameDropdownItems(obj, rowIdx, hDropdown)
            
            if nargin < 2
                rowIdx = 1:obj.NumRows;
                hDropdown = [obj.RowControls.VariableNameDropdown];
            
            elseif nargin < 3
                hDropdown = [obj.RowControls(rowIdx).VariableNameDropdown];
            end
            
            defaultItems = [{'Select variable name'}, obj.SessionVariableNames];
            
            skipNames = {obj.Data.VariableName};
            
            for i = 1:numel(rowIdx)
                thisName = hDropdown(i).Value;
                tmpSkipNames = setdiff(skipNames, thisName, 'stable');
                itemSelection = setdiff(defaultItems, tmpSkipNames, 'stable');
                hDropdown(i).Items = itemSelection;
            end
            
        end
        
    end
    
    methods
        
        function markClean(obj)
            obj.IsDirty = false;
        end
        
    end
    
end