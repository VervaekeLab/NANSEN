classdef MetaTable < handle & nansen.metadata.mixin.VersionedFile
% MetaTable Class interface for creating and working with MetaTables
%
%   MetaTables can be either master or dummy MetaTables. A master
%   MetaTable contains all the actual data entries whereas a dummy
%   MetaTable contains pointers to entries of a master MetaTable.
%
%   A dummy MetaTable can typically contain a subset of members from the
%   master MetaTable, but updates to entries in a dummy will update the
%   data in the master MetaTable.
%
%   Therefore, it also follows that if changes are made either on the
%   master MetaTable or another dummy MetaTable, those changes will be
%   available on all MetaTables linked to that master.
%
%   MetaTable is a handle class — all references to the same instance
%   share state. Data is additionally persisted to disk via VersionedFile.

    properties (SetAccess=private, SetObservable)
        IsModified = false;
    end
    
    properties (SetAccess = private)

        IsMaster = true

        MetaTableKey = '';
        MetaTableName = '';

        % MetaTableMembers - cell array of character vectors representing
        % unique identifiers for all entries of the table
        MetaTableMembers = {} % Todo: enforce cell of char

        % MetaTableVariables - List of table variables. Tracks which variables
        % were present at last synchronization. Used by
        % Project.synchronizeMetaTableVariables to detect new or removed
        % variables on first-time initialization of a metatable.
        MetaTableVariables (:,1) string
    end

    % MetaObject caching properties
    properties (Access = private)
        MetaObjectCache = []  % Cache of metadata objects | Todo: Make this a dictionary/containers.Map
        MetaObjectCacheMembers = {}  % IDs for cached metadata objects % Todo: enforce cell of char
    end

    properties (SetAccess = private)
        ItemClassName = '';
        MetaTableClass = '';
        MetaTableIdVarname = '';
    end

    properties (Dependent)
        VariableNames
    end
    
    % Public properties to access MetaTable contents
    properties (SetAccess = protected)

        members             % IDs for MetaTable entries
        entries table       % MetaTable entries
    end

    properties (Dependent = true, Hidden = true)
        SchemaIdName % The property name for id of a schema/object of this table
    end
    
    properties (Constant, Access = private) % Variable names for export
        
        % These are variables that will be saved to a MetaTable mat file.
        FILEVARS = struct(  'MetaTableMembers', {{}}, ...
                            'MetaTableEntries', {{}}, ...
                            'MetaTableVariables', {{}});
        
        % These are variables that will be saved to the MetaTableCatalog.
        CATALOG_VARIABLES = struct( ...
            'IsMaster', false, ...
            'MetaTableName', '', ...
            'MetaTableClass', '', ...
            'ItemClassName', '', ...    % Which specific class to use to create instances
            'MetaTableIdVarname', '', ...
            'MetaTableKey', '', ...
            'FileName', '', ...
            'IsDefault', false ...
            );
    end

    events
        TableEntryChanged
        EntryAdded
        EntryRemoved
        TableReloadedFromDisk
    end

    methods % Structor
        
        function obj = MetaTable(metadata, propValues)
            arguments
                metadata table = table.empty
                propValues.MetaTableClass
                propValues.ItemClassName
                propValues.MetaTableIdVarname
            end
            
            if ~isempty(metadata)
                obj.entries = metadata;
            end

            propFields = fieldnames(propValues);
            for i = 1:numel(propFields)
                obj.(propFields{i}) = propValues.(propFields{i});
            end
        end
    end
    
    methods

        function tf = hasSameMasterKey(obj, otherMetaTable)
        %hasSameMasterKey Check if two MetaTables share the same master key
            tf = strcmp(obj.MetaTableKey, otherMetaTable.MetaTableKey);
        end

        function tf = isClean(obj)
           tf = ~obj.IsModified;
        end

        function markClean(obj)
            obj.IsModified = false;
        end
        
        function schemaIdName = get.SchemaIdName(obj)
        %GET.SCHEMAIDNAME Get the propertyname of the ID of current schema
            if ~isempty(obj.MetaTableIdVarname)
                schemaIdName = obj.MetaTableIdVarname;
            else
                try
                    schemaIdName = eval(strjoin({obj.MetaTableClass, 'IDNAME'}, '.'));
                catch
                    schemaIdName = 'id';
                end
            end
        end

        function variableNames = get.VariableNames(obj)
            variableNames = obj.entries.Properties.VariableNames;
        end
        
        function members = get.members(obj)
            members = obj.MetaTableMembers;
        end
         
        function set.entries(obj, value)
            obj.entries = value;
            obj.onEntriesChanged()
        end

        function set.MetaTableIdVarname(obj, value)
            obj.MetaTableIdVarname = value;
            obj.postSetMetaTableIdVarname()
        end

        function postSetMetaTableIdVarname(obj)
            if ~isempty(obj.entries)
                obj.MetaTableMembers = obj.entries.(obj.SchemaIdName);
            end
        end

        function typeName = getTableType(obj)
            typeName = utility.string.getSimpleClassName(obj.MetaTableClass);
        end
          
        function setMetaTableVariables(obj, variableNames)
        %setMetaTableVariables Set the MetaTableVariables property
        %
        %   Used by external callers (e.g. Project.synchronizeMetaTableVariables)
        %   to update the list of known table variables after synchronization.
            obj.MetaTableVariables = variableNames;
        end

        function variableName = getVariableName(obj, colIndex)
            variableName = obj.entries.Properties.VariableNames{colIndex};
        end

        function setAsMaster(obj)
        %setAsMaster Set this MetaTable as a master MetaTable
            obj.IsMaster = true;
        end

        function setAsDummy(obj)
        %setAsDummy Set this MetaTable as a dummy MetaTable linked to a master
        %
        %   Sets IsMaster to false. The MetaTableKey must be assigned
        %   separately to link this table to its master.
            obj.IsMaster = false;
        end

        function name = createDefaultName(obj)
        %createDefaultName Set a default name for the metatable.

            schemaName = obj.MetaTableClass;
            schemaNameSplit = strsplit(schemaName, '.');
            metaTableName = schemaNameSplit{end};
            
            if nargout
                name = metaTableName;
            else
                obj.MetaTableName = metaTableName;
            end
        end
        
