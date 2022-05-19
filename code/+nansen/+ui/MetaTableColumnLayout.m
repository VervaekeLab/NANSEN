classdef MetaTableColumnLayout < nansen.mixin.UserSettings
%MetaTableColumnLayout Interface for table column preferences.
%
%   Used for retrieval and editing of column layout preferences for the
%   MetaTableViewer UI.

    
    % TODO:
    %
    % [ ] Rename to ColumnModel...
    % [ ] Test and debug if this works if more metatables are added to
    %     settings. I think I need to work more on the different indexing
    %     methods 
    %     - Do we get the correct values for each table variable from the
    %     settings. Even if variable names are shuffled around in settings?
    %     - Do we set the right values to settings, even when names are
    %       shuffled?
    %     - What if multiple tables are activated/deactivated on the fly?
    %
    % [ ] Add better comments regarding indexing of variables from table to
    %     settings and vice versa
    %
    % [ ] Settings should be saved indiviually based on where the table is used...
    %
    % [ ] Struct should not be a valid column type. Before it was (when the
    % MetaTable property was a nansen.metadata.MetaTable object), but now
    % it should not be. Need to rethink what to do, but I think it is
    % sufficient just to change this value to false, since the parent class
    % already should take care of changing a struct variable to a valid type
    % before it ends up in the MetaTable property.
    
    
    % Ideas for appearance:
    %
    % [ ] Hide gridlines.
    % [ ] Add number dropdowns for column orderering (left to right)
    
    % QUESTIONS:
    % Is metatable the metatable or the data table. If it is the data
    % table, this class does not have to take care of variables that are
    % not renderable... If it is the metatable, this class should do
    % that... Not sure yet...
    
    
    % Need to clean up the table layout
    %
    %   1) One subset of variables from settings are displayed in the settings
    %   editor. Every property and method related to this behavior should
    %   be private to this class.
    %   
    %   2) Another subset of this subset is displayed in the metatable.
    %      The order which this subset is displayed is determined by column
    %      order. This order should be the main IndexList for interacting
    %      with an object of this class.
    %       1) When getting colIndices for table, or values from settings
    %       2) When modifying values from settings...
    %
    %       1) Columns -> setting columns
    %       2) Settings column - column
    %
    
    %   Column order determines which order columns are displayed at.
    %   
    %   ColumnVisible determines if column is part of list to display
    %   
    
    
    
    properties(Constant, Hidden = true)
        USE_DEFAULT_SETTINGS = false
        DEFAULT_SETTINGS = nansen.ui.MetaTableColumnLayout.getDefaultSettings()
        DEFAULT_COLUMN_WIDTH = 100
        
        debug = false
    end
    
    properties (SetAccess = private) %?
        % Question: Is this the MetaTable object or the metatable table???
        MetaTable   % The MetaTable to use for retrieving column layouts.
        MetaTableUi
    end
    
    properties (SetAccess = private)
        
        % Indices to use for retrieval of values from the settings. These
        % should be updated if the MetaTable changes, and if the any of 
        % the values in the ShowColumn settings changes.
        SettingsIndices         % Indices of metatable variable, in the order they appear in the settings.
        MetaTableIndicesAll     % Indices of all metatable variable that are included in settings.
        MetaTableIndicesShow
        
        SortedSettingsInd
        
        OriginalColumnArrangement
    end
    
    properties (Access = private)
        AllTablePropertyNames
        VisibleTablePropertyNames
        SettingsPropertyNames
        
        JColumnModel
        JColumnModelIndices
    end
    
    properties (Access = private, Hidden)
        MetaTableChangedListener
        UIEditorFigure
        UIEditorTable % Table for editing column settings.
    end
    
    
    methods
        
        function obj = MetaTableColumnLayout(hViewer)
            
            %obj@applify.mixin.UserSettings;
            %obj.loadSettings()

            obj.addColumnOrderToSettings() % temporary
            
            % The editable property depends on the metatable and the
            % associated project-dependent variables and should be updated
            % on each instance creation.
            obj.updateColumnEditableState()

            obj.MetaTableUi = hViewer;
            
            % Add listener on metatable property set
            l = addlistener(hViewer, 'MetaTable', 'PostSet', @(s,e) obj.onMetaTableChanged);
            obj.MetaTableChangedListener = l;
            
            if ~isempty(obj.MetaTableUi.MetaTable)
                obj.onMetaTableChanged()
            end
        end
        
        function delete(obj)
            if ~isempty(obj.UIEditorTable)
                uiresume(obj.UIEditorFigure)
                delete(obj.UIEditorFigure)
            end
            
            delete(obj.MetaTableChangedListener)
        end
        
    end
    
    methods %temp
        
        function addColumnOrderToSettings(obj)
            
            if ~isfield(obj.settings, 'ColumnOrder') || obj.debug
                for i = 1:numel(obj.settings)
                    obj.settings_(i).ColumnOrder = i;
                end
            end
        end
        
    end
    
    methods
        
      % % Overide methods from superclass UserSettings
        
        function editSettings(obj)
        %editSettings Override superclass method.
            
            T = getTableDataForUiEditor(obj);
            
            % Open gui for editing column layouts
            obj.openEditorGui(T)
            
            if ~isvalid(obj); return; end
            obj.UIEditorTable = [];
            
            % Uiwait is invoked in openGui, so when figure is closed, the
            % settings will be saved.
            
            % Todo: Fix bug if editor is deleted because app is deleted.
            obj.saveSettings()
        end
        
        function loadSettings(obj)
            % Simplified loading... Todo: This should be modified because
            % table is used in different classes....
            %
            % Override superclass because superclass is not made for struct
            % arrays, and table layout settings is saved in a struct array
            
            if obj.USE_DEFAULT_SETTINGS
                return
            end
            
            % Load settings from file
            loadPath = obj.settingsFilePath;
            
            if exist(loadPath, 'file') % Load settings from file
                
                S = load(loadPath, 'settings');
                obj.settings = S.settings;
                
            else % Initialize settings file using default settings
                obj.settings = obj.DEFAULT_SETTINGS;
                saveSettings(obj)
            end
        end % Why not protected?
        
        function updateColumnEditableState(obj)
        %updateColumnEditableState Update the state of column editable for all variables    
            
            %  Also, need to call this
            % whenever a table variable was edited in sessionbrowser/nansen
            % and when new tables are loaded.
            for i = 1:numel(obj.settings)
                variableName = obj.settings(i).VariableName;
                try
                    tf = obj.checkIfColumnIsEditable(variableName);
                catch
                    tf = false;
                end
                obj.settings_(i).IsEditable = tf;
            end
        end
        
        function colIndices = getColumnIndices(obj)
        %getColumnIndices Get column indices for current metadata table..    
       
        % dont remember what the difference is between 
        % obj.MetaTableIndicesAll & obj.SettingsIndices
            
            indAll = obj.MetaTableIndicesAll;            
            
            indSkip = [obj.settings(indAll).SkipColumn];
            indShow = [obj.settings(indAll).ShowColumn];
            
            indSkip = [obj.settings(obj.SettingsIndices).SkipColumn];
            indShow = [obj.settings(obj.SettingsIndices).ShowColumn];
            
            columnOrder = [obj.settings(obj.SettingsIndices).ColumnOrder];
            columnOrder = columnOrder(indShow & ~indSkip);
            
            [~, sortInd] = sort(columnOrder);
            
            % This yields the column indices 
            colIndices = 1:size(obj.MetaTable, 2);
            colIndices = colIndices(indShow & ~indSkip);
            
            % Reorder table indices
            colIndices = colIndices(sortInd);
            
            %IND = intersect(colIndices, obj.SettingsIndices, )
        end % Table
        
        function currentIndices = getColumnIndicesSettings(obj)
                
            indSkip = [obj.settings(obj.SettingsIndices).SkipColumn];
            indShow = [obj.settings(obj.SettingsIndices).ShowColumn];
            
            columnOrder = [obj.settings(obj.SettingsIndices).ColumnOrder];
            columnOrder = columnOrder(indShow & ~indSkip);
            
            [~, sortInd] = sort(columnOrder);
            
            currentIndices = obj.SettingsIndices(indShow & ~indSkip);
            
            % Reorder indices according to display order

            currentIndices = currentIndices(sortInd);
        end
            
      % % Methods for getting varibles from settings:
        
        function [colNames, varNames] = getColumnNames(obj)
            IND = obj.getIndicesToShowInMetaTable();
            colNames = {obj.settings(IND).ColumnLabel};            
            
            % Why this? 
