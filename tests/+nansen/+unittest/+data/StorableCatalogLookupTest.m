classdef StorableCatalogLookupTest < matlab.unittest.TestCase
    %StorableCatalogLookupTest Item lookup and field ordering in StorableCatalog
    %
    %   Run tests:
    %       runtests('nansen.unittest.data.StorableCatalogLookupTest')

    properties
        CatalogPath char
    end

    methods (TestMethodSetup)
        function createCatalog(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.CatalogPath = fullfile(fixture.Folder, 'catalog.mat');
        end
    end

    methods (Access = private)
        function catalog = catalogWithOneItem(testCase)
            catalog = nansen.integrationtest.helper.StorableCatalogFake(testCase.CatalogPath);
            item = catalog.getBlankItem();
            item.Name = 'Alpha';
            item.Value = 42;
            catalog.insertItem(item);
        end
    end

    methods (Test)

        function testGetItemByName(testCase)
            catalog = testCase.catalogWithOneItem();

            item = catalog.getItem('Alpha');

            testCase.verifyEqual(item.Name, 'Alpha')
            testCase.verifyEqual(item.Value, 42)
        end

        function testGetItemRaisesForAnUnknownName(testCase)
            % An unknown name used to give back an empty struct array, and
            % the failure then surfaced somewhere else entirely, as a
            % message about the number of outputs of an assignment.
            catalog = testCase.catalogWithOneItem();

            testCase.verifyError(@() catalog.getItem('NoSuchItem'), ...
                'NANSEN:StorableCatalog:ItemNotFound')
        end

        function testGetItemRaisesForAnUnknownUuid(testCase)
            catalog = testCase.catalogWithOneItem();

            testCase.verifyError( ...
                @() catalog.getItem('6f2b7c1e-3d4a-4f8e-9a0b-1c2d3e4f5a61'), ...
                'NANSEN:StorableCatalog:ItemNotFound')
        end

        function testGetItemByIndexIsUnchanged(testCase)
            % Numeric lookup keeps MATLAB indexing semantics, including the
            % error it raises for an index out of range.
            catalog = testCase.catalogWithOneItem();

            testCase.verifyEqual(catalog.getItem(1).Name, 'Alpha')
            testCase.verifyError(@() catalog.getItem(7), ...
                'MATLAB:badsubscript')
        end

        function testFieldOrderingMovesAnExistingUuidFirst(testCase)
            catalog = testCase.catalogWithOneItem();

            ordered = catalog.orderItemFields( ...
                struct('Name', 'Beta', 'Uuid', 'abc', 'Value', 1));

            testCase.verifyEqual(fieldnames(ordered), {'Uuid'; 'Name'; 'Value'})
        end

        function testFieldOrderingIgnoresFieldsThatOnlyLookLikeUuid(testCase)
            % validateFieldOrder asked whether "Uuid" contains any of the
            % field names, rather than whether Uuid is one of them. A field
            % named id, ui or uid is a substring of Uuid, so an item
            % without a Uuid was taken to have one and then failed when its
            % fields were reordered. Items reach this without a Uuid when a
            % catalog file is read.
            catalog = testCase.catalogWithOneItem();

            for fieldName = {'id', 'uid', 'ui'}
                item = struct(fieldName{1}, 'x', 'Name', 'Beta');

                ordered = catalog.orderItemFields(item);

                testCase.verifyEqual(fieldnames(ordered), {fieldName{1}; 'Name'}, ...
                    sprintf('A field named %s should not be taken for a Uuid.', fieldName{1}))
            end
        end
    end
end
