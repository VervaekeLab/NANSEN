classdef FolderOrganizationUI < applify.apptable & nansen.config.mixin.HasDataLocationModel
% Class interface for editing file path settings in a uifigure
    
% Todo: Add "api" class?
% Todo: rename class. FolderOrganization something

% Todo: Simplify component creation. 
%     [] Get cell locations as array with one entry for each column of a row.
%     [] Do the centering when getting the cell locations.
%     [] Set fontsize/bg color and other properties in batch.

%     [ ] Reset table - delete all rows
%     [ ] Add row, use advancedView flag to determine/update display

%     [ ] Make sure changes to the controls are added to the data location
%     model right away.
%
%     [ ] Add option for selecting whether lowest level is file or folder.
%     I.e if data from many sessions, i.e sData, NWB files are located in
%     the same folder...
%   
%     [ ] If a folder organization template is used for the first data @
%         location, should also fill out the metadata ui  


% Note: this class is a mess when it comes to updating the data and values.
% Needs work in order to instantly update the datalocation model on
% changes. The methods for updating are misused, so that whenever the
% subfolder example selection is changed, add row and remove row is called,
% although this does not mean the model is changed. Need to separate
% methods better...

%   Methods that use updateSubfolderItems
%       - addrow
%       - subfolderChanged
%       - ignoreListChanged
%       - expressionChanged
%       - onCurrentDataLocationSet
%
%   should separate beteen whether 1) names of existing subfolder levels are
%   changed, 2) subfolders levels are added or removed and 3) datalocation
%   is set/changed.


    properties
        AppFigure % Todo: make sure this is set...
    end

    properties
        CurrentDataLocation

        IsDirty = false     % Flag to show if data has changed.
        IsAdvancedView = true
        IsUpdating = false  % Flag to disable event notification when table is being updated.
        
        FolderListViewer
        FolderListViewerActive = false
    end
    
    properties (Access = protected) % Toolbar Components
        SelectDatalocationDropDownLabel
        SelectDataLocationDropDown
        SelectTemplateLabel
        SelectTemplateDropdown
        
        InfoButton
        PreviewButton
        ShowFilterOptionsButton
    end
    
    properties % todo...
        FolderHierarchyExampleImage
        CloseDialogButton
    end
    
    properties (Access = private)
        FolderOrganizationFilterListener
        FolderOrganizationTemplates
    end
    
    
    events
        FilterChanged
    end
    
    
    methods % Structors
        function obj = FolderOrganizationUI(dataLocationModel, varargin)
        %FolderOrganizationUI Construct a FolderOrganizationUI instance
            
            obj@nansen.config.mixin.HasDataLocationModel(dataLocationModel)
            
            data = dataLocationModel.Data;
            varargin = [varargin, {'CurrentDataLocation', data(1), ...
                'Data', data(1).SubfolderStructure}];

            obj@applify.apptable(varargin{:})
            
            obj.IsUpdating = true;
            for i = 1:obj.NumRows
                obj.updateSubfolderItems(i);
            end
            obj.IsUpdating = false;
            
            obj.AppFigure = ancestor(obj.Parent, 'figure');
                        
        end
        
        function delete(obj)
            
            isDeletable = @(h) ~isempty(h) && isvalid(h);
            
            if isDeletable(obj.FolderOrganizationFilterListener)
                delete(obj.FolderOrganizationFilterListener)
            end

            obj.closeFolderListViewer()
            
        end
        
    end
    
    methods (Access = protected) % Implementation of superclass methods

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
            %hRow.RemoveImage.Text = '-';
            hRow.RemoveImage.Text = '';
            hRow.RemoveImage.Icon = 'minus.png';

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
            hRow.SubfolderDropdown.ValueChangedFcn = @obj.onSubfolderSelectionValueChanged;
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
            %hRow.AddImage.Text = '+';
            hRow.AddImage.Text = '';
            hRow.AddImage.Icon = 'plus.png';
            hRow.AddImage.ButtonPushedFcn = @obj.onAddSubfolderButtonPushed;
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
            
        function createToolbarComponents(obj, hPanel)
        %createToolbarComponents Create "toolbar" components above table.    
            if nargin < 2; hPanel = obj.Parent.Parent; end
        
            import uim.utility.layout.subdividePosition
            
            toolbarPosition = obj.getToolbarPosition();
            
            dataLocationLabelWidth = 110;
            dataLocationSelectorWidth = 100;
            
            templateLabelWidth = 100;
            templateSelectorWidth = 100;
            
            symbolButtonWidth = 30;
            advancedButtonWidth = 135;
            
            Wl_init = [dataLocationLabelWidth, dataLocationSelectorWidth, templateLabelWidth, templateSelectorWidth];
            Wr_init = [symbolButtonWidth, symbolButtonWidth, advancedButtonWidth];
            
            % Get component positions for the components on the left
            [Xl, Wl] = subdividePosition(toolbarPosition(1), ...
                toolbarPosition(3), Wl_init, 10);
            
            
            % Get component positions for the components on the right
            [Xr, Wr] = subdividePosition(toolbarPosition(1), ...
                toolbarPosition(3), Wr_init, 10, 'right');
            
            Y = toolbarPosition(2);
            
            % Create SelectDatalocationDropDownLabel
            obj.SelectDatalocationDropDownLabel = uilabel(hPanel);
            obj.SelectDatalocationDropDownLabel.Position = [Xl(1) Y Wl(1) 22];
            obj.SelectDatalocationDropDownLabel.Text = 'Select data location:';

            % Create SelectDataLocationDropDown
            obj.SelectDataLocationDropDown = uidropdown(hPanel);
            obj.SelectDataLocationDropDown.Items = {'Rawdata'};
            obj.SelectDataLocationDropDown.ValueChangedFcn = @obj.onDataLocationSelectionChanged;
            obj.SelectDataLocationDropDown.Position = [Xl(2) Y Wl(2) 22];
            obj.SelectDataLocationDropDown.Value = 'Rawdata';
            
            % Create SelectTemplateLabel
            obj.SelectTemplateLabel = uilabel(hPanel);
            obj.SelectTemplateLabel.Position = [Xl(3) Y Wl(3) 22];
            obj.SelectTemplateLabel.HorizontalAlignment = 'right';
            obj.SelectTemplateLabel.Text = 'Select template:';
            

            % Create SelectDataLocationDropDown
            obj.SelectTemplateDropdown = uidropdown(hPanel);
            obj.SelectTemplateDropdown.ValueChangedFcn = @obj.onTemplateSelectionChanged;
            obj.SelectTemplateDropdown.Position = [Xl(4) Y Wl(4) 22];
            
            obj.FolderOrganizationTemplates = obj.getFolderOrganizationTemplates();
            
            
            obj.SelectTemplateDropdown.Items = ['No Selection', {obj.FolderOrganizationTemplates.Name}];
            obj.SelectTemplateDropdown.Value = 'No Selection';
            
                        
