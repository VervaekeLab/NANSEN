classdef OptionsManagerPluginTest < matlab.unittest.TestCase
%OptionsManagerPluginTest Unit tests for nansen.manage.OptionsManagerPlugin.
%
%   The plugin is attached to nansen.unittest.structeditor.helper.StructEditorAppStub,
%   whose header panel is created in one hidden figure that all tests
%   share, and to a nansen.unittest.config.FakeOptionsManager. The tests
%   find the plugin's controls in the header panel and call their
%   callbacks, because UI gestures need a visible figure.

    properties (Access = private)
        Figure
    end

    methods (TestClassSetup)
        function createSharedFigure(testCase)
            testCase.Figure = uifigure('Visible', 'off');
            testCase.addTeardown(@delete, testCase.Figure)
        end
    end

    methods (Test, TestTags="Graphical")
        function testAttachListsOptionsSets(testCase)
            [~, editor] = testCase.attachPlugin();
            dropDown = findOptionsDropDown(editor);

            testCase.verifyEqual(dropDown.ItemsData, {'Preset A', 'Preset B', 'Custom A'})
            testCase.verifyEqual(dropDown.Value, 'Preset A')
            testCase.verifyEqual(dropDown.Items{1}, '[Preset A] (Default)')
        end

        function testDataChangeCreatesModifiedOptions(testCase)
            [plugin, editor, manager] = testCase.attachPlugin();

            editor.Data = struct('Value', 5);
            plugin.onDataChanged(editor, struct('Name', "Value"))

            testCase.verifyEqual(plugin.CurrentOptionsName, 'Preset A (Modified)')
            testCase.verifyEqual(manager.getModifiedOptions('Preset A (Modified)').Value, 5)
            testCase.verifyEqual(findOptionsDropDown(editor).Value, 'Preset A (Modified)')
        end

        function testSelectingOptionsSetsEditorData(testCase)
            [plugin, editor] = testCase.attachPlugin();

            selectOption(findOptionsDropDown(editor), 'Preset B')

            testCase.verifyEqual(editor.Data.Value, 2)
            testCase.verifyEqual(plugin.CurrentOptionsName, 'Preset B')
        end

        function testSelectingOptionsKeepsOriginalData(testCase)
            [~, editor] = testCase.attachPlugin();

            selectOption(findOptionsDropDown(editor), 'Preset B')

            testCase.verifyEqual(editor.OriginalData.Value, 1)
        end

        function testSelectingModifiedOptionsRestoresEditedData(testCase)
            [plugin, editor] = testCase.attachPlugin();
            editor.Data = struct('Value', 5);
            plugin.onDataChanged(editor, struct('Name', "Value"))

            dropDown = findOptionsDropDown(editor);
            selectOption(dropDown, 'Preset B')
            selectOption(dropDown, 'Preset A (Modified)')

            testCase.verifyEqual(editor.Data.Value, 5)
            testCase.verifyEqual(plugin.CurrentOptionsName, 'Preset A (Modified)')
        end

        function testSaveOptionsSavesEditorData(testCase)
            [plugin, editor, manager] = testCase.attachPlugin();
            editor.Data = struct('Value', 7);
            plugin.onDataChanged(editor, struct('Name', "Value"))

            saveButton = findButton(editor, 'Save Options');
            testCase.assertEqual(char(saveButton.Enable), 'on')
            pushButton(saveButton)

            testCase.verifyEqual(manager.SaveCustomOptionsCallCount, 1)
            testCase.verifyEqual(manager.SavedOptions.Value, 7)
            testCase.verifyEqual(plugin.CurrentOptionsName, 'Saved Custom')
            testCase.verifyEmpty(manager.EditedOptionNames)
        end

        function testMakeDefaultSetsDefaultOptions(testCase)
            [~, editor, manager] = testCase.attachPlugin();

            selectOption(findOptionsDropDown(editor), 'Custom A')

            defaultButton = findButton(editor, 'Make Default');
            testCase.assertEqual(char(defaultButton.Enable), 'on')
            pushButton(defaultButton)

            testCase.verifyEqual(manager.SetDefaultCallCount, 1)
            testCase.verifyEqual(manager.DefaultName, 'Custom A')
        end
    end

    methods (Access = private)
        function [plugin, editor, manager] = attachPlugin(testCase)
        %attachPlugin Attach a plugin for "Preset A" to a stub app.
            manager = nansen.unittest.config.FakeOptionsManager();
            plugin = nansen.manage.OptionsManagerPlugin(manager, 'Preset A');
            editor = nansen.unittest.structeditor.helper.StructEditorAppStub( ...
                manager.getOptions('Preset A'), ...
                Parent=testCase.Figure, ...
                Plugin=plugin);
            testCase.addTeardown(@delete, editor)
        end
    end
end

function dropDown = findOptionsDropDown(editor)
    dropDown = findobj(editor.getAttachmentContainer("header"), 'Type', 'uidropdown');
end

function button = findButton(editor, text)
    button = findobj(editor.getAttachmentContainer("header"), ...
        'Type', 'uibutton', 'Text', text);
end

function selectOption(dropDown, value)
%selectOption Select a dropdown value and run its callback, as a user selection does.
    previousValue = dropDown.Value;
    dropDown.Value = value;
    dropDown.ValueChangedFcn(dropDown, ...
        struct('Value', value, 'PreviousValue', previousValue))
end

function pushButton(button)
%pushButton Run the callback of a button, as a button push does.
    button.ButtonPushedFcn(button, struct())
end
