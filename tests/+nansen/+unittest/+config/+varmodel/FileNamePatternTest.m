classdef FileNamePatternTest < matlab.unittest.TestCase
    %FileNamePatternTest Placeholders in file name expressions
    %
    %   A file name expression may hold placeholders such as {sessionID}
    %   that are replaced with session metadata. These tests cover the
    %   expansion, the validation of placeholder names and the conversion
    %   of an expanded expression to a file name and a regular expression.
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.varmodel.FileNamePatternTest')

    properties (Constant)
        Values = struct('sessionID', 'm001', 'subjectID', 'sub01')
    end

    properties (TestParameter)
        % Values that do not convert to one non-empty, non-missing string
        ValueWithoutText = struct( ...
            'emptyString', "", ...
            'nan', NaN, ...
            'missingString', string(missing), ...
            'stringArray', ["sub01", "sub02"])
    end

    methods (Test)

        function testHasPlaceholder(testCase)
            import nansen.config.varmodel.FileNamePattern

            testCase.verifyTrue( FileNamePattern.hasPlaceholder('{sessionID}_rois') )
            testCase.verifyTrue( FileNamePattern.hasPlaceholder("{subjectID}") )
            testCase.verifyFalse( FileNamePattern.hasPlaceholder('rois') )
            testCase.verifyFalse( FileNamePattern.hasPlaceholder('') )
        end

        function testExpandReplacesEveryPlaceholder(testCase)
            import nansen.config.varmodel.FileNamePattern

            expanded = FileNamePattern.expand('{subjectID}_{sessionID}_{sessionID}', testCase.Values);

            testCase.verifyEqual(expanded, 'sub01_m001_m001')
        end

        function testExpandLeavesPlainExpressionAlone(testCase)
            import nansen.config.varmodel.FileNamePattern

            testCase.verifyEqual( FileNamePattern.expand('rois', testCase.Values), 'rois' )
        end

        function testExpandRejectsMissingValue(testCase)
            import nansen.config.varmodel.FileNamePattern

            testCase.verifyError( ...
                @() FileNamePattern.expand('{sessionID}', struct('sessionID', '')), ...
                'NANSEN:VariableModel:MissingPlaceholderValue')
            testCase.verifyError( ...
                @() FileNamePattern.expand('{sessionID}', struct()), ...
                'NANSEN:VariableModel:MissingPlaceholderValue')
        end

        function testValueWithoutTextIsMissing(testCase, ValueWithoutText)
        %testValueWithoutTextIsMissing A value counts only when it gives text
        %   Such a value would expand {subjectID}_anat to _anat, or fail
        %   when converted to text.
            import nansen.config.varmodel.FileNamePattern

            values = struct();
            values.subjectID = ValueWithoutText;

            testCase.verifyFalse( FileNamePattern.canExpand('{subjectID}_anat', values) )
            testCase.verifyError( @() FileNamePattern.expand('{subjectID}_anat', values), ...
                'NANSEN:VariableModel:MissingPlaceholderValue')
        end

        function testValueIsConvertedToText(testCase)
        %testValueIsConvertedToText A string or a number expands as its text
            import nansen.config.varmodel.FileNamePattern

            testCase.verifyEqual( ...
                FileNamePattern.expand('{subjectID}_anat', struct('subjectID', "sub01")), 'sub01_anat')
            testCase.verifyEqual( ...
                FileNamePattern.expand('{subjectID}_anat', struct('subjectID', 12)), '12_anat')
        end

        function testMissingValueMessageNamesPlaceholder(testCase)
        %testMissingValueMessageNamesPlaceholder The message says which value to set
            import nansen.config.varmodel.FileNamePattern

            values = struct('sessionID', 'm001', 'subjectID', "");
            [isExpandable, message] = FileNamePattern.canExpand('{sessionID}_{subjectID}', values);

            testCase.verifyFalse(isExpandable)
            testCase.verifySubstring(message, 'The placeholder {subjectID}')
            testCase.verifySubstring(message, 'Set the subjectID of the session')
        end

        function testIsValidMessageNamesUnknownPlaceholder(testCase)
        %testIsValidMessageNamesUnknownPlaceholder The message lists the unknown and the valid names
            import nansen.config.varmodel.FileNamePattern

            [isExpressionValid, message] = FileNamePattern.isValid('{sessionId}_dff');

            testCase.verifyFalse(isExpressionValid)
            testCase.verifySubstring(message, 'unknown placeholder: {sessionId}')
            testCase.verifySubstring(message, '{sessionID}, {subjectID}')

            [isExpressionValid, message] = FileNamePattern.isValid('{sessionID}_dff');

            testCase.verifyTrue(isExpressionValid)
            testCase.verifyEmpty(message)
        end

        function testUnknownPlaceholderIsRejected(testCase)
            import nansen.config.varmodel.FileNamePattern

            testCase.verifyError( @() FileNamePattern.assertValid('{sessionId}'), ...
                'NANSEN:VariableModel:UnknownPlaceholder')
            testCase.verifyError( @() FileNamePattern.expand('{sessionId}', testCase.Values), ...
                'NANSEN:VariableModel:UnknownPlaceholder')
            testCase.verifyWarningFree( @() FileNamePattern.assertValid('{sessionID}') )
            testCase.verifyWarningFree( @() FileNamePattern.assertValid('rois') )
        end

        function testCanExpand(testCase)
            import nansen.config.varmodel.FileNamePattern

            testCase.verifyTrue( FileNamePattern.canExpand('{sessionID}', testCase.Values) )
            testCase.verifyTrue( FileNamePattern.canExpand('rois', struct()) )
            testCase.verifyFalse( FileNamePattern.canExpand('{sessionID}', struct()) )
            testCase.verifyFalse( FileNamePattern.canExpand('{sessionID}', struct('sessionID', '')) )
            testCase.verifyFalse( FileNamePattern.canExpand('{sessionId}', testCase.Values) )
        end

        function testToFileNameAppendsExtensionOnce(testCase)
            import nansen.config.varmodel.FileNamePattern

            testCase.verifyEqual( FileNamePattern.toFileName('m001', '.nwb'), 'm001.nwb' )
            testCase.verifyEqual( FileNamePattern.toFileName('m001', 'nwb'), 'm001.nwb' )
            testCase.verifyEqual( FileNamePattern.toFileName('m001.nwb', '.nwb'), 'm001.nwb' )
        end

        function testToRegexpMatchesWholeNameWithWildcard(testCase)
            import nansen.config.varmodel.FileNamePattern

            exact = FileNamePattern.toRegexp('m001.nwb');
            testCase.verifyNotEmpty( regexp('m001.nwb', exact, 'once') )
            testCase.verifyEmpty( regexp('m001_extra.nwb', exact, 'once') )
            testCase.verifyEmpty( regexp('m001xnwb', exact, 'once') )

            wildcard = FileNamePattern.toRegexp('m001*.nwb');
            testCase.verifyNotEmpty( regexp('m001.nwb', wildcard, 'once') )
            testCase.verifyNotEmpty( regexp('m001_extra.nwb', wildcard, 'once') )
            testCase.verifyEmpty( regexp('m002.nwb', wildcard, 'once') )
        end
    end
end
