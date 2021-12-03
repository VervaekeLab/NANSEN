classdef FolderOrganizationEditor < applify.apptable
% Class interface for editing file path settings in a uifigure
    
% Todo: Add "api" class?
% Todo: rename class. FolderOrganization something

% Todo: Simplify component creation. 
%     [] Get cell locations as array with one entry for each column of a row.
%     [] Do the centering when getting the cell locations.
%     [] Set fontsize/bg color and other properties in batch.

%     [ ] Reset table - delete all rows
%     [ ] Add row, use advancedView flag to determine/update display

 
    properties
        DataLocation
        IsDirty = false     % Flag to show if data has changed.
        IsAdvancedView = true
        IsUpdating = false  % Flag to disable event notification when table is being updated.
    end
    
    events
        FilterChanged
    end
    
    
    methods
% %         function obj = FolderOrganizationEditor(varargin)
% %             
% %             obj@applify.apptable(varargin{:})
% %             
% %             for i = 1:obj.NumRows
% %                 obj.updateSubfolderItems(i)
% %             end
% %             
% %         end
        
    end
    

    methods (Access = protected)

        function assignDefaultTablePropertyValues(obj)
            
            obj.ColumnNames = {'', 'Select subfolder example', 'Set subfolder type', 'Exclusion list', 'Inclusion list', ''};
            obj.ColumnHeaderHelpFcn = @nansen.setup.getHelpMessage;
            obj.ColumnWidths = [22, 175, 130, 90, 125, 22];
            obj.RowSpacing = 20;   
            
        end
        
        function hRow = createTableRowComponents(obj, rowData, rowNum)
        
            hRow = struct();
            
        % % Create Button for removing current row.
            i = 1;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
                        
            
% %             hRow.RemoveImage = uiimage(obj.TablePanel);
% %             hRow.RemoveImage.Position = [xi y 20 20];
% %             hRow.RemoveImage.ImageSource = 'minus.png';
% %             hRow.RemoveImage.ImageClickedFcn = @obj.removeRow;
% %             obj.centerComponent(hRow.RemoveImage, y)
            
            hRow.RemoveImage = uibutton(obj.TablePanel);
            hRow.RemoveImage.Position = [xi y wi h];
            hRow.RemoveImage.Text = '-';
            %hRow.RemoveImage.Icon = 'minus.png';

            hRow.RemoveImage.ButtonPushedFcn = @obj.removeRow;
            if obj.NumRows == 0; hRow.RemoveImage.Enable = 'off'; end
                       
            if rowNum == 1
                hRow.RemoveImage.Enable = 'off';
            end
            
            
            obj.centerComponent(hRow.RemoveImage, y)
            
            
        % % Create SubfolderDropdown for selecting subfolder
            i = 2;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);

            hRow.SubfolderDropdown = uidropdown(obj.TablePanel);
            hRow.SubfolderDropdown.Items = {'Select subfolder'};
            hRow.SubfolderDropdown.FontName = 'Segoe UI';
            hRow.SubfolderDropdown.BackgroundColor = [1 1 1];
            hRow.SubfolderDropdown.Position = [xi y wi h];
            hRow.SubfolderDropdown.Value = 'Select subfolder';
            hRow.SubfolderDropdown.ValueChangedFcn = @obj.subfolderChanged;% todo: remove iRow and used getRow method in callback
            obj.centerComponent(hRow.SubfolderDropdown, y)

            
        % % Create SubfolderTypeDropdown for selecting subfolder type
            i = 3;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);

            hRow.SubfolderTypeDropdown = uidropdown(obj.TablePanel);
            hRow.SubfolderTypeDropdown.Position = [xi y wi h];
            obj.centerComponent(hRow.SubfolderTypeDropdown, y)
            hRow.SubfolderTypeDropdown.ValueChangedFcn = @obj.subFolderTypeChanged;
            
            hRow.SubfolderTypeDropdown.Items = {'Date', 'Animal', 'Session', 'Other'};
            
            if isempty(rowData.Type)
                hRow.SubfolderTypeDropdown.Value = 'Date';
                obj.Data(rowNum).Type = 'Date';
            else
                hRow.SubfolderTypeDropdown.Value = rowData.Type;
            end

            
        % % Create field for entering foldername expression
            i = 5;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            
            hRow.DynamicRegexp = uieditfield(obj.TablePanel, 'text');
            hRow.DynamicRegexp.FontName = 'Segoe UI';
            hRow.DynamicRegexp.BackgroundColor = [1 1 1];
            hRow.DynamicRegexp.Position = [xi y wi h];
            obj.centerComponent(hRow.DynamicRegexp, y)
            hRow.DynamicRegexp.ValueChangedFcn = @obj.expressionChanged;
            if ~isempty(rowData.Expression)
                hRow.DynamicRegexp.Value = rowData.Expression;
            end
            %@(s,e) obj.markDirty;
            
            
            i = 4;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            
            hRow.IgnoreList = uieditfield(obj.TablePanel, 'text');
            hRow.IgnoreList.FontName = 'Segoe UI';
            hRow.IgnoreList.BackgroundColor = [1 1 1];
            hRow.IgnoreList.Position = [xi y wi h];
            obj.centerComponent(hRow.IgnoreList, y)
            hRow.IgnoreList.ValueChangedFcn = @obj.ignoreListChanged;
            
            if ~isempty(rowData.IgnoreList)
                hRow.IgnoreList.Value = strjoin(rowData.IgnoreList, ', ');
            end
            %@(s,e) obj.markDirty;
            
        % % Create button for adding new row
            i = 6;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);
            
            hRow.AddImage = uibutton(obj.TablePanel);
            hRow.AddImage.Position = [xi y wi h];
            hRow.AddImage.Position(2) = y + (h-hRow.RemoveImage.Position(4)) / 2;
            hRow.AddImage.Text = '+';
            hRow.AddImage.ButtonPushedFcn = @obj.addRow;
            hRow.AddImage.Enable = 'off';
            obj.centerComponent(hRow.AddImage, y)

            % Alternative version using an image
