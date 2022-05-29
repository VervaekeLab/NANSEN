classdef DataIoModel < handle
%nansen.dataio.DataIoModel Map a variable to a file on disk.
%
%   Superclass for classes that provide save/load functionality.
%
%   Methods: loadData, saveData, getFilePath
%
%   File specifications are editable, but have default values.
%


%   Todo: 
%
%       [ ] Incorporate the datalocation model + filepath model.
%       [ ] Temporary saving results in a different location, i.e on an SSD drive.


    properties
        DataId
        FileName            % A part of filename which is given to all files
        FolderPath          % The initial directory for saving data
        DataLocation
    end
    
    properties (Access = private)
        DataLocationType = '' % 'InPlace', 'MultiLocation', ''
    end
    
    properties (SetAccess = private)
        FilePathModel
        DataLocationModel
    end

    methods (Abstract)
        name = getDataId(obj)
    end
    
    methods % Constructor
        
        function obj = DataIoModel(varargin)
        %nansen.dataio.DataIoModel Construct a DataIoModel object
        %
        %   h = nansen.dataio.DataIoModel(filePath)

            if isempty(varargin) || (numel(varargin) == 1 && isempty(varargin{1}))
                % Pass
            
            elseif ischar(varargin{1}) && isfile(varargin{1})
               [folder, name] = fileparts(varargin{1});
                obj.FolderPath = folder;
                obj.FileName = name;
                obj.DataLocation = folder;
                
            elseif ischar(varargin{1}) && isfolder(varargin{1})
                obj.FolderPath = varargin{1};
                obj.DataLocation = obj.FolderPath;
                if numel(varargin) <= 2
                    obj.FileName = varargin{2};
                end
            elseif ischar(varargin{1})
                [folder, ~, ext] = fileparts(varargin{1});
                if ~isempty(folder) && ~isempty(ext)
                    errId = 'Nansen:IOModel:FileNotFound';
                    throw(nansen.dataio.getException(errId))
                else
                    errId = 'Nansen:IOModel:WrongInput';
                    throw(nansen.dataio.getException(errId))
                end
                
            elseif isa(varargin{1}, 'struct') % Todo: Object???
                
            else
                errId = 'Nansen:IOModel:WrongInput';
                throw(nansen.dataio.getException(errId))
            end
            
            % Set FilePathModel %Todo: Do we need to get it from a global
            % variable. Why??
            global dataFilePathModel dataLocationModel
            if isempty(dataFilePathModel)
                dataFilePathModel = nansen.dataio.FilePathSettingsEditor;
            end
            
            obj.FilePathModel = dataFilePathModel;

            if isempty(dataLocationModel)
                dataLocationModel = nansen.dataio.DataLocations();
            end
            
            obj.DataLocationModel = dataLocationModel;
            
        end
        
    end

    methods % Load data variables
        
        function data = loadData(obj, varName, varargin)
        %loadData Load data given a variable name
        %
        %   data = h.loadData(varName) returns data according to the 
        %   specifications for the variable with the given varName.
        

            % TODO:
            %   [ ] Implement file adapters.
            
            filePath = obj.getDataFilePath(varName, '-r', varargin{:});
            
            if isfile(filePath)
                S = load(filePath, varName);
                if isfield(S, varName)
                    data = S.(varName);
                else
                    error('File does not hold specified variable')
                end
            else
                error('File not found')
            end
            
        end
        
        function saveData(obj, varName, data, varargin)
        %saveData Save data given a variable name
        %
        %   h.saveData(varName, data) saves data according to the
        %   specification for the variable represented by varName.

            % TODO:
            %   [ ] Implement file adapters.
            
            filePath = obj.getDataFilePath(varName, '-w', varargin{:});
            
            S.(varName) = data;
            
            varInfo = whos('data');
            byteSize = varInfo.bytes;
            
            if byteSize > 2^31
                save(filePath, '-struct', 'S', '-v7.3')
            else
                save(filePath, '-struct', 'S')
            end


        end
        
        function pathStr = getDataFilePath(obj, varName, varargin)
        %getDataFilePath Get absolute filepath for a data variable
        %
        %   pathStr = h.getDataFilePath(varName) returns an absolute
        %   filepath (pathStr) for data with the given variable name 
        %   (varName).
        %
        %   pathStr = h.getDataFilePath(varName, mode) returns the
        %   filepath subject to the specified MODE:
        %       '-r'    : Get filepath of existing file (Default)
        %       '-w'    : Get filepath of existing file or create filepath
        %
        %   pathStr = sessionObj.getDataFilePath(__, Name, Value) uses 
        %   name-value pair arguments to control aspects of the filename.
        %
        %   PARAMETERS:
        %
        %       Subfolder : If file is in a subfolder of sessionfolder.
        %
        %
        %   EXAMPLES:
        %
        %       pathStr = h.getFilePath('dff', '-w', 'Subfolder', 'roisignals')
        
            
            % Todo: 
            %   [ ] (Why) do I need mode here?
            %   [ ] Implement load/save differences, and default datapath
            %       for variable names that are not defined.
            %   [ ] Implement ways to grab data spread over multiple files, i.e
            %       if files are separate by imaging channel, imaging plane,
            %       trials or are just split into multiple parts...
            
            
            % Check if mode is given as input:
            [mode, varargin] = obj.checkDataFilePathMode(varargin{:});
            parameters = struct(varargin{:});
            
            % Get the entry for given variable name from model
            [S, isExistingEntry] = obj.FilePathModel.getEntry(varName);
        
            % Get path to data folder
            dataFolderPath = obj.getDataFolder(S.DataLocation, mode);
            
            % Check if file should be located within a subfolder.
            if isfield(parameters, 'Subfolder') && ~isExistingEntry
                S.Subfolder = parameters.Subfolder;
            end
            
            if ~isempty(S.Subfolder)
                dataFolderPath = fullfile(dataFolderPath, S.Subfolder);
                
                if ~isfolder(dataFolderPath) && strcmp(mode, 'write')
                    mkdir(dataFolderPath)
                end
            end
            
            
            if isempty(S.FileNameExpression)
                fileName = obj.createFileName(varName, parameters);
            else
                fileName = obj.lookForFile(dataFolderPath, S);
                if isempty(fileName)
                    fileName = obj.getFileName(S);
                end
            end
            
            pathStr = fullfile(dataFolderPath, fileName);
            
            % Save filepath entry to filepath settings if it did
            % not exist from before...
            if ~isExistingEntry && strcmp(mode, 'write')
                obj.FilePathModel.addEntry(S)
            end
            
        end
        
        function folderPath = getDataFolder(obj, dataLocationType, mode)
        %getDataFolder Get data folder for a dataLocationType
        
            if nargin < 2
                dataLocationType = '';
            end
            
            if nargin < 3
                mode = 'read';
            end
            
            % Todo: Save directly in folde if it is assigned...
