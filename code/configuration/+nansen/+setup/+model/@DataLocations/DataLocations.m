classdef DataLocations < utility.data.ObjectCatalog
    %DATALOCATIONS Interface for detecting path of data/session folders
    
    
    % TODOS:
    %   [x] Combine code from getSubjectId and getSessionId into separate
    %       methods.
    
    % QUESTIONS:
    
    properties (Dependent, SetAccess = private)
        NumDataLocations 
    end
    
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
                'StringDetectInput', repmat({''}, 1, numVars), ...
                'StringFormat', repmat({''}, 1, numVars));
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
    
    methods % Set/get methods
    
        function numDataLocations = get.NumDataLocations(obj)
            numDataLocations = numel(obj.Data);
        end
    end
    
    methods 
        function setGlobal(obj)
            global dataLocationModel
            dataLocationModel = obj;
        end
        
        function validateRootPath(obj, dataLocIdx)
            
            % Todo: Loop through all entries in cell array (if many are present) 
            
            thisDataLoc = obj.Data(dataLocIdx);
            if ~isfolder(thisDataLoc.RootPath{1})
                thisName = obj.Data(dataLocIdx).Name;
                error('Root path for DataLocation "%s" does not exist', thisName)
            end
            
        end
        
        function createRootPath(obj, dataLocIdx)
            thisRootPath = obj.Data(dataLocIdx).RootPath{1};
            if ~isfolder(thisRootPath)
                mkdir(thisRootPath)
                fprintf('Created root directory for DataLocation %s', obj.Data(dataLocIdx).Name)
            end
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
            
            S = obj.getMetavariableStruct('Animal ID');
            substring = obj.getSubstringFromFolder(pathStr, S);

        end
        
        function substring = getSessionID(obj, pathStr)
            
            S = obj.getMetavariableStruct('Session ID');
            substring = obj.getSubstringFromFolder(pathStr, S);
            
            % If no substring is retrieved, used the foldername of the last
            % folder in the pathstring.
            if isempty(substring)
                [~, substring] = fileparts(pathStr);
            end

        end
        
        function value = getTime(obj, pathStr)
            
            S = obj.getMetavariableStruct('Experiment Time');
            substring = obj.getSubstringFromFolder(pathStr, S);
            
            % Convert to datetime type.
            if ~isempty(substring) && ~isempty(S.StringFormat)
                value = datetime(substring, 'InputFormat', S.StringFormat);
                value.Format = 'HH:mm:ss'; % Format output as a time.
            else
                value = substring;
            end
        end
        
        function value = getDate(obj, pathStr)
            
            S = obj.getMetavariableStruct('Experiment Date');
            substring = obj.getSubstringFromFolder(pathStr, S);
            
            % Convert to datetime type.
            if ~isempty(substring) && ~isempty(S.StringFormat)
                value = datetime(substring, 'InputFormat', S.StringFormat);
            else
                value = substring;
            end
            
        end
        
    end
    
    methods (Access = protected)
        
        function S = getMetavariableStruct(obj, varName)
        %getMetavariableStruct Get metadata struct for given variable
        %
        % Get struct containing instructions for how to find substring
        % (value of a metadata variable) from a directory path.
            
            dataLocIdx = 1;
            S = obj.Data(dataLocIdx).MetaDataDef;

            % Find struct entry corresponding to requested variable
            variableIdx = strcmp({S.VariableName}, varName);
            S = S(variableIdx);
                
            % Need to know how many subfolders the data location has
            numSubfolders = numel(obj.Data(dataLocIdx).SubfolderStructure);
            S.NumSubfolders = numSubfolders;

        end
           
        
        
        function substring = getSubstringFromFolder(obj, pathStr, S)
        %getSubstringFromFolder Find substring from a pathstring.
        %
        %   substring = getSubstringFromFolder(obj, pathStr, varName) Get a
        %   substring containing the value of a variable given by varName.
        %   The substring is obtained from the given pathStr based on
        %   instructions from the DataLocationModel's MetaDataDef property.
        
        % Initialize output
            substring = '';

            mode = S.StringDetectMode;
            strPattern = S.StringDetectInput;
            folderLevel = S.SubfolderLevel;
            
            % Abort if instructions are not present.
            if isempty(strPattern) || isempty(folderLevel)
                return;    
            end
            
            % Get the index of the folder containing the substring,
            % counting backward from the deepest subfolder level.
            reversedFolderIdx = S.NumSubfolders - folderLevel;
            
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
                pathString = nansen.config.project.ProjectManager.getFilePath(fileName);
            catch
                pathString = '';
            end
        end
        
    end
    
end

