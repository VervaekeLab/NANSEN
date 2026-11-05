classdef ModalMethodPreviewControllerTest < matlab.unittest.TestCase
%ModalMethodPreviewControllerTest Unit tests for modal preview lifecycle

    methods (Test)

        function testCancelKeepsOriginalOptionsAndDoesNotRun(testCase)
            originalOptions = struct('Main', struct('Value', 1));
            editedOptions = struct('Main', struct('Value', 2));

            plugin = nansen.unittest.plugin.helper.ModalPreviewControllerSpy(originalOptions);
            testCase.addTeardown(@() testCase.deleteIfValid(plugin))
            editor = nansen.unittest.plugin.helper.OptionsEditorStub(editedOptions, true);
            plugin.Editor = editor;

            [options, wasAborted] = plugin.editOptions();

            testCase.verifyTrue(wasAborted)
            testCase.verifyEqual(options, originalOptions)
            testCase.verifyEqual(plugin.Options, originalOptions)
            testCase.verifyFalse(plugin.WasRun)
            testCase.verifyEqual(plugin.EditorClosedCount, 1)
            testCase.verifyFalse(isvalid(editor))
        end

        function testAcceptAssignsEditedOptionsAndRuns(testCase)
            originalOptions = struct('Main', struct('Value', 1));
            editedOptions = struct('Main', struct('Value', 2));

            plugin = nansen.unittest.plugin.helper.ModalPreviewControllerSpy(originalOptions);
            testCase.addTeardown(@() testCase.deleteIfValid(plugin))
            editor = nansen.unittest.plugin.helper.OptionsEditorStub(editedOptions, false);
            plugin.Editor = editor;

            [options, wasAborted] = plugin.editOptions();

            testCase.verifyFalse(wasAborted)
            testCase.verifyEqual(options, editedOptions)
            testCase.verifyEqual(plugin.Options, editedOptions)
            testCase.verifyTrue(plugin.WasRun)
            testCase.verifyEqual(plugin.EditorClosedCount, 1)
            testCase.verifyFalse(isvalid(editor))
        end

        function testAcceptCanSkipRun(testCase)
            originalOptions = struct('Main', struct('Value', 1));
            editedOptions = struct('Main', struct('Value', 2));

            plugin = nansen.unittest.plugin.helper.ModalPreviewControllerSpy(originalOptions);
            testCase.addTeardown(@() testCase.deleteIfValid(plugin))
            plugin.RunMethodOnFinish = false;
            plugin.Editor = nansen.unittest.plugin.helper.OptionsEditorStub(editedOptions, false);

            [~, wasAborted] = plugin.editOptions();

            testCase.verifyFalse(wasAborted)
            testCase.verifyEqual(plugin.Options, editedOptions)
            testCase.verifyFalse(plugin.WasRun)
        end

        function testAcceptCanDestroyController(testCase)
            originalOptions = struct('Main', struct('Value', 1));
            editedOptions = struct('Main', struct('Value', 2));

            plugin = nansen.unittest.plugin.helper.ModalPreviewControllerSpy(originalOptions);
            plugin.DestroyOnFinish = true;
            plugin.Editor = nansen.unittest.plugin.helper.OptionsEditorStub(editedOptions, false);

            plugin.editOptions()

            testCase.verifyFalse(isvalid(plugin))
        end
    end

    methods (Static, Access = private)

        function deleteIfValid(h)
            if ~isempty(h) && isvalid(h)
                delete(h)
            end
        end
    end
end
