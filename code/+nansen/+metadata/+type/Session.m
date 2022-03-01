classdef Session < nansen.metadata.abstract.BaseSchema
%Session A generic metadata schema for an experimental session.
%
%
%   This class provides general metadata about an experimental session and
%   methods for accessing experimental data.

%   Questions: 
%       - Is it better to have get/create session folders as methods in
%         DataLocations (the model)

%   Todo:
%       [ ] Implement methods for saving processing/analysis results to
%           multiple times based on timestamping... New data location type:
%           "Analyzed", where everytime a variable is saved, it is saved with
%           a timestamp.
%       [ ] Spin off loadData/saveData to a separate class (superclass)
%       [ ] Implement save method... If changes are made, they need to be
%           saved to file... But also table.....
%       [ ] Add listener on DataLocationModel events... Update internal
%           datalocation struct. Should session inherit HasDataLocationModel???
%           This would be quite handy... How would performance be with so
%           many listeners???


    % Implement superclass abstract property
    properties (Constant, Hidden) % Protected?
        IDNAME = 'sessionID'
    end
    
    properties (Constant, Hidden)
        ANCESTOR = 'nansen.metadata.type.animal.Mouse'; % This is not going to fly... How to make a rat session?
    end
    
    properties
        
        % Unique identification properties.
        subjectID      % Add some validation scheme.... Can I dynamically set this according to whatever?
        sessionID    char
               
        Ignore = false 

        % Date and time for experimental session
        Date
        Time
        
        % Experimental descriptions
        Experiment char     % What experiment does the session belong to.
        Protocol char       % What is the name of the protocol
        Description char    % A description of the session

        DataLocation struct % Where is session data stored
        Progress struct     % Whats the pipeline status / progress
        
    end
    
    properties (Constant, Hidden)
        InternalVariables = {'Ignore', 'DataLocation', 'Notebook'}
    end
    
    properties (Hidden, Transient) %, SetAccess = immutable) % Todo: Immutable setacces.. Does it have to be set in this, or can it be set in superclasses?
        DataLocationModel
    end

    
    methods % Constructor
        function obj = Session(varargin)
            
            obj@nansen.metadata.abstract.BaseSchema(varargin{:})
            
            if isempty(varargin)
                return; 
            end
            
            % Todo: Inherit from assignPVPairs??
            [nvPairs, ~] = utility.getnvpairs(varargin);
            for i = 1:2:numel(nvPairs)
                [obj.(nvPairs{i})] = deal(nvPairs{i+1});
            end
            
            if ~all([obj.IsConstructed])
                
                if isa(varargin{1}, 'struct')
                    obj.constructFromDataLocationStruct(varargin{1})
                elseif isa(varargin{1}, 'char')
                    obj.contructFromFolderPath(varargin{1})
                end
                
            end
            
            % Need to update data locations based on data location model
            if ~isempty(obj(1).DataLocationModel)
                obj.refreshDataLocations()
            end
            
            
            % Todo: Should DataSet/DataIoModel/DataCollection be set
            % assigned from default project datalocation if it is not given
            % as input???
            
            % Todo: update datalocation struct from data location model
            
        end
        
    end
    
    methods % Assign metadata
        
        function constructFromDataLocationStruct(obj, dataLocationStruct)
        %constructFromDataLocationStruct Construct object(s)
        
            % Todo: Support vector of objects.
            % Todo: Should I accept old and new dataLocation structure?
            
            obj.DataLocation = dataLocationStruct;
            obj.autoAssignPropertiesOnConstruction(obj)

        end
        
        function contructFromFolderPath(obj, folderPath)
        %contructFromFolderPath Construct object(s)
        %
        
        % Todo: Support vector of objects.
            obj.DataLocation(1).UnNamed = folderPath;
        end
        
        function autoAssignPropertiesOnConstruction(obj)
            
            % Note: Hardcoded, get path for first entry in data
            % location type.
            fieldNames = fieldnames(obj.DataLocation);
            pathStr = obj.DataLocation.(fieldNames{1});
            
            if ~isempty(obj.DataLocationModel)
                obj.assignSubjectID(pathStr)
                obj.assignSessionID(pathStr)
                obj.assignDateInfo(pathStr)
                obj.assignTimeInfo(pathStr)
            end
            
            obj.assignPipeline()
            
        end
        
        
        function assignSubjectID(obj, pathStr)
            % Get specification for how to retrieve subject id from
            % datalocation..
            
            subjectId = obj.DataLocationModel.getSubjectID(pathStr);
            obj.subjectID = subjectId;
        end
        
        function assignSessionID(obj, pathStr)
            % Get specification for how to retrieve session id from
            % datalocation..

            sessionId = obj.DataLocationModel.getSessionID(pathStr);
            obj.sessionID = sessionId;
            
        end
        
        function time = assignTimeInfo(obj, pathStr)
            % Get specification for how to retrieve time info from
            % datalocation..

            if nargin < 2
                pathStr = fullfile(obj.DataLocation(1).Subfolders);
            end
            
            obj.Time = obj.DataLocationModel.getTime(pathStr);
            
            if nargout == 1
                time = obj.Time;
            end
            
        end
        
        function date = assignDateInfo(obj, pathStr)
            % Get specification for how to retrieve date info from
            % datalocation..
            
            if nargin < 2
                pathStr = fullfile(obj.DataLocation(1).Subfolders);
            end
            
            obj.Date = obj.DataLocationModel.getDate(pathStr);
            
            if nargout == 1
                date = obj.Date;
            end

        end
        
        function assignPipeline(obj, pipelineName)
        %assignPipeline Assign pipeline to session object   
            % Todo: Add call to user defined function.
            % If this returns empty, check pipeline definitions...
           
            pmc = nansen.pipeline.PipelineCatalog();
           
            if nargin < 2
                pipelineIdx = 1:pmc.NumPipelines;
                doAutoAssign = true;
            elseif nargin == 2
                pipelineIdx = pmc.containsItem(pipelineName);
                doAutoAssign = false;
            end
           
           
            if true %temp true, see above
                
                for i = pipelineIdx % Loop through pipelines...
                    
                    if doAutoAssign
                        tf = pmc.matchSessionObjectsToPipeline(i, obj);
                    else
                        tf = true(1, numel(obj));
                    end
                    
                    if any(tf)
                        S = pmc.getPipelineForSession(i);
                        idx = find(tf);
                        for j = idx
                            [obj(idx).Progress] = deal(S);
                            
