classdef PipelineViewerApp < uiw.abstract.AppWindow
    
    
    % Todo: Allow many sessions!
    
    
    properties (Constant, Access=protected) % Inherited from uiw.abstract.AppWindow
        AppName char = 'Pipeline Viewer'
    end
    
    properties
        BatchProcessor
    end
    
    properties
        ColumnsToDisplay = {'IsFinished', 'TaskName', 'OptionsName', 'IsManual', 'DateFinished'}
        ColumnFormat = {'logical', 'char', 'char', 'logical', 'date'}
    end
    
    properties (Dependent)
        SelectionMode 
    end
    
    properties (SetAccess = protected)
        MetaObject
        PipelineStruct
        TaskTableData
    end
    
    properties (Hidden) % Layout
        ColumnWidth = []
        Margins (1,4) double = [15, 15, 15, 15]
    end
    
    properties (Access = protected)
        UITable
    end
    
    events
        
    end
    
    
    methods
        
        function app = PipelineViewerApp(pipelineStruct, sessionObj, varargin)
            
            app@uiw.abstract.AppWindow(varargin{:})
            app.Figure.ResizeFcn = @app.onFigureResized;
            app.createUiTable()
            app.setComponentLayout()
            
            if nargin >= 1
                app.assignPipeline( pipelineStruct );
            end
            
            if nargin >= 2
                app.MetaObject = sessionObj;
            end
            
        end
        
    end
    
    
    methods % Set/get
        
        function set.TaskTableData(app, newValue)
            app.TaskTableData = newValue;
            app.onTaskTableDataSet()
        end

        function set.Margins(app, newValue)
            app.Margins = newValue;
            app.setComponentLayout()
        end
        
        function set.SelectionMode(app, newValue)
            app.UITable.SelectionMode = newValue;
        end
        function mode = get.SelectionMode(app)
            mode = app.UITable.SelectionMode;
        end
    end
    
    
    methods % Public methods
        
        function openPipeline(app, progressStruct, metaObject)
            app.assignPipeline(progressStruct)
            figure(app.Figure)
            app.Figure.Name = sprintf('Pipeline Tasks (%s)', metaObject.sessionID);
            app.MetaObject = metaObject;
        end
        
        function assignPipeline(app, progressStruct)
        %assignNotebook Assign notebook in various forms.    
            
            if isa(progressStruct, 'nansen.pipeline.Pipeline') % Todo...
                app.PipelineStruct = progressStruct.toStruct; % Make sense?
            elseif isa(progressStruct, 'struct')
                app.PipelineStruct = progressStruct ;
            else
                errorId = 'Nansen:PipelineViewerApp:InvalidInput';
                errorMsg = 'Pipeline input must be a pipeline structure item.';
                throw(MException(errorId, errorMsg))
            end
            
            app.onPipelineSet()
                        
        end
        
        function setClosePolicy(app, mode)
            
            switch mode
                case 'hide'
                    app.Figure.CloseRequestFcn = @(s,e) app.hideApp;
                case {'close', 'delete'}
                    app.Figure.CloseRequestFcn = @(s,e) app.delete();
            end
                    
        end
        
    end
    
    methods (Access = protected)
        
        function sessionObj = getSessionObject(app, ~)
            sessionObj = app.MetaObject;
        end
        
        function onTaskTableDataSet(app)
            
            isInitialization = isempty(app.UITable.DataTable);
            
            app.UITable.DataTable = app.TaskTableData;
            %numRows = size(app.TaskTableData, 1);
            
            % Update the column formatting properties
            app.UITable.ColumnFormat = {'logical', 'char', 'char', 'logical', 'date'};

            %colFormatData = {};
            %app.UITable.ColumnFormatData = colFormatData;
            
            if isInitialization
                app.UITable.ColumnEditable = [true, false, false, false, false];
                app.UITable.ColumnPreferredWidth = [70, 100, 100, 70, 100];
                app.UITable.ColumnMaxWidth = [100, 1000, 1000, 100, 120];
            end
            
        end
        
        function onTableCellEdited(app, src, evt)
        %onTableCellEdited Callback for table cell edits..
        
            rowNumber = evt.Indices(1); 
            colNumber = evt.Indices(2);
        
            switch colNumber
                
                case 1 % Column showing task numbers
                    if evt.NewValue
                        app.UITable.DataTable{rowNumber, 5} = {datetime('now')};
                    else
                        app.UITable.Data{rowNumber, 5} = datetime.empty;
                    end
                    
                    app.PipelineStruct(rowNumber).IsFinished = evt.NewValue;
                    app.PipelineStruct(rowNumber).DateFinished = app.UITable.Data{rowNumber, 5};
                %case 3 % Column showing option presets

            end
            
            app.MetaObject.Progress = app.PipelineStruct;
        end
 
    end
    
    methods (Access = private) % Component creation and updates
        
        function createUiTable(app)
            % Create table
            app.UITable  = uim.widget.StylableTable('Parent', app.Figure, ...
                        'RowHeight', 25, ...
                        'FontSize', 8, ...
                        'FontName', 'helvetica', ...
                        'FontName', 'avenir next', ...
                        'Theme', uim.style.tableLight, ...
                        'Units', 'pixels' );

            app.UITable.CellEditCallback = @app.onTableCellEdited;
            app.UITable.MouseClickedCallback = @app.onTableCellClicked;
            %app.UITable.CellSelectionCallback = @app.onTableCellSelected;
            app.UITable.KeyPressFcn = @app.onKeyPressedInTable;

            %addlistener(app.UITable, 'MouseMotion', @app.onMouseMotionOnTable);
            
        end
        
        function setComponentLayout(app)
            
            figSize = getpixelposition(app.Figure);
            
            tableSize = figSize(3:4) - sum(app.Margins([1,2;3,4]));
            app.UITable.Position = [app.Margins(1:2), tableSize];
            if ~isempty(app.UITable.Data)
