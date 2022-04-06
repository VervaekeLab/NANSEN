classdef StorableCatalog < handle
%StorableCatalog An storable catalog of items.
%
%   Abstract superclass for storable catalogs. A specific instance will 
%   have a 1-to-1 relationship with the data stored in a file. The data in 
%   the catalog is a struct array representing a list of items. The catalog
%   contains methods for inserting and removing items, by referring to the
%   item's name. All items should be given a name, and is automatically
%   assigned a uuid on creation. All other properties of items has to be
%   specified in the defining subclass, using the getBlankItem method.


%   Abstract Properties:
%       ITEM_TYPE
%
%   Abstract Methods:
%       getBlankItem()
%       getDefaultItem() % Todo: remove
%       validateItem()
%
%   Key features:
%       Should be singleton-ish
%       Provide api and gui (separate class?) functionality for editing. 
%       Access and modify items by name...


% Todo: Clearer policy for when to save changes. Inserting and removing
% items are saved right away, but modification of items, i.e in subclasses
% is not saved.
%
% Implement storing of a data backup, in order to determine if current
% catalog is dirty of not...

% Note, this could have been implemented better with more objectification
% of items, but that unfortunately did not happen:( On the bright side,
% using structs makes it easier to define items...


% Todo:
%       [ ] Inherit from singletonish
%       [ ] addpref and removepref methods
%       [ ] Add mode for saving changes immediately or not. I.e when
%           working with table on command line versus in app...
%       [ ] Property flag for whether items should be assigned uuids or not

% Questions:
%     - Should data be a struct or a table?
%     - Should Data be dependent, and always loaded from file..?
%     - Should Data be observable? Or DataChanged event? 
%           SetAccess public or protected??? 
%
%
% Discussion:
%     - Why struct and not table? 
%           - Because more flexibility...

    properties (Abstract, Constant, Hidden)
        ITEM_TYPE           % Name / label for items in catalog
    end

    properties (SetAccess = protected) % Change to private...
        Data struct % Todo: Rename ?
        Preferences
    end
    
    properties (Dependent, SetAccess = private)
        TabularData
    end
    
    properties (SetAccess = protected)
        FilePath char   % Filepath where current table is archived
    end
    
    properties (Access = protected) % Might be better id this is dependent... (no need to explicity update)
        ItemNames       % Name of all items in archive
    end
    
    
    events % Tentative...
        ItemAdded
        ItemRemoved
        ItemModified
    end
    
    events % Or...
        DataChanged
    end
    
%     Implement this with protected data property, or have a set method
%     that notifies an event or just make Data observable???

%     properties (Access = protected)
%         Data
%     end
    

    methods (Abstract, Static)
    
        S = getBlankItem()

        S = getDefaultItem() % todo... remove
        
        pathStr = getDefaultFilePath()
        
    end
    
    methods (Access =  protected)
        function item = validateItem(obj, item)
        
            requiredFields = fieldnames( obj.getBlankItem() );
            itemFields = fieldnames(item);

            assertMessage = 'Item does not match the item type of this catalog';
            assert(all(ismember(requiredFields, itemFields)), assertMessage)
            
        end
        
        function item = validateFieldOrder(~, item)
        %validateFieldOrder Enforce Uuid as the first field of item struct    
            itemFields = fieldnames(item);
            
            % Make sure uuid is the first field...
            if contains('Uuid', itemFields) && ~strcmp(itemFields{1}, 'Uuid')
                fieldOrder = ['Uuid'; setdiff(itemFields, 'Uuid', 'stable') ];
                item = orderfields(item, fieldOrder);
            end
        end
    end
    
    
    methods % Constructor
        
        function obj = StorableCatalog(varargin)
            
            % Will assign FilePath property if given in list of inputs
            obj.parseVarargin(varargin{:})
            
            if isempty(obj.FilePath)
                obj.FilePath = obj.getDefaultFilePath();
            end
            
            if ~isfile(obj.FilePath)
                obj.initialize()
            end
            
            obj.load()
            
        end
        
    end
    
    methods % Get method
        function T = get.TabularData(obj)
            T = struct2table(obj.Data, 'AsArray', true);
        end
    end
    
    methods % Methods for archiving
        
        function setFilePath(obj, filePath)
        %setFilePath Set fielpath of archive. %Todo: remove?
        
            folderPath = fileparts(filePath);
            if ~exist(folderPath, 'dir'); mkdir(folderPath); end
            
            obj.FilePath = filePath;
            
        end
        
        function refreshFilePath(obj)
            obj.FilePath = obj.getDefaultFilePath();
        end % resetFilePath
        
        function reloadDefault(obj)
            obj.FilePath = obj.getDefaultFilePath();
            obj.load()
        end
        
        function refresh(obj)
            obj.reloadDefault()
        end
        
        function restoreCatalog(obj, structCatalog)
            obj.Preferences = structCatalog.Preferences;
            obj.Data = structCatalog.Data;
        end
        
        function S = initialize(obj)
        %initialize Initialize file with variables    
            S = struct();
            S.Data =  obj.getEmptyItem();
            S.Preferences = struct();
            S.Preferences.SourceID = utility.system.getComputerName(true);
            
            % Add a uuid as the last field of S
            origNames = fieldnames(S.Data);
            [S.Data(:).Uuid] = {};
            S.Data = orderfields(S.Data, ['Uuid'; origNames]);
            
            save(obj.FilePath, '-struct', 'S')
            
            if ~nargout
                clear S
            end
        end

        function load(obj)
        %load Load data from file
        
            if ~isfile(obj.FilePath)
                obj.initialize()
            end
            
            S = load(obj.FilePath, 'Data', 'Preferences');
            
            S = obj.addUuidIfMissing(S); % Todo: Remove this on release.
            
            S = obj.modifyStructOnLoad(S); % For subclasses to make modifications
            obj.fromStruct(S);
            
            obj.assignItemNames()
            
        end
        
        function save(obj)
        %save Save data to file
            S = obj.toStruct; %#ok<NASGU>
            S = obj.cleanStructOnSave(S);
            save(obj.FilePath, '-struct', 'S')
        end
        
        function saveas(obj, filePath)
        %save Save data to file at file path given as input
            S = obj.toStruct; %#ok<NASGU>
            S = obj.cleanStructOnSave(S);
            save(filePath, '-struct', 'S')
        end
        
    end
    
    methods % Methods for manipulating entries
        
        function insertItemList(obj, newItemList)
            for i = 1:numel(newItemList)
                obj.insertItem(newItemList(i))
            end
        end
        
        function newItem = insertItem(obj, newItem)
            
            newItem.Uuid = nansen.util.getuuid();
            newItem = obj.validateFieldOrder(newItem);
            
            % Make sure item has necessary fields...
            newItem = obj.validateItem(newItem);
            
            insertIdx = numel(obj.Data) + 1;
            
            % Make sure not to insert item with name that already exist...
            newItemName = obj.getItemName(newItem);
            if any(obj.containsItem(newItemName))
                message = sprintf('A %s with the name "%s" already exists', ...
                    obj.ITEM_TYPE, newItemName);
                error(message); %#ok<SPERR>
            end
            
            % Todo: Should newItem replace old item if an item with the
            % name already exists? Or make separate replace method?
            if isempty(obj.Data) 
                obj.Data = newItem; % Todo: Initialize data using empty item, on first time startup...
            else
                obj.Data(insertIdx) = newItem;
            end
            
            obj.assignItemNames()
            obj.save()
            
            if ~nargout
                clear newItem
            end
            
        end
        
        function removeItem(obj, itemName)
             
            if isnumeric(itemName) % Assume index was given instead of name
                itemIndex = itemName;
                itemName = obj.ItemNames(itemIndex);
            end
            
            tf = obj.containsItem(itemName);
            
            if ~any(tf)
                error('%s "%s" was not found in table', obj.ITEM_TYPE, itemName)
            end
            
            obj.Data(tf) = [];
            
            obj.assignItemNames()
            obj.save()
        end

    end
    
    methods % Methods for finding entries
        

    end
    
    methods
        
        function list(obj)
            disp( obj.TabularData )
        end
        
        function initializeWithDefault(obj)
            obj.Data = obj.getDefaultItem();
        end
        
        function obj = default(obj)
            obj.initializeWithDefault()
        end

        function name = getNameFromUuid(obj, uuid)
            
            idx = find(strcmp({obj.Data.Uuid}, uuid));
            
            if isempty(idx); name = ''; return; end
            
            name = obj.getItemName( obj.Data(idx) );
            
        end
        
        function [S, idx] = getItem(obj, itemName)
                    
            idx = obj.getItemIndex( itemName );
            S = obj.Data(idx);
            
            if nargout == 1
                clear idx
            end
            
        end
        
        function idx = getItemIndex(obj, itemName)
            
            if isnumeric(itemName) % Assume index was given instead of name
                idx = itemName;
                
            elseif obj.isuuid(itemName) % Assume uuid was given instead of name
                idx = find(strcmp({obj.Data.Uuid}, itemName));
                
            else
                idx = find(strcmp(obj.ItemNames, itemName));
            end
            
        end
        
        function name = getItemName(obj, item)
            
            if ~isempty(obj.Data)
                fieldNames = fieldnames(obj.Data);
                idName = fieldNames{2};
            else
                fieldNames = fieldnames(obj.getEmptyItem() ); % Todo: replace with blank item
                idName = fieldNames{1};
            end
            
            name = item.(idName);
            
        end

        function [Lia, Locb] = ismember(obj, itemName)
        %ismember 
            
            Lia = ismember(itemName, obj.ItemNames);
            
            if nargout == 2
                Locb = find(Lia);
            end
            
        end
        
        function [tf, idx] = containsItem(obj, itemName)
        %containsItem Check if given item is part of current archive

            tf = ismember(obj.ItemNames, itemName);
            
            if nargout == 2
                idx = find(tf);
            end
            
        end
        
        function setData(obj, dataStruct)
            obj.Data = dataStruct; 
        end
        
        function S = getBackupCatalog(obj)
            S = obj.toStruct();
        end
        
        function tf = isequal(obj, catalogStruct)
            S = obj.toStruct();
            tf = isequal(S, catalogStruct);
        end
    end
    
    methods (Access = protected)
        
        function S = cleanStructOnSave(obj, S)
            % Subclass can override
        end
        
        function S = modifyStructOnLoad(obj, S)
            % Subclass can override
        end
        
        function S = getEmptyItem(obj)
        %getEmptyItem Get an empty item for the data property    
            S = obj.getBlankItem();
            S(1) = [];
        end
            
        function assignItemNames(obj)
        %assignItemNames Assign names of all items to property
        
            % Assumes the "Name" is the second fieldname. Todo: generalize
            fieldNames = fieldnames(obj.Data);
            
            if strcmp(fieldNames{1}, 'Uuid')
                idName = fieldNames{2};
            else
                idName = fieldNames{1};
            end
            
            assertMsg = 'Expected leading tablevariable to be name of item';
            assert(contains(lower(idName), 'name'), assertMsg)
            
            obj.ItemNames = {obj.Data.(idName)};
            
        end
        
    end
    
    methods (Access = private)
        
        function S = toStruct(obj)
            S = struct();
            S.Data = obj.Data;
            S.Preferences = obj.Preferences;
        end
        
        function fromStruct(obj, S)
            assert(isfield(S, 'Preferences'), 'Catalog must have Preferences')
            assert(isfield(S, 'Data'), 'Catalog must have Data')
            
            % Todo: Make sure all the fieldnames are the same.
            
            obj.Data = S.Data;
            obj.Preferences = S.Preferences;
        end
       
        function parseVarargin(obj, varargin)
            
            if ~isempty(varargin)
                varargin = obj.checkArgsForFilePath(varargin);
            end
            

        end
        
        function argList = checkArgsForFilePath(obj, argList)
            
            if isa(argList{1}, 'char')
                
                % Check if it is a valid filepath
                isFilePath = contains(argList{1}, filesep);

                if isFilePath

                    parentDir = fileparts(argList{1});
                    if exist(parentDir, 'dir')
                        obj.FilePath = argList{1};
                        argList = argList(2:end);
                    else
                        error('Can not create a Catalog at the given file path. Check that folder exists')
                    end
                end
            end
        end
        
        function S = addUuidIfMissing(~, S)
            %addUuidIfMissing 
            
            if isfield(S.Data, 'Uuid'); return; end
           
            originalFieldNames = fieldnames(S.Data);
            
            for i = 1:numel(S.Data)
                S.Data(i).Uuid = nansen.util.getuuid();
            end
            
            if isempty(S.Data) % Alternative way to add field for empty struct
                [S.Data.Uuid] = {};
            end
            
            S.Data = orderfields(S.Data, ['Uuid'; originalFieldNames]);
        end
        
    end
    
    methods (Static)
        
        function h = new()
        
        end
        
        function open(filePath)
            
        end
        
    end
    
    methods (Static, Access = private)
        
        function tf = isuuid(value)
            
            tf = false;
            
            if ischar(value)
                expression = '\w{8}-\w{4}-\w{4}-\w{4}-\w{12}';
                tf = ~isempty(regexp(value, expression, 'once'));
            end
        end
    end

end



% % % Subclass Template
% % classdef SUBCLASSNAME < utility.data.StorableCatalog
% % %
% % 
% %     properties (Constant, Access = protected)
% %         ITEM_TYPE = 'TYPE_NAME'
% %     end
% %     
% %     methods (Static) % Get empty and default item
% %         
% %         function S = getBlankItem()
% %             S = struct();
% %         end
% %         
% %         function S = getEmptyItem()
% %             S = struct();
% %         end
% %         
% %         function S = getDefaultItem()
% %             S = struct();
% %         end
% %         
% %     end 
% %     
% %     methods % Constructor
% %         
% %         function obj = SUBCLASSNAME(varargin)
% %             
% %             % Superclass constructor. Loads given (or default) archive 
% %             obj@utility.data.StorableCatalog(varargin{:})
% %             
% %         end
% %         
% %     end
% %      
% %     methods (Access = protected)
% %         
% %         function item = validateItem(obj, item)
% %             % Todo...
% %         end
% %         
% %     end
% %     
% %     methods (Static)
% %         
% %         function pathString = getDefaultFilePath()
% %         %getDefaultFilePath Get filepath for loading/saving filepath settings   
% %             fileName = 'FILE_NAME';
% %             try
% %                 pathString = nansen.config.project.ProjectManager.getProjectSubPath(fileName);
% %             catch
% %                 pathString = '';
% %             end
% %         end
% % 
% %     end
% %     
% % end
% % 
