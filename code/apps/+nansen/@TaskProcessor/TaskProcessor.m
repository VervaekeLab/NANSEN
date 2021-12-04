classdef TaskProcessor < uiw.mixin.AssignPVPairs
% This class implemements a manager for adding tasks to a queue-based
% processor.
    
% Todo: 
%   [ ] Separate between recently finished tasks and the complete log


%% PROPERTIES

    properties % Properties keeping track of tasks and status
        TaskQueue % A list of tasks present in the queue
        TaskHistory % A list of tasks present in the history
    	Status
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
        selectedRows
        selectedColumns
    end
    
    properties (Dependent, Access = private)
        ActivePool
    end
    
    properties (Constant, GetAccess = private) % Column names for table views. Todo: Move to separate classes?
        queueTableVars =  {'SessionID', 'Method', 'Status', 'Submitted', 'Parameters', 'Comment'}
        processingTableVars = {'SessionID', 'Method', 'Status', 'Started', 'Elapsed time', 'Comment'}
        historyTableVars = {'SessionID', 'Method', 'Status', 'Finished', 'Elapsed Time', 'Comment'}
    end
    
    
%% METHODS

    methods % Structors
                
        function obj = TaskProcessor(varargin)
        %queueProcessor Create a task processor.
            
            obj.Parent = varargin{2};
            % Todo: Add parent destroyed listener.
            
%             obj.assignPVPairs(varargin{:});
            
            obj.loadTaskLists()

            obj.createPanels()
            obj.createTable()
            drawnow
            
            obj.refreshTable()
            
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
            
            % Delete table view instances
            delete(obj.queueTable)
            delete(obj.historyTable)
            
        end
        
    end
    
    
    methods
        
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
        
            % Create a struct for the items and a table row for the table
            newTask.name = name;
            newTask.method = func;
            newTask.methodName = utility.string.varname2label( func2str(func) );
            newTask.status = 'Created';
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
            obj.addTaskToQueueTable(newTask)
            
        end
        
        
        function loadTaskLists(obj, filePath)
        % loadTaskLists Load a list of tasks from file
        %------------------------------------------------------------------
        %
        % Abstract: Set column sizes automatically to fit the contents
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
        
        
    end

    
    methods (Access = private)
        
        function openFigure()
            
        end
        
        function closeFigure()
            
        end
        
% % % % Methods related to creating the gui

        function createPanels(obj)
        
            % Create TabGroup
            hParent = obj.Parent;
            obj.TabGroup = uitabgroup(hParent);
            obj.TabGroup.Units = 'normalized'; 
            
            %obj.TabGroup.Position = [0 0 1 1];

            % Create Queue and History tab
            obj.queueTab = uitab(obj.TabGroup);
            obj.queueTab.Title = 'Queue';
            
            obj.historyTab = uitab(obj.TabGroup);
            obj.historyTab.Title = 'History';

        end
        
        function createTable(obj)
           
            drawnow % Need to add this for tables to be positioned properly        
            obj.queueTable = nansen.uiwTaskTable('Parent', obj.queueTab, ...
                'ColumnNames', obj.queueTableVars);

            
            obj.historyTable = nansen.TaskTable('Parent', obj.historyTab, ...
                'ColumnNames', obj.historyTableVars);

            
