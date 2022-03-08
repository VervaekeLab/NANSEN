classdef PipelineCatalog < utility.data.StorableCatalog
%DataLocationModel Interface for detecting path of data/session folders
    

    % TODOS:
    %   [x] Combine code from getSubjectId and getSessionId into separate
    %       methods.
    %   [ ] Todo: save on close...
    
    % QUESTIONS:
    
    properties (Constant, Hidden)
        ITEM_TYPE = 'Pipeline'
    end
    
    properties (Dependent, SetAccess = private)
        PipelineNames
        NumPipelines
    end
    
    properties (Dependent)
        DefaultPipeline
    end
    
    
    methods (Static)
        
        function S = getBlankItem()
            
            import nansen.pipeline.PipelineCatalog
            
            S = struct(...
                'PipelineName', '', ...
                'PipelineTasks', PipelineCatalog.getTask('empty'), ...
                'SessionProperties', PipelineCatalog.getSessionMetaVariables() );
            
        end

        function S = getDefaultItem()
                        
            S = struct;
            
            S.PipelineName = ''; % Todo: Get all pipeline names
            S.PipelineTasks = struct.empty;
            S.SessionProperties = nansen.pipeline.PipelineCatalog.getSessionMetaVariables();
            
        end

        function S = getSessionMetaVariables()
        %getSessionMetaVariables Create a default struct
            S = struct(...
                'VariableName', '', ...
                'Mode', '', ...
                'Expression', '' );
            
        end
        
        function S = getTask(option)
            S = struct();
            S.TaskNum = [];
            S.TaskName = '';
            S.TaskFunction = '';
            S.OptionPresetSelection = '';
            
            if nargin == 1 && ischar(option) && strcmp(option, 'empty')
                S(1) = [];
            end
        end
    end
    
    methods % Constructor 
        function obj = PipelineCatalog(varargin)
           
            % Superclass constructor. Loads given (or default) archive 
            obj@utility.data.StorableCatalog(varargin{:})

            if ~nargout
                utility.data.StorableCatalogApp(obj)
                clear obj
            end
            
        end
        
    end
    
    methods % Set/get methods [v]
    
        function numPipelines = get.NumPipelines(obj)
            numPipelines = numel(obj.Data);
        end
        
        function pipelineNames = get.PipelineNames(obj)
            pipelineNames = obj.ItemNames;
        end
        
        function defaultPipeline = get.DefaultPipeline(obj)
            defaultPipeline = obj.Preferences.DefaultPipeline;
        end
        
        function set.DefaultPipeline(obj, newValue)
            
            assert(ischar(newValue), 'Please provide a character vector with the name of a pipeline')

            % Todo: Make table archive method for assertion:
            message = sprintf('"%s" can not be a default %s because no %s with this name exists.', ...
                newValue, lower(obj.ITEM_TYPE), lower(obj.ITEM_TYPE));
            assert(any(strcmp(obj.ItemNames, newValue)), message)
            
            obj.Preferences.DefaultPipeline = newValue;
            
        end
        
    end
    
    methods % Public
        
        function sessionObjects = acceptSessionObject(obj, sessionObjects)
            
            for i = 1:numel(obj.NumPipelines)
                
                tf = obj.matchSessionObjectsToPipeline(i, sessionObjects);
                
                if any(tf)
                end

            end
        
        end
        
        
        function tf = matchSessionObjectsToPipeline(obj, pipelineIdx, sessionObjects)
        %matchSessionObjectsToPipeline Match pipeline with sessionobjects
        %
        %   tf = matchSessionObjectsToPipeline(obj, pipelineIdx, sessionObjects)
        %   returns a logical vector which is true for all sessionObjects
        %   that were matched to pipeline.
        
        %   Todo: Should this be a function?
            tf = true(1, numel(sessionObjects));
        
            sMatchMaker = obj.Data(pipelineIdx).SessionProperties;
            
            for i = 1:numel(sMatchMaker)
                
                thisVarName = sMatchMaker(i).VariableName;
                
                if ~isempty(thisVarName)
                    
                    dummyValue = sessionObjects(1).(thisVarName);
                    
                    if ischar(dummyValue)
                        
                        propValues = cell(1, numel(sessionObjects));
                        for j = 1:numel(propValues)
                            propValues{j} = sessionObjects(j).(thisVarName);
                        end
                            
