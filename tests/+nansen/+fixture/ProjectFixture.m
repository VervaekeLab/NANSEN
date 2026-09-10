classdef ProjectFixture < matlab.unittest.fixtures.Fixture
% PROJECTFIXTURE - Fixture for creating a temporary NANSEN project for testing.
%
% See also matlab.unittest.fixtures.Fixture nansen.config.Project.Project
    properties (Constant)
        MockProjectName = 'MockProject'
    end

    properties
        % TypesOutputFolder - Folder to output generated types for test
        % classes that share this fixture
        ProjectFolder (1,1) string
        UserSession
    end

    methods
        function setup(fixture)
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.TemporaryFolderFixture
            
            % Use a fixture to add the NANSEN folder to the search path
            fixture.applyFixture( PathFixture( nansen.toolboxdir() ) );

            % Use a fixture to create a temporary working directory
            F = fixture.applyFixture( TemporaryFolderFixture );

            % Create a user profile for testing. Todo: make fixture
            % The profile folder lives in prefdir, which all MATLAB processes
            % on a machine share, and every fresh MATLAB process starts from
            % the same default RNG seed, so a name drawn with randi can repeat
            % across test processes that start together. A uuid is unique per
            % process and per fixture instance. The "test" prefix keeps leftover
            % profiles recognisable.
            userProfileName = sprintf('test_%s', nansen.util.getuuid());
            fixture.addTeardown( ...
                @() fixture.deleteUserProfile(userProfileName) )
            
            warnState = warning('off', 'Nansen:NoProjectsAvailable');
            warningCleanup = onCleanup(@() warning(warnState));

            % ConfirmNewUser is disabled because the fixture creates a
            % throwaway profile and must not block on user input.
            fixture.UserSession = ...
                nansen.internal.user.NansenUserSession.instance(...
                userProfileName, "force", ConfirmNewUser=false);

            datasetFolder = fullfile(F.Folder, 'mock_dataset');
            projectFolder = fullfile(F.Folder, 'mock_project');
            nansen.mock.createMockProject(fixture.MockProjectName, projectFolder, datasetFolder)

            fixture.applyFixture( PathFixture(F.Folder) );

            % Save the folder containing cached namespaces and NWB type classes
            % on the fixture object
            fixture.ProjectFolder = F.Folder;
        end
    end

    methods (Access = private)
        function deleteUserProfile(fixture, profileName)
        %deleteUserProfile Remove the mock project and the test profile
        %
        %   The project manager belongs to the active user session, and
        %   another profile may be active by the time teardown runs. The
        %   test profile is therefore activated first, and only the mock
        %   project is removed from it, by name.
            import nansen.internal.user.NansenUserSession

            warnState = warning('off', 'NANSEN:UserSession:UserSessionActive');
            warningCleanup = onCleanup(@() warning(warnState));

            NansenUserSession.instance(profileName, "force");

            projectManager = nansen.ProjectManager();
            if any(strcmp({projectManager.Catalog.Name}, fixture.MockProjectName))
                projectManager.removeProject(fixture.MockProjectName, true, true)
            end

            % Resolve both before the preference file naming the user data
            % directory is removed along with the preference directory.
            preferenceDirectory = NansenUserSession.getPrefdir(profileName);
            userDataDirectory = NansenUserSession.getUserDataDirectory(profileName);

            NansenUserSession.instance(profileName, "reset");

            % The two coincide when userpath is empty
            if ~nansen.util.path.isSamePath(userDataDirectory, preferenceDirectory) ...
                    && isfolder(userDataDirectory)
                rmdir(userDataDirectory, "s")
            end
            if isfolder(preferenceDirectory)
                rmdir(preferenceDirectory, "s")
            end
        end
    end
end
