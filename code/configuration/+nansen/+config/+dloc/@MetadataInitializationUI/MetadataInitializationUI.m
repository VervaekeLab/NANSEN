classdef MetadataInitializationUI < applify.apptable & nansen.config.mixin.HasDataLocationModel
% Class interface for editing metadata specifications in a uifigure

% Todo: Simplify component creation. 
%    [ ] Get cell locations as array with one entry for each column of a row.
%    [ ] Do the centering when getting the cell locations.
%    [ ] Set fontsize/bg color and other properties in batch.
%
%    [ ] Include "data model" as property and update values whenever new values
%        are entered.
    

    properties
        
        IsDirty = false;
        
        % Need Datalocations handle, make a default?
        DataLocations = struct('Name', {'Rawdata', 'Processed', '', ''}, ...
            'RootPath', {{'HDD', ''}, {'HDD', ''}, {'', ''}, {'', ''}}, ...
            'Backup', {[], [], [], []});
        
        IsAdvancedView = true
    end
    
    properties (Access = protected)
        StringFormat = cell(1, 4);
    end
    
    properties % Toolbar
        AdvancedOptionsButton 
    end
    
    
    methods % Structors
        function obj = MetadataInitializationUI(dataLocationModel, varargin)
        %FolderOrganizationUI Construct a FolderOrganizationUI instance
            
            obj@nansen.config.mixin.HasDataLocationModel(dataLocationModel)
            
            % Todo: Make it possible to select which datalocation to use..
            varargin = [varargin, {'Data', dataLocationModel.Data(1).MetaDataDef}];

            obj@applify.apptable(varargin{:})
                        
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
            
            rootPath =  mfilename('fullpath') ;
            imgPath = fullfile(rootPath, '_graphics');
            
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

            hRow.FolderSelector = uidropdown(obj.TablePanel);
            hRow.FolderSelector.BackgroundColor = [1 1 1];
            hRow.FolderSelector.Position = [xi y wi h];
            hRow.FolderSelector.FontName = obj.FontName;
            hRow.FolderSelector.ValueChangedFcn = @obj.onFolderSelectionChanged;
            obj.centerComponent(hRow.FolderSelector, y)

            % Todo: Get folders from DataLocation.
            hRow.FolderSelector.Items = {'Select foldername...'};
            hRow.FolderSelector.Value = 'Select foldername...';
            
        % % Create Togglebutton group for selecting string detection mode
            i = 3;
            [xi, y, wi, h] = obj.getCellPosition(rowNum, i);

            % Insert dialog button 
            hRow.ColumnLabelHelpButton = uibutton(obj.TablePanel);
            hRow.ColumnLabelHelpButton.Position = [xi, y, wi, h];
            hRow.ColumnLabelHelpButton.Text = 'Select Substring...';
            hRow.ColumnLabelHelpButton.ButtonPushedFcn = @obj.onSelectLetterClicked;
            obj.centerComponent(hRow.ColumnLabelHelpButton, y)
            
            
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
        
    end
    
    methods % Methods for updating
        
        function onModelSet(obj)
        %onModelSet Callback for when DatalocationModel is set/reset
        %
        %   % Update control values based on the DataLocationModel
        
            % Update Items and Value of subfolder dropdown
            obj.setFolderSelectionItems(obj.DataLocationModel)
            
            % Update value in string detection input
            
            % Update results
            for i = 1:obj.NumRows
                hComp = obj.RowControls(i).StrfindInputEditbox;
                obj.onStringInputValueChanged(hComp)
                
                % Set stringformat from datalocation model.
                obj.StringFormat{i} = obj.DataLocationModel.Data(1).MetaDataDef(i).StringFormat;
            end
            
        end
        
        function onFolderSelectionChanged(obj, src, ~)
            src.Tooltip = src.Value;
        end
        
        function onSelectLetterClicked(obj, src, evt)
        %
        %   
        %   Open a dialog window for selecting letter positions.
        
            rowNumber = obj.getComponentRowNumber(src);
            hRow = obj.RowControls(rowNumber);
            folderName = hRow.FolderSelector.Value;
           
            hFig = ancestor(src, 'figure');
         
            IND = uim.dialog.createStringSelectorDialog(folderName, hFig.Position);
            
            if isempty(IND)
                pause(0.1)
                figure(hFig)
                return
            else
                
                substring = folderName(IND);
                %hRow.StrfindInputEditbox.Value = num2str(IND);
                hRow.StrfindInputEditbox.Value = obj.simplifyInd(IND);
                
                hRow.StrfindResultEditbox.Value = substring;
                hRow.StrfindResultEditbox.Tooltip = substring;
            
                
                % Get datetime values for date & time variables.
                if strcmp(hRow.VariableName.Text, 'Experiment Date')
                    dlgTitle = 'Enter Date Format';
                    msg = sprintf('Please enter date format, i.e yyyy-MM-dd\n');
                    datetimeFormat = 'MMM-dd-yyyy';
                elseif strcmp(hRow.VariableName.Text, 'Experiment Time')
                    dlgTitle = 'Enter Time Format';
                    msg = sprintf('Please enter time format, i.e HH-mm-ss\n');
                    datetimeFormat = 'HH:mm:ss';
                end
                
                if obj.isDateTimeVariable(hRow.VariableName.Text)
                    
                    shortName = strrep(hRow.VariableName.Text, 'Experiment', '');
                    
                    msg = strjoin({msg, '(See doc datetime for full list of examples).'});
                    str = inputdlg(msg, dlgTitle);
                    
                    if ~isempty(str) && ~isempty(str{1})
                        str = str{1};
                    
                        try
                            datetimeValue = datetime(substring, 'InputFormat', str);
                            datetimeValue.Format = datetimeFormat;
                            hRow.StrfindResultEditbox.Value = char(datetimeValue);  
                            obj.StringFormat{rowNumber} = str;
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
            
            % Bring uifigure back into focus
            figure(hFig)
            
        end
        
        function onStringInputValueChanged(obj, src, event)
            
            M = obj.DataLocationModel.Data(1).MetaDataDef;
            
            rowNumber = obj.getComponentRowNumber(src);
            mode = obj.getStrSearchMode(rowNumber);
            
            hRow = obj.RowControls(rowNumber);
            
            strPattern = obj.getStrSearchPattern(rowNumber, mode);
            
            folderName = hRow.FolderSelector.Value;

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
                
                examplePath = obj.DataLocationModel.Data(1).ExamplePath;
                
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
        
        function setFolderSelectionItems(obj, dataLocModel)
           
            % TODO: Fix error that will occur if several subfolders are
            % given the same subfolder type?
            
            
            % Get all the folder selector controls
            h = [obj.RowControls.FolderSelector];
            
            % Get the folder choice examples from the data location model
            subFolderStructure = dataLocModel.Data(1).SubfolderStructure;
            folderChoices = ['Select foldername...', {subFolderStructure.Name}];
            
            M = dataLocModel.Data(1).MetaDataDef;
            
            %oldValues = arrayfun(@(i) find(strcmp(h(i).Items, h(i).Value)), 1:numel(h));
            
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
        
        function S = getMetaDataDefinitionStruct(obj)
            
            S = obj.DataLocationModel.getDefaultMetadataStructure();
                        
            for i = 1:obj.NumRows
                S(i).StringDetectMode = obj.getStrSearchMode(i);
                S(i).StringDetectInput = obj.getStrSearchPattern(i);
                S(i).SubfolderLevel = obj.getSubfolderLevel(i);
                S(i).StringFormat = obj.StringFormat{i};
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
            
            hDropdown = obj.RowControls(rowNumber).FolderSelector;
            items = hDropdown.Items(2:end); % Exclude first choice.
            num = find(contains(items, hDropdown.Value));
            
            % Note: important to exclude first entry. If no folder was
            % explicitly selected, the value of num should be empty.
            
        end
        
    end
    
    
    
    methods % Show/hide advanced options.
        
        function createAdvancedOptionsButton(obj, hPanel)
            
            % Assumes obj.Parent has same parent as hPanel given as input
            
            tablePanelPosition = obj.Parent.Position;
            buttonSize = [160, 22];
            
            % Determine where to place button:
            SPACING = [3,3];
            
            location = tablePanelPosition(1:2) + tablePanelPosition(3:4) - [1,0] .* buttonSize + [-1, 1] .* SPACING;
            
            obj.AdvancedOptionsButton = uibutton(hPanel, 'push');
            obj.AdvancedOptionsButton.ButtonPushedFcn = @obj.onShowAdvancedOptionsButtonPushed;
            obj.AdvancedOptionsButton.Position = [location buttonSize];
            obj.AdvancedOptionsButton.Text = 'Show Advanced Options...';

        end
        
        function onShowAdvancedOptionsButtonPushed(obj, src, ~)
           
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
            hRow.FolderSelector.Position(3) = hRow.FolderSelector.Position(3) + xOffset;
            hRow.ColumnLabelHelpButton.Position(1) = hRow.ColumnLabelHelpButton.Position(1) + xOffset;

            hRow.ColumnLabelHelpButton.Visible = visibility_;
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
                    obj.onModelSet()
                    
                otherwise
                    % No change is necessary
                
            end
            
        end
        

    end
        
    
    methods (Static)
        
        function tf = isDateTimeVariable(varName)
            tf = contains(varName, {'Date', 'Time'});
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