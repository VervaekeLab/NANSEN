classdef ProjectLayoutMigrationTest < matlab.unittest.TestCase
%ProjectLayoutMigrationTest Tests for bringing a project folder to the current layout
%
%   Works on temporary folders without a user session. The tests of a
%   Configurations folder next to a configurations folder only run on a
%   case sensitive file system, where those are two folders.
%
%   Run tests:
%       runtests('nansen.unittest.config.project.ProjectLayoutMigrationTest')

    properties
        ProjectFolder (1,1) string
    end

    methods (TestMethodSetup)
        function createProjectFolder(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.ProjectFolder = fixture.Folder;

            configuration = struct('x_type', 'NANSEN Project Specification', ...
                'Properties', struct('Name', 'test_project'), 'Preferences', struct());
            utility.io.savejson(testCase.getConfigFilePath(), configuration)
        end
    end

    methods (Test)

        function testProjectWithoutVersionIsBroughtUpToDate(testCase)
            import nansen.config.project.ProjectFolderLayout

            testCase.verifyEqual(ProjectFolderLayout.read(testCase.ProjectFolder), 0)

            ProjectFolderLayout.migrate(testCase.ProjectFolder)

            testCase.verifyEqual(ProjectFolderLayout.read(testCase.ProjectFolder), ...
                ProjectFolderLayout.CURRENT_VERSION)
        end

        function testOtherConfigurationFieldsAreKept(testCase)
            nansen.config.project.ProjectFolderLayout.migrate(testCase.ProjectFolder)

            configurationText = fileread(testCase.getConfigFilePath());
            testCase.verifySubstring(configurationText, '"_type"')

            S = utility.io.loadjson(testCase.getConfigFilePath());
            testCase.verifyEqual(S.Properties.Name, 'test_project')
        end

        function testProjectAtCurrentVersionIsNotWrittenTo(testCase)
        % Opening a project must not touch a file that may be read only

            import nansen.config.project.ProjectFolderLayout

            ProjectFolderLayout.write(testCase.ProjectFolder)
            testCase.makeConfigFileReadOnly()

            testCase.verifyWarningFree(@() ProjectFolderLayout.migrate(testCase.ProjectFolder))
        end

        function testReadOnlyProjectCanStillBeOpened(testCase)
        % A step with nothing to do must not stop a project from opening

            testCase.makeConfigFileReadOnly()

            testCase.verifyWarning( ...
                @() nansen.config.project.ProjectFolderLayout.migrate(testCase.ProjectFolder), ...
                'NANSEN:Project:LayoutVersionNotStored')
        end

        function testNewerProjectIsRefused(testCase)
            import nansen.config.project.ProjectFolderLayout

            ProjectFolderLayout.write(testCase.ProjectFolder, ProjectFolderLayout.CURRENT_VERSION + 1)

            testCase.verifyError(@() ProjectFolderLayout.migrate(testCase.ProjectFolder), ...
                'NANSEN:Project:LayoutNewer')
        end

        function testFolderWithoutConfigurationFileIsLeftAlone(testCase)
        % ProjectManager.upgradeProjects has to convert such a folder first

            import nansen.config.project.ProjectFolderLayout

            delete(testCase.getConfigFilePath())

            testCase.verifyWarningFree(@() ProjectFolderLayout.migrate(testCase.ProjectFolder))
            testCase.verifyEmpty(testCase.listEntries(testCase.ProjectFolder))
        end

        function testLockIsRemovedAfterwards(testCase)
            nansen.config.project.ProjectFolderLayout.migrate(testCase.ProjectFolder)

            testCase.verifyFalse(isfile(fullfile(testCase.ProjectFolder, ".nansen_migration.lock")))
        end

        function testCurrentVersionMatchesTheLastMigrationStep(testCase)
        % A step that is added without updating CURRENT_VERSION would never run

            import nansen.config.project.ProjectFolderLayout

            steps = ProjectFolderLayout.getMigrationSteps(testCase.ProjectFolder);

            testCase.verifyEqual(max([ProjectFolderLayout.FIRST_VERSION, steps.Version]), ...
                ProjectFolderLayout.CURRENT_VERSION)
            testCase.verifyEqual(steps(1).Version, ProjectFolderLayout.FIRST_VERSION + 1)
        end

        function testCapitalizedFolderIsRenamed(testCase)
            testCase.assumeCaseSensitiveFileSystem()
            testCase.createFile("Configurations", "catalog.mat")

            nansen.config.project.ProjectFolderLayout.migrate(testCase.ProjectFolder)

            testCase.verifyTrue(isfile(fullfile(testCase.ProjectFolder, "configurations", "catalog.mat")))
            testCase.verifyFalse(isfolder(fullfile(testCase.ProjectFolder, "Configurations")))
        end

        function testCapitalizedFolderIsMergedIn(testCase)
            testCase.assumeCaseSensitiveFileSystem()
            testCase.createFile("Configurations", "catalog.mat")
            testCase.createFile("configurations", "model.mat")

            nansen.config.project.ProjectFolderLayout.migrate(testCase.ProjectFolder)

            testCase.verifyEqual(testCase.listEntries(fullfile(testCase.ProjectFolder, "configurations")), ...
                ["catalog.mat", "model.mat"])
            testCase.verifyFalse(isfolder(fullfile(testCase.ProjectFolder, "Configurations")))
        end

        function testFileInBothFoldersStaysInBoth(testCase)
            testCase.assumeCaseSensitiveFileSystem()
            testCase.createFile("Configurations", "catalog.mat", "capitalized")
            testCase.createFile("configurations", "catalog.mat", "lowercase")

            nansen.config.project.ProjectFolderLayout.migrate(testCase.ProjectFolder)

            testCase.verifyEqual(strtrim(string(fileread( ...
                fullfile(testCase.ProjectFolder, "configurations", "catalog.mat")))), "lowercase")
            testCase.verifyEqual(strtrim(string(fileread( ...
                fullfile(testCase.ProjectFolder, "Configurations", "catalog.mat")))), "capitalized")
        end

        function testCaseInsensitiveFileSystemIsLeftAsItIs(testCase)
        % The two names are one folder there, and a rename would be refused

            testCase.assumeFalse(testCase.isFileSystemCaseSensitive(), ...
                'The two names are different folders on this file system.')
            testCase.createFile("Configurations", "catalog.mat")

            nansen.config.project.ProjectFolderLayout.migrate(testCase.ProjectFolder)

            testCase.verifyTrue(isfile(fullfile(testCase.ProjectFolder, "Configurations", "catalog.mat")))
            testCase.verifyEqual(nansen.config.project.ProjectFolderLayout.read(testCase.ProjectFolder), ...
                nansen.config.project.ProjectFolderLayout.CURRENT_VERSION)
        end
    end

    methods (Access = private)

        function filePath = getConfigFilePath(testCase)
            filePath = fullfile(testCase.ProjectFolder, ...
                nansen.config.project.Project.PROJECT_CONFIG_FILENAME);
        end

        function createFile(testCase, folderName, fileName, content)
            arguments
                testCase
                folderName (1,1) string
                fileName (1,1) string
                content (1,1) string = "content"
            end

            folderPath = fullfile(testCase.ProjectFolder, folderName);
            if ~isfolder(folderPath); mkdir(folderPath); end
            writelines(content, fullfile(folderPath, fileName))
        end

        function entryNames = listEntries(~, folderPath)
            listing = dir(folderPath);
            entryNames = reshape(setdiff(string({listing.name}), [".", ".."]), 1, []);
        end

        function tf = isFileSystemCaseSensitive(testCase)
            probeFolder = fullfile(testCase.ProjectFolder, "CaseProbe");
            mkdir(probeFolder)
            tf = ~isfolder(fullfile(testCase.ProjectFolder, "caseprobe"));
            rmdir(probeFolder)
        end

        function assumeCaseSensitiveFileSystem(testCase)
            testCase.assumeTrue(testCase.isFileSystemCaseSensitive(), ...
                'The two names are one folder on this file system.')
        end

        function makeConfigFileReadOnly(testCase)
        %makeConfigFileReadOnly Remove write permission from the file for this test
        %
        %   Write protection does not apply to a superuser, in which case
        %   the failure the test needs can not be produced.

            filePath = testCase.getConfigFilePath();
            fileattrib(filePath, '-w');
            testCase.addTeardown(@() fileattrib(filePath, '+w'))

            fileId = fopen(filePath, 'a');
            if fileId ~= -1
                fclose(fileId);
                testCase.assumeFail('Write protection has no effect for this user.')
            end
        end
    end
end
