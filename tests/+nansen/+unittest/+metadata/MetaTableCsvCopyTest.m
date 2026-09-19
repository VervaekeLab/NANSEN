classdef MetaTableCsvCopyTest < matlab.unittest.TestCase
%MetaTableCsvCopyTest - Tests for the CSV copy that MetaTable.save writes
%
%   The mock project's session table is saved with the project
%   preference WriteMetaTableCsvCopies on and off.
%
%   Run tests:
%       runtests('nansen.unittest.metadata.MetaTableCsvCopyTest')

    properties
        Project
        SessionTable
        CsvFilePath char
    end

    methods (TestClassSetup)
        function setupProject(testCase)
            testCase.applyFixture(nansen.fixture.ProjectFixture)
            testCase.Project = nansen.getCurrentProject();
            testCase.SessionTable = testCase.Project.MetaTableCatalog.getMasterMetaTable('session');
            [folderPath, fileName] = fileparts(testCase.SessionTable.filepath);
            testCase.CsvFilePath = fullfile(folderPath, fileName + ".csv");
        end
    end

    methods (TestMethodSetup)
        function removeCopy(testCase)
            if isfile(testCase.CsvFilePath)
                delete(testCase.CsvFilePath)
            end
            testCase.addTeardown(@() testCase.Project.setWriteMetaTableCsvCopies(false))
        end
    end

    methods (Test)
        function testSaveWritesCopyWhenPreferenceIsOn(testCase)
            testCase.Project.setWriteMetaTableCsvCopies(true)

            testCase.SessionTable.save(true);

            copy = readtable(testCase.CsvFilePath, 'TextType', 'string');
            testCase.verifyEqual(height(copy), height(testCase.SessionTable.entries))
            testCase.verifyEqual(copy.sessionID, string(testCase.SessionTable.entries.sessionID))
        end

        function testSaveWritesNoCopyWhenPreferenceIsOff(testCase)
            testCase.SessionTable.save(true);

            testCase.verifyFalse(isfile(testCase.CsvFilePath))
        end

        function testDataLocationBecomesPathColumn(testCase)
            testCase.Project.setWriteMetaTableCsvCopies(true)

            testCase.SessionTable.save(true);

            copy = readtable(testCase.CsvFilePath, 'TextType', 'string');
            testCase.verifyTrue(ismember("DataLocation_MockData", copy.Properties.VariableNames))
            testCase.verifyTrue(all(isfolder(copy.DataLocation_MockData)))
        end

        function testNestedColumnsAreLeftOut(testCase)
            testCase.Project.setWriteMetaTableCsvCopies(true)

            testCase.SessionTable.save(true);

            copy = readtable(testCase.CsvFilePath, 'TextType', 'string');
            testCase.verifyEmpty(intersect(copy.Properties.VariableNames, ...
                {'DataLocation', 'Progress', 'Notebook'}))
        end

        function testTableWithoutRowsGetsCopy(testCase)
            % The data-location column of a table with no rows has no
            % names to make columns from
            metaTable = testCase.createTableInTemporaryFolder(testCase.SessionTable.entries([], :));

            csvFilePath = metaTable.writeCsvCopy();

            testCase.verifyTrue(isfile(csvFilePath))
        end

        function testRowsWithDifferentDataLocationsGetPathColumns(testCase)
            % Rows with different numbers of data locations make the
            % column a cell array of struct arrays
            import matlab.unittest.fixtures.TemporaryFolderFixture
            rootPath = testCase.applyFixture(TemporaryFolderFixture).Folder;
            raw1 = struct('Name', 'Raw', 'RootPath', rootPath, 'Subfolders', 's1');
            raw2 = struct('Name', 'Raw', 'RootPath', rootPath, 'Subfolders', 's2');
            processed2 = struct('Name', 'Processed', 'RootPath', rootPath, 'Subfolders', fullfile('processed', 's2'));
            entries = table({'s1'; 's2'}, {raw1; [raw2, processed2]}, 'VariableNames', {'sessionID', 'DataLocation'});
            metaTable = testCase.createTableInTemporaryFolder(entries);

            % Every column is text and mostly paths, so readtable would
            % take / for the delimiter and the header row for data
            copy = readtable(metaTable.writeCsvCopy(), 'TextType', 'string', ...
                'Delimiter', ',', 'ReadVariableNames', true);

            testCase.assertEqual(string(copy.Properties.VariableNames), ...
                ["sessionID", "DataLocation_Raw", "DataLocation_Processed"])
            testCase.verifyEqual(copy.DataLocation_Raw, string(fullfile(rootPath, {'s1'; 's2'})))
            testCase.verifyEqual(copy.DataLocation_Processed(2), string(fullfile(rootPath, 'processed', 's2')))
            testCase.verifyTrue(ismissing(copy.DataLocation_Processed(1)) || copy.DataLocation_Processed(1) == "")
        end

        function testCopyThatCannotBeWrittenWarns(testCase)
            % A folder in place of the CSV file makes writetable fail
            testCase.Project.setWriteMetaTableCsvCopies(true)
            mkdir(testCase.CsvFilePath)
            testCase.addTeardown(@() rmdir(testCase.CsvFilePath))

            wasSaved = testCase.verifyWarning(@() testCase.SessionTable.save(true), ...
                'NANSEN:MetaTable:CsvCopyFailed');

            testCase.verifyTrue(wasSaved)
        end

        function testTableOutsideCurrentProjectGetsNoCopy(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            testCase.Project.setWriteMetaTableCsvCopies(true)
            folder = testCase.applyFixture(TemporaryFolderFixture).Folder;
            entries = table({'s1'; 's2'}, [1; 2], 'VariableNames', {'sessionID', 'Value'});
            metaTable = nansen.unittest.metadata.helper.MetaTableFake(entries, ...
                'MetaTableClass', 'table', 'ItemClassName', '', 'MetaTableIdVarname', 'sessionID');
            metaTable.setFilepath(fullfile(folder, 'outside.mat'));

            metaTable.save(true);

            testCase.verifyFalse(isfile(fullfile(folder, 'outside.csv')))
        end
    end

    methods (Access = private)
        function metaTable = createTableInTemporaryFolder(testCase, entries)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folder = testCase.applyFixture(TemporaryFolderFixture).Folder;
            metaTable = nansen.unittest.metadata.helper.MetaTableFake(entries, ...
                'MetaTableClass', 'table', 'ItemClassName', '', 'MetaTableIdVarname', 'sessionID');
            metaTable.setFilepath(fullfile(folder, 'table.mat'));
        end
    end
end
