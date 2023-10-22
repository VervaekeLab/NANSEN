classdef Session < nansen.metadata.abstract.BaseSchema & nansen.session.HasSessionData
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
%       [ ] Create a HasSessionInfo(?) class and make a session class that is not a "metadata" class, which subclasses hasSessionInfo and HasSessionData 


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

        DataLocation struct % Where is session data stored % todo: setaccess should be private
        Progress struct     % Whats the pipeline status / progress
    end
    
    properties (Constant, Hidden)
        InternalVariables = {'Ignore', 'DataLocation', 'Notebook'}
    end
    
    properties (Hidden, SetAccess = immutable) %(Transient) 
        DataLocationModel
        VariableModel
        % Note: can not be transient because it does not get passed to a
        % worker in a parallell pool.
        % Todo: Immutable setacces.. Will this work? If using
        % assignPVPairs, the property is not set in  the constructor:/ Need
        % to adapt constructor, to retrieve datalocationmodel from pvpairs
        % and assign in constructor
    end

    methods % Constructor
        function obj = Session(varargin)
            
            obj@nansen.metadata.abstract.BaseSchema(varargin{:})
            obj@nansen.session.HasSessionData()

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
            % Todo: Should I accept old and new dataLocation structure? NO
            
            obj.DataLocation = dataLocationStruct;
            try
                obj.autoAssignPropertiesOnConstruction()
            catch ME
                dlName = fieldnames(dataLocationStruct);
                msg = sprintf('Something went wrong when setting session information for session detected at \n%s\n', ...
                    dataLocationStruct.(dlName{1}));
                warning([msg, newline, ME.message])
            end
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
            
            % Todo: Either remove this, or make it more efficient
            % obj.assignPipeline()
            
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
        
        % Pipeline/progress

        function assignPipeline(obj, pipelineName)
        %assignPipeline Assign pipeline to session object   
            % Todo: Add call to user defined function.
            % If this returns empty, check pipeline definitions...
           
            % This should either be persistent or global, because when
            % creating many session objects, this is a bottleneck. Not
            % foolproof to use persistent/global though....
            pmc = nansen.pipeline.PipelineCatalog();
           
            if nargin < 2
                pipelineIdx = 1:pmc.NumPipelines;
                doAutoAssign = true;
            elseif nargin == 2
                pipelineIdx = find( pmc.containsItem(pipelineName) );
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
        
        function unassignPipeline(obj)
            [obj(:).Progress] = deal(struct.empty);            
        end
        
        function updatePipeline(obj, pipelineTemplate)
        %updatePipeline Update pipeline for sessions that use given template
        %
        %   Updates the progress property of the session objects that has a
        %   pipeline based on the pipeline template.
        
            pipelineStructArray = [obj.Progress];
            pipelineUuids = {pipelineStructArray.Uuid};
            
            affectedIdx = find(strcmp(pipelineUuids, pipelineTemplate.Uuid));
            
            for i = 1:numel(affectedIdx)
                
                thisSession = obj(affectedIdx(i));
                pipelineStruct = thisSession.Progress; 
                pipelineStruct = nansen.pipeline.updatePipelinesFromPipelineTemplate(pipelineStruct, pipelineTemplate);
                thisSession.Progress = pipelineStruct;
            end

        end
        
        function updateProgress(obj, fcnName, status)
            
            % Return if session object does not have a pipeline.
            if isempty(obj.Progress); return; end
            
            if isa(fcnName, 'function_handle')
                fcnName = func2str(fcnName);
            end
            
            if any(strcmp({obj.Progress.TaskList.FunctionName}, fcnName))

                tf = strcmp({obj.Progress.TaskList.FunctionName}, fcnName);
                taskList = obj.Progress.TaskList;

                if strcmp(status, 'Completed')
                    taskList(tf).IsFinished = true;
                    taskList(tf).DateFinished = datetime('now');
                    obj.Progress.TaskList = taskList;
                end
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
        function name = getDataId(obj)
            name = obj.sessionID;
        end
        
        function S = toStruct(obj)
        %TOSTRUCT Convert object to a struct.
        %
        % Override superclass method
            
            S = toStruct@nansen.metadata.abstract.BaseSchema(obj);

            % Remove properties that are objects, these should not be part
            % of the struct
            if isfield(S, 'Data')
                S = rmfield(S, 'Data');
            end
            if isfield(S, 'DataLocationModel')
                S = rmfield(S, 'DataLocationModel');
            end
            if isfield(S, 'VariableModel')
                S = rmfield(S, 'VariableModel');
            end
        end
        
    end
    
    methods % Data location
          
        function refreshDataLocations(obj)
            
            obj.fixDataLocations()
            
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
                        obj(iObj).DataLocation(jDl).RootIdx = rootIdx;
                        obj(iObj).DataLocation(jDl).Diskname = S(jDl).RootPath(rootIdx).DiskName;
                    end
                end
            end
        end
        
        function fixDataLocations(obj)
        
        %   % Todo: Consolidate with DataLocationModel/validateDataLocationPaths


            if isfield(obj(1).DataLocation, 'Uuid'); return; end
            
            for j = 1:numel(obj)
                
                % Initialize a datalocation struct for session object
                S = struct('Uuid', {}, 'RootUid', {}, 'Subfolders', {}, 'RootIdx', {}, 'Diskname', {});
                
                % Loop through datalocations of the DataLocationModel
                for i = 1:obj(j).DataLocationModel.NumDataLocations
                    dataLocation = obj(j).DataLocationModel.getItem(i);
                
                    % Check if there is a root folder in the
                    % DataLocationModel matching the rootfolder for the
                    % current datalocation of the session object
                    name = dataLocation.Name;
                    rootPaths = {dataLocation.RootPath.Value};
                    
                    for k = 1:numel(rootPaths)
                        isMatched = contains( obj(j).DataLocation.(name), rootPaths{k} );
                        if isMatched
                            root = rootPaths{k};
                            rootIdx = k;
                            break
                        end
                    end

                    % Add root uid and subfolders if a rootfolder was
                    % matched from the DataLocationModel
                    S(i).Uuid = dataLocation.Uuid;
                    if ~isempty(rootPaths) && isMatched
                        S(i).RootUid = dataLocation.RootPath(rootIdx).Key;
                        S(i).Subfolders = strrep(obj(j).DataLocation.(name), root, '');
                        S(i).RootIdx = rootIdx;
                        S(i).Diskname = dataLocation.RootPath(rootIdx).DiskName;
                    else
                        S(i).RootIdx = nan;
                        S(i).Diskname = 'N/A';
                    end
                end 
                
                obj(j).DataLocation = S;
            end
        end

        function S = getDataLocation(obj, dataLocationName)
        %getDataLocation Get datalocation item for given datalocation name 
        %
        %   Note: DataLocation should be a private property. Then this
        %   method might be useful
            
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
                
        function folderPath = getDataLocationRootDir(obj, dataLocationName)
        %getDataLocationRoot Get root directory for given datalocation name    
            if nargin < 2
                dataLocationName = obj.DataLocationModel.DefaultDataLocation;
            end
            
            S = obj.getDataLocation(dataLocationName);
            
            folderPath = S.RootPath;
        end
        
        function replaceDataLocation(obj, dataLocationStruct)
        %replaceDataLocation Brute force replace the data location struct.
        %
        %   This should be a private method.

            obj.DataLocation = dataLocationStruct;

            eventData = uiw.event.EventData('Property', 'DataLocation', ...
                'NewValue', dataLocationStruct);
            obj.notify('PropertyChanged', eventData)
        end

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
    
        function updateRootDirPath(obj, dataLocationName, newRootPath)
        %updateRootDirPath Update root directory path for a data location
        
            i = strcmp({obj.DataLocation.Name}, dataLocationName);
            dlItem = obj.DataLocationModel.getItem(dataLocationName);
            
            oldRootPath = obj.DataLocation(i).RootPath;

            if ~strcmp(oldRootPath, newRootPath)
                
                % Find the uid of the new root directory
                isMatch = strcmp({dlItem.RootPath.Value}, newRootPath);
                if ~any(isMatch)
                    error('The specified rootpath does not match any rootpaths in the data location model')
                end
                obj.DataLocation(i).RootUid = dlItem.RootPath(isMatch).Key;
                obj.DataLocation(i).RootPath = newRootPath;
                obj.DataLocation(i).RootIdx = find(isMatch);
                obj.DataLocation(i).Diskname = dlItem.RootPath(isMatch).DiskName;
                  
                eventData = uiw.event.EventData('Property', 'DataLocation', 'NewValue', obj.DataLocation);
                obj.notify('PropertyChanged', eventData)
            end
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
                try
                    thisDataLocName = obj.DataLocation(i).Name;
                    
                    oldRootDir = obj.DataLocation(i).RootPath;
                    newRootDir = rootdirStruct.(thisDataLocName).RootPath;
                    if ~strcmp( oldRootDir, newRootDir )
                        thisModel = obj.DataLocationModel.getItem(i);
                        
                        % Find the uid of the new root directory
                        rootIdx = strcmp({thisModel.RootPath.Value}, newRootDir);
                        obj.DataLocation(i).RootUid = thisModel.RootPath(rootIdx).Key;
                        obj.DataLocation(i).RootPath = newRootDir;
                        obj.DataLocation(i).RootIdx = rootIdx;
                        obj.DataLocation(i).Diskname = thisModel.RootPath(rootIdx).DiskName;
                        
                        wasModified = true;
                    end
                    
                    oldSubfolder = obj.DataLocation(i).Subfolders;
                    newSubfolder = rootdirStruct.(thisDataLocName).Subfolder;
                    if ~strcmp( oldSubfolder, newSubfolder )
                        obj.DataLocation(i).Subfolders = newSubfolder;
                        wasModified = true;
                    end
                catch
                    %fprintf('Failed to set data location root for %s\n', thisDataLocName)
                end
            end
            
            if wasModified
                % Notify with the "reduced" data location struct (Not
                % anymore!)
                %T = struct2table(obj.DataLocation, 'AsArray', true);
                %S = transpose( table2struct(T(:, {'Uuid', 'RootUid', 'Subfolders'})) );
                %eventData = uiw.event.EventData('Property', 'DataLocation', 'NewValue', S);
                eventData = uiw.event.EventData('Property', 'DataLocation', 'NewValue', obj.DataLocation);
                obj.notify('PropertyChanged', eventData)
            end
            
        end
        
        function updateSessionFolder(obj, dataLocationName, folderPath)

            % Update root path

            % Update subfolders


        end
    end
    
    methods % Load data variables
        
        function fileAdapter = getFileAdapter(obj, variableName)
                    
            [filePath, variableInfo] = obj.getDataFilePath(variableName);
            fileAdapterFcn = obj.getFileAdapterFcn(variableInfo);
            fileAdapter = fileAdapterFcn(filePath);

        end
        
        % Todo: Move to variable model
        function fileAdapterFcn = getFileAdapterFcn(obj, variableInfo)
        %getFileAdapterFcn Get function handle for creating file adapter                
            
            % Todo: Make fileAdapter class for this....
            persistent fileAdapterList
            
            if isempty(fileAdapterList)
                fileAdapterList = nansen.dataio.listFileAdapters();
            end
            
            if ischar(variableInfo)
                [~, variableInfo] = obj.getDataFilePath(variableInfo);
            end
            
            % Get file adapter % Todo: make this more persistent...
            isMatch = strcmp({fileAdapterList.FileAdapterName}, variableInfo.FileAdapter);
            
            if ~any(isMatch)
                error('File adapter was not found')
            elseif sum(isMatch) > 1
                error('This is a bug. Please report')
            end
            
            fileAdapterFcn = str2func(fileAdapterList(isMatch).FunctionName);
            
        end
        
        function data = loadData(obj, varName, varargin)
        %loadData Loads data for given variable
        %
        %   sessionObj.loadData(varName) loads data for the specified 
        %       variable
        %
        %    sessionObj.loadData(varName, data, Name, Value, ...) loads data
        %       from the specified variable using options given as name-
        %       value pairs. The name value pairs only take effect if the
        %       specified variable does not exist in the Variable Model.
        %       
        %       Note: When ever a variable already exists, it can be loaded
        %       and saved without specifying the options.
        %   
        %   The following options can be set using name value pairs:
        %
        %   PARAMETERS:
        %       
        %       DataLocation        : Specifies the data location the variable should be loaded from 
        %       Subfolder           : Loads the variable from the given subfolder in the session folder.
        %       FileNameExpression  : Expression for detecting file containing variable
        %       FileType            : Load variable from a file of given type
        %       FileAdapter         : FileAdapter to use for loading variable
        %
        %   See also nansen.metadata.type.Session/getDataFilePath
        %   nansen.config.varmodel.VariableModel/getBlankItem
        
            % TODO:
            %   [v] Implement file adapters.
            
            % Todo: Allow multiple variable names
