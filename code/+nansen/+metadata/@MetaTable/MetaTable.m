classdef MetaTable < handle
%MetaTable Class interface for creating and working with MetaTables
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

    
    properties (Constant, Access = private) % Variable names for export
        
        % These are variables that will be saved to a MetaTable mat file.
        FILEVARS = struct(  'MetaTableMembers', {{}}, ...
                            'MetaTableEntries', {{}} );
        
        % These are variables that will be saved to the MetaTableCatalog.
        MTABVARS = struct(  'IsMaster', false, ...
                            'MetaTableName', '', ...
                            'MetaTableClass', '', ...
                            'MetaTableIdVarname', '', ...
                            'MetaTableKey', '', ...
                            'SavePath', '', ...
                            'FileName', '', ...
                            'IsDefault', false  );
    end
    
    properties (Access = private)
        
        IsMaster = true
        IsModified = false;

        MetaTableKey = '';
        MetaTableName = '';
        MetaTableClass = '';
        MetaTableIdVarname = '';
        
        MetaTableMembers = {}
        
    end
    
    % Public properties to access MetaTable contents
    properties (SetAccess = {?nansen.metadata.MetaTable, ?nansen.App})

        filepath = ''       % Filepath where metatable is saved locally
        members             % IDs for MetaTable entries 
        entries             % MetaTable entries

    end

    properties (Dependent = true, Hidden = true) % Dunno what this is
        SchemaIdName
    end
    
    
    methods % Structor
        
        function obj = MetaTable(varargin)
            
            if nargin > 1 && isa(varargin{1}, 'table') 
                obj.entries = varargin{1};
                varargin(1) = [];

                % Todo: Make parser
                [nvPairs, ~] = utility.getnvpairs(varargin{:});
                s = utility.nvpairs2struct(nvPairs);

                if isfield(s, 'MetaTableClass')
                    obj.MetaTableClass = s.MetaTableClass;
                end
                if isfield(s, 'MetaTableIdVarname')
                    obj.MetaTableIdVarname = s.MetaTableIdVarname;
                    obj.MetaTableMembers = obj.entries.(obj.SchemaIdName);
                end
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
                schemaIdName = eval(strjoin({obj.MetaTableClass, 'IDNAME'}, '.'));
            end
        end
        
        function members = get.members(obj)
            members = obj.MetaTableMembers;
        end
         
        function set.entries(obj, value)
            obj.entries = value;
            obj.onEntriesChanged()
        end
            
        function name = getName(obj)
            name = obj.MetaTableName;
        end
          
        function key = getKey(obj)
            key = obj.MetaTableKey;
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
        
        function load(obj)
        %LOAD Load contents of a MetaTable from file.
        %
        %   Note: MetaTables are not saved directly as class instances, 
        %   instead the entries are saved as a table and the entry ids 
        %   (members) are saved as a cell array. This way, the MetaTables
        %   can be read even if the MetaTable class is not on Matlabs path.
            
        
            % If a filepath does not exist, assume it is a metatable name?
            % Todo: This should not be necessary.
            if ~exist(obj.filepath, 'file')
                
                % Is it only name of MetaTable. Todo: HUH???
                MT = nansen.metadata.MetaTableCatalog.quickload();

                isMatched = contains(MT.MetaTableName, obj.filepath);
                if any(isMatched)
                    mtEntry = MT(isMatched, :);
                    obj.filepath = fullfile(mtEntry{1, {'SavePath', 'FileName'}}{:}); %Picking first entry (There should only be one, but thats having good faith...)
                else
                    error('MetaTable file was not found')
                end
            end
            
            % Load variables from MetaTable file.
            S = load(obj.filepath);

            % Check if the loaded struct contains the variable 
            % MetaTableClass. If not, this is not a valid MetaTable file.
            if ~isfield(S, 'MetaTableClass')
                [~, fileName] = fileparts(obj.filepath);
                msg = sprintf(['The file "%s" does not contain ', ...
                    'a MetaTable'], fileName);
                error('MetaTable:InvalidFileType', msg) %#ok<SPERR>
            end
            
            % Assign the variables from the loaded file to properties of
            % the current MetaClass instance.
            obj.fromStruct(S)
            
            % Check if file is part of MetaTable Catalog (adds if missing)
            %metaCatalogEntry = obj.toStruct('metatable_catalog');
            %nansen.metadata.MetaTableCatalog.checkMetaTableCatalog(metaCatalogEntry)
            
            if ~obj.IsMaster
                obj.synchFromMaster()
            end
            
            % Check that members and entries are corresponding... Only
            % relevant for master inventories (Todo: make conditional?).
            if ~isequal(obj.members, obj.entries.(obj.SchemaIdName))
                warning(['MetaTable is corrupted. Fixed during ', ...
                    'loading, but you should investigate.'])
                
                obj.MetaTableMembers = obj.entries.(obj.SchemaIdName);
            end
            
            % Assign flag stating that entries are not modified.
            obj.IsModified = false;
            %obj.IsModified = false(size(obj.entries));
            
        end
        
        function save(obj)
        %Save Save MetaTable to file
        %
        %   Note: MetaTables are not saved directly as class instances, 
        %   instead the entries are saved as a table and the entry ids 
        %   (members) are saved as a cell array. This way, the MetaTables
        %   can be read even if the MetaTable class is not on Matlabs path.
            
            % If MetaTable has no filepath, use archive method.
            if isempty(obj.filepath)
                obj.archive()
                return
            end
            
            % Get MetaTable variables which will be saved to file.
            S = obj.toStruct('metatable_file');
            
            % Sort MetaTable entries based on the entry ID.
            obj.sort()
            
            % Synch with master if this is a dummy MetaTable.
            if ~obj.IsMaster && ~isempty(S.MetaTableEntries)
                obj.synchToMaster(S)
                S.MetaTableEntries = {};
            end

            % Save metatable variables to file
            save(obj.filepath, '-struct', 'S')
            fprintf('MetaTable saved to %s\n', obj.filepath)
            
            obj.IsModified = false;
        end
        
        function saveCopy(obj, savePath)
        %saveCopy Save a copy of the metatable to the given filePath
            originalPath = obj.filepath;
            obj.filepath = savePath;
            obj.save();
            obj.filePath = originalPath;
        end
        
        function archive(obj, Sin)
        %ARCHIVE Save Metatable using user input and add to Catalog.
        %
        %   This function is used whenever a new MetaTable is saved to disk
        %   Before saving the MetaTable a unique key is generated (or
        %   inherited from a master MetaTable) and the info about the
        %   MetaTable is added to the MetaTableCatalog.
        
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
            
            if isempty(S.MetaTableName) || ~exist(S.SavePath, 'dir')
                error('Not enough info provided to create a new entry')
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
                        
            nansen.metadata.MetaTableCatalog.quickadd(S);
            
            if S.IsDefault
                obj.setDefault()
            end
            
            obj.save()
            
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
                    S = obj.MTABVARS;
                    
                case 'metatable_file'
                    S = obj.FILEVARS;
                    f = fieldnames(obj.MTABVARS);
                    
                    for i = 1:length(f)
                        S.(f{i}) = obj.MTABVARS.(f{i});
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
            
            % Step 1: Specify formatting based on special data types.
            isCategorical = cellfun(@iscategorical, firstRowData);
            formattingFcn(isCategorical) = {'char'};

            isString = cellfun(@isstring, firstRowData);
            formattingFcn(isString) = {'char'}; % uiw.widget.Table does is not compatible with strings.

            isStruct = cellfun(@(c) isstruct(c), firstRowData);
            formattingFcn(isStruct) = {'dispStruct'};

            % Step 2: Get nansen table variables formatters.
            tableClass = 'session'; % Todo: make this variable
            [fcnHandles, names] = getColumnFormatter(variableNames, tableClass);
            
            for i = 1:numel(names)
                isMatch = strcmp(variableNames, names{i});
                if any( isMatch )
                    formattingFcn{isMatch} = fcnHandles{i};
                end
            end
            
            % Step 3: Format all the table columns that needs formatting

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

                elseif isa( thisFormatter, 'function_handle')
                    try
                        tmpObj = thisFormatter( jColumnValues );
                        formattedValue = tmpObj.getCellDisplayString();
                    catch ME
                        if contains(ME.message, 'rgb2hsv')
                            warning('Session table might not be rendered correctly. Try to restart Matlab, and if you still see this message, please report')
                        else
                            warning('Failed to format data for display for table colum "%s"', jColumnName)
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
        
