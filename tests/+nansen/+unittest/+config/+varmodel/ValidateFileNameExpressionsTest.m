classdef ValidateFileNameExpressionsTest < matlab.unittest.TestCase
    %ValidateFileNameExpressionsTest Checking the placeholders of an edited variable list
    %
    %   The variable model app writes the edited table back to the model as
    %   one list, which does not pass through the checks that guard single
    %   insertions. validateFileNameExpressions is the check the app runs on
    %   the file name expressions of that list before saving it: every
    %   placeholder in an expression must be one that FileNamePattern lists.
    %
    %   The function is static and reads nothing from disk, so the tests need
    %   neither a project nor a model file.
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.varmodel.ValidateFileNameExpressionsTest')

    methods (Test)

        function testKnownPlaceholdersPass(testCase)
            variableList = [ ...
                testCase.createItem("presetVariable", "preset", "rois"), ...
                testCase.createItem("sessionFile", "custom", "{sessionID}"), ...
                testCase.createItem("anatomy", "custom", "{subjectID}_anat*"), ...
                testCase.createItem("notes", "internal", "")];

            [isValid, message] = testCase.validate(variableList);

            testCase.verifyTrue(isValid)
            testCase.verifyEmpty(message)
        end

        function testEmptyListPasses(testCase)
            [isValid, message] = testCase.validate(struct([]));

            testCase.verifyTrue(isValid)
            testCase.verifyEmpty(message)
        end

        function testUnknownPlaceholderIsReported(testCase)
        %testUnknownPlaceholderIsReported The message names the variable and the placeholder
            variableList = [ ...
                testCase.createItem("firstCustom", "custom", "rois"), ...
                testCase.createItem("secondCustom", "custom", "{sessionId}_dff")];

            [isValid, message] = testCase.validate(variableList);

            testCase.verifyFalse(isValid)
            testCase.verifySubstring(message, "Custom variable 2: ")
            testCase.verifySubstring(message, "unknown placeholder: {sessionId}")
        end

        function testPresetExpressionIsChecked(testCase)
        %testPresetExpressionIsChecked The app lets users edit preset expressions too
            variableList = testCase.createItem("presetVariable", "preset", "{subjectId}");

            [isValid, message] = testCase.validate(variableList);

            testCase.verifyFalse(isValid)
            testCase.verifySubstring(message, "Preset variable 1: ")
        end

        function testEveryProblemIsReported(testCase)
        %testEveryProblemIsReported All problems are listed, one per line
            variableList = [ ...
                testCase.createItem("presetVariable", "preset", "{sessionId}"), ...
                testCase.createItem("firstCustom", "custom", "{date}_rois"), ...
                testCase.createItem("secondCustom", "custom", "rois")];

            [isValid, message] = testCase.validate(variableList);

            testCase.verifyFalse(isValid)
            testCase.verifyNumElements(splitlines(message), 2)
            testCase.verifySubstring(message, "Preset variable 1: ")
            testCase.verifySubstring(message, "Custom variable 1: ")
        end
    end

    methods (Access = private)
        function [isValid, message] = validate(~, variableList)
            [isValid, message] = ...
                nansen.config.varmodel.VariableModel.validateFileNameExpressions(variableList);
        end
    end

    methods (Static, Access = private)
        function item = createItem(variableName, group, fileNameExpression)
        %createItem Create a variable item of the given group
        %
        %   group is 'preset', 'custom' or 'internal'. Internal variables are
        %   custom variables that are also flagged as internal.
            item = nansen.config.varmodel.VariableModel.getDefaultItem(variableName);
            item.IsCustom = ~strcmp(group, "preset");
            item.IsInternal = strcmp(group, "internal");
            item.FileNameExpression = fileNameExpression;
        end
    end
end
