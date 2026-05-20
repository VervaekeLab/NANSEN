classdef TableVariableRegistryTest < matlab.unittest.TestCase
%TableVariableRegistryTest Phase 4 acceptance tests for the table variable plugin registry.
%
%   Verifies: sidecar parsing, compat discovery from TableVariable subclasses,
%   registry API, listByTableType, getVariableAttributes contract,
%   disabled-state isolation, and project-first shadowing.

    properties (Constant)
        GeneralCoreRoot = fullfile(fileparts(fileparts(fileparts(fileparts( ...
            fileparts(mfilename('fullpath')))))), 'code', 'modules', ...
            '+nansen', '+module', '+general', '+core', '+tablevariable')
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
                'id', 'test.tablevariable.session.MyVar', ...
                'pluginType', 'tablevariable', ...
                'displayName', 'My Var', ...
                'implementation', struct('language', 'matlab', 'kind', 'class', ...
                    'entrypoint', 'test.tablevariable.session.MyVar'), ...
                'variableName', 'MyVar', ...
                'tableType', 'session', ...
                'isEditable', false, ...
                'alternatives', {{}});

            sidecarPath = fullfile(tmpDir, 'tablevariable.plugin.json');
            fid = fopen(sidecarPath, 'w');
            fprintf(fid, '%s', jsonencode(S));
            fclose(fid);

            specs = nansen.plugin.tablevariable.TableVariableSpec.fromJsonFile(sidecarPath);
            testCase.verifyEqual(numel(specs), 1)
            testCase.verifyEqual(char(specs.Id), 'test.tablevariable.session.MyVar')
            testCase.verifyEqual(char(specs.VariableName), 'MyVar')
            testCase.verifyEqual(char(specs.TableType), 'session')
            testCase.verifyFalse(specs.IsEditable)
        end

        function testGroupedSidecarParses(testCase)
            tmpDir = tempname();
            mkdir(tmpDir)
            cleanupDir = onCleanup(@() rmdir(tmpDir, 's'));

            entry = @(id, name, tt) struct( ...
                'schemaVersion', '1.0', ...
                'id', id, ...
                'pluginType', 'tablevariable', ...
                'displayName', name, ...
                'implementation', struct('language', 'matlab', 'kind', 'class', 'entrypoint', id), ...
                'variableName', name, ...
                'tableType', tt, ...
                'isEditable', false, ...
                'alternatives', {{}});

            grouped = struct( ...
                'schemaVersion', '1.0', ...
                'pluginType', 'tablevariable', ...
                'plugins', {{entry('a.VarA', 'VarA', 'session'), entry('b.VarB', 'VarB', 'subject')}});

            sidecarPath = fullfile(tmpDir, 'tablevariable.plugin.json');
            fid = fopen(sidecarPath, 'w');
            fprintf(fid, '%s', jsonencode(grouped));
            fclose(fid);

            specs = nansen.plugin.tablevariable.TableVariableSpec.fromJsonFile(sidecarPath);
            testCase.verifyEqual(numel(specs), 2)
            ids = string({specs.Id});
            testCase.verifyTrue(ismember('a.VarA', ids))
            testCase.verifyTrue(ismember('b.VarB', ids))
        end

    end

    % ------------------------------------------------------------------ %
    % Registry — compat discovery
    % ------------------------------------------------------------------ %
    methods (Test)

        function testRegistryFindsSessionVariables(testCase)
            testCase.assumeTrue(isfolder(testCase.GeneralCoreRoot), ...
                'General core tablevariable folder not found')
            registry = nansen.plugin.tablevariable.Registry({testCase.GeneralCoreRoot});
            specs = registry.list();
            testCase.verifyGreaterThan(numel(specs), 0)
        end

        function testRegistryFindsSubjectVariables(testCase)
            testCase.assumeTrue(isfolder(testCase.GeneralCoreRoot), ...
                'General core tablevariable folder not found')
            registry = nansen.plugin.tablevariable.Registry({testCase.GeneralCoreRoot});
            subjectSpecs = registry.listByTableType('subject');
            testCase.verifyGreaterThan(numel(subjectSpecs), 0)
        end

        function testProgressDiscoveredAsSession(testCase)
            testCase.assumeTrue(isfolder(testCase.GeneralCoreRoot), ...
                'General core tablevariable folder not found')
            registry = nansen.plugin.tablevariable.Registry({testCase.GeneralCoreRoot});
            specs = registry.list();
            ids = string({specs.Id});
            hasProgress = any(contains(ids, 'Progress', 'IgnoreCase', false));
            testCase.verifyTrue(hasProgress, 'Progress not found in registry')
        end

        function testSpeciesDiscoveredAsEditable(testCase)
            testCase.assumeTrue(isfolder(testCase.GeneralCoreRoot), ...
                'General core tablevariable folder not found')
            registry = nansen.plugin.tablevariable.Registry({testCase.GeneralCoreRoot});
            specs = registry.list();
            ids = string({specs.Id});
            speciesIdx = find(contains(ids, 'Species', 'IgnoreCase', false), 1);
            testCase.assumeTrue(~isempty(speciesIdx), 'Species not found in registry')
            testCase.verifyTrue(specs(speciesIdx).IsEditable, ...
                'Species should be IsEditable=true')
        end

        function testAllDiscoveredSpecsHaveTableType(testCase)
            testCase.assumeTrue(isfolder(testCase.GeneralCoreRoot), ...
                'General core tablevariable folder not found')
            registry = nansen.plugin.tablevariable.Registry({testCase.GeneralCoreRoot});
            specs = registry.list();
            for i = 1:numel(specs)
                testCase.verifyNotEmpty(char(specs(i).TableType), ...
                    sprintf('Spec "%s" has empty TableType', char(specs(i).Id)))
            end
        end

    end

    % ------------------------------------------------------------------ %
    % Registry API
    % ------------------------------------------------------------------ %
    methods (Test)

        function testListByTableTypeReturnsOnlyMatchingType(testCase)
            testCase.assumeTrue(isfolder(testCase.GeneralCoreRoot), ...
                'General core tablevariable folder not found')
            registry = nansen.plugin.tablevariable.Registry({testCase.GeneralCoreRoot});
            specs = registry.listByTableType('session');
            for i = 1:numel(specs)
                testCase.verifyEqual(lower(char(specs(i).TableType)), 'session', ...
                    sprintf('Spec "%s" has wrong TableType', char(specs(i).Id)))
            end
        end

        function testResolveByStableId(testCase)
            testCase.assumeTrue(isfolder(testCase.GeneralCoreRoot), ...
                'General core tablevariable folder not found')
            registry = nansen.plugin.tablevariable.Registry({testCase.GeneralCoreRoot});
            specs = registry.list();
            testCase.assumeGreaterThan(numel(specs), 0)
            firstId = specs(1).Id;
            resolved = registry.resolve(firstId);
            testCase.verifyEqual(char(resolved.Id), char(firstId))
        end

        function testNoValidationErrors(testCase)
            testCase.assumeTrue(isfolder(testCase.GeneralCoreRoot), ...
                'General core tablevariable folder not found')
            registry = nansen.plugin.tablevariable.Registry({testCase.GeneralCoreRoot});
            issues = registry.validate();
            errorIssues = issues(strcmp({issues.Severity}, 'error'));
            testCase.verifyEmpty(errorIssues, ...
                sprintf('%d error-level validation issues found', numel(errorIssues)))
        end

    end

    % ------------------------------------------------------------------ %
    % toVariableAttributes contract
    % ------------------------------------------------------------------ %
    methods (Test)

        function testToVariableAttributesHasRequiredFields(testCase)
            testCase.assumeTrue(isfolder(testCase.GeneralCoreRoot), ...
                'General core tablevariable folder not found')
            registry = nansen.plugin.tablevariable.Registry({testCase.GeneralCoreRoot});
            specs = registry.list();
            testCase.assumeGreaterThan(numel(specs), 0)

            requiredFields = {'Name', 'TableType', 'IsEditable', 'HasClassDefinition'};
            for i = 1:numel(specs)
                try
                    S = specs(i).toVariableAttributes();
                    for f = 1:numel(requiredFields)
                        testCase.verifyTrue(isfield(S, requiredFields{f}), ...
                            sprintf('Spec "%s" missing field "%s" in toVariableAttributes', ...
                            char(specs(i).Id), requiredFields{f}))
                    end
                catch ME
                    testCase.verifyFail(sprintf( ...
                        'toVariableAttributes threw for "%s": %s', ...
                        char(specs(i).Id), ME.message))
                end
            end
        end

        function testGetVariableAttributesReturnsTable(testCase)
            testCase.assumeTrue(isfolder(testCase.GeneralCoreRoot), ...
                'General core tablevariable folder not found')
            registry = nansen.plugin.tablevariable.Registry({testCase.GeneralCoreRoot});
            T = registry.getVariableAttributes('session');
            testCase.verifyClass(T, 'table')
            testCase.verifyGreaterThan(height(T), 0)
            testCase.verifyTrue(ismember('Name', T.Properties.VariableNames))
            testCase.verifyTrue(ismember('TableType', T.Properties.VariableNames))
        end

    end

    % ------------------------------------------------------------------ %
    % Project-first shadowing
    % ------------------------------------------------------------------ %
    methods (Test)

        function testProjectRootShadowsModuleOnSameVariableName(testCase)
            testCase.assumeTrue(isfolder(testCase.GeneralCoreRoot), ...
                'General core tablevariable folder not found')

            % Create a project +tablevariable folder with a Progress class
            % that has IsEditable=true (whereas the builtin has IsEditable=false)
            tmpDir = tempname();
            sessionDir = fullfile(tmpDir, '+session');
            mkdir(sessionDir)
            cleanupDir = onCleanup(@() rmdir(tmpDir, 's'));

            progressSrc = sprintf([...
                'classdef Progress < nansen.metadata.abstract.TableVariable\n', ...
                '    properties (Constant)\n', ...
                '        IS_EDITABLE = true\n', ...  % differs from builtin
                '        DEFAULT_VALUE = ''''\n', ...
                '    end\n', ...
                'end\n']);
            fid = fopen(fullfile(sessionDir, 'Progress.m'), 'w');
            fprintf(fid, '%s', progressSrc);
            fclose(fid);

            addpath(tmpDir)
            cleanupPath = onCleanup(@() rmpath(tmpDir));

            % Project root first, module root second
            registry = nansen.plugin.tablevariable.Registry( ...
                {tmpDir, testCase.GeneralCoreRoot});
            specs = registry.listByTableType('session');

            progressIdx = find(arrayfun(@(s) strcmp(char(s.VariableName), 'Progress'), specs), 1);
            testCase.assumeTrue(~isempty(progressIdx), 'Progress not found after shadowing test')

            % The project version (IsEditable=true) should win
            testCase.verifyTrue(specs(progressIdx).IsEditable, ...
                'Project-defined Progress should shadow module Progress (IsEditable=true)')
        end

    end

    % ------------------------------------------------------------------ %
    % Disabled-state isolation
    % ------------------------------------------------------------------ %
    methods (Test)

        function testDisableAndEnableVariable(testCase)
            testCase.assumeTrue(isfolder(testCase.GeneralCoreRoot), ...
                'General core tablevariable folder not found')

            tmpDir = tempname();
            mkdir(tmpDir)
            cleanupDir = onCleanup(@() rmdir(tmpDir, 's'));

            registry = nansen.plugin.tablevariable.Registry( ...
                {testCase.GeneralCoreRoot}, tmpDir);
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
