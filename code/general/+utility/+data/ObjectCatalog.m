classdef ObjectCatalog < handle
%Catalog An exportable table with methods for interacting with entries.
%
%

% Name suggestions:
%   StructArchive
%   StructRegistry
%   StructCatalog

%   ObjectArchive
%   ObjectArray

    properties (Constant, Abstract)
        %OBJECTCLASS % necessary?
    end
      
    
    properties
        FilePath char
        Preferences
        Data struct % Todo: Rename ?
    end
    
    
    methods (Abstract)
        h = getEmptyObject(obj)
    end
    
    methods (Abstract, Static)
        
        S = getDefaultEntry()
        
        pathStr = getDefaultFilePath()
    end

    
    methods % Constructor
        
        function obj = ObjectCatalog(varargin)
            
            obj.parseVarargin(varargin{:})
            
            if ~isempty(obj.FilePath) && isfile(obj.FilePath)
                obj.load()
            end
            
        end
        
    end
    
    
    methods
        
        function disp(obj)
        %disp Override disp method to show table of objects in Catalog
        
        % Todo: Format this better. Show properties as well?
        
            titleTxt = sprintf(['<a href = "matlab: helpPopup %s">', ...
                '%s</a> with available entries:'], class(obj), class(obj) );
            
            T = struct2table(obj.Data, 'AsArray', true);
            fprintf('%s\n\n', titleTxt)
            disp(T)
            fprintf('\nLocated at %s\n\n', obj.FilePath)

        end
        
        function refreshFilePath(obj)
            obj.FilePath = obj.getDefaultFilePath();
        end
        
        function refresh(obj)
            obj.FilePath = obj.getDefaultFilePath();
            obj.load()
        end
        
        function initializeWithDefault(obj)
            obj.Data = obj.getDefaultEntry();
        end
        
        function obj = default(obj)
            obj.initializeWithDefault()
        end
        
        function load(obj)
        %load Load data from file 
        
        % Todo: Load Preferences and Data
        
            if ~exist(obj.FilePath, 'file')
                S.Data =  obj.getEmptyObject();
                S.Preferences = struct();
            else
                S = load(obj.FilePath, 'Data', 'Preferences');
            end
            
            obj.fromStruct(S);
            
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
        
        function insertObject(obj, newObject)
            obj.Data(end+1) = newObject;
        end
        
        function removeObject(obj, objectID)
            
        end
        
        function S = getObject(obj, objectID)
            ind = find(contains({obj.Data.Name}, objectID));
            S = obj.Data(ind);
        end
        
        function ismember(obj, objectID)
            
        end
        
        function containsObject(obj, objectID)
            
        end
        
        function setFilePath(obj, filePath)
            
            folderPath = fileparts(filePath);
            if ~exist(folderPath, 'dir'); mkdir(folderPath); end
            
            obj.FilePath = filePath;
            
        end
        
        function setData(obj, dataStruct)
            obj.Data = dataStruct; 
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