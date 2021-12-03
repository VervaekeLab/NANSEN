classdef DataLocations < utility.data.ObjectCatalog
    %DATALOCATIONS Interface for detecting path of data/session folders
    
    
    % TODOS:
    %   [x] Combine code from getSubjectId and getSessionId into separate
    %       methods.
    
    % QUESTIONS:
    
    
    
    methods (Static) % Methods in separate files
        S = getDefaultEntry()
    end

    methods (Static)
        
        function S = getEmptyObject()
            
            S = struct;
            
            S.Name = '';
            S.RootPath = {'', ''};
            S.ExamplePath = '';
            S.DataSubfolders = {};

            S.SubfolderStructure = nansen.setup.model.DataLocations.getDefaultSubfolderStructure();
            S.MetaDataDef = nansen.setup.model.DataLocations.getDefaultMetadataStructure();
        end
        
        function S = getDefaultMetadataStructure()
            
            varNames = {'Animal ID', 'Session ID', 'Experiment Date', 'Experiment Time'};
            %varNames = {'Animal ID', 'Session ID'};
            numVars = numel(varNames);
            
            S = struct(...
                'VariableName', varNames, ...
                'SubfolderLevel', {[]}, ...
                'StringDetectMode', repmat({'ind'}, 1, numVars), ...
                'StringDetectInput', repmat({''}, 1, numVars) );
        end
        
        function S = getDefaultSubfolderStructure()
        %getDefaultSubfolderStructure Create a default struct
            S = struct(...
                'Name', '', ...
                'Type', '', ...
                'Expression', '', ...
                'IgnoreList', {{}} );
        end
        
    end
    
    methods % Constructor 
        function obj = DataLocations(varargin)
            
            obj@utility.data.ObjectCatalog(varargin{:})
            
            if isempty(obj.FilePath)
                obj.FilePath = obj.getDefaultFilePath();
            end
            
            obj.load()
        end
    end
    
    methods 
        function setGlobal(obj)
            global dataLocationModel
            dataLocationModel = obj;
        end
    end
    
    methods % Methods for updating substructs of data location
         
        function updateMetaDataDefinitions(obj, S)
        %updateMetaDataDefinitions Update the metadata definition struct
        %
        %   Just replaces the struct in the MetaDataDef property with the
        %   input struct S.
        
            dataLocIdx = 1;
            obj.Data(dataLocIdx).MetaDataDef = S;
            
        end
        
        function updateSubfolderStructure(obj, S, idx)
        %updateSubfolderStructure Update the SubfolderStructure struct
        %
        %   Just replaces the struct in the SubfolderStructure property 
        %   with the input struct S.
        
            if nargin < 3
                idx = 1;
            end
            
            obj.Data(idx).SubfolderStructure = S;
            
            subFolderNames = {S.Name};
            obj.Data(idx).ExamplePath = fullfile(obj.Data(idx).RootPath{1}, subFolderNames{:});
            
        end
        
    end
    
    methods % Methods for accessing/modifying entries
        
        function S = getDataLocation(obj, dataLocationName)
            S = obj.getObject(dataLocationName);
            
            %ind = find(contains({obj.Data.Name}, dataLocationName));
            %S = obj.Data(ind);
        end
        
        function addDataLocation(obj, newDataLocation)
            insertObject(obj, newDataLocation)
        end
        
        function pathStr = getExampleFolderPath(obj, dataLocName)
            
            ind = find(contains({obj.Data.Name}, dataLocName));
            pathStr = obj.Data(ind).ExamplePath;
            
            
        end
        
    end
    
    methods % Methods for getting data descriptions from filepaths
        
        function substring = getSubjectID(obj, pathStr)
            % Todo: Specify index as well....
            
            substring = obj.getSubstringFromFolder(pathStr, 'Animal ID');

        end
        
        function substring = getSessionID(obj, pathStr)
                        
            substring = obj.getSubstringFromFolder(pathStr, 'Session ID');
            
            % If no substring is retrieved, used the foldername of the last
            % folder in the pathstring.
            if isempty(substring)
                [~, substring] = fileparts(pathStr);
            end

        end
        
        function substring = getTime(obj, pathStr)
            substring = obj.getSubstringFromFolder(pathStr, 'Experiment Time');
            
            % Todo: Convert to datetime type.
        end
        
        function substring = getDate(obj, pathStr)
                    
            substring = obj.getSubstringFromFolder(pathStr, 'Experiment Date');
            
            % Todo: Convert to datetime type.
        end
        
    end
    
    methods (Access = protected)
        function substring = getSubstringFromFolder(obj, pathStr, varName)
        %getSubstringFromFolder Find substring from a pathstring.
        %
        %   substring = getSubstringFromFolder(obj, pathStr, varName) Get a
        %   substring containing the value of a variable given by varName.
        %   The substring is obtained from the given pathStr based on
        %   instructions from the DataLocationModel's MetaDataDef property.
        
        % Initialize output
            substring = '';
            
            % Get struct containing instructions for how to find substring
            idxA = 1;
            S = obj.Data(idxA).MetaDataDef;
            
            numSubfolders = numel(obj.Data(idxA).SubfolderStructure);
            
            % Find struct entry corresponding to requested variable
            idxB = strcmp({S.VariableName}, varName);

            mode = S(idxB).StringDetectMode;
            strPattern = S(idxB).StringDetectInput;
            folderLevel = S(idxB).SubfolderLevel;
            
            % Abort if instructions are not present.
            if isempty(strPattern) || isempty(folderLevel)
                return;    
            end
            
            % Get the index of the folder containing the substring,
            % counting backward from the deepest subfolder level.
            reversedFolderIdx = numSubfolders - folderLevel;
            
            folderNames = strsplit(pathStr, filesep);
            folderName = folderNames{end-reversedFolderIdx}; % Unpack from cell array
            
            % Get the substring using either indexing or regular
            % expressions.
            try
                switch lower(mode)

                    case 'ind'
                        %substring = folderName(strPattern);
                        substring = eval( ['folderName([' strPattern '])'] );
                        
                    case 'expr'
                        substring = regexp(folderName, strPattern, 'match', 'once');
                end
            catch
                substring = '';
            end
            
        end
    end
    
    methods (Hidden, Access = protected) 
        
    end
    
    methods (Static)
        
        function pathString = getDefaultFilePath()
        %getFilePath Get filepath for loading/saving datalocation settings   
            fileName = 'DataLocationSettings';
            try
                pathString = nansen.setup.model.ProjectManager.getFilePath(fileName);
            catch
                pathString = '';
            end
        end
        
    end
    
end