% %             % Create Info Button
% %             obj.InfoButton = uiimage(hPanel);
% %             obj.InfoButton.ImageClickedFcn = obj.onInfoButtonClicked;
% %             obj.InfoButton.Position = [Xr(1) Y-2 26 26];
% %             obj.InfoButton.ImageSource = 'info2.png';
            
            % Create PreviewFolderListImage
            obj.PreviewButton = uiimage(hPanel);
            obj.PreviewButton.ImageClickedFcn = @obj.onFolderPreviewButtonClicked;
            obj.PreviewButton.Tooltip = {'Press to preview detected folders...'};
            obj.PreviewButton.Position = [Xr(2) Y-2 26 26];
            obj.PreviewButton.ImageSource = 'look2.png';
            
            % Create ShowFilterOptionsButton
            obj.ShowFilterOptionsButton = uibutton(hPanel, 'state');
            obj.ShowFilterOptionsButton.ValueChangedFcn = @obj.onShowFilterOptionsButtonPushed;
            obj.ShowFilterOptionsButton.Text = 'Show Filter Options...';
            obj.ShowFilterOptionsButton.Position = [Xr(3) Y Wr(3) 22];
            
            obj.updateDataLocationSelector()
            
        end
        
        function toolbarComponents = getToolbarComponents(obj)
            toolbarComponents = [...
                obj.SelectDatalocationDropDownLabel, ...
                obj.SelectDataLocationDropDown, ...
                obj.SelectTemplateLabel, ...
                obj.SelectTemplateDropdown, ...
                obj.InfoButton, ...
                obj.PreviewButton, ...
                obj.ShowFilterOptionsButton ];
        end
        
    end
    
    methods % Public
        
        function updateDataLocationModel(obj)
        %updateDataLocationModel Update DLModel with current values from UI 
            
            currentDlName = obj.SelectDataLocationDropDown.Value;
            idx = find( strcmp({obj.DataLocationModel.Data.Name}, currentDlName) ); 
            
            S = obj.getSubfolderStructure();
            
            obj.DataLocationModel.updateSubfolderStructure(S, idx)
            
        end
        
        function closeFolderListViewer(obj)
            isDeletable = @(h) ~isempty(h) && isvalid(h);

            if isDeletable(obj.FolderListViewer)
                delete(obj.FolderListViewer)
            end
        end
    end
    
    methods % Set/get
        
        function set.CurrentDataLocation(obj, newDataLocation)
            obj.CurrentDataLocation = newDataLocation;
            obj.onCurrentDataLocationSet()
        end
        
    end
    
    methods (Access = private)

        function onCurrentDataLocationSet(obj)
        %onCurrentDataLocationSet Update controls based on current DataLoc
        
            if ~obj.IsConstructed; return; end
            
            obj.IsUpdating = true;
            
            obj.resetTable()
            
            obj.Data = obj.CurrentDataLocation.SubfolderStructure;
            
            % Recreate rows.
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
        
            if obj.IsUpdating 
                return; 
            else
                notify@handle(obj, eventName, eventData)
            end
            
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
        
        function setActive(obj)
        %setActive Execute actions needed for ui activation
        % Use if UI is part of an app with tabs, and the tab is selected
        
            if obj.FolderListViewerActive
                obj.showFolderListViewer()
            end
            
        end
        
        function setInactive(obj)
        %setInactive Execute actions needed for ui inactivation
        % Use if UI is part of an app with tabs, and the tab is unselected
            
            if obj.FolderListViewerActive
                obj.hideFolderListViewer()
            end
        end
        
        function wasSuccess = addRow(obj, src, ~)
            
            src.Enable = 'off';
            addRow@applify.apptable(obj)
            
            % Get row number of new row.
            rowNum = obj.getComponentRowNumber(src) + 1;

            if ~obj.IsAdvancedView
                obj.setRowDisplayMode(rowNum, false)
            end
            
            % Todo: should refactor this so that first, we check if folders
            % are available, then add row if confirmed...
            wasSuccess = obj.updateSubfolderItems(rowNum);
            if ~wasSuccess
                obj.removeRow()
                return
            end
            
            evtData = event.EventData();
            obj.notify('FilterChanged', evtData)
                        
        end
        
        function removeRow(obj, src, ~)
            
            if nargin < 2 % Remove last row if no input is given.
                i = obj.NumRows;
            elseif isnumeric(src)
                i = src;
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
        
        function onAddSubfolderButtonPushed(obj, src, ~)
            
            wasSuccess = obj.addRow(src);
            
            if ~wasSuccess
                % Show message if this failed....
                message = 'No subfolders were found within the selected folder';
                hFigure = ancestor(obj.Parent, 'figure');
                uialert(hFigure, message, 'Aborting')
            end
            
        end
        
        function onSubfolderSelectionValueChanged(obj, src, ~)
                        
            obj.subfolderChanged(src)
            
            % obj.updateDataLocationModel()
            
        end
        
        function subfolderChanged(obj, src, ~)
            
            obj.IsDirty = true;
            
            % todo: remove iRow and use getRow method (Still necessary? - 2022-01-26)
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
            
            %obj.updateDataLocationModel()

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
        %updateSubfolderItems Update values in controls...
            
            success = true;
            
            if iRow >= 1 && ~isempty(obj.CurrentDataLocation.RootPath)
                folderPath = obj.CurrentDataLocation.RootPath(1).Value;

                for jRow = 1:iRow-1 % Get folderpath from data struct...
                    folderPath = fullfile(folderPath, obj.Data(jRow).Name);
                end
            else
                folderPath = '';
            end
            
            S = obj.getSubfolderStructure();
            
            
            % Look for subfolders in the folderpath
            [~, dirName] = utility.path.listSubDir(folderPath, S(iRow).Expression, S(iRow).IgnoreList);

            
            % Get handle to dropdown control
            hSubfolderDropdown = obj.RowControls(iRow).SubfolderDropdown;
            
            % Show message dialog and return if no subfolders are found.
            if isempty(obj.CurrentDataLocation.RootPath)
                hSubfolderDropdown.Items = {'Root folder is not specified'};
                return
            elseif ~isfolder( obj.CurrentDataLocation.RootPath(1).Value )
                hSubfolderDropdown.Items = {'Data location root folder not found'};
                return
            elseif isempty(dirName) % && iRow > 1
