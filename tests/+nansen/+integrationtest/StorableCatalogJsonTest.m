classdef StorableCatalogJsonTest < matlab.unittest.TestCase
    %StorableCatalogJsonTest File io tests for StorableCatalog json saving
    %
    %   Exercises utility.data.StorableCatalog.saveas with SaveFormat set
    %   to json, against real files on disk. The json path used to be
    %   derived by substring replacement, which wrote the catalog into a
    %   fabricated sibling folder. Because the writer creates missing
    %   folders, that failed silently rather than erroring, so these tests
    %   assert the file location as well as its content.
    %
    %   Run tests:
    %       runtests('nansen.integrationtest.StorableCatalogJsonTest')

    methods (Access = private)

        function folderPath = createCatalogFolder(testCase, folderName)
        %createCatalogFolder Make a named folder inside a temporary root
            import matlab.unittest.fixtures.TemporaryFolderFixture

            fixture = testCase.applyFixture(TemporaryFolderFixture);
            folderPath = fullfile(fixture.Folder, folderName);
            mkdir(folderPath)
        end

        function catalog = createCatalog(~, catalogPath)
        %createCatalog Build a catalog holding one item
            catalog = nansen.integrationtest.helper.StorableCatalogFake(catalogPath);

            item = catalog.getBlankItem();
            item.Name = 'Alpha';
            item.Value = 42;
            catalog.insertItem(item);
        end
    end

    methods (Test)

        % ----------------------------------------------------------------
        % Where the file lands
        % ----------------------------------------------------------------

        function testJsonIsWrittenBesideCatalogWhenFolderContainsExtensionLetters(testCase)
            % Regression: a folder named "matlab_configs" contains the
            % letters "mat", which a substring replacement rewrote.
            folderPath = testCase.createCatalogFolder('matlab_configs');
            catalogPath = fullfile(folderPath, 'test_catalog.mat');
            catalog = testCase.createCatalog(catalogPath);

            catalog.SaveFormat = 'json';
            catalog.saveas(catalogPath);

            testCase.verifyTrue(isfile(fullfile(folderPath, 'test_catalog.json')), ...
                'Expected the json file to be written next to the catalog.')
        end

        function testJsonIsWrittenBesideCatalogWhenFolderContainsDottedExtension(testCase)
            % Regression: a folder named "archive.mat.backup" contains the
            % dotted extension, which the shared helper also used to rewrite.
            folderPath = testCase.createCatalogFolder('archive.mat.backup');
            catalogPath = fullfile(folderPath, 'test_catalog.mat');
            catalog = testCase.createCatalog(catalogPath);

            catalog.SaveFormat = 'json';
            catalog.saveas(catalogPath);

            testCase.verifyTrue(isfile(fullfile(folderPath, 'test_catalog.json')), ...
                'Expected the json file to be written next to the catalog.')
        end

        function testNoStrayFolderIsCreated(testCase)
            % The original defect created a whole parallel folder tree
            % rather than failing, so assert the parent gains nothing.
            folderPath = testCase.createCatalogFolder('matlab_configs');
            parentPath = fileparts(folderPath);
            catalogPath = fullfile(folderPath, 'test_catalog.mat');
            catalog = testCase.createCatalog(catalogPath);

            entriesBefore = testCase.listFolderNames(parentPath);

            catalog.SaveFormat = 'json';
            catalog.saveas(catalogPath);

            testCase.verifyEqual(testCase.listFolderNames(parentPath), entriesBefore, ...
                'Saving must not create additional folders.')
        end

        % ----------------------------------------------------------------
        % What the file contains
        % ----------------------------------------------------------------

        function testJsonContainsCatalogData(testCase)
            % The written json is parseable and carries the catalog state.
            folderPath = testCase.createCatalogFolder('matlab_configs');
            catalogPath = fullfile(folderPath, 'test_catalog.mat');
            catalog = testCase.createCatalog(catalogPath);

            catalog.SaveFormat = 'json';
            catalog.saveas(catalogPath);

            decoded = jsondecode(fileread(fullfile(folderPath, 'test_catalog.json')));

            testCase.verifyTrue(isfield(decoded, 'Data'));
            testCase.verifyTrue(isfield(decoded, 'Preferences'));
            testCase.verifyEqual(decoded.Data.Name, 'Alpha');
            testCase.verifyEqual(decoded.Data.Value, 42);
        end

        function testMatFormatIsUnaffected(testCase)
            % The default format still writes a .mat and no json.
            folderPath = testCase.createCatalogFolder('matlab_configs');
            catalogPath = fullfile(folderPath, 'test_catalog.mat');
            catalog = testCase.createCatalog(catalogPath);

            catalog.saveas(catalogPath);

            testCase.verifyTrue(isfile(catalogPath));
            testCase.verifyFalse(isfile(fullfile(folderPath, 'test_catalog.json')));
        end
    end

    methods (Static, Access = private)

        function names = listFolderNames(parentPath)
        %listFolderNames Sorted names of the subfolders of a folder
            listing = dir(parentPath);
            listing = listing([listing.isdir]);
            names = sort( setdiff({listing.name}, {'.', '..'}) );
        end
    end
end
