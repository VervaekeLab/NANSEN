classdef ModuleDiscoveryTest < matlab.unittest.TestCase
%ModuleDiscoveryTest Characterization of ModuleManager path-based discovery
%
%   Pins how nansen.config.module.ModuleManager finds modules on the
%   MATLAB path and what it derives for each: package name, short name,
%   category and whether it is the core module.
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

        function [rootFolder, moduleFolder] = createModuleRoot(testCase, shortName, category, options)
        %createModuleRoot Make a path root holding one module folder
        %
        %   Writes <root>/+nansen/+module/+<shortName>/module.nansen.json
        %   with the given category and returns <root>, which the caller
        %   puts on the path, and the module folder. With CategoryFolder
        %   set, the module folder is
        %   <root>/+nansen/+module/+<CategoryFolder>/+<shortName>.
        %   Discovery reads only the specification file, so no code files
        %   are needed.
            arguments
                testCase
                shortName (1,1) string
                category (1,1) string
                options.CategoryFolder (1,1) string = ""
            end
            import matlab.unittest.fixtures.TemporaryFolderFixture

            fixture = testCase.applyFixture(TemporaryFolderFixture);
            rootFolder = char(fixture.Folder);
            moduleFolder = fullfile(rootFolder, '+nansen', '+module');
            if options.CategoryFolder ~= ""
                moduleFolder = fullfile(moduleFolder, ['+', char(options.CategoryFolder)]);
            end
            moduleFolder = fullfile(moduleFolder, ['+', char(shortName)]);
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
            % Module short names must be unique across categories.
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
            % nansen.module.discoverydupmod and
            % nansen.module.beta.discoverydupmod are different packages
            % with the same short name.
            import matlab.unittest.fixtures.PathFixture

            [firstRoot, firstModuleFolder] = testCase.createModuleRoot( ...
                "discoverydupmod", "alpha");
            [secondRoot, secondModuleFolder] = testCase.createModuleRoot( ...
                "discoverydupmod", "beta", CategoryFolder="beta");
            testCase.applyFixture(PathFixture(firstRoot))
            testCase.applyFixture(PathFixture(secondRoot))

            try
                nansen.config.module.ModuleManager();
                testCase.verifyFail('Two packages with the same short name were accepted')
            catch exception
                testCase.verifyEqual(exception.identifier, ...
                    'NANSEN:ModuleManager:DuplicateModuleName')
                % The message names the folder of each clashing package.
                testCase.verifySubstring(exception.message, firstModuleFolder)
                testCase.verifySubstring(exception.message, secondModuleFolder)
            end
        end

        function testSamePackageTwiceIsAccepted(testCase)
            % A package found in two folders on the path, for example a
            % cloned repository and an installed copy, is one module. The
            % entry from the folder first on the path is kept.
            import matlab.unittest.fixtures.PathFixture

            laterRoot = testCase.createModuleRoot("discoverysamemod", "alpha");
            [firstRoot, firstModuleFolder] = testCase.createModuleRoot( ...
                "discoverysamemod", "alpha");
            % PathFixture adds a folder to the top of the path, so the root
            % applied last comes first on the path.
            testCase.applyFixture(PathFixture(laterRoot))
            testCase.applyFixture(PathFixture(firstRoot))

            moduleManager = nansen.config.module.ModuleManager();
            entry = testCase.getEntry("nansen.module.discoverysamemod", moduleManager.ModuleList);

            testCase.verifyEqual(string(entry.FolderPath), string(firstModuleFolder))
        end
    end
end
