classdef VariableEditorTable < applify.apptable
% Class interface for editing variable name and file settings in a uifigure

% Todo: Simplify component creation. 
%     [ ] Get cell locations as array with one entry for each column of a row.
%     [ ] Do the centering when getting the cell locations.
%     [ ] Set fontsize/bg color and other properties in batch.

%     Table specific:
%     [x] Dynamic update of file type choices based on what is entered in
%        the filename expression field.

    properties (Constant)
        DEFAULT_FILETYPES = {'.mat', '.tif', '.raw'}
    end
    
    properties
        
        % Need Datalocations handle
        DataLocationModel = struct('Data', struct('Name', {'Rawdata', 'Processed', '', ''}, ...
            'RootPath', {{'HDD', ''}, {'HDD', ''}, {'', ''}, {'', ''}}, ...
            'Backup', {[], [], [], []}));
        DataFolders = {}
    end
    
    
    methods (Access = protected)

        function assignDefaultTablePropertyValues(obj)

            obj.ColumnNames = {'Data variable name', 'Data location', ...
                 'Filename expression', 'File type', 'File adapter'};
            obj.ColumnHeaderHelpFcn = @nansen.setup.getHelpMessage;
            obj.ColumnWidths = [160, 105, 145, 70, 75];
            obj.RowSpacing = 15;   
            obj.ColumnSpacing = 25;
        end
        
        function hRow = createTableRowComponents(obj, rowData, rowNum)
        
            hRow = struct();
            
        % % Create VariableName edit field
            i = 1;
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
            i = 2;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);

            hRow.DataLocSelect = uidropdown(obj.TablePanel);
            hRow.DataLocSelect.FontName = 'Segoe UI';
            hRow.DataLocSelect.BackgroundColor = [1 1 1];
            hRow.DataLocSelect.Position = [xi y wi-25 h];
            obj.centerComponent(hRow.DataLocSelect, y)
            
            hRow.DataLocSelect.Items = {obj.DataLocationModel.Data.Name}; % Todo: Where to get this from?
            if ~isempty(rowData.DataLocation)
                hRow.DataLocSelect.Value = rowData.DataLocation;
            end
            
            % Create Image for viewing folder
%             i = i+1;
%             [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            hRow.OpenFolderImage = uiimage(obj.TablePanel);
            hRow.OpenFolderImage.Position = [xi+wi-20 y 20 20];
            obj.centerComponent(hRow.OpenFolderImage, y)
            hRow.OpenFolderImage.ImageSource = 'look.png';
            hRow.OpenFolderImage.Tooltip = 'Show session folder';
            hRow.OpenFolderImage.ImageClickedFcn = @obj.openDataFolder;
            
            
        % % Create Filename Expression edit field
            i = 3;
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
            hRow.FileTypeSelect.Items = {'.mat', '.tif', '.raw'};
            hRow.FileTypeSelect.Value = '.mat';
            
            if ~isempty(rowData.FileType)
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
            
            hRow.FileAdapterSelect.Items = {'Not implemented yet'};
            hRow.FileAdapterSelect.Value = 'Not implemented yet';
            
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
                listOfFileExtension = {'.mat', '.tif', '.raw'};
            end
            
            hRow.FileTypeSelect.Items = listOfFileExtension;
            % Todo: List files....
            
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
        
    end
    
    methods
        
        function showPresetVariables(obj)
            
            rowComponentNames = fieldnames(obj.RowControls);
            for i = 2:numel(obj.RowControls)
                for j = 1:numel(rowComponentNames)
                    obj.RowControls(i).(rowComponentNames{j}).Visible = 'on';
                end
            end
            
        end
        
        function hidePresetVariables(obj)
            rowComponentNames = fieldnames(obj.RowControls);
            for i = 2:numel(obj.RowControls)
                for j = 1:numel(rowComponentNames)
                    obj.RowControls(i).(rowComponentNames{j}).Visible = 'off';
                end
            end
        end
        
        function setDataLocationModel(obj, newModel)
            
            obj.DataLocationModel = newModel;
            
            for i = 1:obj.NumRows
                obj.RowControls(i).DataLocSelect.Items = {obj.DataLocationModel.Data.Name}; % Todo: Where to get this from?
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