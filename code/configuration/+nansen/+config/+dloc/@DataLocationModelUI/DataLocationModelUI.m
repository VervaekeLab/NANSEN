classdef DataLocationModelUI < applify.apptable & nansen.config.mixin.HasDataLocationModel
% Class interface for editing data locations in a uifigure  
    
% Todo: Simplify component creation. 
%     [] Get cell locations as array with one entry for each column of a row.
%     [] Do the centering when getting the cell locations.

%     [] Set fontsize/bg color and other properties in batch.

%     [] get a default struct 
    
    
    properties (SetAccess = private)
        IsDirty = false % keep this....?
    end
    
    properties
        RootPathComponentType = 'uieditfield' % 'uieditfield' | 'uidropdown'
    end

    properties % Toolbar button...
        UIButton_AddDataLocation
        SelectDataLocationDropDownLabel
        SelectDataLocationDropDown
    end
    
    properties (Access = private) % Layout properties
        ButtonSizeSmall = [22, 22]
        ButtonSizeLarge = [70, 22]
    end
    
    
    methods
        function obj = DataLocationModelUI(dataLocationModel, varargin)
        %DataLocationModelUI Construct a DataLocationModelUI instance
            obj@nansen.config.mixin.HasDataLocationModel(dataLocationModel)
            
            varargin = [varargin, {'Data', dataLocationModel.Data}];
            obj@applify.apptable(varargin{:})
        end
    end
    
    methods (Access = protected) % Implementation of superclass methods
        
        function assignDefaultTablePropertyValues(obj)
            
            %obj.ColumnNames = {'Data location type', 'Data location root folder', 'Set backup'};
            %obj.ColumnWidths = [130, 365, 125];
            obj.ColumnNames = {'', 'Data location type', 'Data location root directory', 'Permission'};
            obj.ColumnWidths = [22, 130, 370, 80, 125];
            obj.ColumnHeaderHelpFcn = @nansen.setup.getHelpMessage;
            obj.RowSpacing = 20;

        end
        
        function hRow = createTableRowComponents(obj, rowData, rowNum)
        
            hRow = struct(); % Initialize struct to hold row components
            
        % % Create button for removing current row.
            i = 1;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            
            hRow.RemoveImage = uibutton(obj.TablePanel);
            hRow.RemoveImage.Position = [xi y wi h];
            hRow.RemoveImage.Text = '-';
            hRow.RemoveImage.Text = '';
            hRow.RemoveImage.Icon = 'minus.png';
            hRow.RemoveImage.Tooltip = 'Remove Data Location';
            
            hRow.RemoveImage.ButtonPushedFcn = @obj.onRemoveDataLocationButtonPushed;
                       
            if rowNum == 1; hRow.RemoveImage.Visible = 'off'; end
            obj.centerComponent(hRow.RemoveImage, y)
            
            
        % % Create first column: Edit field for data location type 
            i = 2;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            
            hRow.DataLocationName = uieditfield(obj.TablePanel, 'text');
            hRow.DataLocationName.FontName = 'Segoe UI';
            hRow.DataLocationName.Position = [xi y wi-25 h];
            hRow.DataLocationName.BackgroundColor = [0.94,0.94,0.94];
            hRow.DataLocationName.Editable = false;

            obj.centerComponent(hRow.DataLocationName, y)

            hRow.DataLocationName.Value = rowData.Name;
            hRow.DataLocationName.ValueChangedFcn = ...
                @obj.onDataLocationNameChanged;
            
            % Add icon for toggling editing of field
            hRow.EditTypeImage = uiimage(obj.TablePanel);
            hRow.EditTypeImage.Position = [xi+wi-20 y 18 18];
            %hRow.EditTypeImage.Position = [xi y 18 18];
            obj.centerComponent(hRow.EditTypeImage, y)
            hRow.EditTypeImage.ImageSource = 'edit.png';
            hRow.EditTypeImage.Tooltip = 'Edit label for data location type';
            hRow.EditTypeImage.ImageClickedFcn = @obj.onEditDataLocationNameIconClicked;
                        
            if isempty(hRow.DataLocationName.Value)
                hRow.DataLocationName.Editable = true;
                hRow.DataLocationName.BackgroundColor = [1 1 1];
                hRow.EditTypeImage.ImageSource = 'edit3.png';
            end
            
            
        % % Create second column: Edit component for data location rootpath
            i = 3;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            dx = obj.ButtonSizeLarge(1);
            
            hRow.RootPathEditField = obj.createRootPathEditComponent();
            hRow.RootPathEditField.FontName = 'Segoe UI';
            hRow.RootPathEditField.BackgroundColor = [1 1 1];
            hRow.RootPathEditField.Position = [xi y wi-dx-10 h];
            obj.centerComponent(hRow.RootPathEditField, y)
            
            hRow.RootPathEditField.ValueChangedFcn = ...
                @obj.onRootPathEditComponentValueChanged;
            
            % Todo: Make separate method for updating value? Because
            % tooltip should be update too...
            obj.setRootPathEditComponentValue(hRow, rowData)
            
            
            % Create buttons accompanying the rootpath edit component.
            [h, hComponents] = obj.createRootPathButtons();
            
            h.BackgroundColor = [1 1 1];
            h.Position(1:2) = [xi+wi-dx y];
            obj.centerComponent(h, y)
            
            % Add components to the struct of row components.
            uicontrolNames = fieldnames(hComponents);
            for i = 1:numel(uicontrolNames)
                hRow.(uicontrolNames{i}) = hComponents.(uicontrolNames{i});
            end

            % % Create third column: Edit field for data location type 
            i = 4;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            hRow.DLPermissionSelector = uibuttongroup(obj.TablePanel);
            hRow.DLPermissionSelector.BorderType = 'none';
            %hRow.DLPermissionSelector.FontName = 'Segoe UI';
            hRow.DLPermissionSelector.Position = [xi y wi h];
            %hRow.DLPermissionSelector.BackgroundColor = [0.94,0.94,0.94];
            %hRow.DLPermissionSelector.Editable = false;
            obj.centerComponent(hRow.DLPermissionSelector, y)
            %hRow.DLPermissionSelector.Items = {'Read', 'Read/Write'};

            % Create ReadButton
            ReadButton = uitogglebutton(hRow.DLPermissionSelector);
            ReadButton.Text = 'Read';
            ReadButton.Position = [1 1 40 22];
            ReadButton.Value = true;

            % Create WriteButton
            WriteButton = uitogglebutton(hRow.DLPermissionSelector);
            WriteButton.Text = 'Write';
            WriteButton.Position = [40 1 40 22];
            
            
            % Note: This last component might be implemented in the future
            
            % % Create fourth column, buttongroup with buttons for primary and
          % secondary data locations.
            i = 5;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            
            hRow.DL_ButtonGroup_Backup = uibuttongroup(obj.TablePanel);
            hRow.DL_ButtonGroup_Backup.BorderType = 'none';
            hRow.DL_ButtonGroup_Backup.BackgroundColor = [1 1 1];
            hRow.DL_ButtonGroup_Backup.FontName = 'Avenir Next Condensed';
            hRow.DL_ButtonGroup_Backup.Position = [xi y, wi h];
            obj.centerComponent(hRow.DL_ButtonGroup_Backup, y)
            
            % TODO: Enable this
            hRow.DL_ButtonGroup_Backup.Enable = 'off';
            hRow.DL_ButtonGroup_Backup.Visible = 'off';
            
            % Create PrimaryButton
            browseButton = uitogglebutton(hRow.DL_ButtonGroup_Backup);
            browseButton.Text = 'Primary';
            browseButton.Position = [1 1 55 22];
            browseButton.Value = true;

            % Create SecondaryButton
            secondaryButton = uitogglebutton(hRow.DL_ButtonGroup_Backup);
            secondaryButton.Text = 'Secondary';
            secondaryButton.Position = [55 1 70 22];
            
            % Add callback for when button selection is changed
            hRow.DL_ButtonGroup_Backup.SelectionChangedFcn = ...
                @obj.onDataLocationOrderChanged;
            
        end
        
    end
    
    methods (Access = private) % Creation of custom row components
        
        function h = createRootPathEditComponent(obj)
        %createRootPathEditComponent Create control for editing root path
        %
        %   Control can be an edit field or a dropdown. In the input field,
        %   only the first root path is available for edit (simpler, i.e
        %   during first-time initialization) whereas in the dropdown,
        %   multiple root path can be added (advanced configuration).
        
            switch obj.RootPathComponentType
                
                case 'uieditfield'
                    h = uieditfield(obj.TablePanel, 'text');
                    
                case 'uidropdown'
                    h = uidropdown(obj.TablePanel);
                    h.Editable = 'on';
            end
            
        end
        
        function [h, hStruct] = createRootPathButtons(obj)
        %createRootPathButtons Create support button(s) for rootpath field
        %
        %   The buttons accompanying the edit field for the root directory
        %   path depends on the component type for editing the root
        %   directoty path values. If the component is an editfield, a
        %   single browse button is created, whereas if the component is a
        %   uidropdown, a buttongroup containing three buttons is created.
        %
        %   see also createRootPathBrowseButton createRootPathButtonGroup
        
        
            switch obj.RootPathComponentType
                
                case 'uieditfield'
                    hStruct = obj.createRootPathBrowseButton();
                    h = hStruct.UIButton_BrowseRootDir;
                    
                case 'uidropdown'
                    hStruct = obj.createRootPathButtonGroup();
                    h = hStruct.UIButtonGroup_RootDir;
            end
            
        end
        
        function h = createRootPathBrowseButton(obj)
        %createRootPathBrowseButton Create button to open browser dialog
        
            BUTTON_SIZE = obj.ButtonSizeLarge;
            
            h.UIButton_BrowseRootDir = uibutton(obj.TablePanel);
            h.UIButton_BrowseRootDir.FontName = 'Segoe UI';
            h.UIButton_BrowseRootDir.Position(3:4) = BUTTON_SIZE;
            h.UIButton_BrowseRootDir.Text = 'Browse...';
            h.UIButton_BrowseRootDir.ButtonPushedFcn = ...
                @obj.onBrowseRootDirButtonPushed;
            
        end
        
        function h = createRootPathButtonGroup(obj)
        %createRootPathButtonGroup Create button group for rootpath field
        %
        %   Create a button group containing three buttons to support a
        %   root-directory dropdown control. Button descriptions:
        %       Browse Button : Open a browser dialog to set the path
        %       Add Button    : Add a new root directory to the list
        %       Remove Button : Remove a new root directory from the list
        
        
            GROUP_SIZE = obj.ButtonSizeLarge;
            BUTTON_SIZE = obj.ButtonSizeSmall;
                       
            %buttonBgColor = [234,236,237]/255; % Todo: Get from theme...

            h.UIButtonGroup_RootDir = uibuttongroup(obj.TablePanel);
            h.UIButtonGroup_RootDir.BorderType = 'none';
            h.UIButtonGroup_RootDir.Position(3:4) = GROUP_SIZE;
            
            % Get x position for each button
            X = uim.utility.layout.subdividePosition(0, GROUP_SIZE(1), ...
                repmat(BUTTON_SIZE(1), 1,3), 1);
                     
            % Create button to open browse dialog for setting root directory
            h.UIButton_BrowseDir = uibutton(h.UIButtonGroup_RootDir);
            h.UIButton_BrowseDir.Icon = 'ellipsis.png';
            h.UIButton_BrowseDir.Tooltip = 'Browse...';
            h.UIButton_BrowseDir.ButtonPushedFcn = ...
                @obj.onBrowseRootDirButtonPushed;
            
            % Create button to add root directory
            h.UIButton_AddDir = uibutton(h.UIButtonGroup_RootDir);
            h.UIButton_AddDir.Icon = 'plus.png';
            h.UIButton_AddDir.Tooltip = 'Add rootpath';
            h.UIButton_AddDir.ButtonPushedFcn = ...
                @obj.onAddRootDirButtonPushed;
            
            % Create button to remove root directory
            h.UIButton_RemoveDir = uibutton(h.UIButtonGroup_RootDir);
            h.UIButton_RemoveDir.Icon = 'minus.png';
            h.UIButton_RemoveDir.Tooltip = 'Remove rootpath';
            h.UIButton_RemoveDir.ButtonPushedFcn = ...
                @obj.onRemoveRootDirButtonPushed;
            
            % Set common properties for buttons
            buttonNames = {'UIButton_BrowseDir', 'UIButton_AddDir', 'UIButton_RemoveDir'};
            
            for i = 1:numel(buttonNames)
                h.(buttonNames{i}).FontName = 'Segoe UI';
                h.(buttonNames{i}).Text = '';
                %h.(buttonNames{i}).BackgroundColor = buttonBgColor;
                h.(buttonNames{i}).Position = [X(i) 1 BUTTON_SIZE];
            end
            
        end
        
    end
    
    methods % Public methods
        
        function createAddNewDataLocationButton(obj, hPanel)
            
            % Todo: implement as toolbar...
            
            % Assumes obj.Parent has same parent as hPanel given as input
            
            tablePanelPosition = obj.Parent.Position;
            buttonSize = obj.ButtonSizeSmall;
            
            % Determine where to place button:
            SPACING = [3,3];
            
            location = tablePanelPosition(1:2) + tablePanelPosition(3:4) - [1,0] .* buttonSize + [-1, 1] .* SPACING;

            obj.UIButton_AddDataLocation = uibutton(hPanel, 'push');
            obj.UIButton_AddDataLocation.ButtonPushedFcn = @(s, e) obj.onAddDataLocationButtonPushed;
            obj.UIButton_AddDataLocation.Position = [location buttonSize];
            obj.UIButton_AddDataLocation.Text = '';
            obj.UIButton_AddDataLocation.Icon = 'plus.png';
            obj.UIButton_AddDataLocation.Tooltip = 'Add New Data Location';
            
        end
        
        function createDefaultDataLocationSelector(obj, hPanel)
            import uim.utility.layout.subdividePosition
            
            toolbarPosition = obj.getToolbarPosition();
            
            dataLocationLabelWidth = 135;
            dataLocationSelectorWidth = 100;
                        
            Wl_init = [dataLocationLabelWidth, dataLocationSelectorWidth];
            
            % Get component positions for the components on the left
            [Xl, Wl] = subdividePosition(toolbarPosition(1), ...
                toolbarPosition(3), Wl_init, 10);

            Y = toolbarPosition(2);
            
            % Create SelectDataLocationDropDownLabel
            obj.SelectDataLocationDropDownLabel = uilabel(hPanel);
            obj.SelectDataLocationDropDownLabel.Position = [Xl(1) Y Wl(1) 22];
            obj.SelectDataLocationDropDownLabel.Text = 'Set default data location:';

            % Create SelectDataLocationDropDown
            obj.SelectDataLocationDropDown = uidropdown(hPanel);
            obj.SelectDataLocationDropDown.Items = {'Rawdata'};
            obj.SelectDataLocationDropDown.ValueChangedFcn = @obj.onDefaultDataLocationSelectionChanged;
            obj.SelectDataLocationDropDown.Position = [Xl(2) Y Wl(2) 22];

            obj.updateDefaultDataLocationSelector()
        end
        
        function isMissing = isTypeMissing(obj)
            isMissing = ~obj.isRowCompleted('DataLocationName');
        end
        
        function isMissing = isPathMissing(obj)
            isMissing = ~obj.isRowCompleted('RootPathEditField');
        end
        
        function isCompleted = isRowCompleted(obj, rowControlName)
        %isTableCompleted Check if data is entered to all required fields    
            
            isCompleted = true;
            
            for i = 1:numel(obj.RowControls)
                
                if isempty(obj.RowControls(i).(rowControlName).Value)
                    isCompleted = false;
                    return
                end
               
            end
        end
        
        function markClean(obj)
            obj.IsDirty = false;
        end
        
    end
    
    methods (Access = private) % Callbacks for uicomponent interactions
        
        function onDefaultDataLocationSelectionChanged(obj, src, evt)
            obj.DataLocationModel.DefaultDataLocation = src.Value;
            obj.IsDirty = true;
        end
        
        function onEditDataLocationNameIconClicked(obj, src, evt)
        %onEditDataLocationNameIconClicked Callback for click on edit icon
        %
        %   Turn the Editable property of edit field for data location name 
        %   on or off and change the color of the edit icon.
        
            i = obj.getComponentRowNumber(src);
            hRow = obj.RowControls(i);
            
            % Get the edit field, and turn it on/off
            isEditable = hRow.DataLocationName.Editable;
            hRow.DataLocationName.Editable = ~isEditable;

            % Change the icon image.
            if isEditable
                hRow.EditTypeImage.ImageSource = 'edit.png';
                hRow.DataLocationName.BackgroundColor = [0.94,0.94,0.94];
            else
                hRow.EditTypeImage.ImageSource = 'edit3.png';
                hRow.DataLocationName.BackgroundColor = [1,1,1];
            end
            
        end
        
        function onDataLocationNameChanged(obj, src, event)
        %onDataLocationNameChanged Callback for change in editfield    
            
            newName = src.Value;
            
            % Todo: Validate name..
            tf = isvarname(newName);
            if ~tf && ~isempty(newName)
                msg = 'Invalid name, name should be a valid variable name';
                hFig = ancestor(src, 'figure');
                uialert(hFig, msg, 'Invalid name')
                src.Value = event.PreviousValue;
                return
            end
            
            
            % Make sure name does not already exist
            if strcmpi(newName, event.PreviousValue)
                % Accept if current name is modified, i.e small letters
                % changed to big letters
                
            elseif any(strcmpi(obj.DataLocationModel.DataLocationNames, newName))
                msg = 'This name is already used for another data location';
                hFig = ancestor(src, 'figure');
                uialert(hFig, msg, 'Invalid name', 'Icon', 'error')
                src.Value = event.PreviousValue;
                return
            end

            
            i = obj.getComponentRowNumber(src);
            
            dataLocationItem = obj.DataLocationModel.getItem(i);
            oldName = dataLocationItem.Name;
            
            obj.DataLocationModel.modifyDataLocation(oldName, 'Name', newName);
            obj.IsDirty = true;

        end
        
        function onRootPathEditComponentValueChanged(obj, src, evt)
        %onRootPathEditFieldValueChanged Editfield value change
        %
        %   Note: This is a callback for the rootpath editfield component,
        %   so the datalocation rootpath which is edited is the first one.
         
            switch obj.RootPathComponentType

                case 'uieditfield'
                    rootPathIdx = 1;
                    % 
                case 'uidropdown'
                    src.Tooltip = src.Value;
                    if ~evt.Edited; return; end
                    if strcmp(evt.Value, evt.PreviousValue); return; end
                    src.Items = strrep(src.Items, evt.PreviousValue, evt.Value);
                    rootPathIdx = find(strcmp(src.Items, evt.Value));
            end

            % Placeholder...
            %[rootPathType, idx] = obj.getCurrentRootPathType(i);

            newPath = src.Value;
            rowIdx = obj.getComponentRowNumber(src);

            % Get modified value for rootpath list (cell array)
            modifiedRootPath = obj.Data(rowIdx).RootPath;
            modifiedRootPath{rootPathIdx} = newPath;

            % Update the data location model.
            dataLocationItem = obj.DataLocationModel.getItem(rowIdx);
            obj.DataLocationModel.modifyDataLocation(dataLocationItem.Name, ...
                'RootPath', modifiedRootPath);
            
            obj.IsDirty = true;

            % Automatically fill out 2nd datalocation rootdir if it is empty.
            if rowIdx == 1 && isempty( obj.Data(2).RootPath{1} )

                parentDir = fileparts(newPath);
                rootPath = fullfile(parentDir, obj.Data(2).Name);

                obj.DataLocationModel.modifyDataLocation(obj.Data(2).Name, ...
                    'RootPath', rootPath)
                
            end
            
        end
        
        function onBrowseRootDirButtonPushed(obj, src, ~)
        %onBrowseRootDirButtonPushed Callback for press on browse DL button
            % Let user select a folder
            
            if ismac
                initPath = '/Volumes';
            elseif ispc
                initPath = '';
            end
            
            folderPath = uigetdir(initPath);
            
            % Call this to take care of bug in matlab where uifigures loose
            % focus when a uigetdir dialog opens and closes.
            hParentFigure = ancestor(obj.Parent, 'figure');
            figure(hParentFigure)
            
            if folderPath == 0
                return
            end
            
            i = obj.getComponentRowNumber(src);
            hComponent = obj.RowControls(i).RootPathEditField;
            
            % Create a fake event for onRootPathEditComponentValueChanged
            event = struct();
            event.PreviousValue = hComponent.Value;
            event.Value = folderPath;
            
            % Update the value of the edit component:
            if isa(hComponent, 'matlab.ui.control.DropDown')
                idx = strcmp(hComponent.Items, hComponent.Value);
                hComponent.Items{idx} = folderPath;
                hComponent.Value = hComponent.Items{idx};
                event.Edited = true;
            else
                hComponent.Value = folderPath;
            end

            % Invoke callback for taking care of path changes
            obj.onRootPathEditComponentValueChanged( hComponent, event )
            
        end
        
        function onAddRootDirButtonPushed(obj, src, ~)
        %onAddRootDirButtonPushed Callback for button pushed event
        %
        %   Add item to the RootDir dropdown menu
        
            i = obj.getComponentRowNumber(src);
            hDropdown = obj.RowControls(i).RootPathEditField;
            
            newValueStr = 'Add path here...';
            
            if any( strcmp(hDropdown.Items, newValueStr) )
                hFig = ancestor(hDropdown, 'figure');
                message = 'Please specify path before adding new';
                uialert(hFig, message, 'Action aborted', 'Icon', 'info')
            elseif any( strcmp(hDropdown.Items, '') )
                idx = find( strcmp(hDropdown.Items, '') );
                hDropdown.Items{idx(1)} = newValueStr;
                hDropdown.Value = newValueStr;
            else
                hDropdown.Items{end+1} = 'Add path here...';
                hDropdown.Value = hDropdown.Items{end};
            end
                        
            % This is only a ui change, so this should not be updated in
            % the model. 
            
        end
        
        function onRemoveRootDirButtonPushed(obj, src, ~)
        %onRemoveRootDirButtonPushed Callback for button pushed event
        %
        %   Remove current item from the RootDir dropdown menu

            rowIdx = obj.getComponentRowNumber(src);
            hDropdown = obj.RowControls(rowIdx).RootPathEditField;
            
            idx = find( strcmp(hDropdown.Items, hDropdown.Value) );
            
            if numel(hDropdown.Items) == 1
                
                if strcmp(hDropdown.Value, 'Add path here...')
                    hFig = ancestor(hDropdown, 'figure');
                    message = 'At least one root path is required';
                    uialert(hFig, message, 'Action aborted', 'Icon', 'info')
                end
                
                hDropdown.Items{1} = 'Add path here...';
                hDropdown.Value = hDropdown.Items{1};
                return
            else
                hDropdown.Items(idx(end)) = [];
                hDropdown.Value = hDropdown.Items{min([idx(end), numel(hDropdown.Items)])};
                hDropdown.Tooltip = hDropdown.Value;
            end
            
            % Get the modified rootpath...
            modifiedRootPath = hDropdown.Items;
            modifiedRootPath = setdiff(modifiedRootPath, 'Add path here...', 'stable');
            
            if isempty(modifiedRootPath)
                modifiedRootPath = {''};
            end
            
            % Update the data location model.
            dataLocationItem = obj.DataLocationModel.getItem(rowIdx);
            obj.DataLocationModel.modifyDataLocation(dataLocationItem.Name, ...
                'RootPath', modifiedRootPath);
            
            obj.IsDirty = true;

        end

        function onAddDataLocationButtonPushed(obj)
            
            newItem = obj.DataLocationModel.getEmptyItem;
            obj.DataLocationModel.addDataLocation(newItem)
            
            obj.IsDirty = true;
        end
        
        function onRemoveDataLocationButtonPushed(obj, src, ~)
            
            if nargin < 2 % Remove last row if no input is given.
                i = obj.NumRows;
            else
                i = obj.getComponentRowNumber(src);
            end
            
            dataLocationName = obj.RowControls(i).DataLocationName.Value;
            obj.DataLocationModel.removeDataLocation(dataLocationName)
            
            obj.IsDirty = true;
        end
        
        function onDataLocationOrderChanged(obj, src, ~)
        %onDataLocationOrderChanged Callback for togglebutton selection
        %
        %   This feature might be implemented. The idea is to have multiple
        %   types of root directories for a data location, i.e a primary
        %   and a secondary, where the secondary can be a backup directory
        %   type.
        
            i = obj.getComponentRowNumber(src);
            
            switch src.SelectedObject.Text
                case 'Primary'
                    j = 1;
                case 'Secondary'
                    j = 2;
            end
            
            % Todo...
            
            % Update value field of rootpath edit field
            % hRootPath = obj.RowControls(i).RootPathEditField;
            % hRootPath.Value = obj.Data(i).RootPath{j};
            
        end
        
    end
    
        
    methods (Access = private) % Methods to update component values when model has changed.
        
        function updateDefaultDataLocationSelector(obj)
            obj.SelectDataLocationDropDown.Items = {obj.Data.Name};
            obj.SelectDataLocationDropDown.Value = obj.DataLocationModel.DefaultDataLocation;
        end
        
        function updateDataLocationName(obj, rowIdx, newName)
        %updateDataLocationName Update data location name in UI
            
            obj.Data(rowIdx).Name = newName;
            
            currentName = obj.RowControls(rowIdx).DataLocationName.Value;
            
            if ~strcmp(currentName, newName)
                obj.RowControls(rowIdx).DataLocationName.Value = newName;
            end
            
        end
        
        function updateDataLocationRoot(obj, rowIdx, newRootPath)
        %updateDataLocationRoot Update data location root in UI
        %
        %   updateDataLocationRoot(obj, rowIdx, newRootPath) update the
        %   value for the DataLocation RootPath for the row given by rowIdx
        %   according to the new value.
        %
        %   This method makes sure the Data and the uicomponent associated
        %   with the DataLocation's root path is updated
        
            %j = 1; % Might change in the future
            
            hRow = obj.RowControls(rowIdx);

            % Update the data property.
            obj.Data(rowIdx).RootPath = newRootPath;
            rowData = obj.Data(rowIdx);
            
            % Set value of the uicomponent.
            obj.setRootPathEditComponentValue(hRow, rowData)

        end
        
        function setRootPathEditComponentValue(obj, hRow, rowData)
        %setRootPathEditComponentValue Set value of RootPath in uicomponent
        %
        %   Set value of uicomponent, taking into account what type of
        %   uicomponent is currently active.
        
            hEditComponent = hRow.RootPathEditField;
            currentRootPath = hEditComponent.Value;
            
            switch obj.RootPathComponentType
                
                case 'uieditfield'
                    rootPathIdx = 1;
                case 'uidropdown'
                    hEditComponent.Items = rowData.RootPath;
                    rootPathIdx = find(strcmp(hEditComponent.Items, hEditComponent.Value));
            end
            
            if ~strcmp(currentRootPath, rowData.RootPath{rootPathIdx(1)})
                hEditComponent.Value = rowData.RootPath{rootPathIdx(1)};
                hEditComponent.Tooltip = rowData.RootPath{rootPathIdx(1)};
            end

        end
        
    end
    
    methods (Access = private) % Methods for getting values from uicomponents
        
        function [rootPathType, idx] = getCurrentRootPathType(obj, rowIdx)
            
            hRow = obj.RowControls(rowIdx);
            
            rootPathType = hRow.DL_ButtonGroup_Backup.SelectedObject.Text;
            
            % Determine if primary or secondary data location is selected
            switch rootPathType
                case 'Primary'
                    idx = 1;
                case 'Secondary'
                    idx = 2;
            end
            
        end
        
    end
    
    methods (Access = protected) % Implement callbacks from HasDataLocationModel
                
        function onDataLocationAdded(obj, ~, evt)
        %onDataLocationAdded Add new data location to UI
        %
        %   This method is handed down from the HasDataLocationModel 
        %   superclass and is triggered by the DataLocationAdded event on 
        %   the DataLocationModel object. 
        %
        %   Create a new row to match a new DataLocation item

            % Todo: Get idx from evt?
            
            numRows = obj.NumRows;
            obj.addRow(numRows+1, evt.NewValue)
            obj.updateDefaultDataLocationSelector()

        end
        
        function onDataLocationRemoved(obj, ~, evt)
        %onDataLocationRemoved Remove data location from UI
        %
        %   This method is handed down from HasDataLocationModel superclass
        %   and is triggered by the DataLocationRemoved event on the
        %   DataLocationModel class
        %
        %   Remove a row for a removed DataLocation item

            %rowNumber = evt.DataIndex;
            
            rowIdx = find(strcmp({obj.Data.Name}, evt.DataLocationName));
            
            if ~isempty(rowIdx)
                obj.removeRow(rowIdx)
            end
            
            obj.updateDefaultDataLocationSelector()
            
        end
        
        function onDataLocationModified(obj, src, evt, varargin)
        %onDataLocationModified Modify data location in UI
        %
        %   This method is inherited from the HasDataLocationModel 
        %   superclass and is triggered by the DataLocationModified event 
        %   on the DataLocationModel 
        
            [~, rowIdx] = obj.DataLocationModel.ismember(evt.DataLocationName);
        
            switch evt.DataField
                
                case 'Name'
                    obj.updateDataLocationName(rowIdx, evt.NewValue)
                    obj.updateDefaultDataLocationSelector()

                case 'RootPath'
                    obj.updateDataLocationRoot(rowIdx, evt.NewValue)
                    
                otherwise
                
                
            end
        
        end
        
    end
end