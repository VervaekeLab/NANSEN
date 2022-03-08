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


%% PROPERTIES

    properties
        TimerPeriod = 10
    end
    
    properties (SetAccess = private) % Properties keeping track of tasks and status
    	Status      % Status of processor (typically busy or idle)
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
    end
    
%% METHODS

    methods % Structors
                
        function obj = TaskProcessor(varargin)
        %TaskProcessor Create a batch processor for tasks.
            
            obj.loadTaskLists()
            
            obj.createTimer()
            
            obj.isRunning = true;
            obj.Status = 'idle';
        end
        
        function delete(obj)
            
            % Make conditional? I.e are there any chance the timer is
            %already stopped or deleted?
            
            if ~isempty(obj.Timer)
                stop(obj.Timer)
                delete(obj.Timer)
            end
            
            obj.saveTaskLists()
                        
        end
        
    end
    
    methods % Set/get methods
        
        function set.TimerPeriod(obj, newValue)
            assert(isnumeric(newValue), 'TimerPeriod must be numeric')
            obj.TimerPeriod = newValue;
            obj.onTimerPeriodSet(obj)
        end

    end
    
    methods % Public 
        
        function updateSessionObjectListeners(obj, hReferenceApp)
        %updateSessionObjectListeners 
        
            metaObjects = {};
            if numel(obj.TaskQueue) == 0; return; end
            
            for i = 1:numel(obj.TaskQueue)
                metaObjects{i} = obj.TaskQueue(i).args{1};
            end
            
            metaObjects = cat(1, metaObjects{:});

            addlistener(metaObjects, 'PropertyChanged', ...
                @hReferenceApp.onMetaObjectPropertyChanged);
        end
        
        function submitJob(obj, name, func, numOut, args, optsName)
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
            
            % Create a struct for the items and a table row for the table
            newTask.name = name;
            newTask.method = func;
            newTask.methodName = utility.string.varname2label( func2str(func) );
            newTask.status = 'Queued';
            newTask.numOut = numOut;
            newTask.args = args;
            newTask.timeCreated = datestr(now, 'yyyy.mm.dd HH:MM:SS');
            newTask.timeStarted = '';
            newTask.elapsedTime = ''; 
            newTask.timeFinished = ''; 
            newTask.parameters = optsName;
            newTask.comments = '';
            
            % Add to items of the task queue.
            if isempty(obj.TaskQueue)
                obj.TaskQueue = newTask;
            else
                obj.TaskQueue(end+1) = newTask;
            end
            
            % Add item to ui table view
            evtData = uiw.event.EventData('Table', 'Queue', 'Task', newTask);
            obj.notify('TaskAdded', evtData)
                        
        end

        function loadTaskLists(obj, filePath)
        % loadTaskLists Load a list of tasks from file
        %------------------------------------------------------------------
        %
        % Abstract: Load a list of tasks from file
        %
        % Syntax:
        %           obj.loadListOfTasks()
        %           loadListOfTasks(obj, filePath)
        %
        % Inputs:
        %           obj - Table object
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
            
            % Get filepath
            if nargin < 2
                filePath = obj.getDefaultTaskListFilePath();
            end
            
            S = struct();
            S.taskListQueue = obj.TaskQueue;
            S.taskListHistory = obj.TaskHistory;
            
            save(filePath, '-struct', 'S')
            
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
    end

    methods (Access = private)

        function createTimer(obj)
                        
            t = timer('ExecutionMode', 'fixedRate', 'Period', obj.TimerPeriod);
            
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
                    obj.Status = 'busy';
                    
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
                    p = gcp();
                    F = parfeval(p, @task.method, 0, task.args{:});                    
                    obj.runningTask = F;
                    
                    obj.TaskQueue(1).status = 'Running';
                    
                    eventData = uiw.event.EventData('TaskIdx', 1, 'NewState', 'Running');
                    obj.notify('TaskStateChanged', eventData)
                                        
                    obj.Status = 'busy';
                    
            end
            
            % Update table status
            
        end % /function startTask
        
        function finishTask(obj)
        %finishTask Method to execute when a task has finished
             
            completedTask = obj.TaskQueue(1);
            completedTask = obj.updateTaskWhenFinished(completedTask);
            
            obj.TaskQueue(1) = [];
            obj.runningTask = [];
            obj.Status = 'idle';
            
            % Add to items of the task queue.
            if isempty(obj.TaskHistory)
                obj.TaskHistory = completedTask;
            else
                obj.TaskHistory = cat(2, completedTask,  obj.TaskHistory);
            end
            
            % Remove task from queue table (trigger event)
            eventData = uiw.event.EventData('Table', 'Queue', 'TaskIdx', 1);
            obj.notify('TaskRemoved', eventData)
            
            % Add task to history table (trigger event)
            evtData = uiw.event.EventData('Table', 'History', 'Task', completedTask);
            obj.notify('TaskAdded', evtData)


            % Start new task
            if obj.isRunning
                obj.startTask() 
            end
            
        end % /function finishTask
        
        
% % % % Methods related to managing tasks in the Queue and History list
        
        function setTaskStatus(obj, newStatus, taskIdx)
            
            if any(taskIdx == 1) && strcmp(obj.TaskQueue(1).status, 'Running')
                msgbox('Task is already running.')
                taskIdx(taskIdx==1) = [];
            end
            
            if isempty(taskIdx)
                return
            end
            
            switch newStatus
                case 'Initialize'
                    
                    statusList = {obj.TaskQueue.status};
                    
                    % Find the last queued task in the list. The newly
                    % queued task should be inserted after this.
                    ind = find( contains(statusList, 'Pending'), 1, 'last');
                    
                    if isempty(ind) 
                        ind = find( contains(statusList, 'Running'), 1, 'last');
                        if isempty(ind)
                            ind = 0;
                        end
                    end
                    
                    
                    selectedTasks = obj.TaskQueue(taskIdx);
                    obj.TaskQueue(taskIdx) = [];

                    for i = 1:numel(selectedTasks)
                        selectedTasks(i).status = 'Pending';
                    end
                    
                    % Insert newly queued task back into the list
                    obj.TaskQueue = [ obj.TaskQueue(1:ind), ...
                                      selectedTasks, obj.TaskQueue(ind+1:end) ];
                                        
                    
                case 'Pause'
                    
                    for i = taskIdx
                        obj.TaskQueue(i).status = 'Paused';
                    end
                
            end
            
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
        function pathStr = getDefaultTaskListFilePath()
        %getTaskListFilePath Get filepath for task lists
        %
        % Todo: generalize.
        
            pathStr = nansen.localpath('TaskList');
            
        end
    end
end