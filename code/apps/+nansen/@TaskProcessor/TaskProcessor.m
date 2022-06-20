classdef TaskProcessor < uiw.mixin.AssignPVPairs
% This class implemements a manager for adding tasks to a queue-based
% processor.
    
% Todo: 
%   [ ] Separate between recently finished tasks and the complete log
%   [ ] Dont accept job that already exists when using submitJob. 
%        - compare at sessionID, taskName and optionsName.
%   [ ] Need to save jobs list on a project basis
%   [ ] need to send session info back to the metatable when a job
%       finishes.
%
%   [ ] Should sessionobject have its own field in a task item? its a bit
%       weird to pull it out from the argsfield when needed

%   [ ] Happened once that task is set to running but state in table is not
%       updated...


% Note: If changes are made on session class, it will not work to load task
%       lists that contains sessions!

%% PROPERTIES

    properties
        TimerPeriod = 10
        RunTasksWhenQueued = false
        RunTasksOnStartup = false
    end
    
    properties (Dependent)
        NumQueuedTasks
        NumArchivedTasks
    end
    
    properties (SetAccess = private, SetObservable) % Taskprocessor status
    	Status      % Status of processor (typically busy or idle)
    end
    
    properties (SetAccess = private) % Properties keeping track of tasks and status
        TaskQueue   % A list of tasks present in the queue
        TaskHistory % A list of tasks present in the history
    end
    
    properties (Access = private) % Properties for running tasks
        Timer % Timer object for regularly checking status
        runningTask % Handle to the task that is currently running
        isRunning = false; % Flag for whether the QueueProcessor is running
    end
    
    properties (Dependent, Access = private)
        ActivePool % Parallell pool object
    end
    
    
    events
        TaskAdded
        TaskRemoved
        TaskStateChanged
        TaskOrderChanged
    end
    
