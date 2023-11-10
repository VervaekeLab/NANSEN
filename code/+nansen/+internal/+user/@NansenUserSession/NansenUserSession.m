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
%   componenets: 
%       - Preferences
%       - ProjectManager
%       - AddonManager

% Todo: Clear projectmanager instance when user session is deleted
    
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
        %DataManagerApp i.e nansen.App
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
    end

    methods (Access = private)

        function obj = NansenUserSession(userName, skipProjectCheck)
            
            import nansen.config.addons.AddonManager
            import nansen.config.project.ProjectManager

            obj.CurrentUserName = userName;
            obj.SkipProjectCheck = skipProjectCheck;

            obj.Preferences = obj.initializePreferences();
            preferenceDirectory = obj.getPrefdir();

            obj.AddonManager = AddonManager(preferenceDirectory);
            obj.ProjectManager = ProjectManager.instance(preferenceDirectory);

            obj.onStartup()
            obj.SessionUUID = nansen.util.getuuid();
        end

        function delete(obj)
            
            if obj.LOG_UUID
                userName = obj.CurrentUserName;
                fprintf('Closed NANSEN user session for user "%s" (%s).\n', userName, obj.SessionUUID)
            end

            delete(obj.ProjectManager)
            delete(obj.Preferences)
        end

    end

    methods (Access = private)
    
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
        
        function onStartup(obj)
        
            % Check that projects are available
            if ~obj.SkipProjectCheck
                obj.assertProjectsAvailable()
            end
            
            addlistener(obj.ProjectManager, 'CurrentProjectChanged', ...
                @obj.onCurrentProjectChangedInProjectManager);

            currentProject = obj.Preferences.CurrentProjectName;
            if ~isempty(currentProject)
                obj.ProjectManager.setProject(currentProject)
            end

            % Note: important that this happens last
            obj.checkIfUpdateActionsAreNeeded()


            % Check that Addons are on path.

            % Check that dependencies are installed

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

    methods (Access = private)

        function assertProjectsAvailable(obj)
            if obj.ProjectManager.NumProjects == 0
                delete(obj)
                error('Nansen:NoProjectsAvailable', ...
                    'No projects exists. Please run nansen.setup to configure a project')
            end
        end

        function checkIfUpdateActionsAreNeeded(obj)
        % checkIfUpdateActionsAreNeeded - Are actions needed due to update?
        %
        %   Sometimes updates requires some one time refactoring of
        %   userdata. This method checks if that is the case, and performs
        %   necessary actions.

            if isfolder(fullfile(nansen.rootpath, '_userdata'))
                nansen.internal.user.migrateUserdata(obj)
            end
            
            project = obj.ProjectManager.getCurrentProject();
            if ~isempty(project)
                if isfolder(fullfile(project.FolderPath, 'Metadata Tables', '+tablevar'))
                    nansen.internal.refactor.moveTableVarsToProjectNameSpace( obj.ProjectManager )
                end
            end

        end
        
    end
    
    methods (Static)
        
        function preferenceDirectory = getPrefdir(userName)
            if ~nargin || isempty(userName)
                className = mfilename('class');
                userName = eval(sprintf('%s.DEFAULT_USER_NAME', className));
            end
            preferenceDirectory = fullfile(prefdir, 'Nansen', userName);
        end
    end

end