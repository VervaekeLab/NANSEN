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
            
            if exist(filePath, 'file')
                S = load(filePath);
                obj.Table = S.metaTableCatalog;
                % All items should be located in the same folder as the catalog
                obj.Table.SavePath = repmat( {obj.FolderPath}, height(obj.Table), 1 );
            else
                obj.Table = [];
            end
        end
        
        function save(obj)
        %save Save the master table to file
        
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
                    %error('A metatable with this name already exists')
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
            
            for i = 1:size(obj.Table, 1)
                obj.Table{i, 'SavePath'} = {newFilepath};
            end
        end

        function removeSavePathFromTable(obj)
            varNames = obj.Table.Properties.VariableNames;
            varNames = setdiff(varNames, 'SavePath');
            obj.Table = obj.Table(:, varNames);
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

            metatableFilepath = fullfile(mtItem.SavePath{1}, mtItem.FileName{1});
            metaTable = nansen.metadata.MetaTable.open(metatableFilepath);
        end
        
        function tf = hasDefaultOfType(obj, className)
        %HASDEFAULTOFTYPE Check if a default MetaTable of given class exists.    
            isClassMatch = strcmp(className, obj.Table.MetaTableClass);
            isDefault = obj.Table.IsDefault;
            
            S = table2struct( obj.Table(isClassMatch & isDefault, :) );
            tf = ~isempty(S);
        end
    end
    
    methods (Access = private)

        function fixCatalog(obj)
            % Todo: Remove this
            
            if size(obj.Table, 1) >= 1
                %obj.Table(:, 'MetaTableClass') = {'nansen.metadata.type.Session'};
                obj.save()
            end
            
            for i = 1:size(obj.Table,1)
                fileValues = obj.Table{i, {'SavePath', 'FileName'}};
                filePath = fullfile(fileValues{:});
                
                if isfile(filePath)
                    S = load(filePath);
                    if strcmp(S.MetaTableClass, 'nansen.metadata.schema.vlab.TwoPhotonSession')
                        S.MetaTableClass = 'nansen.metadata.type.Session';
                    end
                    save(filePath, '-struct', 'S')
                end
            end

            % Append a table column that was added october 2022
            if ~isempty(obj.Table)
                if ~any(strcmp(obj.Table.Properties.VariableNames, 'MetaTableIdVarname') )
                    numRows = size(obj.Table,1);
                    metaTableIdColumn = repmat({'sessionID'}, numRows, 1);
                    newTableColumn = cell2table(metaTableIdColumn, "VariableNames", {'MetaTableIdVarname'});
                    newTable = cat(2, obj.Table, newTableColumn);
                    columnOrder = [1:3, 8, 4:7]; % MetaTable.MTABVARS
                    obj.Table = newTable(:, columnOrder);
                    obj.save()
                end
            end
        end
        
    end

    methods (Static)
        
        function pathString = getFilePath()
        %getFilePath Get filepath where the MetaTableCatalog is located
            
            % Todo: remove. this class is independent of projects..
            pm = nansen.ProjectManager();
            projectRootDir = pm.CurrentProjectPath;
            
            metaTableDir = fullfile(projectRootDir, 'metadata', 'tables');
            
            if ~exist(metaTableDir, 'dir');  mkdir(metaTableDir);    end
            
            % Get path string from project settings 
            pathString = fullfile(metaTableDir, 'metatable_catalog.mat');
        end
        
        function MT = quickload(filePath)
        %QUICKLOAD Static method for loading catalog without constructing class    

            if ~nargin || isempty(filePath)
                filePath = nansen.metadata.MetaTableCatalog.getFilePath();
            end

            if exist(filePath, 'file')
                S = load(filePath);
                MT = S.metaTableCatalog;
            else
                MT = [];
            end

            MT.SavePath = repmat( {fileparts(filePath)}, height(MT), 1 );
        end
        
        function quicksave(MT, filePath)
        %QUICKSAVE Static method for saving catalog without constructing class
        
            if nargin < 2 || isempty(filePath)
                filePath = nansen.metadata.MetaTableCatalog.getFilePath();
            end

            %Save master table to file
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
        %QUICKADD Static method for removing entries without constructing class
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
            f.CloseRequestFcn = @(s,e,jH)MetaTableCatalog.closeTableView(s,e,jTable);
            
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