% % % %  Methods for saving/loading MetaTable from/to file

        % Load contents of MetaTable file
        % Todo: Check if file is present in MetaTable Catalog
        
        function wasSaved = save(obj, force)
        %save Save MetaTable to file
        %
        %   Note: MetaTables are not saved directly as class instances,
        %   instead the entries are saved as a table and the entry ids
        %   (members) are saved as a cell array. This way, the MetaTables
        %   can be read even if the MetaTable class is not on Matlabs path.

            if nargin < 2; force = false; end

            if isempty(obj.filepath)
                error('NANSEN:MetaTable:NoFilepath', ...
                    ['Cannot save: filepath is not set. ', ...
                     'Use MetaTableCatalog.registerMetaTable() to register ', ...
                     'a new MetaTable before saving.'])
            end

            wasSaved = save@nansen.metadata.mixin.VersionedFile(obj, force);
            if wasSaved
                fprintf('MetaTable saved to %s\n', obj.filepath)
            end

            if ~nargout; clear wasSaved; end
        end

        function load(obj)
        %load Load a MetaTable from file
        %
        %   Delegates to VersionedFile.load(). MetaTable-specific validation
        %   (checking for MetaTableClass field) happens in fromFileStruct().
            load@nansen.metadata.mixin.VersionedFile(obj);
        end
        
        function S = toStruct(obj, source)
        %toStruct Add property values from class to struct for saving.
        %
        %   This function can create a struct for saving either to
        %   MetaTable Catalog or to MetaTable file. This is specified
        %   in optional input.
        %
        % Input:
        %   Source (char) : 'metatable_catalog' | 'metatable_file' (default)
        
            if nargin < 2
                source = 'metatable_file';
            end
        
            switch source
                case 'metatable_catalog'
                    S = obj.CATALOG_VARIABLES;
                    
                case 'metatable_file'
                    S = obj.FILEVARS;
                    f = fieldnames(obj.CATALOG_VARIABLES);
                    
                    % Append CATALOG_VARIABLES to FILEVARS
                    for i = 1:length(f)
                        S.(f{i}) = obj.CATALOG_VARIABLES.(f{i});
                    end
            end
            
            varNames = fieldnames(S);

            for i = 1:numel(varNames)
                switch varNames{i}
                    
                    case 'MetaTableClass'
                        S.MetaTableClass = obj.MetaTableClass;
                    
                    case 'MetaTableEntries'
                        S.MetaTableEntries = obj.entries;
                        
                    case 'FileName'
                        [~, S.FileName] = fileparts(obj.filepath);
                        S.FileName = strcat(S.FileName, '.mat');
                        
                    case 'IsDefault'
                        % This is not a property of MetaTable object
                        
                    otherwise
                        S.(varNames{i}) = obj.(varNames{i});
                end
            end
        end
        
        function fromStruct(obj, S)
        %fromStruct Reverse of toStruct function

            varNames = fieldnames(S);

            for i = 1:numel(varNames)
                switch varNames{i}
                    case {'SavePath', 'FileName', 'IsDefault'}
                        % These are also not assigned
                    case 'MetaTableEntries'
                        obj.entries = S.MetaTableEntries;
                    otherwise
                        obj.(varNames{i}) = S.(varNames{i});
                end
            end
        end

        function columnIndex = getColumnIndex(obj, columnName)
        %getColumnIndex Get column index for given column name
            isMatch = strcmp(obj.entries.Properties.VariableNames, columnName);
            if any(isMatch)
                columnIndex = find(isMatch);
            else
                error('NANSEN:MetaTable:ColumnNotFound', ...
                    'Column with name "%s" does not exist in table', columnName)
            end
        end

        function T = getFormattedTableData(obj, columnIndices, rowIndices, displayContext)
        %getFormattedTableData Format table cells for UI display.
            if nargin < 2 || isempty(columnIndices); columnIndices = 1:size(obj.entries, 2); end
            if nargin < 3 || isempty(rowIndices); rowIndices = 1:size(obj.entries, 1); end
            if nargin < 4; displayContext = 'legacy'; end

            T = nansen.metadata.utility.formatTableForDisplay(...
                obj, columnIndices, rowIndices, displayContext);
        end
        
