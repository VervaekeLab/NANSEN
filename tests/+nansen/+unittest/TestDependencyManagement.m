classdef TestDependencyManagement < matlab.unittest.TestCase
%TestDependencyManagement Tests for the dependency manifest system.
%
%   Tests the real-world workflows: reading manifests, resolving
%   dependencies across scopes, checking installation status, and
%   verifying schema/manifest consistency.

    properties (Constant, Access = private)
        CoreManifestPath = fullfile(nansen.toolboxdir, 'dependencies.nansen.json')
        SchemaPath = fullfile(nansen.toolboxdir, '..', 'schemas', 'dependencies.nansen.json')
    end

    % --- Manifest reading ---

    methods (Test)
        function readCoreManifest(testCase)
        %readCoreManifest Verify the core manifest loads and has expected structure.
            testCase.assumeTrue(isfile(testCase.CoreManifestPath), ...
                'Core manifest file not found')

            dependencies = nansen.internal.dependencies.readManifest( ...
                testCase.CoreManifestPath);

            testCase.verifyNotEmpty(dependencies, ...
                'Core manifest should contain at least one dependency')
            testCase.verifyTrue(isstruct(dependencies), ...
                'readManifest should return a struct array')

            expectedFields = ["Name", "DependencyType", "Scope", "ScopeId", ...
                "RequirementLevel", "Source", "DocsSource", "Description", ...
                "Reason", "WorkflowNotes", "SetupHook", "StartupHook", ...
                "InstallCheck", "VersionConstraint"];
            actualFields = string(fieldnames(dependencies));
            for i = 1:numel(expectedFields)
                testCase.verifyTrue(ismember(expectedFields(i), actualFields), ...
                    sprintf('Missing field: %s', expectedFields(i)))
            end
        end

        function coreManifestScopeInheritance(testCase)
        %coreManifestScopeInheritance Verify scope inherits from manifest level.
            testCase.assumeTrue(isfile(testCase.CoreManifestPath))

            dependencies = nansen.internal.dependencies.readManifest( ...
                testCase.CoreManifestPath);

            for i = 1:numel(dependencies)
                testCase.verifyEqual(string(dependencies(i).Scope), "core", ...
                    sprintf('Dependency "%s" should inherit scope "core"', ...
                    dependencies(i).Name))
            end
        end

        function communityToolboxesHaveSource(testCase)
        %communityToolboxesHaveSource Every community toolbox must have a source URI.
            testCase.assumeTrue(isfile(testCase.CoreManifestPath))

            dependencies = nansen.internal.dependencies.readManifest( ...
                testCase.CoreManifestPath);

            for i = 1:numel(dependencies)
                if dependencies(i).DependencyType == "community-toolbox"
                    testCase.verifyTrue( ...
                        strlength(dependencies(i).Source) > 0, ...
                        sprintf('Community toolbox "%s" has no source', ...
                        dependencies(i).Name))
                end
            end
        end

        function mathworksProductsHaveNoSource(testCase)
        %mathworksProductsHaveNoSource MathWorks products should not have source URIs.
            testCase.assumeTrue(isfile(testCase.CoreManifestPath))

            dependencies = nansen.internal.dependencies.readManifest( ...
                testCase.CoreManifestPath);

            for i = 1:numel(dependencies)
                if dependencies(i).DependencyType == "mathworks-product"
                    testCase.verifyEqual(dependencies(i).Source, "", ...
                        sprintf('MathWorks product "%s" should not have a source URI', ...
                        dependencies(i).Name))
                end
            end
        end
    end

    % --- Module manifest with scope overrides ---

    methods (Test)
        function readModuleManifestWithWorkflowScopes(testCase)
        %readModuleManifestWithWorkflowScopes Verify per-entry scope overrides.
            moduleManifestPath = fullfile(nansen.toolboxdir, 'modules', ...
                '+nansen', '+module', '+ophys', '+twophoton', ...
                'dependencies.nansen.json');
            testCase.assumeTrue(isfile(moduleManifestPath), ...
                'Two-photon module manifest not found')

            dependencies = nansen.internal.dependencies.readManifest( ...
                moduleManifestPath);

            % Find a workflow-scoped entry (e.g. EXTRACT)
            names = string({dependencies.Name});
            extractIdx = find(names == "EXTRACT", 1);
            testCase.assumeNotEmpty(extractIdx, 'EXTRACT dependency not found')

            testCase.verifyEqual(string(dependencies(extractIdx).Scope), "workflow")
            testCase.verifyTrue(contains(dependencies(extractIdx).ScopeId, "extract"))

            % Entries without scope override should inherit "module"
            iptIdx = find(names == "Image Processing Toolbox", 1);
            testCase.assumeNotEmpty(iptIdx)
            testCase.verifyEqual(string(dependencies(iptIdx).Scope), "module")
        end
    end

    % --- Resolve requirements ---

    methods (Test)
        function resolveCoreOnly(testCase)
        %resolveCoreOnly Resolve core dependencies and verify filtering works.
            resolved = nansen.internal.dependencies.resolveRequirements();

            testCase.verifyNotEmpty(resolved, ...
                'Resolving core dependencies should return results')

            % All should be core scope
            scopes = string({resolved.Scope});
            testCase.verifyTrue(all(scopes == "core"), ...
                'Core-only resolution should only contain core-scoped entries')
        end

        function filterByDependencyType(testCase)
        %filterByDependencyType Verify filtering by mathworks-product.
            resolved = nansen.internal.dependencies.resolveRequirements( ...
                "DependencyTypes", "mathworks-product");

            types = string({resolved.DependencyType});
            testCase.verifyTrue(all(types == "mathworks-product"), ...
                'All results should be mathworks-product')
        end

        function filterByRequirementLevel(testCase)
        %filterByRequirementLevel Verify filtering by required level.
            resolved = nansen.internal.dependencies.resolveRequirements( ...
                "RequirementLevels", "required");

            levels = string({resolved.RequirementLevel});
            testCase.verifyTrue(all(levels == "required"), ...
                'All results should be required')
        end

        function resolvedHasIsInstalledField(testCase)
        %resolvedHasIsInstalledField Verify installation status is annotated.
            resolved = nansen.internal.dependencies.resolveRequirements();
            testCase.assumeNotEmpty(resolved)

            testCase.verifyTrue(isfield(resolved, 'IsInstalled'), ...
                'Resolved requirements should have IsInstalled field')
            testCase.verifyTrue(islogical([resolved.IsInstalled]), ...
                'IsInstalled should be logical')
        end

        function missingOnlyFilter(testCase)
        %missingOnlyFilter Verify MissingOnly returns only uninstalled deps.
            resolved = nansen.internal.dependencies.resolveRequirements( ...
                "MissingOnly", true);

            if isempty(resolved); return; end

            installedFlags = [resolved.IsInstalled];
            testCase.verifyTrue(~any(installedFlags), ...
                'MissingOnly should only return uninstalled dependencies')
        end

        function moduleResolutionIncludesWorkflowDependencies(testCase)
        %moduleResolutionIncludesWorkflowDependencies Module install includes workflows.
            moduleManifestPath = fullfile(nansen.toolboxdir, '..', 'tests', ...
                '+nansen', '+fixture', 'manifests', ...
                'test_module_dependencies.nansen.json');

            resolved = nansen.internal.dependencies.resolveRequirements( ...
                "IncludeCore", false, ...
                "SelectedModules", "test.module.alpha", ...
                "ManifestPaths", moduleManifestPath);

            dependencyNames = string({resolved.Name});
            testCase.verifyTrue(ismember("TestWorkflowTool", dependencyNames), ...
                'Workflow dependencies should be included by default for selected modules')
        end

        function explicitWorkflowSelectionNarrowsWorkflowDependencies(testCase)
        %explicitWorkflowSelectionNarrowsWorkflowDependencies Specific workflow selection still works.
            moduleManifestPath = fullfile(nansen.toolboxdir, '..', 'tests', ...
                '+nansen', '+fixture', 'manifests', ...
                'test_module_dependencies.nansen.json');

            resolved = nansen.internal.dependencies.resolveRequirements( ...
                "IncludeCore", false, ...
                "SelectedModules", "test.module.alpha", ...
                "SelectedWorkflows", "test.module.alpha.workflow.missing", ...
                "ManifestPaths", moduleManifestPath);

            dependencyNames = string({resolved.Name});
            testCase.verifyFalse(ismember("TestWorkflowTool", dependencyNames), ...
                'Workflow dependencies should still respect explicit workflow selection')
        end

        function installAllWorkflowsCanBeDisabled(testCase)
        %installAllWorkflowsCanBeDisabled Caller can request module-only deps.
            moduleManifestPath = fullfile(nansen.toolboxdir, '..', 'tests', ...
                '+nansen', '+fixture', 'manifests', ...
                'test_module_dependencies.nansen.json');

            resolved = nansen.internal.dependencies.resolveRequirements( ...
                "IncludeCore", false, ...
                "SelectedModules", "test.module.alpha", ...
                "InstallAllWorkflows", false, ...
                "ManifestPaths", moduleManifestPath);

            dependencyNames = string({resolved.Name});
            testCase.verifyFalse(ismember("TestWorkflowTool", dependencyNames), ...
                'Workflow dependencies should be excluded when InstallAllWorkflows=false')
        end

        function selectedWorkflowsOverrideInstallAllWorkflows(testCase)
        %selectedWorkflowsOverrideInstallAllWorkflows Explicit workflows win.
            moduleManifestPath = fullfile(nansen.toolboxdir, '..', 'tests', ...
                '+nansen', '+fixture', 'manifests', ...
                'test_module_dependencies.nansen.json');

            resolved = nansen.internal.dependencies.resolveRequirements( ...
                "IncludeCore", false, ...
                "SelectedModules", "test.module.alpha", ...
                "SelectedWorkflows", "test.module.alpha.workflow.beta", ...
                "InstallAllWorkflows", false, ...
                "ManifestPaths", moduleManifestPath);

            dependencyNames = string({resolved.Name});
            testCase.verifyTrue(ismember("TestWorkflowTool", dependencyNames), ...
                'SelectedWorkflows should override InstallAllWorkflows=false')
        end
    end

    % --- Check installation status ---

    methods (Test)
        function imageProcessingToolboxDetection(testCase)
        %imageProcessingToolboxDetection Verify MathWorks product detection works.
            entry = struct( ...
                'Name', "Image Processing Toolbox", ...
                'DependencyType', "mathworks-product", ...
                'InstallCheck', "");

            result = nansen.internal.dependencies.checkInstallationStatus(entry);

            % If IPT is installed, IsInstalled should be true
            versionInfo = ver();
            expectedInstalled = any(string({versionInfo.Name}) == "Image Processing Toolbox");
            testCase.verifyEqual(result.IsInstalled, expectedInstalled)
        end

        function communityToolboxCheckDetection(testCase)
        %communityToolboxCheckDetection Verify InstallCheck-based detection.
            % Test with a function we know exists (part of MATLAB itself)
            entry = struct( ...
                'Name', "Test Check", ...
                'DependencyType', "community-toolbox", ...
                'InstallCheck', "nansen");

            result = nansen.internal.dependencies.checkInstallationStatus(entry);
            testCase.verifyTrue(result.IsInstalled, ...
                '"nansen" should always be found via exist()')
        end

        function missingCheckReportsNotInstalled(testCase)
        %missingCheckReportsNotInstalled Empty InstallCheck → not installed.
            entry = struct( ...
                'Name', "No Check", ...
                'DependencyType', "community-toolbox", ...
                'InstallCheck', "");

            result = nansen.internal.dependencies.checkInstallationStatus(entry);
            testCase.verifyFalse(result.IsInstalled, ...
                'Empty InstallCheck should report not installed')
        end
    end

    % --- Schema consistency ---

    methods (Test)
        function schemaAndManifestConsistency(testCase)
        %schemaAndManifestConsistency Verify manifest validates against schema.
            testCase.assumeTrue(isfile(testCase.SchemaPath), ...
                'Schema file not found')
            testCase.assumeTrue(isfile(testCase.CoreManifestPath), ...
                'Core manifest not found')

            schemaData = jsondecode(fileread(testCase.SchemaPath));
            manifestData = jsondecode(fileread(testCase.CoreManifestPath));

            % Check that manifest has all required top-level fields
            % (jsondecode mangles leading _ to x_, so _schema_id → x_schema_id)
            manifestFields = string(fieldnames(manifestData));
            testCase.verifyTrue(ismember("x_schema_id", manifestFields))
            testCase.verifyTrue(ismember("x_schema_version", manifestFields))
            testCase.verifyTrue(ismember("x_type", manifestFields))
            testCase.verifyTrue(ismember("scope", manifestFields))
            testCase.verifyTrue(ismember("scopeId", manifestFields))
            testCase.verifyTrue(ismember("dependencies", manifestFields))

            % Verify _schema_id matches schema $id
            testCase.verifyEqual( ...
                string(manifestData.x_schema_id), ...
                string(schemaData.x_id), ...
                'Manifest _schema_id should match schema $id')
        end

        function camelToPascalMappingRoundTrip(testCase)
        %camelToPascalMappingRoundTrip Verify all schema fields map correctly.
            testCase.assumeTrue(isfile(testCase.CoreManifestPath))

            dependencies = nansen.internal.dependencies.readManifest( ...
                testCase.CoreManifestPath);

            % These PascalCase fields should exist from camelCase JSON keys
            expectedPascalFields = ["Name", "DependencyType", "RequirementLevel", ...
                "Source", "Description", "Reason", "SetupHook"];
            actualFields = string(fieldnames(dependencies));

            for i = 1:numel(expectedPascalFields)
                testCase.verifyTrue(ismember(expectedPascalFields(i), actualFields), ...
                    sprintf('camelToPascal should produce field: %s', ...
                    expectedPascalFields(i)))
            end
        end
    end
end
