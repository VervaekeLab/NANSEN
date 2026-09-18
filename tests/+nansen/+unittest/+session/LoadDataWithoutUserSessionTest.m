classdef LoadDataWithoutUserSessionTest < matlab.unittest.TestCase
%LoadDataWithoutUserSessionTest - Load data from a session object when no user session is active
%
%   A session object holds its data-location and variable models, so it
%   can load data where no NANSEN user session is active, such as in a
%   parallel worker. The mock project's first session gets a .mat file for
%   the variable LocalData; the test ends the user session and loads it.
%   The user session is ended in this class only, because the other
%   session tests hold the project object of the session.
%
%   Run tests:
%       runtests('nansen.unittest.session.LoadDataWithoutUserSessionTest')

    properties (Constant)
        VariableName = 'LocalData'
        StoredValue = magic(4)
    end

    properties
        Session
    end

    methods (TestClassSetup)
        function setupProject(testCase)
            testCase.applyFixture(nansen.fixture.ProjectFixture)
            project = nansen.getCurrentProject();

            % The new item copies the fields of the mock project's item,
            % which has fields that a default item lacks
            variableModel = project.VariableModel;
            item = variableModel.Data(1);
            item.VariableName = testCase.VariableName;
            item.Uuid = nansen.util.getuuid();
            item.DataLocation = 'MockData';
            item.FilePathPattern = '';
            item.FileNameExpression = 'local_data';
            item.FileType = '.mat';
            item.FileAdapter = 'Default';
            variableModel.insertItem(item);
            variableModel.save()

            sessionTable = project.MetaTableCatalog.getMasterMetaTable('session');
            testCase.Session = sessionTable.getMetaObjects(1, ...
                'DataLocationModel', project.DataLocationModel, ...
                'VariableModel', variableModel);

            LocalData = testCase.StoredValue; %#ok<NASGU> Saved by name
            save(fullfile(testCase.Session.getSessionFolder('MockData'), 'local_data.mat'), 'LocalData')
        end
    end

    methods (TestMethodSetup)
        function endUserSession(testCase)
            % The fixture's teardown starts the test profile's user
            % session again to remove the mock project
            userName = nansen.internal.user.NansenUserSession.instance('', 'nocreate').CurrentUserName;
            nansen.internal.user.NansenUserSession.instance(userName, 'reset');
            testCase.assertEmpty(nansen.internal.user.NansenUserSession.instance('', 'nocreate'))
        end
    end

    methods (Test)
        function testLoadDataReadsLocalFile(testCase)
            data = testCase.Session.loadData(testCase.VariableName);

            testCase.verifyEqual(data, testCase.StoredValue)
        end
    end
end
