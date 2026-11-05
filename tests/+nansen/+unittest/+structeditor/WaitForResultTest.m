classdef WaitForResultTest < matlab.unittest.TestCase
%WaitForResultTest Unit tests for structeditor.waitForResult with a stub app.
%
%   The tests use nansen.unittest.structeditor.helper.StructEditorAppStub,
%   so they need neither StructEditor nor a figure. A real app is not used
%   here because uiwait makes the window of the app visible while it waits.

    properties (Constant, Access = private)
        OriginalData = struct('Value', 1)
        EditedData = struct('Value', 2)
    end

    methods (Test)
        function testOkReturnsEditedData(testCase)
            editor = testCase.createEditedEditor("Finished");

            [data, wasCanceled] = structeditor.waitForResult(editor);

            testCase.verifyEqual(data, testCase.EditedData)
            testCase.verifyFalse(wasCanceled)
        end

        function testCancelReturnsOriginalData(testCase)
            editor = testCase.createEditedEditor("Canceled");

            [data, wasCanceled] = structeditor.waitForResult(editor);

            testCase.verifyEqual(data, testCase.OriginalData)
            testCase.verifyTrue(wasCanceled)
        end

        function testClosingWindowCountsAsCancel(testCase)
            editor = testCase.createEditedEditor("");

            [data, wasCanceled] = structeditor.waitForResult(editor);

            testCase.verifyEqual(data, testCase.OriginalData)
            testCase.verifyTrue(wasCanceled)
        end

        function testEditorIsDeletedAfterResultIsRead(testCase)
            editor = testCase.createEditedEditor("Finished");

            structeditor.waitForResult(editor);

            testCase.verifyFalse(isvalid(editor))
        end

        function testEditorDeletedWhileWaitingCountsAsCancel(testCase)
            editor = nansen.unittest.structeditor.helper.StructEditorAppStub( ...
                testCase.OriginalData, ...
                FinishStateOnWait="Finished", ...
                DeleteOnWait=true);

            [data, wasCanceled, optionsName] = structeditor.waitForResult(editor);

            testCase.verifyEmpty(data)
            testCase.verifyTrue(wasCanceled)
            testCase.verifyEqual(optionsName, '')
        end

        function testReturnsOptionsNameOfPlugin(testCase)
            manager = nansen.unittest.config.FakeOptionsManager();
            plugin = nansen.manage.OptionsManagerPlugin(manager, 'Preset B');
            editor = nansen.unittest.structeditor.helper.StructEditorAppStub( ...
                testCase.OriginalData, Plugin=plugin);

            [~, ~, optionsName] = structeditor.waitForResult(editor);

            testCase.verifyEqual(optionsName, 'Preset B')
        end

        function testOptionsNameIsEmptyWithoutPlugin(testCase)
            editor = testCase.createEditedEditor("Finished");

            [~, ~, optionsName] = structeditor.waitForResult(editor);

            testCase.verifyEqual(optionsName, '')
        end
    end

    methods (Access = private)
        function editor = createEditedEditor(testCase, finishState)
        %createEditedEditor Create a stub app whose Data holds EditedData.
            editor = nansen.unittest.structeditor.helper.StructEditorAppStub( ...
                testCase.OriginalData, FinishStateOnWait=finishState);
            editor.Data = testCase.EditedData;
            testCase.addTeardown(@deleteIfValid, editor)
        end
    end
end

function deleteIfValid(object)
    if isvalid(object)
        delete(object)
    end
end
