classdef StorableCatalogJsonTest < matlab.unittest.TestCase
    %StorableCatalogJsonTest File io tests for StorableCatalog json saving
    %
    %   Exercises utility.data.StorableCatalog saving and loading as json,
    %   against real files on disk. Converting a catalog derives the json
    %   path from the mat path, and a wrong derivation writes the catalog
    %   into a fabricated sibling folder without erroring, because the
    %   writer creates missing folders. These tests therefore assert the
    %   file location as well as its content.
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

        function testJsonIsWrittenBesideCatalogWhenFolderNameContainsMat(testCase)
            % A folder named "matlab_configs" contains the letters "mat".
            % Only the file name may change, not the folder.
            folderPath = testCase.createCatalogFolder('matlab_configs');
            catalogPath = fullfile(folderPath, 'test_catalog.mat');
            catalog = testCase.createCatalog(catalogPath);

            catalog.SaveFormat = 'json';
            catalog.save();

            testCase.verifyTrue(isfile(fullfile(folderPath, 'test_catalog.json')), ...
                'Expected the json file to be written next to the catalog.')
        end

        function testJsonIsWrittenBesideCatalogWhenFolderContainsDottedExtension(testCase)
            % A folder named "archive.mat.backup" contains the dotted
            % extension. Only the file name may change, not the folder.
            folderPath = testCase.createCatalogFolder('archive.mat.backup');
            catalogPath = fullfile(folderPath, 'test_catalog.mat');
            catalog = testCase.createCatalog(catalogPath);

            catalog.SaveFormat = 'json';
            catalog.save();

            testCase.verifyTrue(isfile(fullfile(folderPath, 'test_catalog.json')), ...
                'Expected the json file to be written next to the catalog.')
        end

        function testNoStrayFolderIsCreated(testCase)
            % A wrong extension change lands in a fabricated sibling folder,
            % which the writer would create silently, so assert the parent
            % gains nothing.
            folderPath = testCase.createCatalogFolder('matlab_configs');
            parentPath = fileparts(folderPath);
            catalogPath = fullfile(folderPath, 'test_catalog.mat');
            catalog = testCase.createCatalog(catalogPath);

            entriesBefore = testCase.listFolderNames(parentPath);

            catalog.SaveFormat = 'json';
            catalog.save();

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
            catalog.save();

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

            catalog.save();

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

        function testTheMatBackupIsNotLoadedOnceAJsonExists(testCase)
            % After conversion the mat file is only a backup. Asking for
            % the mat path must still give the current, json, catalog.
            folderPath = testCase.createCatalogFolder('configs');
            matPath = fullfile(folderPath, 'test_catalog.mat');
            catalog = testCase.createCatalog(matPath);
            catalog.SaveFormat = 'json';
            catalog.save();

            item = catalog.getBlankItem();
            item.Name = 'OnlyInJson';
            catalog.insertItem(item);

            reloaded = nansen.integrationtest.helper.StorableCatalogFake(matPath);

            testCase.verifyEqual(reloaded.FilePath, catalog.FilePath);
            testCase.verifyEqual({reloaded.Data.Name}, {'Alpha', 'OnlyInJson'});
        end

        function testSaveAsWritesInTheFormatOfTheGivenExtension(testCase)
            % saveas writes a copy where it is told, in the format the
            % extension implies, and leaves the catalog on its own file.
            folderPath = testCase.createCatalogFolder('configs');
            matPath = fullfile(folderPath, 'test_catalog.mat');
            catalog = testCase.createCatalog(matPath);

            copyPath = fullfile(folderPath, 'copy_of_catalog.json');
            catalog.saveas(copyPath);

            testCase.verifyTrue(isfile(copyPath));
            testCase.verifyFalse(isfile(fullfile(folderPath, 'copy_of_catalog.mat')));
            testCase.verifyEqual(jsondecode(fileread(copyPath)).Data.Name, 'Alpha');
            testCase.verifyEqual(catalog.FilePath, matPath);
            testCase.verifyEqual(catalog.SaveFormat, 'mat');
        end

        function testSetFilePathFollowedByLoadUsesTheSibling(testCase)
            % Pointing a mat catalog at a json path that does not exist,
            % then loading, must read the mat file beside it rather than
            % initialize an empty catalog over it.
            folderPath = testCase.createCatalogFolder('configs');
            matPath = fullfile(folderPath, 'test_catalog.mat');
            jsonPath = fullfile(folderPath, 'test_catalog.json');
            catalog = testCase.createCatalog(matPath);

            catalog.setFilePath(jsonPath);
            catalog.load();

            testCase.verifyEqual(catalog.FilePath, matPath);
            testCase.verifyEqual(catalog.SaveFormat, 'mat');
            testCase.verifyEqual({catalog.Data.Name}, {'Alpha'});
            testCase.verifyFalse(isfile(jsonPath));
        end

        function testSetFilePathToAFreshLocationAdoptsItsFormat(testCase)
            % A path in a new location has no sibling, so the catalog
            % adopts the format of the extension it was given.
            folderPath = testCase.createCatalogFolder('configs');
            catalog = testCase.createCatalog(fullfile(folderPath, 'test_catalog.mat'));

            otherPath = fullfile(testCase.createCatalogFolder('elsewhere'), 'moved.json');
            catalog.setFilePath(otherPath);
            catalog.save();

            testCase.verifyEqual(catalog.SaveFormat, 'json');
            testCase.verifyTrue(isfile(otherPath));
            testCase.verifyEqual({nansen.integrationtest.helper.StorableCatalogFake(otherPath).Data.Name}, ...
                {'Alpha'});
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
