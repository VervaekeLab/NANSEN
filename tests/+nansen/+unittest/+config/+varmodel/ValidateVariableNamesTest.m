classdef ValidateVariableNamesTest < matlab.unittest.TestCase
    %ValidateVariableNamesTest Checking the names of an edited variable list
    %
    %   The variable model app writes the edited table back to the model as
    %   one list, which does not pass through the checks that guard single
    %   insertions. validateVariableNames is the check the app runs on that
    %   list before saving it: every custom variable needs a name that is a
    %   valid MATLAB identifier and that no other variable in the list has.
    %
    %   The function is static and reads nothing from disk, so the tests need
    %   neither a project nor a model file.
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.varmodel.ValidateVariableNamesTest')

    properties (TestParameter)
        InvalidName = struct( ...
            'space', 'my var', ...
            'leadingDigit', '1abc', ...
            'hyphen', 'dff-trace', ...
            'keyword', 'end')
    end

    methods (Test)

        function testValidListPasses(testCase)
            variableList = [ ...
                testCase.createItem('presetVariable', 'preset'), ...
                testCase.createItem('customVariable', 'custom'), ...
                testCase.createItem('internalVariable', 'internal')];

            [isValid, message] = testCase.validate(variableList);

            testCase.verifyTrue(isValid)
            testCase.verifyEmpty(message)
        end

        function testEmptyListPasses(testCase)
            [isValid, message] = testCase.validate(struct([]));

            testCase.verifyTrue(isValid)
            testCase.verifyEmpty(message)
        end

        function testNamelessCustomVariableIsReported(testCase)
        %testNamelessCustomVariableIsReported A blank name is named by position
        %
        %   The position counts custom variables only, which is the order the
        %   app lists them in.
            variableList = [ ...
                testCase.createItem('presetVariable', 'preset'), ...
                testCase.createItem('firstCustom', 'custom'), ...
                testCase.createItem('', 'custom')];

            [isValid, message] = testCase.validate(variableList);

            testCase.verifyFalse(isValid)
            testCase.verifySubstring(message, 'Custom variable 2 has no name')
        end

        function testBlankNameCountsAsNoName(testCase)
            variableList = testCase.createItem('   ', 'custom');

            [isValid, message] = testCase.validate(variableList);

            testCase.verifyFalse(isValid)
            testCase.verifySubstring(message, 'Custom variable 1 has no name')
        end

        function testInvalidCustomNameIsReported(testCase, InvalidName)
            variableList = testCase.createItem(InvalidName, 'custom');

            [isValid, message] = testCase.validate(variableList);

            testCase.verifyFalse(isValid)
            testCase.verifySubstring(message, ['Custom variable 1 is named "' InvalidName '"'])
        end

        function testDuplicateCustomNamesAreReported(testCase)
            variableList = [ ...
                testCase.createItem('dffTrace', 'custom'), ...
                testCase.createItem('otherVariable', 'custom'), ...
                testCase.createItem('dffTrace', 'custom')];

            [isValid, message] = testCase.validate(variableList);

            testCase.verifyFalse(isValid)
            testCase.verifySubstring(message, ...
                'Custom variable 1 and custom variable 3 are both named "dffTrace"')
        end

        function testCustomNameTakenByPresetIsReported(testCase)
            variableList = [ ...
                testCase.createItem('dffTrace', 'preset'), ...
                testCase.createItem('dffTrace', 'custom')];

            [isValid, message] = testCase.validate(variableList);

            testCase.verifyFalse(isValid)
            testCase.verifySubstring(message, ...
                'Preset variable 1 and custom variable 1 are both named "dffTrace"')
        end

        function testInternalVariablesAreCountedSeparately(testCase)
        %testInternalVariablesAreCountedSeparately Internal rows have their own numbering
            variableList = [ ...
                testCase.createItem('customVariable', 'custom'), ...
                testCase.createItem('internalVariable', 'internal'), ...
                testCase.createItem('', 'internal')];

            [isValid, message] = testCase.validate(variableList);

            testCase.verifyFalse(isValid)
            testCase.verifySubstring(message, 'Internal variable 2 has no name')
        end

        function testPresetNamesAreNotChecked(testCase)
        %testPresetNamesAreNotChecked Preset names can not be edited, so they pass
            variableList = [ ...
                testCase.createItem('my var', 'preset'), ...
                testCase.createItem('my var', 'preset')];

            [isValid, message] = testCase.validate(variableList);

            testCase.verifyTrue(isValid)
            testCase.verifyEmpty(message)
        end

        function testEveryProblemIsReported(testCase)
        %testEveryProblemIsReported All problems are listed, one per line
            variableList = [ ...
                testCase.createItem('dffTrace', 'preset'), ...
                testCase.createItem('', 'custom'), ...
                testCase.createItem('my var', 'custom'), ...
                testCase.createItem('dffTrace', 'custom')];

            [isValid, message] = testCase.validate(variableList);

            testCase.verifyFalse(isValid)
            testCase.verifyNumElements(splitlines(message), 3)
            testCase.verifySubstring(message, 'Custom variable 1 has no name')
            testCase.verifySubstring(message, 'Custom variable 2 is named "my var"')
            testCase.verifySubstring(message, 'are both named "dffTrace"')
        end
    end

    methods (Access = private)
        function [isValid, message] = validate(~, variableList)
            [isValid, message] = ...
                nansen.config.varmodel.VariableModel.validateVariableNames(variableList);
        end
    end

    methods (Static, Access = private)
        function item = createItem(variableName, group)
        %createItem Create a variable item of the given group
        %
        %   group is 'preset', 'custom' or 'internal'. Internal variables are
        %   created by data methods through getDefaultItem, so they are custom
        %   variables that are also flagged as internal.
            item = nansen.config.varmodel.VariableModel.getDefaultItem(variableName);
            item.IsCustom = ~strcmp(group, 'preset');
            item.IsInternal = strcmp(group, 'internal');
        end
    end
end
