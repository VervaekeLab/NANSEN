classdef SessionTaskMenu < handle
%SessionTaskMenu Class for displaying session methods in a uimenu
%
%   A session method should be coded according to descriptions in the
%   SessionMethod class (or function template). These functions are then
%   saved in a package hierarchy, and this hierarchy will be used here to
%   create a uimenu using the same hierarchy.
%
%   Each menu item corresponding to a session method will be configured to
%   trigger the event MethodSelected when the menu item is selected. The
%   eventdata for this event contains two properties:
%       'TaskAttributes' : A struct with attributes for a session task
%       'Mode' : The mode for which the method should be run
%
%   The mode is one of the following:
%       - 'Default'
%       - 'Preview'
%       - 'TaskQueue'
%       - 'Edit'
%
%   The mode is determined by the value of the Mode property at the time
%   when the event is triggered. The Mode property has no functionality in
%   this class, but can be used by external code for configuring different
%   ways of running methods (see nansen.App for example...)

%   Note: The nomenclature of this class is inconsistent. A session method
%   and a session task refers to the same concept. Need to clean up.

    % TODO
    %   [ ] Make it possible to get session tasks from different
    %       directories. I.e also directories outside of the nansen repo.
    %   [ ] Add (and save) menu shortcuts (accelerators)
    %   [ ] Method for updating tasks in list
    %   [ ] Can the menus be created more efficiently, with regards to
    %       getting task attributes
    %   [ ] Add a mode called update (for updating specific menu item)

