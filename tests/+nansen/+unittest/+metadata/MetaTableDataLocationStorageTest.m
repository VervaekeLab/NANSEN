classdef MetaTableDataLocationStorageTest < matlab.unittest.TestCase
    %MetaTableDataLocationStorageTest Data locations are stored without local paths
    %
    %   A metatable records where a session's data is as the uuid of the
    %   data location, the uid of its root path and the subfolders below
    %   that root. The absolute root path and the values derived with it
    %   belong to whoever opens the table, and are rebuilt on load.
    %
    %   Run tests:
    %       runtests('nansen.unittest.metadata.MetaTableDataLocationStorageTest')

    properties
        TestDir char
    end

    methods (TestClassSetup)
        function setupProject(testCase)
            testCase.applyFixture(nansen.fixture.ProjectFixture)
        end
    end

    methods (TestMethodSetup)
        function createTestDirectory(testCase)
            testCase.TestDir = tempname;
            mkdir(testCase.TestDir);
            testCase.addTeardown(@() rmdir(testCase.TestDir, 's'));
        end
    end

    methods (TestMethodTeardown)
        function resetCache(~)
            nansen.metadata.MetaTableCache.instance("reset");
        end
    end

    methods (Access = private)

        function dlStruct = makeStoredDataLocation(testCase, model)
        %makeStoredDataLocation The struct a metatable is meant to hold
            dlStruct = struct('Uuid', {}, 'RootUid', {}, 'Subfolders', {});

            for i = 1:model.NumDataLocations
                item = model.getItem(i);
                testCase.assertNotEmpty(item.RootPath, ...
                    'The mock project should give every data location a root path.')

                dlStruct(i).Uuid = item.Uuid;
                dlStruct(i).RootUid = item.RootPath(1).Key;
                dlStruct(i).Subfolders = fullfile('sub-01', 'ses-01');
            end
        end

        function metaTable = makeMetaTable(testCase, dlStruct)
            entries = table({'sub-01_ses-01'}, {dlStruct}, ...
                'VariableNames', {'sessionID', 'DataLocation'});

            metaTable = nansen.unittest.metadata.helper.MetaTableFake( ...
                entries, ...
                'MetaTableClass', 'nansen.metadata.type.Session', ...
                'ItemClassName', '', ...
                'MetaTableIdVarname', 'sessionID');
            metaTable.setFilepath(fullfile(testCase.TestDir, 'session_table.mat'));
        end
    end

    methods (Test)

        function testExpandAndReduceAreInverses(testCase)
            model = nansen.DataLocationModel();
            stored = testCase.makeStoredDataLocation(model);

            expanded = model.expandDataLocationInfo(stored);

            for fieldName = nansen.config.dloc.DataLocationModel.getDerivedFieldNames()
                testCase.verifyTrue(isfield(expanded, fieldName{1}), ...
                    sprintf('Expanding should add the %s field.', fieldName{1}))
            end

            item = model.getItem(1);
            testCase.verifyEqual(expanded(1).Name, item.Name)
            testCase.verifyEqual(expanded(1).RootPath, item.RootPath(1).Value)
            testCase.verifyEqual(expanded(1).RootIdx, 1)

            testCase.verifyEqual(model.reduceDataLocationInfo(expanded), stored, ...
                'Reducing an expanded struct should give back what was stored.')
        end

        function testExpandingLeavesAnUnknownDataLocationEmpty(testCase)
            % A metatable may refer to a data location that has since been
            % removed from the model. Opening it must not fail.
            model = nansen.DataLocationModel();
            stored = testCase.makeStoredDataLocation(model);
            stored(1).Uuid = 'not-a-data-location-in-this-model';

            expanded = model.expandDataLocationInfo(stored);

            testCase.verifyEmpty(expanded(1).RootPath)
            testCase.verifyEmpty(expanded(1).Name)
            testCase.verifyNotEmpty(expanded(end).RootPath, ...
                'The remaining data locations should still be expanded.')
        end

        function testValidatingPathsToleratesARemovedDataLocation(testCase)
            % The app refreshes every entry's root path from the model
            % through validateDataLocationPaths. An entry for a removed
            % data location keeps its place and is marked unresolved.
            model = nansen.DataLocationModel();
            stored = testCase.makeStoredDataLocation(model);
            stored(1).Uuid = 'not-a-data-location-in-this-model';

            validated = model.validateDataLocationPaths(stored);

            testCase.verifyTrue(isnan(validated(1).RootIdx))
            testCase.verifyEqual(validated(1).Diskname, 'N/A')
            testCase.verifyEqual(validated(end).RootIdx, 1, ...
                'The remaining data locations should still be resolved.')
        end

        function testSavedFileHoldsNoLocalPath(testCase)
            model = nansen.DataLocationModel();
            stored = testCase.makeStoredDataLocation(model);

            metaTable = testCase.makeMetaTable(model.expandDataLocationInfo(stored));
            metaTable.save(true)

            S = load(metaTable.filepath, 'MetaTableEntries');
            savedDataLocation = S.MetaTableEntries.DataLocation{1};

            testCase.verifyEqual(sort(fieldnames(savedDataLocation)), ...
                sort({'Uuid'; 'RootUid'; 'Subfolders'}), ...
                'Only the fields identifying the data location should be stored.')

            rootPaths = {model.getItem(1).RootPath.Value};
            testCase.verifyFalse(contains(jsonencode(savedDataLocation), rootPaths{1}), ...
                'The saved struct should not contain an absolute root path.')
        end

        function testLoadingRebuildsThePaths(testCase)
            model = nansen.DataLocationModel();
            stored = testCase.makeStoredDataLocation(model);

            metaTable = testCase.makeMetaTable(model.expandDataLocationInfo(stored));
            metaTable.save(true)

            reloaded = nansen.unittest.metadata.helper.MetaTableFake();
            reloaded.setFilepath(metaTable.filepath);
            reloaded.load()

            actual = reloaded.entries.DataLocation{1};
            item = model.getItem(1);

            testCase.verifyEqual(actual(1).Uuid, stored(1).Uuid)
            testCase.verifyEqual(actual(1).Subfolders, stored(1).Subfolders)
            testCase.verifyEqual(actual(1).RootPath, item.RootPath(1).Value, ...
                'The root path should be rebuilt from the model on load.')
            testCase.verifyEqual(actual(1).Name, item.Name)
            testCase.verifyEqual(actual(1).RootIdx, 1)
        end

        function testAMetatableWrittenOnAnotherMachineResolvesLocally(testCase)
            % The point of the change: a file written where the data sat
            % under one absolute path opens where it sits under another.
            model = nansen.DataLocationModel();
            stored = testCase.makeStoredDataLocation(model);

            foreign = model.expandDataLocationInfo(stored);
            [foreign.RootPath] = deal('/somewhere/that/does/not/exist');

            metaTable = testCase.makeMetaTable(foreign);
            metaTable.save(true)

            reloaded = nansen.unittest.metadata.helper.MetaTableFake();
            reloaded.setFilepath(metaTable.filepath);
            reloaded.load()

            actual = reloaded.entries.DataLocation{1};
            testCase.verifyEqual(actual(1).RootPath, model.getItem(1).RootPath(1).Value, ...
                'The root path of the machine opening the file should win.')
        end

        function testLegacyEntriesAreLeftAlone(testCase)
            % Entries written before data locations had a uuid store a
            % struct whose fields are data location names.
            legacy = struct('MockData', '/old/path/sub-01/ses-01');

            metaTable = testCase.makeMetaTable(legacy);
            metaTable.save(true)

            reloaded = nansen.unittest.metadata.helper.MetaTableFake();
            reloaded.setFilepath(metaTable.filepath);
            reloaded.load()

            testCase.verifyEqual(reloaded.entries.DataLocation{1}, legacy)
        end

        function testSavingADummyKeepsTheMasterExpanded(testCase)
            % A dummy hands its entries to the master when it is saved. The
            % master is opened through load, so its entries are expanded
            % and stay cached that way. The dummy's entries must arrive in
            % the same form. Otherwise identical entries look changed, the
            % master is rewritten, and the cached master is left holding
            % the reduced form.
            model = nansen.DataLocationModel();
            stored = testCase.makeStoredDataLocation(model);
            expanded = model.expandDataLocationInfo(stored);

            masterTable = testCase.registerMasterTable(expanded);
            S = load(masterTable.filepath, 'VersionNumber');
            versionBeforeDummy = S.VersionNumber;

            % Registering saves the dummy, which synchronizes it to the master.
            testCase.registerDummyTable(masterTable, expanded);

            S = load(masterTable.filepath, 'VersionNumber');
            testCase.verifyEqual(S.VersionNumber, versionBeforeDummy, ...
                'A dummy whose entries match the master must not rewrite it.')

            cachedMaster = nansen.metadata.MetaTable.open(masterTable.filepath);
            testCase.verifyTrue(isfield(cachedMaster.entries.DataLocation{1}, 'RootPath'), ...
                'The master must keep its expanded entries after a dummy synchronizes.')
        end

        function testSynchronizingFromTheMasterExpandsTheDummy(testCase)
            % Entries pulled from the master file arrive in the stored
            % form. They must be expanded like entries read from the
            % dummy's own file, so that a dummy never holds the stored
            % form in memory.
            model = nansen.DataLocationModel();
            stored = testCase.makeStoredDataLocation(model);
            expanded = model.expandDataLocationInfo(stored);

            masterTable = testCase.registerMasterTable(expanded);
            dummyTable = testCase.registerDummyTable(masterTable, expanded);

            nansen.getCurrentProject().MetaTableCatalog.synchronizeFromMaster(dummyTable);

            actual = dummyTable.entries.DataLocation{1};
            testCase.verifyTrue(isfield(actual, 'RootPath'), ...
                'Entries pulled from the master must be expanded.')
            testCase.verifyEqual(actual(1).RootPath, model.getItem(1).RootPath(1).Value)
        end
    end

    methods (Access = private)

        function masterTable = registerMasterTable(testCase, dlStruct)
        %registerMasterTable Register a master table holding one entry
            catalog = nansen.getCurrentProject().MetaTableCatalog;

            masterTable = nansen.metadata.MetaTable( ...
                testCase.makeEntries(dlStruct), ...
                'MetaTableClass', 'table', ...
                'MetaTableIdVarname', 'sessionID');
            catalog.registerMetaTable(masterTable, struct( ...
                'MetaTableName', sprintf('MasterTable_%09d', randi(1e9)), ...
                'IsDefault', false, ...
                'IsMaster', true));
        end

        function dummyTable = registerDummyTable(testCase, masterTable, dlStruct)
        %registerDummyTable Register a dummy of the master with the same entry
            catalog = nansen.getCurrentProject().MetaTableCatalog;

            dummyTable = nansen.metadata.MetaTable( ...
                testCase.makeEntries(dlStruct), ...
                'MetaTableClass', 'table', ...
                'MetaTableIdVarname', 'sessionID');
            dummyTable.setAsDummy();
            S = dummyTable.toStruct('metatable_file');
            S.MetaTableKey = masterTable.MetaTableKey;
            dummyTable.fromStruct(S);
            catalog.registerMetaTable(dummyTable, struct( ...
                'MetaTableName', sprintf('DummyTable_%09d', randi(1e9)), ...
                'IsDefault', false, ...
                'IsMaster', false));
        end

        function entries = makeEntries(~, dlStruct)
            entries = table({'sub-01_ses-01'}, {dlStruct}, ...
                'VariableNames', {'sessionID', 'DataLocation'});
        end
    end
end