% % %             obj.processingTable = nansen.uiwTaskTable('Parent', obj.queueTab, ...
% % %                 'ColumnNames', obj.processingTableVars);
% % %             
% % %             pixelposition1 = getpixelposition(obj.queueTable.Table);
% % %             pixelposition2 = getpixelposition(obj.processingTable.Table);
% % %             pixelposition1(4) = pixelposition1(4) - 40;
% % %             
% % %             pixelposition2(4) = 40;
% % %             pixelposition2(2) = pixelposition1(4);
% % %             setpixelposition(obj.queueTable.Table, pixelposition1)
% % %             setpixelposition(obj.processingTable.Table, pixelposition2)
% % % 
% % %             obj.processingTable.Table.ColumnResizePolicy = 'subsequent';
            
            obj.queueTable.Table.UIContextMenu = obj.createQueueContextMenu();
            

        end
        
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
            
            
            if ~obj.isRunning; return; end
            
            
            if isempty(obj.runningTask)
                % Start new task:
                obj.startTask();
            end
            
            if isempty(obj.runningTask); return ; end
            
            
            status = obj.runningTask.State;
            
            switch status
                
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
                case 'queued'
                    
                    % Assign the job to the cluster
                    p = gcp();
                    F = parfeval(p, @task.method, 0, task.args{:});                    
                    obj.runningTask = F;
                    
                    obj.TaskQueue(1).status = 'running';
                    obj.refreshTable()
                    
                    obj.Status = 'running';
                    
            end
            
            

            % Update table status
            
        end % /function startTask
        
        function finishTask(obj)
        
            % TODO: Get error....
            
            % Update table status
            obj.TaskQueue(1).timeStarted = obj.runningTask.StartDateTime;
            obj.TaskQueue(1).timeFinished = obj.runningTask.FinishDateTime;
            obj.TaskQueue(1).elapsedTime = obj.runningTask.FinishDateTime - obj.runningTask.StartDateTime;
            obj.TaskQueue(1).status = 'finished';
            
            obj.runningTask = [];
            obj.Status = 'idle';
            
            % Move task to history list
            task = obj.TaskQueue(1);
            obj.TaskQueue(1) = [];
            
            obj.addTaskToHistoryTable(task)
            
            obj.refreshTable()
            
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
        
        function addTaskToHistoryTable(obj, S)
            
            % Select the following fields fram the task struct for
            % displaying in the uitable history viewer
            fields = {'name', 'methodName', 'status', 'timeFinished', 'elapsedTime', 'comments'};
            
            % Todo: This should be part of the finish taks method.
            S.timeFinished = datestr(S.timeFinished, 'yyyy.mm.dd HH:MM:SS');
            S.elapsedTime = datestr(S.elapsedTime, 'HH:MM:SS');

            tableEntry = struct2table(S, 'AsArray', true);
            tableEntry = tableEntry(:, fields);
            
            obj.historyTable.addTask(tableEntry, 'beginning')
            
        end
        
        function setTaskStatus(obj, src, event, newStatus)
            
            selectedRows = obj.queueTable.selectedRows;

            switch newStatus
                case 'queue'
                    
                    statusList = {obj.TaskQueue.status};
                    
                    ind = find( contains(statusList, 'queue'), 1, 'last');
                    
                    if isempty(ind) 
                        ind = find( contains(statusList, 'running'), 1, 'last');
                        if isempty(ind)
                            ind = 0;
                        end
                    end
                    
                    poppedTasks = obj.TaskQueue(selectedRows);
                    
                    for i = 1:numel(poppedTasks)
                        poppedTasks(i).status = 'queued';
                    end
                    
                    obj.TaskQueue(selectedRows) = [];
                    
                    obj.TaskQueue = [ obj.TaskQueue(1:ind), ...
                                      poppedTasks, obj.TaskQueue(ind+1:end) ];
                    
                    obj.refreshTable();
                    
                    
                case 'pause'
                    
                    for i = selectedRows
                        obj.TaskQueue(i).status = 'paused';
                    end
                    obj.refreshTable();

                
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
        
        function refreshTable(obj)
        % Todo: Make this more efficient.
        
            obj.queueTable.clearTable()
        
            if isempty(obj.TaskQueue); return; end
            
            fields = {'name', 'methodName', 'status', 'timeCreated', 'parameters', 'comments'};
            
            tableEntry = struct2table(obj.TaskQueue, 'AsArray', true);
            tableEntry = tableEntry(:, fields);
            %tableEntry(:, 'parameters') = {'Edit'}; %todo!!!
            
            for i = 1:size(tableEntry, 1)
                obj.queueTable.addTask(tableEntry(i, :), 'end')
            end
            
        end
        
        function removeTask(obj, src, event)
            ind = obj.queueTable.selectedRows;
            
            obj.TaskQueue(ind) = [];
            obj.refreshTable()
            
        end
        
        function changeOrder()
            
        end
        
        function onListUpdate()
            
        end
        
        function onTableUpdate()
            
        end
        
    end
    
    
    methods (Access = private)
        
        function h = createQueueContextMenu(obj)
            
            hFig = ancestor(obj.Parent, 'figure');
            h = uicontextmenu(hFig);
            
            mTmp = uimenu(h, 'Text', 'Queue Task', 'Callback', @(s,e,newStatus) obj.setTaskStatus(s,e,'queue'));
            mTmp = uimenu(h, 'Text', 'Pause Task', 'Callback', @(s,e,newStatus) obj.setTaskStatus(s,e,'pause'));
            mTmp = uimenu(h, 'Text', 'Edit Options', 'Callback', @(s,e) obj.onEditOptionsClicked(s,e), 'Separator', 'on'); % Todo: create callback
            mTmp = uimenu(h, 'Text', 'Remove Task', 'Callback', @(s,e) obj.removeTask(), 'Separator', 'on');

        
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