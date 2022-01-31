classdef TabularArchive < handle
%Catalog An archivable table with methods for interacting with items.
%
%   Superclass for tabular archives. A specific instance will have a 1-to-1
%   relationship with the data stored in file. The data in the archive is a
%   table (internally stored as struct array for more flexibility). Each
%   element in the struct array is referred to as an item, and the fields
%   of each item has to be specified in the subclass definition
%
%   Abstract Properties:
%       ITEM_TYPE
%
%   Abstract Methods:
%       getEmptyItem()
%       getDefaultItem()
%       validateItem()
%
%   Key features:
%       Should be singleton-ish
%       Provide api and gui (separate class?) functionality for editing. 
%       Access and modify entries by name...


% Note, this could have been implemented better with more objectification,
% but that unfortunately did not happen:(

% Name suggestions:
%   StructArchive
%   StructCatalog


% Todo:
%       Inherit from singletonish
%       addpref and removepref methods

% Questions:
%     - Should data be a struct or a table?
%     - Should Data be observable? Or DataChanged event? 
%           SetAccess public or protected??? 
%     - Why struct and not table?

    properties (Abstract, Constant, Access = protected)
        ITEM_TYPE
    end

    properties (SetAccess = protected)
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
    
    
    methods (Abstract)
        h = getEmptyItem(obj)
    end
    
    methods (Abstract, Static)
        
        S = getDefaultItem()
        
        pathStr = getDefaultFilePath()
        
    end
    
    methods (Abstract, Access =  protected)
        item = validateItem(obj, item)
    end
    
    
    methods % Constructor
        
        function obj = TabularArchive(varargin)
            
            obj.parseVarargin(varargin{:})
            
            if ~isempty(obj.FilePath) && isfile(obj.FilePath)
                obj.load()
            end
            
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

        function load(obj)
        %load Load data from file
        
            if ~isfile(obj.FilePath)
                S.Data =  obj.getEmptyItem();
                S.Preferences = struct();
            else
                S = load(obj.FilePath, 'Data', 'Preferences');
            end
            
            obj.fromStruct(S);
            
            obj.assignItemNames() 
            
        end
        
        function save(obj)
        %save Save data to file
            S = obj.toStruct; %#ok<NASGU>
            save(obj.FilePath, '-struct', 'S')
        end
        
        function saveas(obj, filePath)
        %save Save data to file at file path given as input
            S = obj.toStruct; %#ok<NASGU>
            save(filePath, '-struct', 'S')
        end
        
    end
    
    methods % Methods for manipulating entries
                
        function insertItem(obj, newItem)
            
            % Make sure item has necessary fields...
            newItem = obj.validateItem(newItem);
            
            insertIdx = numel(obj.Data) + 1;
            
            % Make sure not to insert item with name that already exist...
            newItemName = obj.getItemName(newItem);
            if obj.contains(newItemName)
                message = sprintf('A %s with the name "%s" already exists', ...
                    obj.ITEM_TYPE, newItemName);
                error(message); %#ok<SPERR>
            end
            
            % Todo: Should newItem replace old item if an item with the
            % name already exists? Or make separate replace method?

            obj.Data(insertIdx) = newItem;
            
            obj.assignItemNames()
            obj.save()
            
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
        
        function initializeWithDefault(obj)
            obj.Data = obj.getDefaultItem();
        end
        
        function obj = default(obj)
            obj.initializeWithDefault()
        end

        function [S, idx] = getItem(obj, itemName)
                    
            if isnumeric(itemName) % Assume index was given instead of name
                idx = itemName;
            else
                idx = find(strcmp(obj.ItemNames, itemName));
            end
            
            S = obj.Data(idx);
            
            if nargout == 1
                clear idx
            end
            
        end
        
        function name = getItemName(obj, item)
            
            fieldNames = fieldnames(obj.Data);
            idName = fieldNames{1};
            
            name = item.(idName);
            
        end

        function [Lia, Locb] = ismember(obj, itemName)
        %ismember 
            
            Lia = ismember(obj.ItemNames, itemName);
            
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
        
    end
    
    
    methods (Access = protected)
        
        function assignItemNames(obj)
        %assignItemNames Assign names of all items to property
        
            % Assumes the "Name" is the first fieldname. Todo: generalize
            fieldNames = fieldnames(obj.Data);
            idName = fieldNames{1};
            
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
        
    end

    
    methods (Static)
        
        function h = new()
        
        end
        
        function open(filePath)
            
        end
        
    end

end