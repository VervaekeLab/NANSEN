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
            userProfileName = sprintf('test%d', randi(999));
            fixture.addTeardown( ...
                @() fixture.deleteUserProfile(userProfileName) )
            
            warnState = warning('off', 'Nansen:NoProjectsAvailable');
            warningCleanup = onCleanup(@() warning(warnState));

            fixture.UserSession = ...
                nansen.internal.user.NansenUserSession.instance(...
                userProfileName, "force");

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
            warnState = warning('off', 'NANSEN:UserSession:UserSessionActive');
            warningCleanup = onCleanup(@() warning(warnState));

            nansen.internal.user.NansenUserSession.instance(profileName, "force");

            projectManager = nansen.ProjectManager();
            if any(strcmp({projectManager.Catalog.Name}, fixture.MockProjectName))
                projectManager.removeProject(fixture.MockProjectName, true, true)
            end

            nansen.internal.user.NansenUserSession.instance(profileName, "reset");

            profileFolder = fullfile(prefdir, 'Nansen', profileName);
            if isfolder(profileFolder)
                rmdir(profileFolder, "s")
            end
        end
    end
end