%% METHODS

    methods % Structors
                
        function obj = TaskProcessor(varargin)
        %TaskProcessor Create a batch processor for tasks.
            
            obj.loadTaskLists()
            obj.assignPVPairs(varargin{:})
            
            
            if obj.RunTasksOnStartup
                obj.setTaskStatus('Initialize', 1:obj.NumQueuedTasks)
            else
                obj.setTaskStatus('Uninitialized', 1:obj.NumQueuedTasks)
            end
            
            obj.createTimer()

            obj.isRunning = true;
            obj.Status = 'idle';
            
        end
        
        function delete(obj)
            
            % Make conditional? I.e are there any chance the timer is
            % already stopped or deleted?
            
            if ~isempty(obj.Timer)
                stop(obj.Timer)
                delete(obj.Timer)
            end
            
            % Todo: set state to queued?
            
            obj.saveTaskLists()
                    
        end
        
    end
    
    methods % Set/get methods
        
        function set.TimerPeriod(obj, newValue)
            assert(isnumeric(newValue), 'TimerPeriod must be numeric')
            obj.TimerPeriod = newValue;
            obj.onTimerPeriodSet()
        end
        
        function numTasks = get.NumQueuedTasks(obj)
            numTasks = numel(obj.TaskQueue);
        end
        
        function numTasks = get.NumArchivedTasks(obj)
            numTasks = numel(obj.TaskHistory);
        end
        
    end
    
    methods % Public 
        
        function tf = promptQuit(obj)
        %promptQuit Prompt user to quit processor
        %
        %   tf = promptQuit(obj) returns true if user wants to quit,
        %   otherwise false
        
            % Not necessary to ask user if processor is idle.
            if strcmp(obj.Status, 'idle')
                tf = true; 
                return
            end
            
            titleStr = 'Quit?';
            promptStr = 'Tasks are still running. Are you sure you want to quit?';
            
            answer = questdlg(promptStr, titleStr, 'Yes', 'No', 'Yes');
            switch lower(answer)
                case 'yes'
                    obj.cancelRunningTask()
                    tf = true;
                case 'no'
                    tf = false;
            end 
            
        end
        
        function updateSessionObjectListeners(obj, hReferenceApp)
        %updateSessionObjectListeners 
        
            metaObjects = {};
            if numel(obj.TaskQueue) == 0; return; end
            
            count = 0;
            for i = 1:numel(obj.TaskQueue)
                thisMetaObject = obj.TaskQueue(i).args{1};
                if ~isvalid(thisMetaObject)
                    warning('Please recreate the task "%s for session "%s"', ...
                    obj.TaskQueue(i).methodName, obj.TaskQueue(i).name)
                else
                    count = count+1;
                    metaObjects{count} = obj.TaskQueue(i).args{1}; %#ok<AGROW>
                end
            end
            
            metaObjects = cat(1, metaObjects{:});
            
            for i = 1:numel(metaObjects)
                if ~isvalid(metaObjects(i))
                    % Todo: Validate all tasks on startup
                    warning('Session object is not valid')
                    continue
                end
                addlistener(metaObjects(i), 'PropertyChanged', ...
                    @hReferenceApp.onMetaObjectPropertyChanged);
            end
        end
        

        function submitJob(obj, name, func, numOut, args, optsName, comments)
        % submitJob Submit a job to the task processor
        %------------------------------------------------------------------
        %
        % Abstract: Add a new task to the queue of the task processor
        %
        % Syntax:
        %           obj.submitJob(name, fcnHandle, numOut, args)
        %
        % Inputs:
        %           obj - Table object
        %           fcnHandle - Function handle to run for this task
        %           numOut - Number of output argument from task function 
        %           args - List of arguments for task function.
        %
        % Outputs:
        %           none
        %    
        
            % Todo: Remove numOut, because It should always be 0?
            % Todo: Dont accept job that already exists. compare at
            % sessionID, taskName and optionsName
            
            if nargin < 7; comments = ''; end
            newTask = obj.createTaskItem(name, func, numOut, args, optsName, comments);
            
            if obj.isTaskOnQueue(newTask)
                error('Task is already present on queue.')
            end
            
            % Add to items of the task queue.
            if isempty(obj.TaskQueue)
                obj.TaskQueue = newTask;
            else
                obj.TaskQueue(end+1) = newTask;
            end
            
            % Add item to ui table view
            evtData = uiw.event.EventData('Table', 'Queue', 'Task', newTask);
            obj.notify('TaskAdded', evtData)
            
            if obj.RunTasksWhenQueued
                obj.setTaskStatus('Initialize', obj.NumQueuedTasks)
            end
            
        end

        function tf = isTaskOnQueue(obj, taskStruct)
            
            isMatched = @(fn) strcmp({obj.TaskQueue.(fn)}, taskStruct.(fn));
            
            nameMatched = isMatched('name') ;
            methodMatched = isMatched('methodName') ;
            
            tf = any( nameMatched & methodMatched );
            
        end
        
        function diary = getCurrentDiary(obj)
            if isempty(obj.runningTask)
                diary = '';
            else
                diary = obj.runningTask.Diary();
            end
        end
        
        function taskItem = getQueuedTask(obj, taskIdx)
            taskItem = cat(1, obj.TaskQueue(taskIdx) );
        end
        
        function setQueuedTask(obj, taskItem, idx)
            obj.TaskQueue(idx) = taskItem;
        end
       
        function taskItem = getArchivedTask(obj, idx)
            taskItem = cat(1, obj.TaskHistory(idx) );
        end
        
        function rearrangeQueuedTasks(obj, taskIdx, mode)
            
            % Todo... 
            % This might be messy, if we need to take the task status into
            % account. I.e pending tasks should take precedence over queued
            % (and paused) tasks...
            
        end
        
        function updateTaskComment(obj, taskType, taskIdx, newComment)
            switch taskType
                case 'Queue'
                    obj.TaskQueue(taskIdx).comments = newComment;
                case 'History'
                    obj.TaskHistory(taskIdx).comments = newComment;
            end
            
        end
    end

    methods (Access = private)
        
        function loadTaskLists(obj, filePath)
        % loadTaskLists Load a list of tasks from file
        %------------------------------------------------------------------
        %
        % Abstract: Load a list of tasks from file
        %
        % Syntax:
        %           obj.loadTaskLists()
        %           loadTaskLists(obj, filePath)
        %
        % Inputs:
        %           obj - TaskProcessor object
        %           filePath - Absolute filepath (optional)
        %
        % Outputs:
        %           none
        %
         
            % Get filepath
            if nargin < 2
                filePath = obj.getDefaultTaskListFilePath();
            end
            
            if isfile(filePath)
                S = load(filePath, 'taskListQueue', 'taskListHistory');
                obj.TaskQueue = S.taskListQueue;
                obj.TaskHistory = S.taskListHistory;
            end
            
        end
        
        function saveTaskLists(obj, filePath)
        % saveTaskLists Save lists of tasks to file
        %------------------------------------------------------------------  
            
            % Get filepath
            if nargin < 2
                filePath = obj.getDefaultTaskListFilePath();
            end
            
            S = struct();
            S.taskListQueue = obj.TaskQueue;
            S.taskListHistory = obj.TaskHistory;
            
            save(filePath, '-struct', 'S')
            
        end
        
        function createTimer(obj)
                        
            t = timer('Name', 'TaskProcessorTimer', 'ExecutionMode', ...
                'fixedRate', 'Period', obj.TimerPeriod);
            
            t.TimerFcn = @(myTimerObj, thisEvent) obj.checkStatus();
            start(t)
            
            obj.Timer = t;
            
        end

        function onTimerPeriodSet(obj)
            
            if ~isempty(obj.Timer)
                stop(obj.Timer)
                pause(0.05)
                obj.Timer.Period = obj.TimerPeriod;
                start(obj.Timer)
            end
            
        end
        
        function taskItem = updateTaskWhenFinished(obj, taskItem)
        %updateTaskWhenFinished Update task item from the running task obj
        
            date2str = @(dt) datestr(dt, 'yyyy.mm.dd HH:MM:SS');
            finishDateStr = date2str(obj.runningTask.FinishDateTime);
            
            elapsedDuration = obj.runningTask.FinishDateTime - obj.runningTask.StartDateTime;
            
            % Update table status
            taskItem.timeStarted = obj.runningTask.StartDateTime;
            taskItem.timeFinished = finishDateStr;
            taskItem.elapsedTime = datestr(elapsedDuration, 'HH:MM:SS');

            % Add diary and error stack
            taskItem.Diary = obj.runningTask.Diary;
            taskItem.ErrorStack = obj.runningTask.Error;
            
            % Set status
            if ~isempty(obj.runningTask.Error)
                taskItem.status = 'Failed';
            else
                taskItem.status = 'Completed';
            end

        end
        
        function sortTasksByState(obj)
            
            TASK_STATUS_ORDER = {'Running', 'Pending', 'Paused', 'Uninitialized'};
            
            currentTaskStatus = {obj.TaskQueue.status};
            
            oldTaskOrder = [];
            newTaskOrder = 1:obj.NumQueuedTasks;
            
            for i = 1:numel(TASK_STATUS_ORDER)
                idx = find(strcmp(currentTaskStatus, TASK_STATUS_ORDER{i}));
                
                oldTaskOrder = [oldTaskOrder, idx]; %#ok<AGROW>
                
            end
            
            assert(numel(oldTaskOrder)==numel(newTaskOrder), ...
                'Some tasks have a status which is not accounted for. This is a bug, please report.')
            
            if ~isequal(newTaskOrder, oldTaskOrder)
                obj.TaskQueue = obj.TaskQueue(oldTaskOrder);
                evtData = uiw.event.EventData('IndexOrder', oldTaskOrder);
                obj.notify('TaskOrderChanged', evtData)
            end
            
        end
    end
    
    methods
        
        function parPool = get.ActivePool(obj)
            
            % Todo: Does ActivePool need to be a property? Make static
            % method instead. Is it even used??
            
            % Create parallel pool on cluster if necessary
            if isempty(gcp('nocreate'))
                parPool = parpool();
            else
                parPool = gcp();
            end
        end
        
