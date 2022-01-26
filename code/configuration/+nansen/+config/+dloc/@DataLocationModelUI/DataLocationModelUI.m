classdef DataLocationModelUI < applify.apptable & nansen.config.mixin.HasDataLocationModel
% Class interface for editing data locations in a uifigure  
    
% Todo: Simplify component creation. 
%     [] Get cell locations as array with one entry for each column of a row.
%     [] Do the centering when getting the cell locations.
%     [] Set fontsize/bg color and other properties in batch.

%     [] get a default struct 
    
    
    properties
        isDirty = false % keep this....?
    end
    
    properties % Toolbar button...
        AddDataLocationButton
    end
    
    
    methods
        function obj = DataLocationModelUI(dataLocationModel, varargin)
        %DataLocationModelUI Construct a DataLocationModelUI instance
            obj@nansen.config.mixin.HasDataLocationModel(dataLocationModel)
            
            varargin = [varargin, {'Data', dataLocationModel.Data}];
            obj@applify.apptable(varargin{:})
        end
    end
    
    methods (Access = protected)
        
        function assignDefaultTablePropertyValues(obj)
            
            %obj.ColumnNames = {'Data location type', 'Data location root folder', 'Set backup'};
            %obj.ColumnWidths = [130, 365, 125];
            obj.ColumnNames = {'', 'Data location type', 'Data location root directory'};
            obj.ColumnWidths = [22, 130, 460, 125];
            obj.ColumnHeaderHelpFcn = @nansen.setup.getHelpMessage;
            obj.RowSpacing = 20;

        end
        
        function hRow = createTableRowComponents(obj, rowData, rowNum)
        
            hRow = struct();
            
            
        % % Create Button for removing current row.
            i = 1;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            
            hRow.RemoveImage = uibutton(obj.TablePanel);
            hRow.RemoveImage.Position = [xi y wi h];
            hRow.RemoveImage.Text = '-';
            
            hRow.RemoveImage.ButtonPushedFcn = @obj.onRemoveDataLocationButtonPushed;
                       
            if rowNum == 1; hRow.RemoveImage.Visible = 'off'; end
            obj.centerComponent(hRow.RemoveImage, y)
            
            
        % % Create first column with edit field for data location type 
            i = 2;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            
            hRow.DataLocationName = uieditfield(obj.TablePanel, 'text');
            hRow.DataLocationName.FontName = 'Segoe UI';
            hRow.DataLocationName.Position = [xi y wi-25 h];
            hRow.DataLocationName.BackgroundColor = [0.94,0.94,0.94];
            hRow.DataLocationName.Editable = false;
           
%             hRow.DataLocationName.Visible = false;
%             hRow.DataLocationName_ = uilabel(obj.TablePanel);
%             hRow.DataLocationName_.Position = [xi y wi-25 h];
%             hRow.DataLocationName_.Text = rowData.Name;
            
            obj.centerComponent(hRow.DataLocationName, y)
%             obj.centerComponent(hRow.DataLocationName_, y)

            hRow.DataLocationName.Value = rowData.Name;
            hRow.DataLocationName.ValueChangedFcn = ...
                @obj.onDataLocationTypeChanged;
            
            % Add icon for toggling editing of field
            hRow.EditTypeImage = uiimage(obj.TablePanel);
            hRow.EditTypeImage.Position = [xi+wi-20 y 18 18];
            %hRow.EditTypeImage.Position = [xi y 18 18];
            obj.centerComponent(hRow.EditTypeImage, y)
            hRow.EditTypeImage.ImageSource = 'edit.png';
            hRow.EditTypeImage.Tooltip = 'Edit label for data location type';
            hRow.EditTypeImage.ImageClickedFcn = @obj.onEditIconClicked;
                        
            if isempty(hRow.DataLocationName.Value)
                hRow.DataLocationName.Editable = true;
