classdef ExtractionPatternTest < matlab.unittest.TestCase
    %ExtractionPatternTest Extracting a metadata value from a folder name
    %
    %   A metadata definition extracts its value from a folder name with a
    %   character index pattern (mode 'ind') or a regular expression (mode
    %   'expr'). These tests cover the index patterns a user can type in the
    %   metadata table, in particular 'end' combined with arithmetic, and the
    %   errors reported for patterns that cannot be applied.
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.dloc.ExtractionPatternTest')

    properties (Constant)
        FolderName = 'm001_20240115_01' % 16 characters
    end

    methods (Test)

        function testFixedRangeSelectsThoseCharacters(testCase)
        %testFixedRangeSelectsThoseCharacters A numeric range is applied as it is
            testCase.verifyEqual(testCase.extract('1:4'), 'm001')
        end

        function testEndIsTheLastCharacter(testCase)
        %testEndIsTheLastCharacter 'end' stands for the last character of the name
            testCase.verifyEqual(testCase.extract('1:end'), testCase.FolderName)
            testCase.verifyEqual(testCase.extract('6:end'), '20240115_01')
        end

        function testEndAcceptsArithmetic(testCase)
        %testEndAcceptsArithmetic 'end' can be offset at either side of the range
            testCase.verifyEqual(testCase.extract('1:end-3'), 'm001_20240115')
            testCase.verifyEqual(testCase.extract('end-1:end'), '01')
            testCase.verifyEqual(testCase.extract('6:end-3'), '20240115')
        end

        function testStepsAndMultipleRanges(testCase)
        %testStepsAndMultipleRanges Any MATLAB index expression is accepted
            testCase.verifyEqual(testCase.extract('1:2:end'), 'm0_04150')
            testCase.verifyEqual(testCase.extract('1:4,end-1:end'), 'm00101')
        end

        function testInvalidPatternIsReported(testCase)
        %testInvalidPatternIsReported A pattern that is not index syntax raises a named error
            testCase.verifyError(@() testCase.extract('1:'), ...
                'NANSEN:DataLocationModel:InvalidIndexPattern')
        end

        function testOutOfRangePatternIsReported(testCase)
        %testOutOfRangePatternIsReported Indices outside the name raise a named error
            testCase.verifyError(@() testCase.extract('1:end+1'), ...
                'NANSEN:DataLocationModel:IndexOutOfRange')
            testCase.verifyError(@() testCase.extract('end-20:end'), ...
                'NANSEN:DataLocationModel:IndexOutOfRange')
        end

        function testRegularExpressionReturnsFirstMatch(testCase)
        %testRegularExpressionReturnsFirstMatch Mode 'expr' returns the first match or nothing
            import nansen.config.dloc.DataLocationModel

            testCase.verifyEqual( ...
                DataLocationModel.applyExtractionPattern(testCase.FolderName, 'expr', '\d{8}'), ...
                '20240115')
            testCase.verifyEmpty( ...
                DataLocationModel.applyExtractionPattern(testCase.FolderName, 'expr', '[a-z]{3}'))
        end
    end

    methods (Access = private)
        function substring = extract(testCase, pattern)
            substring = nansen.config.dloc.DataLocationModel.applyExtractionPattern( ...
                testCase.FolderName, 'ind', pattern);
        end
    end
end