% % % % Methods Related to task handling

        function checkStatus(obj)
        %checkStatus Check status of the running task
        
            if ~obj.isRunning; return; end
            
            if isempty(obj.runningTask)
                obj.startTask();
            end
            
            % If not task was started, return here.
            if isempty(obj.runningTask); return ; end
            
            
            status = obj.runningTask.State;
            
            switch lower( status )
                
                case 'running'
                    % Do nothing
                    obj.Status = 'running';
                    
                case 'finished'
                    obj.finishTask()
            end

        end % /function checkStatus
        
        function startTask(obj)
            
            if isempty(obj.TaskQueue); return; end
            
            % Get first task from the queue list
            task = obj.TaskQueue(1);

            switch task.status
                case 'Pending' %'Queued'
                    
                    % Assign the job to the cluster
                    obj.Status = 'busy';
                    p = gcp();
                    F = parfeval(p, @task.method, 0, task.args{:});                    
                    obj.runningTask = F;
                    
                    obj.TaskQueue(1).status = 'Running';
                    
                    eventData = uiw.event.EventData('TaskIdx', 1, 'NewState', 'Running');
                    obj.notify('TaskStateChanged', eventData)
                                        
                    obj.Status = 'running';
                    
            end
            
            % Update table status
            
        end % /function startTask
        
        function cancelRunningTask(obj)
        %cancelTask Cancel the running task
            
            cancel( obj.runningTask )
            obj.finishTask('cancel')

        end
        
        function finishTask(obj, mode)
        %finishTask Method to execute when a task has finished
        %
        %    obj.finishTask()
        %
        %    obj.finishTask(mode) finishes task according to specified mode
        %    mode can be '' (default) or 'cancel'
    
        
        % Question: Is is possible that the user stops a task when this
        % function is running, and the task is put back on the queue and
        % added to the history simultaneously? Test/debug some time?
        
        % Question/todo: add mode for canceling task be retain in queue..?
        
        
            if nargin < 2; mode = ''; end
                
            completedTask = obj.TaskQueue(1);
            completedTask = obj.updateTaskWhenFinished(completedTask);
            
            if strcmpi(mode, 'cancel')
                completedTask.status = 'Canceled';
            end
            
            obj.TaskQueue(1) = [];
            obj.runningTask = [];
            obj.Status = 'idle';
            
            % Remove task from queue table (trigger event)
            eventData = uiw.event.EventData('Table', 'Queue', 'TaskIdx', 1);
            obj.notify('TaskRemoved', eventData)
            
            obj.addTaskToHistory(completedTask)
            
            % Start new task
            if obj.isRunning && ~strcmpi(mode, 'cancel')
                obj.startTask() 
            end
            
        end % /function finishTask
        
        function addTaskToHistory(obj, taskItem)
        %addTaskToHistory Add task to history and trigger event.
        
            % Add to items of the task queue.
            if isempty(obj.TaskHistory)
                obj.TaskHistory = taskItem;
            else
                obj.TaskHistory = cat(2, taskItem,  obj.TaskHistory);
            end

            % Add task to history table (trigger event)
            evtData = uiw.event.EventData('Table', 'History', 'Task', taskItem);
            obj.notify('TaskAdded', evtData)
            
        end
        
        function addCommandWindowTaskToHistory(obj, taskItem)
        %addCommandWindowTaskToHistory Add task item (from command window) 
            
            % Todo: Streamline a bit more, and combine with similar parts
            % from updateTaskWhenFinished.
            
            date2str = @(dt) datestr(dt, 'yyyy.mm.dd HH:MM:SS');
            taskItem.timeFinished = date2str(now);
        
            elapsedDuration = datetime(now, 'ConvertFrom', 'datenum') - taskItem.timeStarted;
            taskItem.elapsedTime = datestr(elapsedDuration, 'HH:MM:SS');

            obj.addTaskToHistory(taskItem)
            
        end
        
