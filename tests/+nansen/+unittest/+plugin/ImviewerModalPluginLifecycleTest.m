classdef ImviewerModalPluginLifecycleTest < matlab.unittest.TestCase
%ImviewerModalPluginLifecycleTest Lifecycle smoke tests for imviewer plugins

    properties (TestParameter)
        PluginSpec = nansen.unittest.plugin.ImviewerModalPluginLifecycleTest.getPluginSpecs()
    end

    methods (TestMethodSetup)
        function assumeWidgetsToolboxOnPath(testCase)
        %assumeWidgetsToolboxOnPath Imviewer plugins require Widgets Toolbox.
            testCase.assumeNotEmpty(which('uiw.mixin.AssignPVPairs'), ...
                'Widgets Toolbox is not on the MATLAB path.')
        end
    end

    methods (Test, TestTags="Graphical")

        function testOpenPlugin(testCase, PluginSpec)
            hImviewer = testCase.createHiddenImviewer();

            plugin = testCase.openPlugin(hImviewer, PluginSpec);
            testCase.addTeardown(@() testCase.deleteIfValid(plugin))

            testCase.verifyClass(plugin, PluginSpec.ClassName)
            testCase.verifySameHandle(plugin.PrimaryApp, hImviewer)
            testCase.verifyTrue(plugin.PartialConstruction)
            testCase.verifyFalse(plugin.RunMethodOnFinish)
            testCase.verifyFalse(plugin.DestroyOnFinish)
            testCase.verifyNotEmpty(plugin.Options)
            testCase.verifyTrue(strcmp(hImviewer.Figure.Visible, 'off'))
        end

        function testCancelOperation(testCase, PluginSpec)
            hImviewer = testCase.createHiddenImviewer();
            plugin = testCase.openPlugin(hImviewer, PluginSpec);
            testCase.addTeardown(@() testCase.deleteIfValid(plugin))

            [~, wasAborted] = testCase.editOptionsWithAction(...
                plugin, 'Cancel', []);

            testCase.verifyTrue(wasAborted)
            testCase.verifyTrue(isvalid(plugin))
            testCase.verifyTrue(plugin.wasAborted)
            testCase.verifyEmpty(plugin.getOptionsEditorForTesting())
        end

        function testAcceptOperation(testCase, PluginSpec)
            hImviewer = testCase.createHiddenImviewer();
            plugin = testCase.openPlugin(hImviewer, PluginSpec);
            testCase.addTeardown(@() testCase.deleteIfValid(plugin))

            [~, wasAborted] = testCase.editOptionsWithAction(...
                plugin, 'Save', []);

            testCase.verifyFalse(wasAborted)
            testCase.verifyTrue(isvalid(plugin))
            testCase.verifyFalse(plugin.wasAborted)
            testCase.verifyEmpty(plugin.getOptionsEditorForTesting())
        end

        function testModifyAndAcceptOperation(testCase, PluginSpec)
            hImviewer = testCase.createHiddenImviewer();
            plugin = testCase.openPlugin(hImviewer, PluginSpec);
            testCase.addTeardown(@() testCase.deleteIfValid(plugin))

            mutation = @(editor) testCase.setEditorOption(...
                editor, PluginSpec.OptionPath, PluginSpec.NewValue);

            [~, wasAborted] = testCase.editOptionsWithAction(...
                plugin, 'Save', mutation);

            actualValue = testCase.getNestedValue(...
                plugin.Options, PluginSpec.OptionPath);

            testCase.verifyFalse(wasAborted)
            testCase.verifyEqual(actualValue, PluginSpec.NewValue)
            testCase.verifyTrue(isvalid(plugin))
        end
    end

    methods (Access = private)

        function hImviewer = createHiddenImviewer(testCase)
            oldDefaultFigureVisible = get(groot, 'DefaultFigureVisible');
            set(groot, 'DefaultFigureVisible', 'off')
            testCase.addTeardown(@set, groot, 'DefaultFigureVisible', oldDefaultFigureVisible)

            hFigure = figure('Visible', 'off', 'HandleVisibility', 'off');
            testCase.addTeardown(@() testCase.deleteIfValid(hFigure))

            hPanel = uipanel(hFigure, 'Units', 'normalized', ...
                'Position', [0, 0, 1, 1], 'Visible', 'off');

            visibilityListener = addlistener(hFigure, 'Visible', 'PostSet', ...
                @(~, ~) testCase.forceFigureHidden(hFigure));
            testCase.addTeardown(@() testCase.deleteIfValid(visibilityListener))

            hImviewer = imviewer(hPanel, rand(32, 32, 5));
            testCase.addTeardown(@() testCase.deleteIfValid(hImviewer))
            uimenu(hImviewer.Figure, 'Text', 'Align Images');
            testCase.forceFigureHidden(hFigure)
        end

        function plugin = openPlugin(~, hImviewer, pluginSpec)
            plugin = hImviewer.openPlugin(...
                pluginSpec.Constructor, pluginSpec.Options, ...
                '-p', ...
                'RunMethodOnFinish', false, ...
                'DestroyOnFinish', false);
        end

        function [options, wasAborted] = editOptionsWithAction(...
                testCase, plugin, action, mutation)

            plugin.Modal = false;
            plugin.setOptionsEditorVisibleForTesting('off')
            plugin.editOptions()

            optionsEditor = plugin.getOptionsEditorForTesting();
            testCase.assertNotEmpty(optionsEditor)
            testCase.verifyTrue(strcmp(optionsEditor.Figure.Visible, 'off'))

            if ~isempty(mutation)
                mutation(optionsEditor)
            end

            optionsEditor.quit(action)
            drawnow

            options = plugin.Options;
            wasAborted = plugin.wasAborted;
        end

        function setEditorOption(testCase, optionsEditor, optionPath, value)
            dataEdit = optionsEditor.dataEdit;

            if iscell(dataEdit)
                [panelIndex, fieldPath] = testCase.getEditorPanelIndex(...
                    optionsEditor, optionPath);
                dataEdit{panelIndex} = testCase.setNestedValue(...
                    dataEdit{panelIndex}, fieldPath, value);
            else
                dataEdit = testCase.setNestedValue(dataEdit, optionPath, value);
            end

            optionsEditor.dataEdit = dataEdit;
        end

        function [panelIndex, fieldPath] = getEditorPanelIndex(~, optionsEditor, optionPath)
            panelIndex = find(strcmp(optionsEditor.Name, optionPath{1}), 1);
            if isempty(panelIndex)
                error('NANSEN:Test:MissingOptionsPanel', ...
                    'Could not find options panel "%s".', optionPath{1})
            end
            fieldPath = optionPath(2:end);
        end

        function forceFigureHidden(~, hFigure)
            if ~isempty(hFigure) && isvalid(hFigure) && strcmp(hFigure.Visible, 'on')
                hFigure.Visible = 'off';
            end
        end

        function value = getNestedValue(~, S, fieldPath)
            subs = cellfun(@(fieldName) struct('type', '.', ...
                'subs', fieldName), fieldPath);
            value = builtin('subsref', S, subs);
        end

        function S = setNestedValue(~, S, fieldPath, value)
            subs = cellfun(@(fieldName) struct('type', '.', ...
                'subs', fieldName), fieldPath);
            S = builtin('subsasgn', S, subs, value);
        end
    end

    methods (Static)

        function pluginSpecs = getPluginSpecs()
            pluginSpecs = { ...
                struct( ...
                    'ClassName', 'nansen.plugin.imviewer.NoRMCorre', ...
                    'Constructor', @nansen.plugin.imviewer.NoRMCorre, ...
                    'Options', nansen.unittest.plugin.ImviewerModalPluginLifecycleTest.getMotionOptions(), ...
                    'OptionPath', {{'Preview', 'numFrames'}}, ...
                    'NewValue', 11), ...
                struct( ...
                    'ClassName', 'nansen.plugin.imviewer.FlowRegistration', ...
                    'Constructor', @nansen.plugin.imviewer.FlowRegistration, ...
                    'Options', nansen.unittest.plugin.ImviewerModalPluginLifecycleTest.getMotionOptions(), ...
                    'OptionPath', {{'Preview', 'numFrames'}}, ...
                    'NewValue', 11), ...
                struct( ...
                    'ClassName', 'nansen.plugin.imviewer.EXTRACT', ...
                    'Constructor', @nansen.plugin.imviewer.EXTRACT, ...
                    'Options', nansen.unittest.plugin.ImviewerModalPluginLifecycleTest.getExtractOptions(), ...
                    'OptionPath', {{'Main', 'num_partitions_x'}}, ...
                    'NewValue', 3), ...
                struct( ...
                    'ClassName', 'nansen.plugin.imviewer.FluFinder', ...
                    'Constructor', @nansen.plugin.imviewer.FluFinder, ...
                    'Options', nansen.unittest.plugin.ImviewerModalPluginLifecycleTest.getFluFinderOptions(), ...
                    'OptionPath', {{'General', 'RoiDiameter'}}, ...
                    'NewValue', 16)};
        end
    end

    methods (Static, Access = private)

        function options = getMotionOptions()
            options.Export = struct( ...
                'OutputFormat', 'Tiff', ...
                'SaveDirectory', '', ...
                'FileName', '');
            options.Preview = struct( ...
                'numFrames', 5, ...
                'saveResults', false, ...
                'showResults', true);
        end

        function options = getExtractOptions()
            options.Main = struct( ...
                'num_partitions_x', 2, ...
                'num_partitions_y', 2, ...
                'use_gpu', false, ...
                'avg_cell_radius', 6, ...
                'trace_output_option', 'raw');
            options.Preprocess = struct('temporal_denoising', false);
            options.Downsample = struct('reestimate_S_if_downsampled', false);
        end

        function options = getFluFinderOptions()
            options.General = struct('RoiDiameter', 12);
            options.Preprocessing = struct( ...
                'PrctileForBinarization', 99, ...
                'PrctileForBaseline', 20, ...
                'SmoothingSigma', 1);
        end

        function deleteIfValid(h)
            if ~isempty(h) && isvalid(h)
                delete(h)
            end
        end
    end
end
