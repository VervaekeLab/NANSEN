classdef MetaTable < handle
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
%   be available on all inventories linked to that master MetaTable.
%
%   Hopefully this will work a bit like handle objects, but with the
%   additional step that data is saved to disk.
%

% Todo:
%   [ ]Inherit from VersionedFile
%   [ ] Constructor access should be MetaTableCatalog...
%   [ ] Should archive be a method on this class? Would it not be better on
%       MetatableCatalog..?
%   [ ] openMetaTableFromName should be a metatable catalog method...

%   [ ] Todo: Meta object listeners??

% Features: Should think about grouping this better.
%       Catalog/Collection, ie adding, removing and modifying entries
%       VersionedFile
%       GetFormattedTableData
%       Methods for adding/removing columns
%       Master/dummy
%       PartOfCatalog


    properties (SetAccess=private, SetObservable)
        IsModified = false;
    end
    
    properties (Access = private)
        
        IsMaster = true

        MetaTableKey = '';
        MetaTableName = '';
        MetaTableClass = '';
        MetaTableIdVarname = '';
        
        % MetaTableMembers - cell array of character vectors representing
        % unique identifiers for all entries of the table
        MetaTableMembers = {} % Todo: enforce cell of char

        % MetaTableVariables - List of table variables. Used and updated in
        % checkIfMetaTableComplete. Purpose: Silently add table var
        % definitions on first time-initialization of a metatable. 
        MetaTableVariables (:,1) string
    end

    % MetaObject caching properties
    properties (Access = private)
        MetaObjectCache = []  % Cache of metadata objects | Todo: Make this a dictionary/containers.Map
        MetaObjectCacheMembers = {}  % IDs for cached metadata objects % Todo: enforce cell of char
    end

    properties (SetAccess = private)
        ItemClassName = '';
    end

    properties (Dependent)
        VariableNames
    end
    
    % Public properties to access MetaTable contents
    properties (SetAccess = {?nansen.metadata.MetaTable, ?nansen.App})

        filepath = ''       % Filepath where metatable is saved locally
        members             % IDs for MetaTable entries
        entries table       % MetaTable entries
    end

    properties (Access = private)
        VersionNumber int64
        ReferenceTable % Reference to master table. Todo
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
            'SavePath', '', ...
            'FileName', '', ...
            'IsDefault', false ...
            );
    end

    events
        TableEntryChanged
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
        
        function className = class(obj)
        %CLASS Override class method to return the class/schema type of
        %the MetaTable entries.
            className = obj.MetaTableClass;
        end
         
        function tf = isMaster(obj)
            tf = obj.IsMaster;
        end
        
        function tf = isDummy(obj, dbRef)
            % Todo: Change name...
            tf = strcmp(obj.MetaTableKey, dbRef.MetaTableKey);
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

        function name = getName(obj)
            name = obj.MetaTableName;
        end

        function typeName = getTableType(obj)
            typeName = utility.string.getSimpleClassName(obj.MetaTableClass);
        end
          
        function key = getKey(obj)
            key = obj.MetaTableKey;
        end

        function variableName = getVariableName(obj, colIndex)
            variableName = obj.entries.Properties.VariableNames{colIndex};
        end

        function setMaster(obj, keyword)
        %setMaster Set value of IsMaster property
            switch keyword
                case 'master'
                    obj.IsMaster = true;
                    
                case 'dummy'
                    obj.IsMaster = false;
                    
                    %Determine which MetaTable it should inherit from
                    obj.linkToMaster()
            end
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
        
        function tf = isLatestVersion(obj)
            if isempty(obj.VersionNumber)
                tf = true;
                return
            end

            versionNumberInFile = obj.loadVersionNumber();
            tf = versionNumberInFile == obj.VersionNumber;
        end

        function tf = resolveCurrentVersion(obj)
        %resolveCurrentVersion Resolve which version to keep in case of conflict
        %
        %   tf = resolveCurrentVersion(obj) returns true if newer version
        %   is loaded to override current and false if current version
        %   should override newer version
        
        %   Todo: Find better function name... Confusing that it loads, but
        %   does not overwrite.

            LOAD_NEWER_VERSION = 'Load newer version';
            LOAD_NEWER_VERSION_AND_DROP = 'Load newer version and drop unsaved changes';
            KEEP_CURRENT_VERSION = 'Keep current version';

            titleStr = 'Newer version exists';

            msg = ['The metatable has been updated outside this instance of Nansen. ' ...
                'Select "Load newer version" to update the table from the latest ', ...
                'version, or "Keep current version" to continue using the ',...
                'version which is currently open. \n\n\\bfNote: Selecting "Keep ', ...
                'current version" will overwrite the newer version for all', ...
                'nansen instances.'];

            if obj.isClean()
                choices = {LOAD_NEWER_VERSION};
            else
                choices = {LOAD_NEWER_VERSION_AND_DROP};
            end

            choices{end+1} = KEEP_CURRENT_VERSION;
            %choices = strcat('<html><font size="4">', choices);

            options = struct('Default', choices{1}, 'Interpreter', 'tex');
            %formattedMessage = strcat('\fontsize{14}', sprintf( msg) );
            formattedMessage = sprintf( msg);
            answer = questdlg(formattedMessage, titleStr, choices{:}, options);

            switch lower(answer)
                case KEEP_CURRENT_VERSION
                    tf = false;
                case LOAD_NEWER_VERSION_AND_DROP
                    tf = true;
                case LOAD_NEWER_VERSION
                    tf = true;
                otherwise
                    tf = [];
            end
        end

        function load(obj)
        %LOAD Load contents of a MetaTable from file.
        %
        %   Note: MetaTables are not saved directly as class instances,
        %   instead the entries are saved as a table and the entry ids
        %   (members) are saved as a cell array. This way, the MetaTables
        %   can be read even if the MetaTable class is not on Matlabs path.
            
            % If a filepath does not exist, throw error.
            if ~isfile(obj.filepath)
                error('NANSEN:MetaTable:FileNotFound', ...
                    'File "%s" does not exist.', obj.filepath)
            end
            
            % Load variables from MetaTable file.
            S = load(obj.filepath);
            
            % Check if the loaded struct contains the variable
            % MetaTableClass. If not, this is not a valid MetaTable file.
            if ~isfield(S, 'MetaTableClass')
                [~, fileName] = fileparts(obj.filepath);
                msg = sprintf(['The file "%s" does not contain ', ...
                    'a MetaTable'], fileName);
                error('NANSEN:MetaTable:InvalidFileType', msg) %#ok<SPERR>
            end
            
            % Assign the variables from the loaded file to properties of
            % the current MetaClass instance.
            obj.fromStruct(S)

            if isempty(obj.VersionNumber)
                obj.VersionNumber = 0;
            end
            
            % Synch from master if this is a dummy
            if ~obj.IsMaster
                obj.synchFromMaster()
            end
            
            % Check that members and entries are corresponding... Only
            % relevant for master inventories (Todo: make conditional?).
            if ~isempty(obj.members)
                if ~isequal(obj.members, obj.entries.(obj.SchemaIdName))
                    warning(['MetaTable is corrupted. Fixed during ', ...
                        'loading, but you should investigate.'])
                    
                    obj.MetaTableMembers = obj.entries.(obj.SchemaIdName);
                end
            end
            
            % Assign flag stating that entries are not modified.
            obj.IsModified = false;
            %obj.IsModified = false(size(obj.entries));
        end
        
        function versionNumber = loadVersionNumber(obj)
            if isfile(obj.filepath)
                warning('off', 'MATLAB:load:variableNotFound')
                S = load(obj.filepath, 'VersionNumber');
                warning('on', 'MATLAB:load:variableNotFound')
                if isfield(S, 'VersionNumber')
                    versionNumber = S.VersionNumber;
                    if isempty(versionNumber); versionNumber = 0; end
                else
                    versionNumber = 0;
                end
            else
                versionNumber = 0;
            end
        end

        function wasSaved = save(obj, force)
        %Save Save MetaTable to file
        %
        %   Note: MetaTables are not saved directly as class instances,
        %   instead the entries are saved as a table and the entry ids
        %   (members) are saved as a cell array. This way, the MetaTables
        %   can be read even if the MetaTable class is not on Matlabs path.
        
            wasSaved = false;

            if nargin < 2; force = false; end

            % If MetaTable has no filepath, use archive method.
            if isempty(obj.filepath)
                obj.archive()
                wasSaved = true;
                if ~nargout; clear wasSaved; end
                return
            end

            if obj.isClean() && ~force
                if ~nargout; clear wasSaved; end
                return;
            end

            if ~obj.isLatestVersion() && ~force
                doCancel = obj.resolveCurrentVersion();
                if isempty(doCancel); return; end
                if doCancel; obj.load(); return; end
            end

            % Get MetaTable variables which will be saved to file.
            S = obj.toStruct('metatable_file');
            
            % Sort MetaTable entries based on the entry ID.
            % Todo: Consider whether to reinstate this
            % obj.sort()
            
            % Synch with master if this is a dummy MetaTable.
            if ~obj.IsMaster && ~isempty(S.MetaTableEntries)
                obj.synchToMaster(S)
                S.MetaTableEntries = {};
            end

            versionNumber = obj.loadVersionNumber();
            obj.VersionNumber = versionNumber + 1;
            S.VersionNumber = obj.VersionNumber;

            tempPath = strrep(obj.filepath, '.mat', '.tempsave.mat');
            save(tempPath, '-struct', 'S');

            try
                verifiedS = load(tempPath); %#ok<NASGU>
                copyfile(tempPath, obj.filepath)
                % Save metatable variables to file
                % save(obj.filepath, '-struct', 'S')
                fprintf('MetaTable saved to %s\n', obj.filepath)
                                
                wasSaved = true;
                obj.IsModified = false;
            catch ME
                error("NANSEN:MetaTable:Save:UnknownError", ...
                    "Something went wrong when saving the MetaTable. " + ...
                    "A backup of the MetaTable should exist with a '.tempsave' postfix")
            end

            if ~nargout; clear wasSaved; end
        end
        
        function saveCopy(obj, savePath)
        %saveCopy Save a copy of the metatable to the given filePath
            originalPath = obj.filepath;
            obj.filepath = savePath;
            obj.save();
            obj.filepath = originalPath;
        end
        
        function archive(obj, Sin, metaTableCatalog)
        %ARCHIVE Save Metatable using user input and add to Catalog.
        %
        %   This function is used whenever a new MetaTable is saved to disk
        %   Before saving the MetaTable a unique key is generated (or
        %   inherited from a master MetaTable) and the info about the
        %   MetaTable is added to the MetaTableCatalog.

        % rename to saveas?
            if nargin < 3; metaTableCatalog = []; end

            S = obj.toStruct('metatable_catalog');

            if nargin == 1 || isempty(Sin)
                % Get name and savepath from user
                msg = 'Enter MetaTable Name and Select Folder to Save';
                inputFields = {'MetaTableName', 'SavePath', 'IsDefault', 'IsMaster'};

                % Open an input dialog where user can add input values.
                S = tools.editStruct( S, inputFields, msg);
            else
                inputFields = fieldnames(Sin);
                for i = 1:numel(inputFields)
                    S.(inputFields{i}) = Sin.(inputFields{i});
                end
            end
            
            if isempty(S.MetaTableName)
                error("NANSEN:MetaTable:Save:MissingName", ...
                    'Can not save MetaTable because the Name is not set.')
            end
            if ~isfolder(S.SavePath)
                error("NANSEN:MetaTable:Save:FolderNotFound", ...
                    'Can not save MetaTable because the folder (for saving) does not exist.')
            end
            
            
            % Update properties of object from user input
            obj.fromStruct(S)

            % Link to master MetaTable if this is a dummy
            if isempty(obj.MetaTableKey) && obj.IsMaster
                obj.MetaTableKey = nansen.util.getuuid();
            elseif isempty(obj.MetaTableKey) && ~obj.IsMaster
                obj.linkToMaster()
            else
                % All is goood.
            end
            
            % Assign filepath of current database object
            S.FileName = obj.createFileName(S);
            obj.filepath = fullfile(S.SavePath, S.FileName);
            
            % Save to MetaTable Catalog
            S.MetaTableKey = obj.MetaTableKey;
                        
            if isempty(metaTableCatalog)
                nansen.metadata.MetaTableCatalog.quickadd(S);
            else
                metaTableCatalog.addEntry(S)
            end
            
            if S.IsDefault
                obj.setDefault()
            end
            
            forceSave = true; % Need to make sure it is saved.
            obj.save(forceSave)
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
                        className = class(obj);
                        S.MetaTableClass = className;
                    
                    case 'MetaTableEntries'
                        S.MetaTableEntries = obj.entries;
                        
                    case {'SavePath', 'FileName'}
                        [S.SavePath, S.FileName] = fileparts(obj.filepath);
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
        
