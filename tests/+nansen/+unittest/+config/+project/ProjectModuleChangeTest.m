classdef ProjectModuleChangeTest < matlab.unittest.TestCase
    %ProjectModuleChangeTest Changing the optional modules of a project
    %
    %   setOptionalModules saves the module names in the project preferences
    %   and calls updateModules, which adds new modules to IncludedModules
    %   and to the project's file adapter registry, and removes deselected
    %   modules from both. The App calls setOptionalModules when modules are
    %   selected in the Module Manager.
    %
    %   The tests run inside a temporary project, which includes only the
    %   core module. The module they add is created in a temporary folder
    %   and holds one file adapter, defined by a fileadapter.json file.
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.project.ProjectModuleChangeTest')

    properties (Constant)
        ModuleName = 'nansentest.registrymodule'
        AdapterName = "RegistryTestAdapter"
    end

    properties
        Project
    end

    methods (TestClassSetup)
        function useTemporaryProject(testCase)
        %useTemporaryProject Create a project and a module it can include
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.TemporaryFolderFixture

            testCase.applyFixture(nansen.fixture.ProjectFixture())
            testCase.Project = nansen.getCurrentProject();

            folderFixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.createModule(folderFixture.Folder)

            % Module.fromName finds a module outside the NANSEN module
            % folder through its package folder on the MATLAB path.
            testCase.applyFixture(PathFixture(folderFixture.Folder))
        end
    end

    methods (TestMethodSetup)
        function restoreCoreModuleOnly(testCase)
        %restoreCoreModuleOnly Leave the project with the core module only
            testCase.addTeardown(@() testCase.Project.setOptionalModules({}))
        end
    end

    methods (Test)

        function testAddingModuleIncludesIt(testCase)
        %testAddingModuleIncludesIt A selected module is added to IncludedModules
            testCase.Project.setOptionalModules({testCase.ModuleName})

            includedModules = testCase.Project.IncludedModules;
            moduleIds = [includedModules.ID];
            testCase.verifyTrue(ismember(testCase.ModuleName, moduleIds))
        end

        function testAddedModuleFileAdapterIsListed(testCase)
        %testAddedModuleFileAdapterIsListed The registry lists the adapters of an added module
            testCase.Project.setOptionalModules({testCase.ModuleName})

            entries = testCase.Project.FileAdapterRegistry.list();
            testCase.verifyTrue(any([entries.FileAdapterName] == testCase.AdapterName))
        end

        function testRemovingModuleRemovesItsFileAdapters(testCase)
        %testRemovingModuleRemovesItsFileAdapters A deselected module and its adapters are removed
            testCase.Project.setOptionalModules({testCase.ModuleName})
            testCase.Project.setOptionalModules({})

            includedModules = testCase.Project.IncludedModules;
            moduleIds = [includedModules.ID];
            testCase.verifyFalse(ismember(testCase.ModuleName, moduleIds))

            entries = testCase.Project.FileAdapterRegistry.list();
            testCase.verifyFalse(any([entries.FileAdapterName] == testCase.AdapterName))
        end
    end

    methods (Access = private)

        function createModule(testCase, rootFolder)
        %createModule Write a module with one sidecar file adapter to rootFolder
            packagePath = "+" + replace(testCase.ModuleName, ".", filesep + "+");
            moduleFolder = fullfile(rootFolder, packagePath);
            mkdir(moduleFolder)

            moduleSpecification = sprintf([ ...
                '{\n', ...
                '    "_type": "NANSEN Module Specification",\n', ...
                '    "_version": "1.0.0",\n', ...
                '    "Properties": {\n', ...
                '        "Name": "Registry Test Module",\n', ...
                '        "Description": "Module with one file adapter"\n', ...
                '    }\n', ...
                '}']);
            utility.filewrite(char(fullfile(moduleFolder, 'module.nansen.json')), ...
                moduleSpecification)

            adapterFolder = fullfile(moduleFolder, '+fileadapter', "+" + testCase.AdapterName);
            mkdir(adapterFolder)

            adapterSpecification = sprintf([ ...
                '{\n', ...
                '    "_type": "FileAdapter",\n', ...
                '    "_version": "1.0.0",\n', ...
                '    "Properties": {\n', ...
                '        "Name": "%s",\n', ...
                '        "Description": "",\n', ...
                '        "SupportedFileTypes": [".rtst"],\n', ...
                '        "FileExpression": "",\n', ...
                '        "DataType": "generic",\n', ...
                '        "IsGeneral": false,\n', ...
                '        "ReadFunction": "",\n', ...
                '        "WriteFunction": "",\n', ...
                '        "ViewFunction": ""\n', ...
                '    }\n', ...
                '}'], testCase.AdapterName);
            utility.filewrite(char(fullfile(adapterFolder, 'fileadapter.json')), ...
                adapterSpecification)
        end
    end
end
