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
%       [ ] Add reset method...

    properties
        CurrentSessionObj
    end
    
    properties (SetAccess = private)
        Parent
        hFolderTree
        jTree
        jVerticalScroller
        
        TabGroup
    end
    
    properties (Access = private, Hidden)
        IconFolderPath
        DataLocationTabs
        IsTabDirty
        IsInitialized = false
        
        CurrentNode
        hContextMenu % todo: rename to hFileContextMenu
        
        nwbContextMenu
        
        hPanelPreview
        hBackgroundLabel
        
        ParentSizeChangedListener event.listener
    end
    
    
    methods % Constructor
        
        function obj = FileViewer(varargin)
        %FileViewer Construct a fileviewer object
        
            % Take care of input arguments.
            obj.parseInputs(varargin)
            
            obj.setIconFolderPath()  
            
            obj.createBackgroundLabel()
            
            % Initialize the context menu on construction. This will be 
            % reused across data locations and items in the uitree.
            obj.hContextMenu = obj.createTreeItemContextMenu();
            obj.nwbContextMenu = obj.createNwbItemContextMenu();
            
% % %             obj.hPanelPreview = uipanel(obj.Parent);
% % %             obj.hPanelPreview.Units = 'pixels';
% % %             obj.hPanelPreview.Position(3:4) = [500,300];
% % %             obj.hPanelPreview.Visible = 'off';
% % %             
% % %             % center
% % %             uim.utility.layout.centerObjectInRectangle(obj.hPanelPreview, obj.Parent);
        
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
            
            delete(obj.hContextMenu)
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
                obj.createFolderTreeControl()
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
        
        function createTabgroup(obj, metaTableEntry)
            
            dlTypes = {metaTableEntry.DataLocation.Name};

            
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
    
        function createFolderTreeControl(obj)
            
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
            
            % Delete old tree if it exists.
            if isfield(obj.hFolderTree, dataLocationName) && isvalid(obj.hFolderTree.(dataLocationName))
                delete(obj.hFolderTree.(dataLocationName))
            end

            W = uiw.widget.FileTree('Parent', hParent);
            W.Root.Name = sprintf('Session: %s', sessionID);
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

            try
                dirPath = sessionObject.getSessionFolder(dataLocationName);
            catch ME
                dirPath = '';
            end
            
            %dirPath = sessionObject.DataLocation.(dataLocationName);
            
            if ~isfolder(dirPath)
                W.Root.Name = sprintf('%s (Not available)', W.Root.Name);
            else
                W.Root.UserData.filePath = dirPath;
            end
            
            obj.addSubFolderToNode(dirPath, W.Root, true)

            W.MouseClickedCallback = @obj.onMouseClickOnTree;
            
            %W.MouseMotionFcn = @obj.onMouseMotionOnTree;
            % This thing is not keeping up!
            %addlistener(W, 'MouseMotion', @obj.onMouseMotionOnTree);
            
            % Turn off opening of nodes on doubleclick. (Some nwb nodes are
            % datasets that should be previewed on doubleclick.
            jObj = W.getJavaObjects();
            obj.jTree = jObj.JControl;
            obj.jTree.setToggleClickCount(0);
            
            obj.jVerticalScroller = jObj.JScrollPane.getVerticalScrollBar();
            
            obj.hFolderTree.(dataLocationName) = W;
            obj.IsTabDirty.(dataLocationName) = false;
            
            warning('on', 'MATLAB:ui:javacomponent:FunctionToBeRemoved')

            if ~isempty(obj.hPanelPreview)
                uistack(obj.hPanelPreview, 'top')
            end
            
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
                    %hBranches(i).UIContextMenu = obj.createTreeItemContextMenu(hBranches(i));
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
        
        function onMouseClickOnTree(obj, src, event)
        %onMouseClickOnTree Callback for mouseclicks on tree    
            currentNode = event.Nodes;
            
            if isempty(currentNode)
                return
            end
            
            if event.NumClicks == 1 && strcmp(event.SelectionType, 'alt')
                
                obj.CurrentNode = currentNode;
                
                % Open context menu on current node.
                cMenuPos = obj.getPositionForContextMenu(event.Position);
                obj.openContextMenu(currentNode, cMenuPos)
                
            elseif event.NumClicks == 2 && ~strcmp(event.SelectionType, 'alt')
                
                % Todo: make a preview / open data method...
                
                %setIdle = obj.setBusy('Opening File...'); %#ok<NASGU>

                [~, ~, fileExt] = fileparts(currentNode.Name);

                switch fileExt
                    
                    case '' % Assume folder
                        folderPath = currentNode.UserData.filePath;
                        if isfolder(folderPath)
                            utility.system.openFolder(folderPath)
                        end
                    case {'.ini', '.tif', '.avi', '.raw'}
                        imviewer(currentNode.UserData.filePath)
                        
                    case '.mat'
                        if ismac
                            [status, ~] = unix(sprintf('open -a finder ''%s''', currentNode.UserData.filePath));
                        else
                            uiopen(currentNode.UserData.filePath)    
                        end
                        
                    case '.png'
                        if ismac
                            filepath = strrep(currentNode.UserData.filePath, ' ', '\ ');
                            [status, msg] = unix(sprintf('open -a Preview %s', filepath));
                        else
                            error('Can not open this file type')
                        end
                        
                    case '.nwb'
                        if isfield(currentNode.UserData, 'nwbNode')
                            disp(currentNode.UserData.nwbNode)
                        end
                        
                        
                    otherwise
                        if isfile(currentNode.UserData.filePath)
                            errorMsg = 'Can not open this file type';
                            errordlg(errorMsg)
                            error(errorMsg)
                            
                        elseif isempty(currentNode.UserData.filePath)
                            if isfield(currentNode.UserData, 'Type') && ...
                                    strcmp(currentNode.UserData.Type, 'nwb') && ...
                                    ~isempty(currentNode.UserData.nwbNode)
 
                                name = currentNode.Name;
                                name = currentNode.UserData.nwbNodeName;
                                nwbObj = currentNode.UserData.nwbNode;
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
            yScroll = obj.jVerticalScroller.getValue();
            y = pixelPos(4) - (mouseEventPos(2) - yScroll);
                
            pos = [x, y];
            
        end
        
        function openContextMenu(obj, treeNode, cMenuPosition)
        %openContextMenu Open contextmenu for a node on the Tree
                           
        % Open context menu. Select correct contextmenu based on whether 
        % node represents a file or an NWB dataset.
        
            if nargin < 3
                
            end
        
            if isfield(obj.CurrentNode.UserData, 'Type') && ...
                    strcmp(obj.CurrentNode.UserData.Type, 'nwb')

                if isfield(obj.CurrentNode.UserData, 'nwbNode')
                    obj.nwbContextMenu.Position = cMenuPosition;
                    obj.nwbContextMenu.Visible = 'on';
                end
            else
                obj.hContextMenu.Position = cMenuPosition;
                obj.hContextMenu.Visible = 'on';
            end
            
        end
        
        function m = createTreeItemContextMenu(obj)
        %createTreeItemContextMenu Create contextmenu for uitree  
        %
        %   
        
        %   Note: This contextmenu is not assigned to a specific uitree
        %   because it will be reused across uitrees.
            
            hFig = ancestor(obj.Parent, 'figure');
            m = uicontextmenu(hFig);
            
            mitem = uimenu(m, 'Text', 'Refresh');
            mitem.Callback = @(s, e) obj.onTreeItemContextMenuSelected(s);
            
            appName = utility.system.getOsDependentName('Finder');
            mitem = uimenu(m, 'Text', sprintf('Show In %s', appName));
            mitem.Callback = @(s, e) obj.onTreeItemContextMenuSelected(s);
            
            mitem = uimenu(m, 'Text', 'Create New Variable from File', 'Separator', 'on');
            mitem.Callback = @(s, e) obj.onCreateVariableMenuItemClicked();
            
            mitem = uimenu(m, 'Text', 'Load Data to Workspace', 'Separator', 'on');
            mitem.Callback = @(s, e) obj.onTreeItemContextMenuSelected(s);
            
            mitem = uimenu(m, 'Text', 'Plot Data in Timeseries Plotter');
            mitem.Callback = @(s, e) obj.onTreeItemContextMenuSelected(s);

        end
        
        function m = createNwbItemContextMenu(obj)
        %createNwbItemContextMenu Create context menu for NWB nodes
        
            hFig = ancestor(obj.Parent, 'figure');
            m = uicontextmenu(hFig);
            
            mitem = uimenu(m, 'Text', 'Preview');
            mitem.Callback = @(s, e) obj.onTreeItemContextMenuSelected(s);
            
            mitem = uimenu(m, 'Text', 'Assign to Workspace');
            mitem.Callback = @(s, e) obj.onTreeItemContextMenuSelected(s);

        end
        
        function onTreeItemContextMenuSelected(obj, src)
        %onTreeItemContextMenuSelected Callback for contect menu items
        
            nodeHandle = obj.CurrentNode;
            
            switch src.Text
                
                case 'Refresh'
                    % Refresh tree if the tab is dirty...
                    obj.createFolderTreeControl()
                
                case {'Show In Finder', 'Show In Explorer'}
                    folderPath = fileparts(nodeHandle.UserData.filePath);
                    utility.system.openFolder(folderPath)
                    
                case 'Load Data to Workspace'
                    % Todo: Use the sessionObject loadData and fileAdapters
                    
                    [~, ~, fileExt] = fileparts(nodeHandle.UserData.filePath);

                    switch fileExt

                        case {'.ini', '.tif', '.avi', '.raw'}
                            imageStack = nansen.stack.ImageStack(nodeHandle.UserData.filePath);
                            assignin('base', 'imageStack', imageStack)
                            
                        case '.mat'
                            S = load(nodeHandle.UserData.filePath);
                            varNames = fieldnames(S);
                            for i = 1:numel(varNames)
                                assignin('base', varNames{i}, S.(varNames{i}))
                            end
                            
                        otherwise 
                            errordlg('Can not load files of type %s to workspace', fileExt)
                            
                    end


                    
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
            fileAdapterList = VariableModel.listFileAdapters(ext);
            
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
            
            VM = VariableModel();
            VM.insertItem(varItem)
            
            % Todo: Display error message if variable already exists.
            % And/or ask if variable should be replaced?
            
        end
        
        function onParentSizeChanged(obj, src, evt)
                      
            uim.utility.layout.centerObjectInRectangle(obj.hBackgroundLabel, ...
                getpixelposition(obj.Parent))
            
        end
    end
    
end