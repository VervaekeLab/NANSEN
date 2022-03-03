classdef PipelineBuilderUI < applify.AppWindow & applify.HasTheme
%PIPELINEBUILDER App for building pipeline by adding and ordering tasks
    %   Detailed explanation goes here
    
    properties (Constant, Hidden)
        DEFAULT_THEME = nansen.theme.getThemeColors('deepblue')
    end
    
    properties (Constant)
        AppName = 'Pipeline Builder'
    end
    
    properties (SetAccess = private)
        PipelineStruct
        SessionMethodCatalog
        TaskTableData
        TaskTableDataOrig
    end
    
    properties (Access = protected) % UI Components
        AddTaskButton
        AutoCompleteWidget
        BrowseTaskFunctionButton
        UITable
        
        HintTextbox
        
        TableContextMenu
        
        UiMenuA
        UiMenuB
    end
    
    properties
        dropdownOpen = false;
    end
    
    
    methods % Constructor
        
        function obj = PipelineBuilderUI(pipelineStruct, sessionMethodCatalog)
        %PIPELINEBUILDERUI Construct an instance of this class
            %   Detailed explanation goes here
            
            obj@applify.AppWindow()
    
            % Assign input to properties
            obj.PipelineStruct = pipelineStruct;
            obj.SessionMethodCatalog = sessionMethodCatalog; % Todo....
            
            % Create components
            obj.createComponents()
            obj.setComponentLayout()
            obj.createContextMenus()
            
            % Set data for table (important to do after creating table...)
            pipelineTable = struct2table( pipelineStruct.PipelineTasks, 'AsArray', true );
            obj.TaskTableDataOrig = pipelineTable;
            obj.TaskTableData = pipelineTable;
            
            obj.Figure.SizeChangedFcn = @(s,e) obj.setComponentLayout;
            obj.Figure.CloseRequestFcn = @(s,e) obj.onFigureClosed;
            
            obj.IsConstructed = true;
            obj.onThemeChanged()
            
        end

    end
    
    methods (Access = protected) % Override AppWindow methods
        function assignDefaultSubclassProperties(obj)
            obj.DEFAULT_FIGURE_SIZE = [800 560];
            obj.MINIMUM_FIGURE_SIZE = [560 420];
        end 
        
        function setComponentLayout(obj)
            
            totalWidth = obj.CanvasSize(1);
            
            % h+w of autocomplete and buttons:
            componentHeight = [30, 22, 22]; 
            componentWidth = [1, 50, 60];
            
            % Calculate position:
            [x, w] = uim.utility.layout.subdividePosition(obj.Margins(1), ...
                totalWidth, componentWidth, 15);

            % Complete ad hoc...
            y = obj.CanvasSize(2) - (componentHeight/3);

            
            % Set positions:
            obj.AutoCompleteWidget.Position = [x(1), y(1), w(1), componentHeight(1)];
            obj.AddTaskButton.Position = [x(2), y(2), w(2), componentHeight(2)];
            obj.BrowseTaskFunctionButton.Position = [x(3), y(3), w(3), componentHeight(3)];

            
            obj.UITable.Position = [obj.Margins(1:2), ...
                totalWidth, y(1) - sum(obj.Margins([2,4])) - 10]; % Substract 10 to not interfere with button tooltips...Yeah, i know...
            
            
            [~, colWidth] = uim.utility.layout.subdividePosition(1, ...
                totalWidth, [60, 150, 1, 150], 0);
            obj.UITable.ColumnPreferredWidth = colWidth;
            %obj.UITable.ColumnWidth = [40, 100, 100, 100];
            
            
            obj.HintTextbox.Position = [obj.Margins(1), sum(obj.UITable.Position([2,4])) + 15];

            
        end
        
    end
    
    methods (Access = private)
        
        
        function createComponents(obj)
            
            % Create search dialog
            sessionMethodNames = {obj.SessionMethodCatalog.Data.FunctionName};
            obj.AutoCompleteWidget = uics.searchAutoCompleteInputDlg(obj.Figure, sessionMethodNames);
            obj.AutoCompleteWidget.PromptText = 'Search for session method';
            
            % Create buttons
            buttonProps = {'Style', uim.style.buttonLightMode, ...
                'HorizontalTextAlignment', 'center'};
            
            obj.AddTaskButton = uim.control.Button_(obj.Figure, 'Text', 'Add', buttonProps{:});
            obj.AddTaskButton.Tooltip = 'Add session method to pipeline';
            obj.AddTaskButton.TooltipYOffset = 10;
            obj.BrowseTaskFunctionButton = uim.control.Button_(obj.Figure, 'Text', 'Browse', buttonProps{:});
            obj.BrowseTaskFunctionButton.Tooltip = 'Browse to find function';
            obj.BrowseTaskFunctionButton.TooltipYOffset = 10;
            
            obj.AddTaskButton.Callback = @obj.onAddTaskButtonPushed;
            obj.BrowseTaskFunctionButton.Callback = @obj.onBrowseFunctionButtonPushed;
            
            uicc = getappdata(obj.Figure, 'UIComponentCanvas');
            obj.HintTextbox = text(uicc.Axes, 1,1, '');
            obj.HintTextbox.String = 'Hint: Add tasks from search field and rearrange in table to create pipeline';
            obj.HintTextbox.HorizontalAlignment = 'left';
            obj.HintTextbox.FontSize = 10;
            %obj.HintTextbox.BackgroundColor = 'none';
            % Create table
            obj.UITable  = uim.widget.StylableTable('Parent', obj.Figure, ...
                        'RowHeight', 25, ...
                        'FontSize', 8, ...
                        'FontName', 'helvetica', ...
                        'FontName', 'avenir next', ...
                        'Theme', uim.style.tableLight, ...
                        'Units', 'pixels' );
                    
            obj.UITable.CellEditCallback = @obj.onTableCellEdited;
            obj.UITable.MouseClickedCallback = @obj.onTableCellClicked;
            obj.UITable.CellSelectionCallback = @obj.onTableCellSelected;
            obj.UITable.KeyPressFcn = @obj.onKeyPressedInTable;

            addlistener(obj.UITable, 'MouseMotion', @obj.onMouseMotionOnTable);
            %addlistener(obj.UITable, 'KeyPress', @obj.onKeyPressedInTable);

        end
        
        function createContextMenus(obj)
            
            obj.TableContextMenu = uicontextmenu(obj.Figure);
            mitem = uimenu(obj.TableContextMenu, 'Text', 'Remove Task');
            mitem.Callback = @obj.onRemoveTaskMenuItemClicked;

        end
        

    end
    
    methods (Access = protected)
        
        function setDefaultFigureCallbacks(obj)
            obj.Figure.WindowKeyPressFcn = @obj.onKeyPressedInTable;
        end
    
        function onThemeChanged(obj)
            % Todo:
        end
    end
    
    methods % Set/get
        
        function set.TaskTableData(obj, newValue)
            obj.TaskTableData = newValue;
            obj.onTaskTableDataSet()
        end
        
    end
    
    methods (Access = private) % Component and user invoked callbacks
        
        function onKeyPressedInTable(obj, src, evt)
            
            switch evt.Key
                case {'backspace', '⌫'}
                    selectedRow = obj.UITable.SelectedRows;
                    if ~isempty(selectedRow)
                        obj.removeTask(selectedRow)
                    end
            end
            
        end

        function onTaskTableDataSet(obj)
            
            obj.UITable.DataTable = obj.TaskTableData;
            numRows = size(obj.TaskTableData, 1);
            
            % Update the column formatting properties
            obj.UITable.ColumnFormat = {'popup', 'char', 'char', 'popup'};

            colFormatData = {arrayfun(@(x) uint8(x), 1:numRows, 'uni',0), [], [], {'OptionA', 'OptionB'}};
            
            obj.UITable.ColumnFormatData = colFormatData;
            obj.UITable.ColumnEditable = [true, true, false, true];
            
        end
        
        function onTableCellEdited(obj, src, evt)
        %onTableCellEdited Callback for table cell edits..
        
            switch evt.Indices(2) % Column numbers..
                
                case 1 % Column showing task numbers
                    obj.rearrangeRows(src, evt)
                
                case 4 % Column showing option presets


            end

        end

        function onTableCellClicked(obj, src, evt)
  
            if evt.Button == 3 || strcmp(evt.SelectionType, 'alt')
                obj.onMouseRightClickedInTable(src, evt)
            end
            
        end
        
        function onTableCellSelected(obj, src, evt)
                         
            colNum = obj.UITable.JTable.getSelectedColumns() + 1;
            rowNum = evt.SelectedRows;
            
            if colNum == 4
                obj.dropdownOpen = true;
            else
                obj.dropdownOpen = false;
            end
            
            
            %cellRenderer = obj.UITable.JTable.getCellRenderer(rowNum-1,colNum-1);
            
            %mPos = java.awt.Point(x,y)
            
            %obj.UITable.JTable.getPoint(rowNum, colNum)
            %obj.UiMenuA.Visible = 'on';
            %colNum = evt.Cell(2);
            
        end
        
        function onMouseRightClickedInTable(obj, src, evt)
            
            % Get row where mouse press ocurred.
            row = evt.Cell(1);

            % Select row where mouse is pressed if it is not already
            % selected
            if ~ismember(row, obj.UITable.SelectedRows)
                obj.UITable.SelectedRows = row;
            end

            % Get scroll positions in table
            xScroll = obj.UITable.JScrollPane.getHorizontalScrollBar().getValue();
            yScroll = obj.UITable.JScrollPane.getVerticalScrollBar().getValue();

            % Get position where mouseclick occured (in figure)
            clickPosX = evt.Position(1) - xScroll;
            clickPosY = evt.Position(2) - yScroll;

            % Open context menu for table
            if ~isempty(obj.TableContextMenu)
                obj.openTableContextMenu(clickPosX, clickPosY);
            end
            
        end
        
        function onMouseMotionOnTable(obj, src, evt)
            
            persistent previousRow
            if isempty(previousRow); previousRow = 0; end
            
            rowNum = evt.Cell(1);
            colNum = evt.Cell(2);

            if rowNum ~= previousRow && rowNum ~= 0                
                obj.updateOptionSelectionDropdown(rowNum)
                previousRow = rowNum;
            end
            
        end
        
        function onFigureClosed(obj)
            
            taskTableDataNew = obj.UITable.DataTable;
            isDirty = ~isequal(taskTableDataNew, obj.TaskTableDataOrig);
            
            if isDirty
            
                message = sprintf('Save changes to %s pipeline?', obj.PipelineStruct.PipelineName);
                title = 'Confirm Save';

                answer = questdlg(message, title, 'Yes', 'No', 'Cancel', 'Yes');

                switch answer

                    case 'Yes'
                        
                        pipelineModel = nansen.pipeline.PipelineCatalog;
                        pipelineName = obj.PipelineStruct.PipelineName;
                        
                        newTaskList = table2struct(taskTableDataNew);
                        pipelineModel.setTaskList(pipelineName, newTaskList)
                        
                        pipelineModel.save()
                    case 'No'

                    otherwise
                        return

                end
                
            end

            delete(obj.Figure)
            
        end
        
        function rearrangeRows(obj, hTable, eventData)
        %rearrangeRows Rearrange table rows in response to user input
        
            data = obj.UITable.DataTable;
            rowData = data(eventData.OldValue,:);
            data(eventData.OldValue,:) = [];

            data = utility.insertRowInTable(data, rowData, eventData.NewValue);

            numRows = size(data,1);
            for i = 1:numRows
                data{i, 1} = uint8(i);
            end

            obj.UITable.DataTable = data;

        end

        function updateTaskOrder(obj)
        %updateTaskOrder Update order of tasks in list. 
        %
        %   Useful when tasks are removed.
        
            data = obj.UITable.DataTable;
            numRows = size(data,1);
            for i = 1:numRows
                data{i, 1} = uint8(i);
            end

            obj.UITable.DataTable = data;

        end
        
        function onAddTaskButtonPushed(obj, src, evt)
            
            % Retrieve current task name from autocomplete field.
            
            % retrieve task object from task catalog
            
            % create a table data row
            
            % Add to table..
            obj.addTask()
        end
        
        function onBrowseFunctionButtonPushed(obj, src, evt)
        %onBrowseFunctionButtonPushed Callback for browse button
        
            % Open uigetfile in nansen (filter for .m files)
            fileSpec = {  '*.m', 'M Files (*.mat)'; ...
                            '*', 'All Files (*.*)' };
            
            [filename, folder] = uigetfile(fileSpec, 'Find Session Method');
            
            if filename == 0; return; end
            
            % Get full filepath. return if 0
            
            filePath = fullfile(folder, filename);
            
            %Todo: make sure function is on path....
            S = obj.SessionMethodCatalog.addSessionMethodFromPath(filePath);

            % Update autocomplete widget.
            obj.AutoCompleteWidget.Items{end+1} = S.FunctionName;
            obj.AutoCompleteWidget.Value = S.FunctionName;
            
            
            % Store:
            %   - filepath
            %   - package+function name
            %   - function name
            
            % Save to taskCatalog
            % Add to search list
            % Set as current string
            
            
        end
        
        function onRemoveTaskMenuItemClicked(obj, src, evt)
            rowNumber = obj.UITable.SelectedRows;
            if ~isempty(rowNumber)
                obj.removeTask(rowNumber)
            end
            
            % Update task numbers
            obj.updateTaskOrder()

        end
        
    end
    
    methods (Access = private) % Actions
        
        function addTask(obj, newTask)
            
            functionName = obj.AutoCompleteWidget.Value;
            
            % Find in sessionMethodCatalog
            sMethodItem = obj.SessionMethodCatalog.getItem(functionName);
            
            % Create task...
            task = nansen.pipeline.PipelineCatalog.getTask();
            task.TaskNum = uint8( size(obj.TaskTableData, 1) ) + 1;
            task.TaskName = sMethodItem.FunctionAlias;
            task.TaskFunction = sMethodItem.FunctionName;
            task.OptionPresetSelection = sMethodItem.OptionsAlternatives{1};
            
            % Initialize task table, or add task to existing table.
            taskAsTable = struct2table(task, 'AsArray', true);
            if isempty(obj.TaskTableData)
                obj.TaskTableData = taskAsTable;
            else
                obj.TaskTableData(end+1,:) = struct2table(task, 'AsArray', true);
            end
            
            
            if size(obj.TaskTableData, 1) == 1
                obj.updateOptionSelectionDropdown(1)
            end
            
            fprintf('Added task %s\n', obj.AutoCompleteWidget.Value)
        end
        
        function removeTask(obj, rowIdx)
            fprintf('Removing task %s\n', obj.UITable.DataTable{rowIdx, 2}{1})
            obj.TaskTableData(rowIdx, :) = []; 
        end
        
        function openTableContextMenu(obj, x, y)
            
            if isempty(obj.TableContextMenu); return; end
            
            % This is now corrected for in caller function...
            tablePosition = getpixelposition(obj.UITable, true);
            tableLocationX = tablePosition(1) + 1; % +1 because ad hoc...
            tableHeight = tablePosition(4);
            
            cMenuPos = [tableLocationX + x, tableHeight - y + 15]; % +15 because ad hoc...
                        
            % Set position and make menu visible.
            obj.TableContextMenu.Position = cMenuPos;
            obj.TableContextMenu.Visible = 'on';
            
        end
        
        function updateOptionSelectionDropdown(obj, rowNumber)
        %updateOptionSelectionDropdown Update table columnformatdata to
        %show options alternatives for current row.
        
            fcnName = obj.UITable.Data{rowNumber, 3};
            isMatch = strcmp({obj.SessionMethodCatalog.Data.FunctionName}, fcnName);
            
            obj.UITable.ColumnFormatData{4} = ...
                obj.SessionMethodCatalog.Data(isMatch).OptionsAlternatives;
            
        end
    end
end

        