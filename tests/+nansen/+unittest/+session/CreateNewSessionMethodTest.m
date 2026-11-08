classdef CreateNewSessionMethodTest < matlab.unittest.TestCase
%CreateNewSessionMethodTest Creating a session method through its dialog
%
%   Covers nansen.session.methods.template.createNewSessionMethod. Stubs
%   replace tools.editStruct, which answers with the values a test sets, and
%   edit, so no window opens. The tests run inside a temporary project,
%   because a method is saved in the method folder of the current project.
%
%   Run tests:
%       runtests('nansen.unittest.session.CreateNewSessionMethodTest')

    properties (Constant, Access = private)
        OptionsKey = 'CreateSessionMethodTestOptions'
        AnswerKey = 'CreateSessionMethodTestAnswer'
    end

    methods (TestClassSetup)
        function setupProjectAndStubs(testCase)
        %setupProjectAndStubs Use a temporary project and stubs of the windows
        %
        %   The stubs are added to the path after the project is created, so
        %   that they come before the toolbox folder the project fixture adds.

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
                "        S.MethodName = answer.MethodName;"; ...
                "        S.MenuSubLocation = answer.MenuSubLocation;"; ...
                "    end"; ...
                "end"], fullfile(stubRoot, "+tools", "editStruct.m"))
            writelines([ ...
                "function edit(varargin)"; ...
                "end"], fullfile(stubRoot, "edit.m"))
            testCase.applyFixture(PathFixture(stubRoot))

            setappdata(groot, testCase.OptionsKey, struct.empty)
            setappdata(groot, testCase.AnswerKey, struct.empty)
            testCase.addTeardown(@rmappdata, groot, testCase.OptionsKey)
            testCase.addTeardown(@rmappdata, groot, testCase.AnswerKey)

            testCase.assertTrue(startsWith(string(which('tools.editStruct')), stubRoot), ...
                'Expected the stub of tools.editStruct to be first on the path.')
            testCase.assertTrue(startsWith(string(which('edit')), stubRoot), ...
                'Expected the stub of edit to be first on the path.')
            testCase.assertEqual(string(nansen.getCurrentProject().Name), ...
                string(nansen.fixture.ProjectFixture.MockProjectName))
        end
    end

    methods (TestMethodTeardown)
        function clearDialogAnswer(testCase)
            setappdata(groot, testCase.AnswerKey, struct.empty)
        end
    end

    methods (Test)

        function testAcceptedValuesCreateFile(testCase)
            testCase.answerDialog('acceptedMethod', '')

            wasSuccess = nansen.session.methods.template.createNewSessionMethod();

            expectedFile = fullfile(testCase.getMethodsFolder(), "+default", "acceptedMethod.m");
            testCase.verifyTrue(wasSuccess)
            testCase.verifySubstring(string(fileread(expectedFile)), "acceptedMethod")
        end

        function testSubLocationCreatesNestedNamespaces(testCase)
            testCase.answerDialog('nestedMethod', 'analysis, stats')

            nansen.session.methods.template.createNewSessionMethod();

            expectedFile = fullfile(testCase.getMethodsFolder(), ...
                "+default", "+analysis", "+stats", "nestedMethod.m");
            testCase.verifyTrue(isfile(expectedFile))
        end

        function testCancelCreatesNothing(testCase)
            wasSuccess = nansen.session.methods.template.createNewSessionMethod();

            testCase.verifyFalse(wasSuccess)
        end

        function testDialogRefusesInvalidName(testCase)
            getProblem = testCase.getDialogValidationFcn();

            problem = getProblem(testCase.createValues('my method'));

            testCase.verifyGreaterThan(strlength(problem), 0)
        end

        function testDialogRefusesExistingMethod(testCase)
            existingFile = fullfile(testCase.getMethodsFolder(), "+default", "existingMethod.m");
            mkdir(fileparts(existingFile))
            writelines("% code the user wrote", existingFile)
            getProblem = testCase.getDialogValidationFcn();

            problem = getProblem(testCase.createValues('existingMethod'));

            testCase.verifyGreaterThan(strlength(problem), 0)
        end

        function testDialogAcceptsNewName(testCase)
            getProblem = testCase.getDialogValidationFcn();

            testCase.verifyEqual(getProblem(testCase.createValues('newMethod')), "")
        end

        function testDialogAcceptsNameOfModuleMethod(testCase)
        %testDialogAcceptsNameOfModuleMethod A project can override a module method
            [menuLocation, methodName] = testCase.findModuleMethod();
            getProblem = testCase.getDialogValidationFcn();

            values = struct('MethodName', methodName, ...
                'MenuLocation', menuLocation, 'MenuSubLocation', '');

            testCase.verifyEqual(getProblem(values), "")
        end
    end

    methods (Access = private)

        function answerDialog(testCase, methodName, subLocation)
            answer = struct('MethodName', methodName, 'MenuSubLocation', subLocation);
            setappdata(groot, testCase.AnswerKey, answer)
        end

        function validationFcn = getDialogValidationFcn(testCase)
            nansen.session.methods.template.createNewSessionMethod();
            options = getappdata(groot, testCase.OptionsKey);
            validationFcn = options.ValidationFcn;
        end

        function folderPath = getMethodsFolder(~)
            folderPath = string(nansen.session.methods.template.internal.getProjectsSessionMethodsDirectory("Session"));
        end

        function [menuLocation, methodName] = findModuleMethod(testCase)
        %findModuleMethod Get the location of a method from a module of the project
            folderPaths = nansen.getCurrentProject().getObjectMethodFolder("Session");
            moduleFolders = folderPaths(2:end);

            listings = cellfun(@(folderPath) dir(fullfile(folderPath, "+*", "*.m")), ...
                moduleFolders, 'UniformOutput', false);
            listing = vertcat(listings{:});
            testCase.assumeNotEmpty(listing, 'Expected the project to include a module with methods.')

            [~, menuFolderName] = fileparts(listing(1).folder);
            menuLocation = extractAfter(menuFolderName, '+');
            [~, methodName] = fileparts(listing(1).name);
        end
    end

    methods (Static, Access = private)

        function values = createValues(methodName)
            values = struct('MethodName', methodName, ...
                'MenuLocation', 'default', 'MenuSubLocation', '');
        end
    end
end
