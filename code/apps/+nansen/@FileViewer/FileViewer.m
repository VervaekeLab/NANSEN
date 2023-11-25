classdef FileViewer < handle
%FileViewer Display a DataLocation in a uitree structure.
%
%   This class can be placed in a uipanel and be used for displaying
%   the files and folders of a DataLocation in a tree structure.
%
%   h = nansen.FileViewer(hParent) creates the fileviewer in the parent
%   container specified as the first input. The parent can be a figure, a
%   uipanel or a uitab.
%
%   Construction of the fileviewer will not create the actual uitree. Use
%   the update method for creating a uitree for a datalocation. For
%   example:
%       h.update(sessionTableEntry)
%
%   The update method takes as input a metatable entry from the session
%   table in nansen's sessionbrowser.
%
%   The fileviewer will create an individual tab for each datalocation of
%   the provided session.


%   Note: Should generalize this class to work with datalocations, not just
%   session entries in the metatable.
%
%   IMPORTANT: the uiw.widget.FileTree can cause the app to lag because the
%   javacontrol is doing a lot of mouseevent processing, and if the tree is
%   large(?) the mouse event processing starts lagging. 
%   Test properly and think of alternatives 


%   Todo
%       [v] Create refresh button... Right click to refresh. Button better?
%       [ ] Add preferences and
%           - MaxNumItemsToShow. Currently hardcoded to 100
%       [ ] Create handleDoubleClick method
%       [ ] Use some of the logic in handling of double click also when
%           loading variables to workspace 

    properties
        CurrentSessionObj
    end
    
    properties (SetAccess = private)
        Parent
    end
    
    properties (Access = private, Hidden)
        IconFolderPath
        DataLocationTabs
        IsTabDirty
        IsInitialized = false
        
        CurrentNode % The current node selection in the tree
    end

    properties (Dependent, Access = private)
        CurrentDataLocationName
        CurrentTree
    end

    properties (Access = private) % GUI Components
        TabGroup % Tabgroup for different data locations
        hFolderTree
        jTree
        jVerticalScroller
        
        FileContextMenu
        FolderContextMenu
                
        nwbContextMenu
        
        hPanelPreview
        hBackgroundLabel
    end

    properties (Access = private) % Internal
        KeypressListener event.listener % Todo: If fileviewer is opened in figure
        ParentSizeChangedListener event.listener
    end

    events
        VariableModelChanged
    end
    
    methods % Constructor
        
        function obj = FileViewer(varargin)
        %FileViewer Construct a fileviewer object

            % Note: The tabgroup and filetree components will be created 
            % on demand.
        
            % Parse the input arguments using private parser method.
            obj.parseInputs(varargin)
            
            obj.setIconFolderPath()  
            obj.createBackgroundLabel()
            obj.createContextMenus()

            obj.jVerticalScroller = containers.Map();
            obj.jTree = containers.Map();

            % obj.createPreviewPanel() % Not implemented yet

            obj.ParentSizeChangedListener = listener(obj.Parent, ...
                'SizeChanged', @obj.onParentSizeChanged);
        end

        function delete(obj)
            if obj.IsInitialized
                delete(obj.TabGroup)
            end
            if ~isempty(obj.ParentSizeChangedListener)
                delete(obj.ParentSizeChangedListener)
            end
            
            delete(obj.FileContextMenu)
            delete(obj.FolderContextMenu)
            delete(obj.nwbContextMenu)
        end
    end
    
    methods (Access = public)
        
        function id = getCurrentObjectId(obj)
        %getCurrentObjectId Get ID of current session object.    
            id = '';
            if ~isempty(obj.CurrentSessionObj)
                id = obj.CurrentSessionObj.sessionID;
            end
        end
        
        function update(obj, metaTableEntry)
        %update Update the uitree based on a session entry from a metatable
        %
        %   hFileviewer.update(sessionTableEntry)
        
            % Todo: Accept multiple sessions and create entry for each.
            if isempty(metaTableEntry); return; end
            
            if ~obj.IsInitialized
                obj.createTabgroup(metaTableEntry)
            end
            
            sessionID = metaTableEntry.sessionID;%{:};
            
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
                obj.updateFolderTree()
            end
        end
        
    end 
    
    methods % Set/get
        function dataLocationName = get.CurrentDataLocationName(obj)
            if ~isempty(obj.TabGroup)
                dataLocationName = obj.TabGroup.SelectedTab.Title;
            else
                % Todo: Will this ever be needed?
                sessionObject = obj.CurrentSessionObj;
                allNames = fieldnames({sessionObject.DataLocation.Name});
                dataLocationName = allNames{1};
            end
        end

        function W = get.CurrentTree(obj)
            W = obj.hFolderTree.(obj.CurrentDataLocationName);
        end
    end

    methods (Access = {?nansen.App, ?nansen.FileViewer, ?uiw.widget.FileTree})
        
        function wasCaptured = onKeyPressed(obj, ~, evt)
            
            wasCaptured = true;
            
            switch evt.Key
                case 'r'
                    if strcmp(evt.Modifier, 'command') | strcmp(evt.Modifier, 'control')
                        obj.updateFolderTree()
                    else
                        wasCaptured = false;
                    end

                otherwise
                    wasCaptured = false;
            end

            if ~nargout
                clear wasCaptured
            end
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

        function createBackgroundLabel(obj)
        %createBackground
        
            obj.hBackgroundLabel = uicontrol(obj.Parent, 'style', 'text');
            obj.hBackgroundLabel.String = 'No Session Selected';
            obj.hBackgroundLabel.FontSize = 20;
            obj.hBackgroundLabel.ForegroundColor = ones(1,3)*0.6;
            obj.hBackgroundLabel.Position(3:4) = obj.hBackgroundLabel.Extent(3:4);
            uim.utility.layout.centerObjectInRectangle(obj.hBackgroundLabel, ...
                getpixelposition(obj.Parent))
        end
        
        function createContextMenus(obj)
        % createContextMenus - Create the context menus for the file viewer
        %
        % Note: The context menus are created on construction. They will be 
        % reused across data locations and items in the uitree.

            obj.FolderContextMenu = obj.createFolderContextMenu();
            obj.FileContextMenu = obj.createFileItemContextMenu();
            obj.nwbContextMenu = obj.createNwbItemContextMenu();
        end

        function createTabgroup(obj, metaTableEntry)
            
            dlNames = {metaTableEntry.DataLocation.Name};

            obj.TabGroup = uitabgroup(obj.Parent);
            obj.TabGroup.Units = 'normalized'; 

            %obj.TabGroup.Position = [0 0 1 1];

            % Create tab for each data location type.
            for i = 1:numel(dlNames)
                tabName = dlNames{i};

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
        
        function createPreviewPanel(obj)
            
            import uim.utility.layout.centerObjectInRectangle

            obj.hPanelPreview = uipanel(obj.Parent);
            obj.hPanelPreview.Units = 'pixels';
            obj.hPanelPreview.Position(3:4) = [500,300];
            obj.hPanelPreview.Visible = 'off';

            centerObjectInRectangle(obj.hPanelPreview, obj.Parent);
        end

        function resetTreeControls(obj)
            
            tabNames = fieldnames(obj.hFolderTree);
            
            for i = 1:numel(tabNames)
                delete( obj.hFolderTree.(tabNames{i}) )
            end
            
            obj.hFolderTree = [];
        end
        
        function changeTab(obj, ~, ~)
            
            dataLocationName = obj.TabGroup.SelectedTab.Title;
            % Create tree if the tab is dirty...
            if obj.IsTabDirty.(dataLocationName)
                obj.updateFolderTree()
            end
        end
    
        function updateFolderTree(obj)
            
            warning('off', 'MATLAB:ui:javacomponent:FunctionToBeRemoved')
            
            sessionObject = obj.CurrentSessionObj;
            sessionID = sessionObject.sessionID;
            
            % Get data location type
            if ~isempty(obj.TabGroup)
                dataLocationName = obj.TabGroup.SelectedTab.Title;
                hParent = obj.TabGroup.SelectedTab;
            else
                alternatives = fieldnames({sessionObject.DataLocation.Name});
                dataLocationName = alternatives{1};
            end
                          
            drawnow limitrate

            if isfield(obj.hFolderTree, dataLocationName) ...
                    && isvalid(obj.hFolderTree.(dataLocationName))

                W = obj.hFolderTree.(dataLocationName);
                W.Visible = 'off';
                delete(W.Root.Children)
                W.Visible = 'on';

                % Delete old tree nodes if tree already exists.
                %todo
            else
                W = obj.createFolderTreeComponent(hParent);
            end

            try
                dirPath = sessionObject.getSessionFolder(dataLocationName);
            catch ME %#ok<NASGU>
                dirPath = '';
            end
                        
            if ~isfolder(dirPath)
                W.Root.Name = sprintf('%s (Not available)', W.Root.Name);
            else
                W.Root.Name = sprintf('Session: %s', sessionID);
                W.Root.UserData.filePath = dirPath;
            end
            
            obj.addSubFolderToNode(dirPath, W.Root, true)

            drawnow
            
            % Tree is up to date
            obj.IsTabDirty.(dataLocationName) = false;

            if ~isempty(obj.hPanelPreview)
                uistack(obj.hPanelPreview, 'top')
            end
        end
        
        function updateSubtree(obj, treeNode)
            
            isExpanded = obj.isNodeExpanded(treeNode);

            delete(treeNode.Children)
            pathName = treeNode.UserData.filePath;
            obj.addSubFolderToNode(pathName, treeNode)

            if isExpanded
                treeNode.expand()
            end
        end

        function W = createFolderTreeComponent(obj, hParent)
        % createFolderTreeComponent - Create a new folder tree component

            warning('off', 'MATLAB:ui:javacomponent:FunctionToBeRemoved')

            W = uiw.widget.FileTree('Parent', hParent);
            W.FontName = 'Avenir New';
            W.FontSize = 8;

            % Set color for selection background
            if ismac
                color = javax.swing.UIManager.get('Focus.color');
                rgb = cellfun(@(name) get(color, name), {'Red', 'Green', 'Blue'});
            else
                rgb = [0,0,200];
            end

            W.SelectionBackgroundColor = rgb./255;

            % Set callbacks
            W.MouseClickedCallback = @obj.onMouseClickOnTree;
            W.KeyPressFcn = @obj.onKeyPressed;

            %W.MouseMotionFcn = @obj.onMouseMotionOnTree;
            % This thing is not keeping up!
            %addlistener(W, 'MouseMotion', @obj.onMouseMotionOnTree);

            % Turn off opening of nodes on doubleclick. (Some nwb nodes are
            % datasets that should be previewed on doubleclick.
            jObj = W.getJavaObjects();
            javaTree = jObj.JControl;
            javaTree.setToggleClickCount(0);
            
            % Save components to class properties
            dataLocationName = obj.CurrentDataLocationName;

            obj.hFolderTree.(dataLocationName) = W;
            obj.jVerticalScroller(dataLocationName) = jObj.JScrollPane.getVerticalScrollBar();
            obj.jTree(dataLocationName) = javaTree;

            obj.IsTabDirty.(dataLocationName) = false;

            warning('on', 'MATLAB:ui:javacomponent:FunctionToBeRemoved')
        end

        function addSubFolderToNode(obj, rootDir, nodeHandle, isRecursive)
            
            if nargin < 4 || isempty(isRecursive)
                isRecursive = true;
            end
            
            L = dir(rootDir);
            skip = strncmp({L.name}, '.',  1);
            L(skip) = [];
            
            if numel(L) > 100
                numItemsNotShown = numel(L) - 100;
                L = L(1:100);
            else
                numItemsNotShown = 0;
            end
            
            hBranches = uiw.widget.FileTreeNode.empty;

            for i = 1:numel(L)
                if L(i).isdir
                    hBranches(i) = uiw.widget.FileTreeNode('Parent', nodeHandle);
                    
                    hBranches(i).Name = L(i).name;
                    
                    if isRecursive
                        obj.addSubFolderToNode(fullfile(rootDir, L(i).name), hBranches(i))
                    end
                    
                    hBranches(i).UserData.filePath = fullfile(L(i).folder, L(i).name);
                    folderIconPath = fullfile(obj.IconFolderPath, 'folder.gif');
                    setIcon(hBranches(i), folderIconPath);

                else
                    hBranches(i) = uiw.widget.FileTreeNode('Parent', nodeHandle);
                    hBranches(i).Name = L(i).name;
                    
                    [~, ~, fileExt] = fileparts(L(i).name);

                    switch fileExt
                        case '.mat'
                            icoFile = fullfile(obj.IconFolderPath, 'matfile.gif');
                        case {'.tif', '.avi', '.raw'}
                            icoFile = fullfile(obj.IconFolderPath, 'movie.gif');
                        case '.nwb'
                            % Todo: Should create reader object if it does
                            % not exist..
                            dataFilePath = obj.CurrentSessionObj.getDataFilePath('nwbReaderObject');
                            if isfile(dataFilePath)
                                nwbFileObj = obj.CurrentSessionObj.loadData('nwbReaderObject');
                                nannwb.nwbTree(nwbFileObj, hBranches(i)) % Todo: include in nansen
                            end
                            
                            icoFile = fullfile(matlabroot,'toolbox','matlab','icons','HDF_filenew.gif');
                        otherwise
                            icoFile = fullfile(matlabroot,'toolbox','matlab','icons','HDF_filenew.gif');
                    end

                    hBranches(i).UserData.filePath = fullfile(L(i).folder, L(i).name);
                    %hBranches(i).UIContextMenu = obj.createFileItemContextMenu(hBranches(i));
                    setIcon(hBranches(i), icoFile);
                end
            end
            
            if numItemsNotShown > 0
                hBranches(i+1) = uiw.widget.FileTreeNode('Parent', nodeHandle);
                hBranches(i+1).Name = sprintf('%d more items are present, but not shown...', numItemsNotShown);
            end
            
            if ~isRecursive % Todo: Fix/test this and recall what the meaning was
                for i = 1:numel(L)
                    if L(i).isdir
                        obj.addSubFolderToNode(fullfile(rootDir, L(i).name), hBranches(i))
                    end
                end
            end
        end
        
        function onMouseClickOnTree(obj, ~, event)
        %onMouseClickOnTree Callback for mouseclicks on tree    
            
            clickedNode = event.Nodes;
            if isempty(clickedNode)
                obj.CurrentNode = [];
                obj.CurrentTree.SelectedNodes = [];
            else
                obj.CurrentNode = clickedNode;
            end
            
            if event.NumClicks == 1 && strcmp(event.SelectionType, 'alt')
                obj.handleRightClick(event)
                
            elseif event.NumClicks == 2 && ~strcmp(event.SelectionType, 'alt')
                    
                if isempty(clickedNode)
                    return
                end

                % Todo: make a preview / open data method...
                
                %setIdle = obj.setBusy('Opening File...'); %#ok<NASGU>

                [~, fileName, fileExt] = fileparts(clickedNode.Name);

                % Look in the data variable model for items / elements that
                % match the filename and file extension.

                varModel = obj.CurrentSessionObj.VariableModel;                
                varName = varModel.findVariableByFilename([fileName, fileExt]);
                
                if ~isempty( varName )
                    [variableInfo, ~] = varModel.getVariableStructure(varName);
                    fileAdapterFcn = varModel.getFileAdapterFcn(variableInfo);
                    fileAdapter = fileAdapterFcn(clickedNode.UserData.filePath);
                    try
                        fileAdapter.view()
                    catch ME
                        errordlg(ME.message)
                    end
                    return
                end

                % - If no file adapter was found, use standard ways of
                % opening files:

                switch fileExt
                    
                    case '' % Assume folder
                        folderPath = clickedNode.UserData.filePath;
                        if isfolder(folderPath)
                            utility.system.openFolder(folderPath)
                        end
                    case {'.ini', '.tif', '.avi', '.raw'}
                        imviewer(clickedNode.UserData.filePath)
                        
                    case '.mat'
                        if ismac
                            [status, ~] = unix(sprintf('open -a finder ''%s''', clickedNode.UserData.filePath));
                        else
                            uiopen(clickedNode.UserData.filePath)    
                        end
                        
                    case '.png'
                        if ismac
                            filepath = strrep(clickedNode.UserData.filePath, ' ', '\ ');
                            [status, msg] = unix(sprintf('open -a Preview %s', filepath));
                        else
                            error('Can not open this file type')
                        end
                        
                    case '.nwb'
                        if isfield(clickedNode.UserData, 'nwbNode')
                            disp(clickedNode.UserData.nwbNode)
                        end
                        
                        
                    otherwise
                        if isfile(clickedNode.UserData.filePath)
                            errorMsg = 'Can not open this file type';
                            errordlg(errorMsg)
                            error(errorMsg)
                            
                        elseif isempty(clickedNode.UserData.filePath)
                            if isfield(clickedNode.UserData, 'Type') && ...
                                    strcmp(clickedNode.UserData.Type, 'nwb') && ...
                                    ~isempty(clickedNode.UserData.nwbNode)
 
                                name = clickedNode.Name;
                                name = clickedNode.UserData.nwbNodeName;
                                nwbObj = clickedNode.UserData.nwbNode;
                                previewNwbObject(name, nwbObj)
                            end

                        end
                end
            end
        end
        
        function onMouseMotionOnTree(obj, src, event)
        
            % Development idea: Do some preview on mouseover..
            
% %             persistent prevNode
% %             
% %             currentNode = event.Nodes
% %             thisNode = event.Nodes;
% %             
% %             if isequal(thisNode, prevNode)
% %                 return
% %             else
% %                 prevNode = thisNode;
% %             end
% %             
% %             if isempty(thisNode)
% %                 obj.hPanelPreview.Visible = 'off';
% %             else
% %                 obj.hPanelPreview.Visible = 'on';
% %             end
        end
        
        function pos = getPositionForContextMenu(obj, mouseEventPos)
        %getPositionForContextMenu Get position for placing contextmenu
        
            pixelPos = getpixelposition(obj.Parent, true);

            x = pixelPos(1) + mouseEventPos(1); 

            % Get y-position of pointer correcting for the vertical
            % scroll
            dataLocationName = obj.CurrentDataLocationName;
            verticalScroller = obj.jVerticalScroller(dataLocationName);
            
            yScroll = verticalScroller.getValue();
            y = pixelPos(4) - (mouseEventPos(2) - yScroll);
                
            pos = [x, y];
        end
        
        function openContextMenu(obj, treeNode, cMenuPosition)
        %openContextMenu Open contextmenu for a node on the Tree
                           
        % Open context menu. Select correct contextmenu based on whether 
        % node represents a file or an NWB dataset.
            
            if nargin < 3
                
            end
        
            if ~isempty(obj.CurrentNode)
                pathName = obj.CurrentNode.UserData.filePath;
            else
                pathName = obj.CurrentSessionObj.getSessionFolder(obj.CurrentDataLocationName);
            end

            if isfolder(pathName)
                obj.FolderContextMenu.Position = cMenuPosition;
                obj.FolderContextMenu.Visible = 'on';

            elseif isfile(pathName)
    
                if isfield(obj.CurrentNode.UserData, 'Type') && ...
                        strcmp(obj.CurrentNode.UserData.Type, 'nwb')
    
                    if isfield(obj.CurrentNode.UserData, 'nwbNode')
                        obj.nwbContextMenu.Position = cMenuPosition;
                        obj.nwbContextMenu.Visible = 'on';
                    end
                else
    
                    obj.FileContextMenu.Position = cMenuPosition;
                    obj.FileContextMenu.Visible = 'on';
                end
            end
        end
        
        function m = createFolderContextMenu(obj)
        % createFolderContextMenu - Create contextmenu for folder items in tree
        
            hFig = ancestor(obj.Parent, 'figure');
            m = uicontextmenu(hFig);

            appName = utility.system.getOsDependentName('Finder');
            mitem = uimenu(m, 'Text', sprintf('Show in %s', appName));
            mitem.Callback = @(s, e) obj.onFolderContextMenuSelected(s);

            mitem = uimenu(m, 'Text', 'Create New Folder');
            mitem.Callback = @(s, e) obj.onFolderContextMenuSelected(s);
            
            mitem = uimenu(m, 'Text', 'Refresh', 'Separator', 'on', 'Accelerator', 'R');
            mitem.Callback = @(s, e) obj.onFolderContextMenuSelected(s);
        end

        function m = createFileItemContextMenu(obj)
        %createFileItemContextMenu Create contextmenu for uitree  
        %
        %   
        
        %   Note: This contextmenu is not assigned to a specific uitree
        %   because it will be reused across uitrees.
            
            hFig = ancestor(obj.Parent, 'figure');
            m = uicontextmenu(hFig);
            
            mitem = uimenu(m, 'Text', 'Refresh', 'Accelerator', 'R');
            mitem.Callback = @(s, e) obj.onFileItemContextMenuSelected(s);
            
            appName = utility.system.getOsDependentName('Finder');
            mitem = uimenu(m, 'Text', sprintf('Show in %s', appName));
            mitem.Callback = @(s, e) obj.onFileItemContextMenuSelected(s);

            if ismac || isunix
                mitem = uimenu(m, 'Text', 'Open as Text', 'Separator', 'on');
                mitem.Callback = @(s, e) obj.onFileItemContextMenuSelected(s);
            end

            mitem = uimenu(m, 'Text', 'Open Outside MATLAB');
            mitem.Callback = @(s, e) obj.onFileItemContextMenuSelected(s);

            mitem = uimenu(m, 'Text', 'Copy Pathname');
            mitem.Callback = @(s, e) obj.onFileItemContextMenuSelected(s); 

            mitem = uimenu(m, 'Text', 'Create New Variable from File', 'Separator', 'on');
            mitem.Callback = @(s, e) obj.onCreateVariableMenuItemClicked();
            
            mitem = uimenu(m, 'Text', 'Create File Adapter for File');
            mitem.Callback = @(s, e) obj.onCreateFileAdapterMenuItemClicked();

            mitem = uimenu(m, 'Text', 'Load Data to Workspace', 'Separator', 'on');
            mitem.Callback = @(s, e) obj.onFileItemContextMenuSelected(s);
            
            mitem = uimenu(m, 'Text', 'Plot Data in Timeseries Plotter');
            mitem.Callback = @(s, e) obj.onFileItemContextMenuSelected(s);
        end
        
        function m = createNwbItemContextMenu(obj)
        %createNwbItemContextMenu Create context menu for NWB nodes
        
            hFig = ancestor(obj.Parent, 'figure');
            m = uicontextmenu(hFig);
            
            mitem = uimenu(m, 'Text', 'Preview');
            mitem.Callback = @(s, e) obj.onFileItemContextMenuSelected(s);
            
            mitem = uimenu(m, 'Text', 'Assign to Workspace');
            mitem.Callback = @(s, e) obj.onFileItemContextMenuSelected(s);
        end

        function handleRightClick(obj, eventData)
            
            clickedNode = eventData.Nodes;
            % Set the clicked node as the current node
            if ~isempty(clickedNode)
                obj.CurrentNode = clickedNode;
            end

            % Open context menu on current node.
            cMenuPos = obj.getPositionForContextMenu(eventData.Position);
            obj.openContextMenu(clickedNode, cMenuPos)
        end

        function onFolderContextMenuSelected(obj, src)
            
            if ~isempty(obj.CurrentNode)
                folderPath = obj.CurrentNode.UserData.filePath;
            else
                folderPath = obj.CurrentSessionObj.getSessionFolder(...
                    obj.CurrentDataLocationName);
            end

            switch src.Text

                case 'Refresh'
                    obj.updateSubtree(obj.CurrentNode)
                
                case 'Create New Folder'
                    obj.createNewFolder(folderPath)
                    obj.updateSubtree(obj.CurrentNode)
                    obj.CurrentNode.expand()

                case {'Show in Finder', 'Show in Explorer'}
                    utility.system.openFolder(folderPath)
            end
        end
        
        function onFileItemContextMenuSelected(obj, src)
        %onFileItemContextMenuSelected Callback for contect menu items
        
            nodeHandle = obj.CurrentNode;
            
            switch src.Text
                
                case 'Refresh'
                    obj.updateFolderTree()
                
                case {'Show in Finder', 'Show in Explorer'}
                    folderPath = obj.CurrentNode.UserData.filePath;
                    utility.system.openFolder(folderPath)

                case {'Open Outside MATLAB'}
                     utility.system.openFile( obj.CurrentNode.UserData.filePath )

                case {'Open as Text'}
                     utility.system.openFile( obj.CurrentNode.UserData.filePath, 'text' )

                case 'Copy Pathname'
                    clipboard('copy', obj.CurrentNode.UserData.filePath)

                case 'Load Data to Workspace'
                    % Todo: Use the sessionObject loadData and fileAdapters
                    obj.loadFileToWorkspace( nodeHandle.UserData.filePath )

                case 'Create New Variable from File'
                    
                case 'Plot Data in Timeseries Plotter'
                    S = load(nodeHandle.UserData.filePath);
                    timeSeriesData = struct2cell(S);
                    timeseriesPlot(timeSeriesData, 'Name', fieldnames(S))
                    
                case 'Preview'
                    % Todo: This is for nwb datasets, but should be general
                    % also for files.
                    name = nodeHandle.Name;
                    name = nodeHandle.UserData.nwbNodeName;
                    nwbObj = nodeHandle.UserData.nwbNode;
                    previewNwbObject(name, nwbObj)
                    
                case 'Assign to Workspace'
                    % Todo: Combine with Load Data to workspace and
                    % generalize...
                    assignin('base', nodeHandle.UserData.nwbNodeName, nodeHandle.UserData.nwbNode)
            end
        end
        
        function onCreateVariableMenuItemClicked(obj)
        %onCreateVariableMenuItemClicked Callback for menu item
        %
        %   Open user dialog to get information and add an item for this
        %   file to the variable model.
        
            import nansen.config.varmodel.VariableModel
        
            nodeHandle = obj.CurrentNode;

            % Get information about file's path and data location
            [folder, fileName, ext] = fileparts(nodeHandle.UserData.filePath);
            currentDataLocation = obj.TabGroup.SelectedTab.Title;
            
            sObj = obj.CurrentSessionObj;

            fileAdapterList = nansen.dataio.listFileAdapters(ext);
            fileName = strrep(fileName, sObj.sessionID, '');
            
            % Create a struct with fields that are required from user
            S = struct();
            S.VariableName = '';
            S.FileNameExpression = fileName;
            S.FileAdapter_ = {fileAdapterList.FileAdapterName};
            S.FileAdapter = fileAdapterList(1).FileAdapterName;
            S.Favorite = false;
            
            % Open user dialog:
            [S, wasAborted] = tools.editStruct(S, [], 'Create New Variable');
            S = rmfield(S, 'FileAdapter_');
            if wasAborted; return; end
            
            % Add other fields that are required for the variable model.
            
            % Add the new item to the current variable model.
            % Todo: Get variable model from the sessionobject/dataiomodel
            
            varItem = VariableModel.getDefaultItem(S.VariableName);
            varItem.IsCustom = true;
            varItem.IsFavorite = S.Favorite;
            varItem.DataLocation = currentDataLocation;
            varItem.FileNameExpression = S.FileNameExpression;
            varItem.FileAdapter = S.FileAdapter;
            
            dloc = sObj.getDataLocation(currentDataLocation);
            varItem.DataLocationUuid = dloc.Uuid;
            varItem.FileType = ext;

            sessionFolder = sObj.getSessionFolder(currentDataLocation);
            varItem.Subfolder = strrep(folder, sessionFolder, '');
            if strncmp(varItem.Subfolder, filesep, 1)
                varItem.Subfolder = varItem.Subfolder(2:end);
            end
            
            fileAdapterIdx = strcmp({fileAdapterList.FileAdapterName}, S.FileAdapter);
            varItem.DataType = fileAdapterList(fileAdapterIdx).DataType;
            
            % Todo: get variable model for current project. In practice
            % this will always happen, but it should be explicit!
            VM = nansen.VariableModel();
            VM.insertItem(varItem)
            obj.notify('VariableModelChanged', event.EventData)
            
            % Todo: Display error message if variable already exists.
            % And/or ask if variable should be replaced?
        end
        
        function onCreateFileAdapterMenuItemClicked(obj)
            
            nodeHandle = obj.CurrentNode;

            % Get information about file's path and data location
            [~, ~, fileExtension] = fileparts(nodeHandle.UserData.filePath);
            fileAdapterAttributes = nansen.module.uigetFileAdapterAttributes(...
                'SupportedFileTypes', fileExtension);

            if isempty(fileAdapterAttributes); return; end

            project = nansen.getCurrentProject();
            targetPath = project.getFileAdapterFolder();
            nansen.module.createFileAdapter(targetPath, fileAdapterAttributes)
        end

        function onParentSizeChanged(obj, src, evt)
                      
            uim.utility.layout.centerObjectInRectangle(obj.hBackgroundLabel, ...
                getpixelposition(obj.Parent))
        end
    
        function tf = isNodeExpanded(obj, treeNode)
        % isNodeExpanded - Check if the provided node is expanded
            % Get current tree
            currentJTree = obj.jTree(obj.CurrentDataLocationName);

            warning('off', 'MATLAB:structOnObject')
            S = struct(treeNode);
            warning('on', 'MATLAB:structOnObject')

            jNode = S.JNode;
            nodePath = jNode.TreePath;
        
            tf = currentJTree.isExpanded(nodePath);
        end

    end
    
    methods (Access = private)

        function createNewFolder(obj, folderPath)
            inputCellArray = inputdlg('Enter folder name', 's');
            if ~isempty(inputCellArray)
                folderName = inputCellArray{1};
                if ~isfolder(fullfile(folderPath, folderName))
                    mkdir(fullfile(folderPath, folderName));
                    % Refresh tree if the tab is dirty...
                else
                    msgbox('Folder already exists.')
                end
            end
        end

    end

    methods (Static, Access = private)
  
        function loadFileToWorkspace( pathName )
            % Todo: This should probably be either a method on the session
            % class or on a data collection class.
            
            [~, ~, fileExt] = fileparts(pathName);

            switch fileExt

                case {'.ini', '.tif', '.avi', '.raw'}
                    imageStack = nansen.stack.ImageStack(pathName);
                    assignin('base', 'imageStack', imageStack)
                    
                case '.mat'
                    S = load(pathName);
                    varNames = fieldnames(S);
                    for i = 1:numel(varNames)
                        assignin('base', varNames{i}, S.(varNames{i}))
                    end
                    
                otherwise
                    message = sprintf('Can not load files of type %s to workspace', fileExt);
                    errordlg(message)
            end
        end
    
    end
end