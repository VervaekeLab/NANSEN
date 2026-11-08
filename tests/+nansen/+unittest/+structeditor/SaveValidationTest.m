classdef SaveValidationTest < matlab.unittest.TestCase
%SaveValidationTest Refusing to save invalid values in the struct editor
%
%   A ValidationFcn runs when the Save button is pressed, and the editor
%   stays open if it returns a reason the values cannot be saved. The tests
%   run the callbacks of the real buttons and edit fields on a hidden editor.
%   A spy of the editor records the reason instead of opening an error dialog.
%
%   Run tests:
%       runtests('nansen.unittest.structeditor.SaveValidationTest')

    properties (Constant)
        NameProblem = "Enter a valid name."
    end

    properties
        ValidationInputs (1,:) cell = {}
    end

    properties (TestParameter)
        AcceptingResult = struct( ...
            'emptyChar', '', ...
            'emptyString', "", ...
            'emptyDouble', [], ...
            'noStrings', string.empty)

        EditedData = struct( ...
            'singlePage', struct('Name', 'value'), ...
            'structOfStructs', struct( ...
                'First', struct('Name', 'value'), ...
                'Second', struct('Size', 5)), ...
            'cellOfStructs', {{struct('Name', 'value'), struct('Size', 5)}})
    end

    methods (Test, TestTags="Graphical")

        function testProblemKeepsEditorOpen(testCase)
            editor = testCase.createEditor(@(~) testCase.NameProblem);

            testCase.pressButton(editor, 'Save Button')

            testCase.verifyTrue(isvalid(editor.Figure))
            testCase.verifyEqual(editor.ReportedProblems, testCase.NameProblem)
        end

        function testRefusedSaveKeepsEnteredText(testCase)
            editor = testCase.createEditor(@(~) testCase.NameProblem);
            nameField = editor.hControls.Name;
            testCase.typeInto(nameField, 'my name')

            testCase.pressButton(editor, 'Save Button')

            testCase.verifyEqual(nameField.String, 'my name')
        end

        function testCorrectedValueIsSaved(testCase)
            editor = testCase.createEditor(@testCase.getNameProblem);
            testCase.pressButton(editor, 'Save Button')
            testCase.verifyTrue(isvalid(editor.Figure))

            testCase.typeInto(editor.hControls.Name, 'validName')
            testCase.pressButton(editor, 'Save Button')

            testCase.verifyFalse(isvalid(editor.Figure))
            testCase.verifyFalse(editor.wasCanceled)
            testCase.verifyEqual(editor.dataEdit.Name, 'validName')
            testCase.verifyEqual(editor.ReportedProblems, testCase.NameProblem)
        end

        function testEmptyResultAcceptsValues(testCase, AcceptingResult)
            editor = testCase.createEditor(@(~) AcceptingResult);

            testCase.pressButton(editor, 'Save Button')

            testCase.verifyFalse(isvalid(editor.Figure))
            testCase.verifyEmpty(editor.ReportedProblems)
        end

        function testAllProblemsAreReported(testCase)
            problems = ["First problem."; ""; "Second problem."];
            editor = testCase.createEditor(@(~) problems);

            testCase.pressButton(editor, 'Save Button')

            testCase.verifyTrue(isvalid(editor.Figure))
            testCase.verifyEqual(editor.ReportedProblems, ["First problem.", "Second problem."])
        end

        function testValidationSeesEnteredValue(testCase)
            editor = testCase.createEditor(@testCase.recordInput);
            testCase.typeInto(editor.hControls.Name, 'entered')

            testCase.pressButton(editor, 'Save Button')

            testCase.verifyEqual(testCase.ValidationInputs{1}.Name, 'entered')
        end

        function testValidationSeesValuesAsReturned(testCase, EditedData)
            editor = testCase.createEditor(@testCase.recordInput, EditedData);

            testCase.pressButton(editor, 'Save Button')

            testCase.verifyEqual(testCase.ValidationInputs{1}, editor.dataEdit)
        end

        function testSavedValuesKeepInputForm(testCase, EditedData)
            editor = testCase.createEditor(function_handle.empty, EditedData);

            testCase.pressButton(editor, 'Save Button')

            testCase.verifyEqual(editor.dataEdit, EditedData)
        end

        function testCancelSkipsValidation(testCase)
            editor = testCase.createEditor(@testCase.recordInput);

            testCase.pressButton(editor, 'Cancel Button')

            testCase.verifyFalse(isvalid(editor.Figure))
            testCase.verifyTrue(editor.wasCanceled)
            testCase.verifyEmpty(testCase.ValidationInputs)
        end

        function testEditorWithoutValidationSaves(testCase)
            editor = testCase.createEditor();

            testCase.pressButton(editor, 'Save Button')

            testCase.verifyFalse(isvalid(editor.Figure))
            testCase.verifyFalse(editor.wasCanceled)
            testCase.verifyEmpty(editor.ReportedProblems)
        end
    end

    methods (Access = private)

        function editor = createEditor(testCase, validationFcn, data)
            arguments
                testCase
                validationFcn function_handle = function_handle.empty
                data = struct('Name', '')
            end

            editor = nansen.unittest.structeditor.helper.StructEditorSpy(data, ...
                'Visible', 'off', 'ValidationFcn', validationFcn);
            testCase.addTeardown(@delete, editor)
        end

        function problem = recordInput(testCase, values)
            testCase.ValidationInputs{end+1} = values;
            problem = "";
        end

        function problem = getNameProblem(testCase, values)
            problem = "";
            if ~isvarname(values.Name)
                problem = testCase.NameProblem;
            end
        end
    end

    methods (Static, Access = private)

        function pressButton(editor, buttonTag)
            button = findall(editor.Figure, 'Tag', buttonTag);
            button.ButtonDownFcn(button, [])
        end

        function typeInto(editField, text)
            editField.String = text;
            editField.Callback(editField, [])
        end
    end
end
