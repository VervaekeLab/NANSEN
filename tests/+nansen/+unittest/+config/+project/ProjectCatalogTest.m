classdef ProjectCatalogTest < matlab.unittest.TestCase
    %ProjectCatalogTest Recording projects in the catalog by name
    %
    %   The catalog is the record of which projects exist and where they
    %   live. createProject writes to it as the last step of creating a
    %   project, after the project folder is already on disk, so an entry
    %   that is refused here leaves a project folder that no longer has a
    %   catalog entry to reach it by.
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.project.ProjectCatalogTest')

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

        function testContainsProjectMatchesNamesInFull(testCase)
        %testContainsProjectMatchesNamesInFull A name is not a substring test
        %
        %   containsProject used to report a project as present whenever its
        %   name appeared anywhere inside the name of a project that was in
        %   the catalog.

            testCase.ProjectManager.addProject('alpha_recordings', 'First', '/tmp/one')

            testCase.verifyTrue(testCase.ProjectManager.containsProject('alpha_recordings'))
            testCase.verifyFalse(testCase.ProjectManager.containsProject('alpha'))
            testCase.verifyFalse(testCase.ProjectManager.containsProject('recordings'))
        end

        function testContainsProjectAcceptsAStringName(testCase)
            testCase.ProjectManager.addProject('alpha', 'First', '/tmp/one')

            testCase.verifyTrue(testCase.ProjectManager.containsProject("alpha"))
        end

        function testCatalogWithoutShortNamesLoads(testCase)
        %testCatalogWithoutShortNamesLoads Each entry gets its name as short name
        %
        %   Catalogs saved by older versions have no ShortName field. The
        %   catalog is loaded when a user session starts, so a failure here
        %   stops NANSEN from starting.

            testCase.writeCatalogFile(struct( ...
                'Name', {'alpha', 'beta'}, ...
                'Description', {'First', 'Second'}, ...
                'Path', {'/tmp/one', '/tmp/two'}))

            testCase.ProjectManager.loadCatalog()

            catalog = testCase.ProjectManager.Catalog;
            testCase.verifyEqual({catalog.ShortName}, {'alpha', 'beta'})
        end

        function testEmptyCatalogWithoutShortNamesAcceptsAProject(testCase)
        %testEmptyCatalogWithoutShortNamesAcceptsAProject The field is added
        %
        %   A new entry has a ShortName field, and a struct array only
        %   accepts an element with the same fields as its own.

            testCase.writeCatalogFile(struct('Name', {}, 'Description', {}, 'Path', {}))

            testCase.ProjectManager.loadCatalog()
            testCase.ProjectManager.addProject('alpha', 'A project', '/tmp/alpha')

            testCase.verifyEqual(testCase.ProjectManager.ProjectNames, "alpha")
        end

        function testProjectPathIsLoadedAsCharacterVector(testCase)
        %testProjectPathIsLoadedAsCharacterVector A saved string is converted
        %
        %   The project upgrade builds folder names by concatenating this
        %   path with character vectors, which gives a string array when
        %   the path is a string.

            testCase.writeCatalogFile(struct('Name', 'alpha', 'ShortName', 'alpha', ...
                'Description', 'A project', 'Path', "/tmp/alpha"))

            testCase.ProjectManager.loadCatalog()

            testCase.verifyEqual(testCase.ProjectManager.Catalog(1).Path, '/tmp/alpha')
        end

        function testMainCatalogGetsEntryFields(testCase)
        %testMainCatalogGetsEntryFields The fields match those of a new entry
        %
        %   A catalog saved on the main branch has a Preferences field and
        %   no ShortName. ProjectManagerUI addresses the fields by position.

            testCase.writeCatalogFile(testCase.createMainFormatCatalog())

            testCase.ProjectManager.loadCatalog()

            newEntry = nansen.config.project.ProjectManager.getEmptyProjectStruct();
            testCase.verifyEqual(fieldnames(testCase.ProjectManager.Catalog), fieldnames(newEntry))
        end

        function testMainCatalogAcceptsProject(testCase)
        %testMainCatalogAcceptsProject A new entry fits a catalog saved on main

            testCase.writeCatalogFile(testCase.createMainFormatCatalog())

            testCase.ProjectManager.loadCatalog()
            testCase.ProjectManager.addProject('beta', 'Second', '/tmp/two')

            testCase.verifyEqual(testCase.ProjectManager.ProjectNames, ["alpha", "beta"])
        end
    end

    methods (Access = private)
        function writeCatalogFile(testCase, projectCatalog)
        %writeCatalogFile Replace the catalog file of the isolated catalog

            catalogPath = testCase.ProjectManager.CatalogPath;
            catalogFolder = fileparts(catalogPath);
            if ~isfolder(catalogFolder); mkdir(catalogFolder); end

            save(catalogPath, 'projectCatalog')
        end
    end

    methods (Static, Access = private)
        function catalog = createMainFormatCatalog()
        %createMainFormatCatalog Create a catalog with the fields saved on main

            catalog = struct('Name', 'alpha', 'Description', 'First', ...
                'Path', '/tmp/one', 'Preferences', struct());
        end
    end
end
