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
    %   [ ] Make it possible to get session tasks from different
    %       directories. I.e also directories outside of the nansen repo.
    %   [ ] Add (and save) menu shortcuts (accelerators)
    %   [ ] Method for updating tasks in list
    %   [ ] Can the menus be created more efficiently, with regards to
    %       getting task attributes
    %   [ ] Add a mode called update (for updating specific menu item)
    

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
        MenuOrder = {'+data', '+process', '+analyze', '+plot'}              % Todo: preference?
        %MenuOrder = {'+data', '+processing', '+analysis', '+plotting'}              % Todo: preference?

    end
    
    properties
        Mode char = 'Default' % Mode for running session task. See doc
        CurrentProject
        TitleColor = '#0072BD';
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
        IsConstructed = false;
        ProjectChangedListener event.listener % Not implemented yet
    end
    
    events
        MethodSelected
    end
    

    methods
        
        function obj = SessionTaskMenu(appHandle, currentProject)
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
            
            % NB: This assumes that the ParentApp has a Figure property
            hFig = obj.ParentApp.Figure;
            assert(~isempty(hFig) && isvalid(hFig), ...
                'App does not have a valid figure')
            
            obj.CurrentProject = currentProject;
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
            end
        end
               
        function set.CurrentProject(obj, project)
            obj.CurrentProject = project;
            obj.onCurrentProjectSet()
        end

        function set.MethodsRootPath(obj, folderPath)
            if ~isequal(sort(obj.MethodsRootPath), sort(folderPath))
                obj.MethodsRootPath = folderPath;
                obj.onMethodsRootPathSet()
            end
        end
        
    end
    
    methods

        function refresh(obj)
        %refresh Refresh the menu. Delete all items and recreate them.

            delete( obj.hMenuDirs )
            delete( obj.hMenuItems )
            
            obj.hMenuDirs = matlab.ui.container.Menu.empty;
            obj.hMenuItems = matlab.ui.container.Menu.empty;
            
            obj.SessionTasks = struct('Name', {}, 'Attributes', {});
            obj.buildMenuFromDirectory(obj.ParentApp.Figure);
        end

        function refreshMenuItem(obj, taskName)

        end
        
        function menuNames = getRootLevelMenuNames(obj)
        %getRootLevelMenuNames Get names of the root menu folders.

            dirPath = obj.MethodsRootPath;
            ignoreList = {'+abstract', '+template'};
            
           	[~, menuNames] = utility.path.listSubDir(dirPath, '', ignoreList);
            menuNames = strrep(menuNames, '+', '');
            menuNames = unique(menuNames);
        end
    
    end
    
    methods (Access = private) % Methods for configuring menu
        
        function tf = isModeLocked(obj)
            tf = obj.IsModeLocked;
        end

        function buildMenuFromDirectory(obj, hParent, dirPath)
        %buildMenuFromDirectory Build menu items from a directory tree
        %
        % Go recursively through a directory tree of matlab packages 
        % and create a menu item for each matlab function which is found 
        % inside. The menu item is configured to trigger an event when it
        % is selected.
        % 
        % See also nansen.session.SessionMethod

        % Requires: utility.string.varname2label
        
            if nargin < 3
                dirPath = [obj.MethodsRootPath];
                isRootDirectory = true;
            else
                isRootDirectory = false;
            end
        
            % List contents of directory given as input
            L = utility.path.multidir(dirPath);
            
            if isRootDirectory % Sort listing by names
                % Sort names to come in a specified order...
                [~, sortIdx] = obj.sortMenuNames( {L.name} );
                L = L( sortIdx );
            end
            
            % Loop through contents of directory/directories
            for i = 1:numel(L)
                
                % For folders, add submenu
                if L(i).isdir
                    isPackageFolder = strncmp( L(i).name, '+', 1);
                    
                    if isPackageFolder
                        obj.addSubmenuForPackageFolder( hParent, L(i) );
                    else
                        continue
                    end

                % For m-files, add submenu item with callback
                else
                    [~, ~, ext] = fileparts(L(i).name);
                    
                    if ~strcmp(ext, '.m') && ~strcmp(ext, '.mlx')  
                        continue % Skip files that are not .m
                    end

                    mFilePath = fullfile(L(i).folder, L(i).name);
                    taskAttributes = obj.getTaskAttributes(mFilePath);
                    
                    switch taskAttributes.TaskType
                        case 'class'
                            obj.addMenuItemForClassTask(hParent, taskAttributes)
                        case 'function'
                            obj.addMenuItemForFunctionTask(hParent, taskAttributes)
                        case 'n/a' % Something went wrong
                            methodName = utility.string.varname2label(taskAttributes.FunctionName);
                            str = getReport(taskAttributes.Error, 'basic', 'hyperlinks', 'off');

                            str = strsplit(str, newline);
                            str = strjoin(str(2:end), '\n');

                            linkStr = regexp(str, '<a href="matlab: opentoline(.*)">', 'match', 'once');
                            str = strrep(str, linkStr, '');
                            str = strrep(str, '</a>', '');

                            errordlg(sprintf('Could not add the session method "%s" to the menu. Caused by:\n\n%s\n', methodName,  str) )
                        otherwise
                            % pass
                    end
                end
            end
        end
        
        function addSubmenuForPackageFolder(obj, hParent, folderListing)
        %addSubmenuForPackageFolder Add submenu for a package folder    
        %
        %   addSubmenuForPackageFolder(obj, hParent, folderListing) adds a
        %   submenu under the given parent menu for a package folder.
        %
        %   Inputs:
        %       hParent : handle to a menu item
        %       folderListing : scalar struct of folder attributes as
        %           returned from the dir function.
            
            % Create a text label for the menu
            menuName = strrep(folderListing.name, '+', '');
            menuName = utility.string.varname2label(menuName);
            
            % Check if menu with this label already exists
            hMenuItem = findobj( hParent, 'Type', 'uimenu', '-and', ...
                                 'Tag', menuName, '-depth', 1 );
            
            % Create new menu item if menu with this label does not exist
            if isempty(hMenuItem)
                if isa(hParent, 'matlab.ui.Figure')
                    styledMenuName = obj.styleTopLevelMenuTitle(menuName);
                else
                    styledMenuName = menuName;
                end
                hMenuItem = uimenu(hParent, 'Text', menuName, 'Tag', menuName);
                obj.hMenuDirs(end+1) = hMenuItem;
            end
            
            % Recursively build a submenu for the package directory
            subDirPath = fullfile(folderListing.folder, folderListing.name);
            obj.buildMenuFromDirectory(hMenuItem, subDirPath)
        end

        function addMenuItemForClassTask(obj, hParent, taskAttributes)
        %addMenuItemForClassTask Add menu item for a class-based task.
        %
        %   For a class based task, if multiple preset options are
        %   available, each preset option gets its own submenu item
            
            menuName = taskAttributes.MethodName;
            iSubMenu = uimenu(hParent, 'Text', menuName);

            options = taskAttributes.OptionsManager.AllOptionNames;

            if isempty(options) || numel(options)==1
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
        %   parallell, so they should always match one to one.
        
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

        function onMethodsRootPathSet(obj)
            if obj.IsConstructed
                obj.refresh()
            end
        end
        
        function menuName = styleTopLevelMenuTitle(obj, menuName)
            menuName = sprintf('<HTML><FONT color="%s">%s</Font></HTML>', ...
                obj.TitleColor, menuName);
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

        function [sortedNames, sortIdx] = sortMenuNames(obj, menuNames)
        %sortMenuNames Sort names in the order of the MenuOrder property
            
            sortIdx = zeros(1, numel(menuNames));
            count = 0;

            for i = 1:numel( obj.MenuOrder )
                
                isMatch = strcmp(obj.MenuOrder{i}, menuNames);
                numMatch = sum(isMatch);

                insertIdx = count + (1:numMatch);
                sortIdx(insertIdx) = find(isMatch);

                count = count + numMatch;
            end
            
            % Put custom names at the end...
            unsortedIdx = setdiff( 1:numel(menuNames), sortIdx(sortIdx~=0) );
            sortIdx(sortIdx == 0) = unsortedIdx;

            sortedNames = menuNames(sortIdx);
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
    
end