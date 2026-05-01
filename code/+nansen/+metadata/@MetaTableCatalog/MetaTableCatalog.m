classdef MetaTableCatalog < uim.handle
%MetaTableCatalog Class for interfacing a catalog of MetaTable filepaths
%
%   The purpose of this class is to interface a catalog of metatables to
%   quickly access info about what metatables are available and where they
%   are located.
%
%   See also MetaTable

%
%   Todo:
%       [ ] Subclass from StorableCatalog.
    
    properties %(SetAccess = private)
        FilePath    % Filepath where the catalog is stored locally
        Table       % Catalog represented with a table
    end

    properties (Access = private)
        FolderPath
    end
    
    properties (Constant, Access = private)
        DEFAULT_FILENAME = 'metatable_catalog.mat'
    end
    
    methods % Constructor
        
        function obj = MetaTableCatalog(filePath)
        % Construct an instance of the metatable catalog
        
            if nargin < 1
                obj.FilePath = obj.getFilePath();
            else
                obj.FilePath = filePath;
            end
            obj.FolderPath = fileparts(obj.FilePath);
            
            obj.load();
            obj.fixCatalog()
        end
                
        function delete(obj)
           % Todo: Check for unsaved changes.
        end
    end

    methods
        function set.FilePath(obj, newFilepath)
            if isfolder(newFilepath)
                obj.FilePath = fullfile(newFilepath, obj.DEFAULT_FILENAME);
            elseif isfile(newFilepath)
                obj.FilePath = newFilepath;
            else
                % Todo: Check that it is char and a folder + filename.
                obj.FilePath = newFilepath;
            end
        end
    end

    methods
        
        function addMetatable(obj, metaTable, isMaster, isDefault)

            arguments
                obj
                metaTable
                isMaster = false
                isDefault = false
            end

            options = struct();
            options.MetaTableName = metaTable.createDefaultName();
            options.IsDefault = isDefault;
            options.IsMaster = isMaster;

            obj.registerMetaTable(metaTable, options);
        end

        function fixCatalog(obj)
            % Todo: Remove this
            
            % Append a table column that was added october 2022
            if ~isempty(obj.Table)
                if ~any(strcmp(obj.Table.Properties.VariableNames, 'MetaTableIdVarname') )
                    numRows = size(obj.Table,1);
                    metaTableIdColumn = repmat({'sessionID'}, numRows, 1);
                    newTableColumn = cell2table(metaTableIdColumn, "VariableNames", {'MetaTableIdVarname'});
                    obj.Table = cat(2, obj.Table, newTableColumn);
                    obj.Table = obj.orderCatalogColumns(obj.Table);
                    obj.save()
                end
            end
        end
        
        function disp(obj)
        %disp Override display function to show table of metatables.
            titleTxt = sprintf(['<a href = "matlab: helpPopup %s">', ...
                '%s</a> with available metatables:'], class(obj), class(obj));
            
            fprintf('%s\n\n', titleTxt)
            disp(obj.Table)
        end
        
        function load(obj)
            % Todo: Call the static load method?
            filePath = obj.FilePath;
            
            if isfile(filePath)
                S = load(filePath);
                obj.Table = S.metaTableCatalog;
                obj.Table = obj.removeSavePathColumn(obj.Table);
                obj.Table = obj.orderCatalogColumns(obj.Table);
            else
                obj.Table = [];
            end
        end
        
        function save(obj)
        %save Save the master table to file
        
            obj.Table = obj.removeSavePathColumn(obj.Table);
            metaTableCatalog = obj.Table;
            save(obj.FilePath, 'metaTableCatalog');
        end
        
        function addEntry(obj, newEntry)
        %addEntry Add entry to the metatable catalog.
        
            % Convert new entry from struct to table
            if isa(newEntry, 'struct')
                newEntry = struct2table(newEntry, 'AsArray', true);
            end
            
            % Add entry to table
            if isempty(obj.Table)
                obj.Table = newEntry;
            else
                
                % Check that there will be no name conflict
                isNamePresent = strcmp(obj.Table.MetaTableName, newEntry.MetaTableName);
                
                if any(isNamePresent)
                    % error('A metatable with this name already exists')
                    obj.Table(isNamePresent,:) = newEntry;
                    fprintf('Metatable replaced\n')
                else
                    obj.Table = [obj.Table; newEntry]; % Concatenate vertically
                end
            end
        end
        
        function removeEntry(obj, entryName)
        %removeEntry Remove entry/entries from the metatable catalog.
        %
        %   Removes entry given entryName. If no name is given, a selection
        %   dialog will open.
            
            metaTableNames = obj.Table.MetaTableName;
            
            if nargin == 2 && ~isempty(entryName)
                ind = find( strcmp(metaTableNames, entryName) );
            else
            
                [ind, tf] = listdlg(...
                    'PromptString', 'Select inventories to remove:', ...
                    'SelectionMode', 'multiple', ...
                    'ListString', metaTableNames );
                if ~tf; return; end
            end
            
            if ~isempty(ind)
                obj.Table(ind, :) = [];
                fprintf('Removed %s from the metatable catalog\n', entryName)
            else
                fprintf('Entry with name %s does not exist in the metatable catalog\n', entryName)
            end

            obj.save()
        end
        
        function entry = getEntry(obj, entryName)
            
            metaTableNames = obj.Table.MetaTableName;
            
            entryName = strrep(entryName, ' (master)', '');
            entryName = strrep(entryName, ' (default)', '');
                    
            ind = find( strcmp(metaTableNames, entryName) );
            
            entry = table2struct(obj.Table(ind, :));
        end
        
        function metaTable = getMetaTable(obj, entryName)
                                
            item = obj.getEntry(entryName);
            
            % Get database filepath
            filePath = fullfile(obj.FolderPath, item.FileName);
                    
            % Open database
            metaTable = nansen.metadata.MetaTable.open(filePath);
        end
        
        function updatePath(obj, newFilepath)
        %updatePath Update path for all entries in the catalog.
        
            [~, oldFilename, extension] = fileparts(obj.FilePath);
            obj.FilePath = fullfile(newFilepath, [oldFilename, extension]);
        end

        function removeSavePathFromTable(obj)
            obj.Table = obj.removeSavePathColumn(obj.Table);
            obj.save()
        end
        
        function pathStr = getDefaultMetaTablePath(obj)
        % getDefaultMetaTablePath - Get filepath for default meta table
        
        % Todo:
        %   [ ] specify type

            if isempty(obj.Table); pathStr = ''; return; end
            
            isDefault = obj.Table.IsDefault;
            fileName = obj.Table{isDefault, 'FileName'};
            
            pathStr = fullfile(obj.FolderPath, fileName);
            
            if isa(pathStr, 'cell')
                pathStr = pathStr{1};
            end
        end

        function metaTable = getMasterMetaTable(obj, typeName)
            % Todo: merge with method below (getMasterTable)
            isMatch = obj.Table.IsMaster & ...
                contains(obj.Table.MetaTableClass, typeName, 'IgnoreCase', true);

            metatableFilename = obj.Table{isMatch, 'FileName'}{1};
            metatableFilepath = fullfile(obj.FolderPath, metatableFilename);
            
            metaTable = nansen.metadata.MetaTable.open(metatableFilepath);
        end
        
        function metaTable = getMasterTable(obj, metaTableType)
            
            isMatch = obj.Table.IsMaster & contains( lower(obj.Table.MetaTableClass), metaTableType);
            idx = find(isMatch);
            
            if numel(idx) > 1
                warning('More than one master table is present. Selected first match.')
                idx = idx(1);
            elseif numel(idx) == 1
                % Continue
            else
                error('No master metatable of this type exists.')
            end
            
            mtItem = obj.Table(idx, :);

            metatableFilepath = fullfile(obj.FolderPath, mtItem.FileName{1});
            metaTable = nansen.metadata.MetaTable.open(metatableFilepath);
        end
        
        function tf = hasDefaultOfType(obj, className)
        %HASDEFAULTOFTYPE Check if a default MetaTable of given class exists.
            isClassMatch = strcmp(className, obj.Table.MetaTableClass);
            isDefault = obj.Table.IsDefault;

            S = table2struct( obj.Table(isClassMatch & isDefault, :) );
            tf = ~isempty(S);
        end

        function registerMetaTable(obj, metaTable, options)
        %registerMetaTable Register a new MetaTable in the catalog and save it
        %
        %   Assigns a MetaTableKey, sets the filepath, adds a catalog entry,
        %   and saves the catalog and MetaTable file.
        %
        %   Input:
        %     metaTable - A nansen.metadata.MetaTable instance
        %     options   - struct with fields: MetaTableName, IsMaster,
        %                 IsDefault. Legacy SavePath values are ignored.

            arguments
                obj (1,1) nansen.metadata.MetaTableCatalog
                metaTable (1,1) nansen.metadata.MetaTable
                options struct = struct()
            end

            S = metaTable.toStruct('metatable_catalog');

            % Apply any provided options
            optionFields = fieldnames(options);
            for i = 1:numel(optionFields)
                if strcmp(optionFields{i}, 'SavePath')
                    continue
                end
                S.(optionFields{i}) = options.(optionFields{i});
            end

            if isempty(S.MetaTableName)
                error('NANSEN:MetaTableCatalog:MissingName', ...
                    'Cannot register MetaTable: MetaTableName is not set.')
            end
            if ~isfolder(obj.FolderPath)
                error('NANSEN:MetaTableCatalog:FolderNotFound', ...
                    'Cannot register MetaTable: save folder does not exist.')
            end

            if isempty(S.MetaTableKey) && S.IsMaster
                S.MetaTableKey = nansen.util.getuuid();
            elseif isempty(S.MetaTableKey) && ~S.IsMaster
                error('NANSEN:MetaTableCatalog:MasterKeyNotSet', ...
                    ['Cannot register a dummy MetaTable without a MetaTableKey. ', ...
                     'Assign the master MetaTable''s key to MetaTableKey first.'])
            end

            S.FileName = nansen.metadata.MetaTable.createFileName(S);
            S.filepath = fullfile(obj.FolderPath, S.FileName);
            metaTable.fromStruct(S);

            catalogEntry = metaTable.toStruct('metatable_catalog');
            catalogEntry.IsDefault = S.IsDefault;
            obj.addEntry(catalogEntry)

            if catalogEntry.IsDefault
                obj.setDefaultMetaTable(metaTable)
            else
                obj.save()
            end

            metaTable.save(true)
        end

        function setDefaultMetaTable(obj, metaTable)
        %setDefaultMetaTable Mark the given MetaTable as default in the catalog

            MT = obj.Table;
            isClass = strcmp(MT.MetaTableClass, metaTable.MetaTableClass);
            isKey   = strcmp(MT.MetaTableKey,   metaTable.MetaTableKey);
            isName  = strcmp(MT.MetaTableName,  metaTable.MetaTableName);

            MT(isClass, 'IsDefault') = {false};
            MT(isClass & isKey & isName, 'IsDefault') = {true};

            obj.Table = MT;
            obj.save();
        end

        function masterFilePath = getMasterFilePath(obj, metaTableKey)
        %getMasterFilePath Get the filepath of the master MetaTable for a given key

            anyKeyMatched = strcmp(obj.Table.MetaTableKey, metaTableKey);
            isMasterAndKeyMatch = obj.Table.IsMaster & anyKeyMatched;

            if ~any(isMasterAndKeyMatch)
                masterFilePath = '';
            elseif sum(isMasterAndKeyMatch) > 1
                error('NANSEN:MetaTableCatalog:MultipleMasters', ...
                    'Multiple master MetaTables found for key "%s".', metaTableKey)
            else
                masterFilePath = fullfile(obj.FolderPath, obj.Table{isMasterAndKeyMatch, 'FileName'}{:});
            end
        end

        function synchronizeToMaster(obj, dummyMetaTable, S)
        %synchronizeToMaster Synchronize dummy MetaTable entries to the master
        %
        %   Entries present in both are updated in master from dummy.
        %   Entries only in dummy are appended to master.

            masterFilePath = obj.getMasterFilePath(dummyMetaTable.MetaTableKey);
            if isempty(masterFilePath)
                error('NANSEN:MetaTableCatalog:MasterNotFound', ...
                    'No master MetaTable found for key "%s"', dummyMetaTable.MetaTableKey)
            end

            masterMetaTable = nansen.metadata.MetaTable.open(masterFilePath);
            wasMerged = masterMetaTable.mergeEntries(S.MetaTableEntries, S.MetaTableMembers);
            if wasMerged
                masterMetaTable.save(true)
            end
        end

        function synchronizeFromMaster(obj, dummyMetaTable)
        %synchronizeFromMaster Pull entries from master into a dummy MetaTable

            masterFilePath = obj.getMasterFilePath(dummyMetaTable.MetaTableKey);

            if isempty(masterFilePath)
                error('NANSEN:MetaTableCatalog:MasterNotFound', ...
                    ['No master MetaTable found for key "%s". ', ...
                     'The dummy MetaTable''s MetaTableKey may be stale or the ', ...
                     'master may have been deleted.'], dummyMetaTable.MetaTableKey)
            end

            sMaster = load(masterFilePath);
            iA = ismember(sMaster.MetaTableMembers, dummyMetaTable.MetaTableMembers);
            S = struct('MetaTableEntries', sMaster.MetaTableEntries(iA, :));
            dummyMetaTable.fromStruct(S);
        end
    end

    methods (Access = private)
        function folderPath = getFolder(obj)
            folderPath = fileparts(obj.FilePath);
        end
    end

    methods (Static)
        
        function pathString = getFilePath()
        %getFilePath Get filepath where the MetaTableCatalog is located
            
            % Todo: remove. this class is independent of projects..
            pm = nansen.ProjectManager();
            projectRootDir = pm.CurrentProjectPath;
            
            % Todo: get this from project instance...
            metaTableDir = fullfile(projectRootDir, 'metadata', 'tables');
            
            if ~isfolder(metaTableDir);  mkdir(metaTableDir);    end
            
            % Get path string from project settings
            pathString = fullfile(metaTableDir, nansen.metadata.MetaTableCatalog.DEFAULT_FILENAME);
            
