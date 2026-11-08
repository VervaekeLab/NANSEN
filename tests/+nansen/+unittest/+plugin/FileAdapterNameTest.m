classdef FileAdapterNameTest < matlab.unittest.TestCase
%FileAdapterNameTest Which names a new file adapter can have
%
%   Covers nansen.plugin.fileadapter.internal.getNameProblem and the check
%   nansen.plugin.fileadapter.createFileAdapter makes with it. A refused
%   name raises its error before createFileAdapter changes the current
%   folder or opens the MATLAB editor, so the tests can call it directly.
%
%   Run tests:
%       runtests('nansen.unittest.plugin.FileAdapterNameTest')

    properties (Constant)
        ExistingName = "ExistingAdapter"
        UserCode = "% code the user wrote"
    end

    properties
        TargetFolder (1,1) string
    end

    properties (TestParameter)
        InvalidName = struct( ...
            'Empty', "", ...
            'Space', "my adapter", ...
            'LeadingDigit', "1adapter", ...
            'Hyphen', "my-adapter", ...
            'Keyword', "for")

        ExistingAdapterFile = struct( ...
            'FunctionBased', fullfile("+ExistingAdapter", "read.m"), ...
            'ClassFolder', fullfile("@ExistingAdapter", "read.m"), ...
            'ClassFile', "ExistingAdapter.m")

        ImplementationType = struct('Function', "Function", 'Class', "Class")
    end

    methods (TestMethodSetup)
        function createTargetFolder(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.TargetFolder = fixture.Folder;
            testCase.assertTrue(startsWith(testCase.TargetFolder, tempdir), ...
                sprintf('Expected "%s" to be inside "%s"', testCase.TargetFolder, tempdir))
        end
    end

    methods (Test)

        function testNewNameHasNoProblem(testCase)
            problem = testCase.getProblem("NewAdapter");

            testCase.verifyEqual(problem, "")
        end

        function testInvalidNameHasProblem(testCase, InvalidName)
            problem = testCase.getProblem(InvalidName);

            testCase.verifyGreaterThan(strlength(problem), 0)
        end

        function testNameInTargetFolderHasProblem(testCase, ExistingAdapterFile)
            testCase.createExistingAdapter(ExistingAdapterFile)

            problem = testCase.getProblem(testCase.ExistingName);

            testCase.verifyGreaterThan(strlength(problem), 0)
        end

        function testCreateRefusesInvalidName(testCase, InvalidName)
            testCase.verifyCreateIsRefused(InvalidName, "Function")

            listing = dir(testCase.TargetFolder);
            testCase.verifyEmpty(setdiff({listing.name}, {'.', '..'}))
        end

        function testCreateKeepsExistingAdapter(testCase, ExistingAdapterFile, ImplementationType)
            filePath = testCase.createExistingAdapter(ExistingAdapterFile);

            testCase.verifyCreateIsRefused(testCase.ExistingName, ImplementationType)

            testCase.verifySubstring(string(fileread(filePath)), testCase.UserCode)
        end
    end

    methods (Access = private)

        function problem = getProblem(testCase, name)
            problem = nansen.plugin.fileadapter.internal.getNameProblem(name, testCase.TargetFolder);
        end

        function filePath = createExistingAdapter(testCase, relativePath)
            filePath = fullfile(testCase.TargetFolder, relativePath);
            folderPath = fileparts(filePath);
            if ~isfolder(folderPath)
                mkdir(folderPath)
            end
            writelines(testCase.UserCode, filePath)
        end

        function verifyCreateIsRefused(testCase, name, implementationType)
            metaProperties = struct('Name', name, 'SupportedFileTypes', "dat", 'DataType', "double");
            fileAdapterMeta = nansen.plugin.fileadapter.FileAdapterMeta(metaProperties);
            fileAdapterMeta.ImplementationType = implementationType;

            testCase.verifyError( ...
                @() nansen.plugin.fileadapter.createFileAdapter(testCase.TargetFolder, fileAdapterMeta, "R"), ...
                'NANSEN:CreateFileAdapter:InvalidName')
        end
    end
end
