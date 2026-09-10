classdef UserDataDirectoryTest < matlab.unittest.TestCase
% UserDataDirectoryTest - Tests for where NANSEN keeps a user's data
%
%   Covers the UserDataDirectory preference, moving the directory, the
%   project catalog that is derived from it, and the machine specific
%   subfolder holding local project configurations.
%
%   Run tests:
%       runtests('nansen.unittest.config.UserDataDirectoryTest')

    properties
        UserSession nansen.internal.user.NansenUserSession
        ProjectManager nansen.config.project.ProjectManager

        % DefaultDirectory - User data directory before a test moves it
        DefaultDirectory char
    end

    properties (Constant)
        CATALOG_FILENAME = 'project_catalog.mat'
    end

    methods (TestClassSetup)
        function setupProject(testCase)
            testCase.applyFixture(nansen.fixture.ProjectFixture)
        end
    end

    methods (TestMethodSetup)
        function getSession(testCase)
            testCase.UserSession = nansen.internal.user.NansenUserSession.instance();
            testCase.ProjectManager = nansen.ProjectManager();
            testCase.DefaultDirectory = testCase.UserSession.getCurrentUserDataDirectory();
        end
    end

    methods (Test)

        function testDefaultIsReleaseIndependent(testCase)
        % The default location must not sit inside the preference directory

            testCase.assumeNotEmpty(userpath())

            testCase.verifyTrue(testCase.UserSession.isUserDataDirectoryDefault())
            testCase.verifyTrue(startsWith(testCase.DefaultDirectory, userpath()))
            testCase.verifyFalse(startsWith(testCase.DefaultDirectory, prefdir()))
        end

        function testCatalogIsDerivedFromUserDataDirectory(testCase)
        % The catalog lives in a "projects" folder of the user data directory

            testCase.verifyEqual(testCase.ProjectManager.CatalogDirectory, ...
                char(fullfile(testCase.DefaultDirectory, 'projects')))
            testCase.verifyEqual(testCase.ProjectManager.CatalogPath, ...
                char(fullfile(testCase.DefaultDirectory, 'projects', testCase.CATALOG_FILENAME)))
        end

        function testSetUserDataDirectoryMovesTheCatalog(testCase)
        % The catalog follows the directory, and does not stay behind

            newDirectory = testCase.moveUserDataDirectory('relocated');

            testCase.verifyEqual(testCase.UserSession.getCurrentUserDataDirectory(), ...
                char(newDirectory))
            testCase.verifyTrue( ...
                isfile(fullfile(newDirectory, 'projects', testCase.CATALOG_FILENAME)))
            testCase.verifyFalse( ...
                isfile(fullfile(testCase.DefaultDirectory, 'projects', testCase.CATALOG_FILENAME)))

            % The project manager must follow, not keep the stale path
            testCase.verifyEqual(testCase.ProjectManager.CatalogDirectory, ...
                char(fullfile(newDirectory, 'projects')))
        end

        function testSetUserDataDirectoryIsRemembered(testCase)
        % A later session must resolve to the chosen directory

            newDirectory = testCase.moveUserDataDirectory('remembered');

            preferenceValue = nansen.internal.user.Preferences.readValue( ...
                nansen.prefdir, "UserDataDirectory");
            testCase.verifyEqual(preferenceValue, string(newDirectory))

            % This is the resolution a new user session performs on startup
            resolved = nansen.internal.user.NansenUserSession.getUserDataDirectory( ...
                testCase.UserSession.CurrentUserName);
            testCase.verifyEqual(resolved, char(newDirectory))
        end

        function testEmptyValueRestoresTheDefault(testCase)
        % An empty value moves everything back under the userpath

            testCase.moveUserDataDirectory('temporary');
            testCase.UserSession.setUserDataDirectory("")

            testCase.verifyEqual(testCase.UserSession.getCurrentUserDataDirectory(), ...
                testCase.DefaultDirectory)
            testCase.verifyTrue(testCase.UserSession.isUserDataDirectoryDefault())

            % The default is stored as unset, so it keeps following userpath
            preferenceValue = nansen.internal.user.Preferences.readValue( ...
                nansen.prefdir, "UserDataDirectory");
            testCase.verifyEqual(preferenceValue, "")
        end

        function testCurrentProjectIsPreservedAcrossMove(testCase)
        % Moving must not deselect the current project

            projectName = testCase.ProjectManager.CurrentProject;
            testCase.assumeNotEmpty(projectName)

            testCase.moveUserDataDirectory('withcurrentproject');

            testCase.verifyEqual(testCase.ProjectManager.CurrentProject, projectName)
        end

        function testRefusesDirectoryHoldingACatalog(testCase)
        % An existing catalog must never be overwritten by the move

            newDirectory = testCase.createTemporaryDirectory('occupied');
            mkdir(fullfile(newDirectory, 'projects'))

            projectCatalog = nansen.config.project.ProjectManager.getEmptyProjectStruct();
            save(fullfile(newDirectory, 'projects', testCase.CATALOG_FILENAME), 'projectCatalog')

            testCase.verifyError( ...
                @() testCase.UserSession.setUserDataDirectory(newDirectory), ...
                'NANSEN:UserSession:UserDataDirectoryInUse')

            % The refused move must leave everything where it was
            testCase.verifyEqual(testCase.UserSession.getCurrentUserDataDirectory(), ...
                testCase.DefaultDirectory)
            testCase.verifyTrue( ...
                isfile(fullfile(testCase.DefaultDirectory, 'projects', testCase.CATALOG_FILENAME)))
        end

        function testRejectsRelativePath(testCase)
        % A relative path would resolve against the current folder

            testCase.verifyError( ...
                @() testCase.UserSession.setUserDataDirectory("relative/nansen"), ...
                'NANSEN:UserSession:RelativeUserDataDirectory')
        end

        function testRejectsMissingParent(testCase)
        % Only the directory itself is created, not a chain of parents

            temporaryDirectory = testCase.createTemporaryDirectory('missingparent');
            newDirectory = fullfile(temporaryDirectory, 'nansen');

            testCase.verifyError( ...
                @() testCase.UserSession.setUserDataDirectory(newDirectory), ...
                'NANSEN:UserSession:MissingParentDirectory')
        end

        function testLocalDirectoryIsKeyedByMachine(testCase)
        % Machines sharing a user data directory must not share this folder

            machineIdentifier = string(utility.system.getComputerName(true));

            testCase.verifyEqual(nansen.localdatadir(), ...
                char(fullfile(testCase.DefaultDirectory, 'local', machineIdentifier)))

            % Project configurations sit under the machine folder
            testCase.verifyEqual(testCase.ProjectManager.getLocalDirectory(), ...
                char(fullfile(nansen.localdatadir(), 'projects')))
        end

        function testSharedConfigurationsResolveUnderUserData(testCase)
        % Settings and options belong to the user, not to a machine

            testCase.verifyEqual(nansen.localpath('user_settings'), ...
                char(fullfile(testCase.DefaultDirectory, 'settings')))
            testCase.verifyEqual(nansen.localpath('custom_options'), ...
                char(fullfile(testCase.DefaultDirectory, 'custom_options')))
        end

        function testMachineStateResolvesUnderLocalDirectory(testCase)
        % Queued tasks and watched folders name state of one machine

            testCase.verifyEqual(nansen.localpath('TaskList'), ...
                char(fullfile(nansen.localdatadir(), 'task_list.mat')))
            testCase.verifyEqual(nansen.localpath('WatchFolderCatalog'), ...
                char(fullfile(nansen.localdatadir(), 'watch_folder_catalog.mat')))
        end

        function testSharedConfigurationsMoveWithTheDirectory(testCase)
        % Settings and options follow the user data directory

            settingsMarker = fullfile(nansen.localpath('user_settings'), 'marker.txt');
            optionsMarker = fullfile(nansen.localpath('custom_options'), 'marker.txt');
            utility.filewrite(settingsMarker, 'marker')
            utility.filewrite(optionsMarker, 'marker')

            newDirectory = testCase.moveUserDataDirectory('withsharedconfigs');

            testCase.verifyTrue(isfile(fullfile(newDirectory, 'settings', 'marker.txt')))
            testCase.verifyTrue(isfile(fullfile(newDirectory, 'custom_options', 'marker.txt')))
            testCase.verifyFalse(isfile(settingsMarker))
            testCase.verifyFalse(isfile(optionsMarker))
        end

        function testLocalProjectPathIsUnderLocalDirectory(testCase)
        % Local project configurations live in the machine specific folder

            projectName = testCase.ProjectManager.CurrentProject;
            testCase.assumeNotEmpty(projectName)

            localProjectPath = nansen.config.project.ProjectManager.getProjectPath( ...
                projectName, 'local');

            expectedPath = char( fullfile( ...
                testCase.ProjectManager.getLocalDirectory(), projectName) );

            testCase.verifyEqual(char(localProjectPath), expectedPath)
            testCase.verifyTrue(isfolder(localProjectPath))
        end

        function testLocalConfigurationsMoveWithTheDirectory(testCase)
        % Machine specific configurations follow the user data directory

            projectName = testCase.ProjectManager.CurrentProject;
            testCase.assumeNotEmpty(projectName)

            localProjectPath = nansen.config.project.ProjectManager.getProjectPath( ...
                projectName, 'local');
            markerFilePath = fullfile(localProjectPath, 'marker.txt');
            utility.filewrite(markerFilePath, 'marker')

            testCase.moveUserDataDirectory('withlocalconfigs');

            movedMarkerFilePath = fullfile( ...
                testCase.ProjectManager.getLocalDirectory(), projectName, 'marker.txt');

            testCase.verifyTrue(isfile(movedMarkerFilePath))
            testCase.verifyFalse(isfile(markerFilePath))
        end
    end

    methods (Access = private)

        function newDirectory = moveUserDataDirectory(testCase, folderName)
        %moveUserDataDirectory Move the directory, and move it back afterwards

            newDirectory = testCase.createTemporaryDirectory(folderName);
            testCase.UserSession.setUserDataDirectory(newDirectory)

            % Added after the temporary folder fixture, so that teardown
            % moves the data back before the folder is removed.
            testCase.addTeardown( ...
                @() testCase.UserSession.setUserDataDirectory("") )
        end

        function folderPath = createTemporaryDirectory(testCase, folderName)
        %createTemporaryDirectory Get a path within a temporary folder
        %
        %   The folder itself is not created, so that callers can use it to
        %   test both an existing and a missing directory.

            import matlab.unittest.fixtures.TemporaryFolderFixture

            temporaryFolder = testCase.applyFixture(TemporaryFolderFixture);
            folderPath = fullfile(temporaryFolder.Folder, folderName);
        end
    end
end
