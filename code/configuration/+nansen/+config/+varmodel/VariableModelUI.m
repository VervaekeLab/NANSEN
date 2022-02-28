classdef VariableModelUI < applify.apptable
% Class interface for editing variable name and file settings in a uifigure

% Todo: Simplify component creation. 
%     [ ] Get cell locations as array with one entry for each column of a row.
%     [ ] Do the centering when getting the cell locations.
%     [ ] Set fontsize/bg color and other properties in batch.

%     Table specific:
%     [x] Dynamic update of file type choices based on what is entered in
%        the filename expression field.
%     [ ] Remove button for rows...

    properties (Constant)
        DEFAULT_FILETYPES = {'.mat', '.tif', '.raw'}
    end
    
    properties
        DataLocationModel % DatalocationModel handle
        VariableModel
    end
    
    properties % Toolbar button...
        UIButton_AddVariable
        UIButton_ToggleVariableVisibility
    end
    
    properties (Access = private) % Layout properties
        ButtonSizeSmall = [22, 22]
        ButtonSizeLarge = [150, 22]
    end
    
    properties (SetAccess = private)
        IsDirty = false % keep this....?
    end
    
    methods % Constructor
        function obj = VariableModelUI(varargin)
        %DataLocationModelUI Construct a DataLocationModelUI instance
            obj@applify.apptable(varargin{:})
            
            obj.updateDataLocationDropdownItems()
            
            if ~nargout
                clear obj
            end
        end
    end
    
    methods (Access = protected)

        function assignDefaultTablePropertyValues(obj)

            obj.ColumnNames = {'', 'Data variable name', 'Data location', ...
                 'Filename expression', 'File type', 'File adapter'};
            obj.ColumnHeaderHelpFcn = @nansen.setup.getHelpMessage;
            obj.ColumnWidths = [12, 150, 105, 135, 70, 75];
            obj.RowSpacing = 15;   
            obj.ColumnSpacing = 20;
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
            hRow.RemoveImage.Icon = 'minus.png';
            hRow.RemoveImage.Tooltip = 'Remove Variable';

            hRow.RemoveImage.ButtonPushedFcn = @obj.onRemoveVariableButtonPushed;
            obj.centerComponent(hRow.RemoveImage, y)
            
            if rowData.IsDefaultVariable
                hRow.RemoveImage.Visible = 'off';
            end
            
        % % Create VariableName edit field
            i = 2;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            
            if rowData.IsDefaultVariable
                hRow.VariableName = uilabel(obj.TablePanel);
                hRow.VariableName.Text = rowData.VariableName;
            else
                hRow.VariableName = uieditfield(obj.TablePanel, 'text');
                hRow.VariableName.Value = rowData.VariableName;
            end
            
            hRow.VariableName.FontName = 'Segoe UI';
            hRow.VariableName.BackgroundColor = [1 1 1];
            hRow.VariableName.Position = [xi y wi h];
            obj.centerComponent(hRow.VariableName, y)

            
         % % Create DataLocation Dropdown
            i = 3;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);

            hRow.DataLocSelect = uidropdown(obj.TablePanel);
            hRow.DataLocSelect.FontName = 'Segoe UI';
            hRow.DataLocSelect.BackgroundColor = [1 1 1];
            hRow.DataLocSelect.Position = [xi y wi-25 h];
            obj.centerComponent(hRow.DataLocSelect, y)
            
            hRow.DataLocSelect.Items = {obj.DataLocationModel.Data.Name}; % Todo: Where to get this from?
            if ~isempty(rowData.DataLocation)
                if contains(rowData.DataLocation, hRow.DataLocSelect.Items)
                    hRow.DataLocSelect.Value = rowData.DataLocation;
                else
                    hRow.DataLocSelect.Items{end+1} = rowData.DataLocation;
                    hRow.DataLocSelect.Value = rowData.DataLocation;
                end
            end
            
            % Create Image for viewing folder
