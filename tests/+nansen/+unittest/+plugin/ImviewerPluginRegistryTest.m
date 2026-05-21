classdef ImviewerPluginRegistryTest < matlab.unittest.TestCase
%ImviewerPluginRegistryTest Phase 5 acceptance tests for the imviewer plugin registry.
%
%   Verifies: sidecar parsing, compat discovery from ImviewerPlugin subclasses,
%   thin-wrapper filtering, registry API (list, resolve, findPlugin), and
%   the getInstance singleton.

    properties (Constant)
        AppPluginRoot = fullfile(fileparts(fileparts(fileparts(fileparts( ...
            fileparts(mfilename('fullpath')))))), 'code', 'apps', '+imviewer', '+plugin')
        WrapperRoot   = fullfile(fileparts(fileparts(fileparts(fileparts( ...
            fileparts(mfilename('fullpath')))))), 'code', 'wrappers', '+nansen', '+plugin', '+imviewer')
    end

    % ------------------------------------------------------------------ %
    methods (TestClassSetup)
        function addNansenPath(testCase) %#ok<MANU>
            root = fullfile(fileparts(fileparts(fileparts(fileparts( ...
                fileparts(mfilename('fullpath')))))));
            addpath(genpath(fullfile(root, 'code')));
            addpath(genpath(fullfile(root, 'tests')));
        end
    end

    % ------------------------------------------------------------------ %
    % Sidecar parsing
    % ------------------------------------------------------------------ %
    methods (Test)

        function testSingleSidecarParses(testCase)
            tmpDir = tempname();
            mkdir(tmpDir)
            cleanupDir = onCleanup(@() rmdir(tmpDir, 's'));

            S = struct( ...
                'schemaVersion', '1.0', ...
                'id', 'test.plugin.imviewer.MyPlugin', ...
                'displayName', 'My Plugin', ...
                'implementation', struct('language', 'matlab', 'kind', 'class', ...
                    'entrypoint', 'test.plugin.imviewer.MyPlugin'), ...
                'menuLocation', {{'Align Images'}}, ...
                'iconName', 'align', ...
                'shortcutKey', 'A');

            sidecarPath = fullfile(tmpDir, 'imviewerplugin.plugin.json');
            fid = fopen(sidecarPath, 'w');
            fprintf(fid, '%s', jsonencode(S));
            fclose(fid);

            specs = nansen.plugin.imviewer.ImviewerPluginSpec.fromJsonFile(sidecarPath);
            testCase.verifyEqual(numel(specs), 1)
            testCase.verifyEqual(char(specs.Id), 'test.plugin.imviewer.MyPlugin')
            testCase.verifyEqual(char(specs.DisplayName), 'My Plugin')
            testCase.verifyEqual(char(specs.MenuLocation), 'Align Images')
            testCase.verifyEqual(char(specs.IconName), 'align')
            testCase.verifyEqual(char(specs.ShortcutKey), 'A')
        end

        function testGroupedSidecarParses(testCase)
            tmpDir = tempname();
            mkdir(tmpDir)
            cleanupDir = onCleanup(@() rmdir(tmpDir, 's'));

            entry = @(id, name) struct( ...
                'schemaVersion', '1.0', ...
                'id', id, ...
                'displayName', name, ...
                'implementation', struct('language', 'matlab', 'kind', 'class', 'entrypoint', id), ...
                'menuLocation', {{}}, 'iconName', '', 'shortcutKey', '');

            grouped = struct( ...
                'schemaVersion', '1.0', ...
                'plugins', {{entry('a.PlugA', 'Plug A'), entry('b.PlugB', 'Plug B')}});

            sidecarPath = fullfile(tmpDir, 'imviewerplugin.plugin.json');
            fid = fopen(sidecarPath, 'w');
            fprintf(fid, '%s', jsonencode(grouped));
            fclose(fid);

            specs = nansen.plugin.imviewer.ImviewerPluginSpec.fromJsonFile(sidecarPath);
            testCase.verifyEqual(numel(specs), 2)
            ids = string({specs.Id});
            testCase.verifyTrue(ismember('a.PlugA', ids))
            testCase.verifyTrue(ismember('b.PlugB', ids))
        end

    end

    % ------------------------------------------------------------------ %
    % Compat discovery
    % ------------------------------------------------------------------ %
    methods (Test)

        function testRegistryFindsRoiManager(testCase)
            testCase.assumeTrue(isfolder(testCase.AppPluginRoot), ...
                'App plugin root not found')
            registry = nansen.plugin.imviewer.Registry();
            specs = registry.list();
            testCase.verifyGreaterThan(numel(specs), 0)
            ids = arrayfun(@(s) char(s.Id), specs, 'uni', false);
            hasRoiManager = any(contains(ids, 'RoiManager'));
            testCase.verifyTrue(hasRoiManager, 'RoiManager should be discoverable')
        end

        function testThinWrappersAreExcluded(testCase)
            testCase.assumeTrue(isfolder(testCase.AppPluginRoot), ...
                'App plugin root not found')
            registry = nansen.plugin.imviewer.Registry();
            specs = registry.list();
            ids = arrayfun(@(s) char(s.Id), specs, 'uni', false);
            % imviewer.plugin.NoRMCorre and imviewer.plugin.FlowRegistration
            % are thin wrappers — must NOT appear in the registry
            testCase.verifyFalse(any(strcmp(ids, 'imviewer.plugin.NoRMCorre')), ...
                'Thin wrapper imviewer.plugin.NoRMCorre should be excluded')
            testCase.verifyFalse(any(strcmp(ids, 'imviewer.plugin.FlowRegistration')), ...
                'Thin wrapper imviewer.plugin.FlowRegistration should be excluded')
        end

        function testAuthorisedImplementationsAreIncluded(testCase)
            testCase.assumeTrue(isfolder(testCase.WrapperRoot), ...
                'Wrapper root not found')
            registry = nansen.plugin.imviewer.Registry();
            specs = registry.list();
            ids = arrayfun(@(s) char(s.Id), specs, 'uni', false);
            % The canonical implementations in nansen.plugin.imviewer.* should appear
            hasNormcorre = any(contains(ids, 'nansen.plugin.imviewer.NoRMCorre'));
            testCase.verifyTrue(hasNormcorre, ...
                'nansen.plugin.imviewer.NoRMCorre should be discoverable')
        end

        function testAllDiscoveredSpecsHaveDisplayName(testCase)
            testCase.assumeTrue(isfolder(testCase.AppPluginRoot), ...
                'App plugin root not found')
            registry = nansen.plugin.imviewer.Registry();
            specs = registry.list();
            for i = 1:numel(specs)
                testCase.verifyNotEmpty(char(specs(i).DisplayName), ...
                    sprintf('Spec "%s" has empty DisplayName', char(specs(i).Id)))
            end
        end

    end

    % ------------------------------------------------------------------ %
    % Registry API
    % ------------------------------------------------------------------ %
    methods (Test)

        function testResolveByStableId(testCase)
            testCase.assumeTrue(isfolder(testCase.AppPluginRoot), ...
                'App plugin root not found')
            registry = nansen.plugin.imviewer.Registry();
            specs = registry.list();
            testCase.assumeGreaterThan(numel(specs), 0)
            firstId = specs(1).Id;
            resolved = registry.resolve(firstId);
            testCase.verifyEqual(char(resolved.Id), char(firstId))
        end

        function testFindPluginByDisplayName(testCase)
            testCase.assumeTrue(isfolder(testCase.AppPluginRoot), ...
                'App plugin root not found')
            registry = nansen.plugin.imviewer.Registry();
            specs = registry.list();
            testCase.assumeGreaterThan(numel(specs), 0)
            displayName = specs(1).DisplayName;
            found = registry.findPlugin(displayName);
            testCase.verifyEqual(char(found.DisplayName), char(displayName))
        end

        function testFindPluginThrowsForUnknownName(testCase)
            registry = nansen.plugin.imviewer.Registry();
            testCase.verifyError( ...
                @() registry.findPlugin('__NonExistentPlugin__9999'), ...
                'nansen:plugin:imviewer:Registry:NotFound')
        end

        function testNoValidationErrors(testCase)
            testCase.assumeTrue(isfolder(testCase.AppPluginRoot), ...
                'App plugin root not found')
            registry = nansen.plugin.imviewer.Registry();
            issues = registry.validate();
            errorIssues = issues(strcmp({issues.Severity}, 'error'));
            testCase.verifyEmpty(errorIssues, ...
                sprintf('%d error-level validation issues found', numel(errorIssues)))
        end

    end

    % ------------------------------------------------------------------ %
    % toFunctionHandle
    % ------------------------------------------------------------------ %
    methods (Test)

        function testSidecarSpecToFunctionHandle(testCase)
            opts = struct( ...
                'Id', 'test.FakePlugin', ...
                'DisplayName', 'Fake Plugin', ...
                'Implementation', struct('language', 'matlab', 'kind', 'class', ...
                    'entrypoint', 'nansen.plugin.imviewer.Registry'));

            spec = nansen.plugin.imviewer.ImviewerPluginSpec(opts);
            fcn = spec.toFunctionHandle();
            testCase.verifyEqual(func2str(fcn), 'nansen.plugin.imviewer.Registry')
        end

        function testSpecMissingEntrypointErrors(testCase)
            opts = struct( ...
                'Id', 'test.NoEntry', ...
                'DisplayName', 'No Entry');

            spec = nansen.plugin.imviewer.ImviewerPluginSpec(opts);
            testCase.verifyError( ...
                @() spec.toFunctionHandle(), ...
                'nansen:plugin:imviewer:ImviewerPluginSpec:MissingEntrypoint')
        end

    end

    % ------------------------------------------------------------------ %
    % Singleton
    % ------------------------------------------------------------------ %
    methods (Test)

        function testGetInstanceReturnsSameObject(testCase)
            r1 = nansen.plugin.imviewer.Registry.getInstance();
            r2 = nansen.plugin.imviewer.Registry.getInstance();
            testCase.verifyEqual(r1, r2)
        end

    end

end