% %                             if isempty(obj(j).Progress)
% %                                 obj(j).Progress = S;
% %                             end
                        end
                    end
                end
            end
        end
        
        function refreshDataLocations(obj)
            
            obj.fixDataLocations()
            
            %tic
            for iObj = 1:numel(obj)
                
                for jDl = 1:numel(obj(iObj).DataLocation)
                    
                    dlUuid = obj(iObj).DataLocation(jDl).Uuid;
                    
                    [S(jDl)] = obj(iObj).DataLocationModel.getItem(dlUuid);
                    
                    fields = {'Name', 'Type'};
                    for k = 1:numel(fields)
                        obj(iObj).DataLocation(jDl).(fields{k}) = S(jDl).(fields{k});
                    end
                    
                    rootUid = obj(iObj).DataLocation(jDl).RootUid;
                    rootIdx = find( strcmp( {S(jDl).RootPath.Key}, rootUid ) );
                    
                    if ~isempty(rootIdx)
                        obj(iObj).DataLocation(jDl).RootPath = S(jDl).RootPath(rootIdx).Value;
                    end
                end
                
            end
            
            %toc
            
        end
        
        function fixDataLocations(obj)
        
            if isfield(obj(1).DataLocation, 'Uuid'); return; end
            
            for j = 1:numel(obj)
                
                S = struct('Uuid', {}, 'RootUid', {}, 'Subfolders', {});
                
                for i = 1:obj(j).DataLocationModel.NumDataLocations
                    dataLocation = obj(j).DataLocationModel.getItem(i);
                
                    name = dataLocation.Name;
                    rootPaths = {dataLocation.RootPath.Value};
                    
                    for k = 1:numel(rootPaths)
                        tf = contains( obj(j).DataLocation.(name), rootPaths{k} );
                        if ~isempty(tf)
                            root = rootPaths{k};
                            rootIdx = k;
                            break
                        end
                    end
                    
                    S(i).Uuid = dataLocation.Uuid;
                    if ~isempty(rootPaths)
                        S(i).RootUid = dataLocation.RootPath(rootIdx).Key;
                        S(i).Subfolders = strrep(obj(j).DataLocation.(name), root, '');
                    end
                end 
                
                obj(j).DataLocation = S;
            end
            
        end
        
    end
   
    methods % Set methods
        
        function set.Progress(obj, newValue)
            obj.Progress = newValue;
            eventData = obj.getPropertyChangedEventData('Progress');
            obj.notify('PropertyChanged', eventData)
        end

    end
    
    methods 
        
        function S = toStruct(obj)
        %TOSTRUCT Convert object to a struct.
        %
        % Override superclass method
            
            S = toStruct@nansen.metadata.abstract.BaseSchema(obj);
            S = rmfield(S, 'DataLocationModel');
        end
        
    end
    
    methods % Data location
        
        function updateDataLocations(obj)
            
            error('This method is down for maintenance')
            
            numDataLocations = numel(obj.DataLocationModel.Data);
            
            for i = 1:numDataLocations
                thisName = obj.DataLocationModel.Data(i).Name;
                
                % update to work with new datalocation structure definition