% % % % Methods for modifying entries

        function tf = isVariable(obj, varName)
            tf = contains(varName, obj.entries.Properties.VariableNames);
        end

        function addTableVariable(obj, variableName, initValue)
        %addTableVariable Add a variable as a new column of the table
        %
        %   addTableVariable(obj, variableName, initValue) adds a new
        %   variable to the table and initializes all column values to the
        %   initValue.
        
        % Todo: Make method for adding multiple variable ine one go, i.e
        % allow variableName and initValue to be cell arrays.

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

        function appendTable(obj, newTableRows)
        %appendTable append a metatable to the current metatable 
        
            % Todo: Add validations to make sure there are not duplicate
            % entries
            % Todo: Extract separate methods for the code which is
            % duplicated in addEntries.
        
            % Todo; what if the id is not the 1st variable.
            schemaIdName = newTableRows.Properties.VariableNames{1};
            
            obj.entries = [obj.entries; newTableRows];
            obj.MetaTableMembers = obj.entries.(schemaIdName);
            
            % Synch entries from master, e.g. if some entries were added
            % that are already in master.
            if ~obj.IsMaster %&& ~isempty(obj.filepath)
                obj.synchFromMaster()
            end
            
            obj.sort()
            
            obj.IsModified = true;
        end
        
        % Add entry/entries to MetaTable table
        function addEntries(obj, newEntries)
        %addEntries Add entries to the MetaTable
        
            % Make sure entries are based on the BaseSchema class.
            isValid = isa(newEntries, 'nansen.metadata.abstract.BaseSchema');
            message = 'MetaTable entries must inherit from the BaseSchema class';            
            assert(isValid, message)
        
            schemaIdName = newEntries(1).IDNAME;
            
            % If this is the first time entries are added, we need to set
            % the MetaTable class property. Otherwise, need to make sure
            % that new entries are matching the class of the MetaTable
            if isempty(obj.MetaTableMembers)
                obj.MetaTableClass = class(newEntries);
            else
                msg = sprintf(['Class of entries (%s) do not match ', ...
                    'the class of the MetaTable (%s)'], class(newEntries), ...
                    obj.MetaTableClass);
                assert(isa(newEntries, obj.MetaTableClass), msg)
            end
            
            % Convert entries to a table before adding to the MetaTable
            newEntries = newEntries.makeTable();
            
            % Get to entry IDs.
            newEntryIds = newEntries.(schemaIdName);
            
            % Check that entry/entries are not already present in the
            % Metatable.
            if iscell(newEntryIds) && ischar(newEntryIds{1})
                iA = contains(newEntryIds, obj.MetaTableMembers);
            elseif isnumeric(newEntryIds)
                if isempty(obj.MetaTableMembers)
                    obj.MetaTableMembers = [];
                end
                iA = ismember(newEntryIds, obj.MetaTableMembers);
            end
            
            newEntryIds(iA) = [];
            
            if isempty(newEntryIds); return; end
            
            % Skip entries that are already present in the MetaTable.
            newEntries(iA, :) = [];
            
            % Add new entries to the MetaTable.
            if isempty(obj.entries)
                obj.entries = newEntries;
            else
                obj.entries = [obj.entries; newEntries];
            end
            
