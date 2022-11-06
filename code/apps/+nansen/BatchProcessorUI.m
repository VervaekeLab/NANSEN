classdef BatchProcessorUI < handle
    
    
    properties
        ParentContainer
        BatchProcessor nansen.TaskProcessor
    end
    
    properties (Dependent)
        SelectedRowIndices % Selected row indices from the table in current tab
    end
    
    properties (Access = private)
        TabGroup
        UITabTaskQueue
        UITabTaskHistory
                
        UITableQueue
        UITableHistory
    end
    
    properties (Constant, GetAccess = private) % Column names for table views.
        QueueTableVars =  {'SessionID', 'Method', 'Status', 'Submitted', 'Parameters', 'Comment'}
        HistoryTableVars = {'SessionID', 'Method', 'Status', 'Finished', 'Elapsed Time', 'Comment'}
    end
    
    
    methods % Structor
        
        function obj = BatchProcessorUI(batchProcessor, hContainer)
            
            obj.BatchProcessor = batchProcessor;
            obj.ParentContainer = hContainer;
            
            obj.createTabGroup()
            obj.createUiTables()
                        
            obj.TabGroup.Visible = 'on';
            
            % Call refresh table to update table contents
            obj.refreshTable('queue')
            obj.refreshTable('history')
            
        end
        
        function delete(obj)
            delete(obj.TabGroup)
        end
        
    end
    
    methods % Set/get methods
        
        function set.BatchProcessor(obj, newValue)
            
            obj.BatchProcessor = newValue;
            obj.onBatchProcessorSet()
            
        end
        
        function selectedIdx = get.SelectedRowIndices(obj)
            switch obj.TabGroup.SelectedTab.Title
                case 'Queue'
                    selectedIdx = obj.UITableQueue.selectedRows;
                case 'History'
                    selectedIdx = obj.UITableHistory.selectedRows;
            end
        end
    end
        
    methods (Access = private) % Methods for gui creation

        function createTabGroup(obj)
        %createTabGroup Create tabgroup with queue and history tabs.
        
            % Create TabGroup
            obj.TabGroup = uitabgroup(obj.ParentContainer, 'Visible', 'off');
            obj.TabGroup.Units = 'normalized'; 

            % Create Queue and History tab
            obj.UITabTaskQueue = uitab(obj.TabGroup);
            obj.UITabTaskQueue.Title = 'Queue';
            
            obj.UITabTaskHistory = uitab(obj.TabGroup);
            obj.UITabTaskHistory.Title = 'History';

        end
        
        function createUiTables(obj)
        %createTable Create ui tables for the taskqueue and taskhistory   
            
            drawnow % Need to add this for tables to be positioned properly        
            
            obj.UITableQueue = nansen.uiwTaskTable(...
                'Parent', obj.UITabTaskQueue, ...
                'ColumnNames', obj.QueueTableVars, ...
                'ColumnEditable', [false, false, false, false, false, true] );
            
            % Todo, save these based on user settings...
            obj.UITableQueue.Table.ColumnMaxWidth = [200, 500, 100, 200, 200, 500];
            obj.UITableQueue.Table.ColumnMinWidth = [150, 100, 50, 120, 150, 100];
            obj.UITableQueue.Table.ColumnPreferredWidth = [170, 200, 75, 135, 200, 200];
            obj.UITableQueue.Table.CellEditCallback = @obj.onTableCellEdited;

            obj.UITableHistory = nansen.uiwTaskTable(...
                'Parent', obj.UITabTaskHistory, ...
                'ColumnNames', obj.HistoryTableVars, ...
                'ColumnEditable', [false, false, false, false, false, true] );
            
            % Todo, save these based on user settings...
            obj.UITableHistory.Table.ColumnMaxWidth = [200, 500, 100, 200, 200, 500];
            obj.UITableHistory.Table.ColumnMinWidth = [150, 100, 50, 120, 120, 100];
            obj.UITableHistory.Table.ColumnPreferredWidth = [170, 200, 75, 135, 135, 200];
            obj.UITableHistory.Table.CellEditCallback = @obj.onTableCellEdited;
            obj.UITableHistory.Table.KeyPressFcn = @obj.onKeyPressedInTable;

            
            %obj.UITableQueue.Table.UIContextMenu = obj.createQueueContextMenu();
            %obj.UITableHistory.Table.UIContextMenu = obj.createHistoryContextMenu();
            
            obj.UITableQueue.UIContextMenu = obj.createQueueContextMenu();
            obj.UITableHistory.UIContextMenu = obj.createHistoryContextMenu();
           
            obj.UITableQueue.MouseButtonRightPressCallbackFcn = ...
                @obj.onMouseRightClickedInTable;
           
            obj.UITableHistory.MouseButtonRightPressCallbackFcn = ...
                @obj.onMouseRightClickedInTable;
        end
        
        function h = createQueueContextMenu(obj)
        %createQueueContextMenu Create context menu for the queue table    
            hFig = ancestor(obj.ParentContainer, 'figure');
            h = uicontextmenu(hFig);
            
            mTmp = uimenu(h, 'Text', 'Start Task(s)');
            mTmp.Callback = @(s,e) obj.onSetTaskStatusMenuItemClicked(s);
            mTmp = uimenu(h, 'Text', 'Pause Task(s)');
            mTmp.Callback = @(s,e) obj.onSetTaskStatusMenuItemClicked(s);
            mTmp = uimenu(h, 'Text', 'Delete Task(s)');
            mTmp.Callback = @(s,e) obj.onDeleteTaskMenuItemClicked('queue');            
            mTmp = uimenu(h, 'Text', 'Move Task(s)', 'Separator', 'on', 'Enable', 'off');
            labels = {'Top', 'Up', 'Down', 'Bottom'};
            for i = 1:numel(labels)
                mItem = uimenu(mTmp, 'Text', labels{i});
                mItem.Callback = @(s,e) obj.onMoveTasksMenuItemClicked(s);
            end

            mTmp = uimenu(h, 'Text', 'Show Full Diary', 'Separator', 'on');
            mTmp.Callback = @(s,e) obj.onShowDiaryMenuItemClicked('queue', 'full');
            mTmp = uimenu(h, 'Text', 'Show Last Diary Entry');
            mTmp.Callback = @(s,e) obj.onShowDiaryMenuItemClicked('queue', 'last');

            mTmp = uimenu(h, 'Text', 'Edit Options', 'Separator', 'on');
            mTmp.Callback = @(s,e) obj.onEditOptionsMenuItemClicked();
            
        end
        
        function h = createHistoryContextMenu(obj)
            
            hFig = ancestor(obj.ParentContainer, 'figure');
            h = uicontextmenu(hFig);
            
            mTmp = uimenu(h, 'Text', 'Reassign to Queue', 'Enable', 'on'); 
            mTmp.Callback = @(s, e) obj.onReassignToQueueMenuItemClicked;
                    
            mTmp = uimenu(h, 'Text', 'Show Diary', 'Separator', 'on', 'Enable', 'on'); 
            mTmp.Callback = @(s,e,str) obj.onShowDiaryMenuItemClicked('history');
            mTmp = uimenu(h, 'Text', 'Show Errors'); 
            mTmp.Callback = @(s,e) obj.onShowErrorsMenuItemClicked;
            mTmp.Accelerator = 'e';
            mTmp = uimenu(h, 'Text', 'Show Warnings', 'Enable', 'off');
            mTmp.Callback = [];
            
            mTmp = uimenu(h, 'Text', 'Delete Task(s)', 'Separator', 'on');
            mTmp.Callback = @(s,e,taskType) obj.onDeleteTaskMenuItemClicked('history');
            
        end
        
    end
    
    methods (Access = private) % Methods for gui update
        
        function taskList = getTaskList(obj, tableType, selectedIdx)
            
            switch lower( tableType )
                case 'queue'
                    taskList = obj.BatchProcessor.TaskQueue;
                case 'history'
                    taskList = obj.BatchProcessor.TaskHistory;
            end
            
            if nargin >=3 
                taskList = taskList(selectedIdx);
            end
            
        end
        
        function hTable = getUiTable(obj, tableType)
            switch lower( tableType )
                case 'queue'
                    hTable = obj.UITableQueue;
                case 'history'
                    hTable = obj.UITableHistory;
            end
        end
        
        function [hTable, taskList] = getTableRefs(obj, tableType)
        %getTableRefs Get uitable handle and task list for gien tabletype   
            switch tableType
                case 'queue'
                    hTable = obj.UITableQueue;
                    taskList = obj.BatchProcessor.TaskQueue;
                case 'history'
                    hTable = obj.UITableHistory;
                    taskList = obj.BatchProcessor.TaskHistory;
            end
        end
        
        function taskTable = getTableData(~, taskList, tableType)
            
            if nargin < 3; tableType = 'queue'; end
            
            switch tableType
                case 'queue'
                    fields = {'name', 'methodName', 'status', 'timeCreated', 'parameters', 'comments'};
                case 'history'
                    fields = {'name', 'methodName', 'status', 'timeFinished', 'elapsedTime', 'comments'};
            end
            
            taskTable = struct2table(taskList, 'AsArray', true);
            taskTable = taskTable(:, fields);
            
        end
        
        function names = getTableVariableNames(obj, tableType)
            switch lower( tableType )
                case 'queue'
                    names = obj.QueueTableVars;
                case 'history'
                    names = obj.HistoryTableVars;
            end            
        end
        
        function refreshTable(obj, tableType)
        %refreshTable Refresh table data of specified table type
            
            if nargin < 2; tableType = 'queue'; end
            [hTable, taskList] = obj.getTableRefs(tableType);
            
            hTable.clearTable()
            
            if isempty(taskList); return; end
            
            taskTable = obj.getTableData( taskList, tableType);
            
            hTable.Table.Data = table2cell(taskTable);
            %hTable.Table.ColumnNames = obj.getTableVariableNames(tableType);
        end
        
        function refreshRow(obj, rowIdx, tableType)
        %refreshRow Refresh cells of given row idx for specified table type
        
            if nargin < 3; tableType = 'queue'; end
            [~, taskList] = obj.getTableRefs(tableType);
            
            taskTable = obj.getTableData( taskList(rowIdx) );
            
            numCols = size(taskTable, 2);
            obj.refreshTableCells(rowIdx, 1:numCols, table2cell(taskTable))
                
        end
        
        function refreshTableCells(obj, rowIdx, columnIdx, newData)
        %refreshTableCells Refresh individual cells of table.
            for iRow = 1:numel(rowIdx)
                for jCol = 1:numel(columnIdx)
                    newCellValue = newData(iRow, jCol);
                    obj.UITableQueue.Table.setCell(rowIdx(iRow), ...
                        columnIdx(jCol), newCellValue)
                end
            end
        end
        
        function appendTaskToQueueTable(obj, ~, evt)
        %appendTaskToQueueTable
            
            % Select the following fields fram the task struct for
            % displaying in the uitable queue viewer
            
            S = evt.Task;
            
            fields = {'name', 'methodName', 'status', 'timeCreated', 'parameters', 'comments'};
            tableEntry = struct2table(S, 'AsArray', true);
            tableEntry = tableEntry(:, fields);
            
            % Add the task to the uitable.
            obj.UITableQueue.addTask(tableEntry, 'end')
        end
        
        function insertTaskToHistoryTable(obj, ~, evt)
        %insertTaskToHistoryTable
        
            S = evt.Task;

            % Select the following fields from the task struct for
            % displaying in the uitable history viewer
            fields = {'name', 'methodName', 'status', 'timeFinished', 'elapsedTime', 'comments'};
            
            tableEntry = struct2table(S, 'AsArray', true);
            tableEntry = tableEntry(:, fields);

            obj.UITableHistory.addTask(tableEntry, 'beginning')
        end
        
        function onTaskAdded(obj, src, evt)
            
            switch evt.Table
                case 'Queue'
                    obj.appendTaskToQueueTable(src, evt)
                case 'History'
                    obj.insertTaskToHistoryTable(src, evt)
            end
        end
        
        function onTaskRemoved(obj, ~, evt)
            
            taskIdx = evt.TaskIdx;
            
            switch lower( evt.Table )
                case 'queue'
                    obj.UITableQueue.Table.Data(taskIdx,:) = [];
                case 'history'
                    obj.UITableHistory.Table.Data(taskIdx,:) = [];
            end
        end
        
        function onTaskStateChanged(obj, ~, evt)
        %onTaskStateChanged Callback for batchprocessor event     
           
            rowIdx = evt.TaskIdx;
            
            data = evt.NewState;
            if ~isa(data, 'cell')
                data = {data};
            end
            
            obj.refreshTableCells(rowIdx, 3, data) % 3rd column is status...
            drawnow
            
        end
        
        function onTaskOrderChanged(obj, ~, evt)
            
            rowIdx = evt.IndexOrder;
            obj.UITableQueue.Table.Data = obj.UITableQueue.Table.Data(rowIdx, :);
            
        end
        
        function onTableUpdated(obj, ~, ~)
            obj.refreshTable('queue')
            obj.refreshTable('history')
        end

        function updateQueueContextMenu(obj, taskList)
        %updateQueueContextMenu Set enabled state of menu items
        %
        %   Work in progress. Change enable state of menu items based on
        %   the state of task items that are selected.
        
            %hMenu = obj.UITableQueue.Table.UIContextMenu;
            hMenu = obj.UITableQueue.UIContextMenu;

          % % Enable/disable "Pause Task(s)" items
            mItem = findobj(hMenu, 'Text', 'Pause Task(s)');
            if all( strcmp({taskList.status}, 'Paused') )
                mItem.Enable = 'off';
            else
                mItem.Enable = 'on';
            end
            
          % % Enable/disable "Show Diary" items
            mItem = findobj(hMenu, 'Text', 'Show Full Diary');
            mItem(2) = findobj(hMenu, 'Text','Show Last Diary Entry');
            
            mItem2 = findobj(hMenu, 'Text', 'Edit Options');
            if all( strcmp({taskList.status}, 'Running') )
                set(mItem, 'Enable', 'on')
                mItem2.Enable = 'off';
            else
                set(mItem, 'Enable', 'off')
                mItem2.Enable = 'on';
            end
            
          % % Set appropriate text for the "Start Task(s)" item. I.e if the
          % state of the task is running, change menu text to "Cancel Task"
            mItem = findobj(hMenu, 'Text', 'Start Task(s)');
            if isempty(mItem) && any(~strcmp({taskList.status}, 'Running'))
                mItem = findobj(hMenu, 'Text', 'Abort Task');
                mItem.Text = 'Start Task(s)';
            else
                if ~isempty(mItem) && all( strcmp({taskList.status}, 'Running') )
                    mItem.Text = 'Abort Task';
                end
            end
            
            
        end
    end
    
    methods (Access = private) % UI Interaction Callback methods
        
        function onDeleteTaskMenuItemClicked(obj, tableType)
            
            if nargin < 2; tableType = 'queue'; end
            
