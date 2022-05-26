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
%    [ ] Update DL Model whenever new values are entered.
%
%    [ ] Fix error that will occur if several subfolders are
%        given the same subfolder type?


    properties
        IsDirty = false;
        IsAdvancedView = true
    end
    
    properties (SetAccess = private) % Todo: make this public when support for changing it is added.
        DataLocationIndex = 1; %Todo: Select which dloc to use...
    end
    
    properties (Access = protected)
        StringFormat = cell(1, 4); % Store stringformat for each session metadata item. Relevant for date and time.
        % Todo: This should be incorporated better, saving directly to the model.
    end
    
    properties (Access = private) % Toolbar
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
            obj.ColumnHeaderHelpFcn = @nansen.setup.getHelpMessage;
            obj.ColumnWidths = [110, 120, 125, 100, 100];
            obj.RowSpacing = 20;   
            obj.ColumnSpacing = 25;
        end
        
        function hRow = createTableRowComponents(obj, rowData, rowNum)
        
            hRow = struct();
            
            %rootPath =  mfilename('fullpath') ;
            %imgPath = fullfile(rootPath, '_graphics');
            
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
            obj.centerComponent(hRow.FolderNameSelector, y)

            % Todo: Get folders from DataLocation.
            hRow.FolderNameSelector.Items = {'Select foldername...'};
            hRow.FolderNameSelector.Value = 'Select foldername...';
            
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
            obj.centerComponent(hRow.ButtonGroupStrfindMode, y)
            
            % Create ModeButton1
            ModeButton1 = uitogglebutton(hRow.ButtonGroupStrfindMode);
            ModeButton1.Text = 'ind';
            ModeButton1.Position = [1 1 62 22];
            ModeButton1.Value = true;

            % Create ModeButton2
            ModeButton2 = uitogglebutton(hRow.ButtonGroupStrfindMode);
            ModeButton2.Text = 'expr';
            ModeButton2.Position = [62 1 62 22];
            
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

        end
        
        function toolbarComponents = getToolbarComponents(obj)
            toolbarComponents = obj.AdvancedOptionsButton;
        end
        
    end
    
    methods (Access = private) %Callbacks for userinteraction with controls
        
        function onFolderNameSelectionChanged(obj, src, ~)
        % Add value to tooltip of control
        
            src.Tooltip = src.Value;
        end

        function onSelectSubstringButtonPushed(obj, src, evt)
        % Open a dialog window for selecting letter positions.
        
            % Get foldername for the row which user pushed button from
            rowNumber = obj.getComponentRowNumber(src);
            hRow = obj.RowControls(rowNumber);
            folderName = hRow.FolderNameSelector.Value;
           
            % Create a dialog where the user can select a substring from 
            % the foldername
            hFig = ancestor(src, 'figure');
            IND = uim.dialog.createStringSelectorDialog(folderName, hFig.Position);

            % Return if user canceled...
            if isempty(IND)
                pause(0.1)
                figure(hFig) % Bring uifigure back to focus
                return
            else % ...Or update data and controls
                
                % Update values in editboxes
                substring = folderName(IND);
                hRow.StrfindInputEditbox.Value = obj.simplifyInd(IND);
                
                hRow.StrfindResultEditbox.Value = substring;
                hRow.StrfindResultEditbox.Tooltip = substring;

                % If the variable is date or time, try to convert to
                % datetime value:
                if obj.isDateTimeVariable(hRow.VariableName.Text)
                    
                    shortName = strrep(hRow.VariableName.Text, 'Experiment', '');
   
                    [dtInFormat, dtOutFormat] = obj.getDateTimeFormat(hRow.VariableName.Text, substring);
                    
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
            mode = obj.getStrSearchMode(rowNumber);
            
            hRow = obj.RowControls(rowNumber);
            
            strPattern = obj.getStrSearchPattern(rowNumber, mode);
            
            folderName = hRow.FolderNameSelector.Value;

            try
                switch lower(mode)
                    case 'ind'
                        substring = eval( ['folderName([' strPattern '])'] );

                    case 'expr'
                        substring = regexp(folderName, strPattern, 'match', 'once');
                end
            
            catch ME
                hFig = ancestor(src, 'figure');
                uialert(hFig, ME.message, 'Invalid input')
            end
            
            % Convert date/time value if date/time format is available
            if obj.isDateTimeVariable(M(rowNumber).VariableName)
                
                
                examplePath = thisDataLocation.ExamplePath;
                
                switch M(rowNumber).VariableName
                    case 'Experiment Time'
                        value = obj.DataLocationModel.getTime(examplePath);
                    case 'Experiment Date'
                        value = obj.DataLocationModel.getDate(examplePath);
                end
                
                substring = char(value);
                
            end

            hRow.StrfindResultEditbox.Value = substring;
            hRow.StrfindResultEditbox.Tooltip = substring;
            
            obj.IsDirty = true;
        end

    end
    
    methods % Methods for updating
        
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
            obj.DataLocationModel.updateMetaDataDefinitions(S)
        end
        
        function S = getMetaDataDefinitionStruct(obj)
        %getMetaDataDefinitionStruct Get struct of values from UI controls
        
            S = obj.DataLocationModel.getDefaultMetadataStructure();
               
            % Retrieve values from controls and add to struct
            for i = 1:obj.NumRows
                S(i).StringDetectMode = obj.getStrSearchMode(i);
                S(i).StringDetectInput = obj.getStrSearchPattern(i);
                S(i).SubfolderLevel = obj.getSubfolderLevel(i);
                S(i).StringFormat = obj.StringFormat{i};
            end

        end
        
        function onModelSet(obj)
        %onModelSet Callback for when DatalocationModel is set/reset
        %
        %   % Update control values based on the DataLocationModel
            
            dlIdx = obj.DataLocationIndex;
            thisDataLocation = obj.DataLocationModel.Data(dlIdx);
            
            % Update Items and Value of subfolder dropdown
            obj.setFolderSelectionItems()
            
            % Update value in string detection input
            
            % Update results
            for i = 1:obj.NumRows
                hComp = obj.RowControls(i).StrfindInputEditbox;
                obj.onStringInputValueChanged(hComp)
                
                % Set stringformat from datalocation model.
                obj.StringFormat{i} = thisDataLocation.MetaDataDef(i).StringFormat;
            end
            
        end

        function setFolderSelectionItems(obj)
        %setFolderSelectionItems Add model's folder names to each dropdown
        
            % TODO: Fix error that will occur if several subfolders are
            % given the same subfolder type?
            
            dlIdx = obj.DataLocationIndex;
            thisDataLocation = obj.DataLocationModel.Data(dlIdx);
            
            % Get all the folder selector controls
            h = [obj.RowControls.FolderNameSelector];
            
            % Get the folder choice examples from the data location model
            subFolderStructure = thisDataLocation.SubfolderStructure;
            folderChoices = ['Select foldername...', {subFolderStructure.Name}];
            
            M = thisDataLocation.MetaDataDef;
            
            %oldValues = arrayfun(@(i) find(strcmp(h(i).Items, h(i).Value)), 1:numel(h));
            
            folderChoices(cellfun(@isempty, folderChoices)) = deal({'Foldername not found'});
            set(h, 'Items', folderChoices)
            
            for i = 1:numel(h)
                %itemInd = oldValues(i);
                itemInd = M(i).SubfolderLevel;
                
                % If there is no selection, try to infer from the data
                % organization.
                if isempty(itemInd)
                    switch obj.RowControls(i).VariableName.Text
                        case 'Animal ID'
                            isMatched = strcmp({subFolderStructure.Type}, 'Animal');
                            if any(isMatched)
                                itemInd = find(isMatched);
                            end
                        case 'Session ID'
                            isMatched = strcmp({subFolderStructure.Type}, 'Session');
                            if any(isMatched)
                                itemInd = find(isMatched);
                            end
                        case {'Date', 'Experiment Date'}
                            isMatched = strcmp({subFolderStructure.Type}, 'Date');
                            if any(isMatched)
                                itemInd = find(isMatched);
                            end
                        case {'Time', 'Experiment Time'}
                            itemInd = 0; 
                        otherwise
                            itemInd = 0; 
                    end
                end
                
                if isempty(itemInd)
                    itemInd = 0;
                elseif numel(itemInd)>1
                    itemInd = itemInd(1);
                end
                
                set(h(i), 'Value', folderChoices{itemInd+1})
            end
        end

    end
    
    methods
        
        function markClean(obj)
            obj.IsDirty = false;
        end
        
        function mode = getStrSearchMode(obj, rowNumber)
            
            hBtnGroup = obj.RowControls(rowNumber).ButtonGroupStrfindMode;
            h = hBtnGroup.SelectedObject;
            mode = h.Text;
            
        end
        
        function strPattern = getStrSearchPattern(obj, rowNumber, mode)
            
            if nargin < 3
                mode = obj.getStrSearchMode(rowNumber);
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
        
        function num = getSubfolderLevel(obj, rowNumber)
            
            hDropdown = obj.RowControls(rowNumber).FolderNameSelector;
            items = hDropdown.Items(2:end); % Exclude first choice.
            num = find(strcmp(items, hDropdown.Value));
            
            % Note: important to exclude first entry. If no folder was
            % explicitly selected, the value of num should be empty.
            
        end
        
    end

    methods % Show/hide advanced options.
        
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
            hRow.SelectSubstringButton.Position(1) = hRow.SelectSubstringButton.Position(1) + xOffset;

            hRow.SelectSubstringButton.Visible = visibility_;
            hRow.ButtonGroupStrfindMode.Visible = visibility;
            hRow.StrfindInputEditbox.Visible = visibility;
            
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
                        obj.onModelSet()
                    end
                    
                otherwise
                    % No change is necessary
                
            end
            
        end
        

    end
        
    
    methods (Static, Access = private)
        
        function tf = isDateTimeVariable(variableName)
            tf = contains(variableName, {'Date', 'Time'});
        end
        
        function [inFormat, outFormat] = getDateTimeFormat(variableName, strValue)
        %getDateTimeFormat Get datetime input and output format
        
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
        
        function IND = simplifyInd(IND)
        %simplifyInd Simplify the indices, by joining all subsequent using
        %the colon separator, i.e 1 2 3 4 5 -> 1:5
        
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
    end
    
end