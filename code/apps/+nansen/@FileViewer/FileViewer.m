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


%   Todo
%       [ ] Create refresh button...


    properties
        CurrentSessionObj
    end
    
    properties (SetAccess = private)
        Parent
        hFolderTree
        TabGroup
    end
    
    properties (Access = private, Hidden)
        IconFolderPath
        DataLocationTabs
        IsTabDirty
        IsInitialized = false
        
        CurrentNode
        hContextMenu
    end
    
    
    methods % Constructor
        
        function obj = FileViewer(varargin)
        %FileViewer Construct a fileviewer object
        
            % Take care of input arguments.
            obj.parseInputs(varargin)
            
            
            obj.setIconFolderPath()  
            
            % Initialize the context menu on construction. This will be 
            % reused across data locations and items in the uitree.
            obj.hContextMenu = obj.createTreeItemContextMenu();
            
        end

    end
    
    methods (Access = public)
        
        function update(obj, metaTableEntry)
        %update Update the uitree based on a session entry from a metatable
        %
        %   hFileviewer.update(sessionTableEntry)
        
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
            else
                W.Root.UserData.filePath = dirPath;
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
                        
                    otherwise
                        if isfile(currentNode.UserData.filePath)
                            errorMsg = 'Can not open this file type';
                            errordlg(errorMsg)
                            error(errorMsg)
                        else
                            % Do nothing (Double clicking on folders should
                            % expand the tree).
                        end
                end
                
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
            mitem = uimenu(m, 'Text', sprintf('Show In %s', appName), 'Separator', 'on');
            mitem.Callback = @(s, e) obj.onTreeItemContextMenuSelected(s);
            
            mitem = uimenu(m, 'Text', 'Load Variables to Workspace');
            mitem.Callback = @(s, e) obj.onTreeItemContextMenuSelected(s);
            
            
            mitem = uimenu(m, 'Text', 'Plot Variables in Timeseries Plotter');
            mitem.Callback = @(s, e) obj.onTreeItemContextMenuSelected(s);

        end
        
        function onTreeItemContextMenuSelected(obj, src)

            nodeHandle = obj.CurrentNode;
            
            switch src.Text
                
                case 'Refresh'
                    % Create tree if the tab is dirty...
                    obj.createFolderTreeControl()
                
                case {'Show In Finder', 'Show In Explorer'}
                    folderPath = fileparts(nodeHandle.UserData.filePath);
                    utility.system.openFolder(folderPath)
                    
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