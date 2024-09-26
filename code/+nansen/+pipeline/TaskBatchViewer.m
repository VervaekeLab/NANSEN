classdef TaskBatchViewer < nansen.pipeline.PipelineViewerApp

    methods
        
        function app = TaskBatchViewer(taskList, sessionObj, varargin)
            
            columnsToDisplay = {'SessionID', 'TaskName', 'OptionsName', 'Comment'};
            
            % Put tasklist in a struct to mimic a pipeline item
            pipelineStruct = struct();
            pipelineStruct.TaskList = taskList;
            
            app@nansen.pipeline.PipelineViewerApp(pipelineStruct, ...
                sessionObj, 'ColumnsToDisplay', columnsToDisplay)
            
            isManual = taskList(1).IsManual;
            if isManual
                name = 'List of Manual Tasks';
            else
                name = 'List of Queuable Tasks';
                app.createQueueButtons()
            end
            
            app.Figure.Name = name;

        end
    end
    
    methods (Access = protected)
        
        function sessionObj = getSessionObject(app, rowNum)
            
            sessionID = app.PipelineStruct.TaskList(rowNum).SessionID;
            sessionIDs = {app.MetaObject.sessionID};
            
            idx = find(strcmp(sessionIDs, sessionID));
            sessionObj = app.MetaObject(idx);

        end
        
        function onTaskTableDataSet(app)
            
            isInitialization = isempty(app.UITable.DataTable);
            
            app.UITable.DataTable = app.TaskTableData;
            %numRows = size(app.TaskTableData, 1);
            
            % Update the column formatting properties

            %colFormatData = {};
            %app.UITable.ColumnFormatData = colFormatData;
            if isInitialization
                app.UITable.ColumnFormat = {'char', 'char', 'char', 'char'};
                app.UITable.ColumnEditable = [false, false, false, true];
                app.UITable.ColumnPreferredWidth = [160, 150, 200, 100];
                app.UITable.ColumnMaxWidth = [200, 200, 300, 2000];
            end
        end
        
        function onTableCellEdited(app, src, evt)
            % Todo?
            rowNumber = evt.Indices(1);
            colNumber = evt.Indices(2);
            
        end
    end
    
    methods (Access = private)
        
        function createQueueButtons(app)
            
            buttonSize = [200, 30];
            
            [x, w] = uim.utility.layout.subdividePosition(app.Margins(1), ...
                app.Figure.Position(3), [buttonSize(1), buttonSize(1)], 20);
            y = app.Margins(2); h = 30;
            
            hButton = uicontrol(app.Figure, 'style', 'pushbutton');
            hButton.Position = [x(1), y, w(1), h];
            hButton.Units = 'normalized';
            hButton.String = 'Add to Task Processor Queue';
            hButton.FontUnits = 'pixels';
            hButton.FontName = 'Avenir Next';
            hButton.FontSize = 12;
            hButton.Callback = @app.onAddToBatchButtonPushed;
            
            app.h.AddToBatchButton = hButton;

            hButton = uicontrol(app.Figure, 'style', 'pushbutton');
            hButton.Position = [x(2), y, w(2), h];
            hButton.Units = 'normalized';
            hButton.String = 'Remove from List';
            hButton.FontUnits = 'pixels';
            hButton.FontName = 'Avenir Next';
            hButton.FontSize = 12;
            hButton.Callback = @app.onRemoveFromListButtonPushed;
            
            app.h.RemoveFromListButton = hButton;

        end
        
        function onRemoveFromListButtonPushed(app, src, evt)
            
            selectedRowIdx = app.UITable.SelectedRows;
            app.PipelineStruct.TaskList(selectedRowIdx) = [];
            app.onPipelineSet()

        end
        
        function onAddToBatchButtonPushed(app, src, evt)
                   
            selectedRowIdx = app.UITable.SelectedRows;
            
            for rowNum = selectedRowIdx
                thisTask = app.PipelineStruct.TaskList(rowNum);
                try
                    app.initQueuableTask(thisTask, rowNum)
                catch ME
                    selectedRowIdx = setdiff(selectedRowIdx, rowNum, 'stable');
                    msgbox(ME.message)
                end
            end
            
            app.PipelineStruct.TaskList(selectedRowIdx) = [];
            app.onPipelineSet()
            
        end
    end
end