% %             % Alternatively:
% %             token = 'MetaTableCatalog'
% %             pathString = nansen.ProjectManager.getProjectSubPath(token);
        end
        
        function MT = quickload(filePath)
        %QUICKLOAD Static method for loading catalog without constructing class

            if ~nargin || isempty(filePath)
                filePath = nansen.metadata.MetaTableCatalog.getFilePath();
            end

            if isfile(filePath)
                S = load(filePath);
                MT = S.metaTableCatalog;
            else
                MT = [];
            end
            if ~isempty(MT)
                MT = nansen.metadata.MetaTableCatalog.removeSavePathColumn(MT);
                MT = nansen.metadata.MetaTableCatalog.orderCatalogColumns(MT);
            end
        end

        function T = removeSavePathColumn(T)
        %removeSavePathColumn Remove legacy SavePath catalog column

            if ~isempty(T) && any(strcmp(T.Properties.VariableNames, 'SavePath'))
                T.SavePath = [];
            end
        end

        function T = orderCatalogColumns(T)
        %orderCatalogColumns Keep catalog columns in canonical order

            preferredOrder = { ...
                'IsMaster', ...
                'MetaTableName', ...
                'MetaTableClass', ...
                'ItemClassName', ...
                'MetaTableIdVarname', ...
                'MetaTableKey', ...
                'FileName', ...
                'IsDefault'};

            existingPreferred = preferredOrder( ...
                ismember(preferredOrder, T.Properties.VariableNames));
            remaining = setdiff(T.Properties.VariableNames, existingPreferred, 'stable');
            T = T(:, [existingPreferred, remaining]);
        end
        
        function quicksave(MT, filePath)
        %QUICKSAVE Static method for saving catalog without constructing class
        
            if nargin < 2 || isempty(filePath)
                filePath = nansen.metadata.MetaTableCatalog.getFilePath();
            end

            % Save master table to file
            MT = nansen.metadata.MetaTableCatalog.removeSavePathColumn(MT);
            metaTableCatalog = MT; %#ok<NASGU>
            save(filePath, 'metaTableCatalog');
        end
        
        function quickadd(newEntry)
        %QUICKADD Static method for adding entries without constructing class
            MT = nansen.metadata.MetaTableCatalog();
            MT.addEntry(newEntry)
            MT.save()
        end
        
        function quickremove(entryName)
        %QUICKREMOVE Static method for removing entries without constructing class
            if nargin == 0; entryName = ''; end
            MT = nansen.metadata.MetaTableCatalog();
            MT.removeEntry(entryName)
            MT.save()
        end

        function print()
            MT = nansen.metadata.MetaTableCatalog.load();
            fprintf('\nMetaTable Catalog: \n\n')
            disp(MT)
        end
        
        function view()
            MT = nansen.metadata.MetaTableCatalog.load();
            
            f = figure('MenuBar', 'none');
            screenSize = get(0, 'ScreenSize');
            f.Position = [50, 200, screenSize(3)-100, 400];
            f.Name = 'MetaTable Catalog';
            f.Resize = 'off';
            
            hTable = uitable(f, 'Position', [20,20,f.Position(3:4)-40]);
            hTable.ColumnName = MT.Properties.VariableNames;
            hTable.Data = table2cell(MT);
            
            if ispref('MetaTableCatalog', 'TableColumnWidths')
                columnWidths = getpref('MetaTableCatalog', 'TableColumnWidths');
                hTable.ColumnWidth = num2cell(columnWidths);
            else
                colWidth = round((f.Position(3)-40) / size(MT,2));
                hTable.ColumnWidth = num2cell(repmat(colWidth, 1, size(MT,2)));
            end
            
            % Make some configurations on underlying java object
            jScrollPane = findjobj(hTable);
 
            % We got the scrollpane container - get its actual contained table control
            jTable = jScrollPane.getViewport.getComponent(0);
            
            % Add a callback upon closing figure and pass on the jTable
            % handle
            f.CloseRequestFcn = @(s,e,jH) nansen.metadata.MetaTableCatalog.closeTableView(s,e,jTable);
        end
        
        function closeTableView(src, evtData, jTable)
        %closeTableView Save the table column widths to preferences
        
            th = jTable.getTableHeader();
            tcm = th.getColumnModel();
            
            numCols = tcm.getColumnCount();

            columnWidths = zeros(1, numCols);
            for i = 1:numCols
                tc = tcm.getColumn(i-1);        % Java indexing starts at 0
                columnWidths(i) = tc.getWidth();
            end
            
            setpref('MetaTableCatalog', 'TableColumnWidths', columnWidths)
            delete(src)
        end
        
        function isMetaTableInCatalog(S)
        end
        
        function checkMetaTableCatalog(S)
        % Check if MetaTable entry is part of MetaTableCatalog.
            
            MT = nansen.metadata.MetaTableCatalog.quickload();
            
            if isempty(MT)
                isPresent = false;
            else
                % Check if entry matches any entries in the MetaTableCatalog
                isKeyMatched = strcmp(MT.MetaTableKey, S.MetaTableKey);
                isNameMatched = strcmp(MT.MetaTableName, S.MetaTableName);
                
                isPresent = isKeyMatched & isNameMatched;
            end
                        
            % Add MetaTable to catalog if it is not present already.
            if sum(isPresent) == 0
                if ~S.IsMaster
                    isMasterPresent = any( isKeyMatched & MT.IsMaster );
                end
                
                if ~S.IsMaster && ~isMasterPresent
                    error(['This is a dummy MetaTable. Please add its ', ...
                        'corresponding master MetaTable before opening.'])
                else
                    nansen.metadata.MetaTableCatalog.quickadd(S)
                end
                
            elseif sum(isPresent) > 1
                warning(['Multiple cases of this MetaTable is present ', ...
                    'in the MetaTableCatalog'])
            end
        end
    end
end
