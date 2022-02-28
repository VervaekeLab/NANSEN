classdef SessionData < dynamicprops
%SessionData Class that provides access to File Variables in DataLocations 
% 
%
%

% NOTE: This class overrides the subsref method and although private
% properties and methods are accounted for, there could be issues if
% subclassing this class and implementing protected properties. Long story
% short, protected properties would not be protected in this case.


% Todo: 
%   [v] Should hold the session object and call methods from the session
%       object, instead of running a copy of those methods....
%   [ ] Remove all methods that are duplicates from the session class.

    properties
        sessionID
    end


    properties (Access = private)
        DataLocation
        subjectID 
        Date 
        Time
    end
    
    properties (Access = private)
        SessionObject
        DataLocationModel
        DataFilePathModel
    end
    
    properties (Access = private)
        VariableList = {};
        FileList containers.Map
    end
    
    
    methods
        
        function obj = SessionData(sessionObj)
                        
            dataFilePathModel = nansen.setup.model.FilePathSettingsEditor();
            
            obj.SessionObject = sessionObj;
            obj.DataLocationModel = sessionObj.DataLocationModel;
            obj.DataFilePathModel = dataFilePathModel;
            
            
            % inherit properties for sessionObj. Todo: Avoid duplication...       
            obj.sessionID = sessionObj.sessionID;
            obj.subjectID = sessionObj.subjectID;
            obj.Date = sessionObj.Date;
            obj.Time = sessionObj.Time;
            obj.DataLocation = sessionObj.DataLocation;

            
            % Initialize the property value here (because Map is handle)
            obj.FileList = containers.Map; % Todo: Use java.HashTable or similar instead?
            
        end
        
    end
    
    
    
    methods
        function updateDataVariables(obj)
            
            varNames = {obj.DataFilePathModel.VariableList.VariableName};
            
            for i = 1:numel(varNames)
                try
                    filePath = obj.SessionObject.getDataFilePath(varNames{i});

                    if isfile(filePath)
                        if ~isprop(obj, varNames{i})
                            obj.addDataProperty(varNames{i})
                        end
                    end
                catch
                    % Todo: Find if session folder is not found, otherwise
                    % need to do something...
                end
            end
            
        end

    end
    
    methods (Access = protected)
        
        function addDataProperty(obj, variableName)
            pPuplic = obj.addprop(variableName);
            
            
            % Add a private property that will hold the actual data.
            privateVariableName = strcat(variableName, '_');
            pPrivate = obj.addprop(privateVariableName);
            pPrivate.SetAccess = 'private';
            pPrivate.GetAccess = 'private';
            
            %obj.(privateVariableName) = [];
            
            pPuplic.GetMethod = @(h, varName) obj.getDataVariable(variableName);
            
            %pPuplic.SetMethod = @obj.setDataVariable;
            pPuplic.SetAccess = 'private'; %todo: Add set functionality
            obj.VariableList{end+1} = variableName;

        end
      
        function value = getDataVariable(obj, varName)
            privateVarName = strcat(varName, '_');
            
            if isempty(obj.(privateVarName))
                value = 'Uninitialized';
            else
                value = obj.(privateVarName);
            end

        end
        
        function assignDataToPrivateVar(obj, varName)
            privateVarName = strcat(varName, '_');
            
            if isempty(obj.(privateVarName))
                obj.(privateVarName) = obj.loadData(varName); 
            end
            
        end
        
        function setDataVariable(obj, varargin)
            disp('so far so goooood')
        end
        
    end
    
    methods (Sealed, Hidden)
        function varargout = subsref(obj, s)
            
            % Preallocate cell array of output.
            varargout = cell(1, nargout);

            switch s(1).type

                % I only want to override the variable names that are added
                % as dynamic properties. If the user request this property,
                % we should load the data from file
                
                case '.'
                    if any(strcmp(obj.VariableList, s(1).subs))
                        obj.assignDataToPrivateVar(s(1).subs)
                        
                    else % Take appropriate action if a property or method is requested.
                    
                        mc = metaclass(obj);
                        throwError = false;

                        % Test if a public property or method was invoked
                        if isprop(obj, s(1).subs)
                            isMatch = strcmp({mc.PropertyList.Name}, s(1).subs);

                            if any(isMatch)
                                getAccessStr = mc.PropertyList(isMatch).GetAccess;
                                if ~strcmpi(getAccessStr, 'public')
                                    throwError = true;
                                end
                            else
                                throwError = true;
                            end

                        elseif ismethod(obj, s(1).subs)
                            % Public method
                        else
                            isMatch = strcmp({mc.MethodList.Name}, s(1).subs);

                            if any(isMatch)
                                accessStr = mc.MethodList(isMatch).Access;

                                if ~strcmpi(accessStr, 'public')
                                    throwError = true;
                                end
                            else
                                throwError = true;
                            end
                        end

                        if throwError
                            errorID = 'MATLAB:noSuchMethodOrField';
                            errorMsg = sprintf('Unrecognized method, property, or field ''%s'' for class ''%s''.', s(1).subs, class(obj));
                            throwAsCaller(MException(errorID, errorMsg))
                        end
                        
                    end

            end
              
            % If we got this far, use the builtin subsref
            if nargout > 0
                [varargout{:}] = builtin('subsref', obj, s);
            else
                try
                    varargout{1} = builtin('subsref', obj, s);
                catch ME
                    switch ME.identifier
                        case {'MATLAB:TooManyOutputs', 'MATLAB:maxlhs'}
                            try
                                builtin('subsref', obj, s)
                            catch ME
                                throwAsCaller(ME)
                            end
                        otherwise
                            throwAsCaller(ME)
                    end
                end
            end
                    
        end
    end
            
            
    methods (Access = protected) % Load data variables
        
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
                error('File not found')
            end
            
        end
        
        function saveData(obj, varName, data, varargin)
            
            % TODO:
            %   [ ] Implement file adapters.
            
            filePath = obj.getDataFilePath(varName, '-w', varargin{:});
            
            S.(varName) = data;
            save(filePath, '-struct', 'S')
            
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
            
            
            pathStr = obj.SessionObject.getDataFilePath(varName, varargin{:});
            return
            
            % Get the model for data file paths.
            global dataFilePathModel
            if isempty(dataFilePathModel)
                dataFilePathModel = nansen.setup.model.FilePathSettingsEditor;
            end

            % Check if mode is given as input:
            [mode, varargin] = obj.checkDataFilePathMode(varargin{:});
            parameters = struct(varargin{:});
            
            % Get the entry for given variable name from model
            [S, isExistingEntry] = dataFilePathModel.getEntry(varName);
        
            if ~isExistingEntry
                S = utility.parsenvpairs(S, [], parameters);
            end
            
            % Get path to session folder
            sessionFolder = obj.getSessionFolder(S.DataLocation);
            
            % Check if file should be located within a subfolder.
            if ~isempty(S.Subfolder)
                dataFolder = fullfile(sessionFolder, S.Subfolder);
                
                if ~isfolder(dataFolder) && strcmp(mode, 'write')
                    mkdir(dataFolder)
                end
            else
                dataFolder = sessionFolder;
            end
            
            
            if isempty(S.FileNameExpression)
                fileName = obj.createFileName(varName, S);
            else
                fileName = obj.lookForFile(dataFolder, S);
                if isempty(fileName)
                    fileName = obj.getFileName(S);
                end
            end
            
            pathStr = fullfile(dataFolder, fileName);
            
            % Save filepath entry to filepath settings if it did
            % not exist from before...
            if ~isExistingEntry && strcmp(mode, 'write')
                dataFilePathModel.addEntry(S)
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
            
            expression = S.FileNameExpression;
            fileType = S.FileType;
            
            if contains(expression, fileType)
                expression = ['*', expression];
            else
                expression = ['*', expression, fileType]; % Todo: ['*', expression, '*', fileType] <- Is this necessary???
            end
            
            
            % Is this faster if there are many files?