%                 hRow.DataLocationName_.Visible = 'off';
%                 hRow.DataLocationName.Visible = 'on';
                hRow.DataLocationName.BackgroundColor = [1 1 1];
                hRow.EditTypeImage.ImageSource = 'edit3.png';
            end
            
            
        % % Create second column, edit field for data location root and
          % browse button.
            i = 3;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            
            hRow.RootPathEditField = uieditfield(obj.TablePanel, 'text');
            hRow.RootPathEditField.FontName = 'Segoe UI';
            hRow.RootPathEditField.BackgroundColor = [1 1 1];
            hRow.RootPathEditField.Position = [xi y wi-80 h];
            obj.centerComponent(hRow.RootPathEditField, y)
            
            % Todo: Make separate method for updating value? Because
            % tooltip should be update too...
            hRow.RootPathEditField.Value = rowData.RootPath{1};
            hRow.RootPathEditField.Tooltip = rowData.RootPath{1};
            
            % Add value changed callback function
            hRow.RootPathEditField.ValueChangedFcn = ...
                @obj.onDataLocationRootPathChanged;
            
            % Add button in same column
            hRow.RootPathBrowseButton = uibutton(obj.TablePanel);
            hRow.RootPathBrowseButton.FontName = 'Segoe UI';
            hRow.RootPathBrowseButton.BackgroundColor = [1 1 1];
            hRow.RootPathBrowseButton.Position = [xi+wi-70 y 70 22];
            hRow.RootPathBrowseButton.Text = 'Browse...';
            obj.centerComponent(hRow.RootPathBrowseButton, y)
            
            hRow.RootPathBrowseButton.ButtonPushedFcn = ...
                @obj.onBrowseDataLocationRootDir;


        % % Create third column, buttongroup with buttons for primary and
          % secondary data locations.
            i = 4;
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
            primaryButton = uitogglebutton(hRow.DL_ButtonGroup_Backup);
            primaryButton.Text = 'Primary';
            primaryButton.Position = [1 1 55 22];
            primaryButton.Value = true;

            % Create SecondaryButton
            secondaryButton = uitogglebutton(hRow.DL_ButtonGroup_Backup);
            secondaryButton.Text = 'Secondary';
            secondaryButton.Position = [55 1 70 22];
            
            % Add callback for when button selection is changed
            hRow.DL_ButtonGroup_Backup.SelectionChangedFcn = ...
                @obj.onDataLocationOrderChanged;
            
        end
        
    end
    
    methods % Public methods
        
        function createAddNewDataLocationButton(obj, hPanel)
            
            % Todo: implement as toolbar...
            
            % Assumes obj.Parent has same parent as hPanel given as input
            
            tablePanelPosition = obj.Parent.Position;
            buttonSize = [22, 22];
            
            % Determine where to place button:
            SPACING = [3,3];
            
            location = tablePanelPosition(1:2) + tablePanelPosition(3:4) - [1,0] .* buttonSize + [-1, 1] .* SPACING;
            
            obj.AddDataLocationButton = uibutton(hPanel, 'push');
            obj.AddDataLocationButton.ButtonPushedFcn = @(s, e) obj.onAddDataLocationButtonPushed;
            obj.AddDataLocationButton.Position = [location buttonSize];
            obj.AddDataLocationButton.Text = '+';

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
        
    end
    
    methods % Subclass specific callbacks
             
        function markClean(obj)
            obj.isDirty = false;
        end
        
        function onEditIconClicked(obj, src, evt)
        %onEditIconClicked Callback for button click on edit icon
        %
        %   Turn the Editable property of edit field on or off and change
        %   the color fo the edit icon.
        
            i = obj.getComponentRowNumber(src);
            hRow = obj.RowControls(i);
            
            % Get the edit field, and turn it on/off
            isEditable = hRow.DataLocationName.Editable;
            hRow.DataLocationName.Editable = ~isEditable;

            % Change the icon image.
            if isEditable
                hRow.EditTypeImage.ImageSource = 'edit.png';
                hRow.DataLocationName.BackgroundColor = [0.94,0.94,0.94];
%                 hRow.DataLocationName_.Visible = 'on';
%                 hRow.DataLocationName.Visible = 'off';
            else
                hRow.EditTypeImage.ImageSource = 'edit3.png';
                hRow.DataLocationName.BackgroundColor = [1,1,1];
%                 hRow.DataLocationName_.Visible = 'off';
%                 hRow.DataLocationName.Visible = 'on';
            end
            
        end
        
        function onDataLocationTypeChanged(obj, src, event)
        %onDataLocationTypeChanged Callback for change in editfield    
            newName = src.Value;
            
            % Todo: Validate name..
            tf = isvarname(newName);
            if ~tf && ~isempty(newName)
                msg = 'Invalid name, name should be a valid variable name';
                hFig = ancestor(src, 'figure');
                uialert(hFig, msg, 'Invalid name')
                newName = event.PreviousValue;
            end
            
            i = obj.getComponentRowNumber(src);
            
            dataLocationItem = obj.DataLocationModel.getItem(i);
            oldName = dataLocationItem.Name;
            
            obj.DataLocationModel.modifyDataLocation(oldName, 'Name', newName);
            
