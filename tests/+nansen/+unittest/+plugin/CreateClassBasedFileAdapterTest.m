classdef CreateClassBasedFileAdapterTest < matlab.unittest.TestCase
%CreateClassBasedFileAdapterTest Unit tests for createClassBasedFileAdapter
%
%   Covers nansen.plugin.fileadapter.internal.createClassBasedFileAdapter
%   and the class templates it fills in. The tests load each generated
%   class from a temporary folder and read its metadata the same way as
%   nansen.dataio.FileAdapter.buildFileAdapterTable.
%
%   The tests call this generator directly, because
%   nansen.plugin.fileadapter.createFileAdapter changes the current folder
%   and opens the MATLAB editor.
%
%   Run tests:
%       runtests('nansen.unittest.plugin.CreateClassBasedFileAdapterTest')

    properties (TestParameter)
        AdapterVariant = struct( ...
            'ReadOnly', struct('AdapterType', "R", 'ClassName', "GeneratedReadOnlyFileAdapter"), ...
            'ReadWrite', struct('AdapterType', "RW", 'ClassName', "GeneratedReadWriteFileAdapter"))
    end

    methods (Access = private)

        function folderPath = createTargetFolderOnPath(testCase)
        %createTargetFolderOnPath Make an empty temporary folder on the MATLAB path
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.TemporaryFolderFixture

            fixture = testCase.applyFixture(TemporaryFolderFixture);
            folderPath = string(fixture.Folder);
            testCase.assertTrue(startsWith(folderPath, tempdir), ...
                sprintf('Expected "%s" to be inside "%s"', folderPath, tempdir))
            testCase.applyFixture(PathFixture(folderPath));
        end

        function generateFileAdapter(testCase, variant, dataType)
        %generateFileAdapter Generate an adapter class in a temporary folder
            metaProperties = struct( ...
                'Name', variant.ClassName, ...
                'SupportedFileTypes', ["dat", "bin"], ...
                'DataType', dataType);
            fileAdapterMeta = nansen.plugin.fileadapter.FileAdapterMeta(metaProperties);

            generatorPath = which('nansen.plugin.fileadapter.createFileAdapter');
            templateFolder = fullfile(fileparts(generatorPath), 'resources');

            nansen.plugin.fileadapter.internal.createClassBasedFileAdapter( ...
                templateFolder, testCase.createTargetFolderOnPath(), ...
                fileAdapterMeta, variant.AdapterType);
        end
    end

    methods (Test)

        function testDataTypeIsTheGivenText(testCase, AdapterVariant)
            dataType = "double";

            testCase.generateFileAdapter(AdapterVariant, dataType)

            classInfo = meta.class.fromName(AdapterVariant.ClassName);
            testCase.assertNotEmpty(classInfo)
            isDataType = string({classInfo.PropertyList.Name}) == "DataType";
            testCase.verifyEqual(classInfo.PropertyList(isDataType).DefaultValue, dataType)
        end
    end
end
