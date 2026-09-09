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

        function testItemsAreWrittenAsAJsonArray(testCase)
            % Data must be a json array whatever its length, so that a
            % reader in another language does not have to tell a
            % one-element list from an object.
            folderPath = testCase.createCatalogFolder('configs');
            catalogPath = fullfile(folderPath, 'test_catalog.json');
            catalog = testCase.createCatalog(catalogPath);

            catalog.save();

            raw = jsondecode(fileread(catalogPath));
            testCase.verifyClass(raw.Data, 'struct');
            testCase.verifyEqual(numel(raw.Data), 1);
            testCase.verifyTrue(contains(fileread(catalogPath), '"Data": ['), ...
                'A single item must still be written inside a json array.')
        end

        function testEmptyCatalogIsWrittenAsAnEmptyArray(testCase)
            folderPath = testCase.createCatalogFolder('configs');
            catalogPath = fullfile(folderPath, 'test_catalog.json');

            catalog = nansen.integrationtest.helper.StorableCatalogFake(catalogPath);

            testCase.verifyTrue(isfile(catalogPath));
            testCase.verifyTrue(contains(fileread(catalogPath), '"Data": []'));
            testCase.verifyClass(catalog.Data, 'struct');
            testCase.verifyEmpty(catalog.Data);
        end
    end

    % --------------------------------------------------------------------
    % Reading back
    % --------------------------------------------------------------------

    methods (Test)

        function testJsonCatalogRoundTrips(testCase)
            % Writing and reloading must give back the same items, with the
            % shapes jsondecode would otherwise have changed.
            folderPath = testCase.createCatalogFolder('configs');
            catalogPath = fullfile(folderPath, 'test_catalog.json');

            catalog = testCase.createCatalog(catalogPath);
            item = catalog.getBlankItem();
            item.Name = 'Beta';
            item.Value = 7;
            catalog.insertItem(item);

            reloaded = nansen.integrationtest.helper.StorableCatalogFake(catalogPath);

            testCase.verifyEqual(size(reloaded.Data), [1 2]);
            testCase.verifyEqual({reloaded.Data.Name}, {'Alpha', 'Beta'});
            testCase.verifyEqual([reloaded.Data.Value], [42 7]);
            testCase.verifyEqual(fieldnames(reloaded.Data), fieldnames(catalog.Data));
        end

        function testCatalogFallsBackToTheMatFileWhenNoJsonExists(testCase)
            % Projects written before json storage ask for a .json path but
            % only have a .mat beside it.
            folderPath = testCase.createCatalogFolder('configs');
            matPath = fullfile(folderPath, 'test_catalog.mat');
            testCase.createCatalog(matPath);

            catalog = nansen.integrationtest.helper.StorableCatalogFake( ...
                fullfile(folderPath, 'test_catalog.json'));

            testCase.verifyEqual(catalog.FilePath, matPath);
            testCase.verifyEqual({catalog.Data.Name}, {'Alpha'});
            testCase.verifyFalse(isfile(fullfile(folderPath, 'test_catalog.json')), ...
                'Loading must not convert the catalog on its own.')
        end

        function testConvertingToJsonRepointsTheCatalog(testCase)
            % Setting the format and saving is the conversion path. The mat
            % file is left in place as a backup.
            folderPath = testCase.createCatalogFolder('configs');
            matPath = fullfile(folderPath, 'test_catalog.mat');
            catalog = testCase.createCatalog(matPath);

            catalog.SaveFormat = 'json';
            catalog.save();

            jsonPath = fullfile(folderPath, 'test_catalog.json');
            testCase.verifyEqual(catalog.FilePath, jsonPath);
            testCase.verifyTrue(isfile(jsonPath));
            testCase.verifyTrue(isfile(matPath));

            reloaded = nansen.integrationtest.helper.StorableCatalogFake(jsonPath);
            testCase.verifyEqual({reloaded.Data.Name}, {'Alpha'});
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
