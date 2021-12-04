classdef FileViewer < handle
    
    
%   Todo
%       [ ] Create refresh button...



    properties
        Parent
        hFolderTree
        hContextMenu
        TabGroup
        
        CurrentSessionObj
    end
    
    
    properties (Access = private, Hidden)
        IconFolderPath
        DataLocationTabs
        IsTabDirty
        IsInitialized = false
        
        CurrentNode
    end
    
    
    methods
        
        function obj = FileViewer(varargin)
            
            % Take care of input arguments.
            obj.parseInputs(varargin)
            obj.setIconFolderPath()  
            
            obj.hContextMenu = obj.createTreeItemContextMenu();
            
        end

    end
    
    
    methods (Access = protected)
        
        function parseInputs(obj, listOfArgs)
            
            if isempty(listOfArgs);    return;    end
            
            if isgraphics(listOfArgs{1})
                obj.Parent = listOfArgs{1};
                listOfArgs = listOfArgs(2:end);
            end
            
            if isempty(listOfArgs);    return;    end
            
        end
        
        function setIconFolderPath(obj)
            rootDir = fileparts(mfilename('fullpath'));
            obj.IconFolderPath = fullfile(rootDir, '_graphics', 'icons');
        end
        
        function createTabgroup(obj, metaTableEntry)
            
            dlTypes = fieldnames(metaTableEntry.DataLocation);

            
            obj.TabGroup = uitabgroup(obj.Parent);
            obj.TabGroup.Units = 'normalized'; 

            %obj.TabGroup.Position = [0 0 1 1];

            % Create tab for each data location type.
            for i = 1:numel(dlTypes)
                tabName = dlTypes{i};

                hTab = uitab(obj.TabGroup);
                hTab.Title = tabName;

                obj.DataLocationTabs.(tabName) = hTab; 
                obj.IsTabDirty.(tabName) = true;
            end

            obj.TabGroup.SelectionChangedFcn = @obj.changeTab;
                            
            obj.IsInitialized = true;
            
        end
        
        function markTabsAsDirty(obj)
            
            tabNames = fieldnames(obj.IsTabDirty); 
           
            for i = 1:numel(tabNames)
                obj.IsTabDirty.(tabNames{i}) = true;
            end
            
        end
        
        function resetTreeControls(obj)
            
            tabNames = fieldnames(obj.hFolderTree);
            
            for i = 1:numel(tabNames)
                delete( obj.hFolderTree.(tabNames{i}) )
            end
            
            obj.hFolderTree = [];
            
        end
        
        
        function changeTab(obj, ~, ~)
            
            dataLocationType = obj.TabGroup.SelectedTab.Title;
            
            % Create tree if the tab is dirty...
            if obj.IsTabDirty.(dataLocationType)
                obj.createFolderTreeControl()
            end
            
        end
        
        
    end
    
    
    methods
        
        function update(obj, metaTableEntry)
            
            % Todo: Accept multiple sessions and create entry for each.
            if isempty(metaTableEntry); return; end
            
            if ~obj.IsInitialized
                obj.createTabgroup(metaTableEntry)
            end
            
            sessionID = metaTableEntry.sessionID{:};
            
            % Determine if an update is needed.
            if ~isempty(obj.hFolderTree)
                
                dataLocationType = obj.TabGroup.SelectedTab.Title;
                hTree = obj.hFolderTree.(dataLocationType);
                
                
                if ~contains(hTree.Root.Name, sessionID)
                    
                    obj.CurrentSessionObj = metaTableEntry;
                    obj.markTabsAsDirty()
                    
                    obj.resetTreeControls()
                    
                    doUpdate = true;