% %             hRow.AddImage = uiimage(app.FolderListPanel);
% %             hRow.AddImage.Position = [xi y wi h];
% %             hRow.AddImage.Position(2) = y + (h-hRow.AddImage.Position(4)) / 2;
% %             hRow.AddImage.ImageSource = 'pluss.png';
% %             hRow.AddImage.ImageClickedFcn = @(s,e)app.addFolderLevelEntry;
            

            if rowNum > 1
                % Disable the button to add new row on the previous row.
                obj.RowControls(rowNum-1).AddImage.Enable = 'off';
            end
            
        end
            
    end
    
    
    methods % Set/get
        function set.DataLocation(obj, newDataLocation)
            obj.DataLocation = newDataLocation;
            obj.onDataLocationSet()
        end
    end
    
    methods (Access = private)
        function onDataLocationSet(obj)
            
            if ~obj.IsConstructed; return; end
            
            obj.IsUpdating = true;
            
            obj.resetTable()
            obj.Data = obj.DataLocation.SubfolderStructure;
            
            for i = 1:numel(obj.Data)
                rowData = obj.getRowData(i);
                obj.createTableRow(rowData, i)
                obj.updateSubfolderItems(i); % Semicolon, this fcn has output.
                if ~obj.IsAdvancedView
                    obj.setRowDisplayMode(i, false)
                end
            end

            obj.IsUpdating = false;

        end
    end
    
    
    methods % Callbacks for row components
        
        function notify(obj, eventName, eventData)
        %notify Disable event notification when table is being updated
        %
        %   Note: Some methods that notify about events are being invoked
        %   during table update. The method ensures that events are not
        %   triggered during table update.
        
            if obj.IsUpdating; return; end
            notify@handle(obj, eventName, eventData)
            
        end
        
        function showAdvancedOptions(obj)
            
            % Relocate / show header elements
            obj.setColumnHeaderDisplayMode(true)

            % Relocate / show column elements
            for i = 1:numel(obj.RowControls)
                obj.setRowDisplayMode(i, true)
            end
            
            obj.IsAdvancedView = true;
            drawnow
            
        end
        
        function hideAdvancedOptions(obj)
            
            % Relocate / show header elements
            obj.setColumnHeaderDisplayMode(false)
            
            % Relocate / show column elements
            for i = 1:numel(obj.RowControls)
                obj.setRowDisplayMode(i, false)
            end
            
            obj.IsAdvancedView = false;
            drawnow
        end
        
        function setColumnHeaderDisplayMode(obj, showAdvanced)
            
            xOffset = sum(obj.ColumnWidths(4:5)) + obj.ColumnSpacing;
            visibility = 'off';

            if showAdvanced
                xOffset = -1 * xOffset;
                visibility = 'on';
            end
            
            % Relocate / show header elements
            %obj.ColumnHeaderLabels{2}.Position(3) = obj.ColumnHeaderLabels{2}.Position(3) + xOffset;
            %obj.ColumnLabelHelpButton{2}.Position(1) = obj.ColumnLabelHelpButton{2}.Position(1) + xOffset;
            
            obj.ColumnHeaderLabels{3}.Position(1) = obj.ColumnHeaderLabels{3}.Position(1) + xOffset;
            obj.ColumnLabelHelpButton{3}.Position(1) = obj.ColumnLabelHelpButton{3}.Position(1) + xOffset;
            
            obj.ColumnHeaderLabels{4}.Visible = visibility;
            obj.ColumnLabelHelpButton{4}.Visible = visibility;
            
            obj.ColumnHeaderLabels{5}.Visible = visibility;
            obj.ColumnLabelHelpButton{5}.Visible = visibility;
            
        end
        
        function setRowDisplayMode(obj, rowNum, showAdvanced)
            
            xOffset = sum(obj.ColumnWidths(4:5)) + obj.ColumnSpacing;
            visibility = 'off';

            if showAdvanced
                xOffset = -1 * xOffset;
                visibility = 'on';
            end
            
            hRow = obj.RowControls(rowNum);
            hRow.SubfolderDropdown.Position(3) = hRow.SubfolderDropdown.Position(3) + xOffset;
            hRow.SubfolderTypeDropdown.Position(1) = hRow.SubfolderTypeDropdown.Position(1) + xOffset;
            hRow.DynamicRegexp.Visible = visibility;
            hRow.IgnoreList.Visible = visibility;
            
        end
        
        function markClean(obj)
            obj.IsDirty = false;
        end
        
        function markDirty(obj)
            obj.IsDirty = true;
        end
        
        function addRow(obj, src, ~)
            
            src.Enable = 'off';
            addRow@applify.apptable(obj)
            
            % Get row number of new row.
            rowNum = obj.getComponentRowNumber(src) + 1;

            if ~obj.IsAdvancedView
                obj.setRowDisplayMode(rowNum, false)
            end
            
            wasSuccess = obj.updateSubfolderItems(rowNum);
            if ~wasSuccess
                obj.removeRow()
            end
            
            evtData = event.EventData();
            obj.notify('FilterChanged', evtData)
            
        end
        
        function removeRow(obj, src, ~)
            
            if nargin < 2 % Remove last row if no input is given.
                i = obj.NumRows;
            else
                i = obj.getComponentRowNumber(src);
            end
            
            removeRow@applify.apptable(obj, i)
            
            % Enable button for adding new row on the row above the one 
            % that was just removed.
            if i > 1
                obj.RowControls(i-1).AddImage.Enable = 'on';
            end
            
            evtData = event.EventData();
            obj.notify('FilterChanged', evtData)
        end
        
        function resetTable(obj)
        %resetTable Remove all rows except for the first one.
        
            for i = 1:obj.NumRows
                obj.removeRow()
            end
            
        end
        
        function subfolderChanged(obj, src, ~)
            
            obj.IsDirty = true;
            
            iRow = obj.getComponentRowNumber(src);
            
            %Update data property obj.Data(iRow).Name
            obj.Data(iRow).Name = obj.RowControls(iRow).SubfolderDropdown.Value;

            if iRow == obj.NumRows
                return
            end
            
            % Update list of subfolder items on the next rows
            obj.updateSubfolderItems( iRow+1 )
            
            % Remove subfolders on successive rows if present
            for i = iRow+2:numel(obj.NumRows)
                obj.removeRow()
            end
            
        end
        
        function subFolderTypeChanged(obj, src, evt)
            iRow = obj.getComponentRowNumber(src);
            obj.Data(iRow).Type = src.Value;
            obj.markDirty()
        end
        
        function ignoreListChanged(obj, src, evt)
            iRow = obj.getComponentRowNumber(src);
            if isempty(src.Value)
                obj.Data(iRow).IgnoreList = {};
            else
                obj.Data(iRow).IgnoreList = strtrim( strsplit(src.Value, ',') );
            end
            obj.markDirty()
            
            evtData = event.EventData();
            obj.notify('FilterChanged', evtData)
            
            obj.updateSubfolderItems(iRow)

        end
        
        function expressionChanged(obj, src, evt)
            iRow = obj.getComponentRowNumber(src);
            obj.Data(iRow).Expression = src.Value;
            obj.markDirty()
            
            evtData = event.EventData();
            obj.notify('FilterChanged', evtData)
            
            obj.updateSubfolderItems(iRow)

        end
        
        function success = updateSubfolderItems(obj, iRow, folderPath)
            
            success = true;
            
            if iRow >= 1
                folderPath = obj.DataLocation.RootPath{1};

                for jRow = 1:iRow-1 % Todo: get folderpath from data struct...
                    folderPath = fullfile(folderPath, obj.Data(jRow).Name);
                end
            end
            
            S = obj.getSubfolderStructure();
            
            
            % Look for subfolders in the folderpath
            [~, dirName] = utility.path.listSubDir(folderPath, S(iRow).Expression, S(iRow).IgnoreList);
            
            L = dir(folderPath);
            L = L(~strncmp({L.name}, '.', 1));
            L = L([L.isdir]);
            %dirName = {L.name};
            
            % Get handle to dropdown control
            hSubfolderDropdown = obj.RowControls(iRow).SubfolderDropdown;
            
            % Show message dialog and return if no subfolders are found.
            if isempty(dirName) % && iRow > 1
                message = 'No subfolders were found within the selected folder';
                hFigure = ancestor(obj.Parent, 'figure');
                uialert(hFigure, message, 'Aborting')
                success = false;
                hSubfolderDropdown.Items = {'No subfolders were found'};
                return
            end
            
            % Need to update field based on current data.
            %hSubfolderDropdown.Items = {L.name};
            hSubfolderDropdown.Items = dirName;

            
            if isempty( obj.Data(iRow).Name )
                % Select the first subfolder:
                newValue = dirName{1};
            else
                if ~contains(hSubfolderDropdown.Items, obj.Data(iRow).Name)
                    % Todo: Add message saying that folder was not
                    % available in detected items.
                    newValue = dirName{1};
                else
                    newValue = obj.Data(iRow).Name;
                end
            end
            
            if ~isequal(hSubfolderDropdown.Value, newValue)
                hSubfolderDropdown.Value = newValue;
                if ~obj.IsUpdating
                    obj.subfolderChanged(hSubfolderDropdown)
                end
            end
            
            obj.Data(iRow).Name = hSubfolderDropdown.Value;
            
            % Switch button for adding new row.
            if iRow == obj.NumRows
                obj.RowControls(iRow).AddImage.Enable = 'on';
            end
            
            obj.IsDirty = true;
            
            if ~nargout
                clear success
            end
            
        end
        
        function S = getSubfolderStructure(obj)
            
            S = struct('Name', {}, 'Type', {}, 'Expression', {}, 'IgnoreList', {{}});
            
            for j= 1:numel(obj.RowControls)
                
                S(j).Name = obj.RowControls(j).SubfolderDropdown.Value;
                S(j).Type = obj.RowControls(j).SubfolderTypeDropdown.Value;
                
                inputExpr = obj.RowControls(j).DynamicRegexp.Value;

                % Convert input expressions to expression that can be
                % used with the regexp function
                if strcmp(S(j).Type, 'Date')
                    S(j).Expression = utility.string.dateformat2expression(inputExpr);
                    S(j).Expression = utility.string.numbersymbol2expression(S(j).Expression);
                else
                    S(j).Expression = utility.string.numbersymbol2expression(inputExpr);
                end
                
                ignoreList = obj.RowControls(j).IgnoreList.Value;
                if isempty(ignoreList)
                    S(j).IgnoreList = {};
                else
                    S(j).IgnoreList = strsplit(obj.RowControls(j).IgnoreList.Value, ',');
                    S(j).IgnoreList = strtrim(S(j).IgnoreList);
                    % If someone accidentally entered a comma at the end of
                    % the list.
                    if isempty(S(j).IgnoreList{end})
                        S(j).IgnoreList(end) = [];
                    end
                end
            end
            


        end
        
    end
    
end