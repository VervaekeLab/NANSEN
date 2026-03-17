classdef MetadataInitializationUI < applify.apptable & nansen.config.mixin.HasDataLocationModel
% Class interface for editing metadata specifications in a uifigure
%
%

% Note: The data in this ui will only depend on the first datalocation. It
% might be an idea to let the user select which data location to use for
% detecting session information, but for simplicity the first data location
% is used.

% Todo: Simplify component creation.
%    [ ] Get cell locations as array with one entry for each column of a row.
%    [ ] Do the centering when getting the cell locations.
%    [ ] Set fontsize/bg color and other properties in batch.
%
%    [ ]Update DL Model whenever new values are entered. - Why???
%
%    [ ] Fix error that will occur if several subfolders are
%        given the same subfolder type?

    properties
        IsDirty = false;
        IsAdvancedView = false
    end

    properties (SetAccess = private) % Todo: make this public when support for changing it is added.
        DataLocationIndex = 1; %Todo: Select which dloc to use...
    end

    properties (Access = protected)
        StringFormat = cell(1, 4); % Store stringformat for each session metadata item. Relevant for date and time.
        FunctionName = cell(1, 4)
        Separator = cell(1, 4) % Store folder-level separator for each session metadata item.
        % Todo: This should be incorporated better, saving directly to the model.
    end

    properties (Access = private)  % Toolbar Components
        SelectDatalocationDropDownLabel
        SelectDataLocationDropDown
        AdvancedOptionsButton
    end

    methods % Structors
        function obj = MetadataInitializationUI(dataLocationModel, varargin)
        %FolderOrganizationUI Construct a FolderOrganizationUI instance

            obj@nansen.config.mixin.HasDataLocationModel(dataLocationModel)

            % Todo: Make it possible to select which datalocation to use..
            varargin = [varargin, {'Data', dataLocationModel.Data(1).MetaDataDef}];

            obj@applify.apptable(varargin{:})

            obj.onModelSet()

            % Reset IsDirty flag because it will be triggered when model is
            % set.
            obj.IsDirty = false;
        end
    end

    methods (Access = protected) % Methods for creation

        function assignDefaultTablePropertyValues(obj)

            obj.ColumnNames = {'Variable name', 'Select foldername', ...
                'Selection Mode', 'Input', 'Result'};
            obj.ColumnHeaderHelpFcn = @nansen.app.setup.getHelpMessage;
            obj.ColumnWidths = [110, 120, 125, 100, 100];
            obj.RowSpacing = 20;
            obj.ColumnSpacing = 25;
        end

        function hRow = createTableRowComponents(obj, rowData, rowNum)

            hRow = struct();

            % rootPath =  mfilename('fullpath') ;
            % imgPath = fullfile(rootPath, '_graphics');

        % % Create VariableName label
            i = 1;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);

            hRow.VariableName = uilabel(obj.TablePanel);
            hRow.VariableName.Position = [xi y wi h];
            hRow.VariableName.FontName = obj.FontName;
            obj.centerComponent(hRow.VariableName, y)

            hRow.VariableName.Text = rowData.VariableName;

        % % Create Filename Expression edit field
            i = 2;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);

            hRow.FolderNameSelector = uidropdown(obj.TablePanel);
            hRow.FolderNameSelector.BackgroundColor = [1 1 1];
            hRow.FolderNameSelector.Position = [xi y wi h];
            hRow.FolderNameSelector.FontName = obj.FontName;
            hRow.FolderNameSelector.ValueChangedFcn = @obj.onFolderNameSelectionChanged;
            hRow.FolderNameSelector.UserData = struct('FolderItems', {{}});
            obj.centerComponent(hRow.FolderNameSelector, y)
            hRow.FolderNameSelector.Items = {'Select foldername...'};
            hRow.FolderNameSelector.Value = 'Select foldername...';

            % Button shown in place of the dropdown when multiple folder
            % levels are selected (initially hidden).
            hRow.FolderMultiSelector = uibutton(obj.TablePanel);
            hRow.FolderMultiSelector.Position = [xi y wi h];
            hRow.FolderMultiSelector.FontName = obj.FontName;
            hRow.FolderMultiSelector.HorizontalAlignment = 'left';
            hRow.FolderMultiSelector.Text = 'Select folder(s)...';
            hRow.FolderMultiSelector.ButtonPushedFcn = @obj.onFolderSelectorButtonPushed;
            hRow.FolderMultiSelector.UserData = struct('FolderItems', {{}}, 'SelectedIndices', []);
            hRow.FolderMultiSelector.Visible = 'off';
            obj.centerComponent(hRow.FolderMultiSelector, y)

        % % Create Togglebutton group for selecting string detection mode
            i = 3;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);

            % Insert dialog button
            hRow.SelectSubstringButton = uibutton(obj.TablePanel);
            hRow.SelectSubstringButton.Position = [xi, y, wi, h];
            hRow.SelectSubstringButton.Text = 'Select Substring...';
            hRow.SelectSubstringButton.ButtonPushedFcn = @obj.onSelectSubstringButtonPushed;
            obj.centerComponent(hRow.SelectSubstringButton, y)

            % Create button group
            hRow.ButtonGroupStrfindMode = uibuttongroup(obj.TablePanel);
            hRow.ButtonGroupStrfindMode.BorderType = 'none';
            hRow.ButtonGroupStrfindMode.BackgroundColor = [1 1 1];
            hRow.ButtonGroupStrfindMode.Position = [xi y wi h];
            hRow.ButtonGroupStrfindMode.FontName = obj.FontName;
            hRow.ButtonGroupStrfindMode.ButtonDownFcn = ...
                @obj.onStrfindModeSelectionChanged;
            hRow.ButtonGroupStrfindMode.SelectionChangedFcn = ...
                @obj.onStrfindModeSelectionChanged;

            obj.centerComponent(hRow.ButtonGroupStrfindMode, y)

            % Create ModeButton1
            ModeButton1 = uitogglebutton(hRow.ButtonGroupStrfindMode);
            ModeButton1.Text = 'ind';
            ModeButton1.Position = [1 1 41 22];
            ModeButton1.Value = true;

            % Create ModeButton2
            ModeButton2 = uitogglebutton(hRow.ButtonGroupStrfindMode);
            ModeButton2.Text = 'expr';
            ModeButton2.Position = [41 1 41 22];

            % Create ModeButton3
            ModeButton3 = uitogglebutton(hRow.ButtonGroupStrfindMode);
            ModeButton3.Text = 'func';
            ModeButton3.Position = [81 1 41 22];

        % % Create Editbox for string expression input
            i = 4;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);

            hRow.StrfindInputEditbox = uieditfield(obj.TablePanel, 'text');
            hRow.StrfindInputEditbox.Position = [xi y wi h];
            hRow.StrfindInputEditbox.FontName = obj.FontName;
            hRow.StrfindInputEditbox.ValueChangedFcn = @obj.onStringInputValueChanged;

            obj.centerComponent(hRow.StrfindInputEditbox, y)
            hRow.StrfindInputEditbox.Enable = 'on';

            if ~isempty(rowData.StringDetectInput)
                hRow.StrfindInputEditbox.Value = rowData.StringDetectInput;
            end

        % % Advanced (function) Create buttons for edit/running function
            import uim.utility.layout.subdividePosition

            [xii, wii] = subdividePosition(xi, wi, [0.5,0.5], 5);
            hRow.EditFunctionButton = uibutton(obj.TablePanel);
            hRow.EditFunctionButton.Text = 'Edit';
            hRow.EditFunctionButton.Position = [xii(1) y wii(1) h];
            hRow.EditFunctionButton.Visible = 'off';
            hRow.EditFunctionButton.ButtonPushedFcn = ...
                @obj.onEditFunctionButtonClicked;
            obj.centerComponent(hRow.EditFunctionButton, y)

            hRow.RunFunctionButton = uibutton(obj.TablePanel);
            hRow.RunFunctionButton.Text  = 'Run';
            hRow.RunFunctionButton.Position = [xii(2) y wii(2) h];
            hRow.RunFunctionButton.Visible = 'off';
            hRow.RunFunctionButton.ButtonPushedFcn = ...
                @obj.onRunFunctionButtonClicked;
            obj.centerComponent(hRow.RunFunctionButton, y)

        % % Create Editbox to show detected string.
            i = 5;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);

            hRow.StrfindResultEditbox = uieditfield(obj.TablePanel, 'text');
            hRow.StrfindResultEditbox.Position = [xi y wi h];
            hRow.StrfindResultEditbox.Enable = 'off';
            hRow.StrfindResultEditbox.FontName = obj.FontName;
            obj.centerComponent(hRow.StrfindResultEditbox, y)
        end

        function createToolbarComponents(obj, hPanel)
        %createToolbarComponents Create "toolbar" components above table.
            if nargin < 2; hPanel = obj.Parent.Parent; end

            obj.createAdvancedOptionsButton(hPanel)
            obj.createDataLocationSelector(hPanel)
        end

        function toolbarComponents = getToolbarComponents(obj)
            toolbarComponents = obj.AdvancedOptionsButton;
        end
    end

    methods (Access = private) %Callbacks for userinteraction with controls

        function onFolderNameSelectionChanged(obj, src, ~)
        % Callback for the folder-level dropdown

            rowNumber = obj.getComponentRowNumber(src);

            if strcmp(src.Value, 'Select multiple folders...')
                % Open multi-select dialog
                hFig = ancestor(src, 'figure');
                folderItems = src.UserData.FolderItems;
                currentSeparator = obj.Separator{rowNumber};
                if isempty(currentSeparator); currentSeparator = ''; end

                [selectedIndices, separator] = obj.showFolderSelectorDialog( ...
                    folderItems, [], currentSeparator, hFig.Position);

                if numel(selectedIndices) > 1
                    obj.exitFuncModeIfActive(rowNumber);
                    obj.switchToMultiSelectMode(rowNumber, selectedIndices, separator);
                elseif isscalar(selectedIndices)
                    % User picked exactly one — stay in dropdown mode
                    obj.exitFuncModeIfActive(rowNumber);
                    src.Value = folderItems{selectedIndices};
                else
                    % User cancelled — reset dropdown, leave mode unchanged
                    src.Value = src.Items{1};
                    return
                end
            else
                obj.exitFuncModeIfActive(rowNumber);
            end

            obj.Data(rowNumber).SubfolderLevel = obj.getSubfolderLevel(rowNumber);

            try
                obj.updateStringResult(rowNumber)
            catch ME
                if strcmp(ME.identifier, 'MATLAB:badsubscript')
                    ME = obj.getModifiedBadSubscriptException();
                end
                hFig = ancestor(src, 'figure');
                uialert(hFig, ME.message, 'Update Failed')
            end

            src.Tooltip = src.Value;
            obj.IsDirty = true;
        end

        function onFolderSelectorButtonPushed(obj, src, ~)
        % Callback for the multi-select button (shown when >1 levels selected)

            rowNumber = obj.getComponentRowNumber(src);
            folderItems = src.UserData.FolderItems;
            currentIndices = src.UserData.SelectedIndices;
            currentSeparator = obj.Separator{rowNumber};
            if isempty(currentSeparator); currentSeparator = ''; end

            hFig = ancestor(src, 'figure');
            [selectedIndices, separator] = obj.showFolderSelectorDialog( ...
                folderItems, currentIndices, currentSeparator, hFig.Position);

            if isequal(selectedIndices, currentIndices) && strcmp(separator, currentSeparator)
                return % No change — leave mode unchanged
            end

            obj.exitFuncModeIfActive(rowNumber);

            if isscalar(selectedIndices)
                % Reduced to a single folder — revert to dropdown
                obj.switchToSingleSelectMode(rowNumber, selectedIndices);
            elseif numel(selectedIndices) > 1
                src.UserData.SelectedIndices = selectedIndices;
                obj.Separator{rowNumber} = separator;
                obj.updateFolderSelectorButtonText(src, folderItems, selectedIndices);
            else
                % User cleared the selection — revert to dropdown, no selection
                obj.switchToSingleSelectMode(rowNumber, []);
            end

            obj.Data(rowNumber).SubfolderLevel = obj.getSubfolderLevel(rowNumber);

            try
                obj.updateStringResult(rowNumber)
            catch ME
                if strcmp(ME.identifier, 'MATLAB:badsubscript')
                    ME = obj.getModifiedBadSubscriptException();
                end
                uialert(hFig, ME.message, 'Update Failed')
            end

            obj.IsDirty = true;
        end

        function onSelectSubstringButtonPushed(obj, src, evt)
        % Open a dialog window for selecting letter positions.

            % Get foldername for the row which user pushed button from
            rowNumber = obj.getComponentRowNumber(src);
            hRow = obj.RowControls(rowNumber);

            % Build the combined folder string from the selected levels and
            % separator — this is the string the pattern is applied to.
            folderName = obj.getCombinedFolderName(rowNumber);

            % Create a dialog where the user can select a substring from
            % the foldername
            hFig = ancestor(src, 'figure');
            IND = uim.dialog.createStringSelectorDialog(folderName, hFig.Position);

            % Return if user canceled...
            if isempty(IND)
                pause(0.1)
                figure(hFig) % Bring uifigure back to focus
                return
            % ...Or update data and controls
            else
                hRow.StrfindInputEditbox.Value = obj.simplifyIndices(IND);

                % If the variable is date or time, try to convert to
                % datetime value:
                if obj.isDateTimeVariable(hRow.VariableName.Text)

                    shortName = strrep(hRow.VariableName.Text, 'Experiment', '');

                    substring = obj.getFolderSubstring(rowNumber);
                    [dtInFormat, dtOutFormat] = obj.uiGetDateTimeFormat(hRow.VariableName.Text, substring);

                    if ~isempty(dtInFormat)
                        try
                            datetimeValue = datetime(substring, 'InputFormat', dtInFormat);
                            datetimeValue.Format = dtOutFormat;
                            hRow.StrfindResultEditbox.Value = char(datetimeValue);
                            obj.StringFormat{rowNumber} = dtInFormat;
                        catch ME
                            uialert(hFig, ME.message, sprintf('%s Format Error', shortName))
                        end
                    else
                        message = 'This value will be represented as text. You can still change your mind!';
                        uialert(hFig, message, sprintf('%s is represented as text', shortName), 'Icon','warning')
                    end
                else
                    obj.updateStringResult(rowNumber)
                end
            end

            obj.IsDirty = true;

            figure(hFig) % Bring uifigure back into focus
        end

        function onStringInputValueChanged(obj, src, event)
        %onStringInputValueChanged Updates result editfield when the string
        % input/selection indices are modified.

            substring = '';

            thisDataLocation = obj.DataLocationModel.Data(obj.DataLocationIndex);
            M = thisDataLocation.MetaDataDef;

            rowNumber = obj.getComponentRowNumber(src);
            hRow = obj.RowControls(rowNumber);
            identifierName = obj.getIdentifierNameForRow(rowNumber);

            try
                substring = obj.getFolderSubstring(rowNumber);
            catch ME
                hFig = ancestor(src, 'figure');
                substring = 'N/A';
                errorMessage = sprintf('Failed to extract "%s" from folder path. Caused by:\n\n%s', identifierName, ME.message);
                uialert(hFig, errorMessage, 'String extraction failed')
            end

            % Convert date/time value if date/time format is available
            if obj.isDateTimeVariable(M(rowNumber).VariableName)
                if isa(substring, 'datetime')
                    substring = char(substring);
                else
                    examplePath = thisDataLocation.ExamplePath;
                    try
                        switch M(rowNumber).VariableName
                            case 'Experiment Time'
                                value = obj.DataLocationModel.getTime(examplePath, obj.DataLocationIndex);
                            case 'Experiment Date'
                                value = obj.DataLocationModel.getDate(examplePath, obj.DataLocationIndex);
                        end
                    catch
                        value = '';
                    end
                    substring = char(value);
                end
            end

            hRow.StrfindResultEditbox.Value = substring;
            hRow.StrfindResultEditbox.Tooltip = substring;

            obj.IsDirty = true;
        end

        function onRunFunctionButtonClicked(obj, src, evt)
            rowNumber = obj.getComponentRowNumber(src);

            if ~isempty(obj.FunctionName{rowNumber})
                try
                    feval(obj.FunctionName{rowNumber}, '', '')
                catch ME
                    functionExists = ~strcmp(ME.identifier, 'MATLAB:UndefinedFunction');
                end
            else
                functionExists = false;
            end

            if ~functionExists
                hFig = ancestor(src, 'figure');
                message = sprintf( ['The function does not exist yet. ', ...
                    'Please press "Edit" to initialize the function from a template.']);
                uialert(hFig, message, 'Function missing...','Icon', 'info')
                return
            end

            obj.onStringInputValueChanged(src, evt)
        end

        function onEditFunctionButtonClicked(obj, src, evt)

            rowNumber = obj.getComponentRowNumber(src);

            identifierName = obj.getIdentifierNameForRow(rowNumber);
            functionName = createFunctionName(identifierName); % local function

            pm = nansen.ProjectManager();
            p = pm.getCurrentProject();
            fileName = sprintf('%s.m', functionName);
            functionFilePath = fullfile(p.getModuleFolder(), '+datalocation', fileName);

            dataLocations = obj.DataLocationModel.Data;

            if ~isfile(functionFilePath)
                nansen.config.dloc.createFunctionFromTemplate(dataLocations, identifierName, functionName)

                hFig = ancestor(src, 'figure');
                message = sprintf( ['The function "%s" will be opened in MATLAB''s editor. ', ...
                    'Please update the function so that it extracts the correct value ', ...
                    'from a session''s folderpath and hit the "Run" button to test it.'], functionName);
                uialert(hFig, message, 'Edit function...','Icon','info' )
                edit(functionFilePath)
            else
                % Todo :
                % nansen.config.dloc.updateFunctionTemplate(functionFilePath, dataLocations);
                edit(functionFilePath)
            end

            fullFunctionName = utility.path.abspath2funcname(functionFilePath);
            obj.FunctionName{rowNumber} = fullFunctionName;
            obj.IsDirty = true;
        end

        function onStrfindModeSelectionChanged(obj, src, evt)
        % onStrfindModeSelectionChanged Callback when strfind mode selection changes

            rowNumber = obj.getComponentRowNumber(src);
            obj.setFunctionButtonVisibility(rowNumber)
            hInputEditbox = obj.RowControls(rowNumber).StrfindInputEditbox;
            obj.onStringInputValueChanged(hInputEditbox)
        end

        function onDataLocationSelectionChanged(obj, src, evt)
        % onDataLocationSelectionChanged - Dropdown value changed callback

            newInd = obj.DataLocationModel.getItemIndex(evt.Value);

            % Update datalocationmodel with data from ui
            obj.updateDataLocationModel()

            % Change current data location
            obj.DataLocationIndex = newInd;
        end
    end

    methods % Methods for updating the Result column

        function substring = getFolderSubstring(obj, rowNumber)
        %getFolderSubstring Get folder substring based on current UI selections
        %
        %   Builds an S struct from the current UI state and delegates the
        %   full extraction to DataLocationModel.getSubstringFromFolder.

            dlIdx = obj.DataLocationIndex;
            thisDataLocation = obj.DataLocationModel.Data(dlIdx);

            S = struct();
            S.StringDetectMode  = obj.getStringSearchMode(rowNumber);
            S.StringDetectInput = obj.getStringSearchPattern(rowNumber, S.StringDetectMode);
            S.SubfolderLevel    = obj.getSubfolderLevel(rowNumber);
            S.Separator         = obj.Separator{rowNumber};
            S.NumSubfolders     = numel(thisDataLocation.SubfolderStructure);
            S.FunctionName      = obj.FunctionName{rowNumber};

            dataLocationName = thisDataLocation.Name;
            substring = obj.DataLocationModel.getSubstringFromFolder( ...
                thisDataLocation.ExamplePath, S, dataLocationName);
        end
    end

    methods % Methods for updating

        function set.DataLocationIndex(obj, newIndex)
            obj.DataLocationIndex = newIndex;
            obj.onModelSet()
        end

        function set.IsDirty(obj, newValue)
            obj.IsDirty = newValue;
        end

        function setActive(obj)
        %setActive Execute actions needed for ui activation
        % Use if UI is part of an app with tabs, and the tab is selected
        end

        function setInactive(obj)
        %setInactive Execute actions needed for ui inactivation
        % Use if UI is part of an app with tabs, and the tab is unselected
            obj.updateDataLocationModel()
        end

        function updateDataLocationModel(obj)
        %updateDataLocationModel Update DLModel with changes from UI
            S = obj.getMetaDataDefinitionStruct();
            dataLocationIdx = obj.DataLocationIndex;
            obj.DataLocationModel.updateMetaDataDefinitions(S, dataLocationIdx)
        end

        function S = getMetaDataDefinitionStruct(obj)
        %getMetaDataDefinitionStruct Get struct of values from UI controls

            S = obj.DataLocationModel.getDefaultMetadataStructure();

            % Retrieve values from controls and add to struct
            for i = 1:obj.NumRows
                S(i).StringDetectMode = obj.getStringSearchMode(i);
                S(i).StringDetectInput = obj.getStringSearchPattern(i);
                S(i).SubfolderLevel = obj.getSubfolderLevel(i);
                S(i).StringFormat = obj.StringFormat{i};
                S(i).Separator = obj.Separator{i};
                S(i).FunctionName = obj.FunctionName{i};
            end
        end

        function onModelSet(obj)
        %onModelSet Callback for when DatalocationModel is set/reset
        %
        %   % Update control values based on the DataLocationModel

            dlIdx = obj.DataLocationIndex;
            thisDataLocation = obj.DataLocationModel.Data(dlIdx);

            % Update Items of subfolder dropdown
            obj.setFolderSelectionItems()

            % Update values of subfolder dropdown based on the metadata
            % definitions
            M = thisDataLocation.MetaDataDef;

            % Update internal values from M
            for i = 1:obj.NumRows
                % Set stringformat from datalocation model.
                obj.StringFormat{i} = thisDataLocation.MetaDataDef(i).StringFormat;
                if isfield(thisDataLocation.MetaDataDef(i), 'Separator')
                    obj.Separator{i} = thisDataLocation.MetaDataDef(i).Separator;
                else
                    obj.Separator{i} = '';
                end
                try
                    obj.FunctionName{i} = thisDataLocation.MetaDataDef(i).FunctionName;
                catch
                    obj.FunctionName{i} = '';
                end
            end

            obj.updateFolderSelectionValue(M)

            % Update results
            for i = 1:obj.NumRows
                % Update detection mode
                obj.setStringSearchMode(i, M(i).StringDetectMode)
                obj.setFunctionButtonVisibility(i)

                hComp = obj.RowControls(i).StrfindInputEditbox;
                % Update value in string detection input
                hComp.Value = M(i).StringDetectInput;
                obj.onStringInputValueChanged(hComp)
            end
        end

        function setFolderSelectionItems(obj)
        %setFolderSelectionItems Populate the folder-level dropdown items for each row

            dlIdx = obj.DataLocationIndex;
            thisDataLocation = obj.DataLocationModel.Data(dlIdx);

            subFolderStructure = thisDataLocation.SubfolderStructure;
            folderItems = {subFolderStructure.Name};
            folderItems(cellfun(@isempty, folderItems)) = {'Foldername not found'};

            for i = 1:obj.NumRows
                hRow = obj.RowControls(i);

                % Store the clean folder list in both controls for index lookups.
                hRow.FolderNameSelector.UserData.FolderItems = folderItems;
                hRow.FolderMultiSelector.UserData.FolderItems = folderItems;

                % Build dropdown items — Session ID gets the multi-select option.
                dropdownItems = ['Select foldername...', folderItems];
                if strcmp(hRow.VariableName.Text, 'Session ID')
                    dropdownItems = [dropdownItems, {'Select multiple folders...'}];
                end
                hRow.FolderNameSelector.Items = dropdownItems;
            end
        end

        function updateFolderSelectionValue(obj, M)
        %updateFolderSelectionValue Restore the folder selection controls from the model

            dlIdx = obj.DataLocationIndex;
            thisDataLocation = obj.DataLocationModel.Data(dlIdx);
            subFolderStructure = thisDataLocation.SubfolderStructure;

            for i = 1:obj.NumRows
                folderItems = obj.RowControls(i).FolderNameSelector.UserData.FolderItems;

                itemIdx = M(i).SubfolderLevel;

                % If there is no selection, try to infer from the data organization.
                if isempty(itemIdx)
                    itemIdx = obj.initFolderSelectionItemIndex(i, subFolderStructure);
                end

                % Clamp to valid range (0 means no selection).
                if isscalar(itemIdx) && itemIdx == 0
                    itemIdx = [];
                else
                    itemIdx = itemIdx(itemIdx >= 1 & itemIdx <= numel(folderItems));
                end

                if numel(itemIdx) > 1
                    separator = '';
                    if isfield(M(i), 'Separator'); separator = M(i).Separator; end
                    obj.switchToMultiSelectMode(i, itemIdx, separator);
                else
                    obj.switchToSingleSelectMode(i, itemIdx);
                end
            end
        end

        function itemIdx = initFolderSelectionItemIndex(obj, rowNumber, subFolderStructure)
        %initFolderSelectionItemIndex Guess which index should be selected
        %
        %   For each subfolder level in the folder organization, there is a
        %   type. If the type matches with the current row, use the index
        %   of that subfolder level as the initial choice.

            itemIdx = 0;
            switch obj.RowControls(rowNumber).VariableName.Text
                case 'Subject ID'
                    isMatched = strcmp({subFolderStructure.Type}, 'Subject');
                    if any(isMatched)
                        itemIdx = find(isMatched);
                    end
                case 'Session ID'
                    isMatched = strcmp({subFolderStructure.Type}, 'Session');
                    if any(isMatched)
                        itemIdx = find(isMatched);
                    end
                case {'Date', 'Experiment Date'}
                    isMatched = strcmp({subFolderStructure.Type}, 'Date');
                    if any(isMatched)
                        itemIdx = find(isMatched);
                    end
                case {'Time', 'Experiment Time'}
                    itemIdx = 0;
                otherwise
                    itemIdx = 0;
            end
        end

        function updateStringResult(obj, rowNumber)

            hRow = obj.RowControls(rowNumber);

            % Update values in editboxes
            substring = obj.getFolderSubstring(rowNumber);
            hRow.StrfindResultEditbox.Value = char( substring );
            hRow.StrfindResultEditbox.Tooltip = char( substring );

            if ~isempty( obj.StringFormat{rowNumber} )
                dtInFormat = obj.StringFormat{rowNumber};
                datetimeValue = datetime(substring, 'InputFormat', dtInFormat);

                dtOutFormat = obj.getDateTimeOutFormat(hRow.VariableName.Text);
                datetimeValue.Format = dtOutFormat;
                substring = char(datetimeValue);

                hRow.StrfindResultEditbox.Value = substring;
                hRow.StrfindResultEditbox.Tooltip = substring;
            end
        end

        function updateDataLocationSelector(obj)
        %updateDataLocationSelector Update items in dropdown
            dataLocationNames = {obj.DataLocationModel.Data.Name};
            isSelected = strcmp(obj.SelectDataLocationDropDown.Items, obj.SelectDataLocationDropDown.Value);
            obj.SelectDataLocationDropDown.Items = dataLocationNames;
            try
                obj.SelectDataLocationDropDown.Value = obj.SelectDataLocationDropDown.Items{isSelected};
            catch
                obj.SelectDataLocationDropDown.Value = obj.SelectDataLocationDropDown.Items{1};
            end
        end
    end

    methods

        function markClean(obj)
            obj.IsDirty = false;
        end

        function mode = getStringSearchMode(obj, rowNumber)

            buttonGroup = obj.RowControls(rowNumber).ButtonGroupStrfindMode;
            h = buttonGroup.SelectedObject;
            mode = h.Text;
        end

        function setStringSearchMode(obj, rowNumber, value)
            buttonGroup = obj.RowControls(rowNumber).ButtonGroupStrfindMode;
            hButtons = buttonGroup.Children;

            isMatch = strcmp({hButtons.Text}, value);
            buttonGroup.SelectedObject = hButtons(isMatch);
        end

        function strPattern = getStringSearchPattern(obj, rowNumber, mode)

            if nargin < 3
                mode = obj.getStringSearchMode(rowNumber);
            end

            hRow = obj.RowControls(rowNumber);
            strInd = hRow.StrfindInputEditbox.Value;

            strPattern = strInd;
            return

            switch lower(mode)

                case 'ind'
