classdef SingleFolderDataSet < nansen.dataio.DataSet
% Class for creating a dataset in a folder on the file system. 
%   A DataSet is a list of data variables that are mapped to a single file 
%   or to multiple files. For the SingleFolderDataSet, all data variables 
%   are by default assigned to an individual folder (with subfolders) on 
%   the file system.
%   
%   
%   
%   See also nansen.dataio.DataSet
    
%   Note: This class is created to work in the same way as a session
%   object. In the future, the aim is to extract all the "dataset" related
%   code from the session class and create a SessionDataSet class. The
%   SessionDataSet and the SingleFolderDataSet should be subclasses of the
%   nansen.dataio.DataSet superclass.
%
%   An alternative is to have one DataSet class but implement different
%   variations of DataLocations and VariableLists. The DataLocations and
%   Variable lists should be designed with the Strategy pattern in mind.


    properties (SetAccess = private)
        FolderPath = '' % The initial directory for saving data
    end

    properties (Dependent)
        NumVariables
        VariableNames
    end
    
    properties (Access = private)
        VariableList struct
    end
    
    methods % Constructor
        
        function obj = SingleFolderDataSet(initialPath, varargin)
        %SingleFolderDataSet Construct a SingleFolderDataSet object
        %
        %   obj = SingleFolderDataSet(initialPath) create a dataset in the
        %   given path. If initialPath is the path to a folder, the
        %   dataset is created in that folder, while if initialPath is a 
        %   file, the dataset is created in the folder containing the file.
        %
        %   obj = SingleFolderDataSet(initialPath, Name, Value) creates a
        %   dataset where name, value pairs specifies custom options.


            if ~nargin; return; end

            if isfile(initialPath)
                [initialPath, ~] = fileparts(initialPath);
            elseif isfolder(initialPath)
                % pass
            else
                if ischar(initialPath)
                    errorID = 'Nansen:DataSet:InvalidInitialPath';
                    error(errorID, obj.getErrorMessage(errorID));
                else
                    errorID = 'Nansen:DataSet:InvalidInput';
                    error(errorID, obj.getErrorMessage(errorID));
                end
            end

            obj.FolderPath = initialPath;
            obj.assignPVPairs(varargin{:})
        end

    end

    methods % Set/get

        function numVariables = get.NumVariables(obj)
            numVariables = numel(obj.VariableList);
        end

        function varNames = get.VariableNames(obj)
            varNames = {obj.VariableList.VariableName};
        end
    end


    methods % Public methods
        
        function [filePath, variableInfo] = getDataFilePath(obj, varName, varargin)
        %getDataFilePath Get filepath for data with the given variable name
        %
        %
            
            % Check if mode is given as input:
            [mode, varargin] = obj.checkDataFilePathMode(varargin{:});

            if obj.existVariableItem(varName)
                variableItem = obj.getVariableItem(varName);
                filePath = variableItem.FilePath;

            else
                variableItem = obj.initializeVariableItem(varName, varargin{:});
                fileName = obj.createFileName(varName, variableItem);
                variableItem.FileName = fileName;

                folderPath = obj.FolderPath;
    
                if ~isempty(variableItem.Subfolder)
                    folderPath = fullfile( folderPath, variableItem.Subfolder);
                end
    
                filePath = fullfile(folderPath, fileName);
                
                if strcmp(mode, 'write')
                    variableItem.FilePath = filePath;
                    obj.insertVariableItem(variableItem)
                end
            end

            if nargout == 2
                variableInfo = variableItem;
            end
        end

        function data = loadData(obj, varName, varargin)
            
            % Check if variable is part of dataset data exists 
            if obj.existVariableItem(varName)
                variableItem = obj.getVariableItem(varName);
                if ~isempty(variableItem.Data)
                    data = variableItem.Data;
                    return
                end
            end

            % Otherwise, get data from file
            filePath = obj.getDataFilePath(varName);

            if isfile(filePath)
                S = load(filePath, varName);
                if isfield(S, varName)
                    data = S.(varName);
                else
                    error('File does not contains specified variable')
                end
            else
                error('File not found')
            end
            
        end

        function saveData(obj, varName, data, varargin)
                
            [filePath, ~] = obj.getDataFilePath(varName, '-w', varargin{:});
            
            folderPath = fileparts(filePath);
            if ~isfolder(folderPath); mkdir(folderPath); end

            % Todo: implement fileadapters.

            S.(varName) = data;
            save(filePath, '-struct', 'S')
        end

        function addVariable(obj, varName, varargin)
            
            assert( ~obj.existVariableItem(varName), ['Variable with name ', ...
                '"%s" already exists for this DataSet'], varName )

            variableItem = obj.initializeVariableItem(varName, varargin{:});

            if isempty(obj.VariableList)
                obj.VariableList = variableItem;
            else
                obj.VariableList(end+1) = variableItem;
            end

        end

        function insertVariableItem(obj, variableItem)
            obj.VariableList(end+1) = variableItem;
        end

        function replaceVariable(obj, varName, varargin)
            
            assert( obj.existVariableItem(varName), ['Variable with name ', ...
                '"%s" does not exist for this DataSet'], varName )

            idx = obj.findVariableItem(varName);
            variableItem = obj.initializeVariableItem(varName, varargin{:});
            obj.VariableList(idx) = variableItem;
        end

        function removeVariable(obj, varName, varargin)
            assert( obj.existVariableItem(varName), ['Variable with name ', ...
                '"%s" does not exist for this DataSet'], varName )

            idx = findVariableItem(obj, varName);
            obj.VariableList(idx) = [];
        end
        
    end

    
    methods (Access = protected)


    end

    methods (Access = private)
        
        function existVariable(obj, varName)


        end
        
        function S = initializeVariableItem(obj, varName, varargin)
        %initializeVariableItem Initialize a variable item struct

            S = struct;
            S.VariableName = varName;
            S.FileName = '';
            S.FileType = 'mat';
            S.Subfolder = '';
            S.FilePath = '';
            S.Data = [];
            S.FileAdapterName = '';

            S = utility.parsenvpairs(S, 1, varargin{:});

        end
        
        function tf = existVariableItem(obj, varName)
            if isempty(obj.VariableList); tf = false; return; end
            tf = any(strcmp({obj.VariableList.VariableName}, varName));
        end
        
        function idx = findVariableItem(obj, varName)
            if isempty(obj.VariableList); idx = []; return; end
            idx = strcmp({obj.VariableList.VariableName}, varName);
        end
        
        function S = getVariableItem(obj, varName)
            S = struct.empty;
            if isempty(obj.VariableList); return; end
            idx = strcmp({obj.VariableList.VariableName}, varName);
            if ~isempty(idx)
                S = obj.VariableList(idx);
            end
        end
        
    end
    
    methods (Access = private)
        
        function msg = getErrorMessage(~, errorID)
        %getErrorMessage Get class specific error message given error id   
            switch errorID

                case 'Nansen:DataSet:InvalidInitialPath'
                    msg = ['The given input should point to an ', ...
                           'existing file or folder'];

                case 'Nansen:DataSet:InvalidInput'
                    msg = ['The given input should be a character ', ...
                           'vector pointing to an existing file or folder'];
            end
        end
        
    end

end