% % %                         % Does not work for dynamic properties...
% % %                         propValues = {sessionObjects.(thisVarName)};
                        
                        switch sMatchMaker(i).Mode
                            
                            case 'contains'
                                tf = tf & contains(propValues, sMatchMaker(i).Expression);
                                
                            case 'match'
                                tf = tf & strcmp(propValues, sMatchMaker(i).Expression);
                                
                            otherwise 
                                error('Unsupported matching mode')
                        end
                        
                    elseif isnumeric(dummyValue)
                                    
                        propValues = [sessionObjects.(thisVarName)];

                        switch sMatchMaker(i).Mode

                            case 'contains'
                                error('not implemented yet')
                            case 'match'
                                tf = tf & ismember(propValues, eval(sMatchMaker(i).Expression));
                            otherwise 
                                error('Unsupported matching mode')
                        end
                        
                    elseif islogical(dummyValue)
                    
                        propValues = [sessionObjects.(thisVarName)];
                        tf = tf & ismember(propValues, eval(sMatchMaker(i).Expression));

                    else
                        error('Unsupported data type for matching pipeline to session')
                        
                    end
                    
                else
                    
                    if numel(sMatchMaker) == 1
                        tf(:) = false;
                    end
                    
                end
            end
        end
        
        
        function pipelineItem = getPipelineForSession(obj, pipelineIdx)
        %getPipelineForSession Get a pipeline item for session object.
        
            if ischar(pipelineIdx) % assume name was given instead of idx
                [~, pipelineIdx] = obj.containsItem(pipelineIdx);
            end
        
            pipelineItem = obj.Data(pipelineIdx);
            pipelineTaskList = pipelineItem.PipelineTasks;
    
            % Remove the following fields, as they are not needed for the
            % session instance of a pipeline.
            pipelineItem = rmfield(pipelineItem, 'SessionProperties');
            pipelineItem = rmfield(pipelineItem, 'PipelineTasks');
            
            % Create an extended tasklist for the session object.
            extendedTaskList = struct( nansen.pipeline.Task );
            
            if isempty(pipelineTaskList) || isempty(fieldnames(pipelineTaskList))
                extendedTaskList(1) = []; 
                pipelineItem.TaskList = extendedTaskList;
                return
            end
            
            % Should these fieldnames be more unified?
            for i = 1:numel(pipelineTaskList)
                extendedTaskList(i).TaskName = pipelineTaskList(i).TaskName;
                extendedTaskList(i).FunctionName = pipelineTaskList(i).TaskFunction;
                extendedTaskList(i).OptionsName = pipelineTaskList(i).OptionPresetSelection;
                
                fcnAttributes = eval( extendedTaskList(i).FunctionName );
                extendedTaskList(i).IsManual = ~fcnAttributes.IsQueueable;
                extendedTaskList(i).WasAborted = false;
                extendedTaskList(i).IsFinished = false;
                extendedTaskList(i).DateFinished = datetime.empty;
            end
            
            if isrow(extendedTaskList); extendedTaskList = extendedTaskList'; end
            
            pipelineItem.TaskList = extendedTaskList;
            
        end
        
    end
    
    methods % Methods for updating substructs
         
        function setTaskList(obj, pipelineName, newTaskList)
            
            idx = obj.getItemIndex(pipelineName);
            obj.Data(idx).PipelineTasks = newTaskList;
            
        end
    end
    
    methods % Methods for accessing/modifying items
        
    end
    
    methods (Access = {?nansen.pipeline.PipelineAssignmentModelApp, ...
            ?nansen.pipeline.PipelineAssignmentModelUI })
        
        function setModelData(obj, data)
            obj.Data = data;
        end
        
    end
    
    methods (Access = protected)
        
        function item = validateItem(obj, item)
            item = validateItem@utility.data.StorableCatalog(obj, item);
            
        end
        
        function name = getNewName(obj)
            
            prefix = 'UNNAMED';
            
            isUnnamed = contains(obj.ItemNames, prefix);
            numUnnamed = sum(isUnnamed);
            unnamedNames = sort(obj.ItemNames(isUnnamed));
            
            candidates = arrayfun(@(i) sprintf('%s_%d', prefix, i), ...
                1:(numUnnamed+1), 'uni', 0);
            
            % Find candidate which is not in use...
            candidates = setdiff(candidates, unnamedNames, 'stable');
            
            name = candidates{1};
            
        end
        
    end
    
    
    methods (Hidden, Access = protected) 
        
    end
    
    methods (Static)
        
        function pathString = getDefaultFilePath()
        %getFilePath Get filepath for loading/saving datalocation settings   
            fileName = 'PipelineAssignmentModel';
            try
                pathString = nansen.config.project.ProjectManager.getFilePath(fileName);
            catch
                pathString = '';
            end
        end
        
    end
    
end