% %                 message = 'No subfolders were found within the selected folder';
% %                 hFigure = ancestor(obj.Parent, 'figure');
% %                 uialert(hFigure, message, 'Aborting')
                success = false;
                hSubfolderDropdown.Items = {'No subfolders were found'};
                return
            end
            
            
            % Need to update field based on current data.
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
            
            %obj.IsDirty = true;
            
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
    
    methods % Callbacks for toolbar components
        
        function updateDataLocationSelector(obj)
        %updateDataLocationSelector Update items in dropdown
        
            numDataLocs = numel(obj.DataLocationModel.Data);
            numItems = numel(obj.SelectDataLocationDropDown.Items);

            % Add new, or rename items in dropdown list
            for i = 1:numDataLocs
                newName = obj.DataLocationModel.Data(i).Name;
            
                if i > numItems
                    obj.SelectDataLocationDropDown.Items{end+1} = newName;
                else
                    obj.SelectDataLocationDropDown.Items{i} = newName;
                end
            end
            
            % Remove items if there are too many (i.e data locations were removed)
            if numItems > numDataLocs
                for i = numItems : -1 : numDataLocs+1
                    obj.SelectDataLocationDropDown.Items(i) = [];
                end
            end
            
        end
        
        function onDataLocationSelectionChanged(obj, ~, event)
        %onDataLocationSelectionChanged Callback handler for when current datalocation changes    
        %
        %   This function gets the values for the subfolder struct from the
        %   current datalocation and adds to the datalocation model before
        %   changing the datalocation.
        %
        %   Note: This means that the subfolder structure is not updated in
        %   the datalocation model until the datalocation is changed.
        
                    
            % Important: Delete this listener so that the the table is not 
            % updated while recreating the subfolder settings table.
            
            % Todo: Dont need listener...
            delete(obj.FolderOrganizationFilterListener)
            
            oldDataLoc = event.PreviousValue;
            newDataLoc = event.Value;
            oldInd = strcmp({obj.DataLocationModel.Data.Name}, oldDataLoc);
            newInd = strcmp({obj.DataLocationModel.Data.Name}, newDataLoc);
            
            % Get data and save in datalocationmodel
            S = obj.getSubfolderStructure();
            
            % Does this trigger itself?
            obj.DataLocationModel.updateSubfolderStructure(S, find(oldInd))
            
            obj.CurrentDataLocation = obj.DataLocationModel.Data(newInd);
            
            drawnow
            
            obj.updateFolderList() % Todo: rename to updateFolderListTable?
            
            % Important: Restore listener.
            obj.FolderOrganizationFilterListener = listener(obj, ...
                'FilterChanged', @(s,e) obj.updateFolderList);
            
        end
    
        function onTemplateSelectionChanged(obj, src, event)
            
            dataLoc = obj.CurrentDataLocation;
            
            % Get the selected template:
            isMatched = strcmp({obj.FolderOrganizationTemplates.Name}, event.Value);
            if ~any( isMatched ); return; end
            
            templateFcn = str2func(...
                obj.FolderOrganizationTemplates(isMatched).FunctionName);
            S = templateFcn();
            
            % Check if template is different fram data in gui...
            if ~isequal(S.SubfolderStructure, dataLoc.SubfolderStructure) || ...
                    ~isequal(S.MetaDataDef, dataLoc.MetaDataDef)
                
                hFig = ancestor(src, 'figure');
                message = 'Template is different than existing data. Do you want to use template? Note: Existing data will be lost';
                
                answer = uiconfirm(hFig, message, 'Please confirm', 'Options', {'Use Template', 'Cancel'}, 'Icon', 'question');
                
                switch answer
                    case 'Cancel'
                        return
                    case 'Use Template'
                        [~, isMatched] = obj.DataLocationModel.containsItem(dataLoc.Name);
                        obj.DataLocationModel.updateSubfolderStructure(S.SubfolderStructure, isMatched)
                   
                        % Todo: Make method for this...
                        delete(obj.FolderOrganizationFilterListener)
                        obj.CurrentDataLocation = obj.DataLocationModel.Data(isMatched);
                        obj.updateFolderList()
                        obj.FolderOrganizationFilterListener = listener(obj, 'FilterChanged', @(s,e) obj.updateFolderList);
                        obj.IsDirty = true;
                        % Todo: Make sure metadata tab is updated as well
                end
                
            end
            
        end
        
        % Image clicked function: InfoIcon_2
        function onInfoButtonClicked(obj, event)
            obj.FolderHierarchyExampleImage.Visible = 'on';
            obj.CloseDialogButton.Visible = 'on';
        end

        % Image clicked function: CloseDialogButton
        function onCloseDialogButtonClicked(app, event)
            app.FolderHierarchyExampleImage.Visible = 'off';
            app.CloseDialogButton.Visible = 'off';
        end
        
        function onFolderPreviewButtonClicked(obj, src, evt)
        %onFolderPreviewButtonClicked Button callback
        %
        %   This callback toggles visibility a figure that displays all the
        %   folders that are detected using current configuration
        
            if ~isempty(obj.FolderListViewer) && isvalid(obj.FolderListViewer)
                if strcmp(obj.FolderListViewer.Visible, 'on')
                    obj.FolderListViewerActive = false;
                    obj.hideFolderListViewer()
                elseif strcmp(obj.FolderListViewer.Visible, 'off')
                    obj.FolderListViewerActive = true;
                    obj.showFolderListViewer()
                end
            else
                obj.FolderListViewerActive = true;
                obj.showFolderListViewer()
            end
        
        end
        
        % Value changed function: ShowFilterOptionsButton
        function onShowFilterOptionsButtonPushed(obj, src, event)
            
            switch src.Text
                case 'Show Filter Options...'
                    obj.showAdvancedOptions()
                    obj.ShowFilterOptionsButton.Text = 'Hide Filter Options...';
                case 'Hide Filter Options...'
                    obj.hideAdvancedOptions()
                    obj.ShowFilterOptionsButton.Text = 'Show Filter Options...';
            end
        end        
        
        % % % % Methods for the folder listing figure and table
        
        function createFolderListViewer(obj)
           
            % Todo: Move figure to left side of *current* screen:
            %app.NansenSetupUIFigure.Position(1) = 10;
            
            %hAppFig = ancestor(obj.Parent, 'figure');       
            %hAppFig.Position(1) = 10;
            
            obj.FolderListViewer = nansen.config.dloc.FolderPathViewer(obj.AppFigure);
            
            addlistener(obj.FolderListViewer, 'ObjectBeingDestroyed', ...
                @(s, e) obj.onFolderListViewerDeleted);
            
            
            % hFig.DeleteFcn = @(s,e) app.closeFolderListViewer;
            
            obj.FolderOrganizationFilterListener = listener(obj, ...
                'FilterChanged', @(s,e) obj.updateFolderList);
            

            % Give focus to the app figure
            figure(obj.AppFigure)
            
        end
    
        function showFolderListViewer(obj)
            
            import uim.utility.getCurrentScreenSize
            
            [screenSize, ~] = getCurrentScreenSize(obj.AppFigure);
            obj.AppFigure.Position(1) = screenSize(1) + 10;

            if isempty(obj.FolderListViewer) || ~isvalid(obj.FolderListViewer)
                obj.createFolderListViewer()
                obj.updateFolderList()
            end
            
            obj.PreviewButton.ImageSource = 'look3.png';
            obj.FolderListViewer.Visible = 'on';
            pause(0.01)
            
            if ~isempty(obj.AppFigure)
                figure(obj.AppFigure)
            end
            
        end
                
        function hideFolderListViewer(obj)
            
            if ~isempty(obj.FolderListViewer) && isvalid(obj.FolderListViewer)
                obj.PreviewButton.ImageSource = 'look2.png';
                obj.FolderListViewer.Visible = 'off';

                if ~isempty(obj.AppFigure)
                    uim.utility.centerFigureOnScreen(obj.AppFigure)
                end

            end
            
        end
        
        function onFolderListViewerDeleted(obj)
            
            if ~isvalid(obj); return; end
            
            obj.FolderListViewerActive = false;
            obj.PreviewButton.ImageSource = 'look2.png';
            obj.FolderListViewer = [];
            
            % % Todo: Which figure?
            %uim.utility.centerFigureOnScreen(app.NansenSetupUIFigure)
        end        
    
    end
    
    methods
        
        function updateFolderList(obj)
        
            % Todo...
            if isempty(obj.FolderListViewer) || ~isvalid(obj.FolderListViewer)
                return
            end
            
            % Make sure data location model is updated with current values
            obj.updateDataLocationModel()
            
            % Get currently selected data location
            currentDataLoc = obj.SelectDataLocationDropDown.Value;            
            dataLocation = obj.DataLocationModel.getItem(currentDataLoc);
          
            % List session folders for current data location
            sessionFolders = nansen.dataio.session.listSessionFolders(obj.DataLocationModel, currentDataLoc);
            if isempty(sessionFolders); sessionFolders = {''}; end
            
            sessionFolders = sessionFolders.(currentDataLoc);
            
            % Remove the root path from the displayed paths.
            rootPath = {dataLocation.RootPath.Value}; % Note rootpath is a struct with fields Key and Value
            for i = 1:numel(rootPath)
                sessionFolders = strrep(sessionFolders, rootPath{i}, sprintf('Root%d: ...', i));
            end
            
            % Update table data in folderlist viewer
            obj.FolderListViewer.Data = sessionFolders';
            
        end
        
    end
    
    methods (Access = protected)
       
        function onDataLocationModelSet(obj)
            onDataLocationModelSet@nansen.config.mixin.HasDataLocationModel(obj)
            if obj.IsConstructed
                obj.updateDataLocationSelector()
            end
        end
        
        function onDataLocationAdded(obj, ~, evt)
        %onDataLocationAdded Callback for DataLocationModel event
        %
        %   This method is inherited from the HasDataLocationModel 
        %   superclass and is triggered by the DataLocationAdded event on 
        %   the DataLocationModel object
        
            obj.updateDataLocationSelector()
        end
               
        function onDataLocationModified(obj, ~, evt)
        %onDataLocationModified Callback for DataLocationModel event
        %
        %   This method is inherited from the HasDataLocationModel 
        %   superclass and is triggered by the DataLocationModified event 
        %   on the DataLocationModel object
        
            switch evt.DataField
                case 'Name'
                    obj.updateDataLocationSelector()
                
                case 'RootPath'
                               
                    if strcmp( evt.DataLocationName, obj.CurrentDataLocation.Name )
                    
                        [~, newInd] = obj.DataLocationModel.containsItem(evt.DataLocationName);
                        obj.CurrentDataLocation = obj.DataLocationModel.Data(newInd);
