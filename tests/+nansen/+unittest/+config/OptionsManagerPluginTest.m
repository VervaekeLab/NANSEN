classdef OptionsManagerPluginTest < matlab.uitest.TestCase

    methods (TestMethodSetup)
        function assumeModernStructEditor(testCase)
            testCase.assumeEqual(exist('structeditor.StructEditorApp', 'class'), 8, ...
                'Standalone StructEditor must be on the MATLAB path.')
        end
    end

    methods (Test)
        function testPluginPopulatesDropdown(testCase)
            manager = nansen.unittest.config.FakeOptionsManager();
            [editor, plugin] = testCase.createEditor(manager);

            testCase.verifyClass(plugin, 'nansen.manage.OptionsManagerPlugin')
            dropDown = plugin.getTestControl('OptionsDropDown');

            testCase.verifyEqual(dropDown.ItemsData, ...
                {'Preset A', 'Preset B', 'Custom A'})
            testCase.verifyEqual(dropDown.Value, 'Preset A')
            testCase.verifyEqual(dropDown.Items{1}, '[Preset A] (Default)')

            delete(editor)
        end

        function testEditingCreatesModifiedOptions(testCase)
            manager = nansen.unittest.config.FakeOptionsManager();
            [editor, plugin] = testCase.createEditor(manager);
            controlContainer = editor.getComponent('UIControlContainers');

            testCase.type(controlContainer.UIControls.Value, 5)

            testCase.verifyEqual(plugin.CurrentOptionsName, 'Preset A (Modified)')
            testCase.verifyTrue(manager.isModified('Preset A (Modified)'))
            testCase.verifyEqual(manager.getModifiedOptions('Preset A (Modified)').Value, 5)

            delete(editor)
        end

        function testSelectingOptionsReplacesEditorData(testCase)
            manager = nansen.unittest.config.FakeOptionsManager();
            [editor, plugin] = testCase.createEditor(manager);
            dropDown = plugin.getTestControl('OptionsDropDown');

            testCase.choose(dropDown, '[Preset B]')

            testCase.verifyEqual(editor.Data.Value, 2)
            testCase.verifyEqual(plugin.CurrentOptionsName, 'Preset B')

            delete(editor)
        end

        function testSaveOptionsPersistsModifiedData(testCase)
            manager = nansen.unittest.config.FakeOptionsManager();
            [editor, plugin] = testCase.createEditor(manager);
            controlContainer = editor.getComponent('UIControlContainers');
            saveButton = plugin.getTestControl('SaveButton');

            testCase.type(controlContainer.UIControls.Value, 7)
            testCase.press(saveButton)

            testCase.verifyEqual(manager.SaveCustomOptionsCallCount, 1)
            testCase.verifyEqual(manager.SavedOptions.Value, 7)
            testCase.verifyEqual(plugin.CurrentOptionsName, 'Saved Custom')
            testCase.verifyFalse(manager.isModified('Preset A (Modified)'))

            delete(editor)
        end

        function testMakeDefaultUpdatesOptionsManager(testCase)
            manager = nansen.unittest.config.FakeOptionsManager();
            [editor, plugin] = testCase.createEditor(manager);
            dropDown = plugin.getTestControl('OptionsDropDown');
            defaultButton = plugin.getTestControl('DefaultButton');

            testCase.choose(dropDown, 'Custom A')
            testCase.press(defaultButton)

            testCase.verifyEqual(manager.SetDefaultCallCount, 1)
            testCase.verifyEqual(manager.DefaultName, 'Custom A')

            delete(editor)
        end
    end

    methods (Access = private)
        function [editor, plugin] = createEditor(testCase, manager)
            plugin = nansen.manage.OptionsManagerPlugin(manager, 'Preset A');
            editor = structeditor(manager.getOptions('Preset A'), ...
                'CloseOnExit', false, ...
                'Plugin', plugin);
            testCase.addTeardown(@() deleteValid(editor));
        end
    end
end

function deleteValid(obj)
    if ~isempty(obj) && isvalid(obj)
        delete(obj)
    end
end
