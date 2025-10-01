classdef MenuCustomizationDialog < handle
    % MenuCustomizationDialog - Dialog for customizing menu visibility
    %
    %   This dialog allows users to select which menu items should be
    %   visible in the NANSEN application interface, with support for
    %   both user-level and project-level preferences.
    
    properties (Access = private)
        App % Reference to main NANSEN app
        Figure matlab.ui.Figure
        Tree matlab.ui.container.CheckBoxTree
        ScopeButtonGroup matlab.ui.container.ButtonGroup
        UserButton matlab.ui.control.RadioButton
        ProjectButton matlab.ui.control.RadioButton
        CancelButton matlab.ui.control.Button
        ResetButton matlab.ui.control.Button
        
        MenuTags cell % All available menu tags
        TreeNodes containers.Map % Map of tag -> tree node
        CurrentScope char = 'user' % 'user' or 'project'
    end
    
    methods
        function obj = MenuCustomizationDialog(app)
            % Constructor
            %
            %   dialog = MenuCustomizationDialog(app)
            %
            %   Inputs:
            %       app - Reference to main NANSEN App instance
            
            obj.App = app;
            obj.createUI();
            obj.loadMenuStructure();
            obj.updateTreeSelection();
        end
        
        function show(obj)
            % Show the dialog
            obj.Figure.Visible = 'on';
            focus(obj.Figure);
        end
        
        function delete(obj)
            % Destructor
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                delete(obj.Figure);
            end
        end
    end
    
    methods (Access = private)
        function createUI(obj)
            % Create the UI components
            
            % Create figure
            obj.Figure = uifigure('Name', 'Customize Menus', ...
                'Position', [100 100 500 600], ...
                'Resize', 'on');
            
            % Create main grid layout
            mainGrid = uigridlayout(obj.Figure, [4 1]);
            mainGrid.RowHeight = {50, '1x', 'fit', 40};
            mainGrid.Padding = [10 10 10 10];
            mainGrid.RowSpacing = 10;
            
            % Scope selection panel
            scopePanel = uipanel(mainGrid, 'Title', 'Settings Scope');
            scopePanel.Layout.Row = 1;
            scopeGrid = uigridlayout(scopePanel, [3 1]);
            scopeGrid.RowHeight = {'1x', 20, '1x'};
            scopeGrid.RowSpacing = 0;
            scopeGrid.Padding = 0;
            
            obj.ScopeButtonGroup = uibuttongroup(scopeGrid, ...
                'SelectionChangedFcn', @obj.onScopeChanged, ...
                'BorderType', 'none');
            obj.ScopeButtonGroup.Layout.Row = 2;

            obj.UserButton = uiradiobutton(obj.ScopeButtonGroup, ...
                'Text', 'User (applies to all projects)', ...
                'Position', [10 0 200 20]);
            
            obj.ProjectButton = uiradiobutton(obj.ScopeButtonGroup, ...
                'Text', 'Project (current project only)', ...
                'Position', [250 0 220 20]);
            
            obj.UserButton.Value = true;
            
            % Tree panel
            treePanel = uipanel(mainGrid, 'Title', 'Menu Items (check to show, uncheck to hide)');
            treePanel.Layout.Row = 2;
            
            treeGrid = uigridlayout(treePanel, [1 1]);
            treeGrid.ColumnWidth = {'1x'};

            obj.Tree = uitree(treeGrid, 'checkbox', ...
                'Position', [10 10 470 520]);
            obj.Tree.CheckedNodesChangedFcn =  @obj.onTreeSelectionChanged;
            % Instructions panel
            infoPanel = uipanel(mainGrid, 'Title', 'Information');
            infoPanel.Layout.Row = 3;
            infoGrid = uigridlayout(infoPanel, [2 1]);
            infoGrid.RowHeight = {'fit', 'fit'};
            infoGrid.Padding = [5 5 5 5];
            
            uilabel(infoGrid, ...
                'Text', '• Checked items will be visible in menus', ...
                'HorizontalAlignment', 'left');
            uilabel(infoGrid, ...
                'Text', '• Changes take effect immediately', ...
                'HorizontalAlignment', 'left');
            
            % Button panel
            buttonPanel = uipanel(mainGrid);
            buttonPanel.Layout.Row = 4;
            buttonGrid = uigridlayout(buttonPanel, [1 4]);
            buttonGrid.ColumnWidth = {100, '1x', 100, 100};
            buttonGrid.Padding = [10 5 10 5];
            
            % Cleanup button
            cleanupButton = uibutton(buttonGrid, ...
                'Text', 'Cleanup', ...
                'Tooltip', 'Remove preferences for menus that no longer exist', ...
                'ButtonPushedFcn', @obj.onCleanupButtonPushed);
            
            % Spacer
            uilabel(buttonGrid, 'Text', '');
            
            obj.ResetButton = uibutton(buttonGrid, ...
                'Text', 'Reset', ...
                'Tooltip', 'Show all menu items', ...
                'ButtonPushedFcn', @obj.onResetButtonPushed);
            
            obj.CancelButton = uibutton(buttonGrid, ...
                'Text', 'Close', ...
                'ButtonPushedFcn', @obj.onCancelButtonPushed);
        end
        
        function loadMenuStructure(obj)
            % Load menu structure from app
            
            manager = obj.App.MenuVisibilityManager;
            obj.MenuTags = manager.getAllMenuTags();
            
            % Build tree structure
            obj.TreeNodes = containers.Map();
            
            % Build hierarchical tree from tags
            % Each tag like 'core.nansen.configure.datalocations' becomes a nested structure
            
            % Sort tags to match menu order in the app
            sortedTags = obj.sortMenuTags(obj.MenuTags);
            
            % Track created nodes to avoid duplicates
            createdPaths = containers.Map();
            
            for i = 1:numel(sortedTags)
                tag = sortedTags{i};
                parts = strsplit(tag, '.');
                
                if numel(parts) < 2
                    continue;
                end
                
                % Build the path incrementally
                currentPath = '';
                parentNode = [];
                
                for j = 1:numel(parts)
                    % Build current path
                    if isempty(currentPath)
                        currentPath = parts{j};
                    else
                        currentPath = [currentPath, '.', parts{j}];
                    end
                    
                    % Check if this node already exists
                    if ~isKey(createdPaths, currentPath)
                        % Create node
                        nodeText = obj.formatLabel(parts{j});
                        
                        if isempty(parentNode)
                            % Top level node
                            newNode = uitreenode(obj.Tree, 'Text', nodeText);
                        else
                            % Child node
                            newNode = uitreenode(parentNode, 'Text', nodeText);
                        end
                        
                        % Store node
                        createdPaths(currentPath) = newNode;
                        
                        % If this is a complete tag (matches a menu item), store in TreeNodes
                        if j == numel(parts)
                            newNode.NodeData = tag;
                            obj.TreeNodes(tag) = newNode;
                        end
                        
                        parentNode = newNode;
                    else
                        % Node already exists
                        existingNode = createdPaths(currentPath);
                        
                        % Check if this path is a complete tag but wasn't stored yet
                        % This happens when a parent menu has children
                        if j == numel(parts) && ~isKey(obj.TreeNodes, currentPath)
                            existingNode.NodeData = tag;
                            obj.TreeNodes(tag) = existingNode;
                        end
                        
                        parentNode = existingNode;
                    end
                end
            end
            
            % Collapse all nodes initially, then expand Core
            collapse(obj.Tree, 'all');
            
            % Find and expand the Core node
            if isKey(createdPaths, 'core')
                expand(createdPaths('core'));
            end
        end
        
        function updateTreeSelection(obj)
            % Update tree checkboxes based on current visibility settings
            
            manager = obj.App.MenuVisibilityManager;
            
            % Build list of nodes that should be checked (visible)
            checkedNodesList = [];
            
            % Get all nodes
            tags = keys(obj.TreeNodes);
            for i = 1:numel(tags)
                tag = tags{i};
                node = obj.TreeNodes(tag);
                
                % Check if this menu is hidden in current scope
                isHidden = manager.isMenuItemHidden(tag, obj.CurrentScope);
                
                % If not hidden, add to checked list
                if ~isHidden
                    checkedNodesList = [checkedNodesList; node]; %#ok<AGROW>
                end
            end
            
            % Update tree checked nodes all at once
            obj.Tree.CheckedNodes = checkedNodesList;
        end
        
        function sortedTags = sortMenuTags(~, tags)
            % Sort tags to match menu order in the app
            % Order: core.nansen, core.metatable, core.session, core.apps, core.help, plugin.*
            
            menuOrder = {'core.nansen', 'core.metatable', 'core.session', ...
                         'core.apps', 'core.help', 'plugin'};
            
            % Group tags by their prefix
            groups = cell(numel(menuOrder), 1);
            for i = 1:numel(menuOrder)
                prefix = menuOrder{i};
                groups{i} = tags(startsWith(tags, prefix));
                groups{i} = sort(groups{i}); % Sort within group
            end
            
            % Concatenate all groups
            sortedTags = [groups{:}];
        end
        
        function label = formatLabel(~, text)
            % Format tag text for display
            
            % Replace underscores with spaces
            label = strrep(text, '_', ' ');
            
            % Capitalize first letter of each word
            words = strsplit(label, ' ');
            for i = 1:numel(words)
                if ~isempty(words{i})
                    words{i}(1) = upper(words{i}(1));
                end
            end
            label = strjoin(words, ' ');
        end
        
        function onScopeChanged(obj, ~, event)
            % Handle scope selection change
            
            % Temporarily disable the tree callback to prevent triggering saves
            originalCallback = obj.Tree.CheckedNodesChangedFcn;
            obj.Tree.CheckedNodesChangedFcn = [];
            
            if event.NewValue == obj.UserButton
                obj.CurrentScope = 'user';
            else
                obj.CurrentScope = 'project';
            end
            
            obj.updateTreeSelection();
            
            % Re-enable the callback
            obj.Tree.CheckedNodesChangedFcn = originalCallback;
        end
        
        function onTreeSelectionChanged(obj, ~, ~)
            % Handle tree checkbox changes - apply immediately
            obj.applyChanges();
        end
        
        function applyChanges(obj)
            % Apply visibility changes to MenuVisibilityManager
            
            manager = obj.App.MenuVisibilityManager;
            
            % Get all leaf nodes (menu items)
            tags = keys(obj.TreeNodes);
            for i = 1:numel(tags)
                tag = tags{i};
                node = obj.TreeNodes(tag);
                
                % Check if node is in checked nodes
                isVisible = ismember(node, obj.Tree.CheckedNodes);
                
                % Update visibility
                manager.setMenuVisibility(tag, isVisible, obj.CurrentScope);
            end
            
            % Save and apply
            manager.savePreferences(obj.CurrentScope);
            manager.applyVisibility();
        end
        
        function onCancelButtonPushed(obj, ~, ~)
            % Close button callback
            delete(obj);
        end
        
        function onResetButtonPushed(obj, ~, ~)
            % Reset button callback - show all menus
            
            manager = obj.App.MenuVisibilityManager;
            
            % Clear all hidden menus for current scope
            tags = keys(obj.TreeNodes);
            for i = 1:numel(tags)
                tag = tags{i};
                manager.setMenuVisibility(tag, true, obj.CurrentScope);
            end
            
            % Save and apply
            manager.savePreferences(obj.CurrentScope);
            manager.applyVisibility();
            
            % Update UI
            obj.updateTreeSelection();
        end
        
        function onCleanupButtonPushed(obj, ~, ~)
            % Cleanup button callback - remove stale preferences
            
            manager = obj.App.MenuVisibilityManager;
            
            % Cleanup stale entries
            manager.cleanupStalePreferences(obj.CurrentScope);
            
            % Refresh the tree to show cleaned list
            delete(obj.Tree.Children);
            obj.TreeNodes = containers.Map();
            obj.loadMenuStructure();
            obj.updateTreeSelection();
            
            % Show confirmation
            uialert(obj.Figure, ...
                'Removed preferences for menus that no longer exist.', ...
                'Cleanup Complete', ...
                'Icon', 'success');
        end
    end
end
