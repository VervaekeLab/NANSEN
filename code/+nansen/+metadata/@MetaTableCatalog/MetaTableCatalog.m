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
    
    
    methods
        
        function obj = MetaTableCatalog(filePath)
        % Construct an instance of the metatable catalog
        
            if nargin < 1
                obj.FilePath = obj.getFilePath();
            else
                obj.FilePath = filePath;
            end
            
            obj.load();
            obj.fixMetatable()
        end
        
        function fixMetatable(obj)
            % Todo: Remove this
            
            if size(obj.Table, 1) >= 1
                obj.Table(:, 'MetaTableClass') = {'nansen.metadata.type.Session'};
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
        end
        
        function disp(obj)
        %disp Override display function to show table of metatables.
            titleTxt = sprintf(['<a href = "matlab: helpPopup %s">', ...
                '%s</a> with available metatables:'], class(obj), class(obj));
            
            fprintf('%s\n\n', titleTxt)
            disp(obj.Table)
        end
        
        function delete(obj)
           % Todo: Check for unsaved changes. 
        end
        
        function load(obj)
            % Todo: Call the static load method?
            filePath = obj.FilePath;
            
            if exist(filePath, 'file')
                S = load(filePath);
                obj.Table = S.metaTableCatalog;
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
                
                isNameOccupied = any(strcmp(...
                    obj.Table.MetaTableName, newEntry.MetaTableName));
            
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
                ind = find( contains(metaTableNames, entryName) );
            else
            
                [ind, tf] = listdlg(...
                    'PromptString', 'Select inventories to remove:', ...
                    'SelectionMode', 'multiple', ...
                    'ListString', metaTableNames );
                if ~tf; return; end
            end
            
            obj.Table(ind, :) = [];
            
            obj.save()
            
        end
        
        function updatePath(obj, newFilepath)
        %updatePath Update path for all entries in the catalog.
        
            for i = 1:size(obj.Table, 1)
                obj.Table{i, 'SavePath'} = {newFilepath};
            end
            
        end
        
        function metaTable = getMasterTable(obj, metaTableType)
            
            
            isMatch = obj.Table.IsMaster &&  contains( lower(obj.Table.MetaTableClass), metaTableType);
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
        
    end
    
    
    methods (Static)
        
        function pathString = getFilePath()
        %getFilePath Get filepath where the MetaTableCatalog is located
        
            projectRootDir = getpref('Nansen', 'CurrentProjectPath');
            metaTableDir = fullfile(projectRootDir, 'Metadata Tables');
            
            if ~exist(metaTableDir, 'dir');  mkdir(metaTableDir);    end
            
            % Get path string from project settings 
            pathString = fullfile(metaTableDir, 'metatable_catalog.mat');
            
% %             % Alternatively:
% %             token = 'MetaTableCatalog'
% %             pathString = nansen.ProjectManager.getProjectSubPath(token);
            
        end
    
        function pathStr = getDefaultMetaTablePath()
            MT = nansen.metadata.MetaTableCatalog.quickload();
            
            if isempty(MT); pathStr = ''; return; end
            
            IND = find( MT.IsDefault );
            pathStr = fullfile(MT{IND, 'SavePath'}, MT{IND, 'FileName'});
            
            if isa(pathStr, 'cell')
                pathStr = pathStr{1};
            end
            
        end
        
        function MT = quickload()
        %QUICKLOAD Static method for loading catalog without constructing class    
            
            filePath = nansen.metadata.MetaTableCatalog.getFilePath();
            
            if exist(filePath, 'file')
                S = load(filePath);
                MT = S.metaTableCatalog;
            else
                MT = [];
            end

        end
        
        function quicksave(MT)
        %QUICKSAVE Static method for saving catalog without constructing class
        
            %Save master table to file
            filePath = nansen.metadata.MetaTableCatalog.getFilePath();
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