% %             obj.updateEntries(listOfEntryIds)
            
            obj.MetaTableMembers = obj.entries.(schemaIdName);
            
            % Synch entries from master, e.g. if some entries were added
            % that are already in master.
            if ~obj.IsMaster %&& ~isempty(obj.filepath)
                obj.synchFromMaster()
            end
            
            obj.sort()
            
            obj.IsModified = true;
        end

        function entries = getEntry(obj, listOfEntryIds)
        %getEntry Get entry/entries from the entry IDs.
            IND = contains(obj.members, listOfEntryIds);
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
                assert( ~isempty( strfindsid(listOfEntryIds{1}) ), 'Cells should contain IDs' )
                IND = contains( obj.entries.(idName), listOfEntryIds);
                
            elseif isa(listOfEntryIds, 'numeric')
                IND = listOfEntryIds;
                
            elseif isa(listOfEntryIds, 'char')
                assert( ~isempty( strfindsid(listOfEntryIds) ), 'Char should contain ID' )
                IND = contains( obj.entries.(idName), listOfEntryIds);
            end

            obj.entries(IND, :) = [];
            obj.MetaTableMembers = obj.entries.(obj.SchemaIdName);
            
            obj.IsModified = true;
        end
        
        function updateEntries(obj, listOfEntryIds)
            
            if nargin < 2 % Update all...
                listOfEntryIds = obj.members;
            end
            
            for i = 1:numel(listOfEntryIds)
                try
                    % Todo: need to convert to instance of schema and invoke
                    % update method.
                catch
                    fprintf( 'Failed for session %s\n', listOfEntryIds{i})
                end
            end
            
            
            % Synch changes to master
            if ~obj.IsMaster && ~isempty(obj.filepath)
                S = obj.toStruct('metatable_file');
                obj.synchToMaster(S)
            end
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
        
        
% % % % Methods for synching a dummy MetaTable with a master MetaTable.
        
        function linkToMaster(obj)
        %linkToMaster Link a dummy MetaTable to a master MetaTable
        %
        %   Lets user select a master MetaTable from a list based on the
        %   MetaTable Catalog. The current MetaTable inherits the uid
        %   key from the master and will be linked to this master MetaTable
            
            MT = nansen.metadata.MetaTableCatalog.quickload();

            assert(~isempty(MT), 'MetaTable Catalog is empty')
            
            
            isMaster = MT.IsMaster; %#ok<PROP>
            isClass = contains(MT.MetaTableClass, class(obj));
            
            mtTmp = MT(isMaster & isClass, :); %#ok<PROP>
            assert(~isempty(mtTmp), 'No master MetaTable for this MetaTable class')

            MetaTableNames = mtTmp.MetaTableName;
            
            promptString = sprintf('Select a master MetaTable');
            
            [ind, ~] = listdlg( 'ListString', MetaTableNames, ...
                                'SelectionMode', 'multiple', ...
                                'Name', 'Select Table', ...
                                'PromptString', promptString);

            if isempty(ind); error('You need link to a master MetaTable'); end
            
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
        
    end
    
    methods (Access = private, Hidden)
       
        function openMetaTableSelectionDialog(obj)
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
                error('No MetaTable found matching the given name ("%s")', inputName)
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
        
            
            metaTable = nansen.metadata.MetaTable();
            
            if isempty(varargin) || isempty(varargin{1})
                return
                
            % If entries are provided, add them to MetaTable:
            elseif isa(varargin{1}, 'nansen.metadata.abstract.BaseSchema')
                metaTable.addEntries(varargin{1})
                
            elseif isa(varargin{1}, 'table')
                metaTable.addEntries(varargin{1})
            
            % If keyword is provided, use this:
            elseif any( strcmp(varargin{1}, {'master', 'dummy'} ) )
                error('Not implemented yet.')
                metaTable.setMaster(varargin{1})
            end
        end
        
        function metaTable = open(varargin)
            
            metaTable = nansen.metadata.MetaTable();

            
            % If no input is provided, open a list selection and let user
            % select a MetaTable to open from the MetaTableCatalog
            if isempty( varargin )
                metaTable.openMetaTableSelectionDialog()
                
            % If varargin is a filepath, open file
            elseif ischar( varargin{1} ) && isfile( varargin{1} )
                metaTable.openMetaTableFromFilepath(varargin{1})
                
            % If varargin is a char, but not a file, assume it is the name
            % of a MetaTable and open using the name
            elseif ischar(varargin{1})
                metaTable.openMetaTableFromName(varargin{1})
                
            else
                message = 'Can not open MetaTable based on current input';
                error(message)
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
        
        function tf = hasDefault(className)
        %HASDEFAULT Check if a default MetaTable of given class exists.    
            
            MT = nansen.metadata.MetaTableCatalog();
            
            if isempty(MT); return; end
            
            isClassMatch = strcmp(className, MT.MetaTableClass);
            isDefault = MT.IsDefault;
            
            S = table2struct( MT(isClassMatch & isDefault, :) );
            tf = ~isempty(S);
        end
        
        function T = addTableVariableStatic(T, variableName, initValue)
        %   addTableVariable(obj, variableName, initValue) adds a new
        %   variable to the table and initializes all column values to the
        %   initValue.
        
            % This is kind of a more general table utility function..
            
            numTableRows = size(T, 1);
            columnValues = repmat(initValue, numTableRows, 1);
            
            T{:, variableName} = columnValues;
        end
        
    end

end

function str = dispStruct(s)
    str = sprintf('%dx%d struct', size(s));
end
