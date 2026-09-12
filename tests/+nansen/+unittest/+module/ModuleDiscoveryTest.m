classdef ModuleDiscoveryTest < matlab.unittest.TestCase
%ModuleDiscoveryTest Characterization of ModuleManager path-based discovery
%
%   Pins how nansen.config.module.ModuleManager finds modules on the
%   MATLAB path and what it derives for each: package name, short name,
%   category and whether it is the core module. Written before the
%   two-photon module moves out of the repository so that discovery does
%   not change by accident on the way.
%
%   Run tests:
%       runtests('nansen.unittest.module.ModuleDiscoveryTest')

    properties (Access = private)
        ModuleList struct
    end

    methods (TestClassSetup)
        function listModules(testCase)
            moduleManager = nansen.config.module.ModuleManager();
            testCase.ModuleList = moduleManager.ModuleList;
            testCase.assertNotEmpty(testCase.ModuleList, ...
                'No modules were discovered; is the NANSEN code folder on the path?')
        end
    end

    methods (Access = private)
        function entry = getEntry(testCase, packageName, moduleList)
            arguments
                testCase
                packageName (1,1) string
                moduleList struct = testCase.ModuleList
            end
            packageNames = string({moduleList.PackageName});
            isMatch = packageNames == packageName;
            testCase.assertEqual(nnz(isMatch), 1, ...
                sprintf('Expected exactly one module named "%s"', packageName))
            entry = moduleList(isMatch);
        end

        function rootFolder = createModuleRoot(testCase, shortName, category)
        %createModuleRoot Make a path root holding one flat module folder
        %
        %   Writes <root>/+nansen/+module/+<shortName>/module.nansen.json
        %   with the given category and returns <root>, which the caller
        %   puts on the path. Discovery keys off the specification file, so
        %   no code files are needed.
            import matlab.unittest.fixtures.TemporaryFolderFixture

            fixture = testCase.applyFixture(TemporaryFolderFixture);
            rootFolder = char(fixture.Folder);
            moduleFolder = fullfile(rootFolder, '+nansen', '+module', ['+', char(shortName)]);
            mkdir(moduleFolder)

            % Only the Properties block is read by discovery.
            specification = struct( ...
                'Properties', struct( ...
                    'Name', sprintf('Test module %s', shortName), ...
                    'Category', char(category), ...
                    'Description', 'Created by ModuleDiscoveryTest'));

            fileId = fopen(fullfile(moduleFolder, 'module.nansen.json'), 'w');
            testCase.assertNotEqual(fileId, -1, 'Could not write the module specification')
            fprintf(fileId, '%s', jsonencode(specification));
            fclose(fileId);
        end
    end

    methods (Test)

        function testCoreModuleIsDiscovered(testCase)
            entry = testCase.getEntry("nansen.module.general.core");
            testCase.verifyEqual(string(entry.ShortName), "core")
            testCase.verifyEqual(string(entry.ModuleCategory), "general")
            testCase.verifyTrue(entry.isCoreModule)
            testCase.verifyTrue(isfolder(entry.FolderPath))
        end

        function testEveryEntryHasTheDerivedFields(testCase)
            requiredFields = ["Name", "Description", "ModuleCategory", ...
                "ShortName", "PackageName", "isCoreModule", "FolderPath", ...
                "RequirementManifestPath"];
            testCase.verifyTrue(all(isfield(testCase.ModuleList, requiredFields)))
        end

        function testShortNamesAreUnique(testCase)
            % Discovery keys modules by short name once the category folder
            % is optional, so short names must not collide.
            shortNames = string({testCase.ModuleList.ShortName});
            testCase.verifyEqual(numel(unique(shortNames)), numel(shortNames))
        end

        function testPackageNameEndsWithShortName(testCase)
            for i = 1:numel(testCase.ModuleList)
                entry = testCase.ModuleList(i);
                testCase.verifyTrue(endsWith(string(entry.PackageName), ...
                    "." + string(entry.ShortName)), ...
                    sprintf('Package "%s" should end with "%s"', ...
                    entry.PackageName, entry.ShortName))
            end
        end

        function testOnlyTheCoreModuleIsMarkedCore(testCase)
            isCore = [testCase.ModuleList.isCoreModule];
            packageNames = string({testCase.ModuleList.PackageName});
            testCase.verifyEqual(packageNames(isCore), "nansen.module.general.core")
        end

        function testCategoryIsReadFromTheSpecification(testCase)
            % A module folder directly under +module has no category folder
            % to derive the category from; it must come from the
            % specification file instead.
            import matlab.unittest.fixtures.PathFixture

            rootFolder = testCase.createModuleRoot("discoverytestmod", "testcategory");
            testCase.applyFixture(PathFixture(rootFolder))

            moduleManager = nansen.config.module.ModuleManager();
            entry = testCase.getEntry("nansen.module.discoverytestmod", moduleManager.ModuleList);

            testCase.verifyEqual(string(entry.ModuleCategory), "testcategory")
            testCase.verifyEqual(string(entry.ShortName), "discoverytestmod")
            testCase.verifyFalse(entry.isCoreModule)
            testCase.verifyFalse(isfield(entry, 'Category'), ...
                'Category is exposed as ModuleCategory, not as a raw manifest field')
        end

        function testDuplicateShortNamesAreRejected(testCase)
            import matlab.unittest.fixtures.PathFixture

            firstRoot = testCase.createModuleRoot("discoverydupmod", "alpha");
            secondRoot = testCase.createModuleRoot("discoverydupmod", "beta");
            testCase.applyFixture(PathFixture(firstRoot))
            testCase.applyFixture(PathFixture(secondRoot))

            testCase.verifyError(@() nansen.config.module.ModuleManager(), ...
                'NANSEN:ModuleManager:DuplicateModuleName')
        end
    end
end
