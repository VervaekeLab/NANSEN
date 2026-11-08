classdef FileAdapterDialogValidationTest < matlab.unittest.TestCase
%FileAdapterDialogValidationTest The name check of the Create File Adapter dialog
%
%   Covers the ValidationFcn that
%   nansen.plugin.fileadapter.uigetFileAdapterAttributes gives the struct
%   editor. A stub replaces tools.editStruct and records the options it is
%   given, so no window opens. The tests run inside a temporary project,
%   because the dialog checks names against the file adapter folder of the
%   current project.
%
%   Run tests:
%       runtests('nansen.unittest.plugin.FileAdapterDialogValidationTest')

    properties (Constant, Access = private)
        OptionsKey = 'FileAdapterDialogTestOptions'
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
            stubFolder = fullfile(stubRoot, "+tools");
            mkdir(stubFolder)
            writelines([ ...
                "function [S, wasAborted] = editStruct(S, ~, ~, varargin)"; ...
                "    setappdata(groot, '" + testCase.OptionsKey + "', struct(varargin{:}))"; ...
                "    wasAborted = true;"; ...
                "end"], fullfile(stubFolder, "editStruct.m"))
            testCase.applyFixture(PathFixture(stubRoot))

            setappdata(groot, testCase.OptionsKey, struct.empty)
            testCase.addTeardown(@rmappdata, groot, testCase.OptionsKey)

            testCase.assertTrue(startsWith(string(which('tools.editStruct')), stubRoot), ...
                'Expected the stub of tools.editStruct to be first on the path.')
            testCase.assertEqual(string(nansen.getCurrentProject().Name), ...
                string(nansen.fixture.ProjectFixture.MockProjectName))
        end
    end

    methods (Test)

        function testNewNameIsAccepted(testCase)
            getProblem = testCase.getDialogValidationFcn();

            testCase.verifyEqual(getProblem(struct('Name', 'NewAdapter')), "")
        end

        function testInvalidNameIsRefused(testCase)
            getProblem = testCase.getDialogValidationFcn();

            problem = getProblem(struct('Name', 'my adapter'));

            testCase.verifyGreaterThan(strlength(problem), 0)
        end

        function testNameInProjectFolderIsRefused(testCase)
            fileAdapterFolder = nansen.getCurrentProject().getFileAdapterFolder();
            mkdir(fullfile(fileAdapterFolder, '+ExistingAdapter'))
            getProblem = testCase.getDialogValidationFcn();

            problem = getProblem(struct('Name', 'ExistingAdapter'));

            testCase.verifyGreaterThan(strlength(problem), 0)
        end
    end

    methods (Access = private)

        function validationFcn = getDialogValidationFcn(testCase)
            nansen.plugin.fileadapter.uigetFileAdapterAttributes();
            options = getappdata(groot, testCase.OptionsKey);
            validationFcn = options.ValidationFcn;
        end
    end
end
