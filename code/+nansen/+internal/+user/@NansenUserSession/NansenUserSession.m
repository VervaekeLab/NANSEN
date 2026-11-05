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

        % UserDataDirectoryOverride - Directory used for this session only,
        % set when the data could not be moved to where the preference
        % points. Empty when the preference is authoritative.
        UserDataDirectoryOverride char = ''

        % RedirectedDirectory - Directory that the redirect file in the
        % default directory names. It is read when the session starts and
        % kept for the session, so that a folder that goes missing, such as
        % an unmounted drive, does not change the directory midway. Empty
        % when there is no redirect file or it names no existing folder.
        RedirectedDirectory char = ''
    end

    properties (Constant, Access = private)
        DEFAULT_USER_NAME = "default"
        LOG_UUID = false;

        % USER_DATA_FOLDER_NAMES - The folders that make up a user's data.
        % These move as a unit; the directory holding them never does.
        USER_DATA_FOLDER_NAMES = ["projects", "settings", "custom_options", "local"]
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
        %
        %   See also nansen.internal.user.NansenUserSession.getUserDataDirectory

            if ~isempty(obj.UserDataDirectoryOverride)
                folderPath = obj.UserDataDirectoryOverride;
                return
            end

            folderPath = obj.resolveUserDataDirectory( ...
                obj.Preferences.UserDataDirectory, obj.RedirectedDirectory, ...
                obj.getDefaultUserDataDirectory(obj.CurrentUserName));
        end

        function tf = isUserDataDirectoryDefault(obj)
        %isUserDataDirectoryDefault Check whether the default location is used

            tf = nansen.util.path.isSamePath(obj.getCurrentUserDataDirectory(), ...
                obj.getDefaultUserDataDirectory(obj.CurrentUserName));
        end

        function setUserDataDirectory(obj, newDirectory)
        %setUserDataDirectory Change where this user's NANSEN data is kept
        %
        %   setUserDataDirectory(obj, newDirectory) moves the folders that
        %   hold this user's NANSEN data, projects, settings,
        %   custom_options and local, into newDirectory and remembers the
        %   location for later sessions. Other files in the old and the new
        %   directory stay where they are.
        %
        %   setUserDataDirectory(obj, "") moves the data back to the default
        %   location, <userpath>/Nansen/profiles/<profile>.
        %
        %   The move is refused when newDirectory is inside the current
        %   directory or contains it, and when newDirectory already
        %   contains one of the folders named above. If a folder fails to
        %   move, the entries moved before it are moved back.
        %
        %   The location is saved in the UserDataDirectory preference of
        %   this MATLAB release. A location other than the default is also
        %   written to the file user_data_redirect.txt in the default
        %   location, which every MATLAB release reads: a release without a
        %   UserDataDirectory preference of its own uses the directory that
        %   the file names, if that directory exists. Moving the data back
        %   to the default location removes the file. Without a userpath
        %   the default location is this release's preference directory,
        %   and no redirect file is written.
        %
        %   Example:
        %       userSession = nansen.internal.user.NansenUserSession.instance();
        %       userSession.setUserDataDirectory("/Users/me/Dropbox/Nansen")
        %
        %   See also nansen.userdatadir, nansen.internal.user.UserDataRedirect

            arguments
                obj (1,1) nansen.internal.user.NansenUserSession
                newDirectory (1,1) string
            end

            newDirectory = obj.validateUserDataDirectory(newDirectory);
            oldDirectory = obj.getCurrentUserDataDirectory();

            if nansen.util.path.isSamePath(newDirectory, oldDirectory); return; end

            nansen.internal.user.validateUserDataTarget( ...
                newDirectory, oldDirectory, obj.USER_DATA_FOLDER_NAMES)

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

            isNewFolder = ~isfolder(newDirectory);
            if isNewFolder; mkdir(newDirectory); end

            try
                nansen.internal.user.moveUserDataFolders( ...
                    oldDirectory, newDirectory, obj.USER_DATA_FOLDER_NAMES)
            catch ME
                if isNewFolder
                    [~] = rmdir(newDirectory); % Removed only if empty; the output keeps rmdir from throwing
                end
                rethrow(ME)
            end

            obj.Preferences.UserDataDirectory = obj.toPreferenceValue(newDirectory);
            obj.UserDataDirectoryOverride = '';
            obj.updateUserDataRedirect(newDirectory)
            obj.ProjectManager.relocate(oldDirectory, newDirectory)

            % The old directory is the user's own when it was a chosen
            % location, or the preference directory, and either can hold
            % files that are not NANSEN's. Only an emptied one is removed.
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
            obj.RedirectedDirectory = char( nansen.internal.user.UserDataRedirect.follow( ...
                obj.getDefaultUserDataDirectory(userName)) );
            obj.warnIfUserDataDirectoryIsReleaseSpecific()

            obj.preStartup()

            obj.AddonManager = nansen.AddonManager();

            userDataDirectory = obj.getCurrentUserDataDirectory();
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

        function warnIfUserDataDirectoryIsReleaseSpecific(obj)
        %warnIfUserDataDirectoryIsReleaseSpecific Warn once when there is no userpath
        %
        %   Without a userpath there is no release independent default, so
        %   the data stays in the preference directory. The resolver is
        %   silent about it, because it runs on every path lookup.

            if strlength(obj.Preferences.UserDataDirectory) > 0; return; end
            if ~isempty(userpath()); return; end

            warning('NANSEN:UserSession:EmptyUserpath', ...
                ['MATLAB''s userpath is empty, so NANSEN keeps its data in ' ...
                 'the preference directory of this MATLAB release. Set a ' ...
                 'userpath, or set the UserDataDirectory preference, to keep ' ...
                 'it across releases.'])
        end

        function folderPath = validateUserDataDirectory(obj, newDirectory)
        %validateUserDataDirectory Check a requested directory, or supply the default

            if strlength(newDirectory) == 0
                folderPath = obj.getDefaultUserDataDirectory(obj.CurrentUserName);
                return
            end

            folderPath = nansen.util.path.stripTrailingSeparator(char(newDirectory));

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

        function updateUserDataRedirect(obj, userDataDirectory)
        %updateUserDataRedirect Point other MATLAB releases to the user data directory
        %
        %   Writes the redirect file in the default directory when the
        %   user data directory is elsewhere, and removes it when the user
        %   data directory is the default. A failure is reported as a
        %   warning, because the data has moved already and this release
        %   finds it through its preference.
        %
        %   See also nansen.internal.user.UserDataRedirect

            import nansen.internal.user.UserDataRedirect

            defaultDirectory = obj.getDefaultUserDataDirectory(obj.CurrentUserName);

            % Without a userpath the default directory is this release's
            % preference directory, which no other release reads
            if nansen.util.path.isSamePath(defaultDirectory, obj.PreferenceDirectory); return; end

            try
                if nansen.util.path.isSamePath(userDataDirectory, defaultDirectory)
                    UserDataRedirect.remove(defaultDirectory)
                    obj.RedirectedDirectory = '';
                else
                    UserDataRedirect.write(defaultDirectory, userDataDirectory)
                    obj.RedirectedDirectory = char(userDataDirectory);
                end
            catch ME
                warning('NANSEN:UserSession:UserDataRedirectNotUpdated', ...
                    ['NANSEN keeps its data in "%s", but could not update "%s", ' ...
                     'so other MATLAB releases may not find it there.\nReason: %s'], ...
                    userDataDirectory, UserDataRedirect.getFilePath(defaultDirectory), ME.message)
            end
        end

        function [tf, redirectFilePath, namedDirectory] = isUserDataRedirectBroken(obj)
        %isUserDataRedirectBroken Check for a redirect file that this session can not follow
        %
        %   True when this release has no UserDataDirectory preference and
        %   the redirect file names a directory that is not an existing
        %   folder, for example on a drive that is not connected.

            import nansen.internal.user.UserDataRedirect

            defaultDirectory = obj.getDefaultUserDataDirectory(obj.CurrentUserName);
            redirectFilePath = UserDataRedirect.getFilePath(defaultDirectory);
            namedDirectory = UserDataRedirect.read(defaultDirectory);

            tf = strlength(obj.Preferences.UserDataDirectory) == 0 ...
                && isempty(obj.RedirectedDirectory) && strlength(namedDirectory) > 0;
        end
    end

    methods (Static, Access = private)

        function folderPath = resolveUserDataDirectory(preferenceValue, redirectedDirectory, defaultDirectory)
        %resolveUserDataDirectory Choose the user data directory
        %
        %   The UserDataDirectory preference of this release comes first,
        %   then the directory that the redirect file names, and then the
        %   default location.

            if strlength(preferenceValue) > 0
                folderPath = char(preferenceValue);
            elseif strlength(redirectedDirectory) > 0
                folderPath = char(redirectedDirectory);
            else
                folderPath = char(defaultDirectory);
            end
        end

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
        %   The project catalog, the settings and the custom options used to
        %   live in the preference directory. That directory belongs to a
        %   single MATLAB release, so the data was left behind when MATLAB
        %   was upgraded. Move it to the release independent user data
        %   directory.

            preferenceDirectory = obj.getPrefdir(obj.CurrentUserName);
            userDataDirectory = obj.getCurrentUserDataDirectory();

            [isRedirectBroken, redirectFilePath, namedDirectory] = obj.isUserDataRedirectBroken();

            if isRedirectBroken
                % The data belongs in the named directory. Moving it to the
                % default directory would leave it behind there once the
                % named directory is available again.
                warning('NANSEN:UserSession:UserDataRedirectUnavailable', ...
                    ['"%s" names "%s" as the NANSEN user data directory, but ' ...
                     'that is not an existing folder. NANSEN uses "%s" for this ' ...
                     'session, and moves nothing out of MATLAB''s preference ' ...
                     'directory. Make the folder available, for example by ' ...
                     'connecting the drive that holds it, and start NANSEN again.'], ...
                    redirectFilePath, namedDirectory, userDataDirectory)

            elseif ~nansen.util.path.isSamePath(preferenceDirectory, userDataDirectory)
                % There is no release independent location when userpath is
                % empty, in which case the preference directory is used.
                obj.moveUserDataOutOfPreferenceDirectory(preferenceDirectory, userDataDirectory)
            end

            % Runs at every startup, in whichever directory this session
            % uses, so that these files are where nansen.localpath looks
            % for them also when the move above did not run or failed.
            nansen.internal.user.moveMachineLocalSettings(obj.getCurrentUserDataDirectory())
        end

        function moveUserDataOutOfPreferenceDirectory(obj, preferenceDirectory, userDataDirectory)
        %moveUserDataOutOfPreferenceDirectory Move the user data folders and report it
        %
        %   The user data directory can already hold data that another
        %   MATLAB release or another machine moved there first. That data
        %   is used, and this release's copy of each folder it holds is
        %   renamed in the preference directory instead of merged into it.
        %   The preference directory is then left without user data
        %   folders, so the move is not attempted again at the next start.
        %
        %   See also nansen.internal.user.migrateUserDataFolders

            legacyFolders = fullfile(preferenceDirectory, obj.USER_DATA_FOLDER_NAMES);
            if ~any( isfolder(legacyFolders) ); return; end

            try
                result = nansen.internal.user.migrateUserDataFolders( ...
                    preferenceDirectory, userDataDirectory, obj.USER_DATA_FOLDER_NAMES);
            catch ME
                % Use the old location for this session only. The preference
                % stays unset, so the move is attempted again next startup.
                obj.UserDataDirectoryOverride = preferenceDirectory;

                warning('NANSEN:UserSession:UserDataMigrationFailed', ...
                    ['NANSEN could not move its data from MATLAB''s preference ' ...
                     'directory, "%s", to "%s", and uses the preference directory ' ...
                     'for this session. The move is attempted again the next time ' ...
                     'NANSEN starts.\nReason: %s'], ...
                    preferenceDirectory, userDataDirectory, ME.message)
                return
            end

            % Only this release's own catalog can name project folders that
            % were kept inside its preference directory
            [~, catalogFolderName] = fileparts( ...
                nansen.config.project.ProjectManager.getCatalogDirectory(userDataDirectory));

            if ismember(catalogFolderName, result.MovedFolderNames)
                obj.repointMigratedProjectPaths(preferenceDirectory, userDataDirectory)
            end

            if isempty(result.RenamedFolderNames)
                fprintf(['NANSEN''s project catalog and configurations were moved out ' ...
                    'of MATLAB''s preference directory to "%s", so that they are kept ' ...
                    'when MATLAB is upgraded.\n'], userDataDirectory)
            else
                obj.warnUserDataSetAside(result, userDataDirectory, catalogFolderName)
            end
        end

        function warnUserDataSetAside(~, result, userDataDirectory, catalogFolderName)
        %warnUserDataSetAside Report the folders renamed instead of moved

            message = sprintf(['NANSEN uses the data in "%s", which another MATLAB ' ...
                'release or another machine moved out of MATLAB''s preference ' ...
                'directory first. This release''s copy of these folders was not ' ...
                'merged into it, and was renamed instead:\n%s'], ...
                userDataDirectory, strjoin("    " + result.RenamedFolderPaths, newline));

            if ~isempty(result.MovedFolderNames)
                message = [message, sprintf('\nThese folders were moved to "%s": %s.', ...
                    userDataDirectory, strjoin(result.MovedFolderNames, ', '))];
            end

            isCatalogRenamed = result.RenamedFolderNames == catalogFolderName;

            if any(isCatalogRenamed)
                [~, catalogFileName, catalogFileExtension] = fileparts( ...
                    nansen.config.project.ProjectManager.getCatalogPath(userDataDirectory));
                renamedCatalogPath = fullfile(result.RenamedFolderPaths(isCatalogRenamed), ...
                    [catalogFileName, catalogFileExtension]);

                message = [message, sprintf(['\nTo add a project of this release to ' ...
                    'the catalog in use, select its project folder on the Add Existing ' ...
                    'Project tab of the project manager, or call ' ...
                    'nansen.ProjectManager().importProject(projectFolder). The project ' ...
                    'folders of this release are listed in "%s".'], renamedCatalogPath)];
            end

            warning('NANSEN:UserSession:UserDataSetAside', '%s', message)
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

            [S.projectCatalog, wasChanged] = ...
                nansen.config.project.ProjectManager.repointProjectPaths( ...
                    S.projectCatalog, oldDirectory, newDirectory);

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
        %   This is, in order of precedence:
        %       1. the UserDataDirectory preference of this MATLAB release,
        %       2. the directory named by the redirect file in the default
        %          location, if that directory exists, see
        %          nansen.internal.user.UserDataRedirect,
        %       3. the default location, <userpath>/Nansen/profiles/<user>.
        %   Unlike the preference directory it does not belong to a MATLAB
        %   release, so it is not left behind when MATLAB is upgraded.
        %
        %   Note: The preference and the redirect file are read from file,
        %   because this is used when there is no session to read them
        %   from. An active session answers the same question from memory
        %   with getCurrentUserDataDirectory.
        %
        %   See also nansen.internal.user.NansenUserSession/getPrefdir

            import nansen.internal.user.NansenUserSession

            if ~nargin || isempty(userName)
                className = mfilename('class');
                userName = nansen.internal.introspection.getConstantPropertyValue(className, 'DEFAULT_USER_NAME');
            end

            preferenceDirectory = NansenUserSession.getPrefdir(userName);
            defaultDirectory = NansenUserSession.getDefaultUserDataDirectory(userName);

            preferenceValue = nansen.internal.user.Preferences.readValue(...
                preferenceDirectory, "UserDataDirectory");
            redirectedDirectory = nansen.internal.user.UserDataRedirect.follow(defaultDirectory);

            userDataDirectory = NansenUserSession.resolveUserDataDirectory( ...
                preferenceValue, redirectedDirectory, defaultDirectory);
        end

        function userDataDirectory = getDefaultUserDataDirectory(userName)
        %getDefaultUserDataDirectory Location used without a preference or redirect
        %
        %   The profiles are kept in their own folder, so that a profile
        %   name can not collide with the Projects, Add-Ons and Backup
        %   folders that NANSEN already keeps under the userpath.
        %
        %   MATLAB's userpath can be empty, in which case there is no
        %   release independent location to fall back on and the preference
        %   directory is used instead. The session warns about that once
        %   when it starts.

            userPathFolder = userpath();

            if isempty(userPathFolder)
                userDataDirectory = nansen.internal.user.NansenUserSession.getPrefdir(userName);
                return
            end

            userDataDirectory = char( fullfile(userPathFolder, 'Nansen', 'profiles', userName) );
        end
    end
end
