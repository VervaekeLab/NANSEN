classdef ReaderResolutionTest < matlab.unittest.TestCase
%ReaderResolutionTest Pins which reader class NANSEN picks for 2P recordings
%
%   Characterization tests for
%   nansen.dataio.fileadapter.imagestack.ImageStack.getVirtualDataClassNameFromFilename,
%   the core dispatcher that maps a file name (or, for SciScan and
%   ScanImage, the file's content) to a virtual-data reader class. The
%   scanner readers move into the two-photon module during the migration;
%   these tests must keep passing with only the class names updated.
%
%   Content-probed formats are synthesised from what the predicates read:
%   SciScanRaw.fileCheck wants a .raw file, a sibling .ini file, and two
%   SciScan keys in the .ini text; ScanImageTiff.fileCheck wants a TIFF
%   whose Software tag starts with "SI".
%
%   Run tests:
%       runtests('twophotontest.ReaderResolutionTest')

    properties (TestParameter)
        FilenameCase = struct( ...
            'prairieView', struct( ...
                'filename', 'TSeries-01012020-0001_Cycle00001_Ch1_000001.ome.tif', ...
                'className', 'nansen.stack.virtual.PrairieViewTiffs'), ...
            'thorLabs', struct( ...
                'filename', 'ChanA_001_001_001_001.tif', ...
                'className', 'nansen.stack.virtual.ThorLabsTiffs'), ...
            'suite2pCorrected', struct( ...
                'filename', fullfile('plane0', 'reg_tif', 'file000_chan0.tif'), ...
                'className', 'nansen.stack.virtual.Suite2pCorrected'), ...
            'multiPartMultiChannel', struct( ...
                'filename', 'recording_ch1_part_001.tif', ...
                'className', 'nansen.stack.virtual.TiffMultiPartMultiChannel'), ...
            'unrecognised', struct( ...
                'filename', 'plain_recording.tif', ...
                'className', ''))
    end

    methods (Access = private)

        function className = resolve(~, filename)
            className = nansen.dataio.fileadapter.imagestack.ImageStack. ...
                getVirtualDataClassNameFromFilename(filename);
        end

        function folderPath = makeFixtureFolder(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            folderPath = char(fixture.Folder);
        end

        function writeText(testCase, filePath, text)
            fileId = fopen(filePath, 'w');
            testCase.assertNotEqual(fileId, -1, ...
                sprintf('Could not create fixture file "%s"', filePath))
            fprintf(fileId, '%s', text);
            fclose(fileId);
        end
    end

    methods (Test)

        function testFilenameExpressionReaders(testCase, FilenameCase)
            className = testCase.resolve(FilenameCase.filename);
            testCase.verifyEqual(className, FilenameCase.className)
        end

        function testSciScanRecordingIsResolvedByContent(testCase)
            folderPath = testCase.makeFixtureFolder();
            baseName = '20200101_12_00_00_recording';
            rawFilePath = fullfile(folderPath, [baseName, '.raw']);
            iniFilePath = fullfile(folderPath, [baseName, '.ini']);

            testCase.writeText(rawFilePath, '');
            testCase.writeText(iniFilePath, sprintf( ...
                'external.start.trigger.enable = TRUE\naocard.model = PCI-6110\n'));

            className = testCase.resolve(rawFilePath);
            testCase.verifyEqual(className, 'nansen.stack.virtual.SciScanRaw')
        end

        function testSciScanNameWithoutIniIsNotResolved(testCase)
            folderPath = testCase.makeFixtureFolder();
            rawFilePath = fullfile(folderPath, '20200101_12_00_00_recording.raw');
            testCase.writeText(rawFilePath, '');

            className = testCase.resolve(rawFilePath);
            testCase.verifyEqual(className, '')
        end

        function testScanImageTiffIsResolvedByContent(testCase)
            folderPath = testCase.makeFixtureFolder();
            tiffFilePath = fullfile(folderPath, 'scanimage_00001.tif');

            tiffFile = Tiff(tiffFilePath, 'w');
            closeTiff = onCleanup(@() close(tiffFile));
            tiffFile.setTag('ImageLength', 4);
            tiffFile.setTag('ImageWidth', 4);
            tiffFile.setTag('Photometric', Tiff.Photometric.MinIsBlack);
            tiffFile.setTag('BitsPerSample', 16);
            tiffFile.setTag('SamplesPerPixel', 1);
            tiffFile.setTag('PlanarConfiguration', Tiff.PlanarConfiguration.Chunky);
            tiffFile.setTag('Software', 'SI.TEST');
            tiffFile.write(zeros(4, 4, 'uint16'));
            clear closeTiff

            className = testCase.resolve(tiffFilePath);
            testCase.verifyEqual(className, 'nansen.stack.virtual.ScanImageTiff')
        end
    end
end
