classdef Attributes2MetaTest < matlab.unittest.TestCase
%Attributes2MetaTest Unit tests for attributes2meta
%
%   Covers nansen.plugin.fileadapter.internal.attributes2meta, which
%   converts the output of the Create File Adapter dialog to the inputs of
%   nansen.plugin.fileadapter.createFileAdapter.
%
%   createFileAdapter changes the current folder and opens the MATLAB
%   editor. The tests that check the effect of the converted values
%   therefore call the generators it delegates to, which write only to the
%   target folder they are given.
%
%   Run tests:
%       runtests('nansen.unittest.plugin.Attributes2MetaTest')

    properties (TestParameter)
        AccessMode = struct( ...
            'ReadOnly', struct('AdapterType', 'R', 'HasWriteFile', false), ...
            'ReadWrite', struct('AdapterType', 'RW', 'HasWriteFile', true))

        Generator = struct( ...
            'FunctionBased', @nansen.plugin.fileadapter.internal.createFunctionBasedFileAdapter, ...
            'ClassBased', @nansen.plugin.fileadapter.internal.createClassBasedFileAdapter)
    end

    methods (Access = private)

        function varargout = convertAttributes(~, attributes)
        %convertAttributes Call the function under test
            [varargout{1:nargout}] = nansen.plugin.fileadapter.internal.attributes2meta(attributes);
        end

        function attributes = createDialogAttributes(~, adapterType)
        %createDialogAttributes Make a struct as returned by uigetFileAdapterAttributes
            attributes = struct();
            attributes.Name = 'ExampleAdapter';
            attributes.Description = 'Example description';
            attributes.SupportedFileTypes = {'dat', 'bin'};
            attributes.DataType = 'double';
            attributes.AdapterType = adapterType;
        end

        function folderPath = createTargetFolder(testCase)
        %createTargetFolder Make an empty temporary folder to generate into
            import matlab.unittest.fixtures.TemporaryFolderFixture

            fixture = testCase.applyFixture(TemporaryFolderFixture);
            folderPath = string(fixture.Folder);
            testCase.assertTrue(startsWith(folderPath, tempdir), ...
                sprintf('Expected "%s" to be inside "%s"', folderPath, tempdir))
        end

        function folderPath = getTemplateFolder(~)
        %getTemplateFolder Get the folder createFileAdapter reads templates from
            generatorPath = which('nansen.plugin.fileadapter.createFileAdapter');
            folderPath = fullfile(fileparts(generatorPath), 'resources');
        end
    end

    methods (Test)

        function testReturnsFileAdapterMetaWithDialogValues(testCase)
            attributes = testCase.createDialogAttributes('R');

            fileAdapterMeta = testCase.convertAttributes(attributes);

            testCase.verifyClass(fileAdapterMeta, 'nansen.plugin.fileadapter.FileAdapterMeta')
            testCase.verifyEqual(fileAdapterMeta.Name, "ExampleAdapter")
            testCase.verifyEqual(fileAdapterMeta.Description, "Example description")
            testCase.verifyEqual(fileAdapterMeta.SupportedFileTypes, ["dat", "bin"])
            testCase.verifyEqual(fileAdapterMeta.DataType, "double")
        end

        function testReturnsSelectedAdapterType(testCase, AccessMode)
            attributes = testCase.createDialogAttributes(AccessMode.AdapterType);

            [~, adapterType] = testCase.convertAttributes(attributes);

            testCase.verifyEqual(adapterType, string(AccessMode.AdapterType))
        end

        function testMissingAdapterTypeIsAnError(testCase)
            attributes = rmfield(testCase.createDialogAttributes('R'), 'AdapterType');

            testCase.verifyError(@() testCase.convertAttributes(attributes), ...
                'MATLAB:nonExistentField')
        end

        function testGeneratedFilesFollowAdapterType(testCase, Generator, AccessMode)
            attributes = testCase.createDialogAttributes(AccessMode.AdapterType);
            [fileAdapterMeta, adapterType] = testCase.convertAttributes(attributes);

            adapterFolder = Generator(testCase.getTemplateFolder(), ...
                testCase.createTargetFolder(), fileAdapterMeta, adapterType);

            testCase.verifyTrue(isfile(fullfile(adapterFolder, 'read.m')))
            testCase.verifyEqual(isfile(fullfile(adapterFolder, 'write.m')), ...
                AccessMode.HasWriteFile)
        end
    end
end
