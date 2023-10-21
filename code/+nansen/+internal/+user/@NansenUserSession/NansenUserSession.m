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
    
    properties (SetAccess = immutable) % Public
        CurrentUserName = "default"
        Preferences nansen.internal.user.Preferences
    end

    properties (Dependent)
        CurrentProject
    end

    properties (Access = private)
        AddonManager nansen.config.addons.AddonManager
        ProjectManager nansen.config.project.ProjectManager
        %DataManagerApp i.e nansen.App
    end

    properties (Access = private)
        PreferenceDirectory
    end

    properties (Constant, Access = private)
        DEFAULT_USER_NAME = "default"
    end


    methods (Static)
        %instance Return a singleton instance of the NansenUserSession  
        obj = instance(userName, mode) % Method in separate file
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

        function obj = NansenUserSession(userName)
            
            import nansen.config.addons.AddonManager
            import nansen.config.project.ProjectManager

            obj.CurrentUserName = userName;

            obj.Preferences = obj.initializePreferences();
            preferenceDirectory = obj.getPrefdir();

            obj.AddonManager = AddonManager(preferenceDirectory);
            obj.ProjectManager = ProjectManager.instance(preferenceDirectory);

            obj.onStartup()
        end

        function delete(obj)
            userName = obj.CurrentUserName;
            fprintf('Closed NANSEN user session for user "%s".\n', userName)

            % Todo: A clear all statement will clear the persistent variable. How to prevent
            % that if app is open...?
        end

    end

    methods (Access = private)
    
        function prefs = initializePreferences(obj)
            prefdir = obj.getPrefdir(obj.CurrentUserName);
            obj.PreferenceDirectory = prefdir;
            % Return preferences, they can only be assigned in constructor
            prefs = nansen.internal.user.Preferences(prefdir);
        end
        
        function onStartup(obj)
        
            obj.checkIfUpdateActionsAreNeeded()

            % Check that Addons are on path.

            % Check that dependencies are installed

        end
    end

    methods (Access = private)
        
        function checkIfUpdateActionsAreNeeded(obj)
        % checkIfUpdateActionsAreNeeded - Are actions needed due to update?
        %
        %   Sometimes updates requires some one time refactoring of
        %   userdata. This method checks if that is the case, and performs
        %   necessary actions.

            if isfolder(fullfile(nansen.rootpath, '_userdata'))
                nansen.internal.user.migrateUserdata(obj)
            end
            
            % Todo: Add contents of nansen.validate here...

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