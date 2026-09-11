classdef ExtractionPatternTest < matlab.unittest.TestCase
    %ExtractionPatternTest Index extraction of metadata from folder and file names
    %
    %   An ind rule is a MATLAB index expression such as 1:6 or 5:end. The
    %   expression is evaluated on its own rather than inside an indexing
    %   expression, where end has no value. Since a refactor in March only
    %   the exact pattern 1:end worked, which broke the shipped BIDS and
    %   SciScan data location templates (5:end and 19:end).
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.ExtractionPatternTest')

    properties (Constant)
        FileName = '170518_1a.ABF'
    end

    properties (TestParameter)
        indexCase = { ...
            {'1:6', '170518'}, ...
            {'1:end', '170518_1a.ABF'}, ...
            {'5:end', '18_1a.ABF'}, ...
            {'1:end-4', '170518_1a'}, ...
            {'end-2:end', 'ABF'}, ...
            {'[1:6, 8]', '1705181'}}
    end

    methods (Static, Access = private)
        function value = extract(text, pattern)
            value = nansen.config.dloc.DataLocationModel.applyExtractionPattern( ...
                text, 'ind', pattern);
        end
    end

    methods (Test)

        function testIndexPatterns(testCase, indexCase)
            testCase.verifyEqual(testCase.extract(testCase.FileName, indexCase{1}), ...
                indexCase{2})
        end

        function testBidsTemplateExtractsTheSubject(testCase)
            % The template reads the subject id after the "sub-" prefix.
            repositoryRoot = fileparts(fileparts(fileparts(fileparts(fileparts( ...
                mfilename('fullpath'))))));
            template = jsondecode(fileread(fullfile(repositoryRoot, 'code', 'modules', ...
                '+nansen', '+module', '+general', '+core', 'resources', 'datalocations', 'bids.json')));

            subjectRule = template.MetaDataDef(strcmp({template.MetaDataDef.VariableName}, 'Subject ID'));
            testCase.assertEqual(subjectRule.StringDetectInput, '5:end')

            testCase.verifyEqual(testCase.extract('sub-01', subjectRule.StringDetectInput), '01')
        end

        function testIndexOutsideTheTextRaises(testCase)
            testCase.verifyError(@() testCase.extract(testCase.FileName, '1:99'), ...
                'NANSEN:DataLocationModel:IndexOutOfRange')
            testCase.verifyError(@() testCase.extract(testCase.FileName, 'end-99:end'), ...
                'NANSEN:DataLocationModel:IndexOutOfRange')
        end

        function testInvalidPatternRaises(testCase)
            testCase.verifyError(@() testCase.extract(testCase.FileName, '1:('), ...
                'NANSEN:DataLocationModel:InvalidIndexPattern')
        end
    end
end
