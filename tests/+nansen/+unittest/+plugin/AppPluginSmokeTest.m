classdef AppPluginSmokeTest < matlab.unittest.TestCase
%AppPluginSmokeTest Smoke tests for plugin class loading and argument routing

    properties (TestParameter)
        PluginClassName = { ...
            'applify.mixin.AppPlugin', ...
            'applify.mixin.HasOptionsManager', ...
            'applify.mixin.ModalMethodPreviewController', ...
            'nansen.plugin.signalviewer.DffExplorer', ...
            'nansen.plugin.signalviewer.CaimanDeconvolution', ...
            'nansen.plugin.imviewer.NoRMCorre', ...
            'nansen.plugin.imviewer.FlowRegistration', ...
            'nansen.plugin.imviewer.EXTRACT', ...
            'nansen.plugin.imviewer.FluFinder', ...
            'imviewer.plugin.NoRMCorre', ...
            'imviewer.plugin.FlowRegistration', ...
            'imviewer.plugin.RoiClassifier', ...
            'imviewer.plugin.RoiManager'}
    end

    methods (Test)

        function testPluginClassLoads(testCase, PluginClassName)
            classMeta = meta.class.fromName(PluginClassName);
            testCase.verifyNotEmpty(classMeta, ...
                sprintf('Expected "%s" to load.', PluginClassName))
        end

        function testSplitOptionsArgumentKeepsPluginArguments(testCase)
            options = struct('A', 1);
            inputArguments = {options, '-p', 'Modal', false};

            [actualOptions, pluginArguments] = ...
                applify.mixin.HasOptionsManager.splitOptionsArgument(inputArguments);

            testCase.verifyEqual(actualOptions, options)
            testCase.verifyEqual(pluginArguments, {'-p', 'Modal', false})

            inputArguments = {'-p', 'Modal', false};
            [actualOptions, pluginArguments] = ...
                applify.mixin.HasOptionsManager.splitOptionsArgument(inputArguments);

            testCase.verifyEmpty(actualOptions)
            testCase.verifyEqual(pluginArguments, {'-p', 'Modal', false})
        end

    end

    methods (Test, TestTags="Graphical")

        function testModalPluginConstructorRoutesOptionsAndPropertyPairs(testCase)
            hImviewer = testCase.createHiddenImviewer();

            plugin = nansen.plugin.imviewer.NoRMCorre(...
                hImviewer, '-p', 'Modal', false);
            testCase.addTeardown(@() testCase.deleteIfValid(plugin))

            testCase.verifyTrue(plugin.PartialConstruction)
            testCase.verifyFalse(plugin.Modal)
            testCase.verifyNotEmpty(plugin.Options)

            options = plugin.Options;
            hImviewer = testCase.createHiddenImviewer();

            plugin = nansen.plugin.imviewer.NoRMCorre(...
                hImviewer, options, '-p', 'Modal', false);
            testCase.addTeardown(@() testCase.deleteIfValid(plugin))

            testCase.verifyTrue(plugin.PartialConstruction)
            testCase.verifyFalse(plugin.Modal)
            testCase.verifyEqual(plugin.Options, options)
        end

        function testOpenPluginDoesNotPassEmptyOptionsPlaceholder(testCase)
            hImviewer = testCase.createHiddenImviewer();

            hPlugin = hImviewer.openPlugin('RoiClassifier');

            if ~isempty(hPlugin)
                testCase.verifyTrue(...
                    isa(hPlugin, 'imviewer.plugin.RoiClassifier') || ~isvalid(hPlugin))
            end
        end
    end

    methods (Access = private)

        function hImviewer = createHiddenImviewer(testCase)
            oldDefaultFigureVisible = get(groot, 'DefaultFigureVisible');
            set(groot, 'DefaultFigureVisible', 'off')
            testCase.addTeardown(@set, groot, 'DefaultFigureVisible', oldDefaultFigureVisible)

            hImviewer = imviewer(rand(16, 16, 5));
            testCase.addTeardown(@() testCase.deleteIfValid(hImviewer))
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