% % % % Methods for modifying entries

        function tf = isVariable(obj, varName)
            tf = any(strcmp(varName, obj.entries.Properties.VariableNames));
        end

        function addTableVariable(obj, variableName, initValue)
        %addTableVariable Add a variable as a new column of the table
        %
        %   addTableVariable(obj, variableName, initValue) adds a new
        %   variable to the table and initializes all column values to the
        %   initValue.
        %
        %   Note: This method changes the table structure and does not emit
        %   a table-change event. Callers that maintain views should refresh
        %   them after adding variables.

        % Todo: Make method for adding multiple variables in one go, i.e
        % allow "variableName" and "initValue" to be cell arrays.

            if ~obj.IsMaster % Add to master metatable
                catalog = nansen.metadata.MetaTableCatalog();
                masterFilePath = catalog.getMasterFilePath(obj.MetaTableKey);
                masterMT = nansen.metadata.MetaTable.open(masterFilePath);
                masterMT.addTableVariable(variableName, initValue);
                masterMT.save();
            end

            obj.entries = obj.addTableVariableStatic(obj.entries, variableName, initValue);
        end

        function removeTableVariable(obj, variableName)
        %removeTableVariable Remove a variable from the table
        %
        %   Note: This method changes the table structure and does not emit
        %   a table-change event. Callers that maintain views should refresh
        %   them after removing variables.

            obj.entries(:, variableName) = [];
        end

        function addTable(obj, T, options)
        %addTable Add table rows to the MetaTable
        %
        %   addTable(obj, T) adds rows from a table directly to the
        %   MetaTable. If the table is missing ID values, UUIDs will be
        %   generated automatically. This is useful for importing data
        %   from external sources or merging MetaTables.
        
            % Set MetaTable class if this is the first time entries are added

            arguments
                obj (1,1) nansen.metadata.MetaTable
                T (:,:) table
                options.AutoUpdateValues (1,1) logical = true
            end

            if isempty(obj.MetaTableMembers)
                if isempty(obj.MetaTableClass) % Don't override if already set
                    obj.MetaTableClass = 'table';
                end
            end

            idName = obj.SchemaIdName;

            % Check if table has ID column, generate UUIDs if missing
            if any(strcmp(T.Properties.VariableNames, idName))
                % IDs exist, no action needed
            else
                % Generate UUIDs for all rows
                newEntryIds = arrayfun(@(i) nansen.util.getuuid, 1:height(T), 'uni', 0);
                T.(idName) = newEntryIds';
            end
            
            % Use common append logic
            obj.appendTableRows(T, "AutoUpdateValues", options.AutoUpdateValues);
        end

        % Add entry/entries to MetaTable table
        function addEntries(obj, newEntries, options)
        %addEntries Add schema object entries to the MetaTable
        %
        %   addEntries(obj, newEntries) adds one or more schema objects
        %   to the MetaTable. The schema objects are validated to ensure
        %   they inherit from MetadataEntity and match the MetaTable's class,
        %   then converted to a table and appended.
        
            % Make sure entries are based on the MetadataEntity class.

            arguments
                obj (1,1) nansen.metadata.MetaTable
                newEntries
                options.AutoUpdateValues (1,1) logical = true
            end

            isValid = isa(newEntries, 'nansen.metadata.abstract.MetadataEntity');
            message = 'MetaTable entries must inherit from the MetadataEntity class';

            assert(isValid, message)
            
            % If this is the first time entries are added, set the
            % MetaTable class property. Otherwise, validate class match.
            if isempty(obj.MetaTableMembers)
                if isempty(obj.MetaTableClass) % Don't override if already set
                    obj.MetaTableClass = class(newEntries);
                end
            else
                msg = sprintf(['Class of entries (%s) do not match ', ...
                    'the class of the MetaTable (%s)'], class(newEntries), ...
                    obj.MetaTableClass);
                assert(isa(newEntries, obj.MetaTableClass), msg)
            end

            % Convert schema objects to a table
            newTableRows = newEntries.makeTable();
            
            % Use common append logic
            obj.appendTableRows(newTableRows, "AutoUpdateValues", options.AutoUpdateValues);
        end

        function entries = getEntry(obj, listOfEntryIds)
        %getEntry Get entry/entries from the entry IDs.
            listOfEntryIds = obj.normalizeIdentifier(listOfEntryIds);
            [~, IND, ~] = intersect(obj.members, listOfEntryIds);
            entries = obj.entries(IND, :);
        end

        function entryIndex = getIndexById(obj, objectId)
            idName = obj.SchemaIdName;
            allIds = obj.entries.(idName);

            entryIndex = find( strcmp(allIds, objectId) );
        end

        function editEntries(obj, rowInd, varName, newValue)
        %editEntries Edit entries given some parameters.

            obj.assignEntries(rowInd, varName, newValue)
            obj.notifyEntryChanged(rowInd, varName)
        end

        function replaceDataColumn(obj, columnName, columnValues)
        %replaceDataColumn Replace all values of a data column.

            assert( isa(columnValues, 'cell') && numel(columnValues) == size(obj.entries, 1), ...
                'column values must be a cell array with one cell per table row')
            
            % Convert to struct in order to assign values that does not
            % match type or size of current values
            tempS = table2struct(obj.entries);
            [tempS(:).(columnName)] = deal( columnValues{:} );
            obj.entries = struct2table(tempS, 'AsArray', true);
            obj.notifyEntryChanged(':', columnName)
        end
    end

    methods (Hidden)
        function editEntriesFromTable(obj, rowInd, varName, newValue)
        %editEntriesFromTable Apply an edit that already originated in a table UI

            editedIds = obj.getObjectId(obj.entries(rowInd, :));
            obj.assignEntries(rowInd, varName, newValue)
            obj.invalidateMetaObjectCache(editedIds)
        end
    end

    methods (Access = private)
        function invalidateMetaObjectCache(obj, objectIds)
        %invalidateMetaObjectCache Remove cached meta objects for given IDs

            objectIds = nansen.metadata.MetaTable.normalizeIdentifier(objectIds);
            if isempty(objectIds) || isempty(obj.MetaObjectCacheMembers)
                return
            end

            cacheIdx = find(ismember(obj.MetaObjectCacheMembers, objectIds));

            % Delete handle objects so external references become invalid
            % instead of silently keeping stale row metadata alive.
            for i = numel(cacheIdx):-1:1
                thisIdx = cacheIdx(i);
                cachedObject = obj.MetaObjectCache(thisIdx);

                if isa(cachedObject, 'handle') && isvalid(cachedObject)
                    delete(cachedObject)
                else
                    obj.MetaObjectCache(thisIdx) = [];
                end
            end

            obj.updateMetaObjectCacheMembers();
        end

        function notifyEntryChanged(obj, rowInd, varName)
        %notifyEntryChanged Notify listeners that table entries changed

            if isequal(rowInd, ':')
                rowInd = 1:height(obj.entries);
            elseif islogical(rowInd)
                rowInd = find(rowInd);
            else
                rowInd = rowInd(:)';
            end

            columnIndex = obj.getColumnIndex(varName);
            newValue = table2cell(obj.entries(rowInd, columnIndex));

            evtData = nansen.metadata.event.MetaTableCellChangedEventData(...
                "RowIndex", rowInd, ...
                "ColumnIndex", columnIndex, ...
                "NewValue", newValue);
            obj.notify('TableEntryChanged', evtData)
        end

        function assignEntries(obj, rowInd, varName, newValue)
        %assignEntries Apply entry values without emitting view-sync events

            if isa( obj.entries{rowInd, varName}, 'cell')
                try
                    obj.entries{rowInd, varName} = newValue;
                catch % Todo: Better way?
                    obj.entries{rowInd, varName} = {newValue};
                end
            elseif isa(newValue, 'cell')
                obj.entries{rowInd, varName} = cat(1, newValue{:});
            else
                obj.entries{rowInd, varName} = newValue;
            end

            obj.onEntriesChanged()
        end

        function changeNotifications = getChangedEntryNotifications(~, oldEntries, newEntries, rowIndices)
        %getChangedEntryNotifications Find changed table cells by column

            variableNames = newEntries.Properties.VariableNames;
            changeNotifications = struct('RowIndex', {}, 'VariableName', {});

            for iColumn = 1:numel(variableNames)
                changedRows = false(1, height(newEntries));
                for iRow = 1:height(newEntries)
                    changedRows(iRow) = ~isequaln( ...
                        oldEntries(iRow, iColumn), newEntries(iRow, iColumn));
                end

                if any(changedRows)
                    changeNotifications(end+1).RowIndex = rowIndices(changedRows); %#ok<AGROW>
                    changeNotifications(end).VariableName = variableNames{iColumn};
                end
            end
        end
    end

    methods

        function wasMerged = mergeEntries(obj, sourceEntries, sourceMembers)
        %mergeEntries Update or append entries from another MetaTable payload

            sourceMembers = nansen.metadata.MetaTable.normalizeIdentifier(sourceMembers);
            wasMerged = false;
            didAppendEntries = false;
            changedEntryNotifications = struct('RowIndex', {}, 'VariableName', {});

            [~, targetIdx, sourceIdx] = intersect(obj.MetaTableMembers, sourceMembers);
            updatedEntries = sourceEntries(sourceIdx, :);
            targetEntries = obj.entries(targetIdx, :);
            if ~isequaln(targetEntries, updatedEntries)
                changedEntryNotifications = obj.getChangedEntryNotifications(targetEntries, updatedEntries, targetIdx);
                obj.entries(targetIdx, :) = updatedEntries;
                wasMerged = true;
            end

            [~, sourceIdx] = setdiff(sourceMembers, obj.MetaTableMembers);
            if ~isempty(sourceIdx)
                obj.entries(end+1:end+numel(sourceIdx), :) = sourceEntries(sourceIdx, :);
                wasMerged = true;
                didAppendEntries = true;
            end

            if wasMerged
                obj.MetaTableMembers = obj.entries.(obj.SchemaIdName);
                obj.onEntriesChanged()
            end

            for i = 1:numel(changedEntryNotifications)
                obj.notifyEntryChanged( ...
                    changedEntryNotifications(i).RowIndex, ...
                    changedEntryNotifications(i).VariableName)
            end

            if didAppendEntries
                obj.notify('EntryAdded')
            end
        end
        
        % Remove entry/entries from MetaTable
        function removeEntries(obj, listOfEntryIds)
            
            idName = obj.SchemaIdName;

            if isa(listOfEntryIds, 'cell')
                IND = ismember(obj.entries.(idName), listOfEntryIds);

            elseif isa(listOfEntryIds, 'numeric')
                IND = listOfEntryIds;

            elseif isa(listOfEntryIds, 'char')
                IND = strcmp(obj.entries.(idName), listOfEntryIds);
            end

            idsToRemove = obj.getObjectId(obj.entries(IND, :));
            obj.invalidateMetaObjectCache(idsToRemove)

            obj.entries(IND, :) = [];
            obj.MetaTableMembers = obj.entries.(obj.SchemaIdName);

            obj.onEntriesChanged()
            obj.notify('EntryRemoved')
        end

        function onEntriesChanged(obj)
            obj.IsModified = true;
        end
        
        function sort(obj)
        %sort Sort entries by schema identifier
        %
        %   Note: This method reorders entries and does not emit a
        %   table-change event. Callers that maintain views should refresh
        %   them after sorting.

            if ~isempty(obj.entries)
                [~, ind] = sort(obj.entries.(obj.SchemaIdName));
                obj.entries = obj.entries(ind, :);
                obj.MetaTableMembers = obj.entries.(obj.SchemaIdName);
            end
        end
        
