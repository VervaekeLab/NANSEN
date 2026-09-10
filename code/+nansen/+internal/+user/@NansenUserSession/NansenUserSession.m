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
%   [ ] Clear projectmanager instance when user session is deleted
%   [ ] Add DataManager app when it is initialized and shut it down
%   properly when a user session is ended.
%   [ ] If DataManager app is shut down independently, DataManagerApp
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

    properties (Constant, Access = private)
        SINGLETON_NAME = "NansenUserSessionSingleton"
    end

    methods (Static)
        %instance Return a singleton instance of the NansenUserSession
        obj = instance(userName, mode, skipProjectCheck) % Method in separate file

        function reset()
            singletonName = nansen.internal.user.NansenUserSession.SINGLETON_NAME;
            if isappdata(0, singletonName)
                delete( getappdata(0, singletonName) )
                rmappdata(0, singletonName)
            end
        end
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
        function am = getAddonManager(~)
        %getAddonManager Get the AddonManager singleton.
            warning("NANSEN:UserSession:DeprecatedMethod", ...
                "Deprecated - use nansen.AddonManager() directly")
            am = nansen.AddonManager();
        end

        function pm = getProjectManager(obj)
            pm = obj.ProjectManager;
        end

        function folderPath = getCurrentUserDataDirectory(obj)
        %getCurrentUserDataDirectory Directory holding this user's NANSEN data

            folderPath = obj.getUserDataDirectory(obj.CurrentUserName);
        end

        function tf = isUserDataDirectoryDefault(obj)
        %isUserDataDirectoryDefault Check whether the default location is used

            tf = nansen.util.path.isSamePath( ...
                obj.getCurrentUserDataDirectory(), ...
                obj.getDefaultUserDataDirectory(obj.CurrentUserName));
        end

        function setUserDataDirectory(obj, newDirectory)
        %setUserDataDirectory Change where this user's NANSEN data is kept
        %
        %   setUserDataDirectory(obj, newDirectory) moves the project
        %   catalog, and the configurations kept alongside it, into
        %   newDirectory and remembers the location for later sessions.
        %
        %   setUserDataDirectory(obj, "") moves everything back to the
        %   default location under MATLAB's userpath.
        %
        %   The move is refused when newDirectory already holds a project
        %   catalog, so that an existing one is never overwritten.
        %
        %   Example:
        %       userSession = nansen.internal.user.NansenUserSession.instance();
        %       userSession.setUserDataDirectory("/Users/me/Dropbox/Nansen")
        %
        %   See also nansen.userdatadir

            arguments
                obj (1,1) nansen.internal.user.NansenUserSession
                newDirectory (1,1) string
            end

            newDirectory = obj.resolveUserDataDirectory(newDirectory);
            oldDirectory = obj.getCurrentUserDataDirectory();

            if nansen.util.path.isSamePath(newDirectory, oldDirectory); return; end

            obj.assertNoCatalogAt(newDirectory)

            % Cached project objects, and the current project's entries on
            % the search path, both point into the old directory. Restore
            % the current project on the way out, whether or not the move
            % succeeds.
            currentProjectName = obj.ProjectManager.CurrentProject;
            if ~isempty(currentProjectName)
                obj.ProjectManager.changeProject('', "Verbose", false)
                restoreCurrentProject = onCleanup( ...
                    @() obj.ProjectManager.changeProject(currentProjectName, "Verbose", false) );
            end
            obj.ProjectManager.reset()

            nansen.internal.system.moveFolderContents(oldDirectory, newDirectory)

            obj.Preferences.UserDataDirectory = obj.toPreferenceValue(newDirectory);
            obj.ProjectManager.relocate(oldDirectory, newDirectory)

            if isfolder(oldDirectory) && obj.isEmptyFolder(oldDirectory)
                rmdir(oldDirectory)
            end

            fprintf('NANSEN user data directory was changed to "%s"\n', newDirectory)
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

            import nansen.config.project.ProjectManager
            obj.CurrentUserName = userName;
            obj.SkipProjectCheck = skipProjectCheck;

            obj.Preferences = obj.initializePreferences();

            obj.preStartup()

            obj.AddonManager = nansen.AddonManager();

            userDataDirectory = obj.getUserDataDirectory(obj.CurrentUserName);
            obj.ProjectManager = ProjectManager.instance(userDataDirectory, 'reset');

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

    methods (Access = private) % User data directory helpers

        function folderPath = resolveUserDataDirectory(obj, newDirectory)
        %resolveUserDataDirectory Validate a requested user data directory

            if strlength(newDirectory) == 0
                folderPath = obj.getDefaultUserDataDirectory(obj.CurrentUserName);
                return
            end

            folderPath = char(newDirectory);

            if ~nansen.util.path.isAbsolutePath(folderPath)
                error('NANSEN:UserSession:RelativeUserDataDirectory', ...
                    ['"%s" is a relative path. Provide an absolute path, so ' ...
                     'that the directory is found independently of the ' ...
                     'current folder.'], folderPath)
            end

            parentDirectory = fileparts(folderPath);
            if ~isfolder(parentDirectory)
                error('NANSEN:UserSession:MissingParentDirectory', ...
                    ['The parent directory "%s" does not exist. Create it ' ...
                     'before moving the NANSEN user data directory.'], parentDirectory)
            end
        end

        function assertNoCatalogAt(~, folderPath)
        %assertNoCatalogAt Refuse a directory that already holds a catalog

            catalogPath = nansen.config.project.ProjectManager.getCatalogPath(folderPath);

            if isfile(catalogPath)
                error('NANSEN:UserSession:UserDataDirectoryInUse', ...
                    ['"%s" already holds a NANSEN project catalog. Select a ' ...
                     'directory without one, or remove the existing catalog ' ...
                     'first.'], folderPath)
            end
        end

        function preferenceValue = toPreferenceValue(obj, folderPath)
        %toPreferenceValue Convert a directory to the value stored in preferences
        %
        %   The default location is stored as an empty value, so that the
        %   directory keeps following the userpath rather than being
        %   pinned to the path it happened to resolve to.

            defaultDirectory = obj.getDefaultUserDataDirectory(obj.CurrentUserName);

            if nansen.util.path.isSamePath(folderPath, defaultDirectory)
                preferenceValue = "";
            else
                preferenceValue = string(folderPath);
            end
        end
    end

    methods (Static, Access = private)

        function tf = isEmptyFolder(folderPath)
        %isEmptyFolder Check whether a folder has no entries left

            listing = dir(folderPath);
            listing = listing( ~ismember({listing.name}, {'.', '..'}) );
            tf = isempty(listing);
        end
    end

    methods (Access = private) % Callbacks

        function onCurrentProjectChangedInPreferences(obj, ~, ~)
        % Set new current project in project manager.
            if obj.isPreferenceListenerActive('CurrentProjectName')
                newProjectName = char(string(obj.Preferences.CurrentProjectName));
                currentProjectName = char(string(obj.ProjectManager.CurrentProject));
                if strcmp(newProjectName, currentProjectName)
                    return
                end
                obj.ProjectManager.setProject(newProjectName)
            end
        end

        function onCurrentProjectChangedInProjectManager(obj, ~, evt)
        % Update value for current project in preferences. Make sure that
        % this is not triggering an event, to avoid infinite update loop.
            obj.deactivatePreferenceListener('CurrentProjectName')
            cleanupObj = onCleanup(@() obj.activatePreferenceListener('CurrentProjectName'));
            obj.Preferences.CurrentProjectName = evt.NewProjectName;
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

            obj.migrateUserDataFromPreferenceDirectory()
        end

        function migrateUserDataFromPreferenceDirectory(obj)
        %migrateUserDataFromPreferenceDirectory Move data out of the preference directory
        %
        %   The project catalog, and the project configurations kept next
        %   to it, used to live in the preference directory. That directory
        %   belongs to a single MATLAB release, so the data was left behind
        %   when MATLAB was upgraded. Move it to the release independent
        %   user data directory.

            preferenceDirectory = obj.getPrefdir(obj.CurrentUserName);
            userDataDirectory = obj.getUserDataDirectory(obj.CurrentUserName);

            % There is no release independent location when userpath is
            % empty, in which case the preference directory is still used.
            if nansen.util.path.isSamePath(preferenceDirectory, userDataDirectory)
                return
            end

            legacyFolder = fullfile(preferenceDirectory, 'projects');
            if ~isfolder(legacyFolder); return; end

            targetFolder = fullfile(userDataDirectory, 'projects');

            try
                nansen.internal.system.moveFolderContents(legacyFolder, targetFolder)
            catch ME
                % Keep using the old location, so that a failed move does
                % not start NANSEN with an empty project catalog.
                obj.Preferences.UserDataDirectory = string(preferenceDirectory);

                warning('NANSEN:UserSession:UserDataMigrationFailed', ...
                    ['NANSEN could not move its project data out of MATLAB''s ' ...
                     'preference directory, and keeps using "%s" for now.\n%s'], ...
                    preferenceDirectory, ME.message)
                return
            end

            rmdir(legacyFolder)
            obj.repointMigratedProjectPaths(preferenceDirectory, userDataDirectory)

            fprintf(['NANSEN''s project data was moved out of MATLAB''s preference ' ...
                'directory to\n"%s",\nso that it is kept when MATLAB is upgraded.\n'], ...
                userDataDirectory)
        end

        function repointMigratedProjectPaths(~, oldDirectory, newDirectory)
        %repointMigratedProjectPaths Update project paths that moved along
        %
        %   An older installation can keep project folders inside the
        %   preference directory. The project manager does not exist yet at
        %   this point, so the catalog is updated on file.

            catalogPath = nansen.config.project.ProjectManager.getCatalogPath(newDirectory);
            if ~isfile(catalogPath); return; end

            S = load(catalogPath, 'projectCatalog');
            oldDirectory = nansen.util.path.stripTrailingSeparator(oldDirectory);

            wasChanged = false;

            for i = 1:numel(S.projectCatalog)
                projectPath = S.projectCatalog(i).Path;
                if ~nansen.util.path.isSubPath(projectPath, oldDirectory); continue; end

                relativePath = extractAfter(string(projectPath), strlength(oldDirectory));
                S.projectCatalog(i).Path = char( fullfile(newDirectory, char(relativePath)) );
                wasChanged = true;
            end

            if wasChanged
                save(catalogPath, '-struct', 'S')
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

            obj.ProjectManager.migrateLocalProjectFolders()

            obj.ProjectManager.checkProjectsExist()

            if obj.ProjectManager.hasUnversionedProjects()
                obj.ProjectManager.upgradeProjects()
            end

            if ispref('Nansen', 'CurrentProject')
                currentProject = getpref('Nansen', 'CurrentProject');
                try
                    obj.ProjectManager.changeProject(currentProject)
                catch
                    warning("NANSEN:UserSession:ChangeProjectFailed", ...
                        "Failed to change project to `%s` for user `%s`", ...
                        currentProject, obj.CurrentUserName)
                end
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
                userName = nansen.internal.introspection.getConstantPropertyValue(className, 'DEFAULT_USER_NAME');
            end
            preferenceDirectory = fullfile(prefdir, 'Nansen', userName);
        end

        function userDataDirectory = getUserDataDirectory(userName)
        %getUserDataDirectory Get the directory holding a user's NANSEN data
        %
        %   userDataDirectory = getUserDataDirectory(userName) returns the
        %   directory that holds the project catalog and the configurations
        %   belonging to the named user.
        %
        %   This is the UserDataDirectory preference when one is set, and
        %   the default location under MATLAB's userpath otherwise. Unlike
        %   the preference directory it does not belong to a MATLAB
        %   release, so it is not left behind when MATLAB is upgraded, and
        %   it can be placed on a shared or synchronized folder.
        %
        %   Note: The preference is read from file rather than from the
        %   session, because this runs while the session is still being
        %   constructed.
        %
        %   See also nansen.internal.user.NansenUserSession/getPrefdir

            import nansen.internal.user.NansenUserSession

            if ~nargin || isempty(userName)
                className = mfilename('class');
                userName = nansen.internal.introspection.getConstantPropertyValue(className, 'DEFAULT_USER_NAME');
            end

            preferenceDirectory = NansenUserSession.getPrefdir(userName);

            userDataDirectory = nansen.internal.user.Preferences.readValue(...
                preferenceDirectory, "UserDataDirectory");

            if strlength(userDataDirectory) == 0
                userDataDirectory = NansenUserSession.getDefaultUserDataDirectory(userName);
            end
            userDataDirectory = char(userDataDirectory);
        end

        function userDataDirectory = getDefaultUserDataDirectory(userName)
        %getDefaultUserDataDirectory Location used while the preference is unset
        %
        %   The profiles are kept in their own folder, so that a profile
        %   name can not collide with the Projects, Add-Ons and Backup
        %   folders that NANSEN already keeps under the userpath.
        %
        %   MATLAB's userpath can be empty, in which case there is no
        %   release independent location to fall back on and the preference
        %   directory is used instead.

            userPathFolder = userpath();

            if isempty(userPathFolder)
                warning('NANSEN:UserSession:EmptyUserpath', ...
                    ['MATLAB''s userpath is empty, so NANSEN keeps its data ' ...
                     'in the preference directory of this MATLAB release. ' ...
                     'Set a userpath, or set the UserDataDirectory ' ...
                     'preference, to keep it across releases.'])
                userDataDirectory = nansen.internal.user.NansenUserSession.getPrefdir(userName);
                return
            end

            userDataDirectory = char( fullfile(userPathFolder, 'Nansen', 'profiles', userName) );
        end
    end
end