%             if ~isempty(obj.FolderPath)
%                 folderPath = obj.FolderPath; return; 
%             end
                
            % Otherwise, use the datalocation schema...
            if ischar(obj.DataLocation) && isfolder(obj.DataLocation)
                folderPath = fullfile(obj.DataLocation, dataLocationType);
        
            elseif isfield(obj.DataLocation, dataLocationType)
                folderPath = obj.DataLocation.(dataLocationType);
            
            else
                dataLocTypes = {obj.DataLocationModel.Data.Name};
                    
                if ~any( strcmp(dataLocTypes, dataLocationType) )
                    error(['Data location type ("%s") is not valid. Please use one of the following:\n', ...
                           '%s'], dataLocationType, strjoin(dataLocTypes, ', ') )
                else
                    folderPath = obj.createDataFolder(dataLocationType);
                end
                
            end
            
            if ~isfolder(folderPath) && strcmp(mode, 'read')
                error('Data folder not found')
            elseif ~isfolder(folderPath) && strcmp(mode, 'write')
                mkdir(folderPath)
                fprintf('Created folder: %s\n', folderPath)
            end
            
        end
        
    end
    
    methods (Access = protected)
        
        function [mode, varargin] = checkDataFilePathMode(~, varargin)
        %checkDataFilePathMode Check if access mode is part of varargin
        
            % Default mode is read:
            mode = 'read';
            
            if ~isempty(varargin) && ischar(varargin{1})
                switch varargin{1}
                    case '-r'
                        mode = 'read';
                        varargin = varargin(2:end);
                    case '-w'
                        mode = 'write';
                        varargin = varargin(2:end);
                end
            end
            
        end
        
        function fileName = lookForFile(obj, dataFolderPath, S)
        %lookForFile Look for file using provided specifications
        
            % Todo: Move this method to filepath settings editor.
            
            expression = S.FileNameExpression;
            fileType = S.FileType;
            
            if contains(expression, fileType)
                expression = ['*', expression];
            else
                expression = ['*', expression, fileType]; % Todo: ['*', expression, '*', fileType] <- Is this necessary???
            end
            
            L = dir(fullfile(dataFolderPath, expression));
            L = L(~strncmp({L.name}, '.', 1));
            
            if ~isempty(L) && numel(L)==1
                fileName = L.name;
            elseif ~isempty(L) && numel(L)>1
                error('Multiple files were found')
            else
                fileName = '';
            end
            
        end
        
        function fileName = createFileName(obj, varName, parameters)
        %createFileName Create filename for data variable
        %
        %   Start with base name, add an underscore version of the matlab
        %   variable name and add file extension to the end.

            %sid = obj.sessionID;
            baseName = obj.FileName;
            
            
            capLetterStrInd = regexp(varName, '[A-Z, 1-9]');

            for i = fliplr(capLetterStrInd)
                if i ~= 1
                    varName = insertBefore(varName, i , '_');
                end
            end
            
            varName = lower(varName);
            
            fileName = sprintf('%s_%s', baseName, varName);
            
            if isfield(parameters, 'FileType')
                fileExtension = parameters.FileType;
                if ~strncmp(fileExtension, '.', 1)
                    fileExtension = strcat('.', fileExtension);
                end
            else
                fileExtension = '.mat';
            end
            
            fileName = strcat(fileName, fileExtension);

        end
        
        function fileName = getFileName(obj, S)
            
            %sid = obj.sessionID;
            baseName = obj.FileName;

            fileName = sprintf('%s_%s', baseName, S.FileNameExpression);
            
            fileType = S.FileType;
            
            if ~strncmp(fileType, '.', 1) % Remove . from ".mat"
                fileType = strcat('.', fileType);
            end
            
            fileName = strcat(fileName, fileType);
            
        end
        
        function folderPath = createDataFolder(obj, dataLocationName)
            
            % Get data location model. Question: Better way to do this?
            S = obj.DataLocationModel.getDataLocation(dataLocationName);
            
            rootPath = S.RootPath{1};
            
            folderPath = rootPath;
            
            for i = 1:numel(S.SubfolderStructure)
                
                switch S.SubfolderStructure(i).Type
                    
                    case 'Animal'
                        folderName = sprintf('subject-%s', obj.subjectID);
                    case 'Session'
                        folderName = sprintf('session-%s', obj.sessionID);
                    case 'Date'
                        folderName = obj.Date;
                    case 'Time'
                        folderName = obj.Time;
                    otherwise
                        folderName = S.SubfolderStructure(i).Name;
                        
                        if isempty(folderName)
                            error('Can not create session folder because foldername is not specified')
                        end
                end
                
                folderPath = fullfile(folderPath, folderName);
                
            end
            
            if ~isfolder(folderPath)
                mkdir(folderPath)
            end
            
            obj.DataLocation.(dataLocationName) = folderPath;
            
            if ~nargout
                clear folderPath
            end

        end
        
    end
    
    
    methods (Static) % Function in external file
        ME = getException(errorId)
    end

end