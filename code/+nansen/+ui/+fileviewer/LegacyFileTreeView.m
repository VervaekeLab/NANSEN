classdef LegacyFileTreeView < handle
%LegacyFileTreeView Adapter for the Java-backed uiw.widget.FileTree.

    methods
        function tree = createTree(~, parent, callbacks)
            warnCleanup = nansen.ui.legacy.tempDisableJavaComponentWarning(); %#ok<NASGU>

            tree = uiw.widget.FileTree('Parent', parent);
            tree.FontName = 'Avenir New';
            tree.FontSize = 8;
            tree.Position = [0.2, 0, 0.8, 1];

            if ismac
                color = javax.swing.UIManager.get('Focus.color');
                rgb = cellfun(@(name) get(color, name), ...
                    {'Red', 'Green', 'Blue'});
            else
                rgb = [0, 0, 200];
            end
            tree.SelectionBackgroundColor = rgb ./ 255;

            tree.MouseClickedCallback = callbacks.MouseClickedFcn;
            tree.KeyPressFcn = callbacks.KeyPressFcn;

            jObj = tree.getJavaObjects();
            javaTree = jObj.JControl;
            javaTree.setToggleClickCount(0);
        end

        function rootNode = getRoot(~, tree)
            rootNode = tree.Root;
        end

        function node = addNode(~, parentNode)
            node = uiw.widget.FileTreeNode('Parent', parentNode);
        end

        function setNodeText(~, node, text)
            node.Name = char(text);
        end

        function text = getNodeText(~, node)
            text = node.Name;
        end

        function setNodeIcon(~, node, iconPath)
            setIcon(node, iconPath);
        end

        function setNodeContextMenu(~, ~, ~)
            % Legacy FileTree context menus are opened manually from the
            % mouse-click callback because the Java widget reports mouse
            % position and selected node through uiw events.
        end

        function deleteChildren(~, node)
            delete(node.Children)
        end

        function setSelectedNode(~, tree, node)
            if isempty(node)
                tree.SelectedNodes = [];
            else
                tree.SelectedNodes = node;
            end
        end

        function setVisible(~, tree, value)
            tree.Visible = value;
        end

        function expandNode(~, node)
            node.expand()
        end

        function tf = isExpanded(~, tree, node)
            warnState = warning('off', 'MATLAB:structOnObject');
            cleanup = onCleanup(@() warning(warnState));
            nodeStruct = struct(node);
            tf = tree.getJavaObjects().JControl.isExpanded(nodeStruct.JNode.TreePath);
        end

        function scroller = getVerticalScroller(~, tree)
            scroller = tree.getJavaObjects().JScrollPane.getVerticalScrollBar();
        end

        function javaTree = getJavaTree(~, tree)
            javaTree = tree.getJavaObjects().JControl;
        end

        function tf = usesAutomaticContextMenus(~)
            tf = false;
        end
    end
end