%             if ~iscell(varName)
%                 varName = {varName};
%             end
            
            % Note: Assume all the provided variables come from the same file
            [filePath, variableInfo] = obj.getDataFilePath(varName, '-r', varargin{:});
            
            if ~isempty( utility.getnvparametervalue(varargin, 'FileAdapter') )
                fileAdapterFcn = str2func( utility.getnvparametervalue(varargin, 'FileAdapter') );
            else
                obj.assertValidFileAdapter(variableInfo, 'load')
                fileAdapterFcn = obj.getFileAdapterFcn(variableInfo);
            end
            
            if isfile(filePath)
                
                switch variableInfo.FileAdapter
                    
                    case 'N/A'
                        error('Nansen:Session:LoadData', ...
                            'No file adapter is available for variable "%s"', varName) %strjoin(varName, ', ')
                    
                    case 'Default'
                        
                        % todo: Use mat for matfile, imagestack for tiff
                        % files etc.
                        
                        S = load(filePath, varName);
                        
                        if isfield(S, varName)
                            data = S.(varName);
                        else
                            S = load(filePath);
                            data = S;
                        end
                        
                    otherwise
                        data = fileAdapterFcn(filePath).load(varName);
                        % data = fileAdapterFcn(filePath).load(varName); %Todo

                end
                
