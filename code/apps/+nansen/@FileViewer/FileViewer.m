classdef FileViewer < nansen.AbstractTabPageModule
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
%       []Add preferences and
%           - MaxNumItemsToShow. Currently hardcoded to 100
%       [ ] More efficient creation of file trees with large number of files
%           ( Large, nested folder tree )
%       [ ] Adding new variables here does not appear to update the
%           variable model in nansen.

    properties (Constant)
        Name = 'File Viewer'
    end

    properties (SetAccess = private)
        DataLocationNames
    end

    properties
        CurrentSessionObj
        SessionIDList
        SessionSelectedFcn % Function handle. Will be called with a single input: sessionID
    end
    
    properties (Access = private, Hidden)
        IconFolderPath
        IsTabDirty
        IsInitialized = false
        
        CurrentNode % The current node selection in the tree
    end

    properties (Dependent, Access = private)
        CurrentDataLocationName
        CurrentTab
        CurrentTree
    end

    properties (Access = private) % GUI Components
        SessionListBox = gobjects().empty

        TabGroup % Tabgroup for different data locations
        DataLocationTabs
        hFolderTree
        jTree
        jVerticalScroller
        
        % %  Menu handles
        FileContextMenu
        FolderContextMenu
        nwbContextMenu
        ViewFileAdapterSubMenu
        ViewFileAdapterSubMenuItems
        LoadDataVariableSubMenu
        LoadDataVariableSubMenuItems
        ViewDataVariableSubMenu
        ViewDataVariableSubMenuItems
        
        hPanelPreview
        hStatusLabel = gobjects().empty % Show status message (if no session is selected)
    end
    
    methods % Constructor
        
        function obj = FileViewer(varargin)
        %FileViewer Construct a fileviewer object
        %
        %   Syntax:
        %
        %      h = nansen.FileViewer(hParent, dataLocationNames) creates a
        %      file viewer for a set of data locations in the graphical
        %      container given by hParent

            % Note: The tabgroup and filetree components will be created
            % on demand.
        
            obj@nansen.AbstractTabPageModule(varargin{:})
        end

        function delete(obj)
            if obj.IsInitialized
                delete(obj.TabGroup)
            end
            %delete(obj.SessionListBox)
            %delete(obj.hStatusLabel)
            delete(obj.FileContextMenu)
            delete(obj.FolderContextMenu)
            delete(obj.nwbContextMenu)
        end
    end
    
    methods (Access = public)
        
        function id = getCurrentObjectId(obj)
        %getCurrentObjectId Get ID of current session object.
            id = '';
            if ~isempty(obj.CurrentSessionObj) && isvalid(obj.CurrentSessionObj)
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
                obj.createTabGroup(metaTableEntry)
            end
            
            sessionID = metaTableEntry.sessionID;%{:};
            
            % Determine if an update is needed.
            if ~isempty(obj.hFolderTree)
                                
                if ~strcmp(obj.getCurrentObjectId, sessionID)
                    
                    obj.CurrentSessionObj = metaTableEntry;
                    obj.markTabsAsDirty()
                                        
                    doUpdate = true;
                else
                    doUpdate = false;
                end
            else
                doUpdate = true;
                obj.CurrentSessionObj = metaTableEntry;
            end

            obj.updateSessionListBoxSelection()
            
            if doUpdate
                obj.updateStatusLabelText('Updating, please wait...')
                obj.updateFolderTree()
                obj.updateStatusLabelText('')
                drawnow
            end
        end
    end
    
    methods % Set/get

        function set.SessionIDList(obj, value)
            obj.SessionIDList = value;
            obj.onSessionIDListSet()
        end

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
            if ~isempty(obj.hFolderTree)
                W = obj.hFolderTree.(obj.CurrentDataLocationName);
            else
                W = [];
            end
        end
    
        function T = get.CurrentTab(obj)
            T = obj.TabGroup.SelectedTab;
        end
    end

    methods (Access = protected) % Implement superclass methods

        function handleOptionalInputs(obj, listOfInputs) %#ok<*INUSD>
            obj.DataLocationNames = listOfInputs{1};
        end

        function createComponents(obj)
            
            %obj.createPanels()
            obj.setIconFolderPath()
            
            obj.createTabGroup()

            obj.createStatusLabel()
            obj.createContextMenus()

            obj.jVerticalScroller = containers.Map();
            obj.jTree = containers.Map();
                       
            % obj.createPreviewPanel() % Not implemented yet
        end

        function updateComponentLayout(obj)
            import uim.utility.layout.subdividePosition
            import uim.utility.layout.centerObjectInRectangle

            if isempty(obj.TabGroup); return; end

            M = 0; % Margin

            if ~isempty(obj.hStatusLabel)
                parentPosition = getpixelposition(obj.Parent);
                centerPosition = parentPosition(1:2) + parentPosition(3:4) / 2;
                newPosition = getpixelposition(obj.hStatusLabel(1), true);
                newPosition(1:2) = centerPosition - newPosition(3:4) / 2;
                newPosition(2) = newPosition(2) + 50;
                arrayfun(@(h) setpixelposition(h, newPosition, true), obj.hStatusLabel);
            end

            parentPosition = getpixelposition(obj.TabGroup.SelectedTab);

            [X, W] = subdividePosition(M, parentPosition(3), [200, 1]);
            H = parentPosition(4);
            
            if ~isempty(obj.SessionListBox)
                arrayfun(@(h)setpixelposition(h, [X(1), 1, W(1), H]), obj.SessionListBox)
            end
            if ~isempty(obj.hFolderTree)
                structfun(@(h) setpixelposition(h, [X(2), 0, W(2)+1, H+2]), obj.hFolderTree);
            end
            drawnow
        end
    end

    methods (Access = ?uiw.widget.FileTree)

        function onKeyPressedInTree(obj, src, evt)
        % onKeyPressedInTree - Give tree to access private callback
            obj.onKeyPressed(src, evt)
        end
    end
    
    methods (Access = {?nansen.App, ?nansen.AbstractTabPageModule})
        
        function wasCaptured = onKeyPressed(obj, ~, evt)
            
            wasCaptured = true;
            
            switch evt.Key
                case 'r'
                    if strcmp(evt.Modifier, 'command') | strcmp(evt.Modifier, 'control')
                        obj.updateFolderTree()
                    else
                        wasCaptured = false;
                    end

                case 'l'
                    if strcmp(evt.Modifier, 'command') | strcmp(evt.Modifier, 'control')
                        obj.loadFileToWorkspace()
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

    methods (Access = private) % Internal creation and updating
        
        function setIconFolderPath(obj)
            rootDir = fileparts(mfilename('fullpath'));
            obj.IconFolderPath = fullfile(rootDir, '_graphics', 'icons');
        end

        function createStatusLabel(obj)
        %createBackground
            
            for i = 1:numel(obj.TabGroup.Children)
                hParent = obj.TabGroup.Children(i);
                obj.hStatusLabel(i) = uicontrol(hParent, 'style', 'text');
                obj.hStatusLabel(i).String = 'No Session Selected';
                obj.hStatusLabel(i).FontSize = 20;
                obj.hStatusLabel(i).ForegroundColor = ones(1,3)*0.6;
                obj.hStatusLabel(i).Position(3:4) = obj.hStatusLabel(i).Extent(3:4);
            end
        end

        function updateStatusLabelText(obj, text)
            for i = 1:numel( obj.hStatusLabel )
                obj.hStatusLabel(i).String = text;
                obj.hStatusLabel(i).Position(3:4) = obj.hStatusLabel(i).Extent(3:4);
            end
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

        function createSessionListbox(obj, hParent, num)
            % Create listbox
            sessionListBox = uicontrol(hParent, 'Style', 'listbox');
            sessionListBox.Units = 'normalized';
            sessionListBox.Position = [0, 0, 0.18, 1];
            sessionListBox.FontSize = 14;
            sessionListBox.FontName = 'Avenir New';
            sessionListBox.Callback = @obj.onSessionSelected;
            sessionListBox.Interruptible = 'off';
            obj.SessionListBox(num) = sessionListBox;
        end

        function createTabGroup(obj)
        % createTabGroup - Create tabgroup with one tab per data location
            obj.TabGroup = uitabgroup(obj.Parent);
            obj.TabGroup.Units = 'normalized';

            %obj.TabGroup.Position = [0 0 1 1];

            % Create tab for each data location type.
            for i = 1:numel(obj.DataLocationNames)
                tabName = obj.DataLocationNames{i};

                hTab = uitab(obj.TabGroup);
                hTab.Title = tabName;

                obj.DataLocationTabs.(tabName) = hTab;
                obj.IsTabDirty.(tabName) = true;

                obj.createSessionListbox(hTab, i)
            end

            obj.onSessionIDListSet()
            obj.updateComponentLayout()

            obj.TabGroup.SelectionChangedFcn = @obj.changeTab;
            obj.IsInitialized = true;
        end
        
        function W = createFolderTreeComponent(obj, hParent)
        % createFolderTreeComponent - Create a new folder tree component

            warning('off', 'MATLAB:ui:javacomponent:FunctionToBeRemoved')

            W = uiw.widget.FileTree('Parent', hParent);
            W.FontName = 'Avenir New';
            W.FontSize = 8;
            W.Position = [0.2,0,0.8,1];

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
            W.KeyPressFcn = @obj.onKeyPressedInTree;

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
            obj.updateComponentLayout()

            warning('on', 'MATLAB:ui:javacomponent:FunctionToBeRemoved')
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
            if isempty(obj.hFolderTree); return; end
            
            for i = 1:numel(obj.DataLocationNames)
                if isfield(obj.hFolderTree, obj.DataLocationNames{i})
                    hTree = obj.hFolderTree.(obj.DataLocationNames{i});
                    hTree.Visible = 'off';
                    hTree.Root.Name = '';
                    delete(hTree.Root.Children)
                end
            end
        end
        
        function changeTab(obj, ~, ~)
            
            dataLocationName = obj.TabGroup.SelectedTab.Title;
            
            % Create tree if the tab is dirty...
            if obj.IsTabDirty.(dataLocationName)
                obj.updateFolderTree()
            end
            drawnow
        end
    
        function onSessionIDListSet(obj)
            if isempty(obj.SessionListBox); return; end

            values = cat(1, {'<No Session Selected>'}, obj.SessionIDList);
            set(obj.SessionListBox, 'String', values);
            set(obj.SessionListBox, 'Value', 1);

            obj.updateSessionListBoxSelection()
        end

        function updateSessionListBoxSelection(obj)
            if ~isempty(obj.CurrentSessionObj) && isvalid(obj.CurrentSessionObj)
                currentSessionID = obj.CurrentSessionObj.sessionID;
                currentValue = find(strcmp(obj.SessionIDList, currentSessionID));
            else
                currentValue = 0;
            end
            set(obj.SessionListBox, 'Value', currentValue+1);
            % Added one because first item in list is the no session
            % selected
        end

        function updateFolderTree(obj)
            
            warning('off', 'MATLAB:ui:javacomponent:FunctionToBeRemoved')
            sessionObject = obj.CurrentSessionObj;
            if isempty(obj.CurrentSessionObj); return; end

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
                %W.Visible = 'off';
            end

            try
                dirPath = sessionObject.getSessionFolder(dataLocationName, 'nocreate');
            catch ME %#ok<NASGU>
                dirPath = '';
            end

            isVirtual = sessionObject.isVirtualSessionFolder(dataLocationName);
            
            if isempty(dirPath)
                W.Root.Name = sprintf('%s [Folder does not exist]', W.Root.Name);
            elseif ~isfolder(dirPath)
                W.Root.Name = sprintf('%s (Not available)', W.Root.Name);
            else
                W.Root.Name = sprintf('Session: %s', sessionID);
                W.Root.UserData.filePath = dirPath;
            end
            
            if isVirtual
                obj.addSubFolderToNode(dirPath, W.Root, false, ...
                    'FilterFcn', @(names) contains(names, sessionObject.sessionID));
            else
                obj.addSubFolderToNode(dirPath, W.Root, true)
            end

            %W.Visible = 'on';
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

        function addSubFolderToNode(obj, rootDir, nodeHandle, isRecursive, options)
        % addSubFolderToNode - Adds subfolders and files to a specified node in a
        %                     file tree structure.
 
            arguments
                obj
                rootDir
                nodeHandle
                isRecursive (1,1) logical = true
                options.FilterFcn = []
            end
            
            L = dir(rootDir);
            skip = strncmp({L.name}, '.',  1);
            L(skip) = [];

            if ~isempty(options.FilterFcn)
                L = L(options.FilterFcn({L.name}));
            end
            
            if numel(L) > 100
                numItemsNotShown = numel(L) - 100;
                L = L(1:100);
            else
                numItemsNotShown = 0;
            end
            
            hBranches = uiw.widget.FileTreeNode.empty;
        
            for i = 1:numel(L)
                if ~isvalid(nodeHandle); continue; end
        
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
                                nannwb.nwbTree(nwbFileObj, hBranches(i)); % Todo: include in nansen
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
            
            % Update current node
            clickedNode = event.Nodes;
            if isempty(clickedNode)
                obj.CurrentNode = [];
                obj.CurrentTree.SelectedNodes = [];
            else
                obj.CurrentNode = clickedNode;
            end
            
            % Handle click based on click type
            if event.NumClicks == 1 && strcmp(event.SelectionType, 'alt')
                obj.handleRightClick(event)
                
            elseif event.NumClicks == 2 && ~strcmp(event.SelectionType, 'alt')
                if isempty(clickedNode); return; end
                obj.handleDoubleClick(event)
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
                % Todo: remove?
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
                    
                    L = dir(pathName);

                    hMenu = findobj(obj.FileContextMenu, 'Text', 'Download File');
                    if ~isempty(hMenu)
                        if L.bytes==0
                            hMenu.Enable = 'on';
                        else
                            hMenu.Enable = 'off';
                        end
                    end

                    obj.createFileAdapterSubMenu(pathName)
                    obj.createLoadDataVariableSubMenu(pathName)
                    obj.createViewDataVariableSubMenu(pathName)

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

            mitem = uimenu(m, 'Text', 'Make Current Folder');
            mitem.Callback = @(s, e) obj.onFolderContextMenuSelected(s);

            mitem = uimenu(m, 'Text', 'Create New Folder');
            mitem.Callback = @(s, e) obj.onFolderContextMenuSelected(s);
            
            mitem = uimenu(m, 'Text', 'Refresh', 'Separator', 'on', 'Accelerator', 'R');
            mitem.Callback = @(s, e) obj.onFolderContextMenuSelected(s);
        end

        function m = createFileItemContextMenu(obj)
        %createFileItemContextMenu Create contextmenu for uitree
        %
        %   Note: This contextmenu is not assigned to a specific uitree
        %   because it will be reused across uitrees.
            
            project = nansen.getCurrentProject();

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
            
            if ~isempty( which( sprintf('%s.filemethod.downloadFile',project.Name) ) )
                mitem = uimenu(m, 'Text', 'Download File', 'Separator', 'on');
                mitem.Callback = @(s, e) obj.onFileItemContextMenuSelected(s);
            end

            mitem = uimenu(m, 'Text', 'Create New Variable from File...', 'Separator', 'on');
            mitem.Callback = @(s, e) obj.onCreateVariableMenuItemClicked();
            
            mitem = uimenu(m, 'Text', 'Create File Adapter for File...');
            mitem.Callback = @(s, e) obj.onCreateFileAdapterMenuItemClicked();
                     
            mitem = uimenu(m, 'Text', 'View File Adapter', "Enable", "off");
            obj.ViewFileAdapterSubMenu = mitem;

            mitem = uimenu(m, 'Text', 'Load Data Variable to Workspace', "Enable", "off", 'Separator', 'on');
            obj.LoadDataVariableSubMenu = mitem;
            
            mitem = uimenu(m, 'Text', 'View Data Variable', "Enable", "off");
            obj.ViewDataVariableSubMenu = mitem;

            mitem = uimenu(m, 'Text', 'Load File to Workspace', 'Accelerator', 'L', 'Separator', 'on');
            mitem.Callback = @(s, e) obj.onFileItemContextMenuSelected(s);
           
            mitem = uimenu(m, 'Text', 'View File', 'Accelerator', 'V');
            mitem.Callback = @(s, e) obj.onFileItemContextMenuSelected(s);

            % mitem = uimenu(m, 'Text', 'Plot Data in Timeseries Plotter');
            % mitem.Callback = @(s, e) obj.onFileItemContextMenuSelected(s);
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

        function createLoadDataVariableSubMenu(obj, filePath)
            varNames = obj.detectVariablesForFile(filePath);

            if ~isempty(obj.LoadDataVariableSubMenuItems)
                delete(obj.LoadDataVariableSubMenuItems)
                obj.LoadDataVariableSubMenuItems = [];
            end

            if isempty(varNames)
                obj.LoadDataVariableSubMenu.Enable = "off";
            else
                if ischar(varNames)
                    varNames = {varNames};
                end
                obj.LoadDataVariableSubMenu.Enable = "on";
                menuList = uics.MenuList(obj.LoadDataVariableSubMenu, varNames);
                menuList.SelectionMode = 'none';
                menuList.MenuSelectedFcn = @(s,e) obj.onLoadDataVariableItemClicked(s, filePath);
                obj.LoadDataVariableSubMenuItems = menuList;
            end
        end
        
        function createViewDataVariableSubMenu(obj, filePath)
            varNames = obj.detectVariablesForFile(filePath);

            if ~isempty(obj.ViewDataVariableSubMenuItems)
                delete(obj.ViewDataVariableSubMenuItems)
                obj.ViewDataVariableSubMenuItems = [];
            end

            if isempty(varNames)
                obj.ViewDataVariableSubMenu.Enable = "off";
            else
                if ischar(varNames)
                    varNames = {varNames};
                end
                obj.ViewDataVariableSubMenu.Enable = "on";
                menuList = uics.MenuList(obj.ViewDataVariableSubMenu, varNames);
                menuList.SelectionMode = 'none';
                menuList.MenuSelectedFcn = @(s,e) obj.onViewDataVariableItemClicked(s, filePath);
                obj.ViewDataVariableSubMenuItems = menuList;
            end
        end

        function createFileAdapterSubMenu(obj, filePath)
            [fileAdapter, varName] = obj.detectFileAdapter(filePath, "all");
            
            if ~isempty(obj.ViewFileAdapterSubMenuItems)
                delete(obj.ViewFileAdapterSubMenuItems)
                obj.ViewFileAdapterSubMenuItems = [];
            end

            if isempty(fileAdapter)
                obj.ViewFileAdapterSubMenu.Enable = "off";
            else
                fileAdapterName = cellfun(@(c) c.classname(), fileAdapter, 'uni', 0);
                fileAdapterName = unique(fileAdapterName);
                obj.ViewFileAdapterSubMenu.Enable = "on";
                menuList = uics.MenuList(obj.ViewFileAdapterSubMenu, fileAdapterName);
                menuList.SelectionMode = 'none';
                menuList.MenuSelectedFcn = @(s,e) obj.onViewFileAdapterItemClicked(s, filePath);
                obj.ViewFileAdapterSubMenuItems = menuList;
            end
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
        
        function handleDoubleClick(obj, eventData)

            % Todo: make a preview / open data method...
            
            %setIdle = obj.setBusy('Opening File...'); %#ok<NASGU>

            clickedNode = eventData.Nodes;
            pathName = clickedNode.UserData.filePath;
            fileAdapter = obj.detectFileAdapter(pathName);
            
            if ~isempty(fileAdapter)
                try
                    fileAdapter.view()
                catch ME
                    errordlg(ME.message)
                end
                return
            end

            % - If no file adapter was found, use standard ways of
            % opening files:
            [~, ~, fileExt] = fileparts(clickedNode.Name);

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

        function onSessionSelected(obj, src, evt)
            if isempty(src.Value); return; end
            
            if src.Value == 1
                obj.updateStatusLabelText('No session selected')
                obj.resetTreeControls()
                obj.CurrentSessionObj = [];
                obj.updateSessionListBoxSelection()
            else
                sessionID = src.String{src.Value};

                if ~strcmp(sessionID, obj.getCurrentObjectId())
                    if ~isempty(obj.SessionSelectedFcn)
                        obj.resetTreeControls()
                        obj.SessionSelectedFcn(sessionID)
                    end
                end
            end
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

                case 'Make Current Folder'
                    cd(folderPath)

                case {'Show in Finder', 'Show in Explorer', 'Show in File Explorer'}
                    utility.system.openFolder(folderPath)
            end
        end
        
        function onFileItemContextMenuSelected(obj, src)
        %onFileItemContextMenuSelected Callback for context menu items
        
            nodeHandle = obj.CurrentNode;
            
            switch src.Text
                
                case 'Refresh'
                    obj.updateFolderTree()
                
                case {'Show in Finder', 'Show in Explorer', 'Show in File Explorer'}
                    folderPath = obj.CurrentNode.UserData.filePath;
                    utility.system.openFolder(folderPath)

                case {'Open Outside MATLAB'}
                     utility.system.openFile( obj.CurrentNode.UserData.filePath )

                case {'Open as Text'}
                     utility.system.openFile( obj.CurrentNode.UserData.filePath, 'text' )

                case 'Copy Pathname'
                    clipboard('copy', obj.CurrentNode.UserData.filePath)

                case 'Download File'
                    project = nansen.getCurrentProject;
                    functionName = sprintf('%s.filemethod.downloadFile', project.Name);

                    try
                        rootPath = obj.CurrentSessionObj.getDataLocationRootDir(obj.CurrentDataLocationName);
                        feval(functionName, nodeHandle.UserData.filePath, rootPath)
                    catch ME
                        msgbox(ME.message)
                    end

                case 'Load File to Workspace'
                    % Todo: Use the sessionObject loadData and fileAdapters
                    obj.loadFileToWorkspace( nodeHandle.UserData.filePath )

                case 'View File'
                    obj.viewFile( nodeHandle.UserData.filePath )

                case 'Create New Variable from File...'
                    
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

        function onLoadDataVariableItemClicked(obj, src, filePath)
            variableName = src.Text;
            obj.loadDataVariableToWorkspace(variableName)            
        end

        function onViewDataVariableItemClicked(obj, src, filePath)
            variableName = src.Text;
            obj.openDataVariableInViewer(variableName)            
        end
        
        function onViewFileAdapterItemClicked(obj, src, filePath)
            fileAdapterName = src.Text;
            fileAdapterList = nansen.dataio.listFileAdapters();

            isMatch = strcmp({fileAdapterList.FileAdapterName}, fileAdapterName);
            edit( sprintf('%s/read', fileAdapterList(isMatch).FunctionName) );
        end
        
        function onCreateVariableMenuItemClicked(obj)
        %onCreateVariableMenuItemClicked Callback for menu item
        %
        %   Open user dialog to get information and add an item for this
        %   file to the variable model.
        
            import nansen.config.varmodel.uiCreateDataVariableFromFile
            filePath = obj.CurrentNode.UserData.filePath;

            if endsWith(filePath, '.mat')
                obj.createDataVariableBatch(); return
            end
            sessionObject = obj.CurrentSessionObj;
            currentDataLocation = obj.TabGroup.SelectedTab.Title;
        
            try
                newDataVariable = uiCreateDataVariableFromFile(...
                    filePath, currentDataLocation, sessionObject);
                if ~isempty(newDataVariable)
                    variableModel = sessionObject.VariableModel;
                    variableModel.insertItem(newDataVariable)
                end
            catch ME
                % Display error message if something went wrong.
                errordlg(ME.message)
                disp(getReport(ME, 'extended'))
                return
            end
        end

        function createDataVariableBatch(obj)
            import nansen.ui.fileviewer.BatchDatavariableSelector
        
            filePath = obj.CurrentNode.UserData.filePath;
            sessionObject = obj.CurrentSessionObj;
            currentDataLocation = obj.TabGroup.SelectedTab.Title;

            try
                nansen.ui.fileviewer.BatchDatavariableSelector(...
                    filePath, currentDataLocation, sessionObject);
            catch ME
                % Display error message if something went wrong.
                errordlg(ME.message)
                disp(getReport(ME, 'extended'))
                return
            end
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

    methods (Access = private) % Nansen related methods

        function [fileAdapter, varName] = detectFileAdapter(obj, filePath, mode)
        % detectFileAdapter - Detect if a file is associated with a file adapter

            arguments
                obj
                filePath
                mode (1,1) string {mustBeMember(mode, ["first", "all"])} = "first"
            end

            [~, fileName, fileExtension] = fileparts(filePath);

            % Look in the data variable model for items / elements that
            % match the filename and file extension.
            varModel = obj.CurrentSessionObj.VariableModel;
            varName = varModel.findVariableByFilename([fileName, fileExtension], mode);
            
            % Wrap in cell to be compatible with loop below
            if ~isempty(varName) && ischar(varName)
                varName = {varName};
            end
            
            fileAdapter = cell(1, numel(varName));

            % Get file adapter
            for i = 1:numel( varName )
                [variableInfo, ~] = varModel.getVariableStructure(varName{i});
                fileAdapterFcn = varModel.getFileAdapterFcn(variableInfo);
                fileAdapter{i} = fileAdapterFcn(filePath);
            end

            if isscalar(varName) && mode == "first"
                fileAdapter = fileAdapter{1};
                varName = varName{1};
            end

            if nargout < 2
                clear varName
            end
        end

        function varNames = detectVariablesForFile(obj, filePath)
            [~, fileName, fileExtension] = fileparts(filePath);

            % Look in the data variable model for items / elements that
            % match the filename and file extension.
            varModel = obj.CurrentSessionObj.VariableModel;
            varNames = varModel.findVariableByFilename([fileName, fileExtension], 'all');
        end
        
        function openFilePreview(obj, filePath)
            % Todo
        end

        function viewFile(obj, pathName)
            obj.viewFileByFileType(pathName)
        end

        function loadFileToWorkspace(obj, pathName)
            % Todo: This should probably be either a method on the session
            % class or on a data collection class.
            
            if nargin < 2
                pathName = obj.CurrentNode.UserData.filePath;
            end

            if isfolder(pathName); return; end
            obj.loadFileToWorkspaceByFileType(pathName)
        end

        function loadDataVariableToWorkspace(obj, variableName)
            fprintf('Please wait, loading data...')
            data = obj.CurrentSessionObj.loadData(variableName);
            assignin('base', variableName, data)
            fprintf(' Done.\n')
        end

        function openDataVariableInViewer(obj, variableName)
            fprintf('Please wait, loading data...')
            obj.CurrentSessionObj.viewDataVariable(variableName);
        end
    end

    methods (Static, Access = private)
  
        function createNewFolder(folderPath)
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
    
        function loadFileToWorkspaceByFileType(pathName)
        % loadFileToWorkspaceByFileType - Try to load a file by its
        % filetype
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

        function viewFileByFileType(pathName)
            errordlg('Not implemented yet')
        end
    end
end
