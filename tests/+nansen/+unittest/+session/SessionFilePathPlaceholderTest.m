classdef SessionFilePathPlaceholderTest < matlab.unittest.TestCase
    %SessionFilePathPlaceholderTest Resolving variable file paths with placeholders
    %
    %   A session resolves the file of a variable from the variable's file
    %   name expression. An expression with placeholders such as
    %   {sessionID} names the whole file once the session's values are
    %   filled in, both when an existing file is located and when a new
    %   file is named.
    %
    %   The tests run inside a temporary project and use its first session
    %   in the MockData data location, the one whose session folders exist
    %   on disk.
    %
    %   Run tests:
    %       runtests('nansen.unittest.session.SessionFilePathPlaceholderTest')

    properties
        Project
        Session
        DataLocationName
    end

    methods (TestClassSetup)
        function useTemporaryProject(testCase)
        %useTemporaryProject Create a session object from the temporary project
            testCase.applyFixture(nansen.fixture.ProjectFixture())
            testCase.Project = nansen.getCurrentProject();

            sessionTable = testCase.Project.MetaTableCatalog.getMetaTable('Session');
            testCase.Session = nansen.metadata.type.Session( ...
                sessionTable.entries(1,:), ...
                'DataLocationModel', testCase.Project.DataLocationModel, ...
                'VariableModel', testCase.Project.VariableModel);
            testCase.DataLocationName = 'MockData';
        end
    end

    methods (Test)

        function testPlaceholderLocatesExistingFile(testCase)
        %testPlaceholderLocatesExistingFile A file named by the session ID is found
            sessionFolder = testCase.Session.getSessionFolder(testCase.DataLocationName);
            expectedPath = fullfile(sessionFolder, [testCase.Session.sessionID, '.nwb']);
            fclose( fopen(expectedPath, 'w') );
            testCase.addTeardown(@() delete(expectedPath))

            testCase.addVariable('SessionNwb', '{sessionID}', '.nwb')

            testCase.verifyEqual( testCase.Session.getDataFilePath('SessionNwb'), expectedPath )
        end

        function testPlaceholderNamesNewFile(testCase)
        %testPlaceholderNamesNewFile A new file takes the expanded expression as its name
            sessionFolder = testCase.Session.getSessionFolder(testCase.DataLocationName);
            testCase.addVariable('SessionNotes', '{sessionID}_notes', '.mat')

            pathStr = testCase.Session.getDataFilePath('SessionNotes', '-w');

            testCase.verifyEqual( pathStr, ...
                fullfile(sessionFolder, [testCase.Session.sessionID, '_notes.mat']) )
        end

        function testMissingFileIsAnErrorOnRead(testCase)
        %testMissingFileIsAnErrorOnRead Reading never invents a file name
            testCase.addVariable('SessionMissing', '{sessionID}_missing', '.mat')

            testCase.verifyError( @() testCase.Session.getDataFilePath('SessionMissing'), ...
                'NANSEN:Session:FileNotFound')
        end
    end

    methods (Access = private)
        function addVariable(testCase, variableName, fileNameExpression, fileType)
            model = testCase.Project.VariableModel;

            % The mock project's items carry fields a blank item lacks, so
            % an existing item serves as the template for the new one.
            item = model.Data(1);
            item.VariableName = variableName;
            item.DataLocation = testCase.DataLocationName;
            item.Subfolder = '';
            item.FileNameExpression = fileNameExpression;
            item.FileType = fileType;
            item.FileAdapter = 'Default';

            model.insertItem(item)
        end
    end
end
