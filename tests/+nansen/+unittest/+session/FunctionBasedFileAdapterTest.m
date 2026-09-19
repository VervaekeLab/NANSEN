classdef FunctionBasedFileAdapterTest < matlab.unittest.TestCase
%FunctionBasedFileAdapterTest - Data variables whose file adapter is function-based
%
%   A function-based file adapter is a folder with a fileadapter.json and
%   read and write functions, such as MatFile of the core module. The mock
%   project gets the variable Values, with the adapter MatFile, and a .mat
%   file for it in the first session folder.
%
%   Run tests:
%       runtests('nansen.unittest.session.FunctionBasedFileAdapterTest')

    properties
        Project
        Session
    end

    methods (TestClassSetup)
        function setupProject(testCase)
            testCase.applyFixture(nansen.fixture.ProjectFixture)
            testCase.Project = nansen.getCurrentProject();

            % The new item copies the fields of the mock project's item,
            % which has fields that a default item lacks
            variableModel = testCase.Project.VariableModel;
            item = variableModel.Data(1);
            item.VariableName = 'Values';
            item.Uuid = nansen.util.getuuid();
            item.FilePathPattern = '';
            item.FileNameExpression = 'values';
            item.FileType = '.mat';
            item.FileAdapter = 'MatFile';
            item.DataType = '';
            variableModel.insertItem(item);
            variableModel.save()

            testCase.Session = testCase.Project.getSessionObjects( ...
                testCase.Project.MetaTableCatalog.getMasterMetaTable('session').entries.sessionID{1});
            Values = magic(3);
            save(fullfile(testCase.Session.getSessionFolder('MockData'), 'values.mat'), 'Values')
        end
    end

    methods (Test)
        function testInsertedVariableGetsDataTypeOfAdapter(testCase)
            item = testCase.Project.VariableModel.getItem('Values');

            testCase.verifyEqual(item.DataType, 'struct')
        end

        function testLoadDataReadsWithFunctionBasedAdapter(testCase)
            data = testCase.Session.loadData('Values');

            testCase.verifyEqual(data.Values, magic(3))
        end

        function testSaveDataWritesWithFunctionBasedAdapter(testCase)
            testCase.addTeardown(@() testCase.Session.saveData('Values', struct('Values', magic(3))))

            testCase.Session.saveData('Values', struct('Values', magic(4)))

            data = testCase.Session.loadData('Values');
            testCase.verifyEqual(data.Values, magic(4))
        end
    end
end