% % % % Get names of all (dummy) MetaTables connected to the current master
        function names = getAssociatedMetaTables(obj, mode)
        %getAssociatedMetaTables Get associated MetaTables
        %
        %   names = getAssociatedMetaTables(obj, mode) returns names of
        %   MetaTables that are associated to the current MetaTable given
        %   the mode keyword. mode is either 'same_master' or 'same_class'
        %   for MetaTables sharing the same master or the same schema class
        %   respectively.
        %
        %   Useful for listing names of associated metatables in guis etc.
        
            MT = nansen.metadata.MetaTableCatalog.quickload();
            if isempty(MT); names = ''; return; end
            
            if nargin < 2 || isempty(mode)
                mode = 'same_master'; % Alt: 'same_class' | 'all'
            end
            
            switch mode
                case 'same_master'
                    currentKey = obj.MetaTableKey;
                    
                    % Pick out rows with matching key
                    rows = strcmp(MT.MetaTableKey, currentKey);

                case 'same_class'
                    rows = strcmp(MT.MetaTableClass, obj.MetaTableClass);
                
                case 'all'
                    rows = 1:size(MT, 1);
            end
            
            MT = MT(rows, :);
            
            names = MT.MetaTableName;

            % Add master to name for master MetaTable
            names(MT.IsMaster) = strcat(names(MT.IsMaster), ' (master)');
            names(MT.IsDefault) = strcat(names(MT.IsDefault), ' (default)');
            
            % Sort names alphabetically..
            names(~MT.IsMaster) = sort(names(~MT.IsMaster));
        end
    
        function wasUpdated = updateTableVariable(obj, variableName, tableRowIndices, updateFunction, options)
            arguments
                obj (1,1) nansen.metadata.MetaTable
                variableName (1,1) string
                tableRowIndices (1,:) double {mustBeInteger} = 1:height(obj.entries) % Default: update all
                updateFunction function_handle = function_handle.empty()
                options.ProgressMonitor = [] % Todo: waitbar class?
                options.MessageDisplay = [] % Constrain to message display
            end
            
            wasUpdated = false(1, numel(tableRowIndices));
            hasWarned = false;
            defaultValue = updateFunction();

            % Character vectors should be in a scalar cell
            if nansen.metadata.utility.isUnassignedCharValue(defaultValue)
                expectedDataType = 'character vector or a scalar cell containing a character vector';
            else
                expectedDataType = class(defaultValue);
            end

            metaObjects = obj.getMetaObjects(tableRowIndices); % Todo: Do we need to pass DataLocationModel/VariableModel here?

            warnState = warning('backtrace', 'off');
            warningCleanup = onCleanup(@() warning(warnState));

            numItems = numel(metaObjects);
            updatedValues = cell(numItems, 1);

            for iItem = 1:numItems
                try % Todo: Use error handling here. What if some conditions can not be met...
                    newValue = updateFunction(metaObjects(iItem));

                    if isa(newValue, 'nansen.metadata.abstract.TableVariable')
                        % Need to extract data value if the newValue is a
                        % TableVariable object
                        if isequal(newValue.Value, newValue.DEFAULT_VALUE)
                            continue % Skip
                        else
                            newValue = newValue.Value; % Unpack value from class object
                        end
                    end

                    [isValid, newValue] = ...
                        nansen.metadata.tablevar.validateVariableValue(...
                            defaultValue, newValue);
                    
                    if isValid
                        wasUpdated(iItem) = true;
                        updatedValues{iItem} = newValue;
                    else
                        if ~hasWarned
                            warningMessage = sprintf('The table variable function returned something unexpected.\nPlease make sure that the table variable function for "%s" returns a %s.', variableName, expectedDataType);
                            if ~isempty(options.MessageDisplay)
                                options.MessageDisplay.warn(warningMessage, 'Title', 'Update failed')
                            end
                            hasWarned = true;
                            % Todo: consider to throw this as error after
                            % processing all items. Make sure current
                            % callers can handle error
                            % ME = MException('Nansen:TableVar:WrongType', warningMessage);
                        end
                    end
                catch ME
                    warning(ME.identifier, ...
                        'Failed to update variable "%s". Reason:\n%s\n', ...
                        variableName, ME.message)
                end

                if ~isempty(options.ProgressMonitor)
                    waitbar(iItem/numItems, options.ProgressMonitor)
                end
            end

            % Update values in the metatable..
            if any(wasUpdated) % Only update if any values actually got updated
                updatedRowIndices = tableRowIndices(wasUpdated);
                updatedValues = updatedValues(wasUpdated);
                obj.editEntries(updatedRowIndices, variableName, updatedValues);
            end
        end
    end

    methods % MetaObject caching methods
        function [metaObjects, status] = getMetaObjects(obj, rowIndices, ...
                objectPropertyName, objectPropertyValue, options)
        % getMetaObjects - Get metadata objects for a set of table rows
        %
        %   Inputs:
        %     - obj - instance of this MetaTable
        %     - tableEntries - a collection of table rows
        %     - options (name-value pairs)
        %         - UseCache - (logical) - flag determining if objects can be
        %                                  retrieved from a cache
        %     - objectNameValueArgs (name-value pairs)
        %
        %   Outputs:
        %       metaObjects - An array of metadata objects
        %       status - A logical vector indicating if an object was
        %           created. Same length as tableEntries.

            % Todo: Use containers.Map / dictionary for cache...
            
            arguments
                obj (1,1) nansen.metadata.MetaTable
                rowIndices (1,:) {mustBeA(rowIndices, ["logical", "double"])}
            end
            arguments (Repeating)
                objectPropertyName string
                objectPropertyValue
            end
            arguments
                options.UseCache (1,1) logical = true
            end

            tableEntries = obj.entries(rowIndices, :);
            propertyArgs = cat(1, objectPropertyName, objectPropertyValue);

            if isempty(tableEntries) || ~options.UseCache
                [metaObjects, status] = obj.createMetaObjects(tableEntries, propertyArgs{:});
            else
                % Check if objects already exists in cache
                ids = obj.getObjectId(tableEntries);
                ids = nansen.metadata.MetaTable.normalizeIdentifier(ids);
                allCachedIds = nansen.metadata.MetaTable.normalizeIdentifier(obj.MetaObjectCacheMembers);
                
                [matchedIds, indInTableEntries, indInMetaObjects] = ...
                    intersect(ids, allCachedIds, 'stable');
    
                metaObjectsCached = obj.MetaObjectCache(indInMetaObjects);
                tableEntries(indInTableEntries, :) = []; % Don't need these anymore
                                
                statusOld = false(1, numel(ids));
                statusOld(indInTableEntries) = true;
                
                % Create meta objects for remaining entries if any
                [metaObjectsNew, statusNew] = obj.createMetaObjects(tableEntries, propertyArgs{:});
            
                % Collect outputs
                if isequal(matchedIds, ids)
                    metaObjects = metaObjectsCached;
                    status = statusOld;
                elseif ~isempty(matchedIds)
                    assert(isrow(metaObjectsNew), 'Expected new meta objects to be a row vector')
                    assert(isrow(metaObjectsCached), 'Expected cached meta objects to be a row vector')
                    metaObjects = utility.insertIntoArray(metaObjectsNew, metaObjectsCached, indInTableEntries, 2);
                    status = utility.insertIntoArray(statusNew, true(1, numel(metaObjectsCached)), indInTableEntries, 2);
                else
                    metaObjects = metaObjectsNew;
                    status = statusNew;
                end

                % Add newly created metaobjects to the cache
                if isempty(obj.MetaObjectCache)
                    obj.MetaObjectCache = metaObjectsNew;
                else
                    obj.MetaObjectCache = [obj.MetaObjectCache, metaObjectsNew];
                end
                obj.updateMetaObjectCacheMembers();
            end

            if nargout == 1
                clear status
            end
        end
        
        function resetMetaObjectCache(obj)
        %resetMetaObjectCache Delete all meta objects from the cache
            for i = numel(obj.MetaObjectCache):-1:1
                if ismethod(obj.MetaObjectCache(i), 'isvalid')
                    if ismethod(obj.MetaObjectCache(i), 'delete')
                        % It's a handle, we might need to delete it
                        if isvalid( obj.MetaObjectCache(i) )
                            delete( obj.MetaObjectCache(i) )
                        end
                    end
                end
            end
            obj.MetaObjectCache = [];
            obj.MetaObjectCacheMembers = {};
        end
    end

    methods (Access = protected)
        function S = toFileStruct(obj)
        %toFileStruct Serialize MetaTable state to struct for saving
            S = obj.toStruct('metatable_file');
        end

        function fromFileStruct(obj, S)
        %fromFileStruct Restore MetaTable state from loaded struct
            if ~isfield(S, 'MetaTableClass')
                [~, fileName] = fileparts(obj.filepath);
                error('NANSEN:MetaTable:InvalidFileType', ...
                    'The file "%s" does not contain a MetaTable', fileName)
            end
            obj.fromStruct(S);
        end

        function S = processFileStruct(obj, S)
        %processFileStruct Synchronize to master before saving (if dummy)
            if ~obj.IsMaster && ~isempty(S.MetaTableEntries)
                catalog = nansen.metadata.MetaTableCatalog();
                catalog.synchronizeToMaster(obj, S)
                S.MetaTableEntries = S.MetaTableEntries([], :);
            end
        end

        function onAfterLoad(obj)
        %onAfterLoad Synchronize from master after loading (if dummy)
            if ~obj.IsMaster
                catalog = nansen.metadata.MetaTableCatalog();
                catalog.synchronizeFromMaster(obj)
            end

            % Check that members and entries correspond
            if ~isempty(obj.members)
                if ~isequal(obj.members, obj.entries.(obj.SchemaIdName))
                    warning(['MetaTable is corrupted. Fixed during loading, ' ...
                        'but you should investigate.'])
                    obj.MetaTableMembers = obj.entries.(obj.SchemaIdName);
                end
            end
        end
    end

    methods (Access = private)
        function itemConstructor = getItemConstructor(obj)
        % getItemConstructor - Get function handle for item constructor
            if isempty(obj.ItemClassName)
                itemConstructor = str2func(obj.MetaTableClass);
            else
                itemConstructor = str2func(obj.ItemClassName);
            end
        end

        function appendTableRows(obj, newTableRows, options)
        %appendTableRows Append table rows to MetaTable with duplicate checking
        %
        %   This is a private helper method that consolidates the common
        %   logic for appending new table rows. It handles:
        %     - Duplicate detection and removal
        %     - Table concatenation with error handling
        %     - Member list updates with ID normalization
        %     - Master MetaTable synchronization (for dummy MetaTables)
        %     - Sorting by ID
        %
        %   This method is called by both addEntries and addTable.

            arguments
                obj (1,1) nansen.metadata.MetaTable
                newTableRows
                options.AutoUpdateValues (1,1) logical = true
            end

            if isempty(newTableRows)
                return
            end

            schemaIdName = obj.SchemaIdName;
            
            % Get new entry IDs and normalize them
            newEntryIds = newTableRows.(schemaIdName);
            newEntryIds = nansen.metadata.MetaTable.normalizeIdentifier(newEntryIds);
            
            % Get existing member IDs and normalize them
            existingIds = nansen.metadata.MetaTable.normalizeIdentifier(obj.MetaTableMembers);
            
            % Find duplicates
            [~, iA] = intersect(newEntryIds, existingIds, 'stable');
            
            if ~isempty(iA)
                % Skip entries that are already present in the MetaTable
                newTableRows(iA, :) = [];
                newEntryIds(iA) = [];
            end
            
            if isempty(newEntryIds)
                return; % Nothing to add
            end

            % Temporarily create a new MetaTable and add missing table
            % variables
            tempMetaTable = nansen.metadata.MetaTable.newLike(newTableRows, obj);
            nansen.getCurrentProject().synchronizeMetaTableVariables(tempMetaTable, ...
                "AutoUpdateValues", options.AutoUpdateValues);
            
            % Concatenate tables
            try
                % Try direct concatenation
                obj.entries = [obj.entries; tempMetaTable.entries];
            catch
                % Fallback: convert to struct, concatenate, then back to table
                obj.entries = struct2table([table2struct(obj.entries); ...
                                            table2struct(tempMetaTable.entries)]);
            end
            
            % Update member list
            obj.MetaTableMembers = obj.entries.(schemaIdName);
            
            % Synchronize from master if this is a dummy MetaTable
            if ~obj.IsMaster
                catalog = nansen.metadata.MetaTableCatalog();
                catalog.synchronizeFromMaster(obj)
            end
            
            % Sort entries by ID
            obj.sort()

            obj.notify('EntryAdded')
        end

        function [metaObjects, status] = createMetaObjects(obj, tableEntries, ...
                objectPropertyName, objectPropertyValue)
        % createMetaObjects - Create new meta objects from table entries
        
            arguments
                obj (1,1) nansen.metadata.MetaTable
                tableEntries
            end
            arguments (Repeating)
                objectPropertyName string
                objectPropertyValue
            end
            
            % Relevant for meta objects that have datalocations:
            if any(strcmp(tableEntries.Properties.VariableNames, 'DataLocation'))
                % Filter out DataLocationModel and VariableModel from
                % property args
                propertyArgs = obj.filterMetaObjectPropertyArgs(...
                    objectPropertyName, objectPropertyValue, ...
                    ["DataLocationModel", "VariableModel"]);
            else
                propertyArgs = {};
            end

            try
                itemConstructor = obj.getItemConstructor();
            catch
                itemConstructor = @table2struct;
            end

            % Initialize output
            status = false(1, height(tableEntries));

            if isempty(tableEntries)
                try
                    metaObjects = itemConstructor().empty;
                catch
                    % Todo: Error handling ! Important

                    metaObjects = [];
                end
                return;
            end

            % Create items one by one
            numItems = height(tableEntries);
            metaObjects = cell(1, numItems);
            status = false(1, numItems);

            for i = 1:numItems
                try
                    metaObjects{i} = itemConstructor(tableEntries(i,:), propertyArgs{:});
                    status(i) = true;
                catch ME
                    fprintf('Could not create meta object. Reason:\n%s\n', ME.message)
                    continue
                end
                try
                    addlistener(metaObjects{i}, 'PropertyChanged', @obj.onMetaObjectPropertyChanged);
                    addlistener(metaObjects{i}, 'ObjectBeingDestroyed', @obj.onMetaObjectDestroyed);
                catch MEForListener
                    if isa(metaObjects{i}, 'nansen.metadata.abstract.MetadataEntity')
                        warning(MEForListener.identifier, 'Failed to add listener to meta object. Reason:\n%s\n', MEForListener.message)
                    end
                    % Todo: Either throw warning or implement interface for
                    % easily implementing PropertyChanged on any table
                    % class..
                end
            end

            try
                metaObjects = [metaObjects{:}];
            catch
                % Pass for now. Todo: Error, warning or handle some way?
            end

            if nargout == 1
                clear status
            end
        end

        function ids = getObjectId(obj, object)
            idName = obj.SchemaIdName;
            if isa(object, 'table')
                ids = object.(idName);
            else
                ids = {object.(idName)};
            end

            ids = nansen.metadata.MetaTable.normalizeIdentifier(ids);
        end

        function updateMetaObjectCacheMembers(obj)
        %updateMetaObjectCacheMembers Update list of ids for members of the
        % metaobject cache
            if isempty(obj.MetaObjectCache)
                obj.MetaObjectCacheMembers = {};
                return
            end

            idName = obj.SchemaIdName;
            obj.MetaObjectCacheMembers = {obj.MetaObjectCache.(idName)};
            obj.MetaObjectCacheMembers = nansen.metadata.MetaTable.normalizeIdentifier(obj.MetaObjectCacheMembers);
        end
        
        function onMetaObjectPropertyChanged(obj, src, evt)
        % onMetaObjectPropertyChanged - Callback to handle value change of meta object
            if ~isvalid(src); return; end

            objectID = obj.getObjectId(src); % sessionID / itemID

            % Todo: Use getEntry
            metaTableEntryIdx = find(strcmp(obj.members, objectID));
            
            if numel(metaTableEntryIdx) > 1
                % metaTableEntryIdx = metaTableEntryIdx(1);
                error('NANSEN:MetaTable:DuplicateEntries', ...
                    'Multiple entries have the ID "%s"', objectID)
            end
            
            obj.editEntries(metaTableEntryIdx, evt.Property, evt.NewValue)
        end
        
        function onMetaObjectDestroyed(obj, src, ~)
            if ~isvalid(obj); return; end
            
            objectID = obj.getObjectId(src);
                        
            [~, ~, iC] = intersect(objectID, obj.MetaObjectCacheMembers);
            if isempty(iC)
                warning('Object was not found in cache member registry. Object will not be removed.')
            end
            obj.MetaObjectCache(iC) = [];

            obj.updateMetaObjectCacheMembers();
        end
    end

    methods (Hidden)
        function reloadFromDisk(obj)
        %reloadFromDisk Refresh this clean handle from its file

            if ~obj.isClean()
                error('NANSEN:MetaTable:CannotReloadDirtyTable', ...
                    ['Cannot reload "%s" from disk because the in-memory ', ...
                     'table has unsaved changes.'], obj.filepath)
            end

            obj.load();
            notify(obj, 'TableReloadedFromDisk')
        end

        function removeDuplicates(obj)
        %removeDuplicates Remove duplicate entries by schema identifier
        %
        %   Note: This hidden maintenance method can remove and reorder
        %   entries and does not emit table-change events.

            varName = obj.SchemaIdName;
            ids = obj.entries.(varName);
            [~, iA] = unique(ids);
            obj.entries = obj.entries(iA,:);
            obj.MetaTableMembers = obj.entries.(varName);
            obj.sort()
            if ~isempty(obj.filepath)
                obj.save()
            end
        end
    end

    methods (Static)
        function metaTable = newLike(entries, metaTable)
            arguments
                entries table
                metaTable (1,1) nansen.metadata.MetaTable
            end

            metaTable = nansen.metadata.MetaTable(entries, ...
                "ItemClassName", metaTable.ItemClassName, ...
                "MetaTableClass", metaTable.MetaTableClass, ...
                "MetaTableIdVarname", metaTable.MetaTableIdVarname);
        end
        
        function metaTable = new(varargin)
        %NEW Create a new MetaTable
        %
        %   Input can be one of the following
        %       - An instance or an array of a metadata schema to create
        %         the new MetaTable based on objects.
        %
        %       - A keyword ('master' or 'dummy') to create a blank
        %         MetaTable
            
            if numel(varargin) > 1
                nvPairs = varargin(2:end);
            else
                nvPairs = {};
            end
            metaTable = nansen.metadata.MetaTable(nvPairs{:});
            
            if isempty(varargin) || isempty(varargin{1})
                return
                
            % If entries are provided, add them to MetaTable:
            elseif isa(varargin{1}, 'nansen.metadata.abstract.MetadataEntity')
                metaTable.addEntries(varargin{1})
                
            elseif isa(varargin{1}, 'table')
                metaTable.addTable(varargin{1})
            
            % If keyword is provided, use this:
            elseif any( strcmp(varargin{1}, {'master', 'dummy'} ) )
                throw(nansen.common.exception.NotImplemented("New MetaTable from keywords."))
            end
        end
        
        function metaTable = open(nameOrFilepath)
        % open - Open a MetaTable from a specified file or name
        %
        % Syntax:
        %   metaTable = nansen.metadata.MetaTable.open(nameOrFilepath) Opens
        %   a MetaTable using the given name or file path.
        %
        % Input Arguments:
        %   nameOrFilepath (string) - The name or file path of the MetaTable
        %   to open.
        %
        % Output Arguments:
        %   metaTable - An instance of the MetaTable class containing the
        %   loaded data.
        %
            arguments
                nameOrFilepath (1,1) string {mustBeNonzeroLengthText}
            end

            if isfile(nameOrFilepath)
                filePath = nameOrFilepath;
            else
                filePath = nansen.metadata.MetaTable.resolveNameToFilepath(nameOrFilepath);
            end

            cache = nansen.metadata.MetaTableCache.instance();
            metaTable = cache.get(filePath);
            if ~isempty(metaTable)
                if metaTable.isClean() && ~metaTable.IsMaster
                    metaTable.reloadFromDisk()
                    return
                elseif metaTable.isLatestVersion()
                    return
                elseif metaTable.isClean()
                    metaTable.reloadFromDisk()
                    return
                else
                    return
                end
            end

            filePath = nansen.metadata.MetaTableCache.canonicalizeFilePath(filePath);
            metaTable = nansen.metadata.MetaTable();
            metaTable.filepath = filePath;
            metaTable.load();
            cache.add(filePath, metaTable)
        end

        function filename = createFileName(S)
        %CREATEFILENAME Create filename (add extension) for metatable file
        %
        %   This method is static because the expected input is a
        %   MetaTableCatalog entry (which is a struct)
            
            filename = matlab.lang.makeValidName(S.MetaTableName);
            filename = utility.string.camel2snake(filename);

            if S.IsMaster
                nameExtension = 'master_metatable';
            else
                nameExtension = 'dummy_metatable';
            end
            
            filename = sprintf('%s_%s.mat', filename, nameExtension);
        end

        function T = addTableVariableStatic(T, variableName, initValue)
        %   addTableVariable(obj, variableName, initValue) adds a new
        %   variable to the table and initializes all column values to the
        %   initValue.
        
            % This is kind of a more general table utility function..
            
            numTableRows = size(T, 1);
            if isempty(initValue); initValue = {initValue}; end
            columnValues = repmat(initValue, numTableRows, 1);
            
            T{:, variableName} = columnValues;
        end
    end

    methods (Static, Hidden) % Hidden instead of private to allow testing
        function normalizedIds = normalizeIdentifier(ids)
        %normalizeIdentifier Normalize identifiers to string cell array
        %
        %   normalizedIds = normalizeIdentifier(ids) converts any type of
        %   identifier (numeric, char, string, cell array) to a cell array
        %   of character vectors for consistent comparison and storage.
        %
        %   Inputs:
        %       ids - Identifiers in various formats:
        %             - Numeric scalar or vector
        %             - Character vector
        %             - String scalar or vector
        %             - Cell array of any of the above
        %
        %   Outputs:
        %       normalizedIds - Cell array of character vectors

        % Todo: Future: Represent ids as string arrays
        
            if isempty(ids)
                normalizedIds = {};
                return
            end
            
            % Handle numeric inputs
            if isnumeric(ids)
                normalizedIds = arrayfun(@(x) num2str(x), ids, 'UniformOutput', false);
                return
            end
            
            % Handle string inputs
            if isstring(ids)
                normalizedIds = cellstr(ids);
                return
            end
            
            % Handle character vector
            if ischar(ids) && isrow(ids)
                normalizedIds = {ids};
                return
            end
            
            % Handle cell array inputs
            if iscell(ids)
                % Check if cells contain numeric values
                if ~isempty(ids) && isnumeric(ids{1})
                    normalizedIds = cellfun(@num2str, ids, 'UniformOutput', false);
                % Check if cells contain strings
                elseif ~isempty(ids) && isstring(ids{1})
                    normalizedIds = cellfun(@char, ids, 'UniformOutput', false);
                else
                    % Already character cells
                    normalizedIds = ids;
                end
                return
            end
            
            % Fallback: convert to string
            normalizedIds = {char(string(ids))};
        end
        
        function propertyArgs = filterMetaObjectPropertyArgs( ...
                objectPropertyName, objectPropertyValue, keepNames)
                
            arguments
                objectPropertyName (1,:) string
                objectPropertyValue (1,:) cell
                keepNames (1,:) string
            end

            objectPropertyName = string(objectPropertyName);

            [keepNames, keepIndex] = intersect(objectPropertyName, keepNames, 'stable');
            keepValues = objectPropertyValue(keepIndex);

            propertyArgs = cat(1, cellstr(keepNames), keepValues);
        end

        function filePath = resolveNameToFilepath(inputName)
        %resolveNameToFilepath Resolve a MetaTable name to its filepath
        %
        %   Used by MetaTable.open() when the input is a name rather than
        %   a file path.

            catalogFilePath = nansen.metadata.MetaTableCatalog.getFilePath();
            MT = nansen.metadata.MetaTableCatalog.quickload(catalogFilePath);

            if isempty(MT)
                error("NANSEN:MetaTable:MetaTableNotFound", ...
                    'No MetaTable found matching the given name ("%s")', inputName)
            end

            candidateIdx = find(strcmpi(MT.MetaTableName, inputName));
            if isempty(candidateIdx)
                candidateIdx = find(strcmpi(MT.MetaTableClass, inputName));
            end
            if isempty(candidateIdx)
                candidateIdx = find(contains(MT.MetaTableName, inputName, 'IgnoreCase', true));
            end
            if isempty(candidateIdx)
                candidateIdx = find(contains(MT.MetaTableClass, inputName, 'IgnoreCase', true));
            end

            if isempty(candidateIdx)
                error("NANSEN:MetaTable:MetaTableNotFound", ...
                    'No MetaTable found matching the given name ("%s")', inputName)
            end

            if numel(candidateIdx) > 1
                defaultIdx = candidateIdx(MT.IsDefault(candidateIdx));
                masterIdx = candidateIdx(MT.IsMaster(candidateIdx));

                if isscalar(defaultIdx)
                    candidateIdx = defaultIdx;
                elseif isscalar(masterIdx)
                    candidateIdx = masterIdx;
                else
                    error("NANSEN:MetaTable:AmbiguousMetaTableName", ...
                        ['Multiple MetaTables match "%s". Use an exact ', ...
                         'MetaTableName or MetaTableClass to disambiguate.'], inputName)
                end
            end

            catalogFolder = fileparts(catalogFilePath);
            entry = MT(candidateIdx, :);
            filePath = fullfile(catalogFolder, entry.FileName{1});
        end
    end
end
