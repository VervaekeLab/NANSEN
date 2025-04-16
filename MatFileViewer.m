classdef MatFileViewer < matlab.apps.AppBase
    % MatFileViewer - MATLAB App for viewing contents of .mat files
    % This app allows users to load and explore the contents of MATLAB .mat files
    % with a tree-based navigation system for nested structures.
    
    properties
        Filename
    end

    properties (Access = private)
        % UI components
        UIFigure
        DataVariableButton matlab.ui.control.Button
        VariableTree matlab.ui.container.CheckBoxTree
        InfoPanel matlab.ui.container.Panel
        VariableInfoTable matlab.ui.control.Table
        VisualizationPanel matlab.ui.container.Panel
        RightPanelGrid matlab.ui.container.GridLayout
        VisualizationGrid matlab.ui.container.GridLayout
        
        % Data properties
        CurrentFile % Path to the currently loaded .mat file
        FileData % Contents of the loaded .mat file
        SelectedVariable % Currently selected variable
        SelectedPath % Path to the selected variable in the structure
        CheckedNodes % List of checked nodes
    end

    methods
    end
    
    methods (Access = private)
        
        function loadMatFile(app, filepath)
            % Load a .mat file and populate the tree
            app.Filename = filepath;
            try
                % Load the file
                app.FileData = load(filepath);
                app.CurrentFile = filepath;
                
                % Update the file path label
                [~, filename, ext] = fileparts(filepath);
                app.UIFigure.Name = sprintf('MAT File Viewer (%s)', [filename ext]);
                
                % Clear the tree
                delete(app.VariableTree.Children);
                
                % Build the tree
                fieldNames = fieldnames(app.FileData);
                for i = 1:length(fieldNames)
                    varName = fieldNames{i};
                    varData = app.FileData.(varName);
                    
                    % Create the top-level node
                    parentNode = uitreenode(app.VariableTree, 'Text', varName, 'NodeData', struct('path', varName, 'data', varData));
                    
                    % Recursively add child nodes if this is a struct or cell
                    app.addChildNodes(parentNode, varData, varName);
                end
                
                % Expand the tree
                expand(app.VariableTree);
                
                % Clear the info panel
                app.clearInfoPanel();
                
            catch ex
                % Display error message
                errordlg(['Error loading file: ' ex.message], 'File Load Error');
            end
        end
        
        function addChildNodes(app, parentNode, data, path)
            % Recursively add child nodes to the tree
            
            if isstruct(data)
                % Handle structure data
                fields = fieldnames(data);
                for i = 1:length(fields)
                    fieldName = fields{i};
                    fieldData = data.(fieldName);
                    fieldPath = [path '.' fieldName];
                    
                    % Create a node for this field
                    childNode = uitreenode(parentNode, 'Text', fieldName, 'NodeData', struct('path', fieldPath, 'data', fieldData));
                    
                    % Recursively add children
                    app.addChildNodes(childNode, fieldData, fieldPath);
                end
                
            elseif iscell(data) && ~isempty(data) && all(size(data) > 0)
                % Handle cell array data
                for i = 1:numel(data)
                    % Create index string based on dimensions
                    dims = size(data);
                    if length(dims) <= 2
                        if dims(1) == 1 || dims(2) == 1
                            % 1D cell array
                            indexStr = sprintf('{%d}', i);
                        else
                            % 2D cell array
                            [row, col] = ind2sub(dims, i);
                            indexStr = sprintf('{%d,%d}', row, col);
                        end
                    else
                        % Multi-dimensional cell array
                        subs = cell(1, length(dims));
                        [subs{:}] = ind2sub(dims, i);
                        indexStr = '{';
                        for j = 1:length(subs)
                            if j > 1
                                indexStr = [indexStr ',' num2str(subs{j})];
                            else
                                indexStr = [indexStr num2str(subs{j})];
                            end
                        end
                        indexStr = [indexStr '}'];
                    end
                    
                    cellData = data{i};
                    cellPath = [path indexStr];
                    
                    % Create a node for this cell
                    childNode = uitreenode(parentNode, 'Text', indexStr, 'NodeData', struct('path', cellPath, 'data', cellData));
                    
                    % Recursively add children
                    app.addChildNodes(childNode, cellData, cellPath);
                end
            end
            
            % For other data types (numeric, char, etc.), we don't add child nodes
        end
        
        function displayVariableInfo(app, node)
            % Display information about the selected variable
            if isempty(node)
                app.clearInfoPanel();
                return;
            end
            
            % Get the data from the node
            nodeData = node.NodeData;
            data = nodeData.data;
            path = nodeData.path;
            
            % Update the selected variable properties
            app.SelectedVariable = data;
            app.SelectedPath = path;
            
            % Clear previous info
            app.clearInfoPanel();
            
            % Create a table with variable information
            infoData = app.getVariableInfo(data);
            app.VariableInfoTable.Data = infoData;
            
            % Attempt to visualize the data
            app.visualizeVariable(data);
        end
        
        function infoData = getVariableInfo(app, data)
            % Get information about a variable
            infoData = {};
            
            % Add class/type
            infoData(end+1,:) = {'Class', class(data)};
            
            % Add size
            sizeStr = mat2str(size(data));
            infoData(end+1,:) = {'Size', sizeStr};
            
            % Add number of elements
            infoData(end+1,:) = {'Elements', num2str(numel(data))};
            
            % Add bytes
            infoBytes = whos('data');
            infoData(end+1,:) = {'Bytes', num2str(infoBytes.bytes)};
            
            % Add additional type-specific information
            if isstruct(data)
                infoData(end+1,:) = {'Fields', num2str(length(fieldnames(data)))};
            elseif iscell(data)
                infoData(end+1,:) = {'Non-Empty', num2str(sum(~cellfun(@isempty, data(:))))};
            elseif isnumeric(data) || islogical(data)
                if ~isempty(data)
                    infoData(end+1,:) = {'Min', num2str(min(data(:)))};
                    infoData(end+1,:) = {'Max', num2str(max(data(:)))};
                    infoData(end+1,:) = {'Mean', num2str(mean(data(:)))};
                end
            elseif ischar(data)
                infoData(end+1,:) = {'Length', num2str(length(data))};
            end
        end
        
        function visualizeVariable(app, data)
            % Visualize the variable based on its type
            
            % Clear previous visualization
            delete(app.VisualizationGrid.Children);
            
            % Check data type and create appropriate visualization
            if isempty(data)
                % Empty data - nothing to visualize
                return;
                
            elseif isnumeric(data) && length(size(data)) <= 2 && numel(data) < 10000
                % 1D or 2D numeric data - create a table
                t = uitable(app.VisualizationGrid);
                t.Data = data;
                %t.Position = [10 10 app.VisualizationPanel.Position(3)-20 app.VisualizationPanel.Position(4)-20];
                
            elseif ischar(data)
                % Text data - create a text area
                ta = uitextarea(app.VisualizationGrid);
                ta.Value = data;
                ta.Position = [10 10 app.VisualizationGrid.Position(3)-20 app.VisualizationGrid.Position(4)-20];
                
            elseif isstruct(data) && length(data) == 1
                % Single struct - show fields in a table
                fields = fieldnames(data);
                tableData = cell(length(fields), 2);
                for i = 1:length(fields)
                    tableData{i,1} = fields{i};
                    fieldValue = data.(fields{i});
                    if ischar(fieldValue)
                        tableData{i,2} = fieldValue;
                    else
                        tableData{i,2} = class(fieldValue);
                    end
                end
                
                t = uitable(app.VisualizationGrid);

                t.Data = tableData;
                t.ColumnName = {'Field', 'Value/Type'};
                %t.Position = [10 10 app.VisualizationGrid.Position(3)-20 app.VisualizationGrid.Position(4)-20];
                
            elseif isnumeric(data) && length(size(data)) <= 2
                % Large numeric data - create a preview
                lbl = uilabel(app.VisualizationGrid);
                lbl.Text = 'Data preview (first 10x10 elements):';
                lbl.Position = [10 app.VisualizationGrid.Position(4)-30 300 20];
                
                t = uitable(app.VisualizationGrid);
                previewSize = min(size(data), [10 10]);
                t.Data = data(1:previewSize(1), 1:previewSize(2));
                %t.Position = [10 50 app.VisualizationGrid.Position(3)-20 app.VisualizationGrid.Position(4)-80];
                
            elseif isnumeric(data) && length(size(data)) == 3 && size(data, 3) <= 3
                % Image data - create an image
                ax = uiaxes(app.VisualizationGrid);
                %ax.Position = [10 10 app.VisualizationGrid.Position(3)-20 app.VisualizationGrid.Position(4)-20];
                
                if size(data, 3) == 1
                    % Grayscale image
                    imshow(data, 'Parent', ax);
                else
                    % Color image
                    imshow(data(:,:,1:min(3,size(data,3))), 'Parent', ax);
                end
                
            else
                % Other data types - show a message
                lbl = uilabel(app.VisualizationGrid);
                lbl.Text = sprintf('Cannot visualize data of type %s with dimensions %s', ...
                    class(data), mat2str(size(data)));
                %lbl.Position = [10 app.VisualizationGrid.Position(4)/2 app.VisualizationGrid.Position(3)-20 40];
                lbl.HorizontalAlignment = 'center';
            end
        end
        
        function clearInfoPanel(app)
            % Clear the information panel
            app.VariableInfoTable.Data = {};
            delete(app.VisualizationGrid.Children);
            app.SelectedVariable = [];
            app.SelectedPath = '';
        end
        
        function handleNodeSelection(app, event)
            % Handle node selection in the tree
            nodes = event.SelectedNodes;
            if ~isempty(nodes)
                app.displayVariableInfo(nodes(1));
            else
                app.clearInfoPanel();
            end
        end
        
        function handleNodeCheck(app, event)
            % Handle node check/uncheck in the tree
            app.CheckedNodes = event.CheckedNodes;
            
            % For now, just display the first checked node
            if ~isempty(app.CheckedNodes)
                app.displayVariableInfo(app.CheckedNodes(1));
            else
                app.clearInfoPanel();
            end
        end
    end
    
    % Callbacks that handle component events
    methods (Access = private)
        
        % Button pushed function: FileLoadButton
        function onCreateDataVariableButtonPushed(app, event)
            app.CheckedNodes = app.VariableTree.CheckedNodes;

            names = app.CheckedNodes.Text;



        
            [folder, fileName, ext] = fileparts(filePath);
        
            % Get variable model from the sessionobject / dataiomodel
            variableModel = sessionObject.VariableModel;
        
            fileAdapterList = nansen.dataio.listFileAdapters(ext);
        
            % Remove session ID from filename
            fileName = strrep(fileName, sessionObject.sessionID, '');
            
            % Create a struct with fields that are required from user
            S = struct();
            S.VariableName = '';
            S.FileNameExpression = fileName;
            S.FileAdapter = fileAdapterList(1).FileAdapterName;
            S.FileAdapter_ = {fileAdapterList.FileAdapterName};
            S.Favorite = false;
            
            % Open user dialog:
            [S, wasAborted] = tools.editStruct(S, [], 'Create New Variable');
            S = rmfield(S, 'FileAdapter_');
            if wasAborted; return; end
            
            % Add other fields that are required for the variable model.
        
            % Create a new data variable item
            varItem = variableModel.getDefaultItem(S.VariableName);
            varItem.IsCustom = true;
            varItem.IsFavorite = S.Favorite;
            varItem.DataLocation = dataLocationName;
            varItem.FileNameExpression = S.FileNameExpression;
            varItem.FileType = ext;
            varItem.FileAdapter = S.FileAdapter;
            
            % Get the data location uuid for the given data location
            dloc = sessionObject.getDataLocation(dataLocationName);
            varItem.DataLocationUuid = dloc.Uuid;
            
            % Determine if file is located in a session subfolder
            sessionFolder = sessionObject.getSessionFolder(dataLocationName);
            varItem.Subfolder = strrep(folder, sessionFolder, '');
            if strncmp(varItem.Subfolder, filesep, 1)
                varItem.Subfolder = varItem.Subfolder(2:end);
            end
            
            % Get data type from file adapter
            fileAdapterIdx = strcmp({fileAdapterList.FileAdapterName}, S.FileAdapter);
            varItem.DataType = fileAdapterList(fileAdapterIdx).DataType;



            

        end
    end
    
    % Component initialization
    methods (Access = private)
        
        % Create UIFigure and components
        function createComponents(app)
            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1000 600];
            app.UIFigure.Name = 'MAT File Viewer';
            app.UIFigure.Resize = 'on';
            
            % Create file controls
            app.DataVariableButton = uibutton(app.UIFigure, 'push');
            app.DataVariableButton.ButtonPushedFcn = createCallbackFcn(app, @onCreateDataVariableButtonPushed, true);
            app.DataVariableButton.Position = [20 app.UIFigure.Position(4)-40 100 30];
            app.DataVariableButton.Text = 'Create Data Variable';
            
            
            % Create left panel with tree
            leftPanel = uipanel(app.UIFigure);
            leftPanel.Position = [10 10 300 app.UIFigure.Position(4)-60];
            leftPanel.Title = 'Variable Structure';
            
            app.VariableTree = uitree(leftPanel, 'checkbox');
            app.VariableTree.Position = [10 10 280 leftPanel.Position(4)-30];
            app.VariableTree.SelectionChangedFcn = createCallbackFcn(app, @handleNodeSelection, true);
            app.VariableTree.CheckedNodesChangedFcn = createCallbackFcn(app, @handleNodeCheck, true);
            
            % Create right panel with info and visualization
            rightPanel = uipanel(app.UIFigure);
            rightPanel.Position = [320 10 app.UIFigure.Position(3)-330 app.UIFigure.Position(4)-60];
            rightPanel.Title = 'Variable Information';
            
            app.RightPanelGrid = uigridlayout( rightPanel );
            app.RightPanelGrid.RowHeight = {150, '1x'};
            app.RightPanelGrid.ColumnWidth = {'1x'};
            app.RightPanelGrid.BackgroundColor = 'w';
            app.RightPanelGrid.Padding = 0;

            % Create info table
            % app.InfoPanel = uipanel(app.RightPanelGrid);
            % app.InfoPanel.Layout.Row = 1;
            % app.InfoPanel.Layout.Column = 1;
            % app.InfoPanel.Title = 'Properties';
            
            app.VariableInfoTable = uitable(app.RightPanelGrid);
            app.VariableInfoTable.Layout.Row = 1;
            app.VariableInfoTable.Layout.Column = 1;
            app.VariableInfoTable.ColumnName = {'Property', 'Value'};
            app.VariableInfoTable.ColumnWidth = {150, 'auto'};
            
            % Create visualization panel
            app.VisualizationPanel = uipanel(app.RightPanelGrid);
            app.VisualizationPanel.Layout.Row = 2;
            app.VisualizationPanel.Layout.Column = 1;
            app.VisualizationPanel.Title = 'Data Preview';

            app.VisualizationGrid = uigridlayout( app.VisualizationPanel );
            app.VisualizationGrid.RowHeight = {'1x'};
            app.VisualizationGrid.ColumnWidth = {'1x'};
            app.VisualizationGrid.BackgroundColor = 'w';
            app.VisualizationGrid.Padding = 0;

            % Make the UI visible
            app.UIFigure.Visible = 'on';
        end
    end
    
    % App creation and deletion
    methods (Access = public)
        
        % Construct app
        function app = MatFileViewer(filePath)
            arguments
                filePath (1,1) string = missing
            end

            if ~ismissing(filePath)
                mustBeFile(filePath)
            end

            % Create UIFigure and components
            createComponents(app);
            
            % Register the app with App Designer
            registerApp(app, app.UIFigure);
            
            % Initialize properties
            app.CheckedNodes = [];
            app.SelectedVariable = [];
            app.SelectedPath = '';

            if ~ismissing(filePath)
                app.loadMatFile(filePath)
            end
            
            if nargout == 0
                clear app
            end
        end
        
        % Code that executes before app deletion
        function delete(app)
            % Delete UIFigure when app is deleted
            delete(app.UIFigure);
        end
    end
end
