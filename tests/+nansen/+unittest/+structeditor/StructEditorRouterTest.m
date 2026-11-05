classdef StructEditorRouterTest < matlab.uitest.TestCase
%StructEditorRouterTest Tests of structeditor with structeditor.StructEditorApp on the path.
%
%   The tests run when nansen.util.useModernStructEditor returns true, that
%   is on MATLAB R2025a or newer with a StructEditor version on the path
%   that has the members NANSEN calls. Otherwise they are skipped.
%
%   StructEditorApp has no option for a hidden window, so the tests set the
%   DefaultFigureVisible root property to 'off' while they run. UI gestures
%   need a visible figure, so the tests call the callbacks of the Ok and
%   Cancel buttons and of the options dropdown instead. The tests do not
%   call structeditor.waitForResult, because uiwait makes the window
%   visible; WaitForResultTest covers that function with a stub app.

    properties (Constant, Access = private)
        OriginalData = struct('Value', 1)
        EditedData = struct('Value', 2)
    end

    methods (TestClassSetup)
        function assumeModernStructEditor(testCase)
            testCase.assumeTrue(nansen.util.useModernStructEditor(), ...
                ['Requires MATLAB R2025a or newer and a StructEditor ', ...
                'version with the members NANSEN calls on the MATLAB path.'])
        end

        function hideNewFigures(testCase)
            originalVisible = get(groot, 'DefaultFigureVisible');
            testCase.addTeardown(@set, groot, 'DefaultFigureVisible', originalVisible)
            set(groot, 'DefaultFigureVisible', 'off')
        end
    end

    methods (Test, TestTags="Graphical")
        function testStandaloneCallOpensModernEditor(testCase)
            editor = testCase.openEditor(testCase.OriginalData, 'Title', 'Test');

            testCase.verifyClass(editor, 'structeditor.StructEditorApp')
            testCase.verifyFalse(editor.CloseOnExit)
        end

        function testLegacyOnlyOptionOpensLegacyEditor(testCase)
            testCase.assumeEqual(exist('uiw.mixin.AssignPVPairs', 'class'), 8, ...
                'The legacy editor requires Widgets Toolbox.')

            editor = testCase.openEditor(testCase.OriginalData, 'Visible', 'off');

            testCase.verifyClass(editor, 'structeditor.App')
        end

        function testOptionsManagerIsShownByPlugin(testCase)
            manager = nansen.unittest.config.FakeOptionsManager();

            editor = testCase.openEditor(manager.getOptions('Preset A'), ...
                'OptionsManager', manager);

            testCase.verifyClass(editor.getPlugin('nansen.manage.OptionsManagerPlugin'), ...
                'nansen.manage.OptionsManagerPlugin')
            testCase.verifyNotEmpty(findOptionsDropDown(editor))
        end

        function testOkKeepsEditorWithEditedData(testCase)
            editor = testCase.openEditor(testCase.OriginalData, 'Title', 'Test');
            editor.Data = testCase.EditedData;

            testCase.pushFooterButton(editor, "OkButton")

            testCase.assertTrue(isvalid(editor))
            testCase.verifyEqual(editor.FinishState, "Finished")
            testCase.verifyEqual(editor.Data, testCase.EditedData)
            testCase.verifyEqual(editor.OriginalData, testCase.OriginalData)
        end

        function testCancelKeepsEditorWithOriginalData(testCase)
            editor = testCase.openEditor(testCase.OriginalData, 'Title', 'Test');
            editor.Data = testCase.EditedData;

            testCase.pushFooterButton(editor, "CancelButton")

            testCase.assertTrue(isvalid(editor))
            testCase.verifyEqual(editor.FinishState, "Canceled")
            testCase.verifyEqual(editor.OriginalData, testCase.OriginalData)
        end

        function testClosingWindowKeepsEditor(testCase)
            editor = testCase.openEditor(testCase.OriginalData, 'Title', 'Test');

            close(editor.Figure)

            testCase.assertTrue(isvalid(editor))
            testCase.verifyEqual(editor.FinishState, "")
        end

        function testSelectingPresetKeepsOriginalOptions(testCase)
            manager = nansen.unittest.config.FakeOptionsManager();
            editor = testCase.openEditor(manager.getOptions('Preset A'), ...
                'OptionsManager', manager);

            selectOption(findOptionsDropDown(editor), 'Preset B')
            testCase.pushFooterButton(editor, "CancelButton")

            testCase.verifyEqual(editor.Data.Value, 2)
            testCase.verifyEqual(editor.OriginalData.Value, 1)
        end

        function testOkAfterSelectingPresetKeepsPresetName(testCase)
            manager = nansen.unittest.config.FakeOptionsManager();
            editor = testCase.openEditor(manager.getOptions('Preset A'), ...
                'OptionsManager', manager);

            selectOption(findOptionsDropDown(editor), 'Preset B')
            testCase.pushFooterButton(editor, "OkButton")

            plugin = editor.getPlugin('nansen.manage.OptionsManagerPlugin');
            testCase.verifyEqual(editor.Data.Value, 2)
            testCase.verifyEqual(plugin.CurrentOptionsName, 'Preset B')
        end
    end

    methods (Access = private)
        function editor = openEditor(testCase, data, varargin)
            editor = structeditor(data, varargin{:});
            testCase.addTeardown(@deleteIfValid, editor)
        end

        function pushFooterButton(~, editor, buttonName)
        %pushFooterButton Run the callback of the Ok or Cancel button, as a button push does.
            footer = editor.getComponent("Footer");
            button = footer.getControl(buttonName);
            button.ButtonPushedFcn(button, [])
        end
    end
end

function dropDown = findOptionsDropDown(editor)
    dropDown = findobj(editor.getAttachmentContainer("header"), 'Type', 'uidropdown');
end

function selectOption(dropDown, value)
%selectOption Select a dropdown value and run its callback, as a user selection does.
    previousValue = dropDown.Value;
    dropDown.Value = value;
    dropDown.ValueChangedFcn(dropDown, ...
        struct('Value', value, 'PreviousValue', previousValue))
end

function deleteIfValid(object)
    if isvalid(object)
        delete(object)
    end
end
