classdef PluginFoundationTest < matlab.unittest.TestCase
%PluginFoundationTest Phase 1 acceptance tests for PluginSpec and Registry bases.
%
%   Tests:
%     - PluginSpec and Registry are abstract (cannot instantiate directly)
%     - TestSpec round-trips a fixture sidecar through fromJsonFile → toJson
%     - Specification.checkRequired rejects specs with missing required fields
%     - Disabled-state persistence across Registry instances (project-folder prefs)
%     - Events fire on add/remove/refresh
%     - Mtime cache prevents re-parsing unchanged sidecars

    properties (TestParameter)
        % id/displayName pairs used across multiple tests
    end

    % ------------------------------------------------------------------ %
    % Test helpers
    % ------------------------------------------------------------------ %
    methods (Access = private)

        function filePath = writeSidecar(~, folder, id, displayName)
        %writeSidecar Write a minimal test.plugin.json to folder.
            filePath = fullfile(folder, 'test.plugin.json');
            S = struct( ...
                'schemaVersion',  '1.0', ...
                'id',             id, ...
                'pluginType',     'fileadapter', ...
                'displayName',    displayName, ...
                'description',    'A fixture plugin', ...
                'version',        '0.1', ...
                'source',         'sidecar', ...
                'provider',       struct(), ...
                'implementation', struct('language', 'matlab', 'kind', 'class', 'entrypoint', 'TestClass'), ...
                'capabilities',   {{}});
            fid = fopen(filePath, 'w', 'n', 'UTF-8');
            fprintf(fid, '%s', jsonencode(S, 'PrettyPrint', true));
            fclose(fid);
        end
    end

    % ------------------------------------------------------------------ %
    % Abstractness
    % ------------------------------------------------------------------ %
    methods (Test, TestTags = {'Phase1', 'Foundation'})

        function testPluginSpecIsAbstract(tc)
        %testPluginSpecIsAbstract PluginSpec cannot be instantiated directly.
            mc = meta.class.fromName('nansen.plugin.base.PluginSpec');
            tc.verifyTrue(mc.Abstract, ...
                'nansen.plugin.base.PluginSpec must be declared abstract.')
        end

        function testRegistryIsAbstract(tc)
        %testRegistryIsAbstract Registry cannot be instantiated directly.
            mc = meta.class.fromName('nansen.plugin.base.Registry');
            tc.verifyTrue(mc.Abstract, ...
                'nansen.plugin.base.Registry must be declared abstract.')
        end

        function testPluginTypesAreCapabilityTypes(tc)
        %testPluginTypesAreCapabilityTypes Modules are providers, not plugins.
            enumValues = enumeration('nansen.plugin.enum.PluginType');
            enumNames = string(arrayfun(@char, enumValues, 'UniformOutput', false));
            enumNames = enumNames(:);

            tc.verifyEqual(enumNames, ...
                ["FileAdapter"; "Action"; "TableVariable"; "ImviewerPlugin"], ...
                'PluginType must only enumerate concrete plugin capability types.')
        end
    end

    % ------------------------------------------------------------------ %
    % Round-trip: sidecar → typed properties → toJson
    % ------------------------------------------------------------------ %
    methods (Test, TestTags = {'Phase1', 'RoundTrip'})

        function testSidecarRoundTrip(tc)
        %testSidecarRoundTrip fromJsonFile preserves all base fields; toJson re-serializes.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = tc.applyFixture(TemporaryFolderFixture);

            filePath = tc.writeSidecar(F.Folder, 'test.Alpha', 'Alpha Plugin');

            specs = nansen.unittest.plugin.fixture.TestSpec.fromJsonFile(filePath);
            tc.assertNumElements(specs, 1, 'fromJsonFile must return a 1-element array.')

            spec = specs(1);
            tc.verifyEqual(spec.Id,          "test.Alpha",    'Id mismatch.')
            tc.verifyEqual(spec.DisplayName, "Alpha Plugin",  'DisplayName mismatch.')
            tc.verifyEqual(spec.Description, "A fixture plugin", 'Description mismatch.')
            tc.verifyEqual(spec.PluginVersion, "0.1",          'PluginVersion mismatch.')
            tc.verifyEqual(spec.Source,      "sidecar",       'Source mismatch.')

            jsonStr = spec.toJson();
            tc.verifyClass(jsonStr, 'char', 'toJson must return a char.')
            tc.verifyNotEmpty(jsonStr, 'toJson output must not be empty.')

            S = jsondecode(jsonStr);
            tc.verifyEqual(S.id,          'test.Alpha',    'Round-trip id mismatch.')
            tc.verifyEqual(S.displayName, 'Alpha Plugin',  'Round-trip displayName mismatch.')
        end

        function testFromJsonFileReturnsArray(tc)
        %testFromJsonFileReturnsArray fromJsonFile always returns a spec array.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = tc.applyFixture(TemporaryFolderFixture);

            filePath = tc.writeSidecar(F.Folder, 'test.Beta', 'Beta Plugin');

            specs = nansen.unittest.plugin.fixture.TestSpec.fromJsonFile(filePath);
            tc.verifyClass(specs, 'nansen.unittest.plugin.fixture.TestSpec')
            tc.verifyNumElements(specs, 1)
        end
    end

    % ------------------------------------------------------------------ %
    % checkRequired
    % ------------------------------------------------------------------ %
    methods (Test, TestTags = {'Phase1', 'Validation'})

        function testCheckRequiredThrowsForMissingId(tc)
        %testCheckRequiredThrowsForMissingId Spec constructor rejects missing required property.
            opts = struct('DisplayName', 'No Id Plugin');
            tc.verifyError( ...
                @() nansen.unittest.plugin.fixture.TestSpec(opts), ...
                'NANSEN:Specification:MissingRequiredProperties')
        end

        function testCheckRequiredThrowsForMissingDisplayName(tc)
        %testCheckRequiredThrowsForMissingDisplayName Both required properties are validated.
            opts = struct('Id', 'test.Orphan');
            tc.verifyError( ...
                @() nansen.unittest.plugin.fixture.TestSpec(opts), ...
                'NANSEN:Specification:MissingRequiredProperties')
        end

        function testCheckRequiredPassesWhenAllPresent(tc)
        %testCheckRequiredPassesWhenAllPresent No error when all required fields are set.
            opts = struct('Id', 'test.Complete', 'DisplayName', 'Complete Plugin');
            spec = nansen.unittest.plugin.fixture.TestSpec(opts);
            tc.verifyEqual(spec.Id, "test.Complete")
        end
    end

    % ------------------------------------------------------------------ %
    % Schema validation
    % ------------------------------------------------------------------ %
    methods (Test, TestTags = {'Phase1', 'SchemaValidation'})

        function testValidateSidecarFieldsWarnsPascalCase(tc)
        %testValidateSidecarFieldsWarnsPascalCase PascalCase keys produce a warning issue.
            S = struct('SchemaVersion', '1.0', 'id', 'x');
            issues = nansen.plugin.base.PluginSpec.validateSidecarFields(S);
            isCamelWarn = strcmp({issues.Severity}, 'warning') & ...
                contains({issues.Message}, 'PascalCase');
            tc.verifyTrue(any(isCamelWarn), ...
                'Expected a warning issue for PascalCase field "SchemaVersion".')
        end

        function testValidateSidecarFieldsErrorsForBadKind(tc)
        %testValidateSidecarFieldsErrorsForBadKind Unknown implementation.kind produces error issue.
            S = struct( ...
                'id', 'x', ...
                'implementation', struct('kind', 'unknown_kind'));
            issues = nansen.plugin.base.PluginSpec.validateSidecarFields(S);
            isKindError = strcmp({issues.Severity}, 'error') & ...
                contains({issues.Field}, 'implementation.kind');
            tc.verifyTrue(any(isKindError), ...
                'Expected an error issue for unknown implementation.kind.')
        end

        function testValidateSidecarFieldsPassesForValidSidecar(tc)
        %testValidateSidecarFieldsPassesForValidSidecar No errors for a well-formed sidecar.
            S = struct( ...
                'schemaVersion', '1.0', ...
                'id', 'good.plugin', ...
                'implementation', struct('kind', 'class'));
            issues = nansen.plugin.base.PluginSpec.validateSidecarFields(S);
            errors = issues(strcmp({issues.Severity}, 'error'));
            tc.verifyEmpty(errors, 'No error issues expected for a valid sidecar.')
        end
    end

    % ------------------------------------------------------------------ %
    % Disabled-state persistence (project-scoped)
    % ------------------------------------------------------------------ %
    methods (Test, TestTags = {'Phase1', 'DisabledState'})

        function testDisabledStatePersistsAcrossRegistryInstances(tc)
        %testDisabledStatePersistsAcrossRegistryInstances Disabled id survives across separate registry objects.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = tc.applyFixture(TemporaryFolderFixture);

            projFolder = fullfile(F.Folder, 'project');
            mkdir(projFolder)

            sidecarFolder = fullfile(F.Folder, 'plugins');
            mkdir(sidecarFolder)
            tc.writeSidecar(sidecarFolder, 'test.Persistent', 'Persistent Plugin');

            % Disable via first registry instance.
            reg1 = nansen.unittest.plugin.fixture.TestRegistry(sidecarFolder, projFolder);
            reg1.list();
            reg1.disable('test.Persistent');
            tc.verifyFalse(reg1.isEnabled('test.Persistent'))

            % Verify via a second instance using the same project folder.
            reg2 = nansen.unittest.plugin.fixture.TestRegistry(sidecarFolder, projFolder);
            tc.verifyFalse(reg2.isEnabled('test.Persistent'), ...
                'Disabled state must persist across separate registry instances.')
        end

        function testEnablingRemovedFromDisabledList(tc)
        %testEnablingRemovedFromDisabledList Calling enable removes an id from the disabled list.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = tc.applyFixture(TemporaryFolderFixture);

            sidecarFolder = fullfile(F.Folder, 'plugins');
            mkdir(sidecarFolder)
            tc.writeSidecar(sidecarFolder, 'test.Toggle', 'Toggle Plugin');

            reg = nansen.unittest.plugin.fixture.TestRegistry(sidecarFolder, F.Folder);
            reg.disable('test.Toggle');
            tc.verifyFalse(reg.isEnabled('test.Toggle'))

            reg.enable('test.Toggle');
            tc.verifyTrue(reg.isEnabled('test.Toggle'), ...
                'Plugin must be enabled after calling enable.')
        end

        function testDisabledPluginExcludedFromList(tc)
        %testDisabledPluginExcludedFromList Disabled plugins do not appear in list().
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = tc.applyFixture(TemporaryFolderFixture);

            sidecarFolder = fullfile(F.Folder, 'plugins');
            mkdir(sidecarFolder)
            tc.writeSidecar(sidecarFolder, 'test.Hidden', 'Hidden Plugin');

            reg = nansen.unittest.plugin.fixture.TestRegistry(sidecarFolder, F.Folder);
            reg.disable('test.Hidden');

            specs = reg.list();
            tc.verifyEmpty(specs, 'Disabled plugin must not appear in list().')

            allSpecs = reg.list('IncludeDisabled', true);
            tc.verifyNumElements(allSpecs, 1, ...
                'Disabled plugin must appear in list(IncludeDisabled=true).')
        end

        function testDisabledIsolatedToProject(tc)
        %testDisabledIsolatedToProject Disabling in project A does not affect project B.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = tc.applyFixture(TemporaryFolderFixture);

            sidecarFolder = fullfile(F.Folder, 'plugins');
            mkdir(sidecarFolder)
            tc.writeSidecar(sidecarFolder, 'test.Isolated', 'Isolated Plugin');

            projA = fullfile(F.Folder, 'projectA');
            projB = fullfile(F.Folder, 'projectB');
            mkdir(projA); mkdir(projB)

            regA = nansen.unittest.plugin.fixture.TestRegistry(sidecarFolder, projA);
            regA.disable('test.Isolated');

            regB = nansen.unittest.plugin.fixture.TestRegistry(sidecarFolder, projB);
            tc.verifyTrue(regB.isEnabled('test.Isolated'), ...
                'Disabling in project A must not affect project B.')
        end
    end

    % ------------------------------------------------------------------ %
    % Events
    % ------------------------------------------------------------------ %
    methods (Test, TestTags = {'Phase1', 'Events'})

        function testRefreshFiresRegistryRefreshedEvent(tc)
        %testRefreshFiresRegistryRefreshedEvent PluginRegistryRefreshed fires on refresh.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = tc.applyFixture(TemporaryFolderFixture);

            reg = nansen.unittest.plugin.fixture.TestRegistry(F.Folder, F.Folder);

            counter = nansen.unittest.plugin.fixture.EventCounter();
            addlistener(reg, 'PluginRegistryRefreshed', @counter.increment);

            reg.refresh();
            tc.verifyEqual(counter.Count, 1, ...
                'PluginRegistryRefreshed must fire once per refresh call.')
        end

        function testPluginAddedEventFiresForNewPlugin(tc)
        %testPluginAddedEventFiresForNewPlugin PluginAdded fires when a new plugin appears on refresh.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = tc.applyFixture(TemporaryFolderFixture);

            sidecarFolder = fullfile(F.Folder, 'plugins');
            mkdir(sidecarFolder)

            reg = nansen.unittest.plugin.fixture.TestRegistry(sidecarFolder, F.Folder);
            reg.refresh();  % first refresh: empty

            counter = nansen.unittest.plugin.fixture.EventCounter();
            addlistener(reg, 'PluginAdded', @counter.increment);

            tc.writeSidecar(sidecarFolder, 'test.New', 'New Plugin');
            reg.clear();
            reg.refresh();

            tc.verifyGreaterThan(counter.Count, 0, ...
                'PluginAdded must fire when a new plugin appears after refresh.')
        end

        function testPluginRemovedEventFiresWhenPluginDisappears(tc)
        %testPluginRemovedEventFiresWhenPluginDisappears PluginRemoved fires when a plugin disappears on refresh.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = tc.applyFixture(TemporaryFolderFixture);

            sidecarFolder = fullfile(F.Folder, 'plugins');
            mkdir(sidecarFolder)
            sidecarPath = tc.writeSidecar(sidecarFolder, 'test.Removable', 'Removable Plugin');

            reg = nansen.unittest.plugin.fixture.TestRegistry(sidecarFolder, F.Folder);
            reg.refresh();

            counter = nansen.unittest.plugin.fixture.EventCounter();
            addlistener(reg, 'PluginRemoved', @counter.increment);

            delete(sidecarPath);
            reg.refresh();

            tc.verifyGreaterThan(counter.Count, 0, ...
                'PluginRemoved must fire when a plugin disappears after refresh.')
        end
    end

    % ------------------------------------------------------------------ %
    % Mtime cache
    % ------------------------------------------------------------------ %
    methods (Test, TestTags = {'Phase1', 'MtimeCache'})

        function testMtimeCachePreventsReparsing(tc)
        %testMtimeCachePreventsReparsing Refreshing without file changes does not re-parse sidecars.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = tc.applyFixture(TemporaryFolderFixture);

            sidecarFolder = fullfile(F.Folder, 'plugins');
            mkdir(sidecarFolder)
            tc.writeSidecar(sidecarFolder, 'test.Cached', 'Cached Plugin');

            reg = nansen.unittest.plugin.fixture.TestRegistry(sidecarFolder, F.Folder);
            reg.list();  % first load: parses the sidecar
            parseAfterFirst = reg.ParseCount;

            reg.refresh();  % second refresh: file unchanged, should use cache
            tc.verifyEqual(reg.ParseCount, parseAfterFirst, ...
                'Sidecar must not be re-parsed when mtime is unchanged.')
        end

        function testMtimeCacheReparseOnFileChange(tc)
        %testMtimeCacheReparseOnFileChange Refreshing after a file change triggers re-parsing.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = tc.applyFixture(TemporaryFolderFixture);

            sidecarFolder = fullfile(F.Folder, 'plugins');
            mkdir(sidecarFolder)
            tc.writeSidecar(sidecarFolder, 'test.Mutable', 'Original Name');

            reg = nansen.unittest.plugin.fixture.TestRegistry(sidecarFolder, F.Folder);
            reg.list();
            parseAfterFirst = reg.ParseCount;

            % Wait a moment and overwrite the sidecar to change its mtime.
            % macOS HFS+ mtime has 1-second granularity; wait long enough to guarantee a change.
            pause(1.1)
            tc.writeSidecar(sidecarFolder, 'test.Mutable', 'Updated Name');
            reg.refresh();

            tc.verifyGreaterThan(reg.ParseCount, parseAfterFirst, ...
                'Sidecar must be re-parsed when mtime changes.')

            spec = reg.resolve("test.Mutable");
            tc.verifyEqual(spec.DisplayName, "Updated Name", ...
                'Spec must reflect the updated sidecar content.')
        end
    end

    % ------------------------------------------------------------------ %
    % resolve / findByDisplayName semantics
    % ------------------------------------------------------------------ %
    methods (Test, TestTags = {'Phase1', 'Resolve'})

        function testResolveFindsByIdOnly(tc)
        %testResolveFindsByIdOnly resolve() matches by Id and errors on DisplayName input.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = tc.applyFixture(TemporaryFolderFixture);

            sidecarFolder = fullfile(F.Folder, 'plugins');
            mkdir(sidecarFolder)
            tc.writeSidecar(sidecarFolder, 'test.IdOnly', 'Human Readable Name');

            reg = nansen.unittest.plugin.fixture.TestRegistry(sidecarFolder, F.Folder);

            spec = reg.resolve("test.IdOnly");
            tc.verifyEqual(spec.Id, "test.IdOnly")

            % Resolving by display name must NOT silently succeed.
            tc.verifyError(@() reg.resolve("Human Readable Name"), ...
                'nansen:plugin:Registry:PluginNotFound', ...
                'resolve() must not match by display name.')
        end

        function testFindByDisplayNameReturnsAllMatches(tc)
        %testFindByDisplayNameReturnsAllMatches findByDisplayName returns all specs with that name.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = tc.applyFixture(TemporaryFolderFixture);

            % Two subdirectories, same display name, different ids.
            subdirA = fullfile(F.Folder, 'a');
            subdirB = fullfile(F.Folder, 'b');
            mkdir(subdirA); mkdir(subdirB)
            tc.writeSidecar(subdirA, 'test.A', 'Shared Name');
            tc.writeSidecar(subdirB, 'test.B', 'Shared Name');

            reg = nansen.unittest.plugin.fixture.TestRegistry(F.Folder, F.Folder);
            specs = reg.findByDisplayName("Shared Name");

            tc.verifyNumElements(specs, 2, ...
                'findByDisplayName must return all specs with matching DisplayName.')
        end
    end
end
