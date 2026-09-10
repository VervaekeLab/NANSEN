classdef AddProjectTest < matlab.unittest.TestCase
    %AddProjectTest Adding an entry to the project catalog
    %
    %   The catalog is the record of which projects exist and where they
    %   live. createProject writes to it as the last step of creating a
    %   project, after the project folder is already on disk, so an entry
    %   that is refused here leaves a project folder that no longer has a
    %   catalog entry to reach it by.
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.project.AddProjectTest')

    properties
        ProjectManager
    end

    methods (TestMethodSetup)
        function useIsolatedCatalog(testCase)
        %useIsolatedCatalog Point the manager at a catalog of its own

            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);

            % The project manager is a singleton, so it is reset onto a
            % temporary preference directory for the duration of a test and
            % put back afterwards. Without this the tests would read, and
            % add projects to, the catalog of whoever runs them.
            testCase.ProjectManager = ...
                nansen.config.project.ProjectManager.instance(fixture.Folder, 'reset');

            testCase.addTeardown(@() ...
                nansen.config.project.ProjectManager.instance(nansen.prefdir, 'reset'));
        end
    end

    methods (Test)

        function testStringArgumentsAreAccepted(testCase)
        %testStringArgumentsAreAccepted A name given as a string is added
        %
        %   createProject passes its arguments through unchanged, so a
        %   project created with string arguments used to be refused here,
        %   after its folder had been created and the current project unset.

            testCase.ProjectManager.addProject("alpha", "A project", "/tmp/alpha")

            testCase.verifyEqual(testCase.ProjectManager.ProjectNames, "alpha")
        end

        function testCharArgumentsAreAccepted(testCase)
            testCase.ProjectManager.addProject('alpha', 'A project', '/tmp/alpha')

            testCase.verifyEqual(testCase.ProjectManager.ProjectNames, "alpha")
        end

        function testTextIsStoredAsCharacterVectors(testCase)
        %testTextIsStoredAsCharacterVectors An entry keeps its type on load
        %
        %   Loading the catalog casts the names to char, so an entry stored
        %   as a string would change type the first time it was read back.

            testCase.ProjectManager.addProject("alpha", "A project", "/tmp/alpha")

            entry = testCase.ProjectManager.Catalog(1);
            testCase.verifyClass(entry.Name, 'char')
            testCase.verifyClass(entry.ShortName, 'char')
            testCase.verifyClass(entry.Description, 'char')
            testCase.verifyClass(entry.Path, 'char')
        end

        function testAnInfoStructIsAccepted(testCase)
            projectInfo = struct(...
                'Name', 'alpha', ...
                'ShortName', 'alpha', ...
                'Description', 'A project', ...
                'Path', '/tmp/alpha');

            testCase.ProjectManager.addProject(projectInfo)

            testCase.verifyEqual(testCase.ProjectManager.ProjectNames, "alpha")
        end

        function testANameContainedInAnExistingNameIsAccepted(testCase)
        %testANameContainedInAnExistingNameIsAccepted Names match in full
        %
        %   The duplicate check used to be a substring test, which refused
        %   any new name that appeared anywhere in the name of a project
        %   that was already in the catalog.

            testCase.ProjectManager.addProject('alpha_recordings', 'First', '/tmp/one')
            testCase.ProjectManager.addProject('alpha', 'Second', '/tmp/two')

            testCase.verifyEqual(testCase.ProjectManager.ProjectNames, ...
                ["alpha_recordings", "alpha"])
        end

        function testADuplicateNameIsRefused(testCase)
            testCase.ProjectManager.addProject('alpha', 'First', '/tmp/one')

            testCase.verifyError( ...
                @() testCase.ProjectManager.addProject('alpha', 'Second', '/tmp/two'), ...
                'Nansen:ProjectExists')
        end

        function testAnIncompleteArgumentListIsRefused(testCase)
            testCase.verifyError( ...
                @() testCase.ProjectManager.addProject('alpha', 'Only a description'), ...
                'Nansen:ProjectManager:InvalidInput')
        end

        function testAnUnsupportedArgumentIsRefused(testCase)
            testCase.verifyError( ...
                @() testCase.ProjectManager.addProject(42), ...
                'Nansen:ProjectManager:InvalidInput')
        end
    end
end