%                 [~, colWidth] = uim.utility.layout.subdividePosition(1, ...
%                     tableSize(1), [70,1/3,1/3,70,1/3], 0);
%                 app.UITable.ColumnPreferredWidth = colWidth;
            end
            
            
            %app.UITable.ColumnWidth = [40, 100, 100, 100];

        end
        
    end
    
    methods (Access = protected) % Component and user invoked callbacks
        
        function onKeyPressedInTable(app, src, evt)
            
            switch evt.Key

            end
            
        end
        
        function onPipelineSet(app)
            % Set data for table (important to do after creating table...)
            pipelineTable = struct2table( app.PipelineStruct, 'AsArray', true );
            
            % Create a reduced table for the viewer
            T = pipelineTable(:, app.ColumnsToDisplay);
            
            app.TaskTableData = T;
        end
        
        function onFigureResized(app, src, evt)
            app.setComponentLayout()
        end

        function onTableCellClicked(app, src, evt)

            if evt.Button == 1 && evt.NumClicks == 2
                rowNum = evt.Cell(1);
                if rowNum == 0; return; end
                
                
                thisTask = app.PipelineStruct(rowNum);
                
                if thisTask.IsManual
                    app.runManualTask(thisTask, rowNum)
                else
                    app.initQueuableTask(thisTask, rowNum)
                end
                
                %disp('double clicked')
            elseif evt.Button == 3 || strcmp(evt.SelectionType, 'alt')
                disp('right clicked')
                %app.onMouseRightClickedInTable(src, evt)
            end
            
        end
        
        function hideApp(app)
            app.Figure.Visible = 'off';
        end
        
        function runManualTask(app, taskStructure, rowNum)
        %runManualTask Initialize the task from the given row number
        
            fcnHandle = str2func(taskStructure.FunctionName);
            optsMngr = nansen.OptionsManager(taskStructure.FunctionName);
            opts = optsMngr.getOptions(taskStructure.OptionsName);

            sessionObj = app.getSessionObject(rowNum);

            try
                fcnHandle(sessionObj, opts);
            catch ME
                message = sprintf('Failed to run task "%s" for session "%s". The following error was caught:\n', ...
                    taskStructure.TaskName, sessionObj.sessionID);
                errordlg(sprintf('%s \n%s', message, ME.message))
                throw(ME)
            end
            
        end
        
        function initQueuableTask(app, taskStructure, rowNum)
        %initQueuableTask Initialize the task on the batch processor

            if isempty(app.BatchProcessor)
                error('Batch Processor is not available')
            end
            
            numTasks = numel(taskStructure);
            
            % Add tasks to the queue
            for i = 1:numTasks
                
                fcnHandle = str2func(taskStructure.FunctionName);
                optsMngr = nansen.OptionsManager(taskStructure.FunctionName);
                optsName = taskStructure.OptionsName;
                opts = optsMngr.getOptions(optsName);

                sessionObj = app.getSessionObject(rowNum);
                taskId = sessionObj.sessionID;
                
                % Prepare input args for function (session object and 
                % options)
                
                methodArgs = {sessionObj, opts};
                
                % Add task to the queue / submit the job
                app.BatchProcessor.submitJob(taskId,...
                                fcnHandle, 0, methodArgs, optsName )
            end

        end

    end
    
end
