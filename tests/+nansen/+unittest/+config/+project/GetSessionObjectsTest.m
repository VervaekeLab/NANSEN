classdef GetSessionObjectsTest < matlab.unittest.TestCase
%GetSessionObjectsTest - Tests for Project.getSessionObjects
%
%   Uses the sessions of the mock project, whose variable NeuralData is a
%   .mat file in each session folder.
%
%   Run tests:
%       runtests('nansen.unittest.config.project.GetSessionObjectsTest')

    properties
        Project
        SessionIDs string
    end

    methods (TestClassSetup)
        function setupProject(testCase)
            testCase.applyFixture(nansen.fixture.ProjectFixture)
            testCase.Project = nansen.getCurrentProject();
            sessionTable = testCase.Project.MetaTableCatalog.getMasterMetaTable('session');
            testCase.SessionIDs = string(sessionTable.entries.sessionID);
        end
    end

    methods (Test)
        function testReturnsEverySessionWithoutIDs(testCase)
            sessions = testCase.Project.getSessionObjects();

            testCase.verifyEqual(string({sessions.sessionID})', testCase.SessionIDs)
        end

        function testReturnsSessionsInGivenOrder(testCase)
            sessionIDs = testCase.SessionIDs([2, 1]);

            sessions = testCase.Project.getSessionObjects(sessionIDs);

            testCase.verifyEqual(string({sessions.sessionID}), sessionIDs')
        end

        function testSessionCanLoadData(testCase)
            % The mock project's own variable is found through a field the
            % variable template lacks, so a variable of its own is added,
            % with the fields of the mock project's item
            variableModel = testCase.Project.VariableModel;
            item = variableModel.Data(1);
            item.VariableName = 'Values';
            item.Uuid = nansen.util.getuuid();
            item.FilePathPattern = '';
            item.FileNameExpression = 'values';
            item.FileType = '.mat';
            item.FileAdapter = 'Default';
            variableModel.insertItem(item);
            variableModel.save()
            testCase.addTeardown(@() variableModel.removeItem('Values'))

            session = testCase.Project.getSessionObjects(testCase.SessionIDs(1));
            Values = magic(3);
            save(fullfile(session.getSessionFolder('MockData'), 'values.mat'), 'Values')

            data = session.loadData('Values');

            testCase.verifyEqual(data, magic(3))
        end

        function testUnknownSessionIDErrors(testCase)
            testCase.verifyError(@() testCase.Project.getSessionObjects("no-such-session"), ...
                'NANSEN:Project:SessionNotFound')
        end
    end
end
