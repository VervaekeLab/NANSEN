classdef ModernFileTreeView < handle
%ModernFileTreeView Adapter for uifigure-compatible uitree.

    methods
        function tree = createTree(obj, parent, callbacks)
            tree = uitree(parent);
            tree.Multiselect = 'off';
            tree.Position = [1, 1, 100, 100];
            tree.FontName = 'Avenir New';
            tree.FontSize = 14;
            tree.NodeExpandedFcn = @(src, event) onNodeExpanded(obj, src, event);
            tree.NodeCollapsedFcn = @(src, event) onNodeCollapsed(obj, src, event);
            tree.SelectionChangedFcn = callbacks.SelectionChangedFcn;
            tree.DoubleClickedFcn = callbacks.DoubleClickedFcn;
        end

        function rootNode = getRoot(obj, tree)
            userData = obj.getTreeUserData(tree);
            hasValidRootNode = isstruct(userData) ...
                && isfield(userData, 'RootNode') ...
                && ~isempty(userData.RootNode) ...
                && isvalid(userData.RootNode);

            if ~hasValidRootNode
                rootNode = uitreenode(tree, 'Text', '');
                userData.RootNode = rootNode;
                tree.UserData = userData;
            else
                rootNode = userData.RootNode;
            end
        end

        function node = addNode(~, parentNode)
            node = uitreenode(parentNode, 'Text', '');
        end

        function setNodeText(~, node, text)
            node.Text = char(text);
        end

        function text = getNodeText(~, node)
            text = node.Text;
        end

        function setNodeIcon(~, node, iconPath)
            if isfile(iconPath)
                node.Icon = iconPath;
            end
        end

        function setNodeContextMenu(~, node, contextMenu)
            node.ContextMenu = contextMenu;
        end

        function deleteChildren(~, node)
            delete(node.Children)
        end

        function setSelectedNode(~, tree, node)
            tree.SelectedNodes = node;
        end

        function setVisible(~, tree, value)
            tree.Visible = value;
        end

        function expandNode(obj, node)
            tree = ancestor(node, 'uitree');
            node.expand()
            obj.markNodeExpanded(tree, node)
        end

        function tf = isExpanded(obj, tree, node)
            userData = obj.getTreeUserData(tree);
            tf = obj.isTrackedExpandedNode(userData, node);
        end

        function scroller = getVerticalScroller(~, ~)
            scroller = [];
        end

        function javaTree = getJavaTree(~, ~)
            javaTree = [];
        end

        function tf = usesAutomaticContextMenus(~)
            tf = true;
        end
    end

    methods (Access = private)
        function onNodeExpanded(obj, src, event)
            obj.markNodeExpanded(src, event.Node)
        end

        function onNodeCollapsed(obj, src, event)
            obj.markNodeCollapsed(src, event.Node)
        end

        function markNodeExpanded(obj, tree, node)
            userData = obj.getTreeUserData(tree);
            if ~obj.isTrackedExpandedNode(userData, node)
                userData.ExpandedNodes{end+1} = node;
            end
            tree.UserData = userData;
        end

        function markNodeCollapsed(obj, tree, node)
            userData = obj.getTreeUserData(tree);
            isMatchingNode = cellfun(@(expandedNode) ...
                obj.isSameValidNode(expandedNode, node), userData.ExpandedNodes);
            userData.ExpandedNodes(isMatchingNode) = [];
            tree.UserData = userData;
        end

        function tf = isTrackedExpandedNode(obj, userData, node)
            if isempty(userData.ExpandedNodes)
                tf = false;
                return
            end

            validNodes = cellfun(@(expandedNode) ...
                obj.isSameValidNode(expandedNode, node), userData.ExpandedNodes);
            tf = any(validNodes);
        end

        function userData = getTreeUserData(~, tree)
            userData = tree.UserData;
            if ~isstruct(userData)
                userData = struct();
            end
            if ~isfield(userData, 'ExpandedNodes') ...
                    || ~iscell(userData.ExpandedNodes)
                userData.ExpandedNodes = {};
            else
                userData.ExpandedNodes = userData.ExpandedNodes( ...
                    cellfun(@(node) ~isempty(node) && isvalid(node), ...
                    userData.ExpandedNodes));
            end
            tree.UserData = userData;
        end

        function tf = isSameValidNode(~, nodeA, nodeB)
            tf = ~isempty(nodeA) && ~isempty(nodeB) ...
                && isvalid(nodeA) && isvalid(nodeB) ...
                && isequal(nodeA, nodeB);
        end
    end
end
