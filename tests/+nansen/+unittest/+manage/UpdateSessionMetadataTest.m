classdef UpdateSessionMetadataTest < matlab.unittest.TestCase
    %UpdateSessionMetadataTest Extracting subject IDs, dates and times of sessions again
    %
    %   nansen.manage.updateSessionMetadata extracts the subjectID, Date and
    %   Time of the sessions in a session table from the folder paths stored
    %   in the table, using the metadata definitions of a data location
    %   model. The tests use the data location model of a mock project and
    %   a session table made by each test. The session folder names hold a
    %   date, a time and a subject ID, for example
    %   "2024-01-15_10-30-00_sub-01". The folders do not need to exist,
    %   because the values are extracted from the paths.
    %
    %   Run tests:
    %       runtests('nansen.unittest.manage.UpdateSessionMetadataTest')

    properties (Constant)
        SessionIDs = {'ses-01'; 'ses-02'}
        SubjectFolderNames = {'sub-01'; 'sub-02'}
        SessionFolderNames = {'2024-01-15_10-30-00_sub-01'; '2024-02-20_14-45-30_sub-02'}
        ExpectedSubjectIDs = {'01'; '02'}
    end

    properties
        DataLocationModel
        MockDataIndex      % Index of the data location holding the sessions
        ProcessedIndex     % Index of the other data location of the mock project
    end

    methods (TestClassSetup)
        function setupProject(testCase)
            testCase.applyFixture(nansen.fixture.ProjectFixture)
        end
    end

    methods (TestMethodSetup)
        function defineMetadataExtraction(testCase)
        %defineMetadataExtraction Extract the values from the folder names of the test sessions
            model = nansen.DataLocationModel();
            testCase.DataLocationModel = model;
            testCase.MockDataIndex = model.getItemIndex('MockData');
            testCase.ProcessedIndex = model.getItemIndex('Processed');

            for index = [testCase.MockDataIndex, testCase.ProcessedIndex]
                originalDefinitions = model.Data(index).MetaDataDef;
                testCase.addTeardown(@() model.updateMetaDataDefinitions( ...
                    originalDefinitions, index))
            end

            testCase.setDefinition('Subject ID', 1, 'ind', '5:6', '')
            testCase.setDefinition('Experiment Date', 2, 'ind', '1:10', 'yyyy-MM-dd')
            testCase.setDefinition('Experiment Time', 2, 'ind', '12:19', 'HH-mm-ss')
        end
    end

    methods (Test)

        function testChangedSubjectIdDefinitionUpdatesSubjectIDs(testCase)
            sessionTable = testCase.createSessionTable( ...
                SubjectIDs={'sub-01'; 'sub-02'});

            [updatedVariableNames, failureMessage] = ...
                nansen.manage.updateSessionMetadata(sessionTable, testCase.DataLocationModel);

            testCase.verifyEqual(sessionTable.entries.subjectID, testCase.ExpectedSubjectIDs)
            testCase.verifyEqual(updatedVariableNames, "subjectID")
            testCase.verifyEqual(failureMessage, "")
        end

        function testValuesThatAgreeWithDefinitionsAreNotRewritten(testCase)
            % A time is parsed without a date, so a time in the table can
            % have any date and still agree with its definition.
            times = datetime(2020, 1, 1, [10; 14], [30; 45], [0; 30], 'Format', 'HH:mm:ss');
            sessionTable = testCase.createSessionTable(Times=times);
            entriesBefore = sessionTable.entries;

            updatedVariableNames = nansen.manage.updateSessionMetadata( ...
                sessionTable, testCase.DataLocationModel);

            testCase.verifyEmpty(updatedVariableNames)
            testCase.verifyEqual(sessionTable.entries, entriesBefore)
        end

        function testSessionIDsAreNotChanged(testCase)
            testCase.setDefinition('Session ID', 2, 'ind', '1:10', '')
            sessionTable = testCase.createSessionTable();

            updatedVariableNames = nansen.manage.updateSessionMetadata( ...
                sessionTable, testCase.DataLocationModel);

            testCase.verifyEqual(sessionTable.entries.sessionID, testCase.SessionIDs, ...
                'Session IDs identify the rows and should never be extracted again.')
            testCase.verifyEmpty(updatedVariableNames)
        end

        function testAddedDateFormatGivesDatetimeColumn(testCase)
            % Without a format, a date is extracted as text.
            sessionTable = testCase.createSessionTable( ...
                Dates={'2024-01-15'; '2024-02-20'});

            updatedVariableNames = nansen.manage.updateSessionMetadata( ...
                sessionTable, testCase.DataLocationModel);

            testCase.verifyClass(sessionTable.entries.Date, 'datetime')
            testCase.verifyEqual(sessionTable.entries.Date, testCase.expectedDates())
            testCase.verifyEqual(updatedVariableNames, "Date")
        end

        function testRemovedDateFormatGivesTextColumn(testCase)
            testCase.setDefinition('Experiment Date', 2, 'ind', '1:10', '')
            sessionTable = testCase.createSessionTable();

            nansen.manage.updateSessionMetadata(sessionTable, testCase.DataLocationModel);

            testCase.verifyEqual(sessionTable.entries.Date, {'2024-01-15'; '2024-02-20'})
            testCase.verifyEqual(sessionTable.entries.sessionID, testCase.SessionIDs)
        end

        function testValueIsKeptWhenNothingIsExtracted(testCase)
            testCase.setDefinition('Subject ID', 1, 'expr', 'mouse\d+', '')
            sessionTable = testCase.createSessionTable( ...
                SubjectIDs={'sub-01'; 'sub-02'});

            [updatedVariableNames, failureMessage] = ...
                nansen.manage.updateSessionMetadata(sessionTable, testCase.DataLocationModel);

            testCase.verifyEqual(sessionTable.entries.subjectID, {'sub-01'; 'sub-02'})
            testCase.verifyEmpty(updatedVariableNames)
            testCase.verifyEqual(failureMessage, "")
        end

        function testExtractionErrorIsReportedAndKeepsValue(testCase)
            % The subject folder names have 6 characters.
            testCase.setDefinition('Subject ID', 1, 'ind', '5:40', '')
            sessionTable = testCase.createSessionTable( ...
                SubjectIDs={'sub-01'; 'sub-02'});

            [updatedVariableNames, failureMessage] = ...
                nansen.manage.updateSessionMetadata(sessionTable, testCase.DataLocationModel);

            testCase.verifyEqual(sessionTable.entries.subjectID, {'sub-01'; 'sub-02'})
            testCase.verifyEmpty(updatedVariableNames)
            testCase.verifySubstring(failureMessage, "subjectID")
            testCase.verifySubstring(failureMessage, "ses-01, ses-02")
            testCase.verifySubstring(failureMessage, "outside the string length")
        end

        function testFirstDataLocationThatGivesValueIsUsed(testCase)
            testCase.assertLessThan(testCase.ProcessedIndex, testCase.MockDataIndex, ...
                'The test expects the Processed data location to come first in the model.')

            processedFolders = {fullfile('P11', 'session'); fullfile('P12', 'session')};
            sessionTable = testCase.createSessionTable(ProcessedSubfolders=processedFolders);

            testCase.setDefinition('Subject ID', 1, 'ind', '2:3', '', ...
                DataLocationIndex=testCase.ProcessedIndex)
            nansen.manage.updateSessionMetadata(sessionTable, testCase.DataLocationModel);
            testCase.verifyEqual(sessionTable.entries.subjectID, {'11'; '12'}, ...
                'The first data location in the model should give the value.')

            testCase.setDefinition('Subject ID', 1, 'expr', 'mouse\d+', '', ...
                DataLocationIndex=testCase.ProcessedIndex)
            nansen.manage.updateSessionMetadata(sessionTable, testCase.DataLocationModel);
            testCase.verifyEqual(sessionTable.entries.subjectID, testCase.ExpectedSubjectIDs, ...
                'A data location that gives no value should be passed over.')
        end

        function testTableWithoutDataLocationsIsUnchanged(testCase)
            entries = table(testCase.SessionIDs, {'sub-01'; 'sub-02'}, ...
                'VariableNames', {'sessionID', 'subjectID'});
            sessionTable = testCase.createMetaTable(entries);

            [updatedVariableNames, failureMessage] = ...
                nansen.manage.updateSessionMetadata(sessionTable, testCase.DataLocationModel);

            testCase.verifyEqual(sessionTable.entries, entries)
            testCase.verifyEmpty(updatedVariableNames)
            testCase.verifyEqual(failureMessage, "")
        end
    end

    methods (Access = private)

        function setDefinition(testCase, variableName, subfolderLevel, mode, pattern, stringFormat, options)
        %setDefinition Set how a data location extracts a metadata variable
            arguments
                testCase
                variableName (1,1) string
                subfolderLevel double
                mode (1,1) string
                pattern (1,1) string
                stringFormat (1,1) string
                options.DataLocationIndex = testCase.MockDataIndex
            end

            model = testCase.DataLocationModel;
            definitions = model.Data(options.DataLocationIndex).MetaDataDef;
            isVariable = strcmp({definitions.VariableName}, variableName);

            definitions(isVariable).SubfolderLevel = subfolderLevel;
            definitions(isVariable).StringDetectMode = char(mode);
            definitions(isVariable).StringDetectInput = char(pattern);
            definitions(isVariable).StringFormat = char(stringFormat);

            model.updateMetaDataDefinitions(definitions, options.DataLocationIndex)
        end

        function sessionTable = createSessionTable(testCase, options)
        %createSessionTable Session table whose values agree with the definitions of the setup
            arguments
                testCase
                options.SubjectIDs = testCase.ExpectedSubjectIDs
                options.Dates = testCase.expectedDates()
                options.Times = datetime(2024, 1, 15, [10; 14], [30; 45], [0; 30], 'Format', 'HH:mm:ss')
                options.ProcessedSubfolders = {''; ''}
            end

            numSessions = numel(testCase.SessionIDs);
            dataLocations = cell(numSessions, 1);
            for iSession = 1:numSessions
                mockDataSubfolders = fullfile(testCase.SubjectFolderNames{iSession}, ...
                    testCase.SessionFolderNames{iSession});
                dataLocations{iSession} = testCase.createStoredDataLocations( ...
                    mockDataSubfolders, options.ProcessedSubfolders{iSession});
            end

            entries = table(testCase.SessionIDs, options.SubjectIDs, options.Dates, ...
                options.Times, dataLocations, 'VariableNames', ...
                {'sessionID', 'subjectID', 'Date', 'Time', 'DataLocation'});
            sessionTable = testCase.createMetaTable(entries);
        end

        function dataLocations = createStoredDataLocations(testCase, mockDataSubfolders, processedSubfolders)
        %createStoredDataLocations Data locations as a session table stores them
            model = testCase.DataLocationModel;
            dataLocations = repmat(struct('Uuid', '', 'RootUid', '', 'Subfolders', ''), ...
                1, model.NumDataLocations);

            for iDataLocation = 1:model.NumDataLocations
                item = model.getItem(iDataLocation);
                dataLocations(iDataLocation).Uuid = item.Uuid;
                dataLocations(iDataLocation).RootUid = item.RootPath(1).Key;
            end

            dataLocations(testCase.MockDataIndex).Subfolders = mockDataSubfolders;
            dataLocations(testCase.ProcessedIndex).Subfolders = processedSubfolders;
        end
    end

    methods (Static, Access = private)

        function sessionTable = createMetaTable(entries)
            sessionTable = nansen.unittest.metadata.helper.MetaTableFake(entries, ...
                'MetaTableClass', 'nansen.metadata.type.Session', ...
                'ItemClassName', '', ...
                'MetaTableIdVarname', 'sessionID');
        end

        function dates = expectedDates()
            dates = datetime(2024, [1; 2], [15; 20]);
        end
    end
end
