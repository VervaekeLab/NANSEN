classdef SessionMethodsMenu < handle
%SessionMethodsMenu Class for displaying session methods in a uimenu
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


% Purpose: Create a folder called sessionMethods with different 
% packages, all with functions that can be called with sessionIDs.
% These functions will be organized in the menu according the the
% packages within the root folder.

    % Questions:
    %   Where/how to implement the keyword trick...

    % TODO
    %   [ ] Make it possible to get session methods from different
    %   directories. I.e also directories outside of the nansen repo.
    %   [ ] Add (and save) menu shortcuts (accelerators)
    %   [ ] Method for updating methods in list
    
    properties (Constant, Hidden)
        ValidModes = {'Default', 'Preview', 'TaskQueue'}
    end
    
    properties
        Mode = 'Default' % Preview | TaskQueue
    end
    
    properties (SetAccess = private)
        ParentApp = []
        SessionMethods = struct('Name', {}, 'Attributes', {})
    end
    
    properties (Access = private)
        hMenuItems matlab.ui.container.Menu
    end
    
    properties (Access = private)
        DefaultMethodsPath char % Todo: Tie to a session type. Ie Ephys, ophys etc.
        ProjectMethodsPath char
        
        ProjectChangedListener
    end
    
    
    events
        MethodSelected
    end
    
    methods
        
        function obj = SessionMethodsMenu(appHandle)
            
            obj.ParentApp = appHandle;
            
            % NB: This assumes that the ParentApp has a Figure property
            hFig = obj.ParentApp.Figure;
            
            obj.assignDefaultMethodsPath()
            obj.assignProjectMethodsPath()
            
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
    
    methods (Access = private)
        
        function assignDefaultMethodsPath(obj)
            %Todo: This should depend on session schema.
            obj.DefaultMethodsPath = fullfile(nansen.rootpath, '+session', '+methods');
        end
        
        function assignProjectMethodsPath(obj)
            
            projectRootPath = nansen.localpath('project');
            [~, projectName] = fileparts(projectRootPath);
            obj.ProjectMethodsPath = fullfile(projectRootPath, ...
                'Session Methods', ['+', projectName] );
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
                dirPath = {obj.DefaultMethodsPath, obj.ProjectMethodsPath};
            end
        
            % List contents of directory given in inputs
            if isa(dirPath, 'cell')
                L = cellfun(@(pStr) dir(pStr), dirPath, 'uni', 0);
                L = cat(1, L{:});
            else
                L = dir(dirPath);
            end
            
            L = L(~strncmp({L.name}, '.', 1));
            
            
            % Loop through contents of directory
            for i = 1:numel(L)
                
                % For folders, add submenu
                if L(i).isdir
                
                    menuName = strrep(L(i).name, '+', '');
                    menuName = utility.string.varname2label(menuName);
                
                    if strcmp(menuName, 'Abstract') || strcmp(menuName, 'Template')
                        continue
                    end
                    
                    iMenu = uimenu(hParent, 'Text', menuName);
                    
                    % Recursively add subdirectory as a submenu
                    subDirPath = fullfile(L(i).folder, L(i).name);
                    obj.createMenuFromDirectory(iMenu, subDirPath)
                   
                % For m-files, add submenu item with callback
                else
                    [~, fileName, ext] = fileparts(L(i).name);
                    
                    if ~strcmp(ext, '.m') % Skip files that are not .m
                        continue
                    end
                    
                    menuName = utility.string.varname2label(fileName);
                                        
                    % Get the full function name (including package names)
                    functionName = obj.getFunctionStringName(L(i).folder, fileName);

                    
                    % Create menu items with function handle as callback
                    if ~isempty(meta.class.fromName(functionName))
                        
                        % Get attributes for session method/function.
                        fcnConfig = obj.getMethodAttributes(functionName);
                        options = fcnConfig.OptionsManager.listAllOptionNames();
                          
                        iSubMenu = uimenu(hParent, 'Text', menuName);
                        
                        if isempty(options)
                            obj.createMenuCallback(iSubMenu, functionName)
                            obj.registerMenuObject(iSubMenu, functionName)
                        
                        else
                            
                            % Create menu item for each function option
                            for j = 1:numel(options)
                                menuName = utility.string.varname2label(options{j});
                                menuName = options{j};
                                iMitem = uimenu(iSubMenu, 'Text', menuName);
                                
                                obj.createMenuCallback(iMitem, functionName, options{j})   
                                obj.registerMenuObject(iMitem, functionName)
                            end
                        end
                        
                    else
                        iMitem = uimenu(hParent, 'Text', menuName);
                        obj.createMenuCallback(iMitem, functionName)
                        obj.registerMenuObject(iMitem, functionName)
                        
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
        
        function registerMenuObject(obj, hMenuItem, functionName)
        %registerMenuObject Register the menuobject in class properties
        
            numItems = numel(obj.hMenuItems) + 1;

            % Add handle to menu item to property.
            obj.hMenuItems(numItems) = hMenuItem;

            obj.SessionMethods(numItems).Name = hMenuItem.Text;
            obj.SessionMethods(numItems).Attributes = ...
                obj.getMethodAttributes(functionName);

        end
           
        function refreshMenuLabels(obj)
        %refreshMenuLabels Callback for changing menu labels.
        %
        %   Invoked when the TaskMode property changes
        
            % Go through all menu items
            for i = 1:numel(obj.hMenuItems)
                h = obj.hMenuItems(i);
                attr = obj.SessionMethods(i).Attributes;

                % Reset text
                h.Text = strrep(h.Text, '...', '');
                h.Text = strrep(h.Text, ' (q)', '');
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
            
        end
        
    end
    
    methods (Static)
        
        function funcStrName = getFunctionStringName(dirPath, fileName)
        %getFunctionStringName Get full function name (including packages)
        %
        %   Example: 
        %       dirPath = '.../sessionMethods/+data/+open'
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
        
        function mConfig = getMethodAttributes(functionName)
                                
            hfun = str2func(functionName);

            try
                mConfig = hfun(); % Call with no input should give configs
            catch % Get defaults it there are no config:
                mConfig = nansen.session.SessionMethod.setAttributes();
            end
        end
        
    end

    
end



% % %         function S = getMethodAttributes(className)
% % %         %getMethodAttributes Get attributes for session method
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