% %             switch lower(tableType)
% %                 case 'queue'
% %                     selectedIdx = obj.UITableQueue.selectedRows;
% %                 case 'history'
% %                     selectedIdx = obj.UITableHistory.selectedRows;
% %             end
            selectedIdx = obj.SelectedRowIndices;
            
            obj.BatchProcessor.removeTask(selectedIdx, tableType)
            %obj.refreshTable(tableType)
        end
        
        function onSetTaskStatusMenuItemClicked(obj, menuItem)
        %onSetTaskStatusMenuItemClicked User changed status of one or more tasks
            
            assertMessage = 'This method is a menu item callback, but the source input was not a menu item';
            assert(isa(menuItem, 'matlab.ui.container.Menu'), assertMessage)
        
            switch menuItem.Text
                case 'Start Task(s)'
                    newStatus = 'Initialize';
                case 'Pause Task(s)'
                    newStatus = 'Pause';
                case 'Abort Task'
                    newStatus = 'Cancel';
            end
        
            rowIdx = obj.UITableQueue.selectedRows;
            
            if any(rowIdx == 1) 
                firstTask = obj.BatchProcessor.getQueuedTask(1);
                if strcmp(firstTask.status, 'Running') && ~strcmp(newStatus, 'Cancel')
                    msgbox('Task is already running.')
                    rowIdx(rowIdx==1) = [];
                end
            end
            
            if isempty(rowIdx)
                return
            end

            obj.BatchProcessor.setTaskStatus(newStatus, rowIdx)

        end

        function onMoveTasksMenuItemClicked(obj, src)
            selectedRows = obj.UITableQueue.SelectedRows;
            obj.BatchProcessor.rearrangeQueuedTasks(selectedRows, src.Text)
        end
        
        function onEditOptionsMenuItemClicked(obj)
            
            % Todo:
            % Give session objects and specified options as inputs to
            % the options manager / options adapter?
            
            
            % Loop through selected rows:
            for i = obj.UITableQueue.selectedRows
            
                % Get task object:
                hTask = obj.BatchProcessor.getQueuedTask(i);
                
                if strcmp(hTask.status, 'Running')
                    msgbox('Can not edit options for a running task')
                    continue
                end
                
                
                optsName = hTask.parameters;
                optsStruct = hTask.args{2};
                
                mConfig = hTask.method();
                if isa(mConfig, 'struct')
                    % Add an options manager to the mConfig struct
                    mConfig.OptionsManager = nansen.manage.OptionsManager(..., 
                        func2str(hTask.method), mConfig.DefaultOptions);
                end
                
                optManager = mConfig.OptionsManager;
                
                [optsName, optsStruct] = optManager.editOptions(optsName, optsStruct);

                hTask.parameters = optsName;
                hTask.args{2} = optsStruct;
                
                % Update task object in the queue.
                obj.BatchProcessor.setQueuedTask(hTask, i);
                
                obj.refreshRow(i)
                                
            end
            
        end

        function onShowDiaryMenuItemClicked(obj, ~, mode)
            if nargin < 3; mode = 'full'; end
            obj.showDiaryForSelectedRows(mode)
        end
        
        function onShowErrorsMenuItemClicked(obj)
        %onShowErrorsMenuItemClicked Show errors for selected tasks
            obj.showErrorsForSelectedRows()
        end
        
        function onReassignToQueueMenuItemClicked(obj)
            
            taskItems = obj.getTaskList('history', obj.SelectedRowIndices);
            
            for i = 1:numel(taskItems)
                taskArgs = {taskItems(i).name, taskItems(i).method, ...
                    0, taskItems(i).args, taskItems(i).parameters, ...
                    taskItems(i).comments} ;
                obj.BatchProcessor.submitJob( taskArgs{:} )
            end
            
        end
        
        function onTableCellEdited(obj, src, evt)
            
            taskType = obj.TabGroup.SelectedTab.Title;          
            taskIdx = evt.Indices(1);
            
            if evt.Indices(2) == 6
                newComment = evt.NewValue;
                obj.BatchProcessor.updateTaskComment(taskType, taskIdx, newComment)
            end
            
        end
        
    end
    
    methods (Access = private) % Actions
            
        function showErrorsForSelectedRows(obj)
            rowIdx = obj.UITableHistory.selectedRows;
            taskItems = obj.BatchProcessor.getArchivedTask(rowIdx);
            obj.displayErrors(taskItems)    
        end
        
        
        function showDiaryForSelectedRows(obj, mode)
            
            if nargin < 2; mode = 'full'; end
            
            taskType = obj.TabGroup.SelectedTab.Title;
            
            switch lower( taskType )
                case 'queue'
                    rowIdx = obj.UITableQueue.selectedRows;

                    if ~any(rowIdx == 1)
                        msgbox('Can only show diary for running task')
                        return
                    elseif any(rowIdx == 1) && numel(rowIdx) > 1
                        msgbox('Showing diary for the running task')
                    end

                    taskItems = obj.BatchProcessor.getQueuedTask(rowIdx);

                    diary = obj.BatchProcessor.getCurrentDiary();
                    switch mode
                        case 'last'
                            diary = strsplit(diary, newline);
                            if isempty(diary{end}); diary = diary(1:end-1); end
                            diary = diary{end};
                        case 'full'

                    end
                    taskItems.Diary = diary;

                case 'history'
                    rowIdx = obj.UITableHistory.selectedRows;
                    taskItems = obj.BatchProcessor.getArchivedTask(rowIdx);
            end
            
            obj.displayDiary(taskItems)
        end
        
    end
    
    methods (Access = private) % Internal callbacks
        function onBatchProcessorSet(obj)
        %onBatchProcessorSet Callback for when the BatchProcessor is set.    
            
            addlistener(obj.BatchProcessor, 'TaskAdded', ...
                @obj.onTaskAdded);
            
            addlistener(obj.BatchProcessor, 'TaskRemoved', ...
                @obj.onTaskRemoved);
            
            addlistener(obj.BatchProcessor, 'TaskStateChanged', ...
                @obj.onTaskStateChanged);
            
            addlistener(obj.BatchProcessor, 'TaskOrderChanged', ...
                @obj.onTaskOrderChanged);

            addlistener(obj.BatchProcessor, 'TableUpdated', ...
                @obj.onTableUpdated);
        end
        
        function onMouseRightClickedInTable(obj, src, evt)
        %onMouseRightClickedInTable Method to run when right click happens in table    
            
            tableType = obj.TabGroup.SelectedTab.Title;
            taskIdx = sort( obj.SelectedRowIndices );
            taskList = obj.getTaskList(tableType, taskIdx);
            hTable = obj.getUiTable(tableType);
            
            switch tableType
                case 'Queue'
                    % Special case, if right click happened on first cell
                    % and the state of the first task is running, only that
                    % row should be selected (for contextmenu to appear 
                    % consistent).
                    
                    if evt.Cell(1) == 1
                        if strcmp(taskList(1).status, 'Running')
                            obj.UITableQueue.Table.SelectedRows = 1;
                            taskList = taskList(1);
                        end
                    end
                    
                    obj.updateQueueContextMenu(taskList)
                
                case 'History'
                    % Todo....
            end
            
            % "Manually" open context menu
            figurePos = hTable.Table.tablepoint2figurepoint(evt.Position);
            hTable.UIContextMenu.Position(1:2) = figurePos + [0, 40]; % Correct y pos, 40 pixels, no idea why or if it is consistent across systems..
            hTable.UIContextMenu.Visible = 'on';
            
        end
        
        function onKeyPressedInTable(obj, src, evt)
            
            isControl = @(m) all(strcmp(m, 'command')) || all(strcmp(m, 'control'));
            
            switch evt.Key
                case 'e'
                    if isControl(evt.Modifier) 
                        obj.showErrorsForSelectedRows()
                    end
                case 'd'
                    if isControl(evt.Modifier) 
                        obj.showDiaryForSelectedRows()
                    end
                    
            end
            
            
        end
            
    end
    
    methods (Static)
        
        function displayDiary(items)
            
            for i = 1:numel(items)
                fprintf('\n# # # Diary for session %s, method "%s":\n', items(i).name, func2str(items(i).method))
                if isempty(items(i).Diary)
                    disp('<EMPTY>')
                else
                    disp(items(i).Diary)
                end
            end
            
        end
        
        function displayErrors(items)
            
            for i = 1:numel(items)
                fprintf('\n# # # Errors for session %s, method "%s":\n', items(i).name, func2str(items(i).method))
                if isempty(items(i).ErrorStack)
                    disp('<NO ERROR>')
                else
                    disp(getReport(items(i).ErrorStack, 'extended'))
                end
            end
            
        end
        
    end
    
    
end