classdef FileTree < uiw.abstract.JavaControl
    % Tree - A rich tree control
    %
    % Create a rich tree control based on Java JTree
    %
    % Syntax:
    %   nObj = uiw.widget.FileTree('Property','Value',...)
    %
    
%   Copyright 2012-2019 The MathWorks Inc.
    %
    % Auth/Revision:
    %   MathWorks Consulting
    %   $Author: rjackey $
    %   $Revision: 324 $  $Date: 2019-04-23 08:05:17 -0400 (Tue, 23 Apr 2019) $
    % ---------------------------------------------------------------------
    
    % Modified by EH to prevent mousemotion event to cause gui lags on
    % complex trees.
    
    %% Properties
    properties (AbortSet, Dependent)
        DndEnabled %controls whether drag and drop is enabled on the tree
        %Editable %controls whether the tree node text is editable
        RootVisible %whether the root is visible or not
        SelectedNodes %tree nodes that are currently selected
        SelectionType %selection mode ('single','contiguous','discontiguous')
    end
    
    properties (AbortSet)
        MouseClickedCallback %callback when the mouse is clicked on the tree
        MouseMotionFcn %callback while the mouse is being moved over the tree
        NodeDraggedCallback %callback for a node being dragged. A custom callback should return a logical true when the node being dragged over is a valid drop target.
        NodeDroppedCallback %callback for a node being dropped. A custom callback should handle the data transfer. If not specified, dragging and dropping nodes just modifies the parent of the nodes that were dragged and dropped.
        NodeExpandedCallback %callback for a node being expanded
        NodeCollapsedCallback %callback for a node being collapsed
        NodeEditedCallback %callback for a node being edited
        SelectionChangeFcn %callback for change in tree node selection
    end
    
    properties (SetAccess=protected)
        Root %the root tree node (uiw.widget.FileTreeNode or uiw.widget.CheckboxTreeNode)
    end
    
    properties (AbortSet)
        TreeBackgroundColor = [1 1 1] %Background color of the tree area
        TreePaneBackgroundColor = [1 1 1] %Background color of the full pane
        SelectionForegroundColor = [0 0 0] %Foreground color of the selection in the tree
        SelectionBackgroundColor = [.2 .6 1] %Background color of the selection in the tree
    end
    
    %% Internal properties
    properties (SetAccess=protected, GetAccess=protected)
        JModel %Java model for tree (internal)
        JSelModel %Java tree selection model (internal)
        JDropTarget %Java drop target (internal)
        JTransferHandler %Java transfer handler for DND (internal)
        JCellRenderer %Java cell renderer (internal)
        IsBeingDeleted = false; %true when the destructor is active (internal)
    end
    
    %% Deprecated properties
    properties (Hidden)
        KeyPressedCallback %callback for a key pressed event
    end
    
    %% Constructor / Destructor
    methods
        
        function obj = FileTree(varargin)
            % Construct the control
            
            % Create the base graphics
            obj.create();
            
            % Set properties from P-V pairs
            obj.assignPVPairs(varargin{:});
            
            % Assign the construction flag
            obj.IsConstructed = true;
            obj.CallbacksEnabled = true;
            
            % Redraw the widget
            obj.onResized();
            obj.onEnableChanged();
            obj.onStyleChanged();
            obj.redraw();
            
        end % constructor
        
        function delete(obj)
            obj.IsBeingDeleted = true;
            obj.CallbacksEnabled = false;
            delete(obj.Root);
        end % destructor
        
    end %methods - constructor/destructor
    
    %% Public Methods
    methods
        function collapseNode(obj,nObj)
            % collapseNode - Collapse a TreeNode within the tree
            % -------------------------------------------------------------------------
            % Abstract: Collapse the specified tree node
            %
            % Syntax:
            %           obj.collapseNode(nObj)
            %
            % Inputs:
            %           obj - Tree object
            %           nObj - TreeNode object
            %
            % Outputs:
            %           none
            %
            
            obj.CallbacksEnabled = false;
            collapsePath(obj.JControl, nObj.JNode.getTreePath());
            obj.CallbacksEnabled = true;
            
        end %function
        
        function expandNode(obj,nObj)
            % expandNode - Expand a TreeNode within the tree
            % -------------------------------------------------------------------------
            % Abstract: Expand the specified tree node
            %
            % Syntax:
            %           obj.expandNode(nObj)
            %
            % Inputs:
            %           obj - Tree object
            %           nObj - TreeNode object
            %
            % Outputs:
            %           none
            %
            
            obj.CallbacksEnabled = false;
            expandPath(obj.JControl, nObj.JNode.getTreePath());
            obj.CallbacksEnabled = true;
            
        end %function
        
        function s = getJavaObjects(obj)
            % Return the Java objects of the tree (for debugging only)
            
            s = struct(...
                'JControl',obj.JControl,...
                'JModel',obj.JModel,...
                'JSelModel',obj.JSelModel,...
                'JScrollPane',obj.JScrollPane,...
                'JDropTarget',obj.JDropTarget,...
                'JTransferHandler',obj.JTransferHandler,...
                'HGJContainer',obj.HGJContainer);
            
        end %function
        
        function [str,data] = onCopy(obj)
            % Get the currently selected data, useful for implementing Copy
            % in an application.
            
            data = [obj.SelectedNodes];
            str = strjoin({obj.SelectedNodes.Name},', ');
            
        end %function
        
        function [str,data] = onCut(obj)
            % Cut the currently selected data from the tree, useful for
            % implementing Cut in an application.
            
            data = [obj.SelectedNodes];
            str = strjoin({obj.SelectedNodes.Name},', ');
            obj.SelectedNodes.Parent = [];
            
        end %function
        
    end %methods
    
    %% Protected Methods
    methods (Access=protected)
        
        function create(obj)
            % Create the graphics objects
            
            % Create the root node (unless subclass already did)
            if isempty(obj.Root)
                obj.Root = uiw.widget.FileTreeNode('Name','Root');
                obj.Root.Tree = obj;
            end
            
            % Create the tree on a scroll pane (unless subclass already
            % did)
            if isempty(obj.JControl)
                obj.createScrollPaneJControl('javax.swing.JTree',obj.Root.JNode);
            end
            
            % Store the model
            obj.JModel = obj.JControl.getModel();
            javaObjectEDT(obj.JModel); % Put it on the EDT
            
            % Store the selection model
            obj.JSelModel = obj.JControl.getSelectionModel();
            javaObjectEDT(obj.JSelModel); % Put it on the EDT
            
            % Set defaults
            obj.SelectionType = 'single'; % Single selection
            obj.JControl.setRowHeight(-1); % Auto row height (for font changes)
            
            % Set the java tree callbacks
            CbProps = handle(obj.JControl,'CallbackProperties');
            %set(CbProps,'KeyPressedCallback',@(src,e)onKeyPressed(obj,e))
            set(CbProps,'MouseClickedCallback',@(src,e)onMouseEvent(obj,e))
            set(CbProps,'MousePressedCallback',@(src,e)onMouseEvent(obj,e))
            set(CbProps,'TreeWillExpandCallback',@(src,e)onExpand(obj,e))
            set(CbProps,'TreeCollapsedCallback',@(src,e)onCollapse(obj,e))
            set(CbProps,'MouseMovedCallback',@(src,e)onMouseEvent(obj,e))
            set(CbProps,'ValueChangedCallback',@(src,e)onNodeSelection(obj,e))
            
            % Set up editability callback
            CbProps = handle(obj.JModel,'CallbackProperties');
            set(CbProps,'TreeNodesChangedCallback',@(src,e)onNodeEdit(obj,e))
            
            % Set up drag and drop
            obj.JDropTarget = obj.constructJObj('java.awt.dnd.DropTarget');
            obj.JControl.setDropTarget(obj.JDropTarget);
            obj.JTransferHandler = obj.constructJObj(...
                'com.mathworks.consulting.widgets.tree.TreeTransferHandler');
            obj.JControl.setTransferHandler(obj.JTransferHandler);
            
            % Set up drop target callbacks
            CbProps = handle(obj.JDropTarget,'CallbackProperties');
            set(CbProps,'DropCallback',@(src,e)onNodeDND(obj,e));
            set(CbProps,'DragOverCallback',@(src,e)onNodeDND(obj,e));
            
            % Allow tooltips
            JTTipMgr = javaMethodEDT('sharedInstance','javax.swing.ToolTipManager');
            JTTipMgr.registerComponent(obj.JControl);
            
            % Use the custom renderer
            obj.JCellRenderer = obj.constructJObj(...
                'com.mathworks.consulting.widgets.tree.TreeCellRenderer');
            setCellRenderer(obj.JControl, obj.JCellRenderer);
            
            % Add properties to the java object for MATLAB data
            hTree = handle(obj.JControl);
            schema.prop(hTree,'Tree','MATLAB array');
            schema.prop(hTree,'UserData','MATLAB array');
            
            % Add a reference to this object
            hTree.Tree = obj;
            
            % Refresh the tree
            reload(obj, obj.Root);
            
        end
        
        function onStyleChanged(obj,~)
            % Handle updates to style changes
            
            % Ensure the construction is complete
            if obj.IsConstructed
                
                % Call superclass methods
                onStyleChanged@uiw.abstract.JavaControl(obj);
                
                % Set the background
                jColor = obj.rgbToJavaColor(obj.TreeBackgroundColor);
                obj.JControl.setBackground(jColor);
                
                jColor = obj.rgbToJavaColor(obj.TreePaneBackgroundColor);
                obj.JCellRenderer.setBackgroundNonSelectionColor(jColor);
                
                jColor = obj.rgbToJavaColor(obj.ForegroundColor);
                obj.JCellRenderer.setTextNonSelectionColor(jColor);
                
                jColor = obj.rgbToJavaColor(obj.SelectionForegroundColor);
                obj.JCellRenderer.setTextSelectionColor(jColor);
                
                jColor = obj.rgbToJavaColor(obj.SelectionBackgroundColor);
                obj.JCellRenderer.setBackgroundSelectionColor(jColor);
                
                obj.JControl.repaint();
                
            end %if obj.IsConstructed
        end %function
        
        function onKeyPressed(obj,jEvent)
            % Triggered when any button is pressed in the keyboard
            
            % Call superclass method
            obj.onKeyPressed@uiw.abstract.JavaControl(jEvent);
            
            % Deprecated functionality (KeyPressedCallback)
            if ~isempty(obj.KeyPressedCallback)
                keyCode = jEvent.getKeyCode;
                e1 = struct('KeyPressed',keyCode,'SelectedNodes',obj.SelectedNodes);
                hgfeval(obj.KeyPressedCallback,obj,e1);
            end %if ~isempty(obj.KeyPressedCallback)
            
        end %function onKeyPressed
        
    end %methods
    
    %% Special Access Methods
    methods (Access={?uiw.widget.FileTree, ?uiw.widget.FileTreeNode})
        
        function reload(obj,nObj)
            % Reload the specified tree node
            
            if ~isempty([obj.JModel]) && ishandle(nObj.JNode)
                obj.CallbacksEnabled = false;
                obj.JModel.reload(nObj.JNode);
                obj.CallbacksEnabled = true;
            end
            
        end %function
        
        function nodeChanged(obj,nObj)
            % Triggered on node changes from Java
            
            if ~isempty([obj.JModel]) && ishandle(nObj.JNode)
                obj.CallbacksEnabled = false;
                obj.JModel.nodeChanged(nObj.JNode);
                obj.CallbacksEnabled = true;
            end
            
        end %function
        
        function insertNode(obj,nObj,pObj,idx)
            % Insert a node at the specified location
            
            obj.CallbacksEnabled = false;
            
            % Insert this node
            obj.JModel.insertNodeInto(nObj.JNode, pObj.JNode, idx-1);
            
            % Insert any children
            insertChildren(nObj)
            
            % If this is the first and only child, we need to reload the
            % tree node so it renders correctly
            if all(pObj.Children == nObj)
                obj.JModel.reload(pObj.JNode);
            end
            
            obj.CallbacksEnabled = true;
            
            function insertChildren(nObj)
                % Recursively add children to the tree
                
                for cIdx = 1:numel(nObj.Children)
                    obj.JModel.insertNodeInto(...
                        nObj.Children(cIdx).JNode,...
                        nObj.JNode,...
                        cIdx-1);
                    
                    if ~isempty(nObj.Children(cIdx).Children)
                        insertChildren(nObj.Children(cIdx));
                    end
                end
                
            end %function insertChildren(nObj)
            
        end %function
        
        function removeNode(obj,nObj,~)
            % Remove the specified node
            
            if ~isempty([obj.JModel]) && ishandle(nObj.JNode)
                obj.CallbacksEnabled = false;
                obj.JModel.removeNodeFromParent(nObj.JNode);
                % If all children were removed, reload the node
                %if isempty(pObj.Children) && ~isempty(pObj.Tree)
                %    obj.JModel.reload(pObj.JNode);
                %end
                obj.CallbacksEnabled = true;
            end
            
        end %function
        
    end %special access methods
    
    %% Private Methods
    methods (Access=private)
        
        function nObj = getNodeFromMouseEvent(obj,jEvent)
            % Retrieve the tree node from a mouse event from Java
            
            % Was a tree node clicked?
            treePath = obj.JControl.getPathForLocation(jEvent.getX, jEvent.getY);
            if isempty(treePath)
                nObj  = uiw.widget.FileTreeNode.empty(0,1);
            else
                nObj = get(treePath.getLastPathComponent,'TreeNode');
            end
            
        end %function
        
        function onExpand(obj,e)
            % Triggered when a node is expanded
            
            % Is there a custom NodeExpandedCallback?
            if obj.isvalid() && obj.CallbacksEnabled && ~isempty(obj.NodeExpandedCallback)
                
                % Get the tree node that was expanded
                CurrentNode = get(e.getPath.getLastPathComponent,'TreeNode');
                
                % Call the custom callback
                e1 = struct('Nodes',CurrentNode);
                hgfeval(obj.NodeExpandedCallback,obj,e1);
                
            end %if ~isempty(obj.NodeExpandedCallback)
            
        end %function onExpand
        
        function onCollapse(obj,e)
            % Triggered when a node is collapsed
            
            % Is there a custom NodeCollapsedCallback?
            if obj.isvalid() && obj.CallbacksEnabled && ~isempty(obj.NodeCollapsedCallback)
                
                % Get the tree node that was collapsed
                CurrentNode = get(e.getPath.getLastPathComponent,'TreeNode');
                
                % Call the custom callback
                e1 = struct('Nodes',CurrentNode);
                hgfeval(obj.NodeCollapsedCallback,obj,e1);
                
            end %if ~isempty(obj.NodeCollapsedCallback)
            
        end %function onCollapse
        
        function onMouseEvent(obj,jEvent)
            % Triggered when the mouse is clicked within the pane
            
            persistent counter
            if isempty(counter); counter = 0; end
            
            if obj.isvalid() && obj.CallbacksEnabled
                
                % Decrease the update rate for mousemotion events for this
                % tree because the below code is too heavy for the fast
                % updates on complex trees.
                counter = counter + 1;
                if mod(counter, 10) == 0
                    counter = 0; % Reset counter
                else
                    jEventId = get( jEvent, 'ID' );
                    if jEventId == 503; return; end
                end
                
                % Get mouse event data
                mEvent = obj.getMouseEventData(jEvent);
                
                % Add Tree-specific mouse event data
                addprop(mEvent,'Nodes');
                mEvent.Nodes = getNodeFromMouseEvent(obj,jEvent);
                
                % Trigger the appropriate callback and notify
                switch mEvent.Interaction
                    case 'ButtonClicked'
                        
                        hgfeval(obj.MouseClickedCallback,obj,mEvent)
                        
                        % Launch context menu in certain cases
                        if mEvent.SelectionType == "alt" && ~(mEvent.ControlOn && mEvent.Button==1)
                            
                            % If the node was not previously selected, do it
                            if ~isempty(mEvent.Nodes) && ...
                                    ~any(obj.SelectedNodes == mEvent.Nodes)
                                % Call right to Java, so we trigger node
                                % selection callback in this unique case
                                if mEvent.ControlOn
                                    obj.JControl.addSelectionPath(mEvent.Nodes.JNode.getTreePath());
                                else
                                    obj.JControl.setSelectionPath(mEvent.Nodes.JNode.getTreePath());
                                end
                            end
                            
                            % Default to the standard context menu
                            cMenu = obj.UIContextMenu;
                            
                            % Is there a node-specific context menu?
                            if ~isempty(mEvent.Nodes)
                                
                                % Get the custom context menus for selected nodes
                                NodeCMenus = [obj.SelectedNodes.UIContextMenu];
                                
                                % See if there is a common context menu
                                ThisCMenu = unique(NodeCMenus);
                                
                                % Is there a common context menu across all
                                % selected nodes?
                                if ~isempty(NodeCMenus) &&...
                                        numel(NodeCMenus) == numel(obj.SelectedNodes) &&...
                                        all(NodeCMenus(1) == NodeCMenus)
                                    
                                    % Use the custom context menu
                                    cMenu = ThisCMenu;
                                end
                                
                            end %if ~isempty(evt.Nodes)
                            
                            % Launch the context menu
                            obj.showContextMenu(cMenu)
                            
                        %elseif isempty(mEvent.Nodes) && ~mEvent.ControlOn && ~mEvent.ShiftOn
                            % Click in white space - deselect everything
                            
                        %    obj.JControl.setSelectionPath([]);
                            
                        end %if mEvent.SelectionType == "alt" && ~mEvent.ControlOn
                        
                    case 'ButtonDown'
                        
                        obj.notify('ButtonDown',mEvent);
                        
                    case 'ButtonUp'
                        % Do nothing - no callback defined
                        
                    case 'ButtonMotion'
                        
                        obj.notify('MouseMotion',mEvent);
                        
                    case 'ButtonDrag'
                        %RAJ - currently not called as we have a separate
                        %method onNodeDND
                        obj.notify('MouseDrag',mEvent);
                        
                end %switch evt.Interaction
                
            end %if obj.isvalid() && obj.CallbacksEnabled
            
        end %function onMouseEvent
        
        function onMouseMotion(obj,jEvent)
            % Triggered when the mouse moves within the pane
            
            % Only do this if there is a custom MouseMotionFcn
            if obj.isvalid() && obj.CallbacksEnabled && ~isempty(obj.MouseMotionFcn)
                
                obj.onMouseEvent(jEvent);
                
            end %if ~isempty(obj.MouseMotionFcn)
            
        end %function onMouseMotion
        
        function onNodeSelection(obj,e)
            % Triggered when the selection of tree paths (nodes) changes
            
            % Has the constructor completed running?
            % Has a treeCallback been specified?
            
            %RAJ - tried a few things here to enable right-clicks for
            %context to call this first to select the node first. It will
            %result in callback firing when programmatically changing nodes
            %though.
            
            %if obj.isvalid() && ~isempty(obj.SelectionChangeFcn)
            if obj.isvalid() && obj.CallbacksEnabled && ~isempty(obj.SelectionChangeFcn)
                
                % Figure out what nodes were added or removed to/from the
                % selection
                p = e.getPaths;
                AddedNodes = uiw.widget.FileTreeNode.empty(0,1);
                RemovedNodes = uiw.widget.FileTreeNode.empty(0,1);
                for idx = 1:numel(p)
                    nObj = get(p(idx).getLastPathComponent(),'TreeNode');
                    if isvalid(nObj)
                        if e.isAddedPath(idx-1) %zero-based index
                            AddedNodes(end+1) = nObj; %#ok<AGROW>
                        else
                            RemovedNodes(end+1) = nObj; %#ok<AGROW>
                        end
                    end
                end
                
                % Prepare eventdata for the callback
                e1 = struct(...
                    'Nodes', obj.SelectedNodes,...
                    'AddedNodes',AddedNodes,...
                    'RemovedNodes',RemovedNodes);
                
                % Call the treeCallback
                hgfeval(obj.SelectionChangeFcn,obj,e1);
            end
            
        end %function onNodeSelection
        
        function onNodeEdit(obj,e)
            % Triggered when a node is edited
            
            % Is there a custom NodeEditedCallback?
            if obj.isvalid() && obj.CallbacksEnabled && ~isempty(obj.NodeEditedCallback)
                
                % Get the tree nodes that were edited
                c = e.getChildren;
                EditedNode = uiw.widget.FileTreeNode.empty(0,1);
                for idx = 1:numel(c)
                    EditedNode = get(c(idx),'TreeNode');
                end
                
                % Get the parent node of the edit
                ParentNode = get(e.getTreePath.getLastPathComponent,'TreeNode');
                
                % Call the custom callback
                e1 = struct(...
                    'Nodes',EditedNode,...
                    'ParentNode',ParentNode);
                hgfeval(obj.NodeEditedCallback,obj,e1);
                
            end %if ~isempty(obj.NodeEditedCallback)
            
        end %function onNodeEdit
        
        function onNodeDND(obj,e)
            % Triggered when a node is dragged or dropped on the tree
            
            % The Transferable object is available only during drag
            persistent Transferable
            
            if obj.isvalid() && obj.CallbacksEnabled
                
                try %#ok<TRYNC>
                    % The Transferable object is available only during drag
                    Transferable = e.getTransferable;
                    javaObjectEDT(Transferable); % Put it on the EDT
                end
                
                % Catch errors if unsupported items are dragged onto the
                % tree
                try
                    DataFlavors = Transferable.getTransferDataFlavors;
                    TransferData = Transferable.getTransferData(DataFlavors(1));
                catch %#ok<CTCH>
                    TransferData = [];
                end
                
                % Get the source node(s)
                SourceNode = uiw.widget.FileTreeNode.empty(0,1);
                for idx = 1:numel(TransferData)
                    SourceNode(idx) = get(TransferData(idx),'TreeNode');
                end
                
                % Filter descendant source nodes. If dragged nodes are
                % descendants of other dragged nodes, they should be
                % excluded so the hierarchy is maintained.
                idxRemove = isDescendant(SourceNode,SourceNode);
                SourceNode(idxRemove) = [];
                
                % Get the target node
                Loc = e.getLocation();
                treePath = obj.JControl.getPathForLocation(...
                    Loc.getX + obj.JScrollPane.getHorizontalScrollBar().getValue(), Loc.getY + obj.JScrollPane.getVerticalScrollBar().getValue());
                if isempty(treePath)
                    % If no target node, the target is the background of
                    % the tree. Assume the root is the intended target.
                    TargetNode = obj.Root;
                else
                    TargetNode = get(treePath.getLastPathComponent,'TreeNode');
                end
                
                % Get the operation type
                switch e.getDropAction()
                    case 0
                        DropAction = 'link';
                    case 1
                        DropAction = 'copy';
                    case 2
                        DropAction = 'move';
                    otherwise
                        DropAction = '';
                end
                
                % Create event data for user callback
                e1 = struct(...
                    'Source',SourceNode,...
                    'Target',TargetNode,...
                    'DropAction',DropAction);
                % Check if the source/target are valid
                % Check the node is not dropped onto itself
                % Check a node may not be dropped onto a descendant
                TargetOk = ~isempty(TargetNode) &&...
                    ~isempty(SourceNode) && ...
                    ~any(SourceNode==TargetNode) && ...
                    ~any(isDescendant(SourceNode,TargetNode));
                
                % A move operation may not drop a node onto its parent
                if TargetOk && strcmp(DropAction,'move')
                    TargetOk = ~any([SourceNode.Parent]==TargetNode);
                end
                
                % Is this the drag or the drop event?
                if e.isa('java.awt.dnd.DropTargetDragEvent')
                    %%%%%%%%%%%%%%%%%%%
                    % Drag Event
                    %%%%%%%%%%%%%%%%%%%
                    
                    % Is there a custom NodeDraggedCallback to call?
                    if TargetOk && ~isempty(obj.NodeDraggedCallback)
                        TargetOk = hgfeval(obj.NodeDraggedCallback,obj,e1);
                    end
                    
                    % Is this a valid target?
                    if TargetOk
                        e.acceptDrag(e.getDropAction);
                    else
                        e.rejectDrag();
                    end
                    
                elseif e.isa('java.awt.dnd.DropTargetDropEvent')
                    %%%%%%%%%%%%%%%%%%%
                    % Drop Event
                    %%%%%%%%%%%%%%%%%%%
                    
                    % Is there a custom NodeDraggedCallback to call?
                    if TargetOk && ~isempty(obj.NodeDraggedCallback)
                        TargetOk = hgfeval(obj.NodeDraggedCallback,obj,e1);
                    end
                    
                    % Should we process the drop?
                    if TargetOk
                        
                        % Is there a custom NodeDroppedCallback to call?
                        if ~isempty(obj.NodeDroppedCallback)
                            hgfeval(obj.NodeDroppedCallback,obj,e1);
                        else
                            % Just move the node to the new destination, and expand
                            switch DropAction
                                case 'copy'
                                    NewSourceNode = copy(SourceNode,TargetNode);
                                    expand(TargetNode)
                                    expand(SourceNode)
                                    expand(NewSourceNode)
                                case 'move'
                                    set(SourceNode,'Parent',TargetNode)
                                    expand(TargetNode)
                                    expand(SourceNode)
                                otherwise
                                    % Do nothing
                            end
                        end
                    end
                    
                    % Tell Java the drop is complete
                    e.dropComplete(true)
                    
                end
                
            end %if obj.isvalid() && obj.CallbacksEnabled
            
        end %function onNodeDND
        
    end %methods
    
    %% Get/Set methods
    methods
        
        % DndEnabled
        function value = get.DndEnabled(obj)
            value = obj.JControl.getDragEnabled();
        end
        function set.DndEnabled(obj,value)
            if ischar(value) || ( isscalar(value) && isstring(value) )
                value = strcmp(value,'on');
            end
            validateattributes(value,{'numeric','logical'},{'scalar'});
            obj.JControl.setDragEnabled(logical(value));
        end
        
        % Editable
        % function value = get.Editable(obj)
        %     value = get(obj.JControl,'Editable');
        % end
        % function set.Editable(obj,value)
        %     validateattributes(value,{'numeric','logical'},{'scalar'});
        %     obj.JControl.setEditable(logical(value));
        % end
        
        % RootVisible
        function value = get.RootVisible(obj)
            value = get(obj.JControl,'rootVisible');
        end
        function set.RootVisible(obj,value)
            if ischar(value) || ( isscalar(value) && isstring(value) )
                value = strcmp(value,'on');
            end
            validateattributes(value,{'numeric','logical'},{'scalar'});
            value = logical(value);
            obj.JControl.setRootVisible(value); %show/hide root
            obj.JControl.setShowsRootHandles(~value); %hide/show top level handles
        end
        
        % SelectedNodes
        function value = get.SelectedNodes(obj)
            value = uiw.widget.FileTreeNode.empty(0,1);
            srcPaths = obj.JControl.getSelectionPaths();
            for idx = 1:numel(srcPaths)
                value(idx) = get(srcPaths(idx).getLastPathComponent,'TreeNode');
            end
        end
        function set.SelectedNodes(obj,value)
            obj.CallbacksEnabled = false;
            if isempty(value)
                if ~isempty(obj.JControl.getSelectionPath)
                    obj.JControl.setSelectionPath([])
                end
            elseif isa(value,'uiw.widget.FileTreeNode')
                if isscalar(value)
                    obj.JControl.setSelectionPath(value.JNode.getTreePath());
                else
                    for idx = numel(value):-1:1 %preallocate by reversing
                        path(idx) = value(idx).JNode.getTreePath();
                    end
                    obj.JControl.setSelectionPaths(path);
                end
            else
                error('Expected TreeNode or empty array');
            end
            obj.CallbacksEnabled = true;
        end
        
        % SelectionType
        function value = get.SelectionType(obj)
            value = obj.JSelModel.getSelectionMode();
            switch value
                case 1
                    value = 'single';
                case 2
                    value = 'contiguous';
                case 4
                    value = 'discontiguous';
            end
        end
        function set.SelectionType(obj,value)
            value = validatestring(value,{'single','contiguous','discontiguous'});
            switch value
                case 'single'
                    mode = obj.JSelModel.SINGLE_TREE_SELECTION;
                case 'contiguous'
                    mode = obj.JSelModel.CONTIGUOUS_TREE_SELECTION;
                case 'discontiguous'
                    mode = obj.JSelModel.DISCONTIGUOUS_TREE_SELECTION;
            end
            obj.CallbacksEnabled = false;
            obj.JSelModel.setSelectionMode(mode);
            obj.CallbacksEnabled = true;
        end
        
        % SelectionForegroundColor
        function set.SelectionForegroundColor(obj, value)
            value = uiw.utility.interpretColor(value);
            evt = struct(...
                'Source',obj,...
                'Property','SelectionForegroundColor',...
                'OldValue',obj.SelectionForegroundColor,...
                'NewValue',value);
            obj.SelectionForegroundColor = value;
            obj.onStyleChanged(evt);
        end
        
        % SelectionBackgroundColor
        function set.SelectionBackgroundColor(obj, value)
            value = uiw.utility.interpretColor(value);
            evt = struct(...
                'Source',obj,...
                'Property','SelectionBackgroundColor',...
                'OldValue',obj.SelectionBackgroundColor,...
                'NewValue',value);
            obj.SelectionBackgroundColor = value;
            obj.onStyleChanged(evt);
        end
        
        % TreeBackgroundColor
        function set.TreeBackgroundColor(obj, value)
            value = uiw.utility.interpretColor(value);
            evt = struct(...
                'Source',obj,...
                'Property','TreeBackgroundColor',...
                'OldValue',obj.TreeBackgroundColor,...
                'NewValue',value);
            obj.TreeBackgroundColor = value;
            obj.onStyleChanged(evt);
        end
        
        % TreePaneBackgroundColor
        function set.TreePaneBackgroundColor(obj, value)
            value = uiw.utility.interpretColor(value);
            evt = struct(...
                'Source',obj,...
                'Property','TreeBackgroundColor',...
                'OldValue',obj.TreePaneBackgroundColor,...
                'NewValue',value);
            obj.TreePaneBackgroundColor = value;
            obj.onStyleChanged(evt);
        end
        
    end %get/set methods
    
end %classdef
