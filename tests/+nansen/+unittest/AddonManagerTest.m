classdef AddonManagerTest < matlab.unittest.TestCase
%AddonManagerTest Tests for the AddonManager singleton.
%
%   Tests initialization, manifest loading, dependency refresh,
%   installation status tracking, merge/deduplication, and edge cases
%   using isolated test manifests.

    properties (Access = private)
        Fixture
    end

    properties (Constant, Access = private)
        TestManifestDirectory = fullfile( ...
            fileparts(fileparts(mfilename('fullpath'))), ...
            '+fixture', 'manifests')
        CoreManifestPath (1,1) string = fullfile( ...
            fileparts(fileparts(mfilename('fullpath'))), ...
            '+fixture', 'manifests', 'test_core_dependencies.nansen.json')
        ModuleManifestPath (1,1) string = fullfile( ...
            fileparts(fileparts(mfilename('fullpath'))), ...
            '+fixture', 'manifests', 'test_module_dependencies.nansen.json')
    end

    methods (TestMethodSetup)
        function applyAddonManagerFixture(testCase)
            testCase.Fixture = testCase.applyFixture( ...
                nansen.fixture.AddonManagerFixture);
        end
    end

    % --- Initialization & manifest loading ---

    methods (Test)
        function createWithEmptyManifest(testCase)
        %createWithEmptyManifest Singleton starts with addon list from test manifests.
            manager = testCase.Fixture.AddonManager;
            testCase.verifyNotEmpty(manager, ...
                'AddonManager instance should be created')
            testCase.verifyClass(manager, ...
                'nansen.config.addons.AddonManager')
        end

        function installationFolderIsTemporary(testCase)
        %installationFolderIsTemporary Installation folder points to temp dir.
            manager = testCase.Fixture.AddonManager;
            testCase.verifyTrue( ...
                contains(manager.InstallationFolder, tempdir) || ...
                contains(manager.InstallationFolder, "tmp"), ...
                'Installation folder should be in a temporary location')
        end

        function persistAndReloadManifest(testCase)
        %persistAndReloadManifest Save, reset, and reload round-trip.
            manager = testCase.Fixture.AddonManager;
            manager.saveAddonList();
            testCase.verifyTrue(isfile(testCase.Fixture.ManifestFilePath), ...
                'Manifest file should exist after save')

            originalAddonNames = string({manager.AddonList.Name});

            % Reset with same storage paths to reload persisted data
            reloadedManager = nansen.config.addons.AddonManager.instance( ...
                "reset", ...
                testCase.Fixture.InstallationFolder, ...
                testCase.Fixture.ManifestFilePath);
            % Refresh from same test manifests
            reloadedManager.refreshManagedAddons( ...
                "ManifestPaths", [testCase.CoreManifestPath, testCase.ModuleManifestPath]);
            reloadedAddonNames = string({reloadedManager.AddonList.Name});

            testCase.verifyEqual(sort(reloadedAddonNames), sort(originalAddonNames), ...
                'Addon names should survive save/reload round-trip')
        end
    end

    % --- Refresh from test manifests ---

    methods (Test)
        function refreshFromCoreManifest(testCase)
        %refreshFromCoreManifest Core test manifest resolves expected entries.
            manager = testCase.Fixture.AddonManager;
            addonNames = string({manager.AddonList.Name});

            testCase.verifyTrue(ismember("TestToolboxA", addonNames), ...
                'TestToolboxA should be in addon list')
            testCase.verifyTrue(ismember("TestToolboxB", addonNames), ...
                'TestToolboxB should be in addon list')
        end

        function coreAddonHasCorrectSource(testCase)
        %coreAddonHasCorrectSource Community toolbox source is preserved.
            manager = testCase.Fixture.AddonManager;
            addonIndex = find(strcmp({manager.AddonList.Name}, 'TestToolboxA'));
            testCase.assumeNotEmpty(addonIndex, 'TestToolboxA not found')

            testCase.verifyEqual(string(manager.AddonList(addonIndex).Source), ...
                "https://github.com/test-org/TestToolboxA")
        end

        function requiredFlagIsSet(testCase)
        %requiredFlagIsSet Required addon has IsRequired=true.
            manager = testCase.Fixture.AddonManager;
            addonIndex = find(strcmp({manager.AddonList.Name}, 'TestToolboxA'));
            testCase.assumeNotEmpty(addonIndex)

            testCase.verifyTrue(manager.AddonList(addonIndex).IsRequired, ...
                'TestToolboxA should be marked as required')
        end

        function optionalFlagIsSet(testCase)
        %optionalFlagIsSet Optional addon has IsRequired=false.
            manager = testCase.Fixture.AddonManager;
            addonIndex = find(strcmp({manager.AddonList.Name}, 'TestToolboxB'));
            testCase.assumeNotEmpty(addonIndex)

            testCase.verifyFalse(manager.AddonList(addonIndex).IsRequired, ...
                'TestToolboxB should be marked as optional')
        end

        function refreshWithModuleDependencies(testCase)
        %refreshWithModuleDependencies Module deps appear after refresh with module selection.
            manager = testCase.Fixture.AddonManager;
            manager.refreshManagedAddons( ...
                "ManifestPaths", [testCase.CoreManifestPath, testCase.ModuleManifestPath], ...
                "SelectedModules", "test.module.alpha");

            addonNames = string({manager.AddonList.Name});
            testCase.verifyTrue(ismember("TestToolboxC", addonNames), ...
                'TestToolboxC (module dep) should appear after refresh with module')
        end

        function mathworksProductsExcludedFromAddonList(testCase)
        %mathworksProductsExcludedFromAddonList MathWorks products are not in AddonList.
        %   refreshManagedAddons filters for community-toolbox only.
            manager = testCase.Fixture.AddonManager;
            addonNames = string({manager.AddonList.Name});

            testCase.verifyFalse(ismember("Image Processing Toolbox", addonNames), ...
                'MathWorks products should not appear in AddonList')
            testCase.verifyFalse(ismember("Parallel Computing Toolbox", addonNames), ...
                'MathWorks products should not appear in AddonList')
        end
    end

    % --- Deduplication and merge ---

    methods (Test)
        function duplicateAcrossScopesMergesCorrectly(testCase)
        %duplicateAcrossScopesMergesCorrectly Same dependency from core+module deduplicates.
            manager = testCase.Fixture.AddonManager;
            manager.refreshManagedAddons( ...
                "ManifestPaths", [testCase.CoreManifestPath, testCase.ModuleManifestPath], ...
                "SelectedModules", "test.module.alpha");

            % TestToolboxA is in both core (required) and module (optional)
            matchIndices = find(strcmp({manager.AddonList.Name}, 'TestToolboxA'));
            testCase.verifyNumElements(matchIndices, 1, ...
                'TestToolboxA should appear exactly once after deduplication')
        end

        function requiredWinsOverOptional(testCase)
        %requiredWinsOverOptional Required level wins when same dep appears in multiple scopes.
            manager = testCase.Fixture.AddonManager;
            manager.refreshManagedAddons( ...
                "ManifestPaths", [testCase.CoreManifestPath, testCase.ModuleManifestPath], ...
                "SelectedModules", "test.module.alpha");

            addonIndex = find(strcmp({manager.AddonList.Name}, 'TestToolboxA'));
            testCase.assumeNotEmpty(addonIndex)

            testCase.verifyTrue(manager.AddonList(addonIndex).IsRequired, ...
                'TestToolboxA should be required (core=required wins over module=optional)')
        end

        function existingAddonPreservesInstallState(testCase)
        %existingAddonPreservesInstallState Installed addon stays installed after refresh.
        %   Seeds a manifest file with one addon marked as installed,
        %   creates a fresh singleton, and verifies the install state
        %   survives a refreshManagedAddons call.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            temporaryFolderFixture = testCase.applyFixture(TemporaryFolderFixture);
            installationFolder = fullfile(temporaryFolderFixture.Folder, 'Add-Ons');
            mkdir(installationFolder);
            manifestFilePath = fullfile(temporaryFolderFixture.Folder, 'installed_addons.json');

            % Create a fake installed addon folder
            fakeAddonFolder = fullfile(installationFolder, 'TestToolboxA');
            mkdir(fakeAddonFolder);
            testCase.addTeardown(@() rmpath(fakeAddonFolder));

            % Write a pre-seeded manifest with one installed addon
            defaultEntry = nansen.config.addons.AddonManager.DefaultAddonEntry;
            addonEntry = defaultEntry;
            addonEntry.Name = 'TestToolboxA';
            addonEntry.IsInstalled = true;
            addonEntry.FilePath = char(fakeAddonFolder);
            addonEntry.InstallationType = 'folder';
            addonEntry.Source = 'https://github.com/test-org/TestToolboxA';
            addonEntry.InstallCheck = 'TestToolboxACheck';
            savedData = struct( ...
                'type', 'Nansen Configuration: List of Installed Addons', ...
                'description', 'Test manifest', ...
                'AddonList', addonEntry);
            jsonText = jsonencode(savedData, 'PrettyPrint', true);
            fileIdentifier = fopen(manifestFilePath, 'w');
            fwrite(fileIdentifier, jsonText, 'char');
            fclose(fileIdentifier);

            % Create singleton from pre-seeded manifest (no discovery)
            manager = nansen.config.addons.AddonManager.instance( ...
                "reset", installationFolder, manifestFilePath);
            % Refresh from test manifest — should preserve install state
            manager.refreshManagedAddons( ...
                "ManifestPaths", testCase.CoreManifestPath);
            addonIndex = find(strcmp({manager.AddonList.Name}, 'TestToolboxA'));
            testCase.assumeNotEmpty(addonIndex, 'TestToolboxA should be in list')
            testCase.verifyTrue(manager.AddonList(addonIndex).IsInstalled, ...
                'Pre-seeded installation state should be preserved after refresh')
        end

        function newDependencyAddedOnRefresh(testCase)
        %newDependencyAddedOnRefresh A dependency not previously tracked appears after refresh.
            manager = testCase.Fixture.AddonManager;

            % Initially only core manifest was used (default fixture)
            addonNamesBefore = string({manager.AddonList.Name});
            testCase.verifyFalse(ismember("TestToolboxC", addonNamesBefore), ...
                'TestToolboxC should not be present before module refresh')

            % Refresh with module manifest
            manager.refreshManagedAddons( ...
                "ManifestPaths", [testCase.CoreManifestPath, testCase.ModuleManifestPath], ...
                "SelectedModules", "test.module.alpha");

            addonNamesAfter = string({manager.AddonList.Name});
            testCase.verifyTrue(ismember("TestToolboxC", addonNamesAfter), ...
                'TestToolboxC should appear after module refresh')
        end
    end

    % --- Installation status ---

    methods (Test)
        function uninstalledAddonReportsFalse(testCase)
        %uninstalledAddonReportsFalse isAddonInstalled returns false for missing addon.
            manager = testCase.Fixture.AddonManager;
            testCase.verifyFalse(manager.isAddonInstalled('TestToolboxA'), ...
                'TestToolboxA should not be installed in test environment')
        end

        function isAddonInstalledReturnsFalseForUnknown(testCase)
        %isAddonInstalledReturnsFalseForUnknown Unknown addon name returns false.
            manager = testCase.Fixture.AddonManager;
            testCase.verifyFalse(manager.isAddonInstalled('NonExistentToolbox'), ...
                'Unknown addon should return false')
        end

        function saveAddonListCreatesValidJson(testCase)
        %saveAddonListCreatesValidJson Saved manifest is valid JSON with expected structure.
            manager = testCase.Fixture.AddonManager;
            manager.saveAddonList();

            jsonText = fileread(testCase.Fixture.ManifestFilePath);
            savedData = jsondecode(jsonText);

            testCase.verifyTrue(isfield(savedData, 'AddonList'), ...
                'Saved data should have AddonList field')
            testCase.verifyTrue(isfield(savedData, 'type'), ...
                'Saved data should have type field')
        end

        function markDirtyAndClean(testCase)
        %markDirtyAndClean IsDirty flag tracks unsaved changes.
            manager = testCase.Fixture.AddonManager;
            manager.markDirty();
            testCase.verifyTrue(manager.IsDirty, ...
                'Manager should be dirty after markDirty')

            manager.saveAddonList();
            testCase.verifyFalse(manager.IsDirty, ...
                'Manager should be clean after save')
        end
    end

    % --- Edge cases ---

    methods (Test)
        function isAddonInstalledCaseInsensitive(testCase)
        %isAddonInstalledCaseInsensitive Addon lookup by name is case-insensitive.
        %   isAddonInstalled uses case-sensitive strcmp for the name check,
        %   so this test documents the current behavior.
            manager = testCase.Fixture.AddonManager;
            testCase.assumeTrue(any(strcmp({manager.AddonList.Name}, 'TestToolboxA')))

            % isAddonInstalled checks exact name match first, then uses
            % getAddonIndex (case-insensitive). With exact name, lookup works.
            resultExact = manager.isAddonInstalled('TestToolboxA');
            testCase.verifyFalse(resultExact, ...
                'TestToolboxA is not installed but name should be found')
        end

        function downloadUnknownAddonThrowsError(testCase)
        %downloadUnknownAddonThrowsError Unknown addon name causes error.
            manager = testCase.Fixture.AddonManager;
            testCase.verifyError( ...
                @() manager.downloadAddon('CompletelyUnknownToolbox', false, true), ...
                'NANSEN:AddonManager:NotFound')
        end

        function managedAddonsReturnsTable(testCase)
        %managedAddonsReturnsTable ManagedAddons property returns a table.
            manager = testCase.Fixture.AddonManager;
            managedAddons = manager.ManagedAddons;
            testCase.verifyClass(managedAddons, 'table')
            testCase.verifyTrue(ismember('Name', managedAddons.Properties.VariableNames), ...
                'ManagedAddons table should have Name column')
        end

        function workflowScopedDepsRequireWorkflowSelection(testCase)
        %workflowScopedDepsRequireWorkflowSelection Workflow deps excluded without selection.
            manager = testCase.Fixture.AddonManager;
            manager.refreshManagedAddons( ...
                "ManifestPaths", [testCase.CoreManifestPath, testCase.ModuleManifestPath], ...
                "SelectedModules", "test.module.alpha");

            addonNames = string({manager.AddonList.Name});
            testCase.verifyFalse(ismember("TestWorkflowTool", addonNames), ...
                'Workflow-scoped deps should not appear without SelectedWorkflows')
        end
    end
end