%                     strInd = strrep(strInd, '-', ':');
%
%                     strInd = sprintf('[%s]', strInd);
%
%                     strPattern = eval(strInd);

                case 'expr'
                    strPattern = strInd;
            end
        end

        function indices = getSubfolderLevel(obj, rowNumber)
            hRow = obj.RowControls(rowNumber);
            if strcmp(hRow.FolderMultiSelector.Visible, 'on')
                indices = hRow.FolderMultiSelector.UserData.SelectedIndices;
            else
                folderItems = hRow.FolderNameSelector.UserData.FolderItems;
                indices = find(strcmp(folderItems, hRow.FolderNameSelector.Value));
            end
        end
    end

    methods % Show/hide advanced options.

        function createDataLocationSelector(obj, hPanel)

            import uim.utility.layout.subdividePosition

            toolbarPosition = obj.getToolbarPosition();

            dataLocationLabelWidth = 110;
            dataLocationSelectorWidth = 125;

            Wl_init = [dataLocationLabelWidth, dataLocationSelectorWidth];

            % Get component positions for the components on the left
            [Xl, Wl] = subdividePosition(toolbarPosition(1), ...
                toolbarPosition(3), Wl_init, 10);

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

            obj.updateDataLocationSelector()
        end

        function createAdvancedOptionsButton(obj, hPanel)
        %createAdvancedOptionsButton Create button to toggle advanced options

            buttonSize = [160, 22];

            toolbarPosition = obj.getToolbarPosition();
            location(1) = sum(toolbarPosition([1,3])) - buttonSize(1);
            location(2) = toolbarPosition(2);

            obj.AdvancedOptionsButton = uibutton(hPanel, 'push');
            obj.AdvancedOptionsButton.ButtonPushedFcn = @obj.onShowAdvancedOptionsButtonPushed;
            obj.AdvancedOptionsButton.Position = [location buttonSize];
            obj.AdvancedOptionsButton.Text = 'Show Advanced Options...';
        end

        function onShowAdvancedOptionsButtonPushed(obj, src, ~)
        %onShowAdvancedOptionsButtonPushed Button pushed callback
        %
        %   Toggle the view for advanced options and update the button
        %   label according to button state

            switch src.Text
                case 'Show Advanced Options...'
                    obj.showAdvancedOptions()
                    obj.AdvancedOptionsButton.Text = 'Hide Advanced Options...';
                case 'Hide Advanced Options...'
                    obj.hideAdvancedOptions()
                    obj.AdvancedOptionsButton.Text = 'Show Advanced Options...';
            end
        end

        function showAdvancedOptions(obj)

            % Relocate / show header elements
            obj.setColumnHeaderDisplayMode(true)
            obj.IsAdvancedView = true;

            % Relocate / show column elements
            for i = 1:numel(obj.RowControls)
                obj.setRowDisplayMode(i, true)
                obj.setFunctionButtonVisibility(i)
            end

            drawnow
        end

        function hideAdvancedOptions(obj)

            % Relocate / show header elements
            obj.setColumnHeaderDisplayMode(false)
            obj.IsAdvancedView = false;

            % Relocate / show column elements
            for i = 1:numel(obj.RowControls)
                obj.setRowDisplayMode(i, false)
                obj.setFunctionButtonVisibility(i)
            end

            drawnow
        end

        function setColumnHeaderDisplayMode(obj, showAdvanced)

            xOffset = sum(obj.ColumnWidths(4))+obj.ColumnSpacing;
            visibility = 'off';

            if showAdvanced
                xOffset = -1 * xOffset;
                visibility = 'on';
            end

            % Relocate / show header elements
            obj.ColumnHeaderLabels{3}.Position(1) = obj.ColumnHeaderLabels{3}.Position(1) + xOffset;
            obj.ColumnLabelHelpButton{3}.Position(1) = obj.ColumnLabelHelpButton{3}.Position(1) + xOffset;
            obj.ColumnHeaderLabels{4}.Visible = visibility;
            obj.ColumnLabelHelpButton{4}.Visible = visibility;

            if showAdvanced
                obj.ColumnHeaderLabels{3}.Text = 'Selection mode';
                obj.ColumnLabelHelpButton{3}.Tag = 'Selection mode';
            else
                obj.ColumnHeaderLabels{3}.Text = 'Select string';
                obj.ColumnLabelHelpButton{3}.Tag = 'Select string';
            end
        end

        function setRowDisplayMode(obj, rowNum, showAdvanced)

            xOffset = sum(obj.ColumnWidths(4))+obj.ColumnSpacing;
            visibility = 'off';
            visibility_ = 'on';

            if showAdvanced
                xOffset = -1 * xOffset;
                visibility = 'on';
                visibility_ = 'off';
            end

            hRow = obj.RowControls(rowNum);
            hRow.FolderNameSelector.Position(3) = hRow.FolderNameSelector.Position(3) + xOffset;
            hRow.FolderMultiSelector.Position(3) = hRow.FolderMultiSelector.Position(3) + xOffset;
            hRow.SelectSubstringButton.Position(1) = hRow.SelectSubstringButton.Position(1) + xOffset;

            hRow.SelectSubstringButton.Visible = visibility_;
            hRow.ButtonGroupStrfindMode.Visible = visibility;
            hRow.StrfindInputEditbox.Visible = visibility;
        end

        function setFunctionButtonVisibility(obj, rowNumber)

            hRow = obj.RowControls(rowNumber);

            showButtons = strcmp(hRow.ButtonGroupStrfindMode.SelectedObject.Text, 'func') ...
                            && obj.IsAdvancedView;

            if showButtons
                hRow.RunFunctionButton.Visible = 'on';
                hRow.EditFunctionButton.Visible = 'on';
                hRow.StrfindInputEditbox.Visible = 'off';
            else
                hRow.RunFunctionButton.Visible = 'off';
                hRow.EditFunctionButton.Visible = 'off';
                if obj.IsAdvancedView
                    hRow.StrfindInputEditbox.Visible = 'on';
                else
                    hRow.StrfindInputEditbox.Visible = 'off';
                end
            end
        end
    end

    methods (Access = protected) % Listener callbacks inherited from HasDataLocationModel

        function onDataLocationModified(obj, ~, evt)
        %onDataLocationModified Callback for DataLocationModel event
        %
        %   This method is inherited from the HasDataLocationModel
        %   superclass and is triggered by the DataLocationModified event
        %   on the DataLocationModel object

            switch evt.DataField
                case 'SubfolderStructure'

                    % Todo: Should this be more specific? i.e does not need
                    % to invoke this method know when filters change...

                    [~, idx] = obj.DataLocationModel.containsItem(evt.DataLocationName);

                    % Currently, only the first data location requires an
                    % update of this ui.
                    if idx == obj.DataLocationIndex

                        obj.setFolderSelectionItems()
                        obj.updateFolderSelectionValue(obj.Data)

                        % Update result of string indexing based on model...
                        for i = 1:obj.NumRows
                            hComp = obj.RowControls(i).StrfindInputEditbox;
                            obj.onStringInputValueChanged(hComp)
                        end
                    end
                case 'Name'
                    obj.updateDataLocationSelector()

                otherwise
                    % No change is necessary
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

        function onDataLocationRemoved(obj, ~, evt)
        %onDataLocationRemoved Callback for DataLocationModel event
        %
        %   This method is inherited from the HasDataLocationModel
        %   superclass and is triggered by the DataLocationRemoved event on
        %   the DataLocationModel object

            obj.updateDataLocationSelector()
        end
    end

    methods (Access = private)
        function substring = getSubstringFromRowFunction(obj, rowNumber)
            dlIdx = obj.DataLocationIndex;
            thisDataLocation = obj.DataLocationModel.Data(dlIdx);
            pathStr = thisDataLocation.ExamplePath;
            dataLocationName = thisDataLocation.Name;
            substring = feval(obj.FunctionName{rowNumber}, pathStr, dataLocationName);
        end

        function exitFuncModeIfActive(obj, rowNumber)
        %exitFuncModeIfActive Switch from func to ind mode when folder selection changes
        %
        %   func mode ignores folder selection entirely, so keeping it active
        %   when the user changes the folder would produce a silent no-op.
        %   Switching back to ind is the predictable default; the user can
        %   re-select expr or func manually if needed.

            if strcmp(obj.getStringSearchMode(rowNumber), 'func')
                obj.setStringSearchMode(rowNumber, 'ind')
                obj.setFunctionButtonVisibility(rowNumber)
            end
        end

        function switchToMultiSelectMode(obj, rowNumber, selectedIndices, separator)
        %switchToMultiSelectMode Show button, hide dropdown, store selection

            hRow = obj.RowControls(rowNumber);
            folderItems = hRow.FolderNameSelector.UserData.FolderItems;

            hRow.FolderMultiSelector.UserData.FolderItems = folderItems;
            hRow.FolderMultiSelector.UserData.SelectedIndices = selectedIndices;
            obj.Separator{rowNumber} = separator;

            obj.updateFolderSelectorButtonText( ...
                hRow.FolderMultiSelector, folderItems, selectedIndices);

            hRow.FolderNameSelector.Visible = 'off';
            hRow.FolderMultiSelector.Visible = 'on';
        end

        function switchToSingleSelectMode(obj, rowNumber, selectedIndex)
        %switchToSingleSelectMode Hide button, show dropdown, clear multi-selection

            hRow = obj.RowControls(rowNumber);
            folderItems = hRow.FolderNameSelector.UserData.FolderItems;

            hRow.FolderMultiSelector.Visible = 'off';
            hRow.FolderMultiSelector.UserData.SelectedIndices = [];
            obj.Separator{rowNumber} = '';

            hRow.FolderNameSelector.Visible = 'on';

            if ~isempty(selectedIndex) && selectedIndex >= 1 && selectedIndex <= numel(folderItems)
                hRow.FolderNameSelector.Value = folderItems{selectedIndex};
            else
                hRow.FolderNameSelector.Value = hRow.FolderNameSelector.Items{1};
            end
        end

        function combinedName = getCombinedFolderName(obj, rowNumber)
        %getCombinedFolderName Get the combined folder string for a row
        %
        %   Used by onSelectSubstringButtonPushed to show the user the
        %   string that the extraction pattern will be applied to.

            dlIdx = obj.DataLocationIndex;
            thisDataLocation = obj.DataLocationModel.Data(dlIdx);
            separator = obj.Separator{rowNumber};

            combinedName = nansen.config.dloc.DataLocationModel.combineFolderNamesFromPath( ...
                thisDataLocation.ExamplePath, ...
                obj.getSubfolderLevel(rowNumber), ...
                numel(thisDataLocation.SubfolderStructure), ...
                separator);
        end

        function updateFolderSelectorButtonText(~, hButton, folderItems, selectedIndices)
        %updateFolderSelectorButtonText Update button label and tooltip to reflect selection

            if isempty(selectedIndices)
                hButton.Text = 'Select folder(s)...';
                hButton.Tooltip = '';
            else
                arrowStr = '  ▼';
                fullName = strjoin(folderItems(selectedIndices), ' + ');
                label = truncateTextForWidth(fullName, hButton.Position(3), ...
                    hButton.FontSize, arrowStr);
                hButton.Text = [label arrowStr];
                hButton.Tooltip = fullName;
            end
        end

        function [selectedIndices, separator] = showFolderSelectorDialog( ...
                obj, folderItems, currentIndices, currentSeparator, parentPosition)
        % showFolderSelectorDialog Modal dialog for selecting folder levels
        %
        %   Opens a figure with a multi-select listbox and a separator
        %   field. Returns the selected indices and separator string, or
        %   the original values if the user cancels.

            selectedIndices = currentIndices;
            separator = currentSeparator;

            dialogWidth = 300;
            dialogHeight = 300;
            dialogX = parentPosition(1) + (parentPosition(3) - dialogWidth) / 2;
            dialogY = parentPosition(2) + (parentPosition(4) - dialogHeight) / 2;

            dialogFigure = uifigure( ...
                'Name', 'Select Folder Level(s)', ...
                'Position', [dialogX, dialogY, dialogWidth, dialogHeight], ...
                'WindowStyle', 'modal', ...
                'Resize', 'off');

            uilabel(dialogFigure, ...
                'Text', 'Select one or more folder levels:', ...
                'Position', [15 265 270 22]);

            hListbox = uilistbox(dialogFigure, ...
                'Items', folderItems, ...
                'Multiselect', 'on', ...
                'Position', [15 110 270 150]);

            if ~isempty(currentIndices) && max(currentIndices) <= numel(folderItems)
                hListbox.Value = folderItems(currentIndices);
            end

            uilabel(dialogFigure, 'Text', 'Separator:', 'Position', [15 75 80 22]);
            hSeparatorField = uieditfield(dialogFigure, 'text', ...
                'Value', currentSeparator, ...
                'Position', [100 75 185 22], ...
                'Placeholder', 'e.g. _ (leave blank for none)');

            uibutton(dialogFigure, 'Text', 'OK', ...
                'Position', [195 30 90 30], ...
                'ButtonPushedFcn', @(~,~) uiresume(dialogFigure));
            uibutton(dialogFigure, 'Text', 'Cancel', ...
                'Position', [100 30 90 30], ...
                'ButtonPushedFcn', @(~,~) delete(dialogFigure));

            uiwait(dialogFigure);

            % If figure still exists, the user pressed OK — read the values.
            if isvalid(dialogFigure)
                selected = hListbox.Value;
                if ischar(selected); selected = {selected}; end
                selectedIndices = find(ismember(folderItems, selected));
                separator = hSeparatorField.Value;
                delete(dialogFigure);
            end
            % else: user cancelled or closed — return the original values.
        end
    end

    methods (Static, Access = private)

        function identifierName = getIdentifierNameForRow(rowNumber)
            identifierNames = {'subjectId', 'sessionId', 'experimentDate', 'experimentTime'};
            identifierName = identifierNames{rowNumber};
        end

        function tf = isDateTimeVariable(variableName)
            tf = contains(variableName, {'Date', 'Time'});
        end

        function [inFormat, outFormat] = uiGetDateTimeFormat(variableName, strValue)
        %uiGetDateTimeFormat Get datetime input and output format

            % Get datetime values for date & time variables.
            if strcmp(variableName, 'Experiment Date')
                dlgTitle = 'Enter Date Format';
                msg = sprintf('Please enter date format for the selected text: "%s". For example: yyyy-MM-dd.', strValue);
                outFormat = 'MMM-dd-yyyy';
            elseif strcmp(variableName, 'Experiment Time')
                dlgTitle = 'Enter Time Format';
                msg = sprintf('Please enter time format for the selected text: "%s". For example: HH-mm-ss.', strValue);
                outFormat = 'HH:mm:ss';
            end

            msg = strjoin({msg, 'See the MATLAB documentation for "datetime" for a full list of examples (type ''doc datetime'' in MATLAB''s Command Window).'});
            answer = inputdlg(msg, dlgTitle);

            if ~isempty(answer) && ~isempty(answer{1})
            	inFormat = answer{1};
            else
                inFormat = '';
            end
        end

        function outFormat = getDateTimeOutFormat(variableName)

            if strcmp(variableName, 'Experiment Date')
                outFormat = 'MMM-dd-yyyy';
            elseif strcmp(variableName, 'Experiment Time')
                outFormat = 'HH:mm:ss';
            end
        end

        function IND = simplifyIndices(IND)
        %simplifyIndices Simplify the indices, by joining all subsequent using
        % the colon separator, i.e 1 2 3 4 5 -> 1:5

            indOrig = num2str(IND);

            indNew = {};
            count = 1;

            finished = false;
            while ~finished

                % Find number in list which is not increment of previous
                lastSequenceIdx = find(diff(IND, 2) ~= 0, 1, 'first') + 1;
                if isempty(lastSequenceIdx)
                    lastSequenceIdx = numel(IND);
                end

                % Add indices of format first:last to results
                indNew{count} = sprintf('%d:%d', IND(1), IND(lastSequenceIdx));

                % Remove all numbers that were part of sequence
                IND(1:lastSequenceIdx) = [];
                count = count+1;

                if isempty(IND)
                    finished = true;
                end
            end

            % Join sequences
            IND = strjoin(indNew, ',');

            % Keep the shortest character vector
            if numel(IND) > indOrig
                IND = indOrig;
            end
        end

        function ME = getModifiedBadSubscriptException()

            ME = MException('NANSEN:SubstringSelection:BadSubscript', ...
                'The indices for selecting a substring does not match the length of the foldername');
        end
    end
end

function truncatedText = truncateTextForWidth(text, widthPx, fontSizePt, ~)
%truncateTextForWidth Truncate text so it fits within a pixel width budget
%
%   Estimates character width as 0.6x the font size (pt→px, proportional
%   font approximation) and reserves a fixed pixel budget for the arrow
%   indicator. Replaces the last character with '…' when truncation occurs.

    arrowReservedPx = 16;
    pixelsPerChar   = fontSizePt * 0.6;
    maxChars = floor((widthPx - arrowReservedPx) / pixelsPerChar);

    if numel(text) > maxChars && maxChars > 3
        truncatedText = [text(1:maxChars-1) '…'];
    else
        truncatedText = text;
    end
end

function functionName = createFunctionName(identifierName)
    %Example: subjectId -> getSubjectId

    identifierName(1) = upper(identifierName(1));
    functionName = sprintf('get%s', identifierName);
end
