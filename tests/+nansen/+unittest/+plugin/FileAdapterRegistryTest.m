classdef FileAdapterRegistryTest < matlab.unittest.TestCase
%FileAdapterRegistryTest Tests for nansen.plugin.fileadapter.Registry.
%
%   Uses temporary directories so no Project object is needed. Verifies
%   that the registry is project-agnostic and that class-based and
%   sidecar-based adapters are discovered correctly.

    properties
        TempDir (1,1) string
    end

    methods (TestMethodSetup)
        function createTempDir(testCase)
            testCase.TempDir = string(tempname());
            mkdir(testCase.TempDir)
            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'))
        end
    end

    methods (Test)

        function testSourceWithNoFileadapterFolderIsEmpty(testCase)
            reg = nansen.plugin.fileadapter.Registry();
            emptyDir = fullfile(testCase.TempDir, 'empty_source');
            mkdir(emptyDir)

            reg.pinBottom("empty", emptyDir);
            reg.reconcile();

            testCase.verifyEmpty(reg.list())
        end

        function testRegistryIsProjectAgnostic(testCase)
            % The registry can be constructed and used without any Project.
            reg = nansen.plugin.fileadapter.Registry();
            dirA = testCase.makeSidecarSource('sourceA', 'TestSidecar', 'mat');
            reg.pinBottom("src-a", dirA);
            reg.reconcile();

            entries = reg.list();
            testCase.verifyNotEmpty(entries)
            testCase.verifyTrue(any([entries.FileAdapterName] == "TestSidecar"))
        end

        function testSidecarAdapterDiscovery(testCase)
            reg = nansen.plugin.fileadapter.Registry();
            srcDir = testCase.makeSidecarSource('src', 'MyAdapter', 'csv');
            reg.pinBottom("src", srcDir);
            reg.reconcile();

            entries = reg.list();
            testCase.verifyNumElements(entries, 1)
            testCase.verifyEqual(entries.FileAdapterName, "MyAdapter")
            testCase.verifyTrue(entries.IsDynamic)
        end

        function testFilterByFileExtension(testCase)
            reg = nansen.plugin.fileadapter.Registry();
            srcDir = fullfile(testCase.TempDir, 'multi');
            testCase.makeSidecarSourceInDir(srcDir, 'TxtAdapter', 'txt');
            testCase.makeSidecarSourceInDir(srcDir, 'CsvAdapter', 'csv');
            reg.pinBottom("src", srcDir);
            reg.reconcile();

            csvEntries = reg.list("csv");
            testCase.verifyNumElements(csvEntries, 1)
            testCase.verifyEqual(csvEntries.FileAdapterName, "CsvAdapter")
        end

        function testFilterByExtensionWithDot(testCase)
            reg = nansen.plugin.fileadapter.Registry();
            srcDir = testCase.makeSidecarSource('src', 'MatAdapter', 'mat');
            reg.pinBottom("src", srcDir);
            reg.reconcile();

            withDot    = reg.list(".mat");
            withoutDot = reg.list("mat");
            testCase.verifyEqual([withDot.FileAdapterName], [withoutDot.FileAdapterName])
        end

        function testSourceAddAndRemoveDynamic(testCase)
            reg = nansen.plugin.fileadapter.Registry();
            srcA = testCase.makeSidecarSource('A', 'AdapterA', 'h5');
            srcB = testCase.makeSidecarSource('B', 'AdapterB', 'npy');

            reg.addSource("src-a", srcA);
            reg.reconcile();
            testCase.verifyNumElements(reg.list(), 1)

            reg.addSource("src-b", srcB);
            reg.reconcile();
            testCase.verifyNumElements(reg.list(), 2)

            reg.removeSource("src-a");
            reg.reconcile();
            entries = reg.list();
            testCase.verifyNumElements(entries, 1)
            testCase.verifyEqual(entries.FileAdapterName, "AdapterB")
        end

        function testTopSourceWinsOnConflict(testCase)
            reg = nansen.plugin.fileadapter.Registry();
            srcBottom = testCase.makeSidecarSource('Bottom', 'SharedName', 'tif');
            srcTop    = testCase.makeSidecarSource('Top',    'SharedName', 'tiff');

            reg.pinBottom("bottom", srcBottom);
            reg.pinTop("top", srcTop);
            reg.reconcile();

            entries = reg.list();
            testCase.verifyNumElements(entries, 1)
            % Top source should win; its supported file type is '.tiff'
            testCase.verifyEqual(entries.SupportedFileTypes, ".tiff")
        end

        function testSidecarAdapterWithSeveralFileTypes(testCase)
        %testSidecarAdapterWithSeveralFileTypes One adapter in a source lists two file types
        %
        %   A source with one adapter gives a scalar adapter struct, and
        %   its SupportedFileTypes field holds two elements.
            srcDir = testCase.makeSidecarSource('src', 'TiffAdapter', ["tif", "tiff"]);
            reg = nansen.plugin.fileadapter.Registry();
            reg.pinBottom("src", srcDir);
            reg.reconcile();

            entries = reg.list();
            testCase.verifyNumElements(entries, 1)
            testCase.verifyEqual(entries.FileAdapterName, "TiffAdapter")
            testCase.verifyEqual(entries.SupportedFileTypes(:), [".tif"; ".tiff"])
        end

        function testClassAdapterOnPathAtFirstLookupIsFound(testCase)
        %testClassAdapterOnPathAtFirstLookupIsFound Sources are scanned at the first lookup
        %
        %   A project adds its sources to the registry before its folder is
        %   on the MATLAB path, and a class-based adapter is found only
        %   when it is on the path.
            import matlab.unittest.fixtures.PathFixture

            [codeFolder, sourceFolder] = testCase.makeClassAdapterSource('ClassAdapter', 'tsv');
            reg = nansen.plugin.fileadapter.Registry();
            reg.pinTop("project", sourceFolder);

            testCase.applyFixture(PathFixture(codeFolder));
            entries = reg.list();

            testCase.verifyEqual([entries.FileAdapterName], "ClassAdapter")
            testCase.verifyFalse(entries.IsDynamic)
        end

        function testModuleDeprecationWarning(testCase)
            module = nansen.module.Module.fromName( ...
                nansen.common.constant.BaseModuleName);
            testCase.verifyWarning( ...
                @() module.FileAdapters, ...
                'NANSEN:DeprecatedPath:ModuleFileAdapters')
        end

        function testGetTableFileAdapterDeprecationWarning(testCase)
            module = nansen.module.Module.fromName( ...
                nansen.common.constant.BaseModuleName);
            testCase.verifyWarning( ...
                @() module.getTable('FileAdapter'), ...
                'NANSEN:DeprecatedPath:ModuleFileAdapters')
        end
    end

    methods (Access = private)
        function [codeFolder, sourceFolder] = makeClassAdapterSource(testCase, adapterName, extension)
        %makeClassAdapterSource Create a source with one class-based adapter.
        %
        %   The source is a package folder in codeFolder, like the
        %   code/+projectname folder of a project. The package is named
        %   after the temporary folder, so that each test defines its own
        %   class.
            codeFolder = fullfile(testCase.TempDir, 'code');
            [~, packageName] = fileparts(testCase.TempDir);
            sourceFolder = fullfile(codeFolder, "+" + packageName);
            adapterFolder = fullfile(sourceFolder, '+fileadapter');
            mkdir(adapterFolder)

            classDefinition = sprintf([ ...
                'classdef %s < nansen.dataio.FileAdapter\n', ...
                '    properties (Constant)\n', ...
                '        DataType = ''table''\n', ...
                '    end\n', ...
                '    properties (Constant, Hidden, Access = protected)\n', ...
                '        SUPPORTED_FILE_TYPES = {''%s''}\n', ...
                '    end\n', ...
                '    methods (Access = protected)\n', ...
                '        function data = readData(obj, varargin)\n', ...
                '            data = readtable(obj.Filename, ''FileType'', ''text'');\n', ...
                '        end\n', ...
                '    end\n', ...
                'end\n'], adapterName, extension);
            utility.filewrite(char(fullfile(adapterFolder, adapterName + ".m")), classDefinition)
        end

        function srcDir = makeSidecarSource(testCase, name, adapterName, extensions)
        %makeSidecarSource Create a temp source dir with one sidecar adapter.
            srcDir = fullfile(testCase.TempDir, name);
            testCase.makeSidecarSourceInDir(srcDir, adapterName, extensions);
        end

        function makeSidecarSourceInDir(~, srcDir, adapterName, extensions)
        %makeSidecarSourceInDir Write a fileadapter.json sidecar into srcDir.
        %
        %   extensions holds one or more file types without a dot. The JSON
        %   has a "_type" field and lists each file type with a leading
        %   dot, matching the format the parser expects.
            faDir = fullfile(srcDir, '+fileadapter', ['+', adapterName]);
            mkdir(faDir)

            fileTypeList = strjoin("""." + string(extensions) + """", ", ");

            % Build JSON manually so the field is literally "_type"
            % (jsonencode would produce "x_type" from a struct, which also
            % works after jsondecode, but this matches the canonical format).
            jsonStr = sprintf( ...
                ['{\n', ...
                '    "_type": "FileAdapter",\n', ...
                '    "_version": "1.0.0",\n', ...
                '    "Properties": {\n', ...
                '        "Name": "%s",\n', ...
                '        "Description": "",\n', ...
                '        "SupportedFileTypes": [%s],\n', ...
                '        "FileExpression": "",\n', ...
                '        "DataType": "generic",\n', ...
                '        "IsGeneral": false,\n', ...
                '        "ReadFunction": "",\n', ...
                '        "WriteFunction": "",\n', ...
                '        "ViewFunction": ""\n', ...
                '    }\n', ...
                '}'], adapterName, fileTypeList);

            utility.filewrite(fullfile(faDir, 'fileadapter.json'), jsonStr)
        end
    end
end