% % %             if isKey(obj.FileList, sessionFolder)
% % %                 fileList = obj.FileList(sessionFolder);
% % %             else
% % %                 L = dir(sessionFolder);
% % %                 L = L(~strncmp({L.name}, '.', 1));
% % %                 fileList = {L.name};
% % %                 obj.FileList(sessionFolder) = fileList;
% % %             end
% % % 
% % %             expression = strrep(expression, '*', '')
% % %             isMatch = contains(fileList, expression);
% % %             if any(isMatch) && sum(isMatch)==1
% % %                 fileName = fileList{isMatch};
% % %             elseif any(isMatch) && sum(isMatch) < 1
% % %                 error('Multiple files were found')
% % %             else
% % %                 fileName = '';
% % %             end
            
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
            
            sid = obj.sessionID;
            
            capLetterStrInd = regexp(varName, '[A-Z, 1-9]');

            for i = fliplr(capLetterStrInd)
                if i ~= 1
                    varName = insertBefore(varName, i , '_');
                end
            end
            
            varName = lower(varName);
            
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
        
        
        
        function folderPath = getSessionFolder(obj, dataLocationName)
        % Get session folder for session given a dataLocationType
        
            % Todo: implement secondary roots (ie cloud directories)
            
            folderPath = obj.SessionObject.getSessionFolder(dataLocationName);
           
        end

    end
   
    methods (Static)
    end
end