%   Generalization:
%       If inheriting from a MultiModalMenu:
%
%       Should this class have project information? Preferably not, the
%       project session method module should be assigned on construction,
%       and there should be a method for changing it...
%       So when a project is changed in nansen, it is nansen's
%       responsibility to set a property TempPackageDirectory (come up
%       with better name) instead of having a project changed listener
%       here...

    properties (Constant, Hidden)
        ValidModes = {'Default', 'Preview', 'TaskQueue', 'Edit', 'Help', 'Restart'} % Available modes
        MenuOrder = {'+data', '+process', '+analyze', '+plot'}                   % Todo: preference?
        %MenuOrder = {'+data', '+processing', '+analysis', '+plotting'}          % Todo: preference?
    end

    properties
        Mode char = 'Default' % Mode for running session task. See doc
        CurrentProject
        CurrentItemType (1,1) string
        %TitleColor = '#0072BD';
        TitleColor = '#303E48';
    end

    properties (SetAccess = private)
        ParentApp = [] % Handle of the app for the session task menu
        SessionTasks = struct('Name', {}, 'Attributes', {})
    end

    properties (Access = private)
        IsModeLocked = false
    end

    properties (Access = private)
        hMenuDirs matlab.ui.container.Menu
        hMenuItems matlab.ui.container.Menu
    end

    properties (Access = private)
        MethodsRootPath cell % List of folder paths for package(s) containing session tasks
    end

    properties (Access = private)
        ActionRegistry_ % nansen.plugin.action.Registry for current project/item type
    end

    properties (Access = private)
        IsConstructed (1,1) logical = false
        SkipRefresh (1,1) logical = false % Flag to skip refresh of menu
        ProjectChangedListener event.listener % Not implemented yet
    end

    events
        ModeChanged
        MenuUpdated
        MethodSelected
    end

    methods % Constructors

        function obj = SessionTaskMenu(appHandle, currentProject, currentItemType)
        %SessionTaskMenu Create a SessionTaskMenu object
        %
        %   obj = SessionTaskMenu(appHandle, modules) creates a
        %   SessionTaskMenu for a given app. appHandle is a handle for the
        %   app and modules is a cell array containing session task
        %   packages to include when building the menu
        %
        %   Currently available modules:
        %       'ophys.twophoton'

            obj.ParentApp = appHandle;

            if nargin < 2
                currentProject = nansen.ProjectManager().getCurrentProject();
            end

            if nargin < 3
                currentItemType = "session";
            end

            % NB: This assumes that the ParentApp has a Figure property
            hFig = obj.ParentApp.Figure;
            assert(~isempty(hFig) && isvalid(hFig), ...
                'App does not have a valid figure')

            obj.CurrentProject = currentProject;
            obj.CurrentItemType = currentItemType;

            assert(~isempty(obj.MethodsRootPath), ...
                ['No root directories for session methods have been assigned. ', ...
                'Please report if you see this.'])

            % Todo: Improve performance!
            obj.buildMenuFromDirectory(hFig);

            obj.IsConstructed = true;
        end

        function delete(obj)
            isdeletable = @(x) ~isempty(x) & isvalid(x);
            if isdeletable(obj.ProjectChangedListener)
                delete(obj.ProjectChangedListener)
            end
            if isdeletable(obj.hMenuItems)
                delete(obj.hMenuItems)
            end
            if isdeletable(obj.hMenuDirs)
                delete(obj.hMenuDirs)
            end
        end
    end

    methods % Set/get

        function set.Mode(obj, newMode)
        %set.Mode Set the mode property to one of the valid modes.
            if obj.isModeLocked(); return; end

            newMode = validatestring(newMode, obj.ValidModes);

            if ~isequal(newMode, obj.Mode)
                obj.Mode = newMode;
                obj.refreshMenuLabels()
                obj.notify('ModeChanged', event.EventData)
            end
        end

        function set.CurrentProject(obj, project)
            obj.CurrentProject = project;
            obj.onCurrentProjectSet()
        end

        function set.CurrentItemType(obj, itemType)
            obj.CurrentItemType = itemType;
            obj.onCurrentItemTypeSet()
        end

        function set.MethodsRootPath(obj, folderPath)
            if ~isequal(sort(obj.MethodsRootPath), sort(folderPath))
                obj.MethodsRootPath = folderPath;
                obj.onMethodsRootPathSet()
            end
        end
    end

    methods
        function updateSource(obj, project, itemType)
            arguments
                obj (1,1) nansen.SessionTaskMenu
                project (1,1) nansen.config.project.Project
                itemType (1,1) string
            end
            obj.SkipRefresh = true;
            skipRefreshCleanup = onCleanup(@obj.resetSkipRefreshFlag);
            obj.CurrentProject = project;
            obj.CurrentItemType = itemType;
            clear skipRefreshCleanup
            obj.refresh()
        end

        function refresh(obj)
        %refresh Refresh the menu. Delete all items and recreate them.

            delete( obj.hMenuDirs )
            delete( obj.hMenuItems )

            obj.hMenuDirs = matlab.ui.container.Menu.empty;
            obj.hMenuItems = matlab.ui.container.Menu.empty;

            obj.SessionTasks = struct('Name', {}, 'Attributes', {});
            obj.buildMenuFromDirectory(obj.ParentApp.Figure);
            obj.refreshMenuLabels()

            obj.notify('MenuUpdated', event.EventData)
        end

        function refreshMenuItem(~, ~)
        end

        function menuNames = getRootLevelMenuNames(obj)
        %getRootLevelMenuNames Get names of the root menu folders.

            dirPath = obj.MethodsRootPath;
            ignoreList = {'+abstract', '+template'};

           	[~, menuNames] = utility.path.listSubDir(dirPath, '', ignoreList);
            if isempty(menuNames)
                menuNames = obj.MenuOrder;
            end
            menuNames = strrep(menuNames, '+', '');
            menuNames = unique(menuNames);
        end
    end

    methods (Access = private) % Methods for configuring menu

        function tf = isModeLocked(obj)
            tf = obj.IsModeLocked;
        end

        function buildMenuFromDirectory(obj, hParent)
        %buildMenuFromDirectory Build the uimenu from an intermediate tree.
        %
        %   When an ActionRegistry is available and returns specs, builds the
        %   tree from action specs (registry path). Otherwise falls back to
        %   building the tree from the directory structure (legacy path).
        %
        %   In both cases an intermediate tree (cell array of node structs)
        %   is constructed first, then rendered to uimenu by buildMenuFromTree_.
        %
        %   See also nansen.plugin.action.Registry, nansen.session.SessionMethod

            if ~isempty(obj.ActionRegistry_)
                specs = obj.ActionRegistry_.list();
                if ~isempty(specs)
                    nodes = nansen.SessionTaskMenu.buildTreeFromActionSpecs_( ...
                        specs, obj.MenuOrder);
                    obj.buildMenuFromTree_(hParent, nodes);
                    return
                end
            end

            nodes = nansen.SessionTaskMenu.buildTreeFromDirectory_( ...
                obj.MethodsRootPath, obj.MenuOrder);
            obj.buildMenuFromTree_(hParent, nodes);
        end

        function buildMenuFromTree_(obj, hParent, nodes)
        %buildMenuFromTree_ Render a tree of folder/action nodes as uimenu items.
        %
        %   Recursively walks the node tree, creating uimenu folder containers
        %   for 'folder' nodes and leaf menu items for 'action' nodes.
        %
        %   Node format:
        %     Folder: struct(Type='folder', Label, Tag, Children={nodes})
        %     Action: struct(Type='action', TaskAttributes)

            for i = 1:numel(nodes)
                node = nodes{i};
                switch node.Type

                    case 'folder'
                        % Find or create the folder menu container
                        hExisting = findobj(hParent, 'Type', 'uimenu', ...
                            'Tag', node.Tag, '-depth', 1);
                        if isempty(hExisting)
                            hNew = uimenu(hParent, 'Text', node.Label, 'Tag', node.Tag);
                            if isa(hParent, 'matlab.ui.Figure')
                                obj.styleTopLevelMenuTitle(hNew, node.Label);
                            end
                            obj.hMenuDirs(end+1) = hNew;
                            hFolder = hNew;
                        else
                            hFolder = hExisting(1);
                        end
                        obj.buildMenuFromTree_(hFolder, node.Children)

                    case 'action'
                        taskAttributes = node.TaskAttributes;
                        switch lower(taskAttributes.TaskType)
                            case 'class'
                                obj.addMenuItemForClassTask(hParent, taskAttributes)
                            case 'n/a'
                                methodName = utility.string.varname2label(taskAttributes.FunctionName);
                                str = getReport(taskAttributes.Error, 'basic', 'hyperlinks', 'off');
                                str = strsplit(str, newline);
                                str = strjoin(str(1:end), '\n');
                                linkStr = regexp(str, '<a href="matlab: opentoline(.*)">', 'match', 'once');
                                str = strrep(str, linkStr, '');
                                str = strrep(str, '</a>', '');
                                errordlg(sprintf('Could not add the session method "%s" to the menu. Caused by:\n\n%s\n', methodName, str))
                            otherwise
                                obj.addMenuItemForFunctionTask(hParent, taskAttributes)
                        end
                end
            end
        end

        function addMenuItemForClassTask(obj, hParent, taskAttributes)
        %addMenuItemForClassTask Add menu item for a class-based task.
        %
        %   For a class based task, if multiple preset options are
        %   available, each preset option gets its own submenu item

            menuName = taskAttributes.MethodName;
            iSubMenu = uimenu(hParent, 'Text', menuName);

            if isfield(taskAttributes, 'OptionsManager') && ~isempty(taskAttributes.OptionsManager)
                options = taskAttributes.OptionsManager.AllOptionNames;
            else
                options = {};
            end

            if isempty(options) || isscalar(options)
                obj.createMenuCallback(iSubMenu, taskAttributes)
                obj.storeMenuObject(iSubMenu, taskAttributes)

            else
                % Create menu item for each task option
                for j = 1:numel(options)
                    %menuName = utility.string.varname2label(options{j});
                    menuName = options{j};
                    iMitem = uimenu(iSubMenu, 'Text', menuName);

                    obj.createMenuCallback(iMitem, taskAttributes, ...
                        'OptionsSelection', options{j} )
                    obj.storeMenuObject(iMitem, taskAttributes)
                end
            end
        end

        function addMenuItemForFunctionTask(obj, hParent, taskAttributes)
        %addMenuItemForFunctionTask Add menu item for a function-based task
        %
        %   Similar to a class based task, but instead of making a submenu
        %   if multiple options are available, a submenu is created if
        %   multiple alternatives are available. An alternative is
        %   different than options in that alternatives are not managed by
        %   the options manager.

            menuName = taskAttributes.MethodName;
            menuName = utility.string.titleCase(menuName);

            % Check if menu with this label already exists
            iSubMenu = findobj( hParent, 'Type', 'uimenu', '-and', ...
                                 'Text', menuName, '-depth', 1 );
            if isempty(iSubMenu)
                iSubMenu = uimenu(hParent, 'Text', menuName);
            end

            if ~isempty(taskAttributes.Alternatives)
                % Create one menu item for each task alternative
                for j = 1:numel(taskAttributes.Alternatives)

                    menuName = taskAttributes.Alternatives{j};
                    iMitem = uimenu(iSubMenu, 'Text', menuName);

                    obj.createMenuCallback(iMitem, taskAttributes, ...
                        'Alternative', taskAttributes.Alternatives{j} )
                    obj.storeMenuObject(iMitem, taskAttributes)
                end
            else
                obj.createMenuCallback(iSubMenu, taskAttributes)
                obj.storeMenuObject(iSubMenu, taskAttributes)
            end
        end

        function createMenuCallback(obj, hMenu, taskAttributes, varargin)
        %createMenuCallback Create a menu callback for the menu item.
        %
        %   If there is a keyword, add it as an input to the callback
        %   function.

            callbackFcn = @(s, e, h, vararg) obj.onMenuSelected(...
                    taskAttributes, varargin{:});

            hMenu.MenuSelectedFcn = callbackFcn;
        end

        function storeMenuObject(obj, hMenuItem, taskAttributes)
        %storeMenuObject Store the menuobject in class properties
        %
        %   The menu item and the session task attributes are stored in
        %   parallel, so they should always match one to one.

            numItems = numel(obj.hMenuItems) + 1;

            % Add handle to menu item to property.
            obj.hMenuItems(numItems) = hMenuItem;

            obj.SessionTasks(numItems).Name = hMenuItem.Text;
            obj.SessionTasks(numItems).Attributes = taskAttributes;
        end

        function refreshMenuLabels(obj)
        %refreshMenuLabels Callback for changing menu labels.
        %
        %   Invoked when the TaskMode property changes

            % Go through all menu items
            for i = 1:numel(obj.hMenuItems)

                h = obj.hMenuItems(i);
                attr = obj.SessionTasks(i).Attributes;

                % Reset text
                h.Text = strrep(h.Text, '...', '');
                h.Text = strrep(h.Text, ' (q)', '');
                h.Text = strrep(h.Text, ' (e)', '');
                h.Text = strrep(h.Text, ' (r)', '');
                h.Text = strrep(h.Text, ' (h)', '');
                h.Enable = 'on';

                % Append token to text
                switch obj.Mode
                    case 'Default'
                        % Do nothing...

                    case 'Preview'
                        h.Text = [h.Text, '...'];

                    case 'TaskQueue'
                        h.Text = [h.Text, ' (q)'];

                        if ~isempty(attr) && isfield(attr, 'IsQueueable')
                            if ~attr.IsQueueable
                                h.Enable = 'off';
                            end
                        end

                    case 'Edit'
                        h.Text = [h.Text, ' (e)'];

                    case 'Help'
                        h.Text = [h.Text, ' (h)'];

                    case 'Restart'
                        h.Text = [h.Text, ' (r)'];
                end
            end
        end
    end

    methods (Access = private) % Callback

        function onMenuSelected(obj, taskAttributes, varargin)
        %onMenuSelected Callback for menu item selection. Trigger event
        %
        %   Create event data containing mode and task attributes ++ and
        %   trigger the MethodSelected event.

            params = struct;
            params.Mode = obj.Mode;
            params.TaskAttributes = taskAttributes;
            params.OptionsSelection = '';
            params.Alternative = '';

            params = utility.parsenvpairs(params, 1, varargin);
            nvPairs = utility.struct2nvpairs(params);

            obj.Mode = 'Default'; % Reset mode
            obj.IsModeLocked = true; % Prevent sticky keys

            evtData = uiw.event.EventData( nvPairs{:} );
            obj.notify('MethodSelected', evtData)

            %obj.Mode = 'Default'; % Reset mode
            pause(0.5)
            obj.IsModeLocked = false;
        end
    end

    methods (Access = private) % Utility methods

        function onCurrentProjectSet(obj)
            rootDirectories = obj.CurrentProject.getSessionMethodFolder();
            obj.MethodsRootPath = rootDirectories;
        end

        function onCurrentItemTypeSet(obj)
            rootDirectories = obj.CurrentProject.getObjectMethodFolder(obj.CurrentItemType);
            obj.MethodsRootPath = rootDirectories;
        end

        function onMethodsRootPathSet(obj)
            obj.ActionRegistry_ = nansen.plugin.action.Registry(obj.MethodsRootPath);
            if obj.IsConstructed && ~obj.SkipRefresh
                obj.refresh()
            end
        end

        function styleTopLevelMenuTitle(obj, hMenuItem, menuName)
            if nansen.util.useModernUiComponents()
                hMenuItem.Text = menuName;
                if isprop(hMenuItem, 'ForegroundColor')
                    hMenuItem.ForegroundColor = obj.getTitleColorRgb();
                end
            else
                hMenuItem.Text = sprintf('<HTML><FONT color="%s">%s</Font></HTML>', ...
                    obj.TitleColor, menuName);
            end
        end

        function rgb = getTitleColorRgb(obj)
            if isnumeric(obj.TitleColor)
                rgb = obj.TitleColor;
                return
            end

            hexColor = char(obj.TitleColor);
            hexColor = strrep(hexColor, '#', '');
            if numel(hexColor) ~= 6
                rgb = [0 0 0];
                return
            end
            rgb = [hex2dec(hexColor(1:2)), ...
                   hex2dec(hexColor(3:4)), ...
                   hex2dec(hexColor(5:6))] ./ 255;
        end

        function resetSkipRefreshFlag(obj)
            obj.SkipRefresh = false;
        end

        function packagePathList = listPackageHierarchy(obj)
        %listPackageHierarchy Get all package folders containing session methods
        %
        %   This function retrieves all package folders that contain
        %   session methods, both default nansen methods and user project
        %   methods.

        %   Not implemented yet. The idea was to list all packages first,
        %   then build menus. Now that happens interchangeably.

            dirPath = obj.MethodsRootPath;
            ignoreList = {'+abstract', '+template'};

            finished = false;
            packagePathList = {};

            while ~finished

                [absPath, ~] = utility.path.listSubDir(dirPath, '', ignoreList);

                if isempty(absPath)
                    finished = true;
                else
                    packagePathList = [packagePathList, absPath]; %#ok<AGROW>
                    dirPath = absPath;
                end
            end

            packagePathList = obj.sortPackageHierarchy(packagePathList);
        end

        function packagePathList = sortPackageHierarchy(obj, packagePathList)
        %sortPackageHierarchy Sort package folders so that subpackages from
        %different root directories are put in successive order.

            packageListLocal = packagePathList;
            for i = 1:numel(obj.MethodsRootPath)
                packageListLocal = strrep(packageListLocal, obj.MethodsRootPath{i}, '');
            end

            [~, sortInd] = sort(packageListLocal);
            packagePathList = packagePathList(sortInd);
        end
    end

    methods (Static)

        function taskAttributes = getTaskAttributes(filePathStr)
        %getTaskAttributes Get task attributes for a session task
        %
        %   Task Attributes is a struct containing the following fields
        %
        %       FunctionName    : Name of function (including package names)
        %       FunctionHandle  : Function handle for running session task
        %       TaskType        : How session task is coded (function or class)
        %       IsQueueable     : Is session task queuable
        %       BatchMode       : How should a batch of sessions run (serial or bacth)
        %       Options         : A set of options to run the session task with
        %       Alternatives (*): A set of alternatives available for running the session task
        %       OptionsManager  : An options manager for the session task
        %
        %       (*) Alternatives is a optional attribute that may exist or
        %       some function based session tasks.

        % todo: Move to an external function/class?

            functionName = utility.path.abspath2funcname(filePathStr);

            taskAttributes = struct;
            taskAttributes.FunctionName = functionName;
            taskAttributes.FunctionHandle = str2func(functionName);

            mc = meta.class.fromName(functionName);

            if ~isempty(mc)
                taskAttributes.TaskType = 'class';

                allPropertyNames = {mc.PropertyList.Name};
                propertyNames = {'MethodName', 'BatchMode', 'IsManual', ...
                    'IsQueueable', 'OptionsManager'};

                for i = 1:numel(propertyNames)
                    thisName = propertyNames{i};
                    isMatch = strcmp(allPropertyNames, propertyNames{i});
                    taskAttributes.(thisName) = mc.PropertyList(isMatch).DefaultValue;
                end

            else
                taskAttributes.TaskType = 'function';
                try
                    % Call function without inputs should return attributes
                    moreAttributes = taskAttributes.FunctionHandle();
                catch ME
                    taskAttributes.TaskType = 'n/a';
                    taskAttributes.Error = ME;
                    return
                end

                taskAttributes = utility.struct.mergestruct(taskAttributes, moreAttributes);
                try
                    taskAttributes.OptionsManager = nansen.OptionsManager(functionName);
                catch ME
                    warning('Could not resolve options for method %s', functionName)
                    disp(getReport(ME))
                end
            end
        end
    end

    % ------------------------------------------------------------------ %
    methods (Static, Access = private)

        function nodes = buildTreeFromDirectory_(dirPaths, menuOrder, sortEntries)
        %buildTreeFromDirectory_ Build a menu node tree by scanning directories.
        %
        %   Returns a cell array of node structs. Package folders (+name)
        %   become 'folder' nodes with recursive Children; MATLAB source
        %   files become 'action' nodes. +abstract and +template folders
        %   are skipped.
        %
        %   At the root call (sortEntries true) the listing is sorted by
        %   menuOrder before traversal. Recursive calls pass false.
        %
        %   Node format:
        %     Folder: struct(Type='folder', Label, Tag, Children={nodes})
        %     Action: struct(Type='action', TaskAttributes)

            if nargin < 3; sortEntries = true; end

            nodes = {};
            if isempty(dirPaths); return; end

            L = utility.path.multidir(dirPaths);
            if isempty(L); return; end

            if sortEntries && ~isempty(menuOrder)
                L = nansen.SessionTaskMenu.sortListingByMenuOrder_(L, menuOrder);
            end

            skipFolders = {'+abstract', '+template'};

            for i = 1:numel(L)
                entryName = L(i).name;

                if L(i).isdir
                    if ~strncmp(entryName, '+', 1); continue; end
                    if any(strcmp(entryName, skipFolders)); continue; end

                    tag   = strrep(entryName, '+', '');
                    label = utility.string.titleCase(utility.string.varname2label(tag));
                    subDirPath = fullfile(L(i).folder, entryName);

                    children = nansen.SessionTaskMenu.buildTreeFromDirectory_( ...
                        subDirPath, menuOrder, false);
                    if isempty(children); continue; end

                    node = struct('Type', 'folder', 'Label', label, ...
                        'Tag', tag, 'Children', {children});
                    nodes{end+1} = node; %#ok<AGROW>

                else
                    [~, ~, ext] = fileparts(entryName);
                    if ~strcmp(ext, '.m') && ~strcmp(ext, '.mlx'); continue; end

                    mFilePath = fullfile(L(i).folder, entryName);
                    taskAttributes = nansen.SessionTaskMenu.getTaskAttributes(mFilePath);
                    node = struct('Type', 'action', 'TaskAttributes', taskAttributes);
                    nodes{end+1} = node; %#ok<AGROW>
                end
            end
        end

        function nodes = buildTreeFromActionSpecs_(specs, menuOrder)
        %buildTreeFromActionSpecs_ Build a menu node tree from an ActionSpec array.
        %
        %   Specs are first sorted by menuOrder priority, then inserted
        %   into a nested tree using each spec's MenuLocation as the path.
        %   Specs with no MenuLocation are added at the root level.
        %
        %   Node format:
        %     Folder: struct(Type='folder', Label, Tag, Children={nodes})
        %     Action: struct(Type='action', TaskAttributes)

            nodes = {};
            if isempty(specs); return; end

            menuOrderStrs = strrep(menuOrder, '+', '');
            specs = nansen.SessionTaskMenu.sortSpecsByMenuOrder_(specs, menuOrderStrs);

            for i = 1:numel(specs)
                spec = specs(i);
                try
                    taskAttrs = spec.toTaskAttributes();
                catch
                    continue
                end

                loc = cellstr(spec.MenuLocation);
                leafNode = struct('Type', 'action', 'TaskAttributes', taskAttrs);
                nodes = nansen.SessionTaskMenu.insertNodeAtPath_(nodes, loc, leafNode);
            end
        end

        function nodes = insertNodeAtPath_(nodes, pathParts, leafNode)
        %insertNodeAtPath_ Recursively insert a leaf node at a folder path.
        %
        %   Creates intermediate 'folder' nodes as needed. Existing folder
        %   nodes with matching Tag are reused to allow multiple specs at
        %   the same menu path to share a container.

            if isempty(pathParts)
                nodes{end+1} = leafNode;
                return
            end

            tag      = pathParts{1};
            label    = utility.string.titleCase(utility.string.varname2label(tag));
            remaining = pathParts(2:end);

            % Find existing folder node with this tag
            folderIdx = [];
            for i = 1:numel(nodes)
                if isstruct(nodes{i}) && strcmp(nodes{i}.Type, 'folder') ...
                        && strcmp(nodes{i}.Tag, tag)
                    folderIdx = i;
                    break
                end
            end

            if isempty(folderIdx)
                newNode = struct('Type', 'folder', 'Label', label, ...
                    'Tag', tag, 'Children', {{}});
                newNode.Children = nansen.SessionTaskMenu.insertNodeAtPath_( ...
                    newNode.Children, remaining, leafNode);
                nodes{end+1} = newNode;
            else
                nodes{folderIdx}.Children = nansen.SessionTaskMenu.insertNodeAtPath_( ...
                    nodes{folderIdx}.Children, remaining, leafNode);
            end
        end

        function L = sortListingByMenuOrder_(L, menuOrder)
        %sortListingByMenuOrder_ Sort a dir listing by the given MenuOrder cell array.
        %
        %   Entries matching a MenuOrder element appear first (in MenuOrder
        %   sequence); remaining entries follow in their original order.

            if isempty(L) || isempty(menuOrder); return; end

            names    = {L.name};
            sortIdx  = zeros(1, numel(names));
            count    = 0;

            for i = 1:numel(menuOrder)
                isMatch  = strcmp(menuOrder{i}, names);
                numMatch = sum(isMatch);
                insertIdx = count + (1:numMatch);
                sortIdx(insertIdx) = find(isMatch);
                count = count + numMatch;
            end

            unsortedIdx = setdiff(1:numel(names), sortIdx(sortIdx ~= 0));
            sortIdx(sortIdx == 0) = unsortedIdx;
            L = L(sortIdx);
        end

        function specs = sortSpecsByMenuOrder_(specs, menuOrderStrs)
        %sortSpecsByMenuOrder_ Sort specs so root-level menu groups follow menuOrder.
        %
        %   menuOrderStrs is a cell array of strings with the '+' prefix
        %   already stripped (e.g. {'data','process','analyze','plot'}).
        %   Within each root-level group, specs are sorted by their full
        %   MenuLocation joined as a dot-string.

            if isempty(specs); return; end

            nSpecs   = numel(specs);
            sortKeys = cell(1, nSpecs);

            for i = 1:nSpecs
                loc = cellstr(specs(i).MenuLocation);
                if ~isempty(loc)
                    root = loc{1};
                    idx  = find(strcmp(menuOrderStrs, root), 1);
                    if isempty(idx)
                        idx = numel(menuOrderStrs) + 1;
                    end
                    sortKeys{i} = sprintf('%05d.%s', idx, strjoin(loc, '.'));
                else
                    sortKeys{i} = sprintf('%05d', numel(menuOrderStrs) + 2);
                end
            end

            [~, sortIdx] = sort(sortKeys);
            specs = specs(sortIdx);
        end

    end

end