% % % % Methods related to managing tasks in the Queue and History list
        function setTaskStatus(obj, action, taskIdx)
            
            if any(taskIdx == 1) && strcmp(obj.TaskQueue(1).status, 'Running') && ~strcmp(action, 'Cancel')
                taskIdx(taskIdx==1) = [];
            end
            
            if isempty(taskIdx)
                return
            end
            
            switch action
                case {'Initialize', 'Start'}
                    newState = 'Pending';

                case {'Pause', 'Paused'}
                    newState = 'Paused';
                    
                case {'Queue', 'Uninitialized'}
                    newState = 'Uninitialized';
                    
                case 'Cancel'
                    assertMessage = 'Can only cancel a running task.';
                    assert(isequal(taskIdx, 1) && strcmp(obj.TaskQueue(1).status, 'Running'), assertMessage)
                    
                    obj.cancelRunningTask()
                    return

            end
            
            [obj.TaskQueue(taskIdx).status] = deal(newState);

            
            newState = {obj.TaskQueue(taskIdx).status};
            if isrow(newState); newState = transpose(newState); end
            eventData = uiw.event.EventData('TaskIdx', taskIdx, 'NewState', newState);
            obj.notify('TaskStateChanged', eventData)
            
            % Rearrange columns according to task states.
            obj.sortTasksByState()
        end

        function removeTask(obj, taskIdx, tableType)
        %removeTask Remove task(s) from specified table
        
            if nargin < 3; tableType = 'queue'; end
            
            switch lower( tableType )
                case 'queue'
                    obj.TaskQueue(taskIdx) = [];
                case 'history'
                    obj.TaskHistory(taskIdx) = [];
            end
            
            % Remove task from queue table
            eventData = uiw.event.EventData('Table', tableType, 'TaskIdx', taskIdx);
            obj.notify('TaskRemoved', eventData)
            
        end
        
    end
    
    methods (Static)
        
        function newTask = createTaskItem(name, func, numOut, args, optsName, comments)
            
            if nargin < 7; comments = ''; end
            
            % Create a struct for the items and a table row for the table
            newTask.name = name;
            newTask.method = func;
            newTask.methodName = utility.string.varname2label( func2str(func) );
            newTask.status = 'Uninitialized';
            newTask.numOut = numOut;
            newTask.args = args;
            newTask.timeCreated = datestr(now, 'yyyy.mm.dd HH:MM:SS');
            newTask.timeStarted = '';
            newTask.elapsedTime = ''; 
            newTask.timeFinished = ''; 
            newTask.parameters = optsName;
            newTask.comments = comments;
            newTask.Diary = '';
            newTask.ErrorStack = [];
            
        end
        
        function [cleanUpObj, logfile] = initializeTempDiaryLog()
        %initializeTempDiaryLog Create and log to temp logfile
        
            % Create a log file in temporary directory
            logfile = fullfile(tempdir, 'temp_logfile');
            
            % Create a cleanup object to make sure file is deleted later.
            cleanUpObj = onCleanup(@() delete(logfile));
            
            % Start logging diary to temporary file: 
            diary(logfile)
                
        end
        
        function pathStr = getDefaultTaskListFilePath()
        %getTaskListFilePath Get filepath for task lists
        %
        % Todo: generalize.
        
            pathStr = nansen.localpath('TaskList');
            
        end
    end
end