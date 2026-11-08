classdef SessionMetadataExtractionTest < matlab.unittest.TestCase
    %SessionMetadataExtractionTest Extracting metadata values from a session's folders
    %
    %   DataLocationModel.getMetadataValue extracts a metadata value from
    %   the folders of a session, using the first data location of the
    %   model that gives one.
    %
    %   The tests use the data location model of a mock project, where the
    %   Processed data location comes before the MockData data location.
    %   The session folder name holds a date, a time and a subject ID. The
    %   folders do not need to exist, because the values are extracted from
    %   the paths.
    %
    %   Run tests:
    %       runtests('nansen.unittest.session.SessionMetadataExtractionTest')

    properties (Constant)
        SubjectFolderName = 'sub-01'
        SessionFolderName = '2024-01-15_10-30-00_sub-01'
    end

    properties
        DataLocationModel
        MockDataIndex      % Index of the data location holding the session
        ProcessedIndex     % Index of the data location before it in the model
    end

    methods (TestClassSetup)
        function setupProject(testCase)
            testCase.applyFixture(nansen.fixture.ProjectFixture)
        end
    end

    methods (TestMethodSetup)
        function defineMetadataExtraction(testCase)
        %defineMetadataExtraction Extract the values from the folder names of the test session
            model = nansen.DataLocationModel();
            testCase.DataLocationModel = model;
            testCase.MockDataIndex = model.getItemIndex('MockData');
            testCase.ProcessedIndex = model.getItemIndex('Processed');

            testCase.assertLessThan(testCase.ProcessedIndex, testCase.MockDataIndex, ...
                'The tests expect the Processed data location to come first in the model.')

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

        function testFirstDataLocationOfTheModelGivesTheValue(testCase)
            testCase.setDefinition('Subject ID', 1, 'ind', '2:3', '', ...
                DataLocationIndex=testCase.ProcessedIndex)
            dataLocations = testCase.createDataLocations( ...
                ProcessedSubfolders=fullfile('P11', 'session'));

            % The order of the model decides, not the order of the struct.
            value = testCase.DataLocationModel.getMetadataValue( ...
                "Subject ID", flip(dataLocations));

            testCase.verifyEqual(value, '11')
        end

        function testDataLocationThatGivesNoValueIsPassedOver(testCase)
            testCase.setDefinition('Subject ID', 1, 'expr', 'mouse\d+', '', ...
                DataLocationIndex=testCase.ProcessedIndex)
            dataLocations = testCase.createDataLocations( ...
                ProcessedSubfolders=fullfile('P11', 'session'));

            value = testCase.DataLocationModel.getMetadataValue("Subject ID", dataLocations);

            testCase.verifyEqual(value, '01')
        end

        function testDataLocationWithoutSessionFolderIsPassedOver(testCase)
            % This rule would give a value for the folders above the root path.
            testCase.setDefinition('Subject ID', 1, 'ind', '1:2', '', ...
                DataLocationIndex=testCase.ProcessedIndex)
            dataLocations = testCase.createDataLocations();

            value = testCase.DataLocationModel.getMetadataValue("Subject ID", dataLocations);

            testCase.verifyEqual(value, '01')
        end

        function testDataLocationNotInTheModelIsPassedOver(testCase)
            testCase.setDefinition('Subject ID', 1, 'ind', '2:3', '', ...
                DataLocationIndex=testCase.ProcessedIndex)
            dataLocations = testCase.createDataLocations( ...
                ProcessedSubfolders=fullfile('P11', 'session'));
            dataLocations(testCase.ProcessedIndex).Uuid = 'not-a-data-location-in-this-model';

            value = testCase.DataLocationModel.getMetadataValue("Subject ID", dataLocations);

            testCase.verifyEqual(value, '01')
        end

        function testUnknownRootPathGivesNoValue(testCase)
            dataLocations = testCase.createDataLocations();
            dataLocations(testCase.MockDataIndex).RootUid = 'not-a-root-of-this-data-location';

            value = testCase.DataLocationModel.getMetadataValue("Subject ID", dataLocations);

            testCase.verifyEqual(value, '')
        end

        function testNoValueWhenNoDataLocationGivesOne(testCase)
            testCase.setDefinition('Subject ID', 1, 'expr', 'mouse\d+', '')
            dataLocations = testCase.createDataLocations();

            value = testCase.DataLocationModel.getMetadataValue("Subject ID", dataLocations);

            testCase.verifyEqual(value, '')
        end

        function testNoValueForEmptyDataLocations(testCase)
            value = testCase.DataLocationModel.getMetadataValue("Subject ID", struct.empty);

            testCase.verifyEqual(value, '')
        end

        function testDateAndTimeAreDatetimeValues(testCase)
            dataLocations = testCase.createDataLocations();
            model = testCase.DataLocationModel;

            date = model.getMetadataValue("Experiment Date", dataLocations);
            time = model.getMetadataValue("Experiment Time", dataLocations);

            testCase.verifyEqual(date, datetime(2024, 1, 15))
            testCase.verifyEqual(timeofday(time), duration(10, 30, 0))
        end

        function testSessionIdIsExtracted(testCase)
            testCase.setDefinition('Session ID', 2, 'ind', '21:end', '')
            dataLocations = testCase.createDataLocations();

            value = testCase.DataLocationModel.getMetadataValue("Session ID", dataLocations);

            testCase.verifyEqual(value, 'sub-01')
        end

        function testExtractionErrorReachesTheCaller(testCase)
            % The subject folder name has 6 characters.
            testCase.setDefinition('Subject ID', 1, 'ind', '5:40', '')
            dataLocations = testCase.createDataLocations();

            testCase.verifyError(@() testCase.DataLocationModel.getMetadataValue( ...
                "Subject ID", dataLocations), 'NANSEN:DataLocationModel:IndexOutOfRange')
        end

        function testUnknownVariableIsRefused(testCase)
            testCase.verifyError(@() testCase.DataLocationModel.getMetadataValue( ...
                "Weight", testCase.createDataLocations()), ...
                'NANSEN:DataLocationModel:UnknownMetadataVariable')
        end

        function testSessionIgnoresRootPathWithoutSessionFolder(testCase)
            % A session of the mock project has a folder in MockData only.
            % This rule would give a value for the folders above the root
            % path of Processed.
            testCase.setDefinition('Subject ID', 1, 'ind', '1:2', '', ...
                DataLocationIndex=testCase.ProcessedIndex)
            sessionObj = testCase.createProjectSession();
            testCase.assertEmpty(sessionObj.DataLocation(testCase.ProcessedIndex).Subfolders)

            value = nansen.metadata.type.Session.extractSubjectId(sessionObj);

            testCase.verifyEqual(value, '01')
        end

        function testTimeThatDoesNotMatchItsFormatRaises(testCase)
            % These characters of the folder name hold the date.
            testCase.setDefinition('Experiment Time', 2, 'ind', '1:10', 'HH-mm-ss')
            dataLocations = testCase.createDataLocations();

            testCase.verifyError(@() testCase.DataLocationModel.getMetadataValue( ...
                "Experiment Time", dataLocations), 'MATLAB:datetime:ParseErr')
        end

        function testNewSessionGetsNaTForUnreadableTime(testCase)
            testCase.setDefinition('Experiment Time', 2, 'ind', '1:10', 'HH-mm-ss')
            model = testCase.DataLocationModel;
            rootPath = model.getItem(testCase.MockDataIndex).RootPath(1).Value;
            sessionFolders = struct('Processed', '', 'MockData', ...
                fullfile(rootPath, testCase.SubjectFolderName, testCase.SessionFolderName));

            sessionObj = testCase.verifyWarning( ...
                @() nansen.metadata.type.Session(sessionFolders, 'DataLocationModel', model), ...
                'MATLAB:datetime:ParseErr');

            testCase.verifyTrue(isnat(sessionObj.Time), ...
                'A time that can not be read should give NaT.')
            testCase.verifyEqual(sessionObj.subjectID, '01', ...
                'A time that can not be read should not stop the other values.')
            testCase.verifyEqual(sessionObj.Date, datetime(2024, 1, 15))
        end
    end

    methods (Access = private)

        function sessionObj = createProjectSession(testCase)
        %createProjectSession Session object for the first session of the mock project
            project = nansen.getCurrentProject();
            sessionTable = project.MetaTableCatalog.getMetaTable('Session');
            sessionObj = nansen.metadata.type.Session(sessionTable.entries(1,:), ...
                'DataLocationModel', testCase.DataLocationModel);
        end

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

        function dataLocations = createDataLocations(testCase, options)
        %createDataLocations Data locations of the test session, as a metatable stores them
            arguments
                testCase
                options.ProcessedSubfolders = ''
            end

            model = testCase.DataLocationModel;
            dataLocations = repmat(struct('Uuid', '', 'RootUid', '', 'Subfolders', ''), ...
                1, model.NumDataLocations);

            for iDataLocation = 1:model.NumDataLocations
                item = model.getItem(iDataLocation);
                dataLocations(iDataLocation).Uuid = item.Uuid;
                dataLocations(iDataLocation).RootUid = item.RootPath(1).Key;
            end

            dataLocations(testCase.MockDataIndex).Subfolders = ...
                fullfile(testCase.SubjectFolderName, testCase.SessionFolderName);
            dataLocations(testCase.ProcessedIndex).Subfolders = options.ProcessedSubfolders;
        end
    end
end
