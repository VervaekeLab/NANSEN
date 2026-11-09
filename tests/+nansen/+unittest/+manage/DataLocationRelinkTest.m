classdef DataLocationRelinkTest < matlab.unittest.TestCase
    %DataLocationRelinkTest Tests for the session ID check before a session table is relinked
    %
    %   Covers nansen.manage.validateDataLocationRelink, and the error that
    %   nansen.manage.updateSessionDatalocations throws when no session
    %   folders are found.
    %
    %   The tests use the data location model of a temporary project. Before
    %   each test, the root folder of its MockData data location is set to an
    %   empty temporary folder, and the root folder of every other data
    %   location is set to a folder that does not exist. A test creates
    %   session folders such as sub-01/sub-01_ses-01, from which MockData
    %   extracts the session ID "sub-01_ses-01". The model is changed in
    %   memory only, and its data is restored after each test.
    %
    %   A DataLocationModel can only be constructed while a project is
    %   current, so the tests run inside nansen.fixture.ProjectFixture.
    %
    %   Run tests:
    %       runtests('nansen.unittest.manage.DataLocationRelinkTest')

    properties
        DataLocationModel nansen.config.dloc.DataLocationModel
        RootFolder (1,1) string = ""
    end

    properties (Constant)
        MOCK_DATA_LOCATION = 'MockData'
    end

    methods (TestClassSetup)
        function useTemporaryProject(testCase)
        %useTemporaryProject Get the data location model of a temporary project
            testCase.applyFixture(nansen.fixture.ProjectFixture())
            project = nansen.getCurrentProject();
            testCase.DataLocationModel = project.DataLocationModel;
        end
    end

    methods (TestMethodSetup)
        function useTemporaryRootFolders(testCase)
        %useTemporaryRootFolders Point the data locations at folders the test controls
            folderFixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture());
            testCase.RootFolder = folderFixture.Folder;

            model = testCase.DataLocationModel;
            originalData = model.Data;
            testCase.addTeardown(@() model.setData(originalData))

            dataLocationNames = string(model.DataLocationNames);
            for dataLocationName = reshape(dataLocationNames, 1, [])
                if dataLocationName == testCase.MOCK_DATA_LOCATION
                    testCase.setRootFolder(dataLocationName, testCase.RootFolder)
                else
                    testCase.setRootFolder(dataLocationName, testCase.getMissingFolder())
                end
            end
        end
    end

    methods (Test)

        function testMatchingSessionIDsPass(testCase)
        %testMatchingSessionIDsPass The check passes when some session IDs are in both the folders and the table
            testCase.createSessionFolders(["sub-01_ses-01", "sub-01_ses-02", "sub-02_ses-01"])
            sessionTable = testCase.createSessionTable( ...
                ["sub-01_ses-01", "sub-02_ses-01", "sub-03_ses-01"]);

            report = nansen.manage.validateDataLocationRelink( ...
                sessionTable, testCase.DataLocationModel);

            testCase.verifyEqual(report.MatchingSessionIDs, {'sub-01_ses-01', 'sub-02_ses-01'})
            testCase.verifyEqual(report.NumMatchingSessionIDs, 2)
        end

        function testChangedSessionIDDefinitionThrows(testCase)
        %testChangedSessionIDDefinitionThrows A session ID rule that changes every ID fails the check
            testCase.createSessionFolders(["sub-01_ses-01", "sub-01_ses-02"])
            sessionTable = testCase.createSessionTable(["sub-01_ses-01", "sub-01_ses-02"]);

            % This rule extracts "ses-01" from the folder sub-01_ses-01
            testCase.setSessionIDExpression('ses-\d+')

            testCase.verifyError( ...
                @() nansen.manage.validateDataLocationRelink( ...
                    sessionTable, testCase.DataLocationModel), ...
                'NANSEN:DataLocations:SessionIdentityMismatch')
        end

        function testTableWithoutSessionIDColumnThrows(testCase)
        %testTableWithoutSessionIDColumnThrows A table without a sessionID column cannot be checked
            testCase.createSessionFolders("sub-01_ses-01")
            subjectTable = nansen.metadata.MetaTable( ...
                table({'sub-01'}, 'VariableNames', {'subjectID'}), ...
                MetaTableIdVarname='subjectID');

            testCase.verifyError( ...
                @() nansen.manage.validateDataLocationRelink( ...
                    subjectTable, testCase.DataLocationModel), ...
                'NANSEN:DataLocations:MissingSessionIDColumn')
        end

        function testMissingRootFolderPasses(testCase)
        %testMissingRootFolderPasses Without session folders there are no session IDs to compare
            testCase.setRootFolder(testCase.MOCK_DATA_LOCATION, testCase.getMissingFolder())
            sessionTable = testCase.createSessionTable("sub-01_ses-01");

            report = nansen.manage.validateDataLocationRelink( ...
                sessionTable, testCase.DataLocationModel);

            testCase.verifyEmpty(report.ExtractedSessionIDs)
            testCase.verifyEqual(report.NumMatchingSessionIDs, 0)
        end

        function testUpdateWithMissingRootFolderThrows(testCase)
        %testUpdateWithMissingRootFolderThrows Relinking without session folders reports that none were found
            testCase.setRootFolder(testCase.MOCK_DATA_LOCATION, testCase.getMissingFolder())
            sessionTable = testCase.createSessionTable("sub-01_ses-01");

            testCase.verifyError( ...
                @() nansen.manage.updateSessionDatalocations( ...
                    sessionTable, testCase.DataLocationModel), ...
                'NANSEN:DataLocations:NoMatchingSessionFolders')
        end
    end

    methods (Access = private)

        function folderPath = getMissingFolder(testCase)
        %getMissingFolder Path of a folder that does not exist, like a drive that is not mounted
            folderPath = fullfile(testCase.RootFolder, "unmounted_drive");
        end

        function createSessionFolders(testCase, sessionFolderNames)
        %createSessionFolders Create folders such as sub-01/sub-01_ses-01 in RootFolder
            for sessionFolderName = sessionFolderNames
                subjectFolderName = extractBefore(sessionFolderName, "_");
                mkdir(fullfile(testCase.RootFolder, subjectFolderName, sessionFolderName))
            end
        end

        function setRootFolder(testCase, dataLocationName, folderPath)
        %setRootFolder Set the first root folder of a data location
            model = testCase.DataLocationModel;
            data = model.Data;
            dataLocationIndex = model.getItemIndex(char(dataLocationName));
            data(dataLocationIndex).RootPath(1).Value = char(folderPath);
            model.setData(data)
        end

        function setSessionIDExpression(testCase, expression)
        %setSessionIDExpression Extract session IDs of MockData with a regular expression
            model = testCase.DataLocationModel;
            data = model.Data;
            dataLocationIndex = model.getItemIndex(testCase.MOCK_DATA_LOCATION);

            definitions = data(dataLocationIndex).MetaDataDef;
            isSessionID = strcmp({definitions.VariableName}, 'Session ID');
            definitions(isSessionID).StringDetectMode = 'expr';
            definitions(isSessionID).StringDetectInput = expression;

            data(dataLocationIndex).MetaDataDef = definitions;
            model.setData(data)
        end
    end

    methods (Static, Access = private)
        function sessionTable = createSessionTable(sessionIDs)
        %createSessionTable Create a session table with one row per session ID
            entries = table(cellstr(sessionIDs(:)), 'VariableNames', {'sessionID'});
            sessionTable = nansen.metadata.MetaTable(entries, ...
                MetaTableIdVarname='sessionID');
        end
    end
end
