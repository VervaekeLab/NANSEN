classdef DependencyLookupTest < matlab.unittest.TestCase
%DependencyLookupTest Tests for finding modules and dependencies by name.
%
%   Covers listModules, resolveModuleNames, resolveDependencyIds and
%   assertInstalled in nansen.internal.dependencies, and the checks that
%   nansen_install makes before it downloads anything. The tests create
%   fixture modules in a temporary folder and add it to the MATLAB path.

    properties (Constant, Access = private)
        AlphaPackageName = "nansen.module.fixturecategory.fixturealpha"
    end

    properties (Access = private)
        % ModuleRootFolder - Temporary folder that holds the fixture modules
        ModuleRootFolder (1,1) string
    end

    methods (TestClassSetup)
        function addFixtureModulesToPath(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture

            temporaryFolderFixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.ModuleRootFolder = temporaryFolderFixture.Folder;

            createFixtureModule(testCase.ModuleRootFolder, "fixturealpha", ...
                "Fixture Alpha", createAlphaDependencies())
            createFixtureModule(testCase.ModuleRootFolder, "fixturebeta", ...
                "Fixture Beta", createBetaDependencies())
            testCase.applyFixture(PathFixture(testCase.ModuleRootFolder));
        end
    end

    % --- listModules ---

    methods (Test)
        function listModulesFindsModuleOnPath(testCase)
            modules = nansen.internal.dependencies.listModules();

            alphaModule = modules([modules.PackageName] == testCase.AlphaPackageName);
            testCase.assertNumElements(alphaModule, 1)
            testCase.verifyEqual(alphaModule.Name, "Fixture Alpha")
            testCase.verifyEqual(alphaModule.ShortName, "fixturealpha")
            testCase.verifyEqual(alphaModule.ManifestPath, string(fullfile( ...
                testCase.ModuleRootFolder, "+nansen", "+module", ...
                "+fixturecategory", "+fixturealpha", "dependencies.nansen.json")))
        end

        function listModulesSkipsModuleTemplate(testCase)
        %listModulesSkipsModuleTemplate The template for new modules is not a module.
            modules = nansen.internal.dependencies.listModules();
            testCase.verifyFalse(any([modules.PackageName] == "nansen.module.category.name"))
        end
    end

    % --- resolveModuleNames ---

    methods (Test)
        function resolveModuleNamesAcceptsEachNameForm(testCase)
            moduleNames = [testCase.AlphaPackageName, "Fixture Alpha", ...
                "fixture alpha", "fixturealpha", "FIXTUREALPHA"];

            packageNames = nansen.internal.dependencies.resolveModuleNames(moduleNames);

            testCase.verifyEqual(packageNames, ...
                repmat(testCase.AlphaPackageName, 1, numel(moduleNames)))
        end

        function resolveModuleNamesListsModulesForUnknownName(testCase)
            exception = captureException(@() ...
                nansen.internal.dependencies.resolveModuleNames("fixture-no-such-module"));

            testCase.assertNotEmpty(exception, 'Expected an error for an unknown module')
            testCase.verifyEqual(exception.identifier, 'NANSEN:Dependencies:UnknownModule')
            testCase.verifySubstring(exception.message, '"fixture-no-such-module"')
            testCase.verifySubstring(exception.message, char(testCase.AlphaPackageName))
            testCase.verifySubstring(exception.message, 'Fixture Alpha')
            testCase.verifySubstring(exception.message, 'MATLAB search path')
        end

        function resolveModuleNamesRejectsAmbiguousName(testCase)
        %resolveModuleNamesRejectsAmbiguousName A name that fits two modules is an error.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture

            % The name of this module equals the short name of fixturebeta
            temporaryFolderFixture = testCase.applyFixture(TemporaryFolderFixture);
            createFixtureModule(temporaryFolderFixture.Folder, "fixturegamma", ...
                "FixtureBeta", {})
            testCase.applyFixture(PathFixture(temporaryFolderFixture.Folder));

            testCase.verifyError( ...
                @() nansen.internal.dependencies.resolveModuleNames("fixturebeta"), ...
                'NANSEN:Dependencies:AmbiguousModuleName')
        end
    end

    % --- resolveDependencyIds ---

    methods (Test)
        function resolveDependencyIdsFindsModuleDependency(testCase)
            [dependency, modulePackageName] = ...
                nansen.internal.dependencies.resolveDependencyIds("fixture-missing-tool");

            testCase.verifyEqual(dependency.Name, "Fixture Missing Tool")
            testCase.verifyEqual(modulePackageName, testCase.AlphaPackageName)
        end

        function resolveDependencyIdsFindsWorkflowDependency(testCase)
            [dependency, modulePackageName] = ...
                nansen.internal.dependencies.resolveDependencyIds("fixture-workflow-tool");

            testCase.verifyEqual(dependency.Name, "Fixture Workflow Tool")
            testCase.verifyEqual(dependency.Scope, "workflow")
            testCase.verifyEqual(modulePackageName, testCase.AlphaPackageName)
        end

        function resolveDependencyIdsFindsCoreDependency(testCase)
            [dependency, modulePackageName] = ...
                nansen.internal.dependencies.resolveDependencyIds("matbox");

            testCase.verifyEqual(dependency.Name, "MatBox")
            testCase.verifyEqual(modulePackageName, "")
        end

        function resolveDependencyIdsIgnoresLetterCase(testCase)
            dependency = nansen.internal.dependencies.resolveDependencyIds( ...
                "Fixture-Missing-Tool");
            testCase.verifyEqual(dependency.Id, "fixture-missing-tool")
        end

        function resolveDependencyIdsKeepsRequestedOrder(testCase)
            dependencies = nansen.internal.dependencies.resolveDependencyIds( ...
                ["fixture-workflow-tool", "fixture-missing-tool"]);
            testCase.verifyEqual([dependencies.Name], ...
                ["Fixture Workflow Tool", "Fixture Missing Tool"])
        end

        function resolveDependencyIdsAcceptsSameDependencyInTwoModules(testCase)
        %resolveDependencyIdsAcceptsSameDependencyInTwoModules Shared ids are not conflicts.
            dependency = nansen.internal.dependencies.resolveDependencyIds( ...
                "fixture-present-tool");
            testCase.verifyEqual(dependency.Name, "Fixture Present Tool")
        end

        function resolveDependencyIdsRejectsDuplicateId(testCase)
        %resolveDependencyIdsRejectsDuplicateId One id used for two dependencies is an error.
            testCase.verifyError( ...
                @() nansen.internal.dependencies.resolveDependencyIds("fixture-duplicate-id"), ...
                'NANSEN:Dependencies:DuplicateDependencyId')
        end

        function resolveDependencyIdsIgnoresMathworksProducts(testCase)
        %resolveDependencyIdsIgnoresMathworksProducts Only community toolboxes can be installed.
            testCase.verifyError( ...
                @() nansen.internal.dependencies.resolveDependencyIds("fixture-mathworks-product"), ...
                'NANSEN:Dependencies:UnknownDependency')
        end

        function resolveDependencyIdsListsIdsForUnknownId(testCase)
            exception = captureException(@() ...
                nansen.internal.dependencies.resolveDependencyIds("fixture-no-such-id"));

            testCase.assertNotEmpty(exception, 'Expected an error for an unknown id')
            testCase.verifyEqual(exception.identifier, 'NANSEN:Dependencies:UnknownDependency')
            testCase.verifySubstring(exception.message, '"fixture-no-such-id"')
            testCase.verifySubstring(exception.message, 'fixture-missing-tool')
            testCase.verifySubstring(exception.message, char(testCase.AlphaPackageName))
            testCase.verifySubstring(exception.message, 'MATLAB search path')
        end

        function resolveDependencyIdsPointsModuleNameToModulesOption(testCase)
        %resolveDependencyIdsPointsModuleNameToModulesOption A module name gets a syntax hint.
            exception = captureException(@() ...
                nansen.internal.dependencies.resolveDependencyIds("fixturealpha"));

            testCase.assertNotEmpty(exception, 'Expected an error for a module name')
            testCase.verifySubstring(exception.message, ...
                'nansen_install(Modules="fixturealpha")')
        end
    end

    % --- assertInstalled ---

    methods (Test)
        function assertInstalledPassesForDependencyOnPath(testCase)
            testCase.verifyWarningFree( ...
                @() nansen.internal.dependencies.assertInstalled("fixture-present-tool"))
        end

        function assertInstalledNamesInstallCommand(testCase)
            exception = captureException(@() ...
                nansen.internal.dependencies.assertInstalled("fixture-missing-tool"));

            testCase.assertNotEmpty(exception, 'Expected an error for a missing dependency')
            testCase.verifyEqual(exception.identifier, 'NANSEN:Dependencies:NotInstalled')
            testCase.verifySubstring(exception.message, 'Fixture Missing Tool')
            testCase.verifySubstring(exception.message, ...
                'nansen_install("fixture-missing-tool")')
        end

        function assertInstalledRejectsEntryWithoutInstallCheck(testCase)
            testCase.verifyError( ...
                @() nansen.internal.dependencies.assertInstalled("fixture-unchecked-tool"), ...
                'NANSEN:Dependencies:MissingInstallCheck')
        end
    end

    % --- nansen_install fails before downloading anything ---

    methods (Test)
        function nansenInstallRejectsUnknownDependencyId(testCase)
            addonFolder = testCase.prepareNansenInstall();
            testCase.verifyError( ...
                @() nansen_install("fixture-no-such-id", ...
                    AddonFolder=addonFolder, SavePath=false), ...
                'NANSEN:Dependencies:UnknownDependency')
        end

        function nansenInstallRejectsUnknownModule(testCase)
            addonFolder = testCase.prepareNansenInstall();
            testCase.verifyError( ...
                @() nansen_install(Modules="fixture-no-such-module", ...
                    AddonFolder=addonFolder, SavePath=false), ...
                'NANSEN:Dependencies:UnknownModule')
        end

        function nansenInstallRejectsDependencyIdsWithModules(testCase)
            addonFolder = testCase.prepareNansenInstall();
            testCase.verifyError( ...
                @() nansen_install("fixture-present-tool", Modules="fixturealpha", ...
                    AddonFolder=addonFolder, SavePath=false), ...
                'NANSEN:Setup:DependenciesAndModulesGiven')
        end
    end

    methods (Access = private)
        function addonFolder = prepareNansenInstall(testCase)
        %prepareNansenInstall - Put nansen_install on the path for one test
        %   nansen_install adds the NANSEN code folders to the path itself,
        %   so the whole path is restored afterwards. The temporary add-on
        %   folder keeps a failing test from writing to the user's add-ons.
            import matlab.unittest.fixtures.TemporaryFolderFixture

            originalPath = path();
            testCase.addTeardown(@path, originalPath)
            addpath(nansen.rootpath())

            temporaryFolderFixture = testCase.applyFixture(TemporaryFolderFixture);
            addonFolder = string(temporaryFolderFixture.Folder);
        end
    end
end

function exception = captureException(functionHandle)
%captureException - Return the error that a function throws, or empty
    exception = MException.empty;
    try
        functionHandle();
    catch exception
        % The caught exception is the output, so there is nothing to do
    end
end

function createFixtureModule(rootFolder, shortName, moduleName, dependencies)
%createFixtureModule - Write a module specification and dependency manifest
    packageName = "nansen.module.fixturecategory." + shortName;
    moduleFolder = fullfile(rootFolder, "+nansen", "+module", ...
        "+fixturecategory", "+" + shortName);
    mkdir(moduleFolder)

    writeTextFile(fullfile(moduleFolder, "module.nansen.json"), sprintf( ...
        ['{"_type": "NANSEN Module Specification", "_version": "1.0.0", ', ...
         '"Properties": {"Name": "%s", "Description": "Module for tests"}}'], ...
        moduleName))

    if isempty(dependencies)
        return
    end
    writeTextFile(fullfile(moduleFolder, "dependencies.nansen.json"), sprintf( ...
        ['{"_schema_id": "https://raw.githubusercontent.com/VervaekeLab/', ...
         'NANSEN/dev/schemas/dependencies.nansen.json", ', ...
         '"_schema_version": "1.0", "_type": "NANSEN Dependency Manifest", ', ...
         '"scope": "module", "scopeId": "%s", "dependencies": %s}'], ...
        packageName, jsonencode(dependencies)))
end

function dependencies = createAlphaDependencies()
%createAlphaDependencies - Dependencies declared by the fixturealpha module
    packageName = "nansen.module.fixturecategory.fixturealpha";
    dependencies = { ...
        createCommunityToolbox("Fixture Present Tool", "fixture-present-tool", ...
            "nansen.toolboxdir"), ...
        createCommunityToolbox("Fixture Missing Tool", "fixture-missing-tool", ...
            "nansenFixtureFunctionThatDoesNotExist"), ...
        struct( ...
            'name', "Fixture Workflow Tool", ...
            'id', "fixture-workflow-tool", ...
            'dependencyType', "community-toolbox", ...
            'scope', "workflow", ...
            'scopeId', packageName + ".workflow.example", ...
            'requirementLevel', "optional", ...
            'source', "https://github.com/test-org/FixtureWorkflowTool", ...
            'installCheck', "nansenFixtureWorkflowFunctionThatDoesNotExist"), ...
        struct( ...
            'name', "Fixture Unchecked Tool", ...
            'id', "fixture-unchecked-tool", ...
            'dependencyType', "community-toolbox", ...
            'requirementLevel', "optional", ...
            'source', "https://github.com/test-org/FixtureUncheckedTool"), ...
        createCommunityToolbox("Fixture Duplicate Tool A", "fixture-duplicate-id", ...
            "nansen.toolboxdir"), ...
        struct( ...
            'name', "Signal Processing Toolbox", ...
            'id', "fixture-mathworks-product", ...
            'dependencyType', "mathworks-product", ...
            'requirementLevel', "optional")};
end

function dependencies = createBetaDependencies()
%createBetaDependencies - Dependencies declared by the fixturebeta module
    dependencies = { ...
        createCommunityToolbox("Fixture Present Tool", "fixture-present-tool", ...
            "nansen.toolboxdir"), ...
        createCommunityToolbox("Fixture Duplicate Tool B", "fixture-duplicate-id", ...
            "nansen.toolboxdir")};
end

function dependency = createCommunityToolbox(name, id, installCheck)
%createCommunityToolbox - Manifest entry for an optional community toolbox
    dependency = struct( ...
        'name', name, ...
        'id', id, ...
        'dependencyType', "community-toolbox", ...
        'requirementLevel', "optional", ...
        'source', "https://github.com/test-org/" + erase(name, " "), ...
        'installCheck', installCheck);
end

function writeTextFile(filePath, text)
%writeTextFile - Write text to a file, replacing its content
    fileIdentifier = fopen(filePath, "w");
    assert(fileIdentifier ~= -1, "Could not open %s for writing.", filePath)
    closeFile = onCleanup(@() fclose(fileIdentifier));
    fwrite(fileIdentifier, text, "char");
end
