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

        % A class name per case keeps one case from loading the class that
        % another case generated.
        DescriptionCase = struct( ...
            'PlainText', struct('Text', 'Recordings from the example rig', 'ClassSuffix', "Plain"), ...
            'QuoteCharacters', struct('Text', 'Don''t use the "raw" channel', 'ClassSuffix', "Quoted"), ...
            'Empty', struct('Text', '', 'ClassSuffix', "Empty"))
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

        function generateFileAdapter(testCase, variant, dataType, description)
        %generateFileAdapter Generate an adapter class in a temporary folder
            arguments
                testCase
                variant (1,1) struct
                dataType (1,1) string
                description (1,1) string = ""
            end

            metaProperties = struct( ...
                'Name', variant.ClassName, ...
                'Description', description, ...
                'SupportedFileTypes', ["dat", "bin"], ...
                'DataType', dataType);
            fileAdapterMeta = nansen.plugin.fileadapter.FileAdapterMeta(metaProperties);

            generatorPath = which('nansen.plugin.fileadapter.createFileAdapter');
            templateFolder = fullfile(fileparts(generatorPath), 'resources');

            nansen.plugin.fileadapter.internal.createClassBasedFileAdapter( ...
                templateFolder, testCase.createTargetFolderOnPath(), ...
                fileAdapterMeta, variant.AdapterType);
        end

        function value = getPropertyDefault(testCase, className, propertyName)
        %getPropertyDefault Read the default value of a generated class property
            classInfo = meta.class.fromName(className);
            testCase.assertNotEmpty(classInfo)
            isProperty = string({classInfo.PropertyList.Name}) == propertyName;
            testCase.assertTrue(any(isProperty), ...
                sprintf('Expected class "%s" to have property "%s"', className, propertyName))
            value = classInfo.PropertyList(isProperty).DefaultValue;
        end
    end

    methods (Test)

        function testDataTypeIsTheGivenText(testCase, AdapterVariant)
            dataType = "double";

            testCase.generateFileAdapter(AdapterVariant, dataType)

            testCase.verifyEqual( ...
                testCase.getPropertyDefault(AdapterVariant.ClassName, "DataType"), dataType)
        end

        function testDescriptionIsTheGivenText(testCase, AdapterVariant, DescriptionCase)
            variant = AdapterVariant;
            variant.ClassName = variant.ClassName + DescriptionCase.ClassSuffix;

            testCase.generateFileAdapter(variant, "double", DescriptionCase.Text)

            % Expected as char because the metadata file writer rejects strings.
            testCase.verifyEqual( ...
                testCase.getPropertyDefault(variant.ClassName, "Description"), DescriptionCase.Text)
        end
    end
end