% % 
% %                     obj.IsUpdating = true;
% %                     for i = 1:obj.NumRows
% %                         obj.updateSubfolderItems(i);
% %                     end
% %                     obj.IsUpdating = false;
% %                     
                        obj.updateFolderList()
                        
                    end
                                        
                otherwise
                    
            end
        
        end
        
        function onDataLocationRemoved(obj, ~, evt)
        %onDataLocationRemoved Callback for DataLocationModel event
        %
        %   This method is inherited from the HasDataLocationModel 
        %   superclass and is triggered by the DataLocationRemoved event on 
        %   the DataLocationModel object
            
            obj.updateDataLocationSelector()
        
        end
         
    end
    
    methods (Static)
        
        function S = getFolderOrganizationTemplates()
            
            % Todo: definitions should be generalized away from .m
            % functions
            
            nansenRootDir = nansen.localpath('nansen_root');
            templateDir = fullfile( nansenRootDir, ...
                'templates', 'datalocation');
            
            addpath(genpath(templateDir))
            
            subfolderPath = utility.path.listSubDir(templateDir);
            
            % Get all .m files in subdirectories
            for i = 1:numel(subfolderPath)
                if i == 1
                    L = dir(fullfile(subfolderPath{i}, '*.m') );
                else
                    L = cat(1, L, dir(fullfile(subfolderPath{i}, '*.m') ));
                end
            end
            
            S = struct('Name', {}, 'DataType', {}, 'FunctionName', {});
            
            for i = 1:numel(L)
                [~, functionName, ~] = fileparts(L(i).name);
                tmpFcn = str2func(functionName);
                tempS = tmpFcn();
                
                S(i).Name = tempS.Name;
                S(i).DataType = tempS.DataType;
                S(i).FunctionName = functionName;
                
            end
        end
    end
    
end