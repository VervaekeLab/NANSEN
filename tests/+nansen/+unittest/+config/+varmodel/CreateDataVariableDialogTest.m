classdef CreateDataVariableDialogTest < matlab.unittest.TestCase
%CreateDataVariableDialogTest The form for creating a data variable from a file
%
%   Covers nansen.config.varmodel.uiCreateDataVariableFromFile. A stub
%   replaces tools.editStruct, which records the options it is given and
%   answers with the values a test sets, so no window opens. The tests run
%   inside a temporary project, because the form lists the file adapters
%   of the current project. Each test uses a variable model stored in its
%   own temporary folder.
%
%   Run tests:
%       runtests('nansen.unittest.config.varmodel.CreateDataVariableDialogTest')

    properties (Constant, Access = private)
        OptionsKey = 'CreateDataVariableTestOptions'
        AnswerKey = 'CreateDataVariableTestAnswer'
        SessionFolder = fullfile(filesep, 'data', 'session01')
        SessionId = 'session01'
        MatchingExpression = 'traces'
    end

    properties (Access = private)
        Model
    end

    properties (TestParameter)
        InvalidName = struct( ...
            'Empty', '', ...
            'Space', 'my variable', ...
            'LeadingDigit', '1variable', ...
            'Hyphen', 'my-variable')

        InvalidExpression = struct( ...
            'Empty', '', ...
            'NoMatch', 'other')
    end

    methods (TestClassSetup)
        function setupProjectAndStub(testCase)
        %setupProjectAndStub Use a temporary project and a stub of the editor
        %
        %   The stub is added to the path after the project is created, so
        %   that it comes before the toolbox folder the project fixture adds.

            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.TemporaryFolderFixture

            testCase.applyFixture(nansen.fixture.ProjectFixture())

            stubRoot = string(testCase.applyFixture(TemporaryFolderFixture).Folder);
            mkdir(fullfile(stubRoot, "+tools"))
            writelines([ ...
                "function [S, wasAborted] = editStruct(S, ~, ~, varargin)"; ...
                "    setappdata(groot, '" + testCase.OptionsKey + "', struct(varargin{:}))"; ...
                "    answer = getappdata(groot, '" + testCase.AnswerKey + "');"; ...
                "    wasAborted = isempty(answer);"; ...
                "    if ~wasAborted"; ...
                "        S.VariableName = answer.VariableName;"; ...
                "        S.FileNameExpression = answer.FileNameExpression;"; ...
                "    end"; ...
                "end"], fullfile(stubRoot, "+tools", "editStruct.m"))
            testCase.applyFixture(PathFixture(stubRoot))

            setappdata(groot, testCase.OptionsKey, struct.empty)
            setappdata(groot, testCase.AnswerKey, struct.empty)
            testCase.addTeardown(@rmappdata, groot, testCase.OptionsKey)
            testCase.addTeardown(@rmappdata, groot, testCase.AnswerKey)

            testCase.assertTrue(startsWith(string(which('tools.editStruct')), stubRoot), ...
                'Expected the stub of tools.editStruct to be first on the path.')
            testCase.assertEqual(string(nansen.getCurrentProject().Name), ...
                string(nansen.fixture.ProjectFixture.MockProjectName))
        end
    end

    methods (TestMethodSetup)
        function useIsolatedModel(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            setappdata(groot, testCase.AnswerKey, struct.empty)

            fixture = testCase.applyFixture(TemporaryFolderFixture);
            modelFilePath = fullfile(fixture.Folder, 'variable_model.mat');
            testCase.Model = nansen.config.varmodel.VariableModel(modelFilePath);
            testCase.assertEqual(string(testCase.Model.FilePath), string(modelFilePath))
        end
    end

    methods (Test)

        function testValidValuesHaveNoProblem(testCase)
            problems = testCase.getProblems(testCase.createValues('newVariable'));

            testCase.verifyEmpty(problems)
        end

        function testInvalidNameIsRefused(testCase, InvalidName)
            problems = testCase.getProblems(testCase.createValues(InvalidName));

            testCase.verifyNumElements(problems, 1)
        end

        function testNameInUseIsRefused(testCase)
            testCase.Model.insertItem(testCase.Model.getDefaultItem('existingVariable'))

            problems = testCase.getProblems(testCase.createValues('existingVariable'));

            testCase.verifyNumElements(problems, 1)
        end

        function testExpressionThatFindsNoFileIsRefused(testCase, InvalidExpression)
            problems = testCase.getProblems(testCase.createValues('newVariable', InvalidExpression));

            testCase.verifyNumElements(problems, 1)
        end

        function testAllProblemsAreReported(testCase)
            problems = testCase.getProblems(testCase.createValues('my variable', 'other'));

            testCase.verifyNumElements(problems, 2)
        end

        function testFormWithoutNameHasNoNameProblem(testCase)
            testCase.createDataVariable("SkipFields", "VariableName");
            getProblems = testCase.getRecordedValidationFcn();

            problems = getProblems(struct('FileNameExpression', testCase.MatchingExpression));

            testCase.verifyEmpty(problems(strlength(problems) > 0))
        end

        function testCancelReturnsNothing(testCase)
            varItem = testCase.createDataVariable();

            testCase.verifyEmpty(varItem)
        end

        function testAcceptedValuesCreateItem(testCase)
            setappdata(groot, testCase.AnswerKey, testCase.createValues('acceptedVariable'))

            varItem = testCase.createDataVariable();

            testCase.verifyEqual(varItem.VariableName, 'acceptedVariable')
            testCase.verifyEqual(varItem.FileNameExpression, testCase.MatchingExpression)
            testCase.verifyEqual(varItem.FileType, '.dat')
            testCase.verifyTrue(varItem.IsCustom)
        end
    end

    methods (Access = private)

        function varItem = createDataVariable(testCase, options)
            arguments
                testCase
                options.SkipFields (1,:) string = string.empty
            end

            filePath = fullfile(testCase.SessionFolder, 'session01_traces.dat');
            sessionObject = struct( ...
                'VariableModel', testCase.Model, ...
                'sessionID', testCase.SessionId, ...
                'getDataLocation', @(~) struct('Uuid', 'data-location-uuid'), ...
                'getSessionFolder', @(~) testCase.SessionFolder);

            varItem = nansen.config.varmodel.uiCreateDataVariableFromFile( ...
                filePath, 'Rawdata', sessionObject, 'SkipFields', options.SkipFields);
        end

        function validationFcn = getRecordedValidationFcn(testCase)
            editorOptions = getappdata(groot, testCase.OptionsKey);
            validationFcn = editorOptions.ValidationFcn;
        end

        function problems = getProblems(testCase, values)
        %getProblems Get the problems the editor would report for the values
            testCase.createDataVariable();
            getInputProblems = testCase.getRecordedValidationFcn();

            problems = getInputProblems(values);
            problems = problems(strlength(problems) > 0);
        end
    end

    methods (Static, Access = private)

        function values = createValues(variableName, expression)
            arguments
                variableName
                expression = nansen.unittest.config.varmodel.CreateDataVariableDialogTest.MatchingExpression
            end

            values = struct('VariableName', variableName, 'FileNameExpression', expression);
        end
    end
end
