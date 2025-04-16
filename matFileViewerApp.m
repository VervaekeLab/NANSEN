function matFileViewerApp(filePath)
    % matFileViewerApp:
    % 1) Prompts user to load a .mat file.
    % 2) Displays a tree of nested variables.
    % 3) Shows the class and size of the selected variable on the right panel.

    %--------------------%
    %    MAIN FIGURE    %
    %--------------------%
    fig = uifigure('Name','MAT-File Viewer','Position',[100 100 600 400]);

    % Layout using a grid (or you can use manual Positioning).
    glayout = uigridlayout(fig,[1 2]);
    glayout.ColumnWidth = {'1x','2x'};  % Left is 1x, right is 2x

    %----------------------------%
    %  LEFT PANE: THE CHECKBOX TREE
    %----------------------------%
    fileTree = uitree(glayout,'checkbox','SelectionChangedFcn',@selectChangeCallback,...
                                       'CheckedNodesChangedFcn',@checkedChangeCallback);
    fileTree.Layout.Row = 1;
    fileTree.Layout.Column = 1;

    %----------------------------%
    %  RIGHT PANE: INFO DISPLAY
    %----------------------------%
    infoPanel = uipanel(glayout,'Title','Variable Info');
    infoPanel.Layout.Row = 1;
    infoPanel.Layout.Column = 2;

    % Create a label (or a text area) to show details in the panel
    infoLabel = uitextarea(infoPanel, 'Editable','off', ...
                           'Position', [10 10 260 340], ...
                           'Value', {''});

    %----------------------------%
    %   LOAD A .MAT FILE
    %----------------------------%
    % [fname,fpath] = uigetfile('*.mat','Select a MAT-file');
    % if isequal(fname,0)
    %     % User canceled file selection
    %     uialert(fig,'No .mat file selected. Closing app...','File Not Found');
    %     pause(1);
    %     delete(fig);
    %     return;
    % end

    % Load the file
    matData = load(filePath);
    [~, fname] = fileparts(filePath);

    % Build the tree from the loaded structure
    % Create a root node with the filename
    rootNode = uitreenode(fileTree,'Text',fname,'NodeData',[]);
    expand(fileTree);
    
    % We assume matData could have multiple top-level variables,
    % each variable might be a structure or something else.
    varNames = fieldnames(matData);
    for i = 1:numel(varNames)
        thisVarName  = varNames{i};
        thisVarValue = matData.(thisVarName);
        
        % Build the sub-tree for each variable
        buildTree(rootNode, thisVarName, thisVarValue);
    end
    
    % Expand the whole tree initially
    expand(fileTree);

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %  Nested function to recursively build sub-tree
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function buildTree(parentNode, varName, varValue)
        % Create a node
        newNode = uitreenode(parentNode, 'Text', varName, ...
                                        'NodeData', varValue);
        % If the current varValue is a structure, we recursively go through fields
        if isstruct(varValue)
            fn = fieldnames(varValue);
            % If this is an array of structures, iterate each element
            if numel(varValue) > 1
                for idx = 1:numel(varValue)
                    arrayNodeName = [varName '[' num2str(idx) ']'];
                    arrayNode = uitreenode(newNode,'Text',arrayNodeName,'NodeData',varValue(idx));
                    % Recurse for the fields of this sub-structure
                    subFields = fieldnames(varValue(idx));
                    for sf = 1:numel(subFields)
                        buildTree(arrayNode, subFields{sf}, varValue(idx).(subFields{sf}));
                    end
                end
            else
                % Single struct
                for sf = 1:numel(fn)
                    subVarName  = fn{sf};
                    subVarValue = varValue.(subVarName);
                    buildTree(newNode, subVarName, subVarValue);
                end
            end
        elseif iscell(varValue)
            % If it's a cell array, create sub-nodes for each element
            for cidx = 1:numel(varValue)
                cellNodeName = [varName '{' num2str(cidx) '}'];
                buildTree(newNode, cellNodeName, varValue{cidx});
            end
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Callback for when the user checks/unchecks nodes
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function checkedChangeCallback(src,event)
        % event.LeafCheckedNodes will list all newly-checked nodes
        nodes = event.LeafCheckedNodes;
        if isempty(nodes)
            disp('No nodes are currently checked.');
        else
            % As an example, we just display how many variables are checked
            % or, you could store them somewhere for further processing
            disp(['Number of checked nodes: ' num2str(numel(nodes))]);
            % For instance, if you wanted the sum of numeric data (like the original example),
            % you could do something like:
            % dataVals = [];
            % for n = 1:numel(nodes)
            %     val = nodes(n).NodeData;
            %     if isnumeric(val)
            %         dataVals(end+1) = sum(val(:)); %#ok<AGROW>
            %     end
            % end
            % disp(['Sum of all numeric checked items: ' num2str(sum(dataVals))]);
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Callback for when the user selects a node
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function selectChangeCallback(src,event)
        % event.SelectedNodes is the selected node
        if isempty(event.SelectedNodes)
            return;
        end
        node = event.SelectedNodes;
        nodeValue = node.NodeData;
        
        % Display the name of the selected node
        disp(['Selected node: ' node.Text]);
        
        % If nodeValue is not empty, show type and size in the infoPanel
        if ~isempty(nodeValue)
            varClass = class(nodeValue);
            varSize  = size(nodeValue);
            sizeStr  = ['[' num2str(varSize) ']'];  % e.g. [10 3]
            
            infoLabel.Value = { ...
                ['Variable Name: ', node.Text], ...
                ['Class: ' varClass], ...
                ['Size: ' sizeStr], ...
                ' ', ...
                'NodeData preview (for small arrays):'
            };
            
            % If numeric or char and not too large, show a snippet in the text area
            % You could decide your own rules for 'too large'
            previewText = '';
            if isnumeric(nodeValue) || ischar(nodeValue) || islogical(nodeValue)
                if numel(nodeValue) <= 25  % small enough to display
                    previewText = evalc('disp(nodeValue)');
                else
                    previewText = 'Data too large to display here.';
                end
            elseif iscell(nodeValue)
                previewText = 'Cell array preview not shown.';
            elseif isstruct(nodeValue)
                previewText = 'Structure data preview not shown.';
            else
                previewText = 'Data preview not supported for this type.';
            end
            
            % Append preview text
            infoLabel.Value{end+1} = previewText;
            
        else
            infoLabel.Value = {'','(No data in NodeData.)'};
        end
    end
end
