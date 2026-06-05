classdef MetaTableTest < matlab.unittest.TestCase
    % MetaTableTest - Unit tests for MetaTable class
    %
    %   This test suite covers the main functionality of the MetaTable class:
    %   - Construction and initialization
    %   - Adding and removing entries
    %   - Adding and removing table variables
    %   - Saving and loading
    %   - Master/dummy MetaTable relationships
    %   - Table formatting and data retrieval
    %   - MetaObject caching
    %
    %   Run tests:
    %       runtests('nansen.unittest.metadata.MetaTableTest')

    % Todo (project dependent - future):
    % [ ] Adding entries with expansion (custom table variables exist)
    % [ ] Remove variables (if it was removed from project)

    properties
        TestDir char
        TestMetaTable nansen.unittest.metadata.helper.MetaTableFake
        TestEntries table
        TempFiles cell = {}
    end

    properties (Constant)
        NUM_TEST_ENTRIES = 5
    end

    methods (TestClassSetup)
        function setupTestEnvironment(~)
            % Ensure required classes are on path
            if ~exist('nansen.metadata.MetaTable', 'class')
                error('MetaTable class not found on path');
            end
        end
        function setupProject(testCase)
            testCase.applyFixture(nansen.fixture.ProjectFixture)
        end
    end

    methods (TestMethodSetup)
        function createTestDirectory(testCase)
            % Create temporary directory for test files
            testCase.TestDir = tempname;
            mkdir(testCase.TestDir);
            testCase.addTeardown(@() rmdir(testCase.TestDir, 's'));
        end

        function createTestEntries(testCase)
            % Create sample table entries for testing
            numEntries = testCase.NUM_TEST_ENTRIES;

            % Generate test data
            ids = arrayfun(@(i) sprintf('test_id_%03d', i), 1:numEntries, 'uni', 0)';
            names = arrayfun(@(i) sprintf('Test Entry %d', i), 1:numEntries, 'uni', 0)';
            values = randi(100, numEntries, 1);
            dates = datetime('now') - days(randi(365, numEntries, 1));
            flags = logical(randi([0, 1], numEntries, 1));

            % Create table
            testCase.TestEntries = table(ids, names, values, dates, flags, ...
                'VariableNames', {'sessionID', 'Name', 'Value', 'Date', 'Flag'});
        end

        function createTestMetaTable(testCase)
            % Create a clean MetaTable instance using testable subclass
            testCase.TestMetaTable = nansen.unittest.metadata.helper.MetaTableFake( ...
                testCase.TestEntries, ...
                'MetaTableClass', 'table', ...
                'ItemClassName', '', ...
                'MetaTableIdVarname', 'sessionID');
        end
    end

    methods (TestMethodTeardown)
        function cleanupTempFiles(testCase)
            nansen.metadata.MetaTableCache.instance("reset");

            % Clean up any temporary files created during tests
            for i = 1:numel(testCase.TempFiles)
                if isfile(testCase.TempFiles{i})
                    delete(testCase.TempFiles{i});
                end
            end
        end
    end

    %% Constructor Tests
    methods (Test)
        function testEmptyConstructor(testCase)
            % Test creating empty MetaTable
            mt = nansen.metadata.MetaTable();

            testCase.verifyClass(mt, 'nansen.metadata.MetaTable');
            testCase.verifyEmpty(mt.entries);
            testCase.verifyEmpty(mt.members);
        end

        function testConstructorWithTable(testCase)
            % Test creating MetaTable with table data
            mt = nansen.metadata.MetaTable(testCase.TestEntries, ...
                'MetaTableClass', 'table', ...
                'MetaTableIdVarname', 'sessionID');

            testCase.verifyEqual(height(mt.entries), testCase.NUM_TEST_ENTRIES);
            testCase.verifyEqual(numel(mt.members), testCase.NUM_TEST_ENTRIES);
        end

        function testConstructorWithProperties(testCase)
            % Test setting properties during construction
            className = 'test.MetaClass';
            idVarname = 'testID';

            mt = nansen.metadata.MetaTable( ...
                'MetaTableClass', className, ...
                'MetaTableIdVarname', idVarname);

            testCase.verifyEqual(mt.MetaTableClass, className);
        end
    end

    %% Property Tests
    methods (Test)
        function testIsMasterProperty(testCase)
            % Test IsMaster property
            testCase.createTestMetaTable();
            testCase.verifyTrue(testCase.TestMetaTable.IsMaster);
        end

        function testVariableNames(testCase)
            % Test VariableNames dependent property
            testCase.createTestMetaTable();

            expectedNames = testCase.TestEntries.Properties.VariableNames;
            testCase.verifyEqual(testCase.TestMetaTable.VariableNames, expectedNames);
        end

        function testMetaTableNameFromStruct(testCase)
            % Test MetaTableName assignment from persisted state
            testCase.createTestMetaTable();

            testFilePath = fullfile(testCase.TestDir, 'test_name.mat');
            testCase.TestMetaTable.setFilepath(testFilePath);
            testCase.TempFiles{end+1} = testFilePath;

            % Use toStruct to set the name indirectly
            S = testCase.TestMetaTable.toStruct('metatable_file');
            S.MetaTableName = 'TestTable';

            mt2 = nansen.metadata.MetaTable();
            mt2.fromStruct(S);

            testCase.verifyEqual(mt2.MetaTableName, 'TestTable');
        end

        function testGetTableType(testCase)
            % Test getTableType method
            testCase.createTestMetaTable();

            tableType = testCase.TestMetaTable.getTableType();
            testCase.verifyClass(tableType, 'char');
        end
    end

    %% Entry Management Tests
    methods (Test)
        function testAddTableEntries(testCase)
            % Test adding table entries
            testCase.createTestMetaTable();
            initialCount = height(testCase.TestMetaTable.entries);

            % Create new entries
            newIds = {'new_id_001', 'new_id_002'}';
            newNames = {'New Entry 1', 'New Entry 2'}';
            newValues = [999; 888];
            newDates = [datetime('now'); datetime('now')];
            newFlags = [true; false];

            newEntries = table(newIds, newNames, newValues, newDates, newFlags, ...
                'VariableNames', {'sessionID', 'Name', 'Value', 'Date', 'Flag'});

            % Add entries
            testCase.TestMetaTable.addTable(newEntries);

            % Verify
            testCase.verifyEqual(height(testCase.TestMetaTable.entries), initialCount + 2);
            testCase.verifyTrue(ismember('new_id_001', testCase.TestMetaTable.members));
        end

        function testAddTableWithoutIDs(testCase)
            % Test adding table entries without ID column (should auto-generate UUIDs)
            testCase.createTestMetaTable();
            initialCount = height(testCase.TestMetaTable.entries);

            % Create entries without ID column
            newNames = {'Auto ID Entry 1', 'Auto ID Entry 2'}';
            newValues = [777; 666];
            newDates = [datetime('now'); datetime('now')];
            newFlags = [false; true];

            newEntries = table(newNames, newValues, newDates, newFlags, ...
                'VariableNames', {'Name', 'Value', 'Date', 'Flag'});

            % Add entries
            testCase.TestMetaTable.addTable(newEntries);

            % Verify IDs were generated
            testCase.verifyEqual(height(testCase.TestMetaTable.entries), initialCount + 2);
            testCase.verifyNotEmpty(testCase.TestMetaTable.members);
        end

        function testAddDuplicateEntry(testCase)
            testCase.createTestMetaTable();
            initialCount = height(testCase.TestMetaTable.entries);

            duplicateEntry = testCase.TestMetaTable.entries(1,:);
            testCase.TestMetaTable.addTable(duplicateEntry)

            finalCount = height(testCase.TestMetaTable.entries);
            testCase.verifyEqual(initialCount, finalCount)
        end

        function testRemoveEntries(testCase)
            % Test removing entries
            testCase.createTestMetaTable();
            initialCount = height(testCase.TestMetaTable.entries);
            testCase.TestMetaTable.markClean();

            % Remove first entry
            idToRemove = testCase.TestMetaTable.members{1};
            testCase.TestMetaTable.removeEntries({idToRemove});

            % Verify
            testCase.verifyEqual(height(testCase.TestMetaTable.entries), initialCount - 1);
            testCase.verifyFalse(ismember(idToRemove, testCase.TestMetaTable.members));
            testCase.verifyFalse(testCase.TestMetaTable.isClean());
        end

        function testRemoveMultipleEntries(testCase)
            % Test removing multiple entries
            testCase.createTestMetaTable();
            initialCount = height(testCase.TestMetaTable.entries);

            % Remove first two entries
            idsToRemove = testCase.TestMetaTable.members(1:2);
            testCase.TestMetaTable.removeEntries(idsToRemove);

            % Verify
            testCase.verifyEqual(height(testCase.TestMetaTable.entries), initialCount - 2);
            testCase.verifyFalse(any(ismember(idsToRemove, testCase.TestMetaTable.members)));
        end

        function testGetEntry(testCase)
            % Test retrieving specific entries
            testCase.createTestMetaTable();

            % Get first entry
            entryId = testCase.TestMetaTable.members{1};
            entry = testCase.TestMetaTable.getEntry(entryId);

            % Verify
            testCase.verifyEqual(height(entry), 1);
            testCase.verifyEqual(entry.sessionID{1}, entryId);
        end

        function testEditEntries(testCase)
            % Test editing entry values
            testCase.createTestMetaTable();

            % Edit first entry's Value field
            newValue = 12345;
            testCase.TestMetaTable.editEntries(1, 'Value', newValue);

            % Verify
            testCase.verifyEqual(testCase.TestMetaTable.entries.Value(1), newValue);
        end
    end

    %% Table Variable Management Tests
    methods (Test)
        function testAddTableVariable(testCase)
            % Test adding a new table variable
            testCase.createTestMetaTable();

            % Add new variable
            varName = 'NewColumn';
            initValue = {0};
            testCase.TestMetaTable.addTableVariable(varName, initValue);

            % Verify
            testCase.verifyTrue(any(strcmp(testCase.TestMetaTable.VariableNames, varName)));
            testCase.verifyEqual(testCase.TestMetaTable.entries.(varName){1}, initValue{1});
        end

        function testRemoveTableVariable(testCase)
            % Test removing a table variable
            testCase.createTestMetaTable();

            % Remove existing variable
            varName = 'Value';
            testCase.TestMetaTable.removeTableVariable(varName);

            % Verify
            testCase.verifyFalse(any(strcmp(testCase.TestMetaTable.VariableNames, varName)));
        end

        function testIsVariable(testCase)
            % Test checking if variable exists
            testCase.createTestMetaTable();

            testCase.verifyTrue(testCase.TestMetaTable.isVariable('Name'));
            testCase.verifyFalse(testCase.TestMetaTable.isVariable('NonExistent'));
        end

        function testReplaceDataColumn(testCase)
            % Test replacing entire data column
            testCase.createTestMetaTable();

            % Create new values
            newValues = arrayfun(@(i) i * 10, 1:testCase.NUM_TEST_ENTRIES, 'uni', 0)';

            % Replace column
            testCase.TestMetaTable.replaceDataColumn('Value', newValues);

            % Verify
            testCase.verifyEqual(testCase.TestMetaTable.entries.Value(1), 10);
        end

        function testReplaceDataColumnChangesColumnType(testCase)
            % Replacing a column should rebuild it, allowing a type change
            % from numeric to text (the use case for resetting a variable
            % whose default value type changed).
            testCase.createTestMetaTable();

            % 'Value' starts out as a numeric column
            testCase.verifyTrue(isnumeric(testCase.TestMetaTable.entries.Value));

            newValues = arrayfun(@(i) sprintf('item_%d', i), ...
                1:testCase.NUM_TEST_ENTRIES, 'uni', 0)';
            testCase.TestMetaTable.replaceDataColumn('Value', newValues);

            % Column is now text (cellstr), with no leftover numeric data
            testCase.verifyTrue(iscell(testCase.TestMetaTable.entries.Value));
            testCase.verifyEqual(testCase.TestMetaTable.entries.Value{1}, 'item_1');
        end

        function testReplaceDataColumnAcceptsNonCellVector(testCase)
            % A non-cell vector is assigned directly to the column
            testCase.createTestMetaTable();

            newValues = (1:testCase.NUM_TEST_ENTRIES)' * 100;
            testCase.TestMetaTable.replaceDataColumn('Value', newValues);

            testCase.verifyEqual(testCase.TestMetaTable.entries.Value, newValues);
        end

        function testReplaceDataColumnRowCountMismatchErrors(testCase)
            % Mismatched element count should error and report both counts
            testCase.createTestMetaTable();

            tooFewValues = {1; 2}; % Table has NUM_TEST_ENTRIES (5) rows

            try
                testCase.TestMetaTable.replaceDataColumn('Value', tooFewValues);
                testCase.verifyFail('Expected an error for row-count mismatch');
            catch ME
                testCase.verifySubstring(ME.message, '5 rows');
                testCase.verifySubstring(ME.message, '2 elements');
            end
        end

        function testGetColumnIndex(testCase)
            % Test getting column index by name
            testCase.createTestMetaTable();

            idx = testCase.TestMetaTable.getColumnIndex('Name');
            testCase.verifyEqual(testCase.TestMetaTable.VariableNames{idx}, 'Name');
        end

        function testGetVariableName(testCase)
            % Test getting variable name by index
            testCase.createTestMetaTable();

            varName = testCase.TestMetaTable.getVariableName(1);
            testCase.verifyEqual(varName, testCase.TestMetaTable.VariableNames{1});
        end
    end

    %% Save/Load Tests
    methods (Test)
        function testSaveAndLoad(testCase)
            % Test saving and loading MetaTable
            testCase.createTestMetaTable();

            % Set filepath and name via struct
            testFilePath = fullfile(testCase.TestDir, 'test_metatable.mat');
            testCase.TestMetaTable.setFilepath(testFilePath);
            S = testCase.TestMetaTable.toStruct('metatable_file');
            S.MetaTableName = 'TestMetaTable';
            testCase.TestMetaTable.fromStruct(S);
            testCase.TempFiles{end+1} = testFilePath;

            % Save
            testCase.TestMetaTable.save();
            testCase.verifyTrue(isfile(testFilePath));

            % Load into new instance
            mt2 = nansen.metadata.MetaTable();
            % Use fromStruct to set filepath (SetAccess is restricted)
            S2 = struct('filepath', testFilePath);
            S2.MetaTableEntries = table.empty;
            mt2.fromStruct(S2);
            mt2.load();

            % Verify
            testCase.verifyEqual(height(mt2.entries), height(testCase.TestMetaTable.entries));
            testCase.verifyEqual(mt2.members, testCase.TestMetaTable.members);
        end

        function testOpenLoadsMetaTableFromFile(testCase)
            testCase.createTestMetaTable();

            testFilePath = fullfile(testCase.TestDir, 'open_metatable.mat');
            testCase.TestMetaTable.setFilepath(testFilePath);
            S = testCase.TestMetaTable.toStruct('metatable_file');
            S.MetaTableName = 'OpenMetaTable';
            testCase.TestMetaTable.fromStruct(S);
            testCase.TempFiles{end+1} = testFilePath;
            testCase.TestMetaTable.save();

            mt = nansen.metadata.MetaTable.open(testFilePath);

            expectedFilePath = nansen.metadata.MetaTableCache.canonicalizeFilePath(testFilePath);
            testCase.verifyEqual(mt.filepath, expectedFilePath);
            testCase.verifyEqual(mt.MetaTableName, 'OpenMetaTable');
            testCase.verifyEqual(mt.entries, testCase.TestMetaTable.entries);
        end

        function testOpenReturnsCachedMetaTableHandle(testCase)
            testCase.createTestMetaTable();

            testFilePath = fullfile(testCase.TestDir, 'cached_open.mat');
            testCase.TestMetaTable.setFilepath(testFilePath);
            S = testCase.TestMetaTable.toStruct('metatable_file');
            S.MetaTableName = 'CachedOpenMetaTable';
            testCase.TestMetaTable.fromStruct(S);
            testCase.TempFiles{end+1} = testFilePath;
            testCase.TestMetaTable.save();

            mt1 = nansen.metadata.MetaTable.open(testFilePath);
            mt2 = nansen.metadata.MetaTable.open(testFilePath);

            testCase.verifyTrue(mt1 == mt2);
        end

        function testOpenDoesNotStartPollingTimer(testCase)
            testCase.createTestMetaTable();

            testFilePath = fullfile(testCase.TestDir, 'cached_open_no_timer.mat');
            testCase.TestMetaTable.setFilepath(testFilePath);
            S = testCase.TestMetaTable.toStruct('metatable_file');
            S.MetaTableName = 'CachedOpenNoTimerMetaTable';
            testCase.TestMetaTable.fromStruct(S);
            testCase.TempFiles{end+1} = testFilePath;
            testCase.TestMetaTable.save();

            nansen.metadata.MetaTable.open(testFilePath);

            timers = timerfind('Name', 'MetaTableCache Polling Timer');
            testCase.verifyEmpty(timers);
        end

        function testMetaTableCacheCanonicalizeRequiresExistingFile(testCase)
            missingFilePath = fullfile(testCase.TestDir, 'missing_metatable.mat');

            testCase.verifyError( ...
                @() nansen.metadata.MetaTableCache.canonicalizeFilePath(missingFilePath), ...
                'NANSEN:MetaTableCache:FileNotFound');
        end

        function testOpenReloadsCleanStaleCachedMetaTable(testCase)
            testCase.createTestMetaTable();

            testFilePath = fullfile(testCase.TestDir, 'cached_clean_stale.mat');
            testCase.TestMetaTable.setFilepath(testFilePath);
            S = testCase.TestMetaTable.toStruct('metatable_file');
            S.MetaTableName = 'CachedCleanStaleMetaTable';
            testCase.TestMetaTable.fromStruct(S);
            testCase.TempFiles{end+1} = testFilePath;
            testCase.TestMetaTable.save();

            mt1 = nansen.metadata.MetaTable.open(testFilePath);
            eventCount = 0;
            listener = addlistener(mt1, 'TableReloadedFromDisk', @(~,~) incrementEventCount());
            testCase.addTeardown(@() delete(listener))

            fileStruct = load(testFilePath);
            fileStruct.MetaTableEntries.Value(1) = 777;
            fileStruct.VersionNumber = fileStruct.VersionNumber + 1;
            save(testFilePath, '-struct', 'fileStruct')

            mt2 = nansen.metadata.MetaTable.open(testFilePath);

            testCase.verifyTrue(mt1 == mt2);
            testCase.verifyEqual(mt2.entries.Value(1), 777);
            testCase.verifyEqual(eventCount, 1);

            function incrementEventCount()
                eventCount = eventCount + 1;
            end
        end

        function testMetaTableCacheEvictionForcesFreshLoad(testCase)
            testCase.createTestMetaTable();

            testFilePath = fullfile(testCase.TestDir, 'cached_evict.mat');
            testCase.TestMetaTable.setFilepath(testFilePath);
            S = testCase.TestMetaTable.toStruct('metatable_file');
            S.MetaTableName = 'CachedEvictMetaTable';
            testCase.TestMetaTable.fromStruct(S);
            testCase.TempFiles{end+1} = testFilePath;
            testCase.TestMetaTable.save();

            mt1 = nansen.metadata.MetaTable.open(testFilePath);
            cache = nansen.metadata.MetaTableCache.instance();
            cache.remove(testFilePath)
            mt2 = nansen.metadata.MetaTable.open(testFilePath);

            testCase.verifyFalse(mt1 == mt2);
        end

        function testMetaTableCacheFileChangedNotificationIsEdgeTriggered(testCase)
            testCase.createTestMetaTable();

            testFilePath = fullfile(testCase.TestDir, 'cached_change_event.mat');
            testCase.TestMetaTable.setFilepath(testFilePath);
            S = testCase.TestMetaTable.toStruct('metatable_file');
            S.MetaTableName = 'CachedChangeMetaTable';
            testCase.TestMetaTable.fromStruct(S);
            testCase.TempFiles{end+1} = testFilePath;
            testCase.TestMetaTable.save();

            cache = nansen.metadata.MetaTableCache.instance();
            cache.pauseFileChangeMonitoring()
            cachedMetaTable = nansen.metadata.MetaTable.open(testFilePath);
            cachedMetaTable.editEntries(1, 'Value', 555);

            eventCount = 0;
            listener = addlistener(cache, 'FileChangedOnDisk', @(~, evt) onFileChanged(evt));
            testCase.addTeardown(@() delete(listener))

            incrementDiskVersion()
            cache.checkForFileChanges()
            testCase.verifyEqual(eventCount, 1);

            cache.checkForFileChanges()
            testCase.verifyEqual(eventCount, 1);

            incrementDiskVersion()
            cache.checkForFileChanges()
            testCase.verifyEqual(eventCount, 2);

            function onFileChanged(evt)
                eventCount = eventCount + 1;
                testCase.verifyTrue(evt.MetaTable == cachedMetaTable);
            end

            function incrementDiskVersion()
                fileStruct = load(testFilePath);
                fileStruct.VersionNumber = fileStruct.VersionNumber + 1;
                save(testFilePath, '-struct', 'fileStruct')
            end
        end

        function testMetaTableCacheReloadsCleanStaleTableOnPoll(testCase)
            testCase.createTestMetaTable();

            testFilePath = fullfile(testCase.TestDir, 'cached_clean_poll.mat');
            testCase.TestMetaTable.setFilepath(testFilePath);
            S = testCase.TestMetaTable.toStruct('metatable_file');
            S.MetaTableName = 'CachedCleanPollMetaTable';
            testCase.TestMetaTable.fromStruct(S);
            testCase.TempFiles{end+1} = testFilePath;
            testCase.TestMetaTable.save();

            cache = nansen.metadata.MetaTableCache.instance();
            cache.pauseFileChangeMonitoring()
            cachedMetaTable = nansen.metadata.MetaTable.open(testFilePath);

            reloadCount = 0;
            conflictCount = 0;
            reloadListener = addlistener(cachedMetaTable, 'TableReloadedFromDisk', @(~,~) incrementReloadCount());
            conflictListener = addlistener(cache, 'FileChangedOnDisk', @(~,~) incrementConflictCount());
            testCase.addTeardown(@() delete(reloadListener))
            testCase.addTeardown(@() delete(conflictListener))

            fileStruct = load(testFilePath);
            fileStruct.MetaTableEntries.Value(1) = 888;
            fileStruct.VersionNumber = fileStruct.VersionNumber + 1;
            save(testFilePath, '-struct', 'fileStruct')

            cache.checkForFileChanges()

            testCase.verifyEqual(cachedMetaTable.entries.Value(1), 888);
            testCase.verifyTrue(cachedMetaTable.isLatestVersion());
            testCase.verifyEqual(reloadCount, 1);
            testCase.verifyEqual(conflictCount, 0);

            function incrementReloadCount()
                reloadCount = reloadCount + 1;
            end

            function incrementConflictCount()
                conflictCount = conflictCount + 1;
            end
        end

        function testMetaTableCacheDropsMissingFileOnPoll(testCase)
            testCase.createTestMetaTable();

            testFilePath = fullfile(testCase.TestDir, 'cached_missing_poll.mat');
            testCase.TestMetaTable.setFilepath(testFilePath);
            S = testCase.TestMetaTable.toStruct('metatable_file');
            S.MetaTableName = 'CachedMissingPollMetaTable';
            testCase.TestMetaTable.fromStruct(S);
            testCase.TempFiles{end+1} = testFilePath;
            testCase.TestMetaTable.save();

            cache = nansen.metadata.MetaTableCache.instance();
            cache.pauseFileChangeMonitoring()
            nansen.metadata.MetaTable.open(testFilePath);

            delete(testFilePath)

            testCase.verifyWarningFree(@() cache.checkForFileChanges());
            testCase.verifyWarningFree(@() cache.checkForFileChanges());
        end

        function testStaleNonForcedSaveErrors(testCase)
            testCase.createTestMetaTable();

            testFilePath = fullfile(testCase.TestDir, 'stale_save.mat');
            testCase.TestMetaTable.setFilepath(testFilePath);
            S = testCase.TestMetaTable.toStruct('metatable_file');
            S.MetaTableName = 'StaleSaveTable';
            testCase.TestMetaTable.fromStruct(S);
            testCase.TempFiles{end+1} = testFilePath;
            testCase.TestMetaTable.save();

            staleMetaTable = nansen.metadata.MetaTable.open(testFilePath);

            testCase.TestMetaTable.editEntries(1, 'Value', 111);
            testCase.TestMetaTable.save();

            staleMetaTable.editEntries(1, 'Value', 222);
            testCase.verifyError(@() staleMetaTable.save(), ...
                'NANSEN:VersionedFile:StaleFile');
        end

        function testLegacyVersionZeroDetectsNewerDiskVersion(testCase)
            testCase.createTestMetaTable();

            testFilePath = fullfile(testCase.TestDir, 'legacy_stale_save.mat');
            testCase.TestMetaTable.setFilepath(testFilePath);
            S = testCase.TestMetaTable.toStruct('metatable_file');
            S.MetaTableName = 'LegacyStaleSaveTable';
            testCase.TestMetaTable.fromStruct(S);
            testCase.TempFiles{end+1} = testFilePath;
            testCase.TestMetaTable.save();

            fileStruct = load(testFilePath);
            fileStruct.VersionNumber = int64(0);
            save(testFilePath, '-struct', 'fileStruct')

            legacyMetaTable = nansen.metadata.MetaTable.open(testFilePath);

            fileStruct.MetaTableEntries.Value(1) = 123;
            fileStruct.VersionNumber = int64(1);
            save(testFilePath, '-struct', 'fileStruct')

            legacyMetaTable.editEntries(1, 'Value', 456);
            testCase.verifyError(@() legacyMetaTable.save(), ...
                'NANSEN:VersionedFile:StaleFile');
        end

        function testRegisterMetaTablePersistsNonDefaultCatalogEntry(testCase)
            catalogPath = fullfile(testCase.TestDir, 'metatable_catalog.mat');
            catalog = nansen.metadata.MetaTableCatalog(catalogPath);

            metaTable = nansen.metadata.MetaTable(testCase.TestEntries, ...
                'MetaTableClass', 'table', ...
                'MetaTableIdVarname', 'sessionID');

            options = struct( ...
                'MetaTableName', 'NonDefaultTestTable', ...
                'IsDefault', false, ...
                'IsMaster', true);

            catalog.registerMetaTable(metaTable, options);
            reloadedCatalog = nansen.metadata.MetaTableCatalog(catalogPath);
            expectedFilePath = fullfile(testCase.TestDir, ...
                reloadedCatalog.Table.FileName{1});

            testCase.verifyEqual(height(reloadedCatalog.Table), 1);
            testCase.verifyEqual(reloadedCatalog.Table.MetaTableName{1}, ...
                'NonDefaultTestTable');
            testCase.verifyFalse(reloadedCatalog.Table.IsDefault(1));
            testCase.verifyFalse(ismember('SavePath', ...
                reloadedCatalog.Table.Properties.VariableNames));
            testCase.verifyEqual(reloadedCatalog.getMetaTableFilePath( ...
                'NonDefaultTestTable'), expectedFilePath);
            testCase.verifyTrue(isfile(expectedFilePath));
        end

        function testMetaTableCatalogIgnoresLegacySavePathOnLoad(testCase)
            catalogPath = fullfile(testCase.TestDir, 'metatable_catalog.mat');
            catalog = nansen.metadata.MetaTableCatalog(catalogPath);

            metaTable = nansen.metadata.MetaTable(testCase.TestEntries, ...
                'MetaTableClass', 'table', ...
                'MetaTableIdVarname', 'sessionID');

            options = struct( ...
                'MetaTableName', 'LegacySavePathTable', ...
                'IsDefault', false, ...
                'IsMaster', true);

            catalog.registerMetaTable(metaTable, options);

            metaTableCatalog = catalog.Table;
            metaTableCatalog.SavePath = {fullfile(testCase.TestDir, 'legacy_location')};
            save(catalogPath, 'metaTableCatalog')

            reloadedCatalog = nansen.metadata.MetaTableCatalog(catalogPath);

            testCase.verifyFalse(ismember('SavePath', ...
                reloadedCatalog.Table.Properties.VariableNames));
            testCase.verifyEqual(reloadedCatalog.getMetaTableFilePath( ...
                'LegacySavePathTable'), metaTable.filepath);
            testCase.verifyEqual(reloadedCatalog.getMetaTable( ...
                'LegacySavePathTable').filepath, metaTable.filepath);
        end

        function testRegisterMetaTableSelectsSingleDefaultForClass(testCase)
            catalogPath = fullfile(testCase.TestDir, 'metatable_catalog.mat');
            catalog = nansen.metadata.MetaTableCatalog(catalogPath);

            firstTable = nansen.metadata.MetaTable(testCase.TestEntries, ...
                'MetaTableClass', 'table', ...
                'MetaTableIdVarname', 'sessionID');
            secondTable = nansen.metadata.MetaTable(testCase.TestEntries, ...
                'MetaTableClass', 'table', ...
                'MetaTableIdVarname', 'sessionID');

            firstOptions = struct( ...
                'MetaTableName', 'FirstDefaultTable', ...
                'IsDefault', true, ...
                'IsMaster', true);
            secondOptions = struct( ...
                'MetaTableName', 'SecondDefaultTable', ...
                'IsDefault', true, ...
                'IsMaster', true);

            catalog.registerMetaTable(firstTable, firstOptions);
            catalog.registerMetaTable(secondTable, secondOptions);
            reloadedCatalog = nansen.metadata.MetaTableCatalog(catalogPath);

            isDefault = reloadedCatalog.Table.IsDefault;
            defaultNames = reloadedCatalog.Table.MetaTableName(isDefault);

            testCase.verifyEqual(nnz(isDefault), 1);
            testCase.verifyEqual(defaultNames{1}, 'SecondDefaultTable');
        end

        function testResolveNameToFilepathRequiresUnambiguousMatch(testCase)
            currentProject = nansen.getCurrentProject();
            catalog = currentProject.MetaTableCatalog;
            uniqueSuffix = sprintf('%09d', randi(1e9));
            firstName = ['ResolveExactTable_' uniqueSuffix '_A'];
            secondName = ['ResolveExactTable_' uniqueSuffix '_B'];

            firstTable = nansen.metadata.MetaTable(testCase.TestEntries, ...
                'MetaTableClass', 'table', ...
                'MetaTableIdVarname', 'sessionID');
            secondTable = nansen.metadata.MetaTable(testCase.TestEntries, ...
                'MetaTableClass', 'table', ...
                'MetaTableIdVarname', 'sessionID');

            catalog.registerMetaTable(firstTable, struct( ...
                'MetaTableName', firstName, ...
                'IsDefault', false, ...
                'IsMaster', true));
            catalog.registerMetaTable(secondTable, struct( ...
                'MetaTableName', secondName, ...
                'IsDefault', false, ...
                'IsMaster', true));

            filePath = nansen.metadata.MetaTable.resolveNameToFilepath(firstName);
            testCase.verifyEqual(filePath, firstTable.filepath);

            testCase.verifyError( ...
                @() nansen.metadata.MetaTable.resolveNameToFilepath( ...
                    ['ResolveExactTable_' uniqueSuffix]), ...
                'NANSEN:MetaTable:AmbiguousMetaTableName');
        end

        function testMasterDummySynchronization(testCase)
            currentProject = nansen.getCurrentProject();
            catalog = currentProject.MetaTableCatalog;
            uniqueSuffix = sprintf('%09d', randi(1e9));

            masterTable = nansen.metadata.MetaTable(testCase.TestEntries, ...
                'MetaTableClass', 'table', ...
                'MetaTableIdVarname', 'sessionID');
            masterOptions = struct( ...
                'MetaTableName', ['MasterSyncTable_' uniqueSuffix], ...
                'IsDefault', false, ...
                'IsMaster', true);
            catalog.registerMetaTable(masterTable, masterOptions);

            dummyEntries = testCase.TestEntries(1:2, :);
            dummyTable = nansen.metadata.MetaTable(dummyEntries, ...
                'MetaTableClass', 'table', ...
                'MetaTableIdVarname', 'sessionID');
            dummyTable.setAsDummy();
            S = dummyTable.toStruct('metatable_file');
            S.MetaTableKey = masterTable.MetaTableKey;
            dummyTable.fromStruct(S);

            dummyOptions = struct( ...
                'MetaTableName', ['DummySyncTable_' uniqueSuffix], ...
                'IsDefault', false, ...
                'IsMaster', false);
            catalog.registerMetaTable(dummyTable, dummyOptions);

            cachedDummy = nansen.metadata.MetaTable.open(dummyTable.filepath);
            masterTable.editEntries(1, 'Value', 333);
            masterTable.save();

            reloadedDummy = nansen.metadata.MetaTable.open(dummyTable.filepath);
            testCase.verifyTrue(cachedDummy == reloadedDummy);
            testCase.verifyEqual(reloadedDummy.entries.Value(1), 333);

            reloadedDummy.editEntries(1, 'Value', 444);
            versionInfo = load(masterTable.filepath, 'VersionNumber');
            masterVersionBeforeDummySave = versionInfo.VersionNumber;
            reloadedDummy.save();

            versionInfo = load(masterTable.filepath, 'VersionNumber');
            masterVersionAfterDummySave = versionInfo.VersionNumber;
            testCase.verifyEqual(masterVersionAfterDummySave, ...
                masterVersionBeforeDummySave + 1);

            reloadedMaster = nansen.metadata.MetaTable.open(masterTable.filepath);
            testCase.verifyEqual(reloadedMaster.entries.Value(1), 444);
        end

        function testIsClean(testCase)
            % Test isClean/markClean methods
            testCase.createTestMetaTable();

            % Initially should be modified (entries were added)
            testCase.verifyTrue(testCase.TestMetaTable.IsModified);

            % Mark clean
            testCase.TestMetaTable.markClean();
            testCase.verifyTrue(testCase.TestMetaTable.isClean());

            % Modify
            testCase.TestMetaTable.editEntries(1, 'Value', 999);
            testCase.verifyFalse(testCase.TestMetaTable.isClean());
        end

        function testEditEntriesNotifiesTableEntryChanged(testCase)
            testCase.createTestMetaTable();

            eventCount = 0;
            lastEvent = [];
            listener = addlistener(testCase.TestMetaTable, 'TableEntryChanged', ...
                @(~, evt) onEntryChanged(evt));
            testCase.addTeardown(@() delete(listener))

            testCase.TestMetaTable.editEntries(1, 'Value', 999);

            testCase.verifyEqual(eventCount, 1);
            testCase.verifyEqual(lastEvent.RowIndex, 1);
            testCase.verifyEqual(lastEvent.ColumnIndex, ...
                testCase.TestMetaTable.getColumnIndex('Value'));
            testCase.verifyEqual(lastEvent.NewValue, {999});

            function onEntryChanged(evt)
                eventCount = eventCount + 1;
                lastEvent = evt;
            end
        end

        function testEditEntriesSupportsBulkChangeEvent(testCase)
            testCase.createTestMetaTable();

            eventCount = 0;
            lastEvent = [];
            listener = addlistener(testCase.TestMetaTable, 'TableEntryChanged', ...
                @(~, evt) onEntryChanged(evt));
            testCase.addTeardown(@() delete(listener))

            rows = [1 2];
            values = [111; 222];
            testCase.TestMetaTable.editEntries(rows, 'Value', values);

            testCase.verifyEqual(eventCount, 1);
            testCase.verifyEqual(lastEvent.RowIndex, rows);
            testCase.verifyEqual(lastEvent.NewValue, num2cell(values));

            function onEntryChanged(evt)
                eventCount = eventCount + 1;
                lastEvent = evt;
            end
        end

        function testReplaceDataColumnNotifiesTableEntryChanged(testCase)
            testCase.createTestMetaTable();

            eventCount = 0;
            lastEvent = [];
            listener = addlistener(testCase.TestMetaTable, 'TableEntryChanged', ...
                @(~, evt) onEntryChanged(evt));
            testCase.addTeardown(@() delete(listener))

            values = num2cell((1:testCase.NUM_TEST_ENTRIES)' * 10);
            testCase.TestMetaTable.replaceDataColumn('Value', values);

            testCase.verifyEqual(eventCount, 1);
            testCase.verifyEqual(lastEvent.RowIndex, 1:testCase.NUM_TEST_ENTRIES);
            testCase.verifyEqual(lastEvent.ColumnIndex, ...
                testCase.TestMetaTable.getColumnIndex('Value'));
            testCase.verifyEqual(lastEvent.NewValue, values);

            function onEntryChanged(evt)
                eventCount = eventCount + 1;
                lastEvent = evt;
            end
        end

        function testMergeEntriesNotifiesChangedExistingEntries(testCase)
            testCase.createTestMetaTable();

            eventCount = 0;
            lastEvent = [];
            listener = addlistener(testCase.TestMetaTable, 'TableEntryChanged', ...
                @(~, evt) onEntryChanged(evt));
            testCase.addTeardown(@() delete(listener))

            sourceEntries = testCase.TestMetaTable.entries;
            sourceMembers = testCase.TestMetaTable.members;
            sourceEntries.Value(1) = 999;

            wasMerged = testCase.TestMetaTable.mergeEntries(sourceEntries, sourceMembers);

            testCase.verifyTrue(wasMerged);
            testCase.verifyEqual(eventCount, 1);
            testCase.verifyEqual(lastEvent.RowIndex, 1);
            testCase.verifyEqual(lastEvent.ColumnIndex, ...
                testCase.TestMetaTable.getColumnIndex('Value'));
            testCase.verifyEqual(lastEvent.NewValue, {999});

            function onEntryChanged(evt)
                eventCount = eventCount + 1;
                lastEvent = evt;
            end
        end

        function testMergeEntriesNotifiesEntryAddedForNewEntries(testCase)
            testCase.createTestMetaTable();

            entryAddedCount = 0;
            listener = addlistener(testCase.TestMetaTable, 'EntryAdded', ...
                @(~, ~) incrementEntryAddedCount());
            testCase.addTeardown(@() delete(listener))

            sourceEntries = testCase.TestMetaTable.entries(1, :);
            sourceEntries.sessionID = {'new_test_id'};
            sourceMembers = sourceEntries.sessionID;

            wasMerged = testCase.TestMetaTable.mergeEntries(sourceEntries, sourceMembers);

            testCase.verifyTrue(wasMerged);
            testCase.verifyEqual(entryAddedCount, 1);

            function incrementEntryAddedCount()
                entryAddedCount = entryAddedCount + 1;
            end
        end

        function testVersioning(testCase)
            % Test version number tracking
            testCase.createTestMetaTable();

            % Set filepath and save
            testFilePath = fullfile(testCase.TestDir, 'versioned_table.mat');
            testCase.TestMetaTable.setFilepath(testFilePath);
            S = testCase.TestMetaTable.toStruct('metatable_file');
            S.MetaTableName = 'VersionedTable';
            testCase.TestMetaTable.fromStruct(S);
            testCase.TempFiles{end+1} = testFilePath;

            % First save
            testCase.TestMetaTable.save();
            versionInfo = load(testFilePath, 'VersionNumber');
            version1 = versionInfo.VersionNumber;
            testCase.verifyEqual(testCase.TestMetaTable.getVersionNumberOnDisk(), version1);

            % Modify and save again
            testCase.TestMetaTable.editEntries(1, 'Value', 888);
            testCase.TestMetaTable.save();
            versionInfo = load(testFilePath, 'VersionNumber');
            version2 = versionInfo.VersionNumber;

            % Verify version incremented
            testCase.verifyEqual(version2, version1 + 1);
        end

        function testSavedVersionNumberPersists(testCase)
            % Test that saved files persist the version number
            testCase.createTestMetaTable();

            % Save with version
            testFilePath = fullfile(testCase.TestDir, 'version_test.mat');
            testCase.TestMetaTable.setFilepath(testFilePath);
            S = testCase.TestMetaTable.toStruct('metatable_file');
            S.MetaTableName = 'VersionTest';
            testCase.TestMetaTable.fromStruct(S);
            testCase.TempFiles{end+1} = testFilePath;
            testCase.TestMetaTable.save();

            savedVersionInfo = load(testFilePath, 'VersionNumber');
            savedVersion = savedVersionInfo.VersionNumber;

            mt2 = nansen.metadata.MetaTable();
            S2 = struct('filepath', testFilePath);
            S2.MetaTableEntries = table.empty;
            mt2.fromStruct(S2);
            mt2.load();

            testCase.verifyEqual(mt2.VersionNumber, savedVersion);
        end
    end

    %% Struct Conversion Tests
    methods (Test)
        function testToStruct(testCase)
            % Test converting MetaTable to struct
            testCase.createTestMetaTable();

            % Set name via struct (since MetaTableName is private)
            S = testCase.TestMetaTable.toStruct('metatable_file');
            S.MetaTableName = 'StructTest';

            mt2 = nansen.metadata.MetaTable();
            mt2.fromStruct(S);
            S = mt2.toStruct('metatable_file');

            testCase.verifyTrue(isstruct(S));
            testCase.verifyTrue(isfield(S, 'MetaTableMembers'));
            testCase.verifyTrue(isfield(S, 'MetaTableEntries'));
            testCase.verifyTrue(isfield(S, 'MetaTableName'));
        end

        function testFromStruct(testCase)
            % Test creating MetaTable from struct
            testCase.createTestMetaTable();

            % Convert to struct and set name
            S = testCase.TestMetaTable.toStruct('metatable_file');
            S.MetaTableName = 'FromStructTest';

            % Create new MetaTable and load from struct
            mt2 = nansen.metadata.MetaTable();
            mt2.fromStruct(S);

            % Verify using public methods
            testCase.verifyEqual(mt2.MetaTableName, 'FromStructTest');
            testCase.verifyEqual(height(mt2.entries), height(testCase.TestMetaTable.entries));
        end
    end

    %% Sorting Tests
    methods (Test)
        function testSort(testCase)
            % Test sorting entries by ID
            testCase.createTestMetaTable();

            % Shuffle entries - use testable subclass method
            shuffledIdx = randperm(height(testCase.TestMetaTable.entries));
            shuffledEntries = testCase.TestMetaTable.entries(shuffledIdx, :);
            testCase.TestMetaTable.setEntries(shuffledEntries);

            % Sort
            testCase.TestMetaTable.sort();

            % Verify sorted using public members property
            sortedMembers = sort(testCase.TestMetaTable.members);
            testCase.verifyEqual(testCase.TestMetaTable.members, sortedMembers);
        end
    end

    %% Formatting Tests
    methods (Test)
        function testGetFormattedTableData(testCase)
            % Test formatting table data for display
            testCase.createTestMetaTable();

            % Get formatted data
            formattedTable = nansen.metadata.utility.formatTableForDisplay(...
                testCase.TestMetaTable);

            % Verify returns a table
            testCase.verifyClass(formattedTable, 'table');
            testCase.verifyEqual(height(formattedTable), height(testCase.TestMetaTable.entries));
        end

        function testGetFormattedTableDataSubset(testCase)
            % Test formatting subset of table data
            testCase.createTestMetaTable();

            % Get formatted data for specific columns and rows
            colIndices = [1, 2];
            rowIndices = [1, 2, 3];
            formattedTable = nansen.metadata.utility.formatTableForDisplay(...
                testCase.TestMetaTable, colIndices, rowIndices);

            % Verify
            testCase.verifyEqual(height(formattedTable), 3);
            testCase.verifyEqual(width(formattedTable), 2);
        end
    end

    %% Static Method Tests
    methods (Test)
        function testNormalizeIdentifier(testCase)
            % Test normalizing different ID formats

            % Numeric
            numericIds = [1, 2, 3];
            normalized = nansen.metadata.MetaTable.normalizeIdentifier(numericIds);
            testCase.verifyClass(normalized, 'cell');

            % String
            stringIds = ["id1", "id2"];
            normalized = nansen.metadata.MetaTable.normalizeIdentifier(stringIds);
            testCase.verifyClass(normalized, 'cell');

            % Cell array
            cellIds = {'id1', 'id2'};
            normalized = nansen.metadata.MetaTable.normalizeIdentifier(cellIds);
            testCase.verifyEqual(normalized, cellIds);

            % Char vector
            charId = 'single_id';
            normalized = nansen.metadata.MetaTable.normalizeIdentifier(charId);
            testCase.verifyClass(normalized, 'cell');
            testCase.verifyEqual(normalized{1}, charId);
        end

        function testAddTableVariableStatic(testCase)
            % Test static method for adding table variable
            T = testCase.TestEntries;
            varName = 'NewStaticColumn';
            initValue = {'default'};

            T = nansen.metadata.MetaTable.addTableVariableStatic(T, varName, initValue);

            testCase.verifyTrue(any(strcmp(T.Properties.VariableNames, varName)));
        end

        function testCreateFileName(testCase)
            % Test filename creation
            S = struct('MetaTableName', 'TestTable', 'IsMaster', true);
            filename = nansen.metadata.MetaTable.createFileName(S);

            testCase.verifyTrue(contains(filename, 'test_table'));
            testCase.verifyTrue(contains(filename, 'master'));
            testCase.verifyTrue(endsWith(filename, '.mat'));
        end
    end

    %% Edge Cases and Error Handling
    methods (Test)
        function testEmptyTable(testCase)
            % Test operations on empty MetaTable
            mt = nansen.metadata.MetaTable();

            % Should not error
            testCase.verifyEmpty(mt.entries);
            testCase.verifyEmpty(mt.members);
            testCase.verifyEmpty(mt.VariableNames);
        end

        function testInvalidColumnName(testCase)
            % Test getting column index for non-existent column
            testCase.createTestMetaTable();

            testCase.verifyError(@() testCase.TestMetaTable.getColumnIndex('NonExistent'), ...
                'NANSEN:MetaTable:ColumnNotFound');
        end

        % function testRemoveDuplicates(testCase)
        %     % Test removing duplicate entries
        %     testCase.createTestMetaTable();
        %
        %     % Artificially create duplicate
        %     originalCount = height(testCase.TestMetaTable.entries);
        %     testCase.TestMetaTable.entries = [testCase.TestMetaTable.entries; testCase.TestMetaTable.entries(1,:)];
        %     testCase.TestMetaTable.MetaTableMembers = testCase.TestMetaTable.entries.sessionID;
        %
        %     % Remove duplicates
        %     testCase.TestMetaTable.removeDuplicates();
        %
        %     % Verify
        %     testCase.verifyEqual(height(testCase.TestMetaTable.entries), originalCount);
        % end
    end

    %% Factory Method Tests
    methods (Test)
        function testNewMethod(testCase)
            % Test static new() method
            mt = nansen.metadata.MetaTable.new();

            testCase.verifyClass(mt, 'nansen.metadata.MetaTable');
            testCase.verifyEmpty(mt.entries);
        end

        function testNewWithTable(testCase)
            % Test new() method with table input
            mt = nansen.metadata.MetaTable.new(testCase.TestEntries, ...
                'MetaTableIdVarname', 'sessionID');

            testCase.verifyEqual(height(mt.entries), testCase.NUM_TEST_ENTRIES);
        end
    end
end
