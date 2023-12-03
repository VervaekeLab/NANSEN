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

    properties (Access = private) % Toolbar button...
        UIButton_AddDataLocation
        SelectDataLocationDropDownLabel
        SelectDataLocationDropDown
        SelectDataLocationHelpButton
    end
    
    properties (Access = private) % Layout properties
        LastUigetdirFolder = ''     % Loast opened folder using uigetdir
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
        
        function delete(obj)
            delete@applify.apptable(obj)
        end
    end
    
    methods (Access = protected) % Implementation of superclass methods
        
        function assignDefaultTablePropertyValues(obj)
        %assignDefaultTablePropertyValues UIControlTable method
        %
        %   Specify layout of table columns and rows.
        
            %obj.ColumnNames = {'Data location type', 'Data location root folder', 'Set backup'};
            %obj.ColumnWidths = [130, 365, 125];
            obj.ColumnNames = {'', 'Data location name', 'Data type', 'Data location root directory'};
            obj.ColumnWidths = [22, 130, 100, 350];
            obj.ColumnHeaderHelpFcn = @nansen.app.setup.getHelpMessage;
            obj.RowSpacing = 20;

        end
        
        function hRow = createTableRowComponents(obj, rowData, rowNum)
        %createTableRowComponents UIControlTable method
            
            hRow = struct(); % Initialize struct to hold row components
            
        % % Create button for removing current row.
            i = 1;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            
            hRow.RemoveImage = uibutton(obj.TablePanel);
            hRow.RemoveImage.Position = [xi y wi h];
            hRow.RemoveImage.Text = '-';
            hRow.RemoveImage.Text = '';
            hRow.RemoveImage.Icon = nansen.internal.getIconPathName('minus.png');
            hRow.RemoveImage.Tooltip = 'Remove Data Location';
            
            hRow.RemoveImage.ButtonPushedFcn = @obj.onRemoveDataLocationButtonPushed;
                       
            if rowNum == 1; hRow.RemoveImage.Visible = 'off'; end
            obj.centerComponent(hRow.RemoveImage, y)
            
            obj.TableComponentCellArray{rowNum, i} = hRow.RemoveImage;
            
        % % Create first column: Edit field for data location name 
            i = i+1;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            
            hRow.DataLocationName = uieditfield(obj.TablePanel, 'text');
            hRow.DataLocationName.FontName = 'Segoe UI';
            hRow.DataLocationName.Position = [xi y wi h];
            hRow.DataLocationName.BackgroundColor = [1, 1, 1];
            hRow.DataLocationName.Editable = true;

            obj.centerComponent(hRow.DataLocationName, y)
            obj.TableComponentCellArray{rowNum, i} = hRow.DataLocationName;

            hRow.DataLocationName.Value = rowData.Name;
            hRow.DataLocationName.ValueChangedFcn = ...
                @obj.onDataLocationNameChanged;
            
        % % Create second column: Edit field for data location type 
            i = i+1;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            
            hRow.DataLocationType = uidropdown(obj.TablePanel);
            hRow.DataLocationType.FontName = 'Segoe UI';
            hRow.DataLocationType.Position = [xi y wi h];
            hRow.DataLocationType.BackgroundColor = [1, 1, 1];
            hRow.DataLocationType.Editable = false;
            
            [~, hRow.DataLocationType.Items] = enumeration('nansen.config.dloc.DataLocationType');
            hRow.DataLocationType.Value = char(rowData.Type);  
            
            obj.centerComponent(hRow.DataLocationType, y)
            obj.TableComponentCellArray{rowNum, i} = hRow.DataLocationType;

            hRow.DataLocationType.ValueChangedFcn = ...
                @obj.onDataLocationTypeChanged;
            
            
        % % Create third column: Edit component for data location rootpath
            i = i+1;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            dx = obj.ButtonSizeLarge(1);
            
            hRow.RootPathEditField = obj.createRootPathEditComponent();
            hRow.RootPathEditField.FontName = 'Segoe UI';
            hRow.RootPathEditField.BackgroundColor = [1 1 1];
            hRow.RootPathEditField.Position = [xi y wi-dx-10 h];
            
            obj.centerComponent(hRow.RootPathEditField, y)
            obj.TableComponentCellArray{rowNum, i} = hRow.RootPathEditField;
           
            hRow.RootPathEditField.ValueChangedFcn = ...
                @obj.onRootPathEditComponentValueChanged;
            
            % Set value of the component for datalocation root path:
            obj.setRootPathEditComponentValue(hRow, rowData)
            
            
            % Create buttons accompanying the rootpath edit component.
            [h, hComponents] = obj.createRootPathButtons();
            
            %h.BackgroundColor = [1 1 1];
            h.Position(1:2) = [xi+wi-dx y];

            obj.centerComponent(h, y)
            obj.TableComponentCellArray{rowNum, i} = h;

            
            % Add components to the struct of row components.
            uicontrolNames = fieldnames(hComponents);
            for i = 1:numel(uicontrolNames)
                hRow.(uicontrolNames{i}) = hComponents.(uicontrolNames{i});
            end

        end
        
        function createToolbarComponents(obj, hPanel)
        %createToolbarComponents Create "toolbar" components above table.    
            if nargin < 2; hPanel = obj.Parent.Parent; end
                        
            obj.createAddNewDataLocationButton(hPanel)
            
            obj.createDefaultDataLocationSelector(hPanel)
        end
        
        function toolbarComponents = getToolbarComponents(obj)
            toolbarComponents = [...
                obj.UIButton_AddDataLocation, ...
                obj.SelectDataLocationDropDownLabel, ...
                obj.SelectDataLocationDropDown, ...
                obj.SelectDataLocationHelpButton];
        end
    end
    
    methods (Access = private) % Creation of custom components
        
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
            %h.UIButton_BrowseRootDir.Icon = nansen.internal.getIconPathName('folder.png');
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
            h.UIButton_BrowseDir.Icon = nansen.internal.getIconPathName('ellipsis.png');
            h.UIButton_BrowseDir.Tooltip = 'Browse...';
            h.UIButton_BrowseDir.ButtonPushedFcn = ...
                @obj.onBrowseRootDirButtonPushed;
            
            % Create button to add root directory
            h.UIButton_AddDir = uibutton(h.UIButtonGroup_RootDir);
            h.UIButton_AddDir.Icon = nansen.internal.getIconPathName('plus.png');
            h.UIButton_AddDir.Tooltip = 'Add rootpath';
            h.UIButton_AddDir.ButtonPushedFcn = ...
                @obj.onAddRootDirButtonPushed;
            
            % Create button to remove root directory
            h.UIButton_RemoveDir = uibutton(h.UIButtonGroup_RootDir);
            h.UIButton_RemoveDir.Icon = nansen.internal.getIconPathName('minus.png');
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
        
        function createAddNewDataLocationButton(obj, hPanel)
        %createAddNewDataLocationButton Button for adding new data locations
        
            buttonSize = obj.ButtonSizeSmall;

            toolbarPosition = obj.getToolbarPosition();
            location(1) = sum(toolbarPosition([1,3])) - buttonSize(1);
            location(2) = toolbarPosition(2);

            obj.UIButton_AddDataLocation = uibutton(hPanel, 'push');
            obj.UIButton_AddDataLocation.ButtonPushedFcn = @(s, e) obj.onAddDataLocationButtonPushed;
            obj.UIButton_AddDataLocation.Position = [location buttonSize];
            obj.UIButton_AddDataLocation.Text = '';
            obj.UIButton_AddDataLocation.Icon = nansen.internal.getIconPathName('plus.png');
            obj.UIButton_AddDataLocation.Tooltip = 'Add New Data Location';
            
        end
        
        function createDefaultDataLocationSelector(obj, hPanel)
            import uim.utility.layout.subdividePosition
            
            toolbarPosition = obj.getToolbarPosition();
            
            dataLocationLabelWidth = 135;
            dataLocationSelectorWidth = 100;
                        
            Wl_init = [dataLocationLabelWidth, dataLocationSelectorWidth, 20];
            
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
            
            obj.SelectDataLocationHelpButton = obj.createHelpIconButton(hPanel);
            obj.SelectDataLocationHelpButton.Position = [Xl(3) Y+1 Wl(3) 20];
            obj.SelectDataLocationHelpButton.Tag = 'Default Data Location';
        end
        
    end
    
    methods % Public methods
        
        function [tf, msg] = isTableCompleted(obj)
            
            tf = false; % null hypothesis
            msg = '';
            
            if obj.isPathMissing()
                [~, rowNum] = obj.isPathMissing();
                dlNames = obj.DataLocationModel.DataLocationNames(rowNum);
                if numel(rowNum) == 1
                    msg = sprintf('Please enter a root path for the following datalocation: %s', strjoin(dlNames, ', '));
                else
                    msg = sprintf('Please enter a root path for the following datalocations: %s', strjoin(dlNames, ', '));
                end
            else
                tf = true;
            end

        end
        
        function isMissing = isTypeMissing(obj)
            isMissing = ~obj.isRowCompleted('DataLocationName');
        end
        
        function [isMissing, rowNum] = isPathMissing(obj)
        %isPathMissing Check if rootpath is missing from any of the rows.
            
            isMissingRow = ~obj.isRowCompleted('RootPathEditField');
            isMissing = any(isMissingRow);
            
            if nargout == 2
                rowNum = find(isMissingRow);
            end

        end
        
        function isCompleted = isRowCompleted(obj, rowControlName)
        %isTableCompleted Check if data is entered to all required fields    
                        
            isCompleted = true(1, obj.NumRows); % null hypothesis
            
            for i = 1:numel(obj.RowControls)
                if isempty(obj.RowControls(i).(rowControlName).Value)
                    isCompleted(i) = false;
                end
            end
            
        end

        function markClean(obj)
            obj.IsDirty = false;
        end
        
        
        function setActive(obj)
        %setActive Execute actions needed for ui activation
        % Use if UI is part of an app with tabs, and the tab is selected        
        end
        
        function setInactive(obj)
        %setInactive Execute actions needed for ui inactivation
        % Use if UI is part of an app with tabs, and the tab is unselected
        
            for i = 1:obj.DataLocationModel.NumDataLocations
                
                try
                    obj.DataLocationModel.validateRootPath(i)
                catch ME
                    message = ME.message;
                    message = [message, '. ', 'Create folder now?']; %#ok<AGROW>
                    hFig = ancestor(obj.Parent, 'figure');
                    selection = uiconfirm(hFig, message, 'Create Folder?', 'Options', {'Ok', 'Skip'});
                    
                    switch selection
                        case {'OK', 'Ok'}
                            try
                                obj.DataLocationModel.createRootPath(i)
                            catch ME
                                uialert(obj.Figure, ME.message, ME.identifier)
                                return
                            end
                        otherwise
                            return
                    end
                end
            end
            
        end
        
    end

    methods (Access = private) % Callbacks for uicomponent interactions
        
        function onDefaultDataLocationSelectionChanged(obj, src, evt)
            try
                obj.DataLocationModel.DefaultDataLocation = src.Value;
                obj.IsDirty = true;
                
                if contains('None', src.Items)
                    src.Items = setdiff(src.Items, 'None', 'stable');
                end
                
            catch ME
                hFig = ancestor(src, 'figure');
                uialert(hFig, ME.message, 'Aborted')
                src.Value = evt.PreviousValue;
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
        
        function onDataLocationTypeChanged(obj, src, evt)
            
            newValue = evt.Value;
            rowIdx = obj.getComponentRowNumber(src);

            % Update the data location model.
            dataLocationItem = obj.DataLocationModel.getItem(rowIdx);
            
                        
            % Make sure we are not removing the default data location.
            if strcmp(dataLocationItem.Name, obj.DataLocationModel.DefaultDataLocation)
                hFig = ancestor(src, 'figure');
                message = 'Can not change data type for this data location because it is the default data location.';
                uialert(hFig, message, 'Aborted')
                
                src.Value = evt.PreviousValue;
                return
            end

            % Update datalocation model
            obj.DataLocationModel.modifyDataLocation(dataLocationItem.Name, ...
                'Type', newValue);
            
            obj.IsDirty = true;
        end
        
        function onRootPathEditComponentValueChanged(obj, src, evt)
        %onRootPathEditFieldValueChanged Editfield value change
        %
        %   Note: This is a callback for the rootpath editfield component,
        %   so the datalocation rootpath which is edited is the first one.
         
            rowIdx = obj.getComponentRowNumber(src);
        
            switch obj.RootPathComponentType

                case 'uieditfield'
                    rootPathIdx = 1;
                    if isempty(obj.Data(rowIdx).RootPath)
                        thisKey = nansen.util.getuuid();
                    else
                        thisKey = obj.Data(rowIdx).RootPath(rootPathIdx).Key;
                    end
                    
                case 'uidropdown'
                    src.Tooltip = src.Value;
                    if ~evt.Edited; return; end
                    if strcmp(evt.Value, evt.PreviousValue); return; end
                    
                    % Todo: Abort if rootpath that were in list was
                    % selected...
                    
                    % If aborting:
                    %src.Items = strrep(src.Items, evt.Value, evt.PreviousValue);
                    
                    rootPathIdx = find(strcmp(src.Items, evt.Value));
                    
                    % Note: This is necessary when the dropdown value is manually
                    % edited.
                    if isempty(rootPathIdx)
                        rootPathIdx = find(strcmp(src.Items, evt.PreviousValue));
                    elseif numel(rootPathIdx) > 1
                        warning('Multiple paths matched the new value, selected first one')
                        rootPathIdx = rootPathIdx(1);
                    end
                    
                    if isempty(src.UserData.Keys) % Need to initialize a key
                        thisKey = nansen.util.getuuid();
                        src.UserData.Keys = {thisKey};
                    else
                        thisKey = src.UserData.Keys{rootPathIdx};
                    end
            end

            newPath = src.Value;

            % Placeholder...
            %[rootPathType, idx] = obj.getCurrentRootPathType(i);

            % Get modified value for rootpath list (cell array)
            modifiedRootPath = obj.Data(rowIdx).RootPath;
            
            % Update key, value pair in modified root...
            modifiedRootPath(rootPathIdx).Key = thisKey;
            modifiedRootPath(rootPathIdx).Value = newPath;

            % Add name of disk to the rootpath struct.
            diskName = obj.DataLocationModel.resolveDiskName(newPath);
            modifiedRootPath(rootPathIdx).DiskName = diskName;

            % Update the data location model.
            dataLocationItem = obj.DataLocationModel.getItem(rowIdx);
            obj.DataLocationModel.modifyDataLocation(dataLocationItem.Name, ...
                'RootPath', modifiedRootPath);
            
            obj.IsDirty = true;

            % Automatically fill out 2nd datalocation rootdir if it is empty.
            if rowIdx == 1 && numel(obj.Data) > 1 && isempty( obj.Data(2).RootPath )

                parentDir = fileparts(newPath);
                
                rootPath.Key = nansen.util.getuuid();
                rootPath.Value = fullfile(parentDir, obj.Data(2).Name);

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
            
            if ~isempty(obj.LastUigetdirFolder)
                initPath = obj.LastUigetdirFolder;
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
            
            obj.LastUigetdirFolder = fileparts(folderPath);
            
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
                hDropdown.UserData.Keys{end+1} = nansen.util.getuuid();
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
                hDropdown.UserData.Keys(idx(end)) = [];
                hDropdown.Value = hDropdown.Items{min([idx(end), numel(hDropdown.Items)])};
                hDropdown.Tooltip = hDropdown.Value;
            end
            
            % Get the modified rootpath...
            dropdownItems = hDropdown.Items;
            dropdownKeys = hDropdown.UserData.Keys;
            
            idx = find(strcmp(dropdownItems, 'Add path here...'));
            if ~isempty(idx)
                dropdownItems(idx) = [];
                dropdownKeys(idx) = [];
            end
           
            n = numel(dropdownItems);
            [modifiedRootPath(1:n).Key] = deal( dropdownKeys{:} );
            [modifiedRootPath(1:n).Value] = deal( dropdownItems{:} );
            
            if isempty(modifiedRootPath)
                modifiedRootPath = struct('Key', {}, 'Value', {});
            end
            
            % Update the data location model.
            dataLocationItem = obj.DataLocationModel.getItem(rowIdx);
            obj.DataLocationModel.modifyDataLocation(dataLocationItem.Name, ...
                'RootPath', modifiedRootPath);
            
            obj.IsDirty = true;

        end

        function onAddDataLocationButtonPushed(obj)
            
            newItem = obj.DataLocationModel.getBlankItem;
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
            
            % Make sure we are not removing the default data location.
            if strcmp(dataLocationName, obj.DataLocationModel.DefaultDataLocation)
                hFig = ancestor(src, 'figure');
                message = 'Can not remove the default data location';
                uialert(hFig, message, 'Aborted')
                return
            end
            
            obj.DataLocationModel.removeDataLocation(dataLocationName)
            
            obj.IsDirty = true;
        end
        
    end
        
    methods (Access = private) % Methods to update component values when model has changed.
        
        function updateDefaultDataLocationSelector(obj)
            obj.SelectDataLocationDropDown.Items = {obj.Data.Name};
            
            defaultName = obj.DataLocationModel.DefaultDataLocation;
            
            if isempty(defaultName)
                obj.SelectDataLocationDropDown.Items = ['None', ...  
                    obj.SelectDataLocationDropDown.Items ];
                obj.SelectDataLocationDropDown.Value = 'None';
                return;
            end
            
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
            
            rootPathItems = {rowData.RootPath.Value};
            if isempty(rootPathItems)
                rootPathItems = {''};
            end
            
            switch obj.RootPathComponentType
                
                case 'uieditfield'
                    rootPathIdx = 1;
                case 'uidropdown'
                    hEditComponent.Items = rootPathItems;
                    hEditComponent.UserData.Keys = {rowData.RootPath.Key};
                    rootPathIdx = find(strcmp(hEditComponent.Items, hEditComponent.Value));
            end
            
            if ~strcmp(currentRootPath, rootPathItems{rootPathIdx(1)})
                hEditComponent.Value = rootPathItems{rootPathIdx(1)};
                hEditComponent.Tooltip = rootPathItems{rootPathIdx(1)};
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
        
            [~, rowIdx] = obj.DataLocationModel.containsItem(evt.DataLocationName);
        
            switch evt.DataField
                
                case 'Name'
                    obj.updateDataLocationName(rowIdx, evt.NewValue)
                    obj.updateDefaultDataLocationSelector()

                case 'Type'
                    
                    
                case 'RootPath'
                    obj.updateDataLocationRoot(rowIdx, evt.NewValue)
                    
                otherwise
                
                
            end
        
        end
        
    end
    
    methods (Access = protected) % Override superclass methods (UIControlTable)
        
        function showToolbar(obj)
            
            if isempty(obj.UIButton_AddDataLocation)
                obj.createToolbarComponents()
            end
            
            obj.UIButton_AddDataLocation.Visible = 'on';
            obj.SelectDataLocationDropDownLabel.Visible = 'on';
            obj.SelectDataLocationDropDown.Visible = 'on';
        end
        
        function hideToolbar(obj)
            obj.UIButton_AddDataLocation.Visible = 'off';
            obj.SelectDataLocationDropDownLabel.Visible = 'off';
            obj.SelectDataLocationDropDown.Visible = 'off';
        end
        
    end
    
end