%             i = i+1;
%             [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            hRow.OpenFolderImage = uiimage(obj.TablePanel);
            hRow.OpenFolderImage.Position = [xi+wi-20 y 20 20];
            obj.centerComponent(hRow.OpenFolderImage, y)
            hRow.OpenFolderImage.ImageSource = 'look.png';
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
            hRow.FileNameExpr.ValueChangedFcn = @obj.fileNameExpressionChanged;
            
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
                if ~contains(rowData.FileType, hRow.FileTypeSelect.Items)
                    hRow.FileTypeSelect.Items{end+1} = rowData.FileType;
                end

                hRow.FileTypeSelect.Value = rowData.FileType;

            end
            
           % Create FileAdapter Dropdown
            i = i+1;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);

            hRow.FileAdapterSelect = uidropdown(obj.TablePanel);
            hRow.FileAdapterSelect.FontName = 'Segoe UI';
            hRow.FileAdapterSelect.BackgroundColor = [1 1 1];
            hRow.FileAdapterSelect.Position = [xi y wi h];
            obj.centerComponent(hRow.FileAdapterSelect, y)
            
            hRow.FileAdapterSelect.Items = {'Default', 'ImageStack'};
            
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
            
        end
        
        function createToolbarComponents(obj, hPanel)
        %createToolbarComponents Create "toolbar" components above table.    
            if nargin < 2; hPanel = obj.Parent.Parent; end
                        
            obj.createAddNewDataLocationButton(hPanel)
            
            obj.createShowVariablesToggleButton(hPanel)
            
        end
        
    end
    
    methods (Access = protected)
        
        function fileNameExpressionChanged(obj,src, evt)
            
            newExpression = src.Value;
            
            rowNumber = obj.getComponentRowNumber(src);
            hRow = obj.RowControls(rowNumber);
            
            folderPath = obj.getSelectedDataLocationFolderPath(rowNumber);
            
            expression = ['*', newExpression, '*'];
            L = dir(fullfile(folderPath, expression));
            
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
            
            obj.IsDirty = true;
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
            numRows = obj.NumRows;
            rowData = obj.VariableModel.getBlankItem;
            % Fuck, this is ugly
            if ~isfield(rowData, 'Uuid')
                rowData.Uuid = nansen.util.getuuid();
            end
            obj.addRow(numRows+1, rowData)
            obj.IsDirty = true;
        end
        
        function onRemoveVariableButtonPushed(obj, src, ~)
            
            rowNumber = obj.getComponentRowNumber(src);
            obj.VariableModel.removeItem(rowNumber)
            obj.removeRow(rowNumber)
            
            
        end
        
        function onShowVariablesToggleButtonValueChanged(obj, src, event)
            if strcmp(src.Text, 'Show all variables...')
                obj.showPresetVariables()
                src.Text = 'Show preset variables...';
                obj.UIButton_AddVariable.Enable = 'on';
            else
                obj.hidePresetVariables()
                src.Text = 'Show all variables...';
                obj.UIButton_AddVariable.Enable = 'off';
            end            
        end
        
    end
    
    methods
        
        function createAddNewDataLocationButton(obj, hPanel)
            
            % Todo: implement as toolbar...
            
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
            obj.UIButton_AddVariable.Icon = 'plus.png';
            obj.UIButton_AddVariable.Tooltip = 'Add New Variable';
            
        end
        
        function createShowVariablesToggleButton(obj, hPanel)
            import uim.utility.layout.subdividePosition
            
            hPanel = obj.Parent.Parent;

            toolbarPosition = obj.getToolbarPosition();
            
            % Create SelectDataLocationDropDownLabel
            obj.UIButton_ToggleVariableVisibility = uibutton(hPanel);
            obj.UIButton_ToggleVariableVisibility.Position(1:2) = toolbarPosition(1:2);
            obj.UIButton_ToggleVariableVisibility.Position(3:4) = obj.ButtonSizeLarge;
            obj.UIButton_ToggleVariableVisibility.Text = 'Show preset variables...';
            obj.UIButton_ToggleVariableVisibility.ButtonPushedFcn = @obj.onShowVariablesToggleButtonValueChanged;

        end
        
        
        
        function showPresetVariables(obj)
            rowComponentNames = fieldnames(obj.RowControls);
            
            % Todo:
            idx = find(~[obj.Data.IsDefaultVariable]);
            for i = idx %2:numel(obj.RowControls)
                for j = 1:numel(rowComponentNames)
                    obj.RowControls(i).(rowComponentNames{j}).Visible = 'on';
                end
            end
            
        end
        
        function hidePresetVariables(obj)
            rowComponentNames = fieldnames(obj.RowControls);
            idx = find(~[obj.Data.IsDefaultVariable]);
            for i = idx %2:numel(obj.RowControls)
                for j = 1:numel(rowComponentNames)
                    obj.RowControls(i).(rowComponentNames{j}).Visible = 'off';
                end
            end
        end
        
        function set.DataLocationModel(obj, newModel)
            
            obj.DataLocationModel = newModel;
            obj.updateDataLocationDropdownItems();

        end
        
        function updateDataLocationDropdownItems(obj)
            
            if obj.IsConstructed
                for i = 1:obj.NumRows
                    obj.RowControls(i).DataLocSelect.Items = {obj.DataLocationModel.Data.Name};
                end
            end
        end
        
        function S = getUpdatedTableData(obj)
                        
            S = struct('VariableName', {}, ...
                'IsDefaultVariable', {}, ...
                'FileNameExpression', {}, ...
                'DataLocation', {}, ...
                'FileType', {}, ...
                'FileAdapter', {}) ;
            
            % Todo: debug this (important)!
            S = obj.Data;
            
            for j = 1:obj.NumRows
                
                hRow = obj.RowControls(j);
                
                try
                    S(j).VariableName = hRow.VariableName.Value;
                    S(j).IsDefaultVariable = false;
                catch
                    S(j).VariableName = hRow.VariableName.Text;
                    S(j).IsDefaultVariable = true;
                end
                S(j).FileNameExpression = hRow.FileNameExpr.Value;
                S(j).DataLocation = hRow.DataLocSelect.Value;
                S(j).FileType = hRow.FileTypeSelect.Value;
                S(j).FileAdapter = hRow.FileAdapterSelect.Value;
            end
            


        end
        
    end
end