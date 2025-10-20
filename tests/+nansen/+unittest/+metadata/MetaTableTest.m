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
    
    properties
        TestDir char
        TestMetaTable nansen.unittest.metadata.TestableMetaTable
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
            testCase.TestMetaTable = nansen.unittest.metadata.TestableMetaTable( ...
                testCase.TestEntries, ...
                'MetaTableClass', 'table', ...
                'ItemClassName', '', ...
                'MetaTableIdVarname', 'sessionID');
        end
    end
    
    methods (TestMethodTeardown)
        function cleanupTempFiles(testCase)
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
            
            testCase.verifyEqual(mt.class(), className);
        end
    end
    
    %% Property Tests
    methods (Test)
        function testIsMaster(testCase)
            % Test isMaster method
            testCase.createTestMetaTable();
            testCase.verifyTrue(testCase.TestMetaTable.isMaster());
        end
        
        function testVariableNames(testCase)
            % Test VariableNames dependent property
            testCase.createTestMetaTable();
            
            expectedNames = testCase.TestEntries.Properties.VariableNames;
            testCase.verifyEqual(testCase.TestMetaTable.VariableNames, expectedNames);
        end
        
        function testGetName(testCase)
            % Test getName method
            % Note: MetaTableName is private, so we test by saving/loading
            testCase.createTestMetaTable();
            
            % Save with a name and verify getName retrieves it
            testFilePath = fullfile(testCase.TestDir, 'test_name.mat');
            testCase.TestMetaTable.setFilepath(testFilePath);
            testCase.TempFiles{end+1} = testFilePath;
            
            % Use toStruct to set the name indirectly
            S = testCase.TestMetaTable.toStruct('metatable_file');
            S.MetaTableName = 'TestTable';
            
            mt2 = nansen.metadata.MetaTable();
            mt2.fromStruct(S);
            
            testCase.verifyEqual(mt2.getName(), 'TestTable');
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
            
            % Remove first entry
            idToRemove = testCase.TestMetaTable.members{1};
            testCase.TestMetaTable.removeEntries({idToRemove});
            
            % Verify
            testCase.verifyEqual(height(testCase.TestMetaTable.entries), initialCount - 1);
            testCase.verifyFalse(ismember(idToRemove, testCase.TestMetaTable.members));
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
        
        function testNoDuplicateEntries(testCase)
            % Test that duplicate entries are not added
            testCase.createTestMetaTable();
            initialCount = height(testCase.TestMetaTable.entries);
            
            % Try to add duplicate entry
            duplicateEntry = testCase.TestEntries(1, :);
            testCase.TestMetaTable.addTable(duplicateEntry);
            
            % Verify count hasn't changed
            testCase.verifyEqual(height(testCase.TestMetaTable.entries), initialCount);
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
            version1 = testCase.TestMetaTable.loadVersionNumber();
            
            % Modify and save again
            testCase.TestMetaTable.editEntries(1, 'Value', 888);
            testCase.TestMetaTable.save();
            version2 = testCase.TestMetaTable.loadVersionNumber();
            
            % Verify version incremented
            testCase.verifyEqual(version2, version1 + 1);
        end
        
        function testLoadVersionNumber(testCase)
            % Test loading version number from file
            testCase.createTestMetaTable();
            
            % Save with version
            testFilePath = fullfile(testCase.TestDir, 'version_test.mat');
            testCase.TestMetaTable.setFilepath(testFilePath);
            S = testCase.TestMetaTable.toStruct('metatable_file');
            S.MetaTableName = 'VersionTest';
            testCase.TestMetaTable.fromStruct(S);
            testCase.TempFiles{end+1} = testFilePath;
            testCase.TestMetaTable.save();
            
            savedVersion = testCase.TestMetaTable.loadVersionNumber();
            
            % Load version number via new instance
            mt2 = nansen.metadata.MetaTable();
            S2 = struct('filepath', testFilePath);
            S2.MetaTableEntries = table.empty;
            mt2.fromStruct(S2);
            loadedVersion = mt2.loadVersionNumber();
            
            testCase.verifyEqual(loadedVersion, savedVersion);
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
            testCase.verifyEqual(mt2.getName(), 'FromStructTest');
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
            formattedTable = testCase.TestMetaTable.getFormattedTableData();
            
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
            formattedTable = testCase.TestMetaTable.getFormattedTableData(colIndices, rowIndices);
            
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
