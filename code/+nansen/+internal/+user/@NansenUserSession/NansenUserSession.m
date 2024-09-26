classdef NansenUserSession < handle
% NansenUserSession - Interface for managing a user session in NANSEN
%   
%   This class is activated when a user runs nansen, and handles all the 
%   user-specific customization for nansen. It saves all changes the user 
%   makes during a session and restores them when a the user starts a new 
%   session at a later time. It should work behind the scenes, but users 
%   are free to interact with it directly.
%
%   Note: The class is created to handle multiple users/user profiles, but
%   this functionality is not supported yet.
%
%   Syntax:
%       nansen.internal.user.NansenUserSession.instance() returns a
%       UserSession instance.

%   This class provides a singleton instance containing the following
%   components: 
%       - Preferences
%       - ProjectManager
%       - AddonManager

% Todo: 
%   [ ] Clear projectmanager instance when user session is deleted
%   [ ] Add DataManager app when it is initialized and shut it down
%   properly when a user session is ended.
%   [ ] If DataManager app is shut down independently, DataManagerApp
%   property should be reset

    
    properties (SetAccess = immutable) % Public
        CurrentUserName = "default"
        Preferences nansen.internal.user.Preferences
    end

    properties (Dependent, SetAccess = private)
        CurrentProject
    end

    properties (Access = private)
        AddonManager nansen.config.addons.AddonManager
        ProjectManager nansen.config.project.ProjectManager
        DataManagerApp % App of type nansen.App. 
        % NB: Can not specify type for property, because the nansen.App 
        % class depends on the Widgets Toolbox which might not be installed 
        % when creating a UserSession for the first time.
    end

    properties (Access = private)
        SessionUUID
        PreferenceDirectory
        PreferenceListenerState (1,1) struct
        ProjectChangedListener
    end

    properties (Access = private)
        SkipProjectCheck = false
    end

    properties (Constant, Access = private)
        DEFAULT_USER_NAME = "default"
        LOG_UUID = false;
    end

    methods (Static)
        %instance Return a singleton instance of the NansenUserSession  
        obj = instance(userName, mode, skipProjectCheck) % Method in separate file
    end

    methods % Set/get methods for dependent properties
        function set.CurrentProject(obj, newValue)
            obj.Preferences.CurrentProjectName = newValue;
        end

        function project = get.CurrentProject(obj)
            project = obj.ProjectManager.CurrentProject;
        end

    end

    methods
        function am = getAddonManager(obj)
            am = obj.AddonManager;
        end

        function pm = getProjectManager(obj)
            pm = obj.ProjectManager;
        end

        function setDataManagerApp(obj, app)
            assert(isa(app, 'nansen.App'), 'DataManager must be of type ''nansen.App''')
            obj.DataManagerApp = app;
        end
        
        function assertProjectsAvailable(obj)
            if obj.ProjectManager.NumProjects == 0
                error('Nansen:NoProjectsAvailable', ...
                    'No projects exist. Please run nansen.setup to configure a project')
            end
        end
    end

    methods (Access = private) % Structors

        function obj = NansenUserSession(userName, skipProjectCheck)
        % NansenUserSession - Constructor method

            import nansen.config.addons.AddonManager
            import nansen.config.project.ProjectManager
            obj.CurrentUserName = userName;
            obj.SkipProjectCheck = skipProjectCheck;

            obj.Preferences = obj.initializePreferences();
            preferenceDirectory = obj.getPrefdir(obj.CurrentUserName);

            obj.preStartup()

            obj.AddonManager = AddonManager(preferenceDirectory);
            obj.ProjectManager = ProjectManager.instance(preferenceDirectory, 'reset');

            obj.postStartup()
            obj.SessionUUID = nansen.util.getuuid();
        end

        function delete(obj)

            if ~isempty(obj.DataManagerApp)

            end

            delete(obj.ProjectManager)
            delete(obj.Preferences)

            if obj.LOG_UUID
                userName = obj.CurrentUserName;
                fprintf('Closed NANSEN user session for user "%s" (%s).\n', userName, obj.SessionUUID)
            end
        end

    end

    methods (Access = private) % Initialization procedures
    
        function prefs = initializePreferences(obj)
            prefdir = obj.getPrefdir(obj.CurrentUserName);
            obj.PreferenceDirectory = prefdir;
            % Return preferences, they can only be assigned in constructor
            prefs = nansen.internal.user.Preferences(prefdir);

            addlistener(prefs, 'CurrentProjectName', 'PostSet', ...
                @obj.onCurrentProjectChangedInPreferences);

            obj.PreferenceListenerState.CurrentProjectName = ...
                matlab.lang.OnOffSwitchState('on');
        end

        function preStartup(obj)
        % preStartup - Run procedures that need to execute before startup.
            obj.runPreStartupUpdateActions()
        end
        
        function postStartup(obj)
        % postStartup - Run procedures that need to execute after startup.

            % Check that projects are available
            if ~obj.SkipProjectCheck
                try
                    obj.assertProjectsAvailable()
                catch ME
                    warning(ME.identifier, '%s', ME.message)
                end
            end
            
            addlistener(obj.ProjectManager, 'CurrentProjectChanged', ...
                @obj.onCurrentProjectChangedInProjectManager);

            currentProject = obj.Preferences.CurrentProjectName;
            if ~isempty(currentProject)
                try
                    obj.ProjectManager.setProject(currentProject)
                catch ME
                    warning(ME.message)
                end
            end

            % Note: important that this happens last
            % obj.runPostStartupUpdateActions()

            % Check that Addons are on path.

            % Check that dependencies are installed
            nansen.internal.setup.checkWidgetsToolboxVersion()
        end

        function activatePreferenceListener(obj, preferenceName)
            obj.PreferenceListenerState.(preferenceName) = ...
                matlab.lang.OnOffSwitchState('on');
        end

        function deactivatePreferenceListener(obj, preferenceName)
            obj.PreferenceListenerState.(preferenceName) = ...
                matlab.lang.OnOffSwitchState('off');
        end

        function tf = isPreferenceListenerActive(obj, preferenceName)
            tf = logical(obj.PreferenceListenerState.(preferenceName));
        end
    end

    methods (Access = private) % Callbacks
        
        function onCurrentProjectChangedInPreferences(obj, src, evt)
        % Set new current project in project manager.
            if obj.isPreferenceListenerActive('CurrentProjectName')
                newProjectName = obj.Preferences.CurrentProjectName;
                obj.ProjectManager.setProject(newProjectName)
            end
        end

        function onCurrentProjectChangedInProjectManager(obj, src, evt)
        % Update value for current project in preferences. Make sure that
        % this is not triggering an event, to avoid infinite update loop.
            obj.deactivatePreferenceListener('CurrentProjectName')
            obj.Preferences.CurrentProjectName = evt.NewProjectName;
            obj.activatePreferenceListener('CurrentProjectName')
        end

    end

    methods (Access = private) % Internal actions

        function runPreStartupUpdateActions(obj)
        % runPreStartupUpdateActions - Run upgrade actions
            
        % The actions here should be a one-time thing. Sometimes changes 
        % are made to the code which influence user data, and these actions
        % update userdata if necessary.
            
            % Move _userdata folder from the nansen repository folder to
            % MATLAB's pref dir in order to avoid having preferences saved
            % in the reposiory folder.
            if isfolder(fullfile(nansen.rootpath, '_userdata'))
                nansen.internal.refactor.migrateUserdata(obj)
            end
            
            if contains( getpref('NansenSetup', 'DefaultProjectPath', ''), fullfile(nansen.rootpath, '_userdata'))
                rmpref('NansenSetup', 'DefaultProjectPath')
            end
        end

        function runPostConstructionUpdateActions(obj)
        % runPostStartupUpdateActions - Are actions needed due to update?
        %
        % The actions here should be a one-time thing. Sometimes changes 
        % are made to the code which influence user data, and these actions
        % update userdata if necessary.

        % Note: This method will be and should only be called from the 
        % static instance method. This is because some of the procedures
        % below might depend on the user session itself, so the singleton
        % instance must have been created when this method is called to
        % prevent an infinite recursion sequence.

            if obj.AddonManager.existExternalToolboxInRepository()
                obj.AddonManager.moveExternalToolboxes() % Todo: Remove
            end
            
            if obj.ProjectManager.hasUnversionedProjects()
                obj.ProjectManager.upgradeProjects()
            end

            if ispref('Nansen', 'CurrentProject')
                currentProject = getpref('Nansen', 'CurrentProject');
                obj.ProjectManager.changeProject(currentProject)
                rmpref('Nansen', 'CurrentProject');
                rmpref('Nansen', 'CurrentProjectPath');
            end
        end

    end
    
    methods (Static)
        % Why is this static
        function preferenceDirectory = getPrefdir(userName)
            if ~nargin || isempty(userName)
                warning('No username given, returning prefdir for default user')
                className = mfilename('class');
                userName = eval(sprintf('%s.DEFAULT_USER_NAME', className));
            end
            preferenceDirectory = fullfile(prefdir, 'Nansen', userName);
        end
    end

end