classdef VariableModelUI < applify.apptable & nansen.config.mixin.HasDataLocationModel
% Class interface for editing variable name and file settings in a uifigure

%     Table specific:
%     [v] Dynamic update of file type choices based on what is entered in
%        the filename expression field.
%     [v] Remove button for rows...
%     [v] Update datalocation name if it is changed... 
%     [v] Update datalocation items if datalocation is added
%     [ ] Make sure correct number of rows are visible...
%     [ ] By default, only show public variables
%     [ ] Button / dropdown to toggle between different views
%     [ ] Allow removing preset variables.

    properties (Constant)
        DEFAULT_FILETYPES = {'.mat', '.tif', '.raw'}
    end
    
    properties
        %DataLocationModel % DatalocationModel handle
        VariableModel
    end
    
    properties (Dependent)
        FileAdapterList
    end
    
    properties % Toolbar button...
        UIButton_AddVariable
        UIButton_ToggleVariableVisibility
        ButtonGroup
        ToolbarButtons matlab.ui.control.ToggleButton
    end
    
    properties (Access = private) % Layout properties
        ButtonSizeSmall = [22, 22]
        ButtonSizeLarge = [150, 22]
    end
    
    properties (SetAccess = private)
        IsDirty = false % keep this....?
    end

    properties (Access = private)
        VariableAddedListener event.listener
        VariableRemovedListener event.listener
    end
    
    methods % Constructor
        function obj = VariableModelUI(varargin)
        %DataLocationModelUI Construct a DataLocationModelUI instance
            obj@applify.apptable(varargin{:})

            obj.updateDataLocationDropdownItems()
            obj.UIButton_AddVariable.Enable = 'off';
            obj.UIButton_AddVariable.Tooltip = 'Tip: Show Custom Variables to Add New Variable';
            obj.updateVisibleRows()

            if ~nargout
                clear obj
            end
        end
    end
    
    methods % Set / get methods
        function set.VariableModel(obj, newModel)
            obj.VariableModel = newModel;
            obj.onVariableModelSet();
        end
        
        function fileAdapterList = get.FileAdapterList(obj)
            fileAdapterList = nansen.dataio.listFileAdapters();
        end

        % % function set.DataLocationModel(obj, newModel)
        % %
        % %     obj.DataLocationModel = newModel;
        % %     %obj.updateDataLocationDropdownItems();
        % %
        % % end
    end

    methods
        function S = getUpdatedTableData(obj)
        % getUpdatedTableData - Todo: What is this`??

            fileAdapterList = obj.FileAdapterList;

            % Todo: debug this (important)!
            S = obj.Data;
            
            for j = 1:obj.NumRows
                
                hRow = obj.RowControls(j);
                
                try
                    S(j).VariableName = hRow.VariableName.Value;
                    S(j).IsCustom = true;
                catch
                    S(j).VariableName = hRow.VariableName.Text;
                    S(j).IsCustom = false;
                end
                S(j).IsFavorite = strcmp(hRow.StarButton.Tooltip, 'Remove from favorites');
                S(j).FileNameExpression = hRow.FileNameExpr.Value;
                S(j).DataLocation = hRow.DataLocSelect.Value;
                S(j).FileType = hRow.FileTypeSelect.Value;
                S(j).FileAdapter = hRow.FileAdapterSelect.Value;
                
                % Update data type based on fileadapter selection
                isMatch = strcmp({fileAdapterList.FileAdapterName}, S(j).FileAdapter);
                if any(isMatch) && ~strcmp( S(j).FileAdapter, 'Default' )
                    S(j).DataType = fileAdapterList(isMatch).DataType;
                end
            end
        end
        
        function updateFromList(obj, dataVariables)
        % updateFromList - Update data (table) based on list of variable info
            
            for i = numel(dataVariables):-1:1
                variableName = dataVariables(i).VariableName;
                if ~any(obj.VariableModel.containsItem(variableName))
                    obj.addNewVariableItem(dataVariables(i))
                end
            end
        end

        function togglePresetVariableVisibility(obj)
            % Todo: Make method so that this can be toggled
            % programmatically.
            % See: onShowVariablesToggleButtonValueChanged
        end
    end

    methods (Access = protected) % Implement parent class methods

        function assignDefaultTablePropertyValues(obj)

            obj.ColumnNames = {'', 'Data variable name', 'Data location', ...
                 'Filename expression', 'File type', 'File adapter'};
            obj.ColumnHeaderHelpFcn = @nansen.app.setup.getHelpMessage;
            obj.ColumnWidths = [12, 200, 115, 175, 70, 125];
            obj.RowSpacing = 20;
            obj.ColumnSpacing = 18;
        end
        
        function hRow = createTableRowComponents(obj, rowData, rowNum)
        
            hRow = struct();
            
            % % Create button for removing current row.
            i = 1;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);

            hRow.RemoveImage = uibutton(obj.TablePanel);
            hRow.RemoveImage.Position = [xi-4 y wi+10 h]; % Quick fix of pos...
            hRow.RemoveImage.Text = '-';
            hRow.RemoveImage.Text = '';
            hRow.RemoveImage.Icon = nansen.internal.getIconPathName('minus.png');
            hRow.RemoveImage.Tooltip = 'Remove Variable';

            hRow.RemoveImage.ButtonPushedFcn = @obj.onRemoveVariableButtonPushed;
            obj.centerComponent(hRow.RemoveImage, y)
            
            % % Todo: Probably Remove this
            % % if ~rowData.IsCustom
            % %     hRow.RemoveImage.Visible = 'off';
            % % end
            
        % % Create VariableName edit field
            i = 2;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            
            if ~rowData.IsCustom
                hRow.VariableName = uilabel(obj.TablePanel);
                hRow.VariableName.Text = rowData.VariableName;
                hRow.VariableName.Tooltip = rowData.VariableName;
            else
                hRow.VariableName = uieditfield(obj.TablePanel, 'text');
                hRow.VariableName.Value = rowData.VariableName;
            end
            
            hRow.VariableName.FontName = 'Segoe UI';
            hRow.VariableName.BackgroundColor = [1 1 1];
            hRow.VariableName.Position = [xi+25 y wi-25 h];
            obj.centerComponent(hRow.VariableName, y)
            
            % % Create star button
            hRow.StarButton = uiimage(obj.TablePanel);
            hRow.StarButton.Position = [xi y 20 20];
            obj.centerComponent(hRow.StarButton, y)
            hRow.StarButton.ImageClickedFcn = @obj.onStarButtonClicked;
            
            if rowData.IsFavorite
                hRow.StarButton.ImageSource = nansen.internal.getIconPathName('star_on.png');
                hRow.StarButton.Tooltip = 'Remove from favorites';
            else
                hRow.StarButton.ImageSource = nansen.internal.getIconPathName('star_off.png');
                hRow.StarButton.Tooltip = 'Add to favorites';
            end
            
         % % Create DataLocation Dropdown
            i = 3;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);

            hRow.DataLocSelect = uidropdown(obj.TablePanel);
            hRow.DataLocSelect.FontName = 'Segoe UI';
            hRow.DataLocSelect.BackgroundColor = [1 1 1];
            hRow.DataLocSelect.Position = [xi y wi-25 h];
            hRow.DataLocSelect.ValueChangedFcn = @obj.onDataLocationChanged;
            obj.centerComponent(hRow.DataLocSelect, y)
            
            % Fill in values (and items..)
            obj.setDataLocationSelectionDropdownValues(hRow, rowData)
            
            % Create Image for viewing folder
%             i = i+1;
%             [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            hRow.OpenFolderImage = uiimage(obj.TablePanel);
            hRow.OpenFolderImage.Position = [xi+wi-20 y 20 20];
            obj.centerComponent(hRow.OpenFolderImage, y)
            hRow.OpenFolderImage.ImageSource = nansen.internal.getIconPathName('look.png');
            hRow.OpenFolderImage.Tooltip = 'Open session folder';
            hRow.OpenFolderImage.ImageClickedFcn = @obj.openDataFolder;
            
        % % Create Filename Expression edit field
            i = 4;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);

            hRow.FileNameExpr = uieditfield(obj.TablePanel, 'text');
            hRow.FileNameExpr.FontName = 'Segoe UI';
            hRow.FileNameExpr.BackgroundColor = [1 1 1];
            hRow.FileNameExpr.Position = [xi y wi h];
            obj.centerComponent(hRow.FileNameExpr, y)
            hRow.FileNameExpr.ValueChangedFcn = @obj.onFileNameExpressionChanged;
            
            if ~isempty(rowData.FileNameExpression)
                hRow.FileNameExpr.Value = rowData.FileNameExpression;
            end
            
            % Create FileType Dropdown
            i = i+1;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);

            hRow.FileTypeSelect = uidropdown(obj.TablePanel);
            hRow.FileTypeSelect.FontName = 'Segoe UI';
            hRow.FileTypeSelect.BackgroundColor = [1 1 1];
            hRow.FileTypeSelect.Position = [xi y wi h];
            obj.centerComponent(hRow.FileTypeSelect, y)
            
            % Todo: Get this more interactively...
            hRow.FileTypeSelect.Items = obj.DEFAULT_FILETYPES;
            hRow.FileTypeSelect.Value =  obj.DEFAULT_FILETYPES{1};
            
            if ~isempty(rowData.FileType)
                if ~any(strcmp(rowData.FileType, hRow.FileTypeSelect.Items))
                    hRow.FileTypeSelect.Items{end+1} = rowData.FileType;
                end

                hRow.FileTypeSelect.Value = rowData.FileType;
            end
            
            hRow.FileTypeSelect.ValueChangedFcn = @obj.onFileTypeChanged;
            
           % Create FileAdapter Dropdown
            i = i+1;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);

            hRow.FileAdapterSelect = uidropdown(obj.TablePanel);
            hRow.FileAdapterSelect.FontName = 'Segoe UI';
            hRow.FileAdapterSelect.BackgroundColor = [1 1 1];
            hRow.FileAdapterSelect.Position = [xi y wi h];
            obj.centerComponent(hRow.FileAdapterSelect, y)
            
            if ~isempty(rowData.FileType)
                fileAdapterOptions = nansen.dataio.listFileAdapters(rowData.FileType);
                fileAdapterOptions = {fileAdapterOptions.FileAdapterName};
            else
                fileAdapterOptions = {obj.FileAdapterList.FileAdapterName};
            end
                
            hRow.FileAdapterSelect.Items = fileAdapterOptions;

            if ~contains(rowData.FileAdapter, hRow.FileAdapterSelect.Items)
            
                if isempty(rowData.FileAdapter)

                    hRow.FileAdapterSelect.Value = 'Default';
                else
                    hRow.FileAdapterSelect.Items{end+1} = rowData.FileAdapter;
                    hRow.FileAdapterSelect.Value = rowData.FileAdapter;
                end
            else
                hRow.FileAdapterSelect.Value = rowData.FileAdapter;
            end
            
            hRow.FileAdapterSelect.ValueChangedFcn = @obj.onFileAdapterChanged;
        end
        
        function createToolbarComponents(obj, hPanel)
        %createToolbarComponents Create "toolbar" components above table.
            if nargin < 2; hPanel = obj.Parent.Parent; end
                        
            obj.createAddNewDataVariableButton(hPanel)
            
            obj.createShowVariablesToggleButton(hPanel)
        end
        
        function toolbarComponents = getToolbarComponents(obj)
            toolbarComponents = [...
                obj.UIButton_AddVariable, ...
                obj.ButtonGroup ];
        end
    end
    
    methods (Access = protected) % Callbacks
        
        function onDataLocationModelSet(obj)
            onDataLocationModelSet@nansen.config.mixin.HasDataLocationModel(obj)
            obj.updateDataLocationDropdownItems();
        end
        
        function onDataLocationChanged(obj,src, ~)
                                
            rowNumber = obj.getComponentRowNumber(src);
            obj.updateFileTypeDropdownItems(rowNumber)
            
            obj.IsDirty = true;
        end
        
        function onDataLocationAdded(obj, ~, evt)
        %onDataLocationAdded Callback for DataLocationModel event
        %
        %   This method is inherited from the HasDataLocationModel
        %   superclass and is triggered by the DataLocationAdded event on
        %   the DataLocationModel object
        
            obj.updateDataLocationDropdownItems()
        end
        
        function onDataLocationRemoved(obj, ~, evt)
        %onDataLocationRemoved Callback for DataLocationModel event
        %
        %   This method is inherited from the HasDataLocationModel
        %   superclass and is triggered by the DataLocationRemoved event on
        %   the DataLocationModel object
            
            obj.updateDataLocationDropdownItems()
        end
                
        function onDataLocationNameChanged(obj, src, evt)
        %onDataLocationNameChanged Callback for VariableModel event
            for i = 1:numel(obj.Data)
                obj.Data(i).DataLocation = obj.VariableModel.Data(i).DataLocation;
                hRow = obj.RowControls(i);
                obj.setDataLocationSelectionDropdownValues(hRow, obj.Data(i))
            end
        end

        function onVariableAdded(obj, src, evtData)
        % onVariableAdded - Callback for VariableAdded event on Model
            variableItem = evtData.VariableInfo;
            obj.addVariableToTable(variableItem)
        end

        function onVariableRemoved(obj, src, evtData)
        % onVariableRemoved - Callback for VariableRemoved event on Model

            variableName = evtData.VariableName;
            variableNames = obj.getVariableNamesFromControls();

            % Find row number:
            rowNumber = find(strcmp(variableNames, variableName));
            obj.removeRow(rowNumber)
        end

        function onStarButtonClicked(obj, src, ~)
            
            switch src.Tooltip
                case 'Remove from favorites'
                    src.Tooltip = 'Add to favorites';
                    src.ImageSource = nansen.internal.getIconPathName('star_off.png');
                case 'Add to favorites'
                    src.Tooltip = 'Remove from favorites';
                    src.ImageSource = nansen.internal.getIconPathName('star_on.png');
            end
        end
        
        function onFileNameExpressionChanged(obj,src, ~)
                                
            rowNumber = obj.getComponentRowNumber(src);
            obj.updateFileTypeDropdownItems(rowNumber)
            
            obj.IsDirty = true;
        end
        
        function onFileTypeChanged(obj, src, evt)
        %onFileTypeChanged Callback for filetype selection changed
        
            % Get row number where filetype was changed
            rowNumber = obj.getComponentRowNumber(src);
            hRow = obj.RowControls(rowNumber);
            
            % Get the selected filetype
            fileType = hRow.FileTypeSelect.Value;
            fileType = strrep(fileType, '.', '');
            
            fileAdapterOptions = nansen.dataio.listFileAdapters(fileType);
            fileAdapterOptions = {fileAdapterOptions.FileAdapterName};

            % Update the list of file adapters available for this filetype
            if ~isequal(fileAdapterOptions, {'N/A'})
                hRow.FileAdapterSelect.Items = fileAdapterOptions;

                if ~contains(hRow.FileAdapterSelect.Value, fileAdapterOptions)
                    hRow.FileAdapterSelect.Value = fileAdapterOptions{1};
                end
            else
                hRow.FileAdapterSelect.Items = fileAdapterOptions;
                hRow.FileAdapterSelect.Value = fileAdapterOptions{1};
            end
        end
        
        function onFileAdapterChanged(obj, src, evt)
        %onFileAdapterChanged Callback for file adapter selection changed
            
            % Get row number where file adapter was changed
            rowNumber = obj.getComponentRowNumber(src);
            hRow = obj.RowControls(rowNumber);
            
            % Get the selected filetype for this row
            fileType = hRow.FileTypeSelect.Value;
            fileType = strrep(fileType, '.', '');

            % Check if the current file adapter selection is supporting
            % this filetype
            newValue = evt.Value;
            fileAdapterList = obj.FileAdapterList;
            isMatch = strcmp({fileAdapterList.FileAdapterName}, newValue);
            
            % Reset the file adapter selection if filetype is not supported
            if any(strcmp(fileAdapterList(isMatch).SupportedFileTypes, fileType))
                % pass
            else
                hFig = ancestor(obj.Parent, 'figure');
                allowedFileTypes = strcat('.', fileAdapterList(isMatch).SupportedFileTypes);
                supportedFileTypes = strjoin(allowedFileTypes, ', ');
                uialert(hFig, sprintf('The file adapter "%s" supports the following file types: %s', newValue, supportedFileTypes), 'Selection Aborted')
                src.Value = evt.PreviousValue;
            end
        end
        
        function pathStr = getSelectedDataLocationFolderPath(obj, rowNumber)
            
            hRow = obj.RowControls(rowNumber);
            
            ind = find( strcmp(hRow.DataLocSelect.Items, ...
                hRow.DataLocSelect.Value) );

            pathStr = obj.DataLocationModel.Data(ind).ExamplePath;
        end
        
        function openDataFolder(obj, src, evt)
        
            rowNumber = obj.getComponentRowNumber(src);
            folderPath = obj.getSelectedDataLocationFolderPath(rowNumber);
            
            utility.system.openFolder(folderPath)
        end
        
        function onAddNewVariableButtonPushed(obj, src, event)
        % onAddNewVariableButtonPushed - Callback for table button
            
            newVariableItem = obj.VariableModel.getDefaultItem('');
            obj.addNewVariableItem(newVariableItem)
        end
        
        function onRemoveVariableButtonPushed(obj, src, ~)
        % onRemoveVariableButtonPushed - Callback for table button
            rowNumber = obj.getComponentRowNumber(src);

            obj.VariableModel.disableNotifications()
            obj.VariableModel.removeItem(rowNumber)
            obj.VariableModel.enableNotifications()
            
            obj.removeRow(rowNumber)
        end
        
        function onShowVariablesToggleButtonValueChanged(obj, src, event)
            
            obj.UIButton_AddVariable.Enable = obj.ToolbarButtons(2).Value;
            if obj.ToolbarButtons(2).Value
                obj.UIButton_AddVariable.Tooltip = 'Add New Variable';
            else
                obj.UIButton_AddVariable.Tooltip = 'Tip: Show Custom Variables to Add New Variable';
            end

            obj.updateVisibleRows()
            obj.TablePanel.Scrollable='off';
            drawnow
            obj.TablePanel.Scrollable='on';
        end
        
        function onVariableModelSet(obj)
            
            addlistener(obj.VariableModel, 'DataLocationNameChanged', ...
                @obj.onDataLocationNameChanged);

            if ~isempty(obj.VariableAddedListener)
                delete(obj.VariableAddedListener)
            end
            obj.VariableAddedListener = listener(obj.VariableModel, ...
                'VariableAdded', @obj.onVariableAdded);
            
            if ~isempty(obj.VariableRemovedListener)
                delete(obj.VariableRemovedListener)
            end
            obj.VariableRemovedListener = listener(obj.VariableModel, ...
                'VariableRemoved', @obj.onVariableRemoved);
        end
    end
    
    methods (Access = private) % Methods for creating toolbar components
        
        function createAddNewDataVariableButton(obj, ~)
                        
            % Assumes obj.Parent has same parent as hPanel given as input
            hPanel = obj.Parent.Parent;
            
            tablePanelPosition = obj.Parent.Position;
            buttonSize = obj.ButtonSizeSmall;
            
            % Determine where to place button:
            SPACING = [3,3];
            
            location = tablePanelPosition(1:2) + tablePanelPosition(3:4) - [1,0] .* buttonSize + [-1, 1] .* SPACING;

            obj.UIButton_AddVariable = uibutton(hPanel, 'push');
            obj.UIButton_AddVariable.ButtonPushedFcn = @(s, e) obj.onAddNewVariableButtonPushed;
            obj.UIButton_AddVariable.Position = [location buttonSize];
            obj.UIButton_AddVariable.Text = '';
            obj.UIButton_AddVariable.Icon = nansen.internal.getIconPathName('plus.png');
            obj.UIButton_AddVariable.Tooltip = 'Add New Variable';
        end
        
        function createShowVariablesToggleButton(obj, ~)
            import uim.utility.layout.subdividePosition
            
            hPanel = obj.Parent.Parent;

            toolbarPosition = obj.getToolbarPosition();
            
            buttonNames = {'Show Preset Variables', 'Show Custom Variables', 'Show Internal Variables'};
            buttonWidths = [140, 140, 140];
            numButtons = numel(buttonNames);

            % Get component positions for the components on the left
            [Xl, Wl] = subdividePosition(1, ...
                toolbarPosition(3), buttonWidths, 10);
            Y = toolbarPosition(2);

            % Create ButtonGroup
            obj.ButtonGroup = uibuttongroup(hPanel);
            obj.ButtonGroup.BorderType = 'none';
            obj.ButtonGroup.Position = [toolbarPosition(1) Y 150*3 22];
            
            % Create buttons
            for i = 1:numButtons
                obj.ToolbarButtons(i) = uitogglebutton(obj.ButtonGroup);
                obj.ToolbarButtons(i).Position = [Xl(i) 1 Wl(i) 22];
                obj.ToolbarButtons(i).Text = buttonNames{i};
            end
            obj.ButtonGroup.SelectionChangedFcn = @obj.onShowVariablesToggleButtonValueChanged;
        end
    end

    methods (Access = private) % Methods for updating components
        
        function visibleRowIndices = getVisibleRowIndices(obj)
            isVisible = false(size(obj.Data));

            if obj.ToolbarButtons(1).Value
                isVisible = isVisible | ...
                    (~[obj.Data.IsCustom] & ~[obj.Data.IsInternal]);
            end

            if obj.ToolbarButtons(2).Value
                isVisible = isVisible | ...
                    ([obj.Data.IsCustom] & ~[obj.Data.IsInternal]);
            end

            if obj.ToolbarButtons(3).Value
                isVisible = isVisible | [obj.Data.IsInternal];
            end

            visibleRowIndices = find(isVisible);
        end

        function updateVisibleRows(obj)
            
            makeVisible = false(size(obj.Data));
            visibleRowIndices = getVisibleRowIndices(obj);
            makeVisible(visibleRowIndices) = true;

            if isempty(obj.RowControls); return; end
            rowComponentNames = fieldnames(obj.RowControls);
            
            for iRow = 1:numel(obj.RowControls)
                for jCol = 1:numel(rowComponentNames)
                    if makeVisible(iRow)
                        obj.RowControls(iRow).(rowComponentNames{jCol}).Visible = 'on';
                    else
                        obj.RowControls(iRow).(rowComponentNames{jCol}).Visible = 'off';
                    end
                end
            end

            % Reposition to make visible rows appear from top:
            for iRow = 1:numel(visibleRowIndices)
                for jCol = 1:numel(rowComponentNames)
                    [~, y, ~, ~] = obj.getCellPosition(iRow, 1);
                    rowNum = visibleRowIndices(iRow);
                    obj.RowControls(rowNum).(rowComponentNames{jCol}).Position(2)=y;
                end
            end
        end

        function showVariables(obj, flag)
            
            if nargin < 2 || isempty(flag)
                flag = 'all';
            end
            
            flag = validatestring(flag, {'all', 'preset', 'custom', 'internal'}, 1);
                   
            makeVisible = true(size(obj.Data));

            if strcmp(flag, 'all')
                % Keep all
            elseif strcmp(flag, 'preset')
                makeVisible = makeVisible & ~[obj.Data.IsCustom] & ~[obj.Data.IsInternal];
            elseif strcmp(flag, 'custom')
                makeVisible = makeVisible & [obj.Data.IsCustom] & ~[obj.Data.IsInternal];
            elseif strcmp(flag, 'internal')
                makeVisible = makeVisible & [obj.Data.IsInternal];
            end
            
            rowComponentNames = fieldnames(obj.RowControls);
            
            for iRow = 1:numel(obj.RowControls)
                for jCol = 1:numel(rowComponentNames)
                    if makeVisible(iRow)
                        obj.RowControls(iRow).(rowComponentNames{jCol}).Visible = 'on';
                    else
                        obj.RowControls(iRow).(rowComponentNames{jCol}).Visible = 'off';
                    end
                end
            end
        end

        function setDataLocationSelectionDropdownValues(obj, hRow, rowData)
            
            hRow.DataLocSelect.Items = {obj.DataLocationModel.Data.Name}; % Todo: Where to get this from?
            if ~isempty(rowData.DataLocation)
                if contains(rowData.DataLocation, hRow.DataLocSelect.Items)
                    hRow.DataLocSelect.Value = rowData.DataLocation;
                else
                    hRow.DataLocSelect.Items{end+1} = rowData.DataLocation;
                    hRow.DataLocSelect.Value = rowData.DataLocation;
                end
            end
        end
        
        function updateDataLocationDropdownItems(obj)
            
            if obj.IsConstructed
                for i = 1:obj.NumRows
                    obj.RowControls(i).DataLocSelect.Items = {obj.DataLocationModel.Data.Name};
                end
            end
        end
        
        function updateFileTypeDropdownItems(obj, rowNumber)
        %updateFileTypeDropdownItems Update items of file type dropdown
        
            hRow = obj.RowControls(rowNumber);
            
            folderPath = obj.getSelectedDataLocationFolderPath(rowNumber);
            fileNameExpression = hRow.FileNameExpr.Value;
            
            % Find files in folder
            expression = ['*', fileNameExpression, '*'];
            % Make sure we don't have two successive wildcards.
            expression = strrep(expression, '**', '*');
            L = dir(fullfile(folderPath, expression));
            keep = ~strncmp({L.name}, '.', 1);
            L = L(keep);
            
            listOfFileExtension = cell(numel(L), 1);
            for i = 1:numel(L)
                [~, ~, ext] = fileparts(L(i).name);
                listOfFileExtension{i} = ext;
            end
            
            if isempty(listOfFileExtension)
                listOfFileExtension = obj.DEFAULT_FILETYPES;
            end
            
            listOfFileExtension = unique(listOfFileExtension);
            
            hRow.FileTypeSelect.Items = listOfFileExtension;
            % Todo: List files....
        end
        
        function addNewVariableItem(obj, variableItem)
        % addNewVariableItem - Add new variable item.

            if ~isfield(variableItem, 'Uuid')
                variableItem.Uuid = nansen.util.getuuid();
            end

            if isempty(variableItem.VariableName)
                variableItem.VariableName = obj.VariableModel.getNewName();
            end

            % Add variable to model, while disabling model notifications
            obj.VariableModel.disableNotifications()
            obj.VariableModel.insertItem(variableItem)
            obj.VariableModel.enableNotifications()

            obj.addVariableToTable(variableItem)
            obj.IsDirty = true;
        end
    
        function addVariableToTable(obj, variableItem)
            numRows = obj.NumRows;

            obj.addRow(numRows+1, variableItem)

            % Place as next visible row:
            visibleRowIndices = obj.getVisibleRowIndices();
            numVisibleRows = numel(visibleRowIndices);
            
            % Reposition to make new row appear on top:
            rowComponentNames = fieldnames(obj.RowControls);
            rowNum = numRows+1;

            for jCol = 1:numel(rowComponentNames)
                [~, y, ~, ~] = obj.getCellPosition(numVisibleRows, 1);
                obj.RowControls(rowNum).(rowComponentNames{jCol}).Position(2)=y;
            end
        end
    
        function variableNames = getVariableNamesFromControls(obj)

            varNameControls = [obj.RowControls.VariableName];
            variableNames = cell(size(varNameControls));

            for i = 1:numel(varNameControls)
                if isa(varNameControls(i), 'matlab.ui.control.Label')
                    variableNames{i} = varNameControls(i).Text;
                elseif isa(varNameControls(end), 'matlab.ui.control.EditField')
                    variableNames{i} = varNameControls(i).Value;
                end
            end
        end
    end
end