%                 if isfield(obj.DataLocation, thisName)
%                     continue
%                 end
%                 
%                 thisDataLocation = dataLocationModel.Data(i);
                
                pathString = obj.detectSessionFolder(thisDataLocation);
                
                obj.DataLocation.(thisName) = pathString;
            end
            
        end
        
        function pathString = detectSessionFolder(obj, dataLocation)
            
            rootPaths = {dataLocation.RootPath.Value};
            
            % Todo: Loop all? Update session's datalocation root key if
            % folder is found in different location..?
            rootPath = rootPaths{1};
            
            S = dataLocation.SubfolderStructure;

            for j = 1:numel(S)
                expression = S(j).Expression;
                ignoreList = S(j).IgnoreList;
                [rootPath, ~] = utility.path.listSubDir(rootPath, expression, ignoreList);
            end
            
            isMatch = contains(rootPath, obj.sessionID);
            
            if sum(isMatch) == 0
                pathString = '';
            elseif sum(isMatch) == 1
                pathString = rootPath{isMatch};
            else 
                warning('Multiple session folders mathed. Selected first one')
                pathString = rootPath{find(isMatch, 1, 'first')};
            end
            
        end
    end
    
    methods % Load data variables

        function data = loadData(obj, varName, varargin)
            
            % TODO:
            %   [ ] Implement file adapters.
            
            filePath = obj.getDataFilePath(varName, '-r', varargin{:});
            
            if isfile(filePath)
                
                [~, ~, ext] = fileparts(filePath);

                switch ext
                    case '.mat'
                        S = load(filePath, varName);
                        if isfield(S, varName)
                            data = S.(varName);
                        else
                            S = load(filePath);
                            data = S;
        %                 else
        %                     error('File does not hold specified variable')
                        end
                        
                    case {'.raw', '.tif'}
                        data = nansen.stack.ImageStack(filePath);
                        
                    otherwise
                        error('Nansen:Session:LoadData', 'Files of type ''%s'' is not supported for loading', ext)
 
                end

            else
                error('Variable ''%s'' was not found.', varName)
            end
            
        end
        
        function saveData(obj, varName, data, varargin)
            
            % TODO:
            %   [ ] Implement file adapters.
            
            filePath = obj.getDataFilePath(varName, '-w', varargin{:});
            
            S.(varName) = data;
            save(filePath, '-struct', 'S')
            
        end
        
        function validateVariable(obj, variableName)
        %validateData Does data variable exists?
                    
            dataFilePathModel = nansen.config.varmodel.VariableModel;

            [S, ~] = dataFilePathModel.getVariableStructure(variableName);
            
            % Check if data location folder exists:
            if ~obj.existSessionFolder( S.DataLocation )
                errorID = 'NANSEN:Session:FolderNotFound';
                errorMsg = sprintf(['No folder exists in the data location "%s" ', ...
                    'for session %s'], S.DataLocation, obj.sessionID);
                error(errorID, errorMsg) %#ok<SPERR>
                
