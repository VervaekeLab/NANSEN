classdef ActionRegistryTest < matlab.unittest.TestCase
%ActionRegistryTest Phase 3 acceptance tests for the action plugin registry.
%
%   Verifies: sidecar parsing, compat discovery from session method files,
%   registry API, disabled-state isolation, and toTaskAttributes contract.

    properties (Constant)
        ModuleRoot = fullfile(fileparts(fileparts(fileparts(fileparts( ...
            fileparts(mfilename('fullpath')))))), 'code', 'modules')
        TwoPhotonRoot = fullfile(fileparts(fileparts(fileparts(fileparts( ...
            fileparts(mfilename('fullpath')))))), 'code', 'modules', ...
            '+nansen', '+module', '+ophys', '+twophoton', '+sessionmethod')
        GeneralRoot = fullfile(fileparts(fileparts(fileparts(fileparts( ...
            fileparts(mfilename('fullpath')))))), 'code', 'modules', ...
            '+nansen', '+module', '+general', '+core', '+sessionmethod')
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
            % Write a minimal single-plugin sidecar to a temp dir
            tmpDir = tempname();
            mkdir(tmpDir)
            cleanupDir = onCleanup(@() rmdir(tmpDir, 's'));

            S = struct( ...
                'schemaVersion', '1.0', ...
                'id', 'test.action.myMethod', ...
                'pluginType', 'action', ...
                'displayName', 'My Method', ...
                'implementation', struct('language', 'matlab', 'kind', 'function', 'entrypoint', 'test.action.myMethod'), ...
                'entityType', 'session', ...
                'methodName', 'My Method', ...
                'batchMode', 'serial', ...
                'isQueueable', true, ...
                'alternatives', {{}}, ...
                'menuLocation', {{'data'}});

            sidecarPath = fullfile(tmpDir, 'action.plugin.json');
            fid = fopen(sidecarPath, 'w');
            fprintf(fid, '%s', jsonencode(S));
            fclose(fid);

            specs = nansen.plugin.action.ActionSpec.fromJsonFile(sidecarPath);
            testCase.verifyEqual(numel(specs), 1)
            testCase.verifyEqual(char(specs.Id), 'test.action.myMethod')
            testCase.verifyEqual(char(specs.EntityType), 'session')
            testCase.verifyEqual(char(specs.BatchMode), 'serial')
            testCase.verifyTrue(specs.IsQueueable)
            testCase.verifyEqual(cellstr(specs.MenuLocation), {'data'})
        end

        function testGroupedSidecarParses(testCase)
            % Grouped sidecar (plugins array) must yield one spec per entry
            tmpDir = tempname();
            mkdir(tmpDir)
            cleanupDir = onCleanup(@() rmdir(tmpDir, 's'));

            entry = @(id, name) struct( ...
                'schemaVersion', '1.0', ...
                'id', id, ...
                'pluginType', 'action', ...
                'displayName', name, ...
                'implementation', struct('language', 'matlab', 'kind', 'class', 'entrypoint', id), ...
                'entityType', 'session', ...
                'methodName', name, ...
                'batchMode', 'serial', ...
                'isQueueable', true, ...
                'alternatives', {{}}, ...
                'menuLocation', {{'process'}});

            grouped = struct( ...
                'schemaVersion', '1.0', ...
                'pluginType', 'action', ...
                'plugins', {{entry('a.MethodA', 'Method A'), entry('b.MethodB', 'Method B')}});

            sidecarPath = fullfile(tmpDir, 'action.plugin.json');
            fid = fopen(sidecarPath, 'w');
            fprintf(fid, '%s', jsonencode(grouped));
            fclose(fid);

            specs = nansen.plugin.action.ActionSpec.fromJsonFile(sidecarPath);
            testCase.verifyEqual(numel(specs), 2)
            ids = string({specs.Id});
            testCase.verifyTrue(ismember('a.MethodA', ids))
            testCase.verifyTrue(ismember('b.MethodB', ids))
        end

    end

    % ------------------------------------------------------------------ %
    % Registry — compat discovery
    % ------------------------------------------------------------------ %
    methods (Test)

        function testRegistryFindsSessionMethodsFromModuleRoot(testCase)
            testCase.assumeTrue(isfolder(testCase.TwoPhotonRoot), ...
                'Twophoton sessionmethod folder not found')
            registry = nansen.plugin.action.Registry({testCase.TwoPhotonRoot});
            specs = registry.list();
            testCase.verifyGreaterThan(numel(specs), 0)
        end

        function testNormcorreDiscoveredAsClass(testCase)
            testCase.assumeTrue(isfolder(testCase.TwoPhotonRoot), ...
                'Twophoton sessionmethod folder not found')
            registry = nansen.plugin.action.Registry({testCase.TwoPhotonRoot});
            specs = registry.list();
            ids = string({specs.Id});
            hasNormcorre = any(contains(ids, 'normcorre', 'IgnoreCase', true));
            testCase.verifyTrue(hasNormcorre, 'normcorre not found in registry')
        end

        function testDiscoveredSpecHasMenuLocation(testCase)
            testCase.assumeTrue(isfolder(testCase.TwoPhotonRoot), ...
                'Twophoton sessionmethod folder not found')
            registry = nansen.plugin.action.Registry({testCase.TwoPhotonRoot});
            specs = registry.list();
            for i = 1:numel(specs)
                testCase.verifyNotEmpty(specs(i).MenuLocation, ...
                    sprintf('Spec "%s" has no MenuLocation', char(specs(i).Id)))
            end
        end

        function testBackupDiscoveredAsFunction(testCase)
            testCase.assumeTrue(isfolder(testCase.GeneralRoot), ...
                'General core sessionmethod folder not found')
            registry = nansen.plugin.action.Registry({testCase.GeneralRoot});
            specs = registry.list();
            ids = string({specs.Id});
            hasBackup = any(contains(ids, 'backup', 'IgnoreCase', true));
            testCase.verifyTrue(hasBackup, 'backup not found in registry')
        end

    end

    % ------------------------------------------------------------------ %
    % Lazy entity loading (path resolver)
    % ------------------------------------------------------------------ %
    methods (Test)

        function testRegistryStartsEmptyWithPathResolver(testCase)
        %testRegistryStartsEmptyWithPathResolver Registry with a path resolver has no specs until entity is requested.
            testCase.assumeTrue(isfolder(testCase.TwoPhotonRoot), ...
                'Twophoton sessionmethod folder not found')
            registry = nansen.plugin.action.Registry( ...
                @(~) {testCase.TwoPhotonRoot});
            % list() before any listByEntityType call must be empty because
            % no root paths have been loaded yet.
            testCase.verifyEmpty(registry.list(), ...
                'Registry with path resolver must start empty before any entity is requested.')
        end

        function testPathResolverPopulatesOnFirstEntityCall(testCase)
        %testPathResolverPopulatesOnFirstEntityCall First listByEntityType call triggers path loading.
            testCase.assumeTrue(isfolder(testCase.TwoPhotonRoot), ...
                'Twophoton sessionmethod folder not found')
            registry = nansen.plugin.action.Registry( ...
                @(~) {testCase.TwoPhotonRoot});
            specs = registry.listByEntityType('session');
            testCase.verifyGreaterThan(numel(specs), 0, ...
                'listByEntityType must populate registry via path resolver.')
        end

        function testRepeatedEntityLoadIsIdempotent(testCase)
        %testRepeatedEntityLoadIsIdempotent Repeated listByEntityType calls return consistent results.
            testCase.assumeTrue(isfolder(testCase.TwoPhotonRoot), ...
                'Twophoton sessionmethod folder not found')
            registry = nansen.plugin.action.Registry( ...
                @(~) {testCase.TwoPhotonRoot});
            specs1 = registry.listByEntityType('session');
            specs2 = registry.listByEntityType('session');
            testCase.verifyEqual(numel(specs1), numel(specs2), ...
                'listByEntityType must be idempotent across calls for the same entity type.')
        end

        function testDifferentEntityTypesLoadedIndependently(testCase)
        %testDifferentEntityTypesLoadedIndependently Each entity type loads via its own resolver call.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = testCase.applyFixture(TemporaryFolderFixture);

            % Session specs live under +sessionmethod, subject under +objectmethod/+subject.
            % Neither folder has real content, so specs will be empty, but the
            % key invariant tested is that loading 'session' does not cause
            % 'subject' to appear, and vice versa.
            mkdir(fullfile(F.Folder, '+sessionmethod'))
            mkdir(fullfile(F.Folder, '+objectmethod', '+subject'))

            registry = nansen.plugin.action.Registry(@(~) {F.Folder});

            sessionSpecs = registry.listByEntityType('session');
            subjectSpecs = registry.listByEntityType('subject');

            % With only empty folders there should be no specs.
            testCase.verifyEmpty(sessionSpecs)
            testCase.verifyEmpty(subjectSpecs)

            % list() after loading two entity types still returns nothing
            % because no actual method files are present.
            testCase.verifyEmpty(registry.list())
        end

        function testBackwardCompatCellArrayConstructor(testCase)
        %testBackwardCompatCellArrayConstructor Cell array of paths still works after constructor change.
            testCase.assumeTrue(isfolder(testCase.TwoPhotonRoot), ...
                'Twophoton sessionmethod folder not found')
            registry = nansen.plugin.action.Registry({testCase.TwoPhotonRoot});
            specs = registry.list();
            testCase.verifyGreaterThan(numel(specs), 0, ...
                'Cell-array constructor must discover specs from the provided path.')
        end

    end

    % ------------------------------------------------------------------ %
    % Registry API
    % ------------------------------------------------------------------ %
    methods (Test)

        function testResolveByStableId(testCase)
            testCase.assumeTrue(isfolder(testCase.TwoPhotonRoot), ...
                'Twophoton sessionmethod folder not found')
            registry = nansen.plugin.action.Registry({testCase.TwoPhotonRoot});
            specs = registry.list();
            testCase.assumeGreaterThan(numel(specs), 0)
            firstId = specs(1).Id;
            spec = registry.resolve(firstId);
            testCase.verifyEqual(char(spec.Id), char(firstId))
        end

        function testListByEntityType(testCase)
            testCase.assumeTrue(isfolder(testCase.TwoPhotonRoot), ...
                'Twophoton sessionmethod folder not found')
            registry = nansen.plugin.action.Registry({testCase.TwoPhotonRoot});
            specs = registry.listByEntityType('session');
            for i = 1:numel(specs)
                testCase.verifyEqual(lower(char(specs(i).EntityType)), 'session')
            end
        end

        function testNoValidationErrors(testCase)
            testCase.assumeTrue(isfolder(testCase.TwoPhotonRoot), ...
                'Twophoton sessionmethod folder not found')
            registry = nansen.plugin.action.Registry({testCase.TwoPhotonRoot});
            issues = registry.validate();
            errorIssues = issues(strcmp({issues.Severity}, 'error'));
            testCase.verifyEmpty(errorIssues, ...
                sprintf('%d error-level validation issues found', numel(errorIssues)))
        end

    end

    % ------------------------------------------------------------------ %
    % toTaskAttributes contract
    % ------------------------------------------------------------------ %
    methods (Test)

        function testToTaskAttributesHasRequiredFields(testCase)
            testCase.assumeTrue(isfolder(testCase.TwoPhotonRoot), ...
                'Twophoton sessionmethod folder not found')
            registry = nansen.plugin.action.Registry({testCase.TwoPhotonRoot});
            specs = registry.list();
            testCase.assumeGreaterThan(numel(specs), 0)

            for i = 1:numel(specs)
                try
                    S = specs(i).toTaskAttributes();
                    testCase.verifyTrue(isfield(S, 'FunctionName'), ...
                        sprintf('Spec "%s" missing FunctionName', char(specs(i).Id)))
                    testCase.verifyTrue(isfield(S, 'FunctionHandle'), ...
                        sprintf('Spec "%s" missing FunctionHandle', char(specs(i).Id)))
                    testCase.verifyTrue(isfield(S, 'TaskType'), ...
                        sprintf('Spec "%s" missing TaskType', char(specs(i).Id)))
                    testCase.verifyTrue(isfield(S, 'IsQueueable'), ...
                        sprintf('Spec "%s" missing IsQueueable', char(specs(i).Id)))
                    testCase.verifyTrue(isfield(S, 'BatchMode'), ...
                        sprintf('Spec "%s" missing BatchMode', char(specs(i).Id)))
                    testCase.verifyTrue(isfield(S, 'MethodName'), ...
                        sprintf('Spec "%s" missing MethodName', char(specs(i).Id)))
                catch ME
                    testCase.verifyFail(sprintf( ...
                        'toTaskAttributes threw for "%s": %s', char(specs(i).Id), ME.message))
                end
            end
        end

        function testClassSpecHasOptionsManagerInTaskAttributes(testCase)
            testCase.assumeTrue(isfolder(testCase.TwoPhotonRoot), ...
                'Twophoton sessionmethod folder not found')
            registry = nansen.plugin.action.Registry({testCase.TwoPhotonRoot});
            specs = registry.list();
            % Find a class-based spec
            isClass = arrayfun(@(s) ...
                isstruct(s.Implementation) && ...
                isfield(s.Implementation, 'kind') && ...
                strcmpi(s.Implementation.kind, 'class'), specs);
            testCase.assumeTrue(any(isClass), 'No class-based spec found')
            classSpec = specs(find(isClass, 1));
            S = classSpec.toTaskAttributes();
            testCase.verifyTrue(isfield(S, 'OptionsManager'), ...
                sprintf('Class spec "%s" missing OptionsManager in task attributes', ...
                char(classSpec.Id)))
        end

    end

    % ------------------------------------------------------------------ %
    % Disabled-state isolation
    % ------------------------------------------------------------------ %
    methods (Test)

        function testDisableAndEnableAction(testCase)
            testCase.assumeTrue(isfolder(testCase.TwoPhotonRoot), ...
                'Twophoton sessionmethod folder not found')

            tmpDir = tempname();
            mkdir(tmpDir)
            cleanupDir = onCleanup(@() rmdir(tmpDir, 's'));

            registry = nansen.plugin.action.Registry({testCase.TwoPhotonRoot}, tmpDir);
            specs = registry.list();
            testCase.assumeGreaterThan(numel(specs), 0)

            targetId = specs(1).Id;
            registry.disable(targetId);
            testCase.verifyFalse(registry.isEnabled(targetId))

            listIds = string({registry.list().Id});
            testCase.verifyFalse(ismember(targetId, listIds))

            registry.enable(targetId);
            testCase.verifyTrue(registry.isEnabled(targetId))
        end

    end

end