% %             [~, indSort] = sort(intersect( obj.SettingsIndices, IND, 'stable'));
% %             colNames(indSort) = colNames;
            
            varNames = {obj.settings(IND).VariableName};
% %             varNames(indSort) = varNames;
            
            colOrder = [obj.settings(IND).ColumnOrder];
            [~, indSort] = sort(colOrder);
            colNames = colNames(indSort);
            varNames = varNames(indSort);

            
            if nargout == 1
                clear varNames
            end
        end
        
        function isEditable = getColumnIsEditable(obj)
            
            IND = obj.getIndicesToShowInMetaTable();
            
            isEditable = [obj.settings(IND).IsEditable];
            
%             [~, indSort] = sort(intersect( obj.SettingsIndices, IND, 'stable'));
%             isEditable(indSort) = isEditable;
                        
            % Adjust widths according to the column order
            colOrder = [obj.settings(IND).ColumnOrder];
            [~, indSort] = sort(colOrder);
            isEditable = isEditable(indSort);
        end
        % Todo: Set method for whether columns are editable..
        
        function colWidths = getColumnWidths(obj)
            IND = obj.getIndicesToShowInMetaTable();
            colWidths = [obj.settings(IND).ColumnWidth];
            
            % Make sure output is a row vector
            if iscolumn(colWidths)
                colWidths = transpose(colWidths);
            end
            
