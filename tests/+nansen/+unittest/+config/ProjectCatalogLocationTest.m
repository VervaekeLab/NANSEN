classdef ProjectCatalogLocationTest < matlab.unittest.TestCase
% ProjectCatalogLocationTest - Tests for where the project catalog is saved
%
%   Covers the ProjectCatalogDirectory preference, moving the catalog
%   directory to another location, and the machine specific subfolder that
%   holds local project configurations.
%
%   Run tests:
%       runtests('nansen.unittest.config.ProjectCatalogLocationTest')

    properties
        ProjectManager nansen.config.project.ProjectManager

        % DefaultCatalogDirectory - Catalog directory before a test moves it
        DefaultCatalogDirectory char
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
        function getProjectManager(testCase)
            testCase.ProjectManager = nansen.ProjectManager();
            testCase.DefaultCatalogDirectory = testCase.ProjectManager.CatalogDirectory;
        end
    end

    methods (Test)

        function testCatalogDefaultsToPreferenceDirectory(testCase)
        % An unset preference keeps the catalog in the preference directory

            expectedDirectory = char( fullfile(nansen.prefdir, 'projects') );

            testCase.verifyEqual( ...
                testCase.ProjectManager.CatalogDirectory, expectedDirectory)
            testCase.verifyEqual( ...
                testCase.ProjectManager.CatalogPath, ...
                char(fullfile(expectedDirectory, testCase.CATALOG_FILENAME)))
        end

        function testSetCatalogDirectoryMovesCatalog(testCase)
        % The catalog file follows the directory, and does not stay behind

            newDirectory = testCase.moveCatalogDirectory('relocated');

            testCase.verifyEqual( ...
                testCase.ProjectManager.CatalogDirectory, char(newDirectory))
            testCase.verifyTrue( ...
                isfile(fullfile(newDirectory, testCase.CATALOG_FILENAME)))
            testCase.verifyFalse( ...
                isfile(fullfile(testCase.DefaultCatalogDirectory, testCase.CATALOG_FILENAME)))
        end

        function testSetCatalogDirectoryIsRememberedAsPreference(testCase)
        % A later session must resolve the catalog to the chosen directory

            newDirectory = testCase.moveCatalogDirectory('remembered');

            preferenceValue = nansen.internal.user.Preferences.readValue( ...
                nansen.prefdir, "ProjectCatalogDirectory");
            testCase.verifyEqual(preferenceValue, string(newDirectory))

            % This is the resolution a new user session performs on startup
            resolvedDirectory = nansen.config.project.ProjectManager.getCatalogDirectory( ...
                nansen.prefdir);
            testCase.verifyEqual(resolvedDirectory, char(newDirectory))
        end

        function testSetCatalogDirectoryToEmptyRestoresDefault(testCase)
        % An empty value moves the catalog back to the preference directory

            testCase.moveCatalogDirectory('temporary');
            testCase.ProjectManager.setCatalogDirectory("")

            testCase.verifyEqual( ...
                testCase.ProjectManager.CatalogDirectory, testCase.DefaultCatalogDirectory)
            testCase.verifyTrue( ...
                isfile(fullfile(testCase.DefaultCatalogDirectory, testCase.CATALOG_FILENAME)))

            % The default is stored as unset, so the catalog keeps following
            % the preference directory of whichever user is active
            preferenceValue = nansen.internal.user.Preferences.readValue( ...
                nansen.prefdir, "ProjectCatalogDirectory");
            testCase.verifyEqual(preferenceValue, "")
        end

        function testCurrentProjectIsPreservedAcrossMove(testCase)
        % Moving the catalog must not deselect the current project

            projectName = testCase.ProjectManager.CurrentProject;
            testCase.assumeNotEmpty(projectName)

            testCase.moveCatalogDirectory('withcurrentproject');

            testCase.verifyEqual(testCase.ProjectManager.CurrentProject, projectName)
        end

        function testSetCatalogDirectoryRefusesExistingCatalog(testCase)
        % An existing catalog must never be overwritten by the move

            newDirectory = testCase.createTemporaryDirectory('occupied');
            mkdir(newDirectory)

            projectCatalog = nansen.config.project.ProjectManager.getEmptyProjectStruct();
            save(fullfile(newDirectory, testCase.CATALOG_FILENAME), 'projectCatalog')

            testCase.verifyError( ...
                @() testCase.ProjectManager.setCatalogDirectory(newDirectory), ...
                'NANSEN:ProjectManager:CatalogExists')

            % The refused move must leave the catalog where it was
            testCase.verifyEqual( ...
                testCase.ProjectManager.CatalogDirectory, testCase.DefaultCatalogDirectory)
            testCase.verifyTrue( ...
                isfile(fullfile(testCase.DefaultCatalogDirectory, testCase.CATALOG_FILENAME)))
        end

        function testSetCatalogDirectoryRejectsRelativePath(testCase)
        % A relative path would resolve against the current folder

            testCase.verifyError( ...
                @() testCase.ProjectManager.setCatalogDirectory("relative/projects"), ...
                'NANSEN:ProjectManager:RelativeCatalogDirectory')
        end

        function testSetCatalogDirectoryRejectsMissingParent(testCase)
        % Only the directory itself is created, not a chain of parents

            temporaryDirectory = testCase.createTemporaryDirectory('missingparent');
            newDirectory = fullfile(temporaryDirectory, 'catalog');

            testCase.verifyError( ...
                @() testCase.ProjectManager.setCatalogDirectory(newDirectory), ...
                'NANSEN:ProjectManager:MissingParentDirectory')
        end

        function testLocalDirectoryIsKeyedByMachine(testCase)
        % Machines sharing a catalog directory must not share this folder

            localDirectory = testCase.ProjectManager.getLocalDirectory();

            testCase.verifyTrue( startsWith(localDirectory, ...
                char(fullfile(testCase.DefaultCatalogDirectory, 'local'))) )

            [~, machineIdentifier] = fileparts(localDirectory);
            testCase.verifyNotEmpty(machineIdentifier)
            testCase.verifyEqual( ...
                string(machineIdentifier), string(utility.system.getComputerName(true)))
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

        function testLocalConfigurationsMoveWithCatalog(testCase)
        % Machine specific configurations follow the catalog directory

            projectName = testCase.ProjectManager.CurrentProject;
            testCase.assumeNotEmpty(projectName)

            localProjectPath = nansen.config.project.ProjectManager.getProjectPath( ...
                projectName, 'local');
            markerFilePath = fullfile(localProjectPath, 'marker.txt');
            utility.filewrite(markerFilePath, 'marker')

            testCase.moveCatalogDirectory('withlocalconfigs');

            movedMarkerFilePath = fullfile( ...
                testCase.ProjectManager.getLocalDirectory(), projectName, 'marker.txt');

            testCase.verifyTrue(isfile(movedMarkerFilePath))
            testCase.verifyFalse(isfile(markerFilePath))
        end
    end

    methods (Access = private)

        function newDirectory = moveCatalogDirectory(testCase, folderName)
        %moveCatalogDirectory Move the catalog, and move it back afterwards

            newDirectory = testCase.createTemporaryDirectory(folderName);
            testCase.ProjectManager.setCatalogDirectory(newDirectory)

            % Added after the temporary folder fixture, so that teardown
            % moves the catalog back before the folder is removed.
            testCase.addTeardown( ...
                @() testCase.ProjectManager.setCatalogDirectory("") )
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