% % %                 [~, ~, ext] = fileparts(filePath);
% % % 
% % %                 switch ext
% % %                     case '.mat'
% % %                         S = load(filePath, varName);
% % %                         if isfield(S, varName)
% % %                             data = S.(varName);
% % %                         else
% % %                             S = load(filePath);
% % %                             data = S;
% % %         %                 else
% % %         %                     error('File does not hold specified variable')
% % %                         end
% % %                         
% % %                     case {'.raw', '.tif'}
% % %                         data = nansen.stack.ImageStack(filePath);
% % %                         
% % %                     otherwise
% % %                         error('Nansen:Session:LoadData', 'Files of type ''%s'' is not supported for loading', ext)
% % %  
% % %                 end

            else
                error('Variable ''%s'' was not found.', varName)
            end
            
        end
        
        function saveData(obj, varName, data, varargin)
        %saveData Saves data for given variable 
        %        
        %   sessionObj.saveData(varName, data) saves data to the specified 
        %       variable 
        %
        %   sessionObj.saveData(varName, data, Name, Value, ...) saves data
        %       to the specified variable using options given as name-
        %       value pairs. The name value pairs only take effect if the
        %       specified variable does not exist in the Variable Model.
        %       
        %       Note: When ever a variable already exists, it can be loaded
        %       and saved without specifying the options.
        %   
        %   The following options can be set using name value pairs
        %
        %   PARAMETERS:
        %       
        %       DataLocation        : Specifies the data location the variable should be saved to
        %       Subfolder           : Saves the variable in the given subfolder in the session folder.
        %       FileType            : Save variable to a file of given type
        %       FileAdapter         : FileAdapter to use for variable
        %
        %
        % See also nansen.metadata.type.Session/getDataFilePath
        
            % TODO:
            %   [ ] Implement file adapters.
            
            [filePath, variableInfo] = obj.getDataFilePath(varName, '-w', varargin{:});

            obj.assertValidFileAdapter(variableInfo, 'save')
            fileAdapterFcn = obj.getFileAdapterFcn(variableInfo);
            
            switch variableInfo.FileAdapter
                case 'N/A'
                    error('Nansen:Session:SaveData', ...
                            'No file adapter is available for variable "%s"', varName)
                case 'Default'
                    S.(varName) = data;

                    varInfo = whos('data');
                    byteSize = varInfo.bytes;

                    if byteSize > 2^31
                        save(filePath, '-struct', 'S', '-v7.3')
                    else
                        save(filePath, '-struct', 'S')
                    end
                    
                otherwise
                    fileAdapterFcn(filePath, '-w').save(data, varName);
                    % data = fileAdapterFcn(filePath).load(varName); %Todo
            end
            obj.Data.resetCache(varName)
        end
        
        function validateVariable(obj, variableName)
        %validateData Does data variable exists?
            
            % Todo: Rename to assertVariableAvailable?

            variableModel = obj.VariableModel;

            if ~isa(variableName, 'cell')
                variableName = {variableName}; 
            end
            
            for i = 1:numel(variableName)
            
                [S, ~] = variableModel.getVariableStructure(variableName{i});
            
                % Check if data location folder exists:
                if ~obj.existSessionFolder( S.DataLocation )
                    errorID = 'NANSEN:Session:FolderNotFound';
                    errorMsg = sprintf(['The data location "%s" does not exist (or is not available) ', ...
                        'for session %s'], S.DataLocation, obj.sessionID);
                    error(errorID, errorMsg) %#ok<SPERR>

    % %                 [errorId, errorMsg] = obj.getErrorDetails();
    % %                 error(errorId, errorMsg)
                end

                filePath = obj.getDataFilePath(variableName{i});

                if ~isfile(filePath)
                    errorId = 'NANSEN:Session:RequiredDataMissing';
                    %errorMsg = obj.getErrorMessage(errorId);
                    errorMsg = sprintf(['The file containing "%s" does not ', ...
                        'exist or was not found for session "%s"'], ...
                        variableName{i}, obj.sessionID);
                    error(errorId, errorMsg) %#ok<SPERR>
                end
            end
        end
        
        function tf = existVariable(obj, varName)
            filePath = obj.getDataFilePath(varName);
            tf = isfile(filePath);
        end

        function tf = existVariableInModel(obj, varName)
            variableModel = obj.VariableModel;
            [~, tf] = variableModel.getVariableStructure(varName);
        end

        function createVariable(obj, varName, varargin)
        %createVariable Create a variable and insert in the variable model            

            variableModel = obj.VariableModel;

            % Get the entry for given variable name from model
            [S, isExistingEntry] = variableModel.getVariableStructure(varName);
        
            if isExistingEntry
                error('Variable "%s" already exists')
            end

            parameters = struct(varargin{:});

            S = utility.parsenvpairs(S, [], parameters);
            if isempty(S.DataLocation)
                dlItem = obj.DataLocationModel.getDefaultDataLocation;
                S.DataLocation = dlItem.Name;
                S.DataLocationUuid = dlItem.Uuid;
            end

            variableModel.insertItem(S)
        end

        function [pathStr, variableInfo] = getDataFilePath(obj, varName, varargin)
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
        %       DataLocation        : Specifies which data location the variable belongs to
        %       Subfolder           : If file is in a subfolder of sessionfolder.
        %       FileNameExpression  : Expression for detecting file containing variable
        %       FileType            : File type for file containing variable
        %       FileAdapter         : FileAdapter to use for variable
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
            

            % If input is a cell array of variable names, call this method
            % for each variable.
            if isa(varName, 'cell')
                if nargout == 1
                    error('Please provide a variable name as a character vector.')
                else
                    error('Session:NotImplementedYet', 'Can not retrieve variable info for multiple variables.')
                end
            end
            
            % Get the model for data file paths.
            
            % Todo: Should be part of DataIoModel
            variableModel = obj.VariableModel;

            
            % Check if mode is given as input:
            [mode, varargin] = obj.checkDataFilePathMode(varargin{:});
            
            % Get the entry for given variable name from model
            [S, isExistingEntry] = variableModel.getVariableStructure(varName);
        
            if ~isExistingEntry % Create variableItem using input options.
                parameters = struct(varargin{:});
                S = utility.parsenvpairs(S, 1, parameters);
                if isempty(S.DataLocation)
                    dlItem = obj.DataLocationModel.getDefaultDataLocation;
                    S.DataLocation = dlItem.Name;
                    S.DataLocationUuid = dlItem.Uuid;
                end

                % Save filepath entry to filepath settings if it did
                % not exist from before...
                if strcmp(mode, 'write') % Save to model
                    variableModel.insertItem(S)
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
            
            if nargout == 2
                variableInfo = S;
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
                fileName = L(1).name;
                warning off backtrace
                warning('Multiple files were found for variable "%s".\nSelected first file in list.', S.VariableName)
                warning on backtrace
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
        
        % Session folder

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

        function folderPath = getSessionFolder(obj, dataLocationName)
        %getSessionFolder Get session folder for a given dataLocationName
        %
        %
                            
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
        
            if nargin < 2
                dataLocationName = obj.DataLocationModel.DefaultDataLocation;
            end
        
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
            
            newValue = obj.DataLocation;
            %newValue = obj.DataLocationModel.reduceDataLocationInfo( obj.DataLocation );
            
            eventData = uiw.event.EventData('Property', 'DataLocation', ...
                'NewValue', newValue);%obj.DataLocation);
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
        
    end

    methods (Access = private)

        function errorMsg = getErrorMessage(obj, errorId, varargin)
            % Todo?
        end
        
    end
    
    
    methods (Static)
                
        function assertValidFileAdapter(variableInfo, action)
                    
            if strcmp(variableInfo.FileAdapter, 'N/A')
                error(['Variable "%s" is contained in an unsupported ', ...
                    'fileformat (%s). Create or specify a file adapter ', ...
                    'to %s this variable.'], ...
                    variableInfo.VariableName, variableInfo.FileType, action)
            end
        
        end
        
        function S = getMetaDataVariables()
            
            
        end
    end
    
end