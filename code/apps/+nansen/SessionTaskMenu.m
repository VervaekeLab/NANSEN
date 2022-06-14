classdef SessionTaskMenu < handle
%SessionTaskMenu Class for displaying session methods in a uimenu
%
%   A session method should be coded according to descriptions in the 
%   SessionMethod class (or function template). These functions are then
%   saved in a package hierarchy, and this hierarchy will be used here to
%   create a uimenu using the same hierarcy.
%
%   Each menu item corresponding to a session method will be configured to
%   trigger the event MethodSelected when the menu item is selected. The
%   eventdata for this event contains two properties:
%       'MethodFcn' : A function handle for the session method
%       'Mode'      : The mode for which the method should be run
%
%   The mode is one of the following: 'Default' | 'Preview' | 'TaskQueue'
%
%   The mode is determined by the value of the Mode property at the time
%   when the event is triggered. The Mode property has no functionality in
%   this class, but can be used by external code for configuring different
%   ways of running methods (see nansen.App for example...)


% Purpose: Create a folder called SessionTasks with different 
% packages, all with functions that can be called with sessionIDs.
% These functions will be organized in the menu according the the
% packages within the root folder.

    % Questions:
    %   Where/how to implement the keyword trick...

    % TODO
    %   [ ] Make it possible to get session tasks from different
    %   directories. I.e also directories outside of the nansen repo.
    %   [ ] Add (and save) menu shortcuts (accelerators)
    %   [ ] Method for updating tasks in list
    %   [ ] Can the menus be created more efficiently, with regards to
    %       getting task attributes
    
    properties (Constant, Hidden)
        ValidModes = {'Default', 'Preview', 'TaskQueue', 'Edit', 'Restart'}
    end
    
    properties
        Mode = 'Default' % Preview | TaskQueue
    end
    
    properties (SetAccess = private)
        ParentApp = []
        SessionTasks = struct('Name', {}, 'Attributes', {})
    end
    
    properties (Access = private)
        hMenuDirs matlab.ui.container.Menu
        hMenuItems matlab.ui.container.Menu
    end
    
    properties (Access = private)
        DefaultMethodsPath char % Todo: Tie to a session type. Ie Ephys, ophys etc.
        ProjectMethodsPath char
        DefaultMethodsPackage char % not used, remove?
        ProjectMethodsPackage char % not used, remove?
        
        ProjectChangedListener
    end
    
    
    events
        MethodSelected
    end
    
    methods
        
        function obj = SessionTaskMenu(appHandle, modules)
            
            obj.ParentApp = appHandle;
            
            if nargin < 2
                modules = {'ophys.twophoton'};
            end
            
            % NB: This assumes that the ParentApp has a Figure property
            hFig = obj.ParentApp.Figure;
            
            obj.assignDefaultMethodsPath(modules)
            obj.assignProjectMethodsPath()
            
            % Todo: Improve performance!
            obj.createMenuFromDirectory(hFig);
            
        end

    end
    
    methods % Set/get
        function set.Mode(obj, newMode)
        %set.Mode Set the mode property to one of the valid modes.
        
            newMode = validatestring(newMode, obj.ValidModes);
            
            if ~isequal(newMode, obj.Mode)
                obj.Mode = newMode;
                obj.refreshMenuLabels()
            end
            
        end
    end
    
    methods
        function refresh(obj)
            delete( obj.hMenuDirs )
            delete( obj.hMenuItems )
            
            obj.hMenuDirs = matlab.ui.container.Menu.empty;
            obj.hMenuItems = matlab.ui.container.Menu.empty;
            
            obj.SessionTasks = struct('Name', {}, 'Attributes', {});

            
            obj.assignProjectMethodsPath() % Should make this happen only if project is changed... Not urgent
            obj.createMenuFromDirectory(obj.ParentApp.Figure);
        end
        
        function menuNames = getTopMenuNames(obj)
            
            dirPath = {obj.DefaultMethodsPath, obj.ProjectMethodsPath};
            ignoreList = {'+abstract', '+template'};
            
           	[~, menuNames] = utility.path.listSubDir(dirPath, '', ignoreList);
            menuNames = strrep(menuNames, '+', '');
            menuNames = unique(menuNames);
        end
    end
    
    
    methods (Access = private)
        
        function assignDefaultMethodsPath(obj, modules)
            
            sesMethodRootFolder = nansen.localpath('sessionmethods');

            integrationDirs = utility.path.packagename2pathstr(modules);
            obj.DefaultMethodsPath = fullfile(sesMethodRootFolder, integrationDirs);
            return
            
            %Todo: This should depend on session schema.
            obj.DefaultMethodsPath = fullfile(nansen.rootpath, '+session', '+methods');
            obj.DefaultMethodsPackage = utility.path.pathstr2packagename(obj.DefaultMethodsPath);
        end
        
        function assignProjectMethodsPath(obj)
            
            projectRootPath = nansen.localpath('project');
            [~, projectName] = fileparts(projectRootPath);
            obj.ProjectMethodsPath = fullfile(projectRootPath, ...
                'Session Methods', ['+', projectName] );
            
            if ~isfolder(obj.ProjectMethodsPath); mkdir(obj.ProjectMethodsPath); end
            obj.ProjectMethodsPackage = utility.path.pathstr2packagename(obj.ProjectMethodsPath);
            
        end
        
        function packagePathList = listPackageHierarchy(obj)
        %listPackageHierarchy Get all package folders containing session methods   
        %
        %   This function retrieves all package folders that contain
        %   session method, both default nansen methods and user project
        %   methods.
        
            dirPath = {obj.DefaultMethodsPath, obj.ProjectMethodsPath};
            ignoreList = {'+abstract', '+template'};
            
            finished = false;
            packagePathList = {};
            
            while ~finished
                
                [absPath, ~] = utility.path.listSubDir(dirPath, '', ignoreList);

                if isempty(absPath)
                    finished = true;
                else
                    packagePathList = [packagePathList, absPath];
                    dirPath = absPath;
                end
            end

            packagePathList = obj.sortPackageHierarchy(packagePathList);
            
        end
        
        function packagePathList = sortPackageHierarchy(obj, packagePathList)
        %sortPackageHierarchy Sort package folders so that subpackages from
        %different root directories are put in successive order.
        
            packageListLocal = packagePathList;
            packageListLocal = strrep(packageListLocal, obj.DefaultMethodsPath, '');
            packageListLocal = strrep(packageListLocal, obj.ProjectMethodsPath, '');
            
            [~, sortInd] = sort(packageListLocal);
            packagePathList = packagePathList(sortInd);
        end

        function createMenuFromDirectory(obj, hParent, dirPath)
        %createMenuFromDirectory Create menu items from a directory tree
        %
        % Go recursively through a directory tree of matlab packages 
        % and create a menu item for each matlab function which is found 
        % inside. The menu item is configured to trigger an event when it
        % is selected.
        % 
        % See also SessionMethod (todo: update reference)

        
        % Requires: utility.string.varname2label
        
            if nargin < 3
                dirPath = [obj.DefaultMethodsPath, {obj.ProjectMethodsPath}];
                init = true;
            else
                init = false;
            end
        
            % List contents of directory given in inputs
            if isa(dirPath, 'cell')
                L = cellfun(@(pStr) dir(pStr), dirPath, 'uni', 0);
                L = cat(1, L{:});
            else
                L = dir(dirPath);
            end
            
            L = L(~strncmp({L.name}, '.', 1));
            
            if init % Sort menus 
                
                % Sort names to come in a specified order...
                menuOrder = {'+data', '+process', '+analyze', '+plot'};
                [~, ~, ic] = intersect(menuOrder, {L.name}, 'stable');
                mySortIdx = unique( [ic', 1:numel(L)], 'stable');
                L = L(mySortIdx);
                
            end
            
            % Loop through contents of directory
            for i = 1:numel(L)
                
                % For folders, add submenu
                if L(i).isdir
                
                    menuName = strrep(L(i).name, '+', '');
                    menuName = utility.string.varname2label(menuName);
                
                    if strcmp(menuName, 'Abstract') || strcmp(menuName, 'Template')
                        continue
                    end
                    
                    % Check if menu already exist.
                    iMenu = findobj(hParent, 'Type', 'uimenu', '-and', 'Text', menuName, '-depth', 1);
                    if isempty(iMenu)
                        iMenu = uimenu(hParent, 'Text', menuName);
                        obj.hMenuDirs(end+1) = iMenu;
                    end
                    
                    % Recursively add subdirectory as a submenu
                    subDirPath = fullfile(L(i).folder, L(i).name);
                    obj.createMenuFromDirectory(iMenu, subDirPath)
                   
                % For m-files, add submenu item with callback
                else
                    [~, fileName, ext] = fileparts(L(i).name);
                    
                    if ~strcmp(ext, '.m') &&  ~strcmp(ext, '.mlx')  % Skip files that are not .m
                        continue
                    end
                    
                    menuName = utility.string.varname2label(fileName);
                                        
                    % Get the full function name (including package names)
                    functionName = obj.getFunctionStringName(L(i).folder, fileName);
                    fcnConfig = obj.getTaskAttributes(functionName);

                    
                    % Create menu items with function handle as callback
                    if ~isempty(meta.class.fromName(functionName))
                        
                        % Get attributes for session method/function.
                        %fcnConfig = obj.getTaskAttributes(functionName);
                        options = fcnConfig.OptionsManager.AllOptionNames;
                        iSubMenu = uimenu(hParent, 'Text', menuName);
                        
                        if isempty(options) || numel(options)==1
                            obj.createMenuCallback(iSubMenu, functionName)
                            obj.registerMenuObject(iSubMenu, fcnConfig)
                        
                        else
                            
                            % Create menu item for each function option
                            for j = 1:numel(options)
                                menuName = utility.string.varname2label(options{j});
                                menuName = options{j};
                                iMitem = uimenu(iSubMenu, 'Text', menuName);
                                
                                obj.createMenuCallback(iMitem, functionName, options{j})   
                                obj.registerMenuObject(iMitem, fcnConfig)
                            end
                        end
                        
                    else
                        iMitem = uimenu(hParent, 'Text', menuName);
                        obj.createMenuCallback(iMitem, functionName)
                        obj.registerMenuObject(iMitem, fcnConfig)
                        
                    end
                    
                end
                
            end

        end
        
        function createMenuCallback(obj, hMenu, functionName, keyword)
        %createMenuCallback Create a menu callback for the menu item.
        %
        %   If there is a keyword, add it as an input to the callback
        %   function.
        
            hfun = str2func(functionName);
            
            if nargin < 4 || isempty(keyword)
                callbackFcn = @(s, e, h) obj.onMenuSelected(hfun);
            elseif nargin == 4 && ~isempty(keyword)
                callbackFcn = @(s, e, h, kwd) obj.onMenuSelected(hfun, keyword);
                
                % Alternative:
                % hfun = @(sObj, opt) hfun(sObj, 'Preset Selection', keyword, opt);
                % callbackFcn = @(s, e, h) obj.onMenuSelected(hfun);
                
            end
    
            hMenu.MenuSelectedFcn = callbackFcn;

        end
        
        function registerMenuObject(obj, hMenuItem, taskAttributes)
        %registerMenuObject Register the menuobject in class properties
        
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
                        
                    case 'Restart'
                        h.Text = [h.Text, ' (r)'];
                        
                 end
            end
           
        end
       
    end
    
    methods

        function onMenuSelected(obj, funHandle, optionName)
            
            nvPairs = {'MethodFcn', funHandle, 'Mode', obj.Mode};
            
            if nargin < 3 || isempty(optionName)
                optionName = '';
            end
            nvPairs = [nvPairs, {'OptionsSelection', optionName}];

            evtData = uiw.event.EventData( nvPairs{:} );
            obj.notify('MethodSelected', evtData)
            
            drawnow
            
            % Reset mode to default when item is selected
            obj.Mode = 'Default';

        end
        
    end
    
    methods (Static)
        
        function funcStrName = getFunctionStringName(dirPath, fileName)
        %getFunctionStringName Get full function name (including packages)
        %
        %   Example: 
        %       dirPath = '.../SessionTasks/+data/+open'
        %       fileName = 'twoPhotonRawImages.m'
        %       funcStrName = obj.getFunctionStringName(dirPath, fileName)
        %       
        %       funcStrName =
        %
        %           'data.open.twoPhotonRawImages.m'
        
        
            % Split directory path to get name of each individual folder
            splitFolders = strsplit(dirPath, filesep);
            
            % Determine which folders are package folders
            isPackage = strncmp(splitFolders, '+', 1);
            
            % Combine all package folders with filename using the . symbol
            packageName = strjoin(splitFolders(isPackage), '.');
            packageName = strrep(packageName, '+', '');

            funcStrName = strjoin({packageName, fileName}, '.');
            
        end
        
        function mConfig = getTaskAttributes(functionName)
                                
            hfun = str2func(functionName);
            
            mc = meta.class.fromName(functionName);
            if ~isempty(mc)
                allPropertyNames = {mc.PropertyList.Name};
                mConfig = struct;
                propertyNames = {'BatchMode', 'IsManual', 'IsQueueable', 'OptionsManager'};
                for i = 1:numel(propertyNames)
                    thisName = propertyNames{i};
                    isMatch = strcmp(allPropertyNames, propertyNames{i});
                    mConfig.(thisName) = mc.PropertyList(isMatch).DefaultValue;
                end
            else
                mConfig = hfun(); % Call with no input should give configs
                mConfig.OptionsManager = nansen.OptionsManager(functionName);
                
            end
            
% %             try
% %                 mConfig = hfun(); % Call with no input should give configs
% %             catch % Get defaults it there are no config:
% %                 mConfig = nansen.session.SessionMethod.setAttributes();
% %             end
        end
        
    end

    
end



% % %         function S = getTaskAttributes(className)
% % %         %getTaskAttributes Get attributes for session method
% % %         %
% % %         %   the SessionMethod superclass has some abstract and constant
% % %         %   properties that provide "attributes" for a session method. Get
% % %         %   the values of the subclass given by className
% % %         
% % %         
% % %             % Todo: Get from superclass constant properties. 
% % %             % utility.class.findproperties('nansen.session.SessionMethod', 'Constant')
% % %             
% % %             attributes = {'BatchMode', 'Alternatives', 'IsQueueable'};
% % %             S = struct();
% % %             
% % %             mc = meta.class.fromName(className);
% % % 
% % %             if ~isempty(mc)
% % %                 
% % %                 for i = 1:numel(attributes)
% % %                     iAttribute = attributes{i};
% % %                     isMatched = contains({mc.PropertyList.Name}, iAttribute);
% % %                     S.(iAttribute) = mc.PropertyList(isMatched).DefaultValue;
% % %                 end
% % %                 
% % %             else
% % %                 S = struct.empty();
% % %             end
% % %             
% % %         end