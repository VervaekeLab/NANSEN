classdef OptionsManagerPlugin < handle

    properties (SetAccess = private)
        OptionsManager
        CurrentOptionsName char = ''
    end

    properties (Access = private)
        Editor
        HeaderGrid matlab.ui.container.GridLayout
        OptionsDropDown matlab.ui.control.DropDown
        SaveButton matlab.ui.control.Button
        DefaultButton matlab.ui.control.Button
        IsUpdating (1,1) logical = false
    end

    methods
        function obj = OptionsManagerPlugin(optionsManager, optionsName)
            arguments
                optionsManager
                optionsName char = ''
            end

            obj.OptionsManager = optionsManager;
            if isempty(optionsName)
                optionsName = optionsManager.OptionsName;
            end
            if isempty(optionsName)
                optionsName = optionsManager.getPreferredOptionsName();
            end
            obj.CurrentOptionsName = char(optionsName);
        end

        function attach(obj, editor)
            obj.Editor = editor;
            parent = editor.getAttachmentContainer("header");

            obj.HeaderGrid = uigridlayout(parent);
            obj.HeaderGrid.ColumnWidth = {'1x', 82, 96};
            obj.HeaderGrid.RowHeight = {'1x'};
            obj.HeaderGrid.Padding = [0 0 0 0];
            obj.HeaderGrid.ColumnSpacing = 6;

            obj.OptionsDropDown = uidropdown(obj.HeaderGrid);
            obj.OptionsDropDown.Layout.Row = 1;
            obj.OptionsDropDown.Layout.Column = 1;
            obj.OptionsDropDown.ValueChangedFcn = @obj.onOptionsSetChanged;

            obj.SaveButton = uibutton(obj.HeaderGrid, ...
                "Text", "Save Options", ...
                "ButtonPushedFcn", @obj.onSaveOptionsPushed);
            obj.SaveButton.Layout.Row = 1;
            obj.SaveButton.Layout.Column = 2;

            obj.DefaultButton = uibutton(obj.HeaderGrid, ...
                "Text", "Make Default", ...
                "ButtonPushedFcn", @obj.onMakeDefaultPushed);
            obj.DefaultButton.Layout.Row = 1;
            obj.DefaultButton.Layout.Column = 3;

            obj.refreshOptionsDropdown();
        end

        function setCurrentOptionsName(obj, optionsName)
            obj.CurrentOptionsName = char(optionsName);
            obj.refreshOptionsDropdown();
        end

        function onDataChanged(obj, ~, ~)
            if obj.IsUpdating || isempty(obj.OptionsDropDown)
                return
            end

            opts = obj.Editor.Data;
            currentName = obj.CurrentOptionsName;

            if contains(currentName, 'Modified')
                obj.OptionsManager.appendModifiedOptions(opts, currentName)
            else
                obj.CurrentOptionsName = sprintf('%s (Modified)', currentName);
                obj.OptionsManager.appendModifiedOptions(opts, obj.CurrentOptionsName)
            end

            obj.refreshOptionsDropdown();
        end

        function onFinishStateChanged(~, ~, ~)
            % Hook kept for the generic plugin lifecycle. OptionsManager
            % state is read by callers after editor.waitfor returns.
        end

        function control = getTestControl(obj, controlName)
            control = obj.(controlName);
        end
    end

    methods (Access = private)
        function onOptionsSetChanged(obj, src, ~)
            newName = char(src.Value);
            oldName = obj.CurrentOptionsName;

            if strcmp(newName, oldName)
                return
            end

            if contains(oldName, 'Modified')
                obj.OptionsManager.appendModifiedOptions(obj.Editor.Data, oldName)
            end

            if obj.OptionsManager.isModified(newName)
                newOptions = obj.OptionsManager.getModifiedOptions(newName);
            else
                newOptions = obj.OptionsManager.getOptions(newName);
            end

            obj.IsUpdating = true;
            cleanupObj = onCleanup(@() obj.clearUpdatingFlag());
            obj.Editor.replaceData(newOptions);
            obj.CurrentOptionsName = newName;
            obj.refreshOptionsDropdown();
            delete(cleanupObj)
        end

        function onSaveOptionsPushed(obj, ~, ~)
            currentName = obj.CurrentOptionsName;
            givenName = obj.OptionsManager.saveCustomOptions(obj.Editor.Data);
            if isempty(givenName)
                return
            end

            if contains(currentName, 'Modified')
                obj.OptionsManager.removeModifiedOptions(currentName)
            end

            obj.CurrentOptionsName = givenName;
            obj.refreshOptionsDropdown();
        end

        function onMakeDefaultPushed(obj, ~, ~)
            if isempty(obj.CurrentOptionsName) || contains(obj.CurrentOptionsName, 'Modified')
                return
            end

            obj.OptionsManager.setDefault(obj.CurrentOptionsName);
            obj.refreshOptionsDropdown();
        end

        function refreshOptionsDropdown(obj)
            if isempty(obj.OptionsDropDown) || ~isvalid(obj.OptionsDropDown)
                return
            end

            [displayNames, optionNames] = obj.getDropdownNames();
            obj.OptionsDropDown.Items = displayNames;
            obj.OptionsDropDown.ItemsData = optionNames;

            if any(strcmp(optionNames, obj.CurrentOptionsName))
                obj.OptionsDropDown.Value = obj.CurrentOptionsName;
            elseif ~isempty(optionNames)
                obj.CurrentOptionsName = optionNames{1};
                obj.OptionsDropDown.Value = obj.CurrentOptionsName;
            end

            obj.updateButtonStates();
        end

        function [displayNames, optionNames] = getDropdownNames(obj)
            presetNames = obj.OptionsManager.PresetOptionNames;
            customNames = obj.OptionsManager.CustomOptionNames;
            editedNames = obj.OptionsManager.EditedOptionNames;
            optionNames = [presetNames, customNames, editedNames];

            displayNames = [ ...
                obj.OptionsManager.formatPresetNames(presetNames), ...
                customNames, ...
                obj.OptionsManager.formatEditedNames(editedNames)];

            defaultName = obj.OptionsManager.getPreferredOptionsName();
            isDefault = strcmp(optionNames, defaultName);
            displayNames(isDefault) = obj.OptionsManager.formatDefaultName(displayNames(isDefault));
        end

        function updateButtonStates(obj)
            if isempty(obj.SaveButton) || ~isvalid(obj.SaveButton)
                return
            end

            isModified = contains(obj.CurrentOptionsName, 'Modified');
            obj.SaveButton.Enable = obj.onOff(isModified);

            defaultName = obj.OptionsManager.getPreferredOptionsName();
            canMakeDefault = ~isempty(obj.CurrentOptionsName) ...
                && ~isModified ...
                && ~strcmp(obj.CurrentOptionsName, defaultName);
            obj.DefaultButton.Enable = obj.onOff(canMakeDefault);
        end

        function clearUpdatingFlag(obj)
            obj.IsUpdating = false;
        end
    end

    methods (Static, Access = private)
        function value = onOff(tf)
            if tf
                value = 'on';
            else
                value = 'off';
            end
        end
    end
end