% %             obj.Data(i).Name = newName;
% %             obj.RowControls(i).DataLocationName.Value = newName;

        end
        
        function onDataLocationRootPathChanged(obj, src, ~)
            
            newPath = src.Value;
            
            i = obj.getComponentRowNumber(src);
            hRow = obj.RowControls(i);
            
            % Determine if primary or secondary data location is selected
            switch hRow.DL_ButtonGroup_Backup.SelectedObject.Text
                case 'Primary'
                    j = 1;
                    obj.isPathDirty = true;
                case 'Secondary'
                    j = 2;
            end
            
            % Assign the selected folder path to data location and root dir
            % input field.
            obj.Data(i).RootPath{j} = newPath;
            hRow.RootPathEditField.Value = newPath;
            hRow.RootPathEditField.Tooltip = newPath;
            
            if i == 1 && j == 1 && isempty(obj.Data(2).RootPath{1})
                parentDir = fileparts(newPath);
                obj.Data(2).RootPath{j} = fullfile(parentDir, obj.Data(2).Name);
                obj.RowControls(2).RootPathEditField.Value = obj.Data(2).RootPath{j};
                obj.RowControls(2).RootPathEditField.Tooltip = obj.Data(2).RootPath{j};
            end
        end
        
        function onBrowseDataLocationRootDir(obj, src, ~)
        %onBrowseDataLocationRootDir Callback for press on browse DL button
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
            hRow = obj.RowControls(i);
            hRow.RootPathEditField.Value = folderPath;
            
            % Invoke callback for taking care of path changes
            obj.onDataLocationRootPathChanged( hRow.RootPathEditField )
            
        end
        
        function onDataLocationOrderChanged(obj, src, ~)
        %onDataLocationOrderChanged Callback for togglebutton selection
        
            i = obj.getComponentRowNumber(src);
            
            switch src.SelectedObject.Text
                case 'Primary'
                    j = 1;
                case 'Secondary'
                    j = 2;
            end
            
            % Update value field of rootpath edit field
            hRootPath = obj.RowControls(i).RootPathEditField;
            hRootPath.Value = obj.Data(i).RootPath{j};
            
        end
        
        function onRemoveDataLocationButtonPushed(obj, src, ~)
            
            if nargin < 2 % Remove last row if no input is given.
                i = obj.NumRows;
            else
                i = obj.getComponentRowNumber(src);
            end
            
            dataLocationName = obj.RowControls(i).DataLocationName.Value;
            obj.DataLocationModel.removeDataLocation(dataLocationName)
            
        end
        
        function addRow(obj, rowNum, rowData)
            addRow@applify.apptable(obj, rowNum, rowData)
            obj.isDirty = true;
        end
        
        function onAddDataLocationButtonPushed(obj)
            
            newItem = obj.DataLocationModel.getEmptyItem;
            obj.DataLocationModel.addDataLocation(newItem)
            
        end
        
    end
    
    methods (Access = private)
        
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
        
            j = 1; % Might change in the future
            
            obj.Data(rowIdx).RootPath{j} = newRootPath;
            
            hRow = obj.RowControls(rowIdx);
            currentRootPath = hRow.RootPathEditField.Value;
            
            if ~strcmp(currentRootPath, newRootPath)
                hRow.RootPathEditField.Value = newRootPath;
                hRow.RootPathEditField.Tooltip = newRootPath;
            end
            
        end
        
    end
    
    methods (Access = protected) % Implement callbacks from HasDataLocationModel
                
        function onDataLocationAdded(obj, ~, evt)
        %onDataLocationAdded Add new data location to UI
        %
        %   This method is handed down from the HasDataLocationModel 
        %   superclass and is triggered by the DataLocationAdded event on 
        %   the DataLocationModel object

            % Todo: Get idx from evt?
            
            numRows = obj.NumRows;
            obj.addRow(numRows+1, evt.NewValue)
            
        end
        
        function onDataLocationRemoved(obj, ~, evt)
        %onDataLocationRemoved Remove data location from UI
        %
        %   This method is handed down from HasDataLocationModel superclass
        %   and is triggered by the DataLocationRemoved event on the
        %   DataLocationModel class
            
            %rowNumber = evt.DataIndex;
            
            rowIdx = find(strcmp({obj.Data.Name}, evt.DataLocationName));
            
            if ~isempty(rowIdx)
                obj.removeRow(rowIdx)
            end 
            
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
                    
                case 'RootPath'
                    obj.updateDataLocationRoot(rowIdx, evt.NewValue)
                    
                otherwise
                
                
            end
        
        end
        
    end
end