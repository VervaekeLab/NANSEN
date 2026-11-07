classdef DetectFileAdapterForFilepathTest < matlab.unittest.TestCase
%DetectFileAdapterForFilepathTest - Choose the file adapter that nansen.load and nansen.save use
%
%   The adapter list is given to the function, so no project is needed.
%
%   Run tests:
%       runtests('nansen.unittest.plugin.DetectFileAdapterForFilepathTest')

    properties
        AdapterList
    end

    methods (TestMethodSetup)
        function createAdapterList(testCase)
            testCase.AdapterList = struct( ...
                'FunctionName', {'test.Gzip', 'test.NIfTI', 'test.MatFile'}, ...
                'SupportedFileTypes', {{'gz'}, {'nii', 'nii.gz'}, {'.mat'}}, ...
                'IsDynamic', {false, false, true});
        end
    end

    methods (Test)
        function testSingleExtension(testCase)
            [name, isDynamic] = nansen.plugin.fileadapter.internal.detectFileAdapterForFilepath( ...
                fullfile('data', 'values.mat'), testCase.AdapterList);

            testCase.verifyEqual(name, 'test.MatFile')
            testCase.verifyTrue(isDynamic)
        end

        function testExtensionOfSeveralPartsPrefersLongestType(testCase)
            name = nansen.plugin.fileadapter.internal.detectFileAdapterForFilepath( ...
                fullfile('data', 'run.nii.gz'), testCase.AdapterList);

            testCase.verifyEqual(name, 'test.NIfTI')
        end

        function testCaseIsIgnored(testCase)
            name = nansen.plugin.fileadapter.internal.detectFileAdapterForFilepath( ...
                fullfile('data', 'RUN.NII'), testCase.AdapterList);

            testCase.verifyEqual(name, 'test.NIfTI')
        end

        function testUnsupportedTypeErrors(testCase)
            testCase.verifyError(@() nansen.plugin.fileadapter.internal.detectFileAdapterForFilepath( ...
                fullfile('data', 'trace.abf'), testCase.AdapterList), ?MException)
        end
    end
end
