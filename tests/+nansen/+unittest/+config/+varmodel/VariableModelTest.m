classdef VariableModelTest < matlab.unittest.TestCase
    %VariableModelTest Adding data variables to the variable model
    %
    %   Session objects expose every variable in the model as a dynamic
    %   property, so a name the model accepts has to be a valid MATLAB
    %   identifier. Every insertion passes through the model, which makes
    %   it the layer that has to refuse any other name.
    %
    %   The model looks up file adapters through the current project, so the
    %   tests run inside a temporary project. Each test then works on a model
    %   stored in a temporary folder of its own, so nothing is read from or
    %   written to the projects of whoever runs the tests.
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.varmodel.VariableModelTest')

    properties
        ModelFilePath
    end

    properties (TestParameter)
        InvalidName = struct( ...
            'empty', '', ...
            'space', 'my var', ...
            'leadingDigit', '1abc', ...
            'hyphen', 'dff-trace')
    end

    methods (TestClassSetup)
        function useTemporaryProject(testCase)
        %useTemporaryProject Provide the project the file adapter lookup needs
            testCase.applyFixture(nansen.fixture.ProjectFixture())
        end
    end

    methods (TestMethodSetup)
        function useIsolatedModelFile(testCase)
        %useIsolatedModelFile Store the model in a temporary folder

            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.ModelFilePath = fullfile(fixture.Folder, 'variable_model.mat');
        end
    end

    methods (Test)

        function testValidNameIsAdded(testCase)
            model = testCase.createModel();

            model.insertItem( testCase.createItem('dffTrace') )

            testCase.verifyEqual(model.VariableNames, {'dffTrace'})
        end

        function testInvalidNameIsRefused(testCase, InvalidName)
        %testInvalidNameIsRefused A name that is not an identifier is an error
            model = testCase.createModel();

            testCase.verifyError( ...
                @() model.insertItem( testCase.createItem(InvalidName) ), ...
                'NANSEN:VariableModel:InvalidVariableName')
            testCase.verifyEqual(model.NumVariables, 0)
        end

        function testRefusedItemIsNotSaved(testCase)
        %testRefusedItemIsNotSaved A refused item never reaches the model file
            model = testCase.createModel();

            testCase.verifyError( ...
                @() model.insertItem( testCase.createItem('') ), ...
                'NANSEN:VariableModel:InvalidVariableName')

            reloadedModel = testCase.createModel();
            testCase.verifyEqual(reloadedModel.NumVariables, 0)
        end

        function testInvalidNameIsRefusedOnReplace(testCase)
        %testInvalidNameIsRefusedOnReplace Replacing an item checks the name too
            model = testCase.createModel();
            model.insertItem( testCase.createItem('dffTrace') )

            item = model.getItem('dffTrace');
            item.VariableName = '';

            testCase.verifyError(@() model.replaceItem(item), ...
                'NANSEN:VariableModel:InvalidVariableName')
            testCase.verifyEqual(model.VariableNames, {'dffTrace'})
        end

        function testUnknownPlaceholderIsRefused(testCase)
        %testUnknownPlaceholderIsRefused A file name expression must use known placeholders
            model = testCase.createModel();
            item = testCase.createItem('dffTrace');
            item.FileNameExpression = '{sessionId}_dff';

            testCase.verifyError(@() model.insertItem(item), ...
                'NANSEN:VariableModel:UnknownPlaceholder')
            testCase.verifyEqual(model.NumVariables, 0)
        end
    end

    methods (Access = private)
        function model = createModel(testCase)
            model = nansen.config.varmodel.VariableModel(testCase.ModelFilePath);
        end
    end

    methods (Static, Access = private)
        function item = createItem(variableName)
            item = nansen.config.varmodel.VariableModel.getDefaultItem(variableName);
        end
    end
end