%             className = class(obj);
%             assert(strcmp(className, S.MetaTableClass), ...
%                 'MetaTable is wrong class' )
        
            varNames = fieldnames(S);
            
            for i = 1:numel(varNames)
                switch varNames{i}
                    %case 'MetaTableClass'
                        % This is not a class property
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
        
        function T = getFormattedTableData(obj, columnIndices, rowIndices)
        %formatTableData Format cells of columns with special data types.
        %
        % Some columns might have special data types, and this function
        % formats data of such cells into a data type that can be displayed
        % in the table, typically into a formatted string.
            
            import nansen.metadata.utility.getColumnFormatter

            if nargin < 2 % Get all columns
                columnIndices = 1:size(obj.entries, 2);
            end
            if nargin < 3 % Get all rows
                rowIndices = 1:size(obj.entries, 1);
            end
            
            if isempty(obj.entries)
                T = obj.entries; return
            end
            
            % Subselect the part of the table that should be formatted
            T = obj.entries(rowIndices, columnIndices);
            variableNames = T.Properties.VariableNames;

            % Check if any of the columns contain structs
            firstRowData = table2cell( obj.entries(1, columnIndices) );
            
            % Create a cell array to hold formatting functions for each column
            formattingFcn = cell(size(firstRowData));
            
            % Step 0: (Do this first)
            % Note, this is done before checking for enum on purpose (Todo: Adapt special enum classes to also use the CompactDisplayProvider...)
            isCustomDisplay = @(x) isa(x, 'matlab.mixin.CustomCompactDisplayProvider');
            isCustomDisplayObj = cellfun(@(cell) isCustomDisplay(cell), firstRowData, 'uni', 1);
            formattingFcn(isCustomDisplayObj) = {@(o) obj.getCustomDisplayString(o)};

            % Step 1: Specify formatting based on special data types.
            isCategorical = cellfun(@iscategorical, firstRowData);
            formattingFcn(isCategorical) = {'char'};

            isEnum = cellfun(@isenum, firstRowData);
            formattingFcn(isEnum) = {'char'};
            
            isString = cellfun(@isstring, firstRowData);
            formattingFcn(isString) = {'char'}; % uiw.widget.Table does is not compatible with strings.

            isStruct = cellfun(@(c) isstruct(c), firstRowData);
            formattingFcn(isStruct) = {'dispStruct'};

            isDatetime = cellfun(@(c) isdatetime(c), firstRowData);
            formattingFcn(isDatetime) = {'datetime'};

            % Step 2: Get nansen table variables formatters.
            tableClass = lower( obj.getTableType() );
            [fcnHandles, names] = getColumnFormatter(variableNames, tableClass);
            
            for i = 1:numel(names)
                isMatch = strcmp(variableNames, names{i});
                if any( isMatch )
                    formattingFcn{isMatch} = fcnHandles{i};
                end
            end
            
            % Step 3: does the data type have it's own formatter?
            dataHasTableFormatter = cellfun(@(c) isa(c, 'nansen.metadata.tablevar.mixin.HasTableColumnFormatter'), firstRowData);
            formattingFcn(dataHasTableFormatter) = cellfun(@(c) ...
                str2func(class(eval( strjoin({class(c), 'TableColumnFormatter'}, '.')))), ...
                firstRowData(dataHasTableFormatter), 'uni', 0);
            
            % Step 4: Format all the table columns that needs formatting

            % Convert table to struct for the formatting of values.
            % (Can't change the datatype of the table columns otherwise...?)
            tempStruct = table2struct(T);
            numRows = numel(tempStruct);

            numCols = numel(formattingFcn);
            for jColumn = 1:numCols % Go through columns

                if isempty(formattingFcn{jColumn})
                    continue
                end

                jColumnName = T.Properties.VariableNames{jColumn};
                jColumnValues = { tempStruct.(jColumnName) };
                thisFormatter = formattingFcn{jColumn};

                if isa( thisFormatter, 'char' )
                    tmpFcn = str2func( thisFormatter );
                    formattedValue = cellfun(@(s) tmpFcn(s), jColumnValues, 'uni', 0);
                    if strcmp(thisFormatter, 'datetime')
                        isEmpty = cellfun(@isempty, formattedValue);
                        [formattedValue{isEmpty}] = deal(NaT);
                    end
              
                elseif isa( thisFormatter, 'function_handle')
                    try
                        tmpObj = thisFormatter( jColumnValues );
                        if isa(tmpObj, 'cell')
                            formattedValue = tmpObj;
                        else
                            formattedValue = tmpObj.getCellDisplayString();
                        end
                    catch ME
                        if contains(ME.message, 'rgb2hsv')
                            warning('Session table might not be rendered correctly. Try to restart Matlab, and if you still see this message, please report')
                        else
                            warning('Failed to format data for display for table column "%s"', jColumnName)
                            disp(getReport(ME))
                        end
                        formattedValue = repmat({''}, numRows, 1);
                    end
                else
                    % This should not kick in
                end

                [tempStruct(:).(jColumnName)] = deal(formattedValue{:});
            end
            
            % Convert back to table.
            T = struct2table(tempStruct, 'AsArray', true);
        end

        function strVector = getCustomDisplayString(~, dataObj)
            strVector = cell(numel(dataObj), 1);

            for i = 1:numel(dataObj)
                rep = dataObj{i}.compactRepresentationForColumn();
                strVector{i} = rep.Representation;
            end
        end
        
% % % %  Methods for checking MetaTable against project variables

        function checkIfMetaTableComplete(obj, options)
        %checkIfMetaTableComplete Check if user-defined variables are
        % missing from the table.
                    
            arguments
                obj
                options.MessageDisplay = []
            end

            if isempty(obj.entries); return; end
    
            tableType = lower( obj.getTableType() );
            
            obj.addMissingVarsToMetaTable(tableType);
        
            nvPairs = namedargs2cell(options);
            obj.removeMissingVarsFromMetaTable(tableType, nvPairs{:});
        
            obj.MetaTableVariables = obj.entries.Properties.VariableNames;
        end
        
        function addMissingVarsToMetaTable(obj, metaTableType)
        %addMissingVarsToMetaTable Add variable to table if it is missing.
        %
        %   If a table is present in the table variable definitions, but
        %   missing from the table, this functions adds a new variable to
        %   the table and initializes with the default value based on the
        %   table variable definition.
                    
            if nargin < 2
                metaTableType = 'session';
            end
            
            tableVarNames = obj.entries.Properties.VariableNames;
            
            currentProject = nansen.getCurrentProject();
            refVariableAttributes = currentProject.getTable('TableVariable');

            % Todo: Create method for getting table variable info given a
            % type, a name an potentially other attributes like "isCustom"
            refVariableAttributes(refVariableAttributes.TableType ~= metaTableType, :) = [];

            isCustom = refVariableAttributes.IsCustom;
            customVariableNames = refVariableAttributes{isCustom, 'Name'};
            
            % Check if any variable is present in the table variable list, but
            % the corresponding variable is missing from the table.
            missingVarNames = setdiff(customVariableNames, tableVarNames);
            
            getRowIndex = @(T, varName) find( strcmp(T.Name, varName) );

            if not(isempty(missingVarNames))
                projectName = nansen.getCurrentProject().Name;
            end

            for iVarName = 1:numel(missingVarNames)
                thisName = missingVarNames{iVarName};
                thisRowIndex = getRowIndex(refVariableAttributes, thisName);

                fcnName = sprintf('%s.tablevariable.%s.%s', projectName, lower(metaTableType), thisName);
                fcnResult = feval(fcnName);
                if isa(fcnResult, 'nansen.metadata.abstract.TableVariable')
                    defaultValue = fcnResult.DEFAULT_VALUE;
                else
                    defaultValue = fcnResult;
                end
                obj.addTableVariable(thisName, defaultValue)

                if refVariableAttributes{thisRowIndex, 'HasUpdateFunction'}
                    % Update for all items of the metatable
                    tableRowInd = 1:height(obj.entries);
                    updateFcnName = refVariableAttributes{thisRowIndex, 'UpdateFunctionName'}{1};
                    wasUpdated = obj.updateTableVariable(thisName, tableRowInd, str2func(updateFcnName)); %#ok<NASGU>
                    % Todo: Show warning if any fails to update?
                end
            end
            if not( isempty(obj.filepath) )
                obj.save()
            end
        end

        function removeMissingVarsFromMetaTable(obj, metaTableType, options)
        %removeMissingVarsFromMetaTable Remove variable from table if it is missing.
        %
        %   If a table variable is missing from the table variable definitions, 
        %   but is present in the table, this functions asks the user if the 
        %   variable should be removed from the table.
        %
        %   If the user selects "Yes" the variable is deleted from the
        %   table. If the user selects no, the a non-editable dummy
        %   variable is placed in the table variable folder for the current
        %   project.
        %
        %   If the table is loaded into nansen for the first time, should
        %   skip the step of asking user. 
        %   
        %   Todo: How to reliably know if this is the first time initialization?

            arguments
                obj
                metaTableType
                options.MessageDisplay = []
            end

            if isempty(options.MessageDisplay); return; end

            import nansen.metadata.utility.createClassForCustomTableVar
            
            tableVarNames = obj.entries.Properties.VariableNames;
                        
            currentProject = nansen.getCurrentProject();
            variableAttributes = currentProject.getTable('TableVariable');
            variableAttributes(variableAttributes.TableType ~= metaTableType, :) = [];
            
            % Get custom (user-defined) and default table variables
            isCustom = variableAttributes.IsCustom;
            customVariableNames = variableAttributes{isCustom, 'Name'};
            defaultVariableNames = variableAttributes{~isCustom, 'Name'};
            
            % Get those variables present in the table that are not default
            customVariablesInTable = setdiff(tableVarNames, defaultVariableNames);
            
            % Find the difference between those and the user-defined
            % variables, i.e if the user-defined variables were removed
            % from the table variable folders.
            missingVarNames = setdiff(customVariablesInTable, customVariableNames);

            % Display a prompt to the user if any table variables have been
            % removed. If user does not want to remove those variables,
            % create a dummy function for that table variable.
            
            wasUpdated = false;

            for iVarName = 1:numel(missingVarNames)
                thisName = missingVarNames{iVarName};

                question = sprintf( ['The tablevar definition is missing ', ...
                    'for "%s". Do you want to delete data for this variable ', ...
                    'from the table?'], thisName );
                title = 'Delete Table Column?';
                if any( strcmp(thisName, obj.MetaTableVariables))
                    answer = options.MessageDisplay.ask(question, ...
                        'Title', title, ...
                        'Alternatives', ["Yes", "No"], ...
                        'DefaultAnswer', "No");
                else
                    answer = 'No';
                end

                switch answer
                    case 'Yes'
                        obj.removeTableVariable(thisName)
                        obj.save()
                    case {'Cancel', 'No', ''}
                        
                        % Todo (Is it necessary): Maybe if the variable is
                        % editable...(which we dont know when the definition
                        % is removed.) Should resolve based on user
                        % feedback/tests
                        
                        % Get table row as struct in order to check data
                        % type. (Some data is within a cell array in the table)
                        tableRow = obj.entries(1, :);
                        rowAsStruct = table2struct(tableRow);
                        
                        % Create dummy function
                        S = struct();
                        S.VariableName = thisName;
                        S.MetadataClass = metaTableType;
                        S.DataType = class(rowAsStruct.(thisName));
                        
                        S.InputMode = '';
                        
                        targetFolderPath = currentProject.getTableVariableFolder();
                        createClassForCustomTableVar(S, targetFolderPath);
                        wasUpdated = true;
                end
            end
            if wasUpdated
                rehash
                % Ad hoc, need to wait 1 second in order for new table variable 
                % definitions to be registered. See nansen.module.Module/rehash
                pause(1.1)
            end
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
        
        % Todo: Make method for adding multiple variables in one go, i.e
        % allow "variableName" and "initValue" to be cell arrays.

            if ~obj.IsMaster % Add to master metatable
                % Get filepath to master MetaTable file and load MetaTable
                masterFilePath = obj.getMasterMetaTableFile();
                masterMT = nansen.metadata.MetaTable.open(masterFilePath);
                masterMT.addTableVariable(variableName, initValue);
                masterMT.save();
            end
        
            obj.entries = obj.addTableVariableStatic(obj.entries, variableName, initValue);
        end

        function removeTableVariable(obj, variableName)
            obj.entries(:, variableName) = [];
        end

        function appendTable(obj, T)
            warning('appendTable is deprecated and will be removed, use addTable instead.')
            obj.addTable(T)
        end

        function addTable(obj, T)
        %addTable Add table rows to the MetaTable
        %
        %   addTable(obj, T) adds rows from a table directly to the
        %   MetaTable. If the table is missing ID values, UUIDs will be
        %   generated automatically. This is useful for importing data
        %   from external sources or merging MetaTables.
        
            % Set MetaTable class if this is the first time entries are added
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
            obj.appendTableRows(T);
        end

        % Add entry/entries to MetaTable table
        function addEntries(obj, newEntries)
        %addEntries Add schema object entries to the MetaTable
        %
        %   addEntries(obj, newEntries) adds one or more schema objects
        %   to the MetaTable. The schema objects are validated to ensure
        %   they inherit from BaseSchema and match the MetaTable's class,
        %   then converted to a table and appended.
        
            % Validate that entries are based on the BaseSchema class
            isValid = isa(newEntries, 'nansen.metadata.abstract.BaseSchema');
            message = 'MetaTable entries must inherit from the BaseSchema class';
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
            obj.appendTableRows(newTableRows);
        end

        function entries = getEntry(obj, listOfEntryIds)
        %getEntry Get entry/entries from the entry IDs.
            listOfEntryIds = obj.normalizeIdentifier(listOfEntryIds);
            [~, IND, ~] = intersect(obj.members, listOfEntryIds);
            entries = obj.entries(IND, :);
        end
        
        function editEntries(obj, rowInd, varName, newValue)
        %editEntries Edit entries given some parameters.
            
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
        end
        
        % Remove entry/entries from MetaTable
        function removeEntries(obj, listOfEntryIds)
            
            idName = obj.SchemaIdName;

            if isa(listOfEntryIds, 'cell')
                IND = contains( obj.entries.(idName), listOfEntryIds);
                
            elseif isa(listOfEntryIds, 'numeric')
                IND = listOfEntryIds;
                
            elseif isa(listOfEntryIds, 'char')
                IND = contains( obj.entries.(idName), listOfEntryIds);
            end

            obj.entries(IND, :) = [];
            obj.MetaTableMembers = obj.entries.(obj.SchemaIdName);
            
            %obj.IsModified = true;
        end

        function onEntriesChanged(obj)
            obj.IsModified = true;
        end
        
        function sort(obj)
            if ~isempty(obj.entries)
                [~, ind] = sort(obj.entries.(obj.SchemaIdName));
                obj.entries = obj.entries(ind, :);
                obj.MetaTableMembers = obj.entries.(obj.SchemaIdName);
            end
        end
        
        % Set current MetaTable to default in MetaTable Catalog
        function setDefault(obj)
        %setDefault Set the current MetaTable instance to default
        %
        %   Also update all other MetaTables of the same class to not
        %   default.
        
            className = class(obj);
            MT = nansen.metadata.MetaTableCatalog.quickload();

            if isempty(MT); return; end
            
            isClass = strcmp(MT.MetaTableClass, className);
            isKey = strcmp(MT.MetaTableKey, obj.MetaTableKey);
            isName = strcmp(MT.MetaTableName, obj.MetaTableName);
            
            MT(isClass, 'IsDefault') = {false};
            MT(isClass&isKey&isName, 'IsDefault') = {true};
            
            nansen.metadata.MetaTableCatalog.quicksave(MT);
        end
        
        function openDefault(obj)
            
            className = class(obj);
            
            MT = nansen.metadata.MetaTableCatalog.quickload();

            if isempty(MT); return; end
            
            isClass = strcmp(className, MT.MetaTableClass);
            isDefault = MT.IsDefault;
            
            S = table2struct( MT(isClass & isDefault, :) );
           
            % Set filepath to filepath of default MetaTable.
            if ~isempty(S)
                obj.filepath = fullfile(S.SavePath, S.FileName);
            end
        end
        
% % % % Methods for syncing a dummy MetaTable with a master MetaTable.
        
        function linkToMaster(obj)
        %linkToMaster Link a dummy MetaTable to a master MetaTable
        %
        %   Lets user select a master MetaTable from a list based on the
        %   MetaTable Catalog. The current MetaTable inherits the uid
        %   key from the master and will be linked to this master MetaTable
            
            MT = nansen.metadata.MetaTableCatalog.quickload();

            assert(~isempty(MT), 'MetaTable Catalog is empty')
            
            isMaster = MT.IsMaster;
            isClass = contains(MT.MetaTableClass, class(obj));
            
            mtTmp = MT(isMaster & isClass, :);
            assert(~isempty(mtTmp), 'No master MetaTable for this MetaTable class')

            MetaTableNames = mtTmp.MetaTableName;
            
            promptString = sprintf('Select a master MetaTable');
            
            [ind, ~] = listdlg( 'ListString', MetaTableNames, ...
                                'SelectionMode', 'single', ...
                                'Name', 'Select Table', ...
                                'PromptString', promptString);

            if isempty(ind); error("NANSEN:MetaTable:OperationCanceled", ...
                    'You need link to a master MetaTable'); end
            
            obj.MetaTableKey = mtTmp.('MetaTableKey'){ind};
            obj.save()
        end
        
        function synchToMaster(obj, S)
        %synchToMaster Synch entries from dummy to master MetaTable.
        %
        %   Entries that are present in both will be written from dummy to
        %   master.
        %   Entries that are only present in dummy will be appended to
        %   master.
        
            % Get filepath to master MetaTable file and load MetaTable
            masterFilePath = obj.getMasterMetaTableFile();
            sMaster = load(masterFilePath);
            
            % Replace entries in master with corresponding entries in dummy
            [~, iA, iB] = intersect(sMaster.MetaTableMembers, S.MetaTableMembers);
            sMaster.MetaTableEntries(iA, :) = S.MetaTableEntries(iB, :);
            
            % Add entries to master which is only present in dummy
            [~, iA] = setdiff(S.MetaTableMembers, sMaster.MetaTableMembers);
            if ~isempty(iA)
                sMaster.MetaTableEntries(end+1:end+numel(iA), :) = S.MetaTableEntries(iA, :);
            end
            
            % Update MetaTable members
            sMaster.MetaTableMembers = sMaster.MetaTableEntries.(obj.SchemaIdName);
            
            % Save master MetaTable.
            save(masterFilePath, '-struct', 'sMaster')
        end
        
        function synchFromMaster(obj)
        %synchFromMaster Get entries from master MetaTable.
        
            % Get filepath to master MetaTable file and load MetaTable
            masterFilePath = obj.getMasterMetaTableFile();
            
            if isempty(masterFilePath)
                obj.linkToMaster()
                masterFilePath = obj.getMasterMetaTableFile();
            end
            
            sMaster = load(masterFilePath);
            
            iA = contains(sMaster.MetaTableMembers, obj.MetaTableMembers);
            
            % Todo: what if some entries are not present in master?
            obj.entries = sMaster.MetaTableEntries(iA, :);
        end
        
        function masterFilePath = getMasterMetaTableFile(obj)
        %getMasterMetaTableFile Get filepath for master metatable
        %   (relevant for dummy metatables)
        
            % Find master MetaTable from MetaTable Catalog
            MT = nansen.metadata.MetaTableCatalog.quickload();
            
            anyKeyMatched = contains(MT.MetaTableKey, obj.MetaTableKey);
            IND = MT.IsMaster & anyKeyMatched;
            
            if sum(IND) == 0 || isempty(IND)
                masterFilePath = '';
            else
                % Use {:} in the end to unpack indexes results from cell array
                % (MT{...} unpacks specified table variables to a cell array)
                
                rootDir = fileparts(nansen.metadata.MetaTableCatalog.getFilePath());
                masterFilePath = fullfile(rootDir, MT{IND, 'FileName'}{:});
                %deprecated, not compatible with multiple file locations...
                %masterFilePath = fullfile( MT{ IND, {'SavePath', 'FileName'} }{:} );
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
                    rows = contains(MT.MetaTableKey, currentKey);
                    
                case 'same_class'
                    rows = contains(MT.MetaTableClass, class(obj));
                
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
            
            if isempty(updateFunction) % Retrieve update function if not given
                updateFunction = obj.getTableVariableUpdateFunction(variableName);
            end
            defaultValue = updateFunction();

            % Character vectors should be in a scalar cell
            if isequal(defaultValue, {'N/A'}) || isequal(defaultValue, {'<undefined>'}) 
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

                    [isValid, newValue] = obj.validateVariableValue(defaultValue, newValue);

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
            updatedRowIndices = tableRowIndices(wasUpdated);
            updatedValues = updatedValues(wasUpdated);
            obj.editEntries(updatedRowIndices, variableName, updatedValues);
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
                    metaObjects = utility.insertIntoArray(metaObjectsNew, metaObjectsCached, indInTableEntries);
                    status = utility.insertIntoArray(statusNew, true(1,numel(metaObjectsCached)), indInTableEntries);
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

    methods (Access = private) % Not implemented yet
        function updateEntries(obj, listOfEntryIds)
            
            % Note: not implemented
            arguments
                obj (1,1) nansen.metadata.MetaTable %#ok<INUSA>
                listOfEntryIds = obj.members %#ok<INUSA> % Default: update all
            end

            error('Not implemented yet')

            % % for i = 1:numel(listOfEntryIds)
            % %     try
            % %         % Todo: need to convert to instance of metadata entity 
            % %         % and invoke update method.
            % %         % Note: Assumes this class has an update method.
            % %     catch
            % %         fprintf( 'Failed for session %s\n', listOfEntryIds{i})
            % %     end
            % % end

            % % % Synch changes to master
            % % if ~obj.IsMaster && ~isempty(obj.filepath)
            % %     S = obj.toStruct('metatable_file');
            % %     obj.synchToMaster(S)
            % % end
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

        function appendTableRows(obj, newTableRows)
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
            
            % Todo:
            % - expand entries if table has dynamic table variables
            % % updateEntries(obj, listOfEntryIds) [Not implemented]

            % Concatenate tables
            try
                % Try direct concatenation
                obj.entries = [obj.entries; newTableRows];
            catch
                % Fallback: convert to struct, concatenate, then back to table
                obj.entries = struct2table([table2struct(obj.entries); ...
                                            table2struct(newTableRows)]);
            end
            
            % Update member list
            obj.MetaTableMembers = obj.entries.(schemaIdName);
            
            % Synchronize from master if this is a dummy MetaTable
            if ~obj.IsMaster
                obj.synchFromMaster()
            end
            
            % Sort entries by ID
            obj.sort()
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
                    if isa(metaObjects{i}, 'nansen.metadata.abstract.BaseSchema')
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

        function entryIndex = getIndexById(obj, objectId)
            idName = obj.SchemaIdName;
            allIds = obj.entries.(idName);

            entryIndex = find( strcmp(allIds, objectId) );
        end

        function updateMetaObjectCacheMembers(obj)
        %updateMetaObjectCacheMembers Update list of ids for members of the
        % metaobject cache
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

            rowIdx = metaTableEntryIdx;
            colIdx = find(strcmp(obj.entries.Properties.VariableNames, evt.Property));
            newValue = obj.getFormattedTableData(colIdx, rowIdx);
            newValue = table2cell(newValue);

            evtData = nansen.metadata.event.MetaTableCellChangedEventData(...
                "RowIndex", rowIdx, ...
                "ColumnIndex", colIdx, ...
                "NewValue", newValue);
            obj.notify('TableEntryChanged', evtData)
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

    methods (Access = private) % Methods related to updating table variables
        function updateFcn = getTableVariableUpdateFunction(obj, variableName)
        % getTableVariableUpdateFunction - Get function name of table variable update function
                    
            % Todo: Think about whether we always want to get tables from 
            % the current project, or if we also want to be able to specify
            % which project to use.
            currentProject = nansen.getCurrentProject();
            refVariableAttributes = currentProject.getTable('TableVariable');
         
            tableType = lower(obj.getTableType());
            refVariableAttributes(refVariableAttributes.TableType ~= tableType, :) = [];
            
            isVariableEntry = refVariableAttributes.TableType == tableType & ...
                                strcmp(refVariableAttributes.Name, variableName);
            updateFcnName = refVariableAttributes{isVariableEntry, 'UpdateFunctionName'}{1};
            updateFcn = str2func(updateFcnName);
        end
    end
    
    methods (Access = private)
        function assertValidClass(obj, items)
            msgTemplate = sprintf(['Class of entries (%s) do not match ', ...
                'the class of the MetaTable (%%s)'], class(items));
            if ~isempty(obj.ItemClassName)
                assert(isa(items, obj.ItemClassName), ...
                    sprintf(msgTemplate, obj.ItemClassName))

            else
                assert(isa(items, obj.MetaTableClass), ...
                    sprintf(msgTemplate, obj.MetaTableClass))
            end
        end
    end

    methods (Hidden)
        function removeDuplicates(obj)
            varName = obj.SchemaIdName;
            ids = obj.entries.(varName);
            [~, iA] = unique(ids);
            obj.entries = obj.entries(iA,:);
            obj.MetaTableMembers = obj.entries.(varName);
            obj.sort()
            obj.save()
        end
    end

    methods (Access = private) % Static??
       
        function openMetaTableSelectionDialog(~)
            error('Not implemented yet')
            % Todo:
            
            % Open a quest dialog to ask if user wants to open a metatable
            % from the MetaTableCatalog or browse for a file
            
            % Open dialog base on user's choice
        end
        
        function openMetaTableFromFilepath(obj, filePath)
            
            obj.filepath = filePath;
            obj.load()
        end
        
        function openMetaTableFromName(obj, inputName)
             
            MT = nansen.metadata.MetaTableCatalog.quickload();
            
            isNameMatch = contains(MT.MetaTableName, inputName);
            isClassMatch = contains(MT.MetaTableClass, inputName);
            
            if any(isNameMatch)
                entry = MT(isNameMatch, :);
                obj.filepath = fullfile(entry.SavePath{:}, entry.FileName{:});
            elseif any(isClassMatch)
                entry = MT(isClassMatch & MT.IsMaster, :);
                obj.filepath = fullfile(entry.SavePath{:}, entry.FileName{:});
            else
                error("NANSEN:MetaTable:MetaTableNotFound", ...
                    'No MetaTable found matching the given name ("%s")', inputName)
            end
            
            obj.load()
        end
    end
    
    methods (Static)
        
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
            elseif isa(varargin{1}, 'nansen.metadata.abstract.BaseSchema')
                metaTable.addEntries(varargin{1})
                
            elseif isa(varargin{1}, 'table')
                metaTable.addTable(varargin{1})
            
            % If keyword is provided, use this:
            elseif any( strcmp(varargin{1}, {'master', 'dummy'} ) )
                throw(nansen.common.exception.NotImplemented("New MetaTable from keywords."))
                % Todo: metaTable.setMaster(varargin{1})
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

            arguments
                nameOrFilepath (1,1) string {mustBeNonzeroLengthText}
            end

            metaTable = nansen.metadata.MetaTable();

            % NOT IMPLEMENTED:
            % If no input is provided, open a list selection and let user
            % select a MetaTable to open from the MetaTableCatalog
            % % if isempty( nameOrFilepath )
            % %     metaTable.openMetaTableSelectionDialog()
            % % end

            if isfile( nameOrFilepath )
                % If input is a filepath, open file
                metaTable.openMetaTableFromFilepath(nameOrFilepath)
            else
                % If input is not a file, assume it is the name
                % of a MetaTable and open using the name
                metaTable.openMetaTableFromName(nameOrFilepath)
            end
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
            if ischar(ids) && height(ids)
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
        
        function [isValid, newValue] = validateVariableValue(defaultValue, newValue)
        % validateVariableValue - Validate a table variable value
            arguments
                defaultValue 
                newValue 
            end

            % Todo: 
            % Maintain a list of valid types and if the value is
            % valid, just check that the defaultValue and the newValue is
            % of same class instead of having an if check for each type

            % String values need to be converted to char as the table
            % currently does not support string type.
            if isa(newValue, 'string')
                newValue = char(newValue); 
            end

            isValid = false;

            if isequal(defaultValue, {'N/A'}) || isequal(defaultValue, {'<undefined>'}) % Character vectors should be in a scalar cell
                if iscell(newValue) && numel(newValue)==1 && ischar(newValue{1})
                    newValue = newValue{1};
                    isValid = true;
                elseif isa(newValue, 'char')
                    isValid = true;
                end

            elseif isa(defaultValue, 'double')
                isValid = isnumeric(newValue);

            elseif isa(defaultValue, 'logical')
                isValid = islogical(newValue);
                
            elseif isa(defaultValue, 'struct')
                isValid = isstruct(newValue);

            elseif isa(defaultValue, 'categorical')
                isValid = isa(newValue, 'categorical');

            else
                % Invalid;
            end
        end
    end
end

function str = dispStruct(s)
    str = sprintf('%dx%d struct', size(s));
end
