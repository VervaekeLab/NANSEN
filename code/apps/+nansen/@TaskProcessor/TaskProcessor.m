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


%% PROPERTIES

    properties % Properties keeping track of tasks and status
    	Status      % Status of processor (typically busy or idle)
        TaskQueue   % A list of tasks present in the queue
        TaskHistory % A list of tasks present in the history
    end
    
    properties % Properties for running tasks
        Timer % Timer object for regularly checking status
        ParPool % Parallell pool object
        runningTask % Handle to the task that is currently running
        isRunning = false; % Flag for whether the QueueProcessor is running
    end
        
    properties (Access = private)
        Parent
        TabGroup
        queueTab
        historyTab
        queueTable
        historyTable
        %processingTable
    end
    
    properties (Access = protected) % Should be part of table class
        %selectedRows
        %selectedColumns
    end
    
    properties (Dependent, Access = private)
        ActivePool
    end
    
    properties (Constant, GetAccess = private) % Column names for table views. Todo: Move to separate classes?
        queueTableVars =  {'SessionID', 'Method', 'Status', 'Submitted', 'Parameters', 'Comment'}
        historyTableVars = {'SessionID', 'Method', 'Status', 'Finished', 'Elapsed Time', 'Comment'}
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
    
    
    methods % Public 
        
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
            
            %obj.addTaskToQueueTable(newTask)
            
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
                        
            t = timer('ExecutionMode', 'fixedRate', 'Period', 10);
            
            t.TimerFcn = @(myTimerObj, thisEvent) obj.checkStatus();
            start(t)
            
            obj.Timer = t;
            
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
        %finishTask
        
            % TODO: Get error....
            
            % Update table status
            obj.TaskQueue(1).timeStarted = obj.runningTask.StartDateTime;
            obj.TaskQueue(1).timeFinished = obj.runningTask.FinishDateTime;
            obj.TaskQueue(1).elapsedTime = obj.runningTask.FinishDateTime - obj.runningTask.StartDateTime;
            
            % Todo: This should be part of the finish task method.
            obj.TaskQueue(1).timeFinished = datestr(obj.TaskQueue(1).timeFinished, 'yyyy.mm.dd HH:MM:SS');
            obj.TaskQueue(1).elapsedTime = datestr(obj.TaskQueue(1).elapsedTime, 'HH:MM:SS');
            
            
            diary = obj.runningTask.Diary;
            error = obj.runningTask.Error;
            
            if ~isempty(obj.runningTask.Error)
                obj.TaskQueue(1).status = 'Failed';
            else
                obj.TaskQueue(1).status = 'Completed';
            end

            
            obj.runningTask = [];
            obj.Status = 'idle';
            
            % Move task to history list
            finishedTask = obj.TaskQueue(1);
            finishedTask.Diary = diary;
            finishedTask.ErrorStack = error;
            obj.TaskQueue(1) = [];
            
            % Add to items of the task queue.
            if isempty(obj.TaskHistory)
                obj.TaskHistory = finishedTask;
            else
                obj.TaskHistory = cat(2, finishedTask,  obj.TaskHistory);
            end
            
            % Remove task from queue table
            eventData = uiw.event.EventData('Table', 'Queue', 'TaskIdx', 1);
            obj.notify('TaskRemoved', eventData)
            
            % Add task to history table
            evtData = uiw.event.EventData('Table', 'History', 'Task', finishedTask);
            obj.notify('TaskAdded', evtData)

            
            % Start new task
            if obj.isRunning
               obj.startTask() 
            end
            
        end % /function finishTask
        
        
% % % % Methods related to managing tasks in the Queue and History list

        function addTaskToQueueTable(obj, S)
            
            % Select the following fields fram the task struct for
            % displaying in the uitable queue viewer
            
            fields = {'name', 'methodName', 'status', 'timeCreated', 'parameters', 'comments'};
            tableEntry = struct2table(S, 'AsArray', true);
            tableEntry = tableEntry(:, fields);
            
            % Add the task to the uitable.
            obj.queueTable.addTask(tableEntry, 'end')

        end
        
        function removeTaskFromQueueTable(obj, S)
            
        end
        
        function addTaskToHistoryTable(obj, S)
            
            % Select the following fields fram the task struct for
            % displaying in the uitable history viewer
            fields = {'name', 'methodName', 'status', 'timeFinished', 'elapsedTime', 'comments'};
            
            tableEntry = struct2table(S, 'AsArray', true);
            tableEntry = tableEntry(:, fields);
            
            obj.historyTable.addTask(tableEntry, 'beginning')
            
        end
        
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
        
        function onEditOptionsClicked(obj, s, e)
            
            % Loop through selected rows:
            for i = obj.queueTable.selectedRows
                
                % Get task object:
                hTask = obj.TaskQueue(i);
                
                optsName = hTask.parameters;
                optsStruct = hTask.args{2};
                
                mConfig = hTask.method();
                optManager = mConfig.OptionsManager;
                
                
                [optsName, optsStruct] = optManager.editOptions(optsName, optsStruct);

                hTask.parameters = optsName;
                hTask.args{2} = optsStruct;
                
                % Update task object in the queue.
                obj.TaskQueue(i) = hTask;
                
                % Todo:
                % Give session objects and specified options as inputs to
                % the options manager / options adapter?
             
                obj.refreshTable();
                
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