% %             [~, indSort] = sort(intersect( obj.SettingsIndices, IND, 'stable'));
% %             colWidths(indSort) = colWidths;
            
            % Adjust widths according to the column order
            colOrder = [obj.settings(IND).ColumnOrder];
            [~, indSort] = sort(colOrder);
            colWidths = colWidths(indSort);

            % Question: Do I need to return as cell array?
        end
        
        function setColumnWidths(obj, columnWidths)
        %setColumnWidths Set column width of current metatable columns.
        
            % Todo: Maybe IND should be given in input...
            IND = obj.getIndicesToShowInMetaTable();
            
            msg = 'Something went wrong. Please send bug report';
            assert(numel(IND) == numel(columnWidths), msg)
            
            visibleColumnOrder = [obj.settings(IND).ColumnOrder];
            
            % Todo: debug with complex tables!!! % Do this to make sure the
            % value is inserted at the right point in settings.
            %[~, ~, iB] = intersect( obj.SettingsIndices, visibleColumnOrder, 'stable');

            [~, iB] = sort(visibleColumnOrder);
            
            for i = 1:numel(IND)
                obj.settings_(IND(iB(i))).ColumnWidth = columnWidths(i);
            end
            
            
            obj.updateUiTableEditor()
            obj.saveSettings()
        end
        
        function hideColumn(obj, columnIdx)
            %IND = obj.getIndicesToShowInMetaTable();
            %columnIdxSetting = IND(columnIdx);            
              
            colInd = obj.getColumnIndicesSettings;
            columnIdxSetting = colInd(columnIdx);
            
            % Todo: what if columns are rearranged

            obj.settings_(columnIdxSetting).ShowColumn = false;
            
            if ~isempty(obj.UIEditorTable)
                % If the ui editor table is open, need to update the table
                % values.
                T = getTableDataForUiEditor(obj);
                obj.UIEditorTable.Data = table2cell(T);
            end
            
            
            % Todo: Update table view (remove columns).
            obj.MetaTableUi.refreshTable([], true)
            obj.updateUiTableEditor()
        end
        
        function setNewColumnOrder(obj, newColumnArrangement)
        %setNewColumnOrder 
        %
        
        %   Note: This methods should be used to update settings when the
        %   columns have already been rearranged. 
        %
        %   This is currently the only behavior, but an idea is to be able
        %   to change these values for the column settings editor, and in
        %   this case we need to also to the actual rearranging of columns
        
            % newColumnOrder is a cellarray of column names in the order 
            % they appear in the table   
            
            % Indices of variables in settings that are currently visible
            % in the metatable.
            IND = getIndicesToShowInMetaTable(obj);
            
            % Get the names of the visible variables and their order in the
            % settings.
            visibleNames = {obj.settings(IND).ColumnLabel};
            visibleOrder = [obj.settings(IND).ColumnOrder];
            
            % Get the current arrangement of columns
            currentInd = 1:numel(visibleNames);
            [~, sortInd] = sort(visibleOrder);
            currentInd = currentInd(sortInd);
            
            currentColumnArrangement = visibleNames(currentInd);
            
            % Get indices (iC) describing how the newColumnArrangement is
            % relative to the arrangement in settings.
            [~, ~, iC] = intersect(currentColumnArrangement, newColumnArrangement, 'stable');
            
            % Find indices which changed:
            try
                hasChanged = iC' ~= 1:numel(visibleNames);
            catch ME
                disp(ME.message)
            end
            
            rearrangedColumns = iC(hasChanged);
            rearrangedColumnsSettingsInd = IND( currentInd(rearrangedColumns) );
            
            newOrder = [obj.settings(rearrangedColumnsSettingsInd).ColumnOrder];
            
            currentColumnsSettingsInd = IND(currentInd(hasChanged));
            
            for count = 1:numel(currentColumnsSettingsInd)
                thisInd = currentColumnsSettingsInd(count);
                obj.settings_(thisInd).ColumnOrder = newOrder(count);
            end
                    
            obj.updateUiTableEditor()
        end
        
        function updateJavaColumnModel(obj)
            
            if isempty(obj.JColumnModel)
                obj.JColumnModel = obj.MetaTableUi.HTable.JTable.getTableHeader.getColumnModel;
            end
            
            numColumns = get(obj.JColumnModel, 'ColumnCount');
            % Rearrange the column model index...
            for i = 1:numColumns
                jColumn = obj.JColumnModel.getColumn(i-1);
                jColumn.setModelIndex(i-1)
            end
            
            obj.JColumnModelIndices = 1:numColumns;
        end
        
        function idx = getColumnIdx(obj, idx)
            
            numColumns = get(obj.JColumnModel, 'ColumnCount');
            for i = 1:numColumns
                jColumn = obj.JColumnModel.getColumn(i-1);
                colIdx = jColumn.getModelIndex();
                if colIdx+1 == idx
                    idx = i;
                    return
                end
            end
        end
        
        function [colIndex, colNames] = getColumnModelIndexOrder(obj)
            
            numColumns = get(obj.JColumnModel, 'ColumnCount');
            colIndex = zeros(1, numColumns);
            colNames = cell(1, numColumns);
            for i = 1:numColumns
                jColumn = obj.JColumnModel.getColumn(i-1);
                colIndex(i) = jColumn.getModelIndex()+1;
                colNames{i} = jColumn.getHeaderValue();
            end
            
            if nargout == 1
                clear colNames
            end
        end
        
    end
    
    methods (Access = private) % Create gui for editing settings
        
        function IND = getIndicesToShowInLayoutEditor(obj)
        %getIndicesToShowInLayoutEditor For indexing the settings struct 
        
            % Indices of those variables in settings that are present in
            % current metatable.
            indA = obj.MetaTableIndicesAll;
            
            % Indices of those varibles that are not displayable
            indB = find( [obj.settings.SkipColumn] );
            
            % Indices of variables in current metatable that are displayable
            IND = setdiff(indA, indB, 'stable'); % I.e keep those in A that are not in B
        end
        
        function T = getTableDataForUiEditor(obj)
            
            % Get column layout settings as a table.
            T = struct2table(obj.settings);
        
            % Get indices of variables in current metatable that are
            % displayable:
            IND = obj.getIndicesToShowInLayoutEditor();
            
            % Get subset of table to display in column layout editor.
            T = T(IND, [1,2,3,5,7]); % 4th + 6th column is not editable.
        end
        
        function openEditorGui(obj, T)
            
            % Create figure
            tmpF = figure('Visible', 'off');
            tmpF.NumberTitle = 'off';
            tmpF.Name = 'Edit Column Layout';
            tmpF.MenuBar = 'none';
            tmpF.Resize = 'off';
            
            % Create table
            tmpTable = uitable('Parent', tmpF);
            tmpTable.FontSize = 12;
            tmpTable.FontName = 'Avenir New';
            tmpTable.ColumnWidth = {150, 150, 100, 100};
            tmpTable.Data = table2cell(T);
            tmpTable.ColumnName = T.Properties.VariableNames;
            tmpTable.ColumnEditable = [false true true true];
            tmpTable.Position = tmpTable.Extent;
            tmpTable.CellEditCallback = @obj.onSettingsChanged;
            
            obj.UIEditorFigure = tmpF;
            obj.UIEditorTable = tmpTable;
            
            % Set figure position same as figure extent and make visible
            tmpF.Position(3:4) = tmpTable.Extent(3:4);
            tmpF.Visible = 'on';

            % Todo: Make sure figure is not taller than the screen size.
            
            % Wait for figure...
            uiwait(tmpF)
        end

        function updateUiTableEditor(obj)
            
            if ~isempty(obj.UIEditorTable)
                T = getTableDataForUiEditor(obj);
                obj.UIEditorTable.Data = table2cell(T);
            end
        end
        
    end
    
    methods % Set/get
%         function set.MetaTable(obj, newTable)
%             % msg = 'This is not a valid meta table';
%             % assert(isa(newTable, 'nansen.metadata.MetaTable'), msg)
%             obj.MetaTable = newTable;
%             obj.onMetaTableChanged()
%         end
%         
    end
    
    methods (Access = protected)
                
        function checkAndUpdateColumnEntries(obj)
        %checkAndUpdateColumnEntries Check if new variables are present in
        % the metatable that are missing from the settings.
        
            % Variable names that are already in settings.
            if isempty(obj.settings)
                varNamesA = '';
            else
                varNamesA = {obj.settings.VariableName}; 
            end
            
            % Variable names that are in the current metatable.
            varNamesB = obj.MetaTable.Properties.VariableNames;
            
            % Check if any variable names from the MetaTable are missing 
            % from the settings file (if a new table definition is loaded)
            varNamesC = setdiff(varNamesB, varNamesA, 'stable');
            
            % If not, we can return
            if isempty(varNamesC);    return;    end
            
            
            % Need to get a table row to test data types of variables
            tableRow = table2struct(obj.MetaTable(1,:));

            % Otherwise, we add all the new variables to the settings and
            % use default values for the different settings options.
            numOldEntries = numel(obj.settings);
            
            for i = 1:numel(varNamesC)
                
                iVarName = varNamesC{i};
                
                % Get data type of this variable and check if it is valid
                dataValue = tableRow.(iVarName);          % Todo: Check if this works if dataValue is cell array....
                isValidDatatype = obj.checkIfColumnDataIsValid(dataValue);
                isEditable = obj.checkIfColumnIsEditable(iVarName);
                
                iColumn = numOldEntries + i;
                obj.settings_(iColumn).VariableName = iVarName;
                obj.settings_(iColumn).ColumnLabel = iVarName;
                obj.settings_(iColumn).ShowColumn = true;
                obj.settings_(iColumn).SkipColumn = ~isValidDatatype;
                obj.settings_(iColumn).ColumnWidth = obj.DEFAULT_COLUMN_WIDTH;
                obj.settings_(iColumn).IsEditable = isEditable;
                obj.settings_(iColumn).ColumnOrder = iColumn;
            end
            
            obj.saveSettings()

        end
        
        function onSettingsSet(obj, newSettings)
        %onSettingsSet Update value of settings when property value is set
        
        % Override superclass methods. In contrast to the superclass
        % this subclass does not have to invoke the onSettingsChanged when
        % settings are set...
            obj.settings_ = newSettings;
        end
        
        function onSettingsChanged(obj, src, event)
        %onSettingsChanged Callback for when settings are changed. 
        %
        %   Note: This method has a slightly different implementation than
        %   the definition from the superclass. This is because
        %   editSettings opens settings in a table view instead of a
        %   structeditor.
        
            
            % Get those indices of the settings struct array that are 
            % currently shown in the column-layout table editor.
            IND = obj.getIndicesToShowInLayoutEditor();
            
            rowNum = event.Indices(1); % Row number of edited cell
            colNum = event.Indices(2); % Col number of edited cell
            
            % Index of entry in the settings struct that was changed.
            iChanged = IND(rowNum);
            
            switch src.ColumnName{colNum}
                
                case 'ColumnLabel'
                    obj.settings(iChanged).ColumnLabel = event.NewData;
                    
                    % Update column names in the meta table ui
                    newNames = obj.getColumnNames();
                    obj.MetaTableUi.changeColumnNames(newNames);
                    
                case 'ShowColumn'
                    obj.settings(iChanged).ShowColumn = event.NewData;
                    %Todo: Use java column model for this
                    % Todo: Update table view (remove columns).
                    obj.MetaTableUi.refreshTable([], true)
                    
                case 'ColumnWidth'
                    obj.settings(iChanged).ColumnWidth = event.NewData;
                    
                    % Update column widths in the meta table ui
                    newWidths = obj.getColumnWidths();
                    obj.MetaTableUi.changeColumnWidths(newWidths);
                    
            end
            
        end
        
        function onMetaTableChanged(obj)
            
            obj.MetaTable = obj.MetaTableUi.MetaTable; %Todo: Change to TableVariables 

            obj.checkAndUpdateColumnEntries()
            
            % Todo: Update Indices based on what variables are present in
            % the metatable.
            
            varNamesSettings = {obj.settings.VariableName}; % VarNames already in settings.
            varNamesTable = obj.MetaTable.Properties.VariableNames;
            
            % Get indices of names in settings that are also in table
            [~, iA] = intersect(varNamesSettings, varNamesTable, 'stable');
            obj.MetaTableIndicesAll = iA;
            %obj.SettingsVarTableIdx = iA;
            
            % Do I need this?
            [~, ~, iC] = intersect(varNamesTable, varNamesSettings, 'stable');
            obj.SettingsIndices = iC;
            
            columnOrder = [obj.settings(obj.SettingsIndices).ColumnOrder];
            [~, sortedOrder] = sort(columnOrder);
            obj.SortedSettingsInd = obj.SettingsIndices(sortedOrder);
            
            %obj.TableVarSettingsIdx = iC;
            
            % Set order of data
            obj.OriginalColumnArrangement = obj.MetaTable.Properties.VariableNames;

        end
        
        function IND = getIndicesToShowInMetaTable(obj)
        %getIndicesToShowInMetaTable For indexing the settings struct
        
            % Indices of those variables in settings that should be 
            % displayed from the current metatable.
            indA = obj.getIndicesToShowInLayoutEditor();
            indB = find( [obj.settings.ShowColumn] );
            
            IND = intersect(indA, indB);
            
            if ~isrow(IND); IND = transpose(IND); end
        end
        
        function IND = getRearrangedColumnIndices(obj)
            
            IND = obj.getIndicesToShowInMetaTable();            
        end

    end
    
    methods (Static)
        function S = getDefaultSettings()
            
            S = struct(...
                'VariableName', {}, ...   % Metadata variable name
                'ColumnLabel', {}, ...    % What name to display in column header
                'ShowColumn', [], ...     % Show or hide column in table viewer ui
                'SkipColumn', [], ...     % Skip column when displaying table data (if data is not renderable, i.e matlab arrays, etc)
                'ColumnWidth', {}, ...    % What width to assign column
                'IsEditable', logical.empty ); % Is column editable
            %'ColumnNumber', []
                %
                
            % Todo: Add a way to change order or columns...
            
        end
        
        function S = getSettings()
            S = getSettings@nansen.mixin.UserSettings('nansen.ui.MetaTableColumnLayout');
        end
        
        function tf = checkIfColumnDataIsValid(value)
        %checkIfColumnDataIsValid Check if data type is valid for display    
        %
        % Valid data types are numerics, logicals, character vectors and
        % structs. Numeric or logical arrays are not valid.
        %
        %   Todo: include date (and time)
        
            if isa(value, 'numeric') && numel(value) <= 1
                tf = true;
            elseif isa(value, 'logical') && numel(value) <= 1
                tf = true;
            elseif isa(value, 'char')
                tf = true;
            elseif isa(value, 'struct') % TODO.
                tf = true;
            elseif isa(value, 'datetime') % TODO.
                tf = true;
            else
                tf = false;
            end
            
        end
        
        function tf = checkIfColumnIsEditable(variableName)
            
            % Todo: Check pre-programmed variables as well..
            
            import nansen.metadata.utility.getCustomTableVariableNames
            import nansen.metadata.utility.getCustomTableVariableFcn
            
            tf = false;
            
            customVarNames = getCustomTableVariableNames();
            
            if ~contains(variableName, customVarNames)
                return
            end
            
            thisFcn = getCustomTableVariableFcn(variableName);
            fcnValue = thisFcn();

            if isa(fcnValue, 'nansen.metadata.abstract.TableVariable')
                tf = fcnValue.IS_EDITABLE;
            end
            
        end
    end
    
end