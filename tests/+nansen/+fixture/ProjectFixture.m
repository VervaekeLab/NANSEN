classdef ProjectFixture < matlab.unittest.fixtures.Fixture
% PROJECTFIXTURE - Fixture for creating a temporary NANSEN project for testing.
%
% See also matlab.unittest.fixtures.Fixture nansen.config.Project.Project
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
            
            fixture.UserSession = ...
                nansen.internal.user.NansenUserSession.instance(...
                userProfileName, "force");

            datasetFolder = fullfile(F.Folder, 'mock_dataset');
            projectFolder = fullfile(F.Folder, 'mock_project');
            nansen.mock.createMockProject('MockProject', projectFolder, datasetFolder)

            fixture.applyFixture( PathFixture(F.Folder) );

            % Save the folder containing cached namespaces and NWB type classes
            % on the fixture object
            fixture.ProjectFolder = F.Folder;
        end
    end

    methods (Access = private)
        function deleteUserProfile(~, profileName)

            project = nansen.getCurrentProject();
            project.removeFromSearchPath();

            nansen.internal.user.NansenUserSession.instance(profileName, "reset");
            rmdir(fullfile(prefdir, 'Nansen', profileName), "s")
        end
    end
end
