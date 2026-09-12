classdef CreateProjectTest < matlab.unittest.TestCase
    %CreateProjectTest What createProject leaves behind when it fails
    %
    %   Creating a project writes a project folder and a catalog entry, and
    %   unsets the current project while it works. A call that fails part
    %   way has to undo all of it: a folder without a catalog entry cannot
    %   be reached from the project manager, and a caller whose project was
    %   deselected has no way to know which project to select again.
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.project.CreateProjectTest')

    properties
        ProjectManager
        RootFolder (1,1) string
    end

    methods (TestMethodSetup)
        function useIsolatedCatalog(testCase)
        %useIsolatedCatalog Point the manager at a catalog of its own

            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.RootFolder = string(fixture.Folder);

            % The project manager is a singleton, so it is reset onto a
            % temporary preference directory for the duration of a test and
            % put back afterwards. Without this the tests would create
            % projects in the catalog of whoever runs them.
            testCase.ProjectManager = ...
                nansen.config.project.ProjectManager.instance(fixture.Folder, 'reset');

            testCase.addTeardown(@() ...
                nansen.config.project.ProjectManager.instance(nansen.prefdir, 'reset'));
        end
    end

    methods (Access = private)

        function projectRootDir = createProject(testCase, name)
        %createProject Create a project that is expected to succeed
            projectRootDir = fullfile(testCase.RootFolder, name);
            testCase.ProjectManager.createProject(name, 'A project', char(projectRootDir))
        end

        function folderPath = makeFolderHolding(testCase, entryName)
        %makeFolderHolding Create a folder that holds one named file
            folderPath = fullfile(testCase.RootFolder, 'occupied');
            mkdir(folderPath)
            utility.filewrite(char(fullfile(folderPath, entryName)), 'in the way')
        end

        function tryCreateProject(testCase, name, projectRootDir)
        %tryCreateProject Attempt a creation, keeping the error out of the way
            try
                testCase.ProjectManager.createProject(name, 'A project', char(projectRootDir))
            catch
                % The failure is the point of these tests. What is asserted
                % is the state left behind, which is read by the caller.
            end
        end
    end

    methods (Test)

        function testTheProjectFolderIsRemovedWhenCreationFails(testCase)
        %testTheProjectFolderIsRemovedWhenCreationFails No orphan is left
        %
        %   A hyphen makes the name invalid as a package folder, so the
        %   project fails to construct after its folder has been written.

            projectRootDir = fullfile(testCase.RootFolder, 'not-an-identifier');

            testCase.tryCreateProject('not-an-identifier', projectRootDir)

            testCase.verifyFalse(isfolder(projectRootDir))
        end

        function testNoCatalogEntryIsLeftWhenCreationFails(testCase)
            projectRootDir = fullfile(testCase.RootFolder, 'not-an-identifier');

            testCase.tryCreateProject('not-an-identifier', projectRootDir)

            testCase.verifyEqual(testCase.ProjectManager.NumProjects, 0)
        end

        function testTheCurrentProjectIsRestoredWhenCreationFails(testCase)
            testCase.createProject('alpha');
            projectRootDir = fullfile(testCase.RootFolder, 'not-an-identifier');

            testCase.tryCreateProject('not-an-identifier', projectRootDir)

            testCase.verifyEqual(testCase.ProjectManager.CurrentProject, 'alpha')
        end

        function testAFailureBeforeTheFolderIsWrittenIsReported(testCase)
        %testAFailureBeforeTheFolderIsWrittenIsReported Cleanup keeps quiet
        %
        %   The project root is placed inside a file here, so the folder
        %   cannot be created at all. Cleanup then has no folder to remove,
        %   and must not raise on its way to reporting the real failure.

            blockingFile = fullfile(testCase.RootFolder, 'blocking_file');
            utility.filewrite(char(blockingFile), 'not a folder')

            testCase.createProject('alpha');
            projectRootDir = fullfile(blockingFile, 'beta');

            testCase.verifyError( ...
                @() testCase.ProjectManager.createProject('beta', 'A project', char(projectRootDir)), ...
                'Nansen:CreateProjectFailed')

            testCase.verifyEqual(testCase.ProjectManager.CurrentProject, 'alpha')
        end

        function testANonEmptyFolderIsRefused(testCase)
            occupiedFolder = testCase.makeFolderHolding('notes.txt');

            testCase.verifyError( ...
                @() testCase.ProjectManager.createProject('beta', 'A project', char(occupiedFolder)), ...
                'NANSEN:ProjectManager:ProjectFolderExists')
        end

        function testAFolderHoldingOnlyAHiddenFileIsRefused(testCase)
        %testAFolderHoldingOnlyAHiddenFileIsRefused Hidden entries count
        %
        %   A failed creation empties the folder it was given, so a folder
        %   holding a .git directory or a similar hidden entry must not be
        %   read as empty and accepted.

            occupiedFolder = testCase.makeFolderHolding('.hidden');

            testCase.verifyError( ...
                @() testCase.ProjectManager.createProject('beta', 'A project', char(occupiedFolder)), ...
                'NANSEN:ProjectManager:ProjectFolderExists')
        end

        function testTheCurrentProjectSurvivesTheFolderExistsCheck(testCase)
        %testTheCurrentProjectSurvivesTheFolderExistsCheck Refusal changes nothing
        %
        %   The current project used to be unset before this check ran, so
        %   a refused creation left no project selected.

            occupiedFolder = testCase.makeFolderHolding('notes.txt');
            testCase.createProject('alpha');

            testCase.verifyError( ...
                @() testCase.ProjectManager.createProject('beta', 'A project', char(occupiedFolder)), ...
                'NANSEN:ProjectManager:ProjectFolderExists')

            testCase.verifyEqual(testCase.ProjectManager.CurrentProject, 'alpha')
        end

        function testAProjectCanBeCreatedIntoAnEmptyFolder(testCase)
            preparedFolder = fullfile(testCase.RootFolder, 'prepared');
            mkdir(preparedFolder)

            testCase.ProjectManager.createProject('beta', 'A project', char(preparedFolder))

            testCase.verifyTrue(testCase.ProjectManager.containsProject('beta'))
            testCase.verifyTrue(isfile(fullfile(preparedFolder, 'project.nansen.json')))
        end

        function testAFolderThatWasThereBeforeIsKeptWhenCreationFails(testCase)
        %testAFolderThatWasThereBeforeIsKeptWhenCreationFails Not ours to remove
        %
        %   Cleanup empties a folder the caller prepared rather than
        %   removing it, since removing it would delete a folder this call
        %   did not create.

            preparedFolder = fullfile(testCase.RootFolder, 'not-an-identifier');
            mkdir(preparedFolder)

            testCase.tryCreateProject('not-an-identifier', preparedFolder)

            testCase.verifyTrue(isfolder(preparedFolder))
            testCase.verifyEmpty(setdiff({dir(preparedFolder).name}, {'.', '..'}))
        end

        function testCreationCanLeaveTheCurrentProjectAlone(testCase)
            testCase.createProject('alpha');
            projectRootDir = fullfile(testCase.RootFolder, 'beta');

            testCase.ProjectManager.createProject('beta', 'A project', char(projectRootDir), false)

            testCase.verifyEqual(testCase.ProjectManager.CurrentProject, 'alpha')
            testCase.verifyTrue(testCase.ProjectManager.containsProject('beta'))
        end

        function testCreationSelectsTheNewProjectByDefault(testCase)
            testCase.createProject('alpha');

            testCase.verifyEqual(testCase.ProjectManager.CurrentProject, 'alpha')
            testCase.verifyTrue(testCase.ProjectManager.containsProject('alpha'))
        end
    end
end