%                     delete(obj.hFolderTree)
%                     obj.hFolderTree = [];
                else
                    doUpdate = false;
                end
            else
                doUpdate = true;
                obj.CurrentSessionObj = metaTableEntry;
            end
            
            if doUpdate
                obj.createFolderTreeControl()
            end

            
        end
        
        function createFolderTreeControl(obj)
            
            warning('off', 'MATLAB:ui:javacomponent:FunctionToBeRemoved')

            sessionObject = obj.CurrentSessionObj;
            sessionID = sessionObject.sessionID{:};
            
            % Get data location type
            if ~isempty(obj.TabGroup)
                dataLocationType = obj.TabGroup.SelectedTab.Title;
                hParent = obj.TabGroup.SelectedTab;
            else
                alternatives = fieldnames(sessionObject.DataLocation);
                dataLocationType = alternatives{1};
            end
            
            % Delete old tree if it exists.
            if isfield(obj.hFolderTree, dataLocationType) && isvalid(obj.hFolderTree.(dataLocationType))
                delete(obj.hFolderTree.(dataLocationType))
            end

            W = uiw.widget.Tree('Parent', hParent);
            W.Root.Name = sprintf('Session: %s', sessionID);
            W.FontName = 'Avenir New';
            W.FontSize = 9;

            % Set color for selection background
            if ismac
                color = javax.swing.UIManager.get('Focus.color');
                rgb = cellfun(@(name) get(color, name), {'Red', 'Green', 'Blue'});
            else
                rgb = [0,0,200];
            end

            W.SelectionBackgroundColor = rgb./255;


            dirPath = sessionObject.DataLocation.(dataLocationType);
            
            if ~isfolder(dirPath)
                W.Root.Name = sprintf('%s (Not available)', W.Root.Name);
            end
            
            addSubFolderToNode(obj, dirPath, W.Root, true)

            W.MouseClickedCallback = @obj.onMouseClickOnTree;

            
            obj.hFolderTree.(dataLocationType) = W;
            obj.IsTabDirty.(dataLocationType) = false;
            
            warning('on', 'MATLAB:ui:javacomponent:FunctionToBeRemoved')

        end
        
        function addSubFolderToNode(obj, rootDir, nodeHandle, isRecursive)
            
            if nargin < 4 || isempty(isRecursive)
                isRecursive = true;
            end
            
            L = dir(rootDir);
            skip = strncmp({L.name}, '.',  1);
            L(skip) = [];
            
            hBranches = uiw.widget.TreeNode.empty;
            

            for i = 1:numel(L)
                if L(i).isdir
                    hBranches(i) = uiw.widget.TreeNode('Parent', nodeHandle);
                    
                    hBranches(i).Name = L(i).name;
                    
                    if isRecursive
                        obj.addSubFolderToNode(fullfile(rootDir, L(i).name), hBranches(i))
                    end
                    
                    hBranches(i).UserData.filePath = fullfile(L(i).folder, L(i).name);
                    folderIconPath = fullfile(obj.IconFolderPath, 'folder.gif');
                    setIcon(hBranches(i), folderIconPath);

                else
                    hBranches(i) = uiw.widget.TreeNode('Parent', nodeHandle);
                    hBranches(i).Name = L(i).name;
                    
                    [~, ~, fileExt] = fileparts(L(i).name);

                    switch fileExt
                        case '.mat'
                            icoFile = fullfile(obj.IconFolderPath, 'matfile.gif');
                        case {'.tif', '.avi', '.raw'}
                            icoFile = fullfile(obj.IconFolderPath, 'movie.gif');
                        otherwise
                            icoFile = fullfile(matlabroot,'toolbox','matlab','icons','HDF_filenew.gif');
                            
                    end
                    hBranches(i).UserData.filePath = fullfile(L(i).folder, L(i).name);
                    %hBranches(i).UIContextMenu = obj.createTreeItemContextMenu(hBranches(i));
                    setIcon(hBranches(i), icoFile);
                end
            end
            
            
            if ~isRecursive % Todo: Fix/test this and recall what the meaning was
                for i = 1:numel(L)
                    if L(i).isdir
                        obj.addSubFolderToNode(fullfile(rootDir, L(i).name), hBranches(i))
                    end
                end
            end
            
            
            
        end
        
        function onMouseClickOnTree(obj, src, event)
            
            currentNode = event.Nodes;
            
            if isempty(currentNode)
                return
            end
            
            if event.NumClicks == 1 && strcmp(event.SelectionType, 'alt')
                
                obj.CurrentNode = currentNode;

                pixelPos = getpixelposition(obj.Parent, true);

                x = pixelPos(1) + event.Position(1); 
                y = pixelPos(4) - event.Position(2);
                
                obj.hContextMenu.Position = [x,y];
                obj.hContextMenu.Visible = 'on';
                
                
            elseif event.NumClicks == 2 && ~strcmp(event.SelectionType, 'alt')
                
                %setIdle = obj.setBusy('Opening File...'); %#ok<NASGU>

                [~, ~, fileExt] = fileparts(currentNode.Name);

                switch fileExt
                    case {'.ini', '.tif', '.avi', '.raw'}
                        imviewer(currentNode.UserData.filePath)
                    case '.mat'
%                         uiopen(currentNode.UserData.filePath)
                        [status, ~] = unix(sprintf('open -a finder ''%s''', currentNode.UserData.filePath));
                    case '.png'
                        filepath = strrep(currentNode.UserData.filePath, ' ', '\ ');
                        [status, msg] = unix(sprintf('open -a Preview %s', filepath));
                end
                
            end
            
        end
        
        function m = createTreeItemContextMenu(obj, nodeHandle)
            % Big todo: Should not create one contextmenu for each branch/leaf
            
            if nargin < 2
                nodeHandle = [];
            end
            
            hFig = ancestor(obj.Parent, 'figure');
            m = uicontextmenu(hFig);
            
            mitem = uimenu(m, 'Text', 'Refresh', 'Callback', @(s, e, h) obj.onTreeItemContextMenuSelected(s, nodeHandle));
            mitem = uimenu(m, 'Text', 'Show In Finder', 'Separator', 'on', 'Callback', @(s, e, h) obj.onTreeItemContextMenuSelected(s, nodeHandle));
            mitem = uimenu(m, 'Text', 'Load Variables to Workspace', 'Callback', @(s, e, h) obj.onTreeItemContextMenuSelected(s, nodeHandle));
            mitem = uimenu(m, 'Text', 'Plot Variables in Timeseries Plotter', 'Callback', @(s, e, h) obj.onTreeItemContextMenuSelected(s, nodeHandle));

        end
        
        function onTreeItemContextMenuSelected(obj, src, nodeHandle)

            nodeHandle = obj.CurrentNode;
            
            switch src.Text
                
                case 'Refresh'
                    
                    % Create tree if the tab is dirty...
                    obj.createFolderTreeControl()

                
                case 'Show In Finder'
                
                    dirPath = fileparts(nodeHandle.UserData.filePath);
                
                    if isunix
                        [status, ~] = unix(sprintf('open -a finder ''%s''', dirPath));
                        if status
                            fprintf('Something went wrong')
                        end

                    elseif ispc
                        winopen(dirPath);
                    end
                    
                    
                case 'Load Variables to Workspace'
                    
                    S = load(nodeHandle.UserData.filePath);
                    
                    varNames = fieldnames(S);
                    
                    for i = 1:numel(S)
                        assignin('base', varNames{i}, S.(varNames{i}))
                    end
                    
                case 'Plot Variables in Timeseries Plotter'
            
                    S = load(nodeHandle.UserData.filePath);
                    
                    timeSeriesData = struct2cell(S);
                    timeseriesPlot(timeSeriesData, 'Name', fieldnames(S))
                    
            end
            
            
            
        end
        
    end
    
end