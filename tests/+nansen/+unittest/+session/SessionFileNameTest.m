classdef SessionFileNameTest < matlab.unittest.TestCase
    %SessionFileNameTest Naming the file of a variable that has no file yet
    %
    %   A session names a new file after its session ID and the variable's
    %   file name expression. An expression with a wildcard describes
    %   existing files only, so it cannot name a file.
    %
    %   The tests run inside a temporary project and use its first session.
    %
    %   Run tests:
    %       runtests('nansen.unittest.session.SessionFileNameTest')

    properties
        Session
    end

    methods (TestClassSetup)
        function useTemporaryProject(testCase)
        %useTemporaryProject Create a session object from the temporary project
            testCase.applyFixture(nansen.fixture.ProjectFixture())
            project = nansen.getCurrentProject();

            sessionTable = project.MetaTableCatalog.getMetaTable('Session');
            testCase.Session = nansen.metadata.type.Session( ...
                sessionTable.entries(1,:), ...
                'DataLocationModel', project.DataLocationModel);
        end
    end

    methods (Test)

        function testNameJoinsSessionIdAndExpression(testCase)
        %testNameJoinsSessionIdAndExpression The name is session ID, expression and type
            item = testCase.createItem('Rois', 'rois', '.mat');

            expected = [testCase.Session.sessionID, '_rois.mat'];
            testCase.verifyEqual(testCase.Session.getFileName(item), expected)
        end

        function testFileTypeGetsItsDot(testCase)
        %testFileTypeGetsItsDot A file type given without a dot still ends up with one
            item = testCase.createItem('Rois', 'rois', 'mat');

            expected = [testCase.Session.sessionID, '_rois.mat'];
            testCase.verifyEqual(testCase.Session.getFileName(item), expected)
        end

        function testWildcardExpressionCannotNameAFile(testCase)
        %testWildcardExpressionCannotNameAFile A star describes existing files only
            item = testCase.createItem('AnyNwb', '*', '.nwb');

            testCase.verifyError(@() testCase.Session.getFileName(item), ...
                'NANSEN:Session:WildcardInFileName')
        end
    end

    methods (Static, Access = private)
        function item = createItem(variableName, fileNameExpression, fileType)
            item = nansen.config.varmodel.VariableModel.getDefaultItem(variableName);
            item.FileNameExpression = fileNameExpression;
            item.FileType = fileType;
        end
    end
end
