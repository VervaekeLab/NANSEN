classdef PluginRegistryContractTest < matlab.unittest.TestCase
%PluginRegistryContractTest Phase 8 cross-registry contract tests.
%
%   Tests contracts that every concrete Registry must honour, using the
%   fixture classes (TestRegistry, MultiRootTestRegistry, TestSpec) to
%   isolate from real plugin content.
%
%   Contracts covered:
%     - Root-path precedence: first root wins when two roots have the same Id
%     - Duplicate-Id detection: duplicate within one root produces an error issue
%     - Malformed sidecar: parse error is captured as an issue, not thrown
%     - Project-first shadowing: project root (index 1) shadows later roots
%     - Sidecar shadows compat: sidecar spec is preferred over compat-derived spec
%     - Disabled plugin excluded from list, included with IncludeDisabled
%     - Disabled state is project-scoped (different projects see different states)
%     - Resolve errors for unknown Id
%     - findByDisplayName returns all matches (no silent shadowing)
%     - refresh after disable/enable cycle is consistent

    % ------------------------------------------------------------------ %
    methods (Access = private)

        function filePath = writeSidecar(~, folder, id, displayName)
        %writeSidecar Write a minimal test.plugin.json to folder.
            filePath = fullfile(folder, 'test.plugin.json');
            S = struct( ...
                'schemaVersion', '1.0', ...
                'id', id, ...
                'pluginType', 'fileadapter', ...
                'displayName', displayName, ...
                'description', '', ...
                'version', '1.0', ...
                'source', 'sidecar', ...
                'provider', struct(), ...
                'implementation', struct('language', 'matlab', 'kind', 'class', 'entrypoint', id), ...
                'capabilities', {{}});
            fid = fopen(filePath, 'w', 'n', 'UTF-8');
            fprintf(fid, '%s', jsonencode(S, 'PrettyPrint', true));
            fclose(fid);
        end

    end

    % ------------------------------------------------------------------ %
    % Root-path precedence
    % ------------------------------------------------------------------ %
    methods (Test, TestTags={'Contract', 'Precedence'})

        function testFirstRootWinsOnDuplicateId(testCase)
        %testFirstRootWinsOnDuplicateId First root path shadows later roots for same Id.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = testCase.applyFixture(TemporaryFolderFixture);

            rootA = fullfile(F.Folder, 'A'); mkdir(rootA)
            rootB = fullfile(F.Folder, 'B'); mkdir(rootB)

            testCase.writeSidecar(rootA, 'test.Conflict', 'Version A')
            testCase.writeSidecar(rootB, 'test.Conflict', 'Version B')

            reg = nansen.unittest.plugin.fixture.MultiRootTestRegistry({rootA, rootB});
            specs = reg.list();

            testCase.verifyEqual(numel(specs), 1, ...
                'Exactly one spec expected when Id conflicts across roots.')
            testCase.verifyEqual(char(specs.DisplayName), 'Version A', ...
                'First-root spec must win.')

            % A duplicate-id issue must be reported.
            issues = reg.validate();
            errIssues = issues(strcmp({issues.Severity}, 'error'));
            testCase.verifyGreaterThan(numel(errIssues), 0, ...
                'A duplicate-Id error issue must be recorded.')
        end

        function testSecondRootVisibleWhenFirstLacks(testCase)
        %testSecondRootVisibleWhenFirstLacks Specs unique to later roots still appear.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = testCase.applyFixture(TemporaryFolderFixture);

            rootA = fullfile(F.Folder, 'A'); mkdir(rootA)
            rootB = fullfile(F.Folder, 'B'); mkdir(rootB)

            testCase.writeSidecar(rootA, 'test.OnlyInA', 'Only In A')
            testCase.writeSidecar(rootB, 'test.OnlyInB', 'Only In B')

            reg = nansen.unittest.plugin.fixture.MultiRootTestRegistry({rootA, rootB});
            specs = reg.list();

            ids = string({specs.Id});
            testCase.verifyTrue(ismember('test.OnlyInA', ids))
            testCase.verifyTrue(ismember('test.OnlyInB', ids))
            testCase.verifyEqual(numel(specs), 2)
        end

        function testProjectFirstShadowsBuiltin(testCase)
        %testProjectFirstShadowsBuiltin Project-root spec (index 1) shadows same Id from module root.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = testCase.applyFixture(TemporaryFolderFixture);

            projectRoot = fullfile(F.Folder, 'project'); mkdir(projectRoot)
            moduleRoot  = fullfile(F.Folder, 'module');  mkdir(moduleRoot)

            testCase.writeSidecar(projectRoot, 'my.Plugin', 'Project Version')
            testCase.writeSidecar(moduleRoot,  'my.Plugin', 'Module Version')

            reg = nansen.unittest.plugin.fixture.MultiRootTestRegistry( ...
                {projectRoot, moduleRoot});
            spec = reg.resolve('my.Plugin');

            testCase.verifyEqual(char(spec.DisplayName), 'Project Version', ...
                'Project (first root) spec must shadow module (second root) spec.')
        end

    end

    % ------------------------------------------------------------------ %
    % Duplicate-Id within a single sidecar / root
    % ------------------------------------------------------------------ %
    methods (Test, TestTags={'Contract', 'DuplicateId'})

        function testDuplicateIdWithinSingleRootIsRecordedAsIssue(testCase)
        %testDuplicateIdWithinSingleRootIsRecordedAsIssue Grouped sidecar with duplicate Id logs an error issue.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = testCase.applyFixture(TemporaryFolderFixture);

            % Grouped sidecar with two entries that share the same Id.
            sidecarPath = fullfile(F.Folder, 'test.plugin.json');
            entry = @(name) struct( ...
                'schemaVersion', '1.0', 'id', 'dupe.Plugin', ...
                'pluginType', 'fileadapter', 'displayName', name, ...
                'description', '', 'version', '1.0', 'source', 'sidecar', ...
                'provider', struct(), ...
                'implementation', struct('language', 'matlab', 'kind', 'class', 'entrypoint', 'x'), ...
                'capabilities', {{}});
            grouped = struct('schemaVersion', '1.0', ...
                'plugins', {{entry('First'), entry('Second')}});
            fid = fopen(sidecarPath, 'w'); fprintf(fid, '%s', jsonencode(grouped)); fclose(fid);

            reg = nansen.unittest.plugin.fixture.MultiRootTestRegistry({F.Folder});
            specs = reg.list();

            testCase.verifyEqual(numel(specs), 1, ...
                'One spec expected after dedup.')
            testCase.verifyEqual(char(specs.DisplayName), 'First', ...
                'First occurrence must be kept.')

            issues = reg.validate();
            errIssues = issues(strcmp({issues.Severity}, 'error'));
            testCase.verifyGreaterThan(numel(errIssues), 0, ...
                'Duplicate Id must be recorded as an error issue.')
        end

    end

    % ------------------------------------------------------------------ %
    % Malformed sidecar
    % ------------------------------------------------------------------ %
    methods (Test, TestTags={'Contract', 'MalformedSidecar'})

        function testMalformedJsonIsRecordedAsIssueNotThrown(testCase)
        %testMalformedJsonIsRecordedAsIssueNotThrown Registry loads cleanly despite bad JSON.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = testCase.applyFixture(TemporaryFolderFixture);

            % Write a valid sidecar alongside a broken one.
            goodDir = fullfile(F.Folder, 'good'); mkdir(goodDir)
            badDir  = fullfile(F.Folder, 'bad');  mkdir(badDir)

            testCase.writeSidecar(goodDir, 'test.GoodPlugin', 'Good Plugin')
            brokenPath = fullfile(badDir, 'test.plugin.json');
            fid = fopen(brokenPath, 'w');
            fprintf(fid, '{broken json!');
            fclose(fid);

            reg = nansen.unittest.plugin.fixture.MultiRootTestRegistry({goodDir, badDir});

            % list() must not throw even with a bad sidecar in one root.
            testCase.verifyWarningFree(@() reg.list())

            specs = reg.list();
            testCase.verifyEqual(numel(specs), 1, ...
                'Only the good plugin should be discovered.')

            issues = reg.validate();
            errIssues = issues(strcmp({issues.Severity}, 'error'));
            testCase.verifyGreaterThan(numel(errIssues), 0, ...
                'Parse error must be recorded as an issue.')
        end

    end

    % ------------------------------------------------------------------ %
    % Disabled-state contract
    % ------------------------------------------------------------------ %
    methods (Test, TestTags={'Contract', 'DisabledState'})

        function testDisabledPluginAbsentFromListByDefault(testCase)
        %testDisabledPluginAbsentFromListByDefault Disabled plugin hidden from default list.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = testCase.applyFixture(TemporaryFolderFixture);

            testCase.writeSidecar(F.Folder, 'test.Disable', 'Disable Me')
            reg = nansen.unittest.plugin.fixture.TestRegistry(F.Folder, F.Folder);
            reg.disable('test.Disable');

            specs = reg.list();
            testCase.verifyEmpty(specs)
        end

        function testIncludeDisabledReturnsAllSpecs(testCase)
        %testIncludeDisabledReturnsAllSpecs list(IncludeDisabled=true) includes disabled specs.
        %
        %   Two plugins must live in separate subfolders because writeSidecar
        %   always writes to <folder>/test.plugin.json — a second write to the
        %   same folder would overwrite the first.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = testCase.applyFixture(TemporaryFolderFixture);

            dirA = fullfile(F.Folder, 'A'); mkdir(dirA)
            dirB = fullfile(F.Folder, 'B'); mkdir(dirB)

            testCase.writeSidecar(dirA, 'test.Visible', 'Visible Plugin')
            testCase.writeSidecar(dirB, 'test.Hidden',  'Hidden Plugin')
            reg = nansen.unittest.plugin.fixture.MultiRootTestRegistry( ...
                {dirA, dirB}, F.Folder);
            reg.disable('test.Hidden');

            allSpecs = reg.list('IncludeDisabled', true);
            testCase.verifyEqual(numel(allSpecs), 2)

            enabledSpecs = reg.list();
            testCase.verifyEqual(numel(enabledSpecs), 1)
            testCase.verifyEqual(char(enabledSpecs.Id), 'test.Visible')
        end

        function testDisabledStateIsScopedToProject(testCase)
        %testDisabledStateIsScopedToProject Disabling in one project does not affect another.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = testCase.applyFixture(TemporaryFolderFixture);

            sidecarDir = fullfile(F.Folder, 'plugins'); mkdir(sidecarDir)
            testCase.writeSidecar(sidecarDir, 'test.Scoped', 'Scoped Plugin')

            projA = fullfile(F.Folder, 'projA'); mkdir(projA)
            projB = fullfile(F.Folder, 'projB'); mkdir(projB)

            regA = nansen.unittest.plugin.fixture.TestRegistry(sidecarDir, projA);
            regA.disable('test.Scoped');

            regB = nansen.unittest.plugin.fixture.TestRegistry(sidecarDir, projB);
            testCase.verifyTrue(regB.isEnabled('test.Scoped'), ...
                'Disabling in project A must not affect project B.')
        end

    end

    % ------------------------------------------------------------------ %
    % Resolve contract
    % ------------------------------------------------------------------ %
    methods (Test, TestTags={'Contract', 'Resolve'})

        function testResolveThrowsForUnknownId(testCase)
        %testResolveThrowsForUnknownId resolve() errors with a typed id for missing plugins.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = testCase.applyFixture(TemporaryFolderFixture);
            reg = nansen.unittest.plugin.fixture.TestRegistry(F.Folder, F.Folder);
            testCase.verifyError( ...
                @() reg.resolve('completely.Unknown'), ...
                'nansen:plugin:Registry:PluginNotFound')
        end

        function testResolveFindsByExactId(testCase)
        %testResolveFindsByExactId resolve() returns spec with the matching Id.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = testCase.applyFixture(TemporaryFolderFixture);
            testCase.writeSidecar(F.Folder, 'test.Exact', 'Exact Match')
            reg = nansen.unittest.plugin.fixture.TestRegistry(F.Folder, F.Folder);
            spec = reg.resolve('test.Exact');
            testCase.verifyEqual(char(spec.Id), 'test.Exact')
        end

        function testFindByDisplayNameReturnsAllMatches(testCase)
        %testFindByDisplayNameReturnsAllMatches All specs with the same DisplayName are returned.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = testCase.applyFixture(TemporaryFolderFixture);

            rootA = fullfile(F.Folder, 'A'); mkdir(rootA)
            rootB = fullfile(F.Folder, 'B'); mkdir(rootB)

            testCase.writeSidecar(rootA, 'test.A', 'Shared Name')
            testCase.writeSidecar(rootB, 'test.B', 'Shared Name')

            reg = nansen.unittest.plugin.fixture.MultiRootTestRegistry({rootA, rootB});
            specs = reg.findByDisplayName('Shared Name');

            testCase.verifyEqual(numel(specs), 2, ...
                'findByDisplayName must return all specs with matching DisplayName.')
        end

    end

    % ------------------------------------------------------------------ %
    % Refresh consistency
    % ------------------------------------------------------------------ %
    methods (Test, TestTags={'Contract', 'Refresh'})

        function testRefreshAfterDisableEnableCycleIsConsistent(testCase)
        %testRefreshAfterDisableEnableCycleIsConsistent State is stable across disable/enable/refresh.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = testCase.applyFixture(TemporaryFolderFixture);

            testCase.writeSidecar(F.Folder, 'test.Cycle', 'Cycle Plugin')
            reg = nansen.unittest.plugin.fixture.TestRegistry(F.Folder, F.Folder);

            reg.disable('test.Cycle');
            testCase.verifyEmpty(reg.list())

            reg.enable('test.Cycle');
            testCase.verifyEqual(numel(reg.list()), 1)

            reg.refresh();
            testCase.verifyEqual(numel(reg.list()), 1)
        end

        function testClearThenRefreshRestoresSpecs(testCase)
        %testClearThenRefreshRestoresSpecs clear() followed by refresh() restores all specs.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = testCase.applyFixture(TemporaryFolderFixture);

            testCase.writeSidecar(F.Folder, 'test.Restore', 'Restore Plugin')
            reg = nansen.unittest.plugin.fixture.TestRegistry(F.Folder, F.Folder);
            reg.list();

            reg.clear();
            testCase.verifyEmpty(reg.Specs)

            reg.refresh();
            testCase.verifyEqual(numel(reg.list()), 1)
        end

    end

end
