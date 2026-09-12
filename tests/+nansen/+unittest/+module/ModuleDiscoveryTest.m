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
        function entry = getEntry(testCase, packageName)
            packageNames = string({testCase.ModuleList.PackageName});
            isMatch = packageNames == packageName;
            testCase.assertEqual(nnz(isMatch), 1, ...
                sprintf('Expected exactly one module named "%s"', packageName))
            entry = testCase.ModuleList(isMatch);
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
    end
end