% %                 [errorId, errorMsg] = obj.getErrorDetails();
% %                 error(errorId, errorMsg)
            end
            
            filePath = obj.getDataFilePath(variableName);
            
            if ~isfile(filePath)
                errorId = 'NANSEN:Session:RequiredDataMissing';
                %errorMsg = obj.getErrorMessage(errorId);
                errorMsg = sprintf(['The file containing "%s" does not ', ...
                    'exist or was not found for session "%s"'], ...
                    variableName, obj.sessionID);
                error(errorId, errorMsg) %#ok<SPERR>
            end
            
            
        end
        
        function tf = existSessionFolder(obj, dataLocationName)
        %existSessionFolder Check is folder for data location exists.
            
            try
                obj.getSessionFolder( dataLocationName );
                tf = true;
            catch ME
                if strcmp(ME.identifier, 'NANSEN:Session:FolderNotFound')
                    tf = false;
                else
                    rethrow(ME)
                end
            end
            
        end
        
        function pathStr = getDataFilePath(obj, varName, varargin)
        %getDataFilePath Get filepath to data within a session folder
        %
        %   pathStr = sessionObj.getDataFilePath(varName) returns a
        %   filepath (pathStr) for data with the given variable name 
        %   (varName).
        %
        %   pathStr = sessionObj.getDataFilePath(varName, mode) returns the
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
        %       pathStr = sObj.getFilePath('dff', '-w', 'Subfolder', 'roisignals')
        
            
            % Todo: 
            %   [ ] (Why) do I need mode here?
            %   [ ] Implement load/save differences, and default datapath
            %       for variable names that are not defined.
            %   [ ] Implement ways to grab data spread over multiple files, i.e
            %       if files are separate by imaging channel, imaging plane,
            %       trials or are just split into multiple parts...
            
            
            % Get the model for data file paths.
            %global dataFilePathModel
            %if isempty(dataFilePathModel)
            
            % Todo: Should be part of DataIoModel
                dataFilePathModel = nansen.setup.model.FilePathSettingsEditor;
                dataFilePathModel = nansen.config.varmodel.VariableModel;

            %end

            
            % Check if mode is given as input:
            [mode, varargin] = obj.checkDataFilePathMode(varargin{:});
            parameters = struct(varargin{:});
            
            % Get the entry for given variable name from model
            [S, isExistingEntry] = dataFilePathModel.getVariableStructure(varName);
        
            if ~isExistingEntry
                S = utility.parsenvpairs(S, [], parameters);
                if isempty(S.DataLocation)
                    S.DataLocation = obj.DataLocationModel.DefaultDataLocation;
                end
            end
            
            % Get path to session folder
            dataLocationName = S.DataLocation; % NB: Confusing naming of that field...
            try
                sessionFolder = obj.getSessionFolder(dataLocationName);
            catch ME
                dlItem = obj.DataLocationModel.getItem(dataLocationName);
                if strcmp(mode, 'write') && strcmp(dlItem.Type.Permission, 'write')
                    sessionFolder = obj.createSessionFolder(dataLocationName);
                elseif strcmp(mode, 'write') && strcmp(dlItem.Type.Permission, 'read')
                    errMsg = sprintf(['Can not get filepath for variable "%s" because it belongs to a read-only \n', ...
                        'data location and the session folder does not exist.'], varName);
                    error('Nansen:Session:DataLocationMissing', errMsg) %#ok<*SPERR>
                else
                    rethrow(ME)
                end
            end
            
            if ~isempty(S.Subfolder)
                sessionFolder = fullfile(sessionFolder, S.Subfolder);
                
                if ~isfolder(sessionFolder) && strcmp(mode, 'write')
                    mkdir(sessionFolder)
                end
            end
            
            
            if isempty(S.FileNameExpression)
                fileName = obj.createFileName(varName, S);
            else
                fileName = obj.lookForFile(sessionFolder, S);
                if isempty(fileName)
                    fileName = obj.getFileName(S);
                end
            end
            
            pathStr = fullfile(sessionFolder, fileName);
            
            % Save filepath entry to filepath settings if it did
            % not exist from before...
            if ~isExistingEntry && strcmp(mode, 'write')
                dataFilePathModel.insertItem(S)
            end
            
        end
        
        function [mode, varargin] = checkDataFilePathMode(~, varargin)
            
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
        
        function fileName = lookForFile(obj, sessionFolder, S)

            % Todo: Move this method to filepath settings editor.
            %   Move to DataIOModel/DataCollection
            
            expression = S.FileNameExpression;
            fileType = S.FileType;
            
            if ~strncmp(fileType, '.', 1)
                fileType = ['.', fileType];
            end
                
            if contains(expression, fileType)
                expression = ['*', expression];
            else
                expression = ['*', expression, fileType]; % Todo: ['*', expression, '*', fileType] <- Is this necessary???
            end
            
            L = dir(fullfile(sessionFolder, expression));
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
            %todo: variable model...
            sid = obj.sessionID;
            
            
            % Make the name into snake case before creating the filename
            varName = utility.string.camel2snake(varName);
            
            % Combine variable name and session id
            fileName = sprintf('%s_%s', sid, varName);
            
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
            
            sid = obj.sessionID;

            fileName = sprintf('%s_%s', sid, S.FileNameExpression);
            
            fileType = S.FileType;
            
            if ~strncmp(fileType, '.', 1)
                fileType = strcat('.', fileType);
            end
            
            fileName = strcat(fileName, fileType);
            
        end
        
        function folderPath = getDataLocationRootDir(obj, dataLocationName)
        %getDataLocationRoot Get root directory for given datalocation name    
            if nargin < 2
                dataLocationName = obj.DataLocationModel.DefaultDataLocation;
            end
            
            S = obj.getDataLocation(dataLocationName);
            
            folderPath = S.RootPath;
        end
        
        function updateRootDir(obj, rootdirStruct)
        %updateRootDir Updates the root directories based on input struct
        %
        %   sessionObj.updateRootDir(rootdirStruct) updates the
        %   rootdirectories of the session's data location based on
        %   information in rootdirStruct. rootDir struct is a structure
        %   where each fieldname is the name of a datalocation and each
        %   value is the corresponding new root directory for that data
        %   location.
        
            wasModified = false;
        
            for i = 1:numel(obj.DataLocation)
                thisDataLocName = obj.DataLocation(i).Name;
                
                oldRootDir = obj.DataLocation(i).RootPath;
                newRootDir = rootdirStruct.(thisDataLocName);
                if ~strcmp( oldRootDir, newRootDir )
                    thisModel = obj.DataLocationModel.getItem(i);
                    
                    % Find the uid of the new root directory
                    rootIdx = strcmp({thisModel.RootPath.Value}, newRootDir);
                    obj.DataLocation(i).RootUid = thisModel.RootPath(rootIdx).Key;
                    obj.DataLocation(i).RootPath = newRootDir;
                    
                    wasModified = true;
                end
            end
            
            if wasModified
                % Notify with the "reduced" data location struct
                T = struct2table(obj.DataLocation, 'AsArray', true);
                S = transpose( table2struct(T(:, {'Uuid', 'RootUid', 'Subfolders'})) );
                eventData = uiw.event.EventData('Property', 'DataLocation', 'NewValue', S);
                obj.notify('PropertyChanged', eventData)
            end
            
        end
        
        function folderPath = getSessionFolder(obj, dataLocationName)
        %getSessionFolder Get session folder for session given a
        %dataLocationName
                            
            if nargin < 2
                dataLocationName = obj.DataLocationModel.DefaultDataLocation;
            end
            
            folderPath = '';
            
            S = obj.getDataLocation(dataLocationName);
            
            if ~isempty(S.Subfolders)
                folderPath = fullfile(S.RootPath, S.Subfolders);
            else
                if strcmp(S.Type.Permission, 'write')
                    folderPath = obj.createSessionFolder(dataLocationName);
                end
            end
            
            if ~isfolder(folderPath)
                errorID = 'NANSEN:Session:FolderNotFound';
                errorMsg = sprintf(['Session folder at "%s" does not ', ...
                    'exist for session %s'], dataLocationName, obj.sessionID);
                error(errorID, errorMsg) %#ok<SPERR>
            end
            
        end
        
        function folderPath = createSessionFolder(obj, dataLocationName)
        %createSessionFolder Create a session folder if it does not exist
        
            [~, dlIdx] = obj.DataLocationModel.containsItem(dataLocationName);
            
            % Get the datalocation for this session object for the rootpath
            dlSession = obj.getDataLocation(dataLocationName);
            
            if strcmp(dlSession.Type.Permission, 'read')
                errMsg = sprintf(['Can not create session folder for data location "%s" because \n', ...
                    'any data location of type "%s" is read-only.'], dataLocationName, dlSession.Type);
                error('Nansen:Session:CreateSessionFolderDenied', errMsg)
            end
            
            
            rootPath = dlSession.RootPath;
            
            % Todo: If there are multiple rootpaths in the data location
            % model, should check if any of the parent folders of the
            % subfolders already exist in any of the roots and select the
            % root based on that.
            
            % Get the model in order to retrieve the subfolder structure
            dlModel = obj.DataLocationModel.getDataLocation(dataLocationName);
            
            folderPath = rootPath;
            subfolders = '';
            
            % Include subfolders in the folder path
            for i = 1:numel(dlModel.SubfolderStructure)
                iSubfolderStruct = dlModel.SubfolderStructure(i);
                folderName = obj.generateFolderName(iSubfolderStruct);
                folderPath = fullfile(folderPath, folderName);
                subfolders = fullfile(subfolders, folderName);
            end
            
            if ~isfolder(folderPath)
                mkdir(folderPath)
            end
            
            obj.DataLocation(dlIdx).Subfolders = subfolders;
            
            eventData = uiw.event.EventData('Property', 'DataLocation', ...
                'NewValue', obj.DataLocation);
            %eventData = obj.getPropertyChangedEventData('DataLocation');
            obj.notify('PropertyChanged', eventData)
            
            
            if ~nargout
                clear folderPath
            end

        end
        
        function folderName = generateFolderName(obj, subfolderStruct)
        %generateFolderName Create a foldername based on session metadata
        %
        %   folderName = generateFolderName(obj, subfolderStruct) generates
        %   the name given the input subfolderStruct. subfolderStruct is a
        %   struct from the datalocation model which must contain the
        %   following fields:
        %       - Type : Type of subfolder (i.e animal, session, date)
        %       - Name : Only required if type is 'Other'
        
        
            % Todo: need to abort if:
            %   a) this datalocation does not have a subfolder Structure
            %   b) no subfolder structure is defined for this datalocation
            
            if isempty(subfolderStruct)
                
            end
        
            switch subfolderStruct.Type
                
                case 'Animal'
                    folderName = sprintf('subject-%s', obj.subjectID);
                    
                case 'Session'
                    folderName = sprintf('session-%s', obj.sessionID);
                    
                case 'Date'
                    folderName = obj.Date;
                    if isa(folderName, 'datetime') % Todo: Should be method...
                        folderName.Format = 'yyyy_MM_dd';
                        folderName = char(folderName);
                    end
                    
                case 'Time'
                    folderName = obj.Time;
                    if isa(folderName, 'datetime') % Todo: Should be method...
                        folderName.Format = 'HH_mm_ss';
                        folderName = char(folderName);
                    end
                    
                otherwise % Other, 
                    folderName = subfolderStruct.Name;

                    if isempty(folderName)
                        error('Can not create session folder because foldername is not specified')
                    end
            end
            
        end
        
        function S = getDataLocation(obj, dataLocationName)
        %getDataLocation Get datalocation item for given datalocation name                
            
            if nargin < 2
                dataLocationName = obj.DataLocationModel.DefaultDataLocation;
            end
            
            if isempty(dataLocationName)
                error('Data location name is required')
            end
        
            % Get index for datalocation which is provided...
            if ~isempty(obj.DataLocationModel)
                [~, idx] = obj.DataLocationModel.getItem(dataLocationName);
            else
                idx = find(strcmp({obj.DataLocation.Name}, dataLocationName));
            end
                
            if isempty(idx)
                error(['Data location type ("%s") is not valid. Please use one of the following:\n', ...
                           '%s'], dataLocationName, strjoin(obj.DataLocationModel.DataLocationNames, ', ') )
            end
            
            S = obj.DataLocation(idx);
            
        end
        
        function errorMsg = getErrorMessage(obj, errorId, varargin)
            % Todo?
        end
        
    end
    
    
    methods (Static)
                        
        function S = getMetaDataVariables()
            
            
        end
    end
    
end