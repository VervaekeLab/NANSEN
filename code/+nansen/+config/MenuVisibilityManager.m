classdef MenuVisibilityManager < handle
    % MenuVisibilityManager - Manages visibility of menu items in NANSEN
    %
    %   This class provides functionality to hide/show menu items based on
    %   user preferences and project settings. It supports hierarchical
    %   menu tags (e.g., 'core.nansen.new_project', 'plugin.tools.my_tool')
    %   to enable fine-grained control over menu visibility.
    %
    %   Usage:
    %       manager = nansen.config.MenuVisibilityManager(figureHandle);
    %       manager.loadPreferences();
    %       manager.applyVisibility();
    
    properties (Access = private)
        FigureHandle matlab.ui.Figure
        HiddenMenus struct  % Struct with 'user' and 'project' fields
    end
    
    properties (Constant, Access = private)
        PREFERENCE_KEY = 'HiddenMenuItems'
    end
    
    methods
        function obj = MenuVisibilityManager(figureHandle)
            % Constructor
            %
            %   manager = MenuVisibilityManager(figureHandle)
            %
            %   Inputs:
            %       figureHandle - Handle to the figure containing menus
            
            obj.FigureHandle = figureHandle;
            obj.HiddenMenus = struct('user', {{}}, 'project', {{}});
        end
        
        function loadPreferences(obj, scope)
            % Load hidden menu preferences from file
            %
            %   loadPreferences(obj)
            %   loadPreferences(obj, scope)
            %
            %   Inputs:
            %       scope - Optional. 'user' or 'project'. Default: both
            
            if nargin < 2
                scope = 'both';
            end
            
            % Load user-level preferences
            if ismember(scope, {'user', 'both'})
                userPrefs = obj.loadUserPreferences();
                obj.HiddenMenus.user = userPrefs; % Always update, even if empty
            end
            
            % Load project-level preferences
            if ismember(scope, {'project', 'both'})
                projectPrefs = obj.loadProjectPreferences();
                obj.HiddenMenus.project = projectPrefs; % Always update, even if empty
            end
        end
        
        function savePreferences(obj, scope)
            % Save hidden menu preferences to file
            %
            %   savePreferences(obj)
            %   savePreferences(obj, scope)
            %
            %   Inputs:
            %       scope - Optional. 'user' or 'project'. Default: both
            
            if nargin < 2
                scope = 'both';
            end
            
            % Save user-level preferences
            if ismember(scope, {'user', 'both'})
                obj.saveUserPreferences(obj.HiddenMenus.user);
            end
            
            % Save project-level preferences
            if ismember(scope, {'project', 'both'})
                obj.saveProjectPreferences(obj.HiddenMenus.project);
            end
        end
        
        function applyVisibility(obj, cleanupStale)
            % Apply visibility settings to all tagged menu items
            %
            %   applyVisibility(obj)
            %   applyVisibility(obj, cleanupStale)
            %
            %   Inputs:
            %       cleanupStale - Optional. If true, removes preferences
            %                      for tags that no longer exist. Default: false
            
            if nargin < 2
                cleanupStale = false;
            end
            
            % Optionally cleanup stale preferences
            if cleanupStale
                obj.cleanupStalePreferences();
            end
            
            % Get all menu items with tags
            allMenus = obj.getAllTaggedMenus();
            
            % Also get parent menus (root menus without tags but with children)
            allRootMenus = findall(obj.FigureHandle, 'Type', 'uimenu', '-depth', 1);
            
            asRow = @(x) reshape(x, 1, []);

            % Combine user and project hidden menus
            allHiddenTags = [asRow(obj.HiddenMenus.user), asRow(obj.HiddenMenus.project)];

            % First pass: Apply direct visibility to each menu
            for i = 1:numel(allMenus)
                menuItem = allMenus(i);
                menuTag = menuItem.Tag;
                
                if isempty(menuTag)
                    continue;
                end
                
                % Check if this menu should be hidden
                isHidden = obj.isMenuHidden(menuTag, allHiddenTags);
                
                % Set visibility
                if isHidden
                    menuItem.Visible = 'off';
                else
                    menuItem.Visible = 'on';
                end
            end
            
            % Second pass: Make parent menus visible if any children are visible
            % This ensures that if you show a child menu, its parent becomes visible too
            % Check both tagged menus and root menus
            menusToCheck = unique([allMenus; allRootMenus]);
            
            for i = 1:numel(menusToCheck)
                menuItem = menusToCheck(i);
                
                % Check if this menu has visible children
                if ~isempty(menuItem.Children)
                    hasVisibleChildren = any(strcmp({menuItem.Children.Visible}, 'on'));
                    if hasVisibleChildren
                        menuItem.Visible = 'on';
                    end
                end
            end
            
            % Third pass: Hide parent menus if ALL children are hidden
            % This ensures that if you hide all items under a root menu, the root is hidden too
            % Check both tagged menus and root menus
            menusToCheck = unique([allMenus; allRootMenus]);
            
            for i = 1:numel(menusToCheck)
                menuItem = menusToCheck(i);
                
                % Skip Tools menu - it should always be visible
                if strcmp(menuItem.Text, 'Tools')
                    continue;
                end
                
                % Check if this menu has children and they're all hidden
                if ~isempty(menuItem.Children)
                    allChildrenHidden = all(strcmp({menuItem.Children.Visible}, 'off'));
                    if allChildrenHidden
                        menuItem.Visible = 'off';
                    end
                end
            end
        end
        
        function setMenuVisibility(obj, menuTag, isVisible, scope)
            % Set visibility for a specific menu item
            %
            %   setMenuVisibility(obj, menuTag, isVisible, scope)
            %
            %   Inputs:
            %       menuTag - String tag of the menu item
            %       isVisible - true to show, false to hide
            %       scope - 'user' or 'project'
            
            if nargin < 4
                scope = 'user';
            end
            
            % Get current hidden list for this scope
            hiddenList = obj.HiddenMenus.(scope);
            
            if isVisible
                % Remove from hidden list
                hiddenList(strcmp(hiddenList, menuTag)) = [];
            else
                % Add to hidden list if not already there
                if ~any(strcmp(hiddenList, menuTag))
                    hiddenList{end+1} = menuTag;
                end
            end
            
            % Update the hidden list
            obj.HiddenMenus.(scope) = hiddenList;
        end
        
        function tags = getAllMenuTags(obj)
            % Get all unique menu tags from the figure
            %
            %   tags = getAllMenuTags(obj)
            %
            %   Returns:
            %       tags - Cell array of unique tag strings
            
            allMenus = obj.getAllTaggedMenus();
            tags = {allMenus.Tag};
            tags = tags(~cellfun(@isempty, tags));
            tags = unique(tags);
        end
        
        function tree = getMenuTree(obj)
            % Get hierarchical structure of all menus
            %
            %   tree = getMenuTree(obj)
            %
            %   Returns:
            %       tree - Struct array representing menu hierarchy
            
            allTags = obj.getAllMenuTags();
            tree = obj.buildMenuTree(allTags);
        end
        
        function isHidden = isMenuItemHidden(obj, menuTag, scope)
            % Check if a specific menu item is hidden
            %
            %   isHidden = isMenuItemHidden(obj, menuTag)
            %   isHidden = isMenuItemHidden(obj, menuTag, scope)
            %
            %   Inputs:
            %       menuTag - String tag of the menu item
            %       scope - Optional. 'user', 'project', or 'both'
            %
            %   Returns:
            %       isHidden - true if menu is hidden, false otherwise
            
            if nargin < 3
                scope = 'both';
            end
            
            % Combine hidden lists based on scope
            switch scope
                case 'user'
                    hiddenList = obj.HiddenMenus.user;
                case 'project'
                    hiddenList = obj.HiddenMenus.project;
                case 'both'
                    hiddenList = [obj.HiddenMenus.user, obj.HiddenMenus.project];
            end
            
            isHidden = obj.isMenuHidden(menuTag, hiddenList);
        end
        
        function cleanupStalePreferences(obj, scope)
            % Remove preferences for menu tags that no longer exist
            %
            %   cleanupStalePreferences(obj)
            %   cleanupStalePreferences(obj, scope)
            %
            %   Inputs:
            %       scope - Optional. 'user', 'project', or 'both'. Default: 'both'
            
            if nargin < 2
                scope = 'both';
            end
            
            % Get all current menu tags
            currentTags = obj.getAllMenuTags();
            
            % Clean user preferences
            if ismember(scope, {'user', 'both'})
                obj.HiddenMenus.user = obj.filterStaleEntries(...
                    obj.HiddenMenus.user, currentTags);
            end
            
            % Clean project preferences
            if ismember(scope, {'project', 'both'})
                obj.HiddenMenus.project = obj.filterStaleEntries(...
                    obj.HiddenMenus.project, currentTags);
            end
            
            % Save cleaned preferences
            obj.savePreferences(scope);
        end
    end
    
    methods (Access = private)
        function allMenus = getAllTaggedMenus(obj)
            % Get all menu items with non-empty tags
            
            allMenus = findall(obj.FigureHandle, 'Type', 'uimenu');
            hasTag = ~cellfun(@isempty, {allMenus.Tag});
            allMenus = allMenus(hasTag);
        end
        
        function isHidden = isMenuHidden(~, menuTag, hiddenList)
            % Check if a menu tag is in the hidden list
            %
            %   Also checks for wildcard patterns (e.g., 'core.nansen.*')
            
            isHidden = false;
            
            for i = 1:numel(hiddenList)
                hiddenPattern = hiddenList{i};
                
                % Check for exact match
                if strcmp(menuTag, hiddenPattern)
                    isHidden = true;
                    return;
                end
                
                % Check for wildcard match (e.g., 'core.nansen.*')
                if endsWith(hiddenPattern, '.*')
                    prefix = hiddenPattern(1:end-2);
                    if startsWith(menuTag, [prefix, '.'])
                        isHidden = true;
                        return;
                    end
                end
            end
        end
        
        function prefs = loadUserPreferences(~)
            % Load user-level preferences
            
            prefs = {};
            
            try
                prefsFile = fullfile(prefdir, 'nansen_menu_visibility.mat');
                
                if isfile(prefsFile)
                    data = load(prefsFile, 'hiddenMenusUser');
                    if isfield(data, 'hiddenMenusUser')
                        prefs = data.hiddenMenusUser;
                    end
                end
            catch ME
                warning('MenuVisibilityManager:LoadFailed', ...
                    'Failed to load user preferences: %s', ME.message);
            end
        end
        
        function saveUserPreferences(~, prefs)
            % Save user-level preferences
            
            try
                prefsFile = fullfile(prefdir, 'nansen_menu_visibility.mat');
                hiddenMenusUser = prefs; %#ok<NASGU>
                save(prefsFile, 'hiddenMenusUser');
            catch ME
                warning('MenuVisibilityManager:SaveFailed', ...
                    'Failed to save user preferences: %s', ME.message);
            end
        end
        
        function prefs = loadProjectPreferences(~)
            % Load project-level preferences
            
            prefs = {};
            
            try
                % Get current project
                currentProject = nansen.getCurrentProject();
                
                if isempty(currentProject)
                    return;
                end
                
                % Load from project configuration folder
                configDir = currentProject.getConfigurationFolder();
                prefsFile = fullfile(configDir, 'menu_visibility.json');
                
                if isfile(prefsFile)
                    % Read JSON file
                    txt = fileread(prefsFile);
                    data = jsondecode(txt);
                    
                    % Convert from struct to cell array if needed
                    if isfield(data, 'hiddenMenus')
                        if iscell(data.hiddenMenus)
                            prefs = data.hiddenMenus;
                        elseif ischar(data.hiddenMenus) || isstring(data.hiddenMenus)
                            prefs = {char(data.hiddenMenus)};
                        end
                    end
                end
            catch ME
                warning('MenuVisibilityManager:LoadFailed', ...
                    'Failed to load project preferences: %s', ME.message);
            end
        end
        
        function saveProjectPreferences(~, prefs)
            % Save project-level preferences
            
            try
                % Get current project
                currentProject = nansen.getCurrentProject();
                
                if isempty(currentProject)
                    return;
                end
                
                % Load from project configuration folder
                configDir = currentProject.getConfigurationFolder();

                % Create Configurations directory if it doesn't exist
                if ~isfolder(configDir)
                    mkdir(configDir);
                end
                
                prefsFile = fullfile(configDir, 'menu_visibility.json');
                
                % Create struct with preferences
                data = struct();
                data.hiddenMenus = prefs;
                data.description = 'NANSEN menu visibility settings for this project';
                data.lastModified = char(datetime('now'));
                
                % Write JSON file with pretty formatting
                txt = jsonencode(data, 'PrettyPrint', true);
                fid = fopen(prefsFile, 'w');
                if fid == -1
                    error('Could not open file for writing: %s', prefsFile);
                end
                fprintf(fid, '%s', txt);
                fclose(fid);
            catch ME
                warning('MenuVisibilityManager:SaveFailed', ...
                    'Failed to save project preferences: %s', ME.message);
            end
        end
        
        function tree = buildMenuTree(~, tags)
            % Build hierarchical tree structure from flat tag list
            
            tree = struct('name', {}, 'tag', {}, 'children', {}, 'isLeaf', {});
            
            for i = 1:numel(tags)
                tag = tags{i};
                parts = strsplit(tag, '.');
                
                % Create node for this tag
                node = struct(...
                    'name', parts{end}, ...
                    'tag', tag, ...
                    'children', [], ...
                    'isLeaf', true);
                
                % Add to tree (simplified version - full implementation
                % would build proper hierarchy)
                tree(end+1) = node; %#ok<AGROW>
            end
        end
        
        function cleanList = filterStaleEntries(~, hiddenList, currentTags)
            % Filter out tags that no longer exist
            %
            %   Inputs:
            %       hiddenList - Cell array of hidden menu tags
            %       currentTags - Cell array of currently existing tags
            %
            %   Returns:
            %       cleanList - Filtered list with only existing tags
            
            cleanList = {};
            
            for i = 1:numel(hiddenList)
                hiddenTag = hiddenList{i};
                
                % Check for exact match
                if any(strcmp(currentTags, hiddenTag))
                    cleanList{end+1} = hiddenTag; %#ok<AGROW>
                    continue;
                end
                
                % Check if it's a wildcard pattern (e.g., 'core.nansen.*')
                if endsWith(hiddenTag, '.*')
                    prefix = hiddenTag(1:end-2);
                    % Keep wildcard if any tags start with this prefix
                    hasMatch = any(startsWith(currentTags, [prefix, '.']));
                    if hasMatch
                        cleanList{end+1} = hiddenTag; %#ok<AGROW>
                    end
                end
            end
        end
    end
end
