classdef NewSessionMethodInputTest < matlab.unittest.TestCase
%NewSessionMethodInputTest Which values can be used to create a session method
%
%   Covers nansen.session.methods.template.getInputProblem and
%   nansen.session.methods.template.getTargetFilePath, which the dialog of
%   createNewSessionMethod relies on. Everything happens in a temporary
%   folder that stands in for the method folder of a project.
%
%   Run tests:
%       runtests('nansen.unittest.session.NewSessionMethodInputTest')

    properties (Constant)
        MenuLocation = 'processing'
    end

    properties
        MethodsFolder (1,1) string
    end

    properties (TestParameter)
        InvalidMethodName = struct( ...
            'Empty', '', ...
            'Space', 'my method', ...
            'LeadingDigit', '1method', ...
            'Hyphen', 'my-method', ...
            'Keyword', 'for')

        ValidSubLocation = struct( ...
            'Empty', '', ...
            'OneName', 'analysis', ...
            'TwoNames', 'analysis, stats', ...
            'NoSpaceAfterComma', 'analysis,stats', ...
            'ExtraSpaces', '  analysis ,  stats  ')

        InvalidSubLocation = struct( ...
            'Space', 'my group', ...
            'LeadingDigit', '1group', ...
            'EmptyName', 'analysis,,stats', ...
            'TrailingComma', 'analysis,')
    end

    methods (TestMethodSetup)
        function createMethodsFolder(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.MethodsFolder = fixture.Folder;
        end
    end

    methods (Test)

        function testNewMethodHasNoProblem(testCase, ValidSubLocation)
            problem = testCase.getProblem('newMethod', ValidSubLocation);

            testCase.verifyEqual(problem, "")
        end

        function testInvalidMethodNameHasProblem(testCase, InvalidMethodName)
            problem = testCase.getProblem(InvalidMethodName, '');

            testCase.verifyGreaterThan(strlength(problem), 0)
        end

        function testInvalidSubLocationHasProblem(testCase, InvalidSubLocation)
            problem = testCase.getProblem('newMethod', InvalidSubLocation);

            testCase.verifyGreaterThan(strlength(problem), 0)
        end

        function testExistingMethodHasProblem(testCase, ValidSubLocation)
            testCase.createMethodFile('existingMethod', ValidSubLocation)

            problem = testCase.getProblem('existingMethod', ValidSubLocation);

            testCase.verifyGreaterThan(strlength(problem), 0)
        end

        function testSameNameAtOtherLocationHasNoProblem(testCase)
            testCase.createMethodFile('existingMethod', 'analysis')

            problem = testCase.getProblem('existingMethod', 'stats');

            testCase.verifyEqual(problem, "")
        end

        function testFileIsInNestedNamespaces(testCase)
            filePath = nansen.session.methods.template.getTargetFilePath( ...
                testCase.createValues('newMethod', 'analysis, stats'), testCase.MethodsFolder);

            expectedPath = fullfile(testCase.MethodsFolder, ...
                "+processing", "+analysis", "+stats", "newMethod.m");
            testCase.verifyEqual(filePath, expectedPath)
        end
    end

    methods (Access = private)

        function problem = getProblem(testCase, methodName, subLocation)
            problem = nansen.session.methods.template.getInputProblem( ...
                testCase.createValues(methodName, subLocation), testCase.MethodsFolder);
        end

        function values = createValues(testCase, methodName, subLocation)
            values = struct('MethodName', methodName, ...
                'MenuLocation', testCase.MenuLocation, ...
                'MenuSubLocation', subLocation);
        end

        function createMethodFile(testCase, methodName, subLocation)
            filePath = nansen.session.methods.template.getTargetFilePath( ...
                testCase.createValues(methodName, subLocation), testCase.MethodsFolder);
            mkdir(fileparts(filePath))
            writelines("% code the user wrote", filePath)
        end
    end
end
