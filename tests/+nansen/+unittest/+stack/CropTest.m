classdef CropTest < matlab.unittest.TestCase
    %CropTest Unit tests for nansen.stack.crop.
    %
    %   Covers the crop rectangle convention ([xmin, ymin, width, height]
    %   with an exact output size), all supported dimension arrangements,
    %   chunked processing, metadata, export to binary and TIFF files, and
    %   the errors that protect existing files from being overwritten.
    %
    %   Image data is filled with consecutive values, so every pixel is
    %   unique and any shifted, permuted or misplaced chunk is detected.
    %
    %   Run tests:
    %       runtests('nansen.unittest.stack.CropTest')

    properties (TestParameter)
        stackCase = struct( ...
            'image',        struct('size', [20, 30],         'arrangement', 'YX'), ...
            'rgbImage',     struct('size', [20, 30, 3],      'arrangement', 'YXC'), ...
            'timeSeries',   struct('size', [20, 30, 7],      'arrangement', 'YXT'), ...
            'planes',       struct('size', [20, 30, 7],      'arrangement', 'YXZ'), ...
            'multiChannel', struct('size', [20, 30, 2, 7],   'arrangement', 'YXCT'), ...
            'volumetric',   struct('size', [20, 30, 2, 3, 4], 'arrangement', 'YXCZT'))

        % 7 timepoints: one frame per chunk, a chunk length that leaves a
        % shorter last chunk, and a chunk longer than the stack.
        chunkLength = struct('oneFrame', 1, 'withRemainder', 3, 'longerThanStack', 100)

        fileExtension = struct('binary', '.raw', 'tiff', '.tif')

        invalidRect = struct( ...
            'exceedsWidth',  struct('rect', [25, 1, 10, 5],   'errorId', 'NANSEN:Stack:Crop:RectangleOutOfBounds'), ...
            'exceedsHeight', struct('rect', [1, 15, 10, 10],  'errorId', 'NANSEN:Stack:Crop:RectangleOutOfBounds'), ...
            'nonInteger',    struct('rect', [1.5, 1, 10, 10], 'errorId', 'MATLAB:validators:mustBeInteger'), ...
            'zeroWidth',     struct('rect', [1, 1, 0, 10],    'errorId', 'MATLAB:validators:mustBePositive'), ...
            'threeElements', struct('rect', [1, 1, 10],       'errorId', 'MATLAB:validation:IncompatibleSize'))
    end

    properties (Constant)
        Rect = [5, 3, 10, 8] % Columns 5-14 and rows 3-10
    end

    methods (Test)

        % ------------------------------------------------------------
        % Cropping in memory
        % ------------------------------------------------------------

        function testCropMatchesIndexedArray(testCase, stackCase)
            imageArray = createImageArray(stackCase.size);
            imageStack = nansen.stack.ImageStack(imageArray, ...
                'DataDimensionOrder', stackCase.arrangement);

            croppedStack = nansen.stack.crop(imageStack, testCase.Rect);

            testCase.verifyEqual(readAllData(croppedStack), cropArray(imageArray, testCase.Rect));
            testCase.verifyEqual(croppedStack.Data.StackDimensionArrangement, stackCase.arrangement);
            testCase.verifyFalse(croppedStack.IsVirtual);
        end

        function testOutputSizeIsExactlyHeightByWidth(testCase)
            % Unlike imcrop, which returns (height+1)-by-(width+1) pixels
            % for an integer-valued rectangle.
            imageStack = nansen.stack.ImageStack(createImageArray([20, 30, 7]));

            croppedStack = nansen.stack.crop(imageStack, [5, 3, 10, 8]);

            testCase.verifyEqual(croppedStack.ImageWidth, 10);
            testCase.verifyEqual(croppedStack.ImageHeight, 8);
            testCase.verifyEqual(croppedStack.NumTimepoints, 7);
        end

        function testRectTouchingImageEdgeIsValid(testCase)
            imageArray = createImageArray([20, 30, 7]);
            imageStack = nansen.stack.ImageStack(imageArray);
            rect = [21, 13, 10, 8]; % Ends on column 30 and row 20

            croppedStack = nansen.stack.crop(imageStack, rect);

            testCase.verifyEqual(readAllData(croppedStack), imageArray(13:20, 21:30, :));
        end

        function testFullImageRectReturnsAllData(testCase)
            imageArray = createImageArray([20, 30, 7]);
            imageStack = nansen.stack.ImageStack(imageArray);

            croppedStack = nansen.stack.crop(imageStack, [1, 1, 30, 20]);

            testCase.verifyEqual(readAllData(croppedStack), imageArray);
        end

        function testChunkLengthDoesNotChangeResult(testCase, chunkLength)
            imageArray = createImageArray([20, 30, 2, 7]);
            imageStack = nansen.stack.ImageStack(imageArray);

            croppedStack = nansen.stack.crop(imageStack, testCase.Rect, ...
                ChunkLength=chunkLength);

            testCase.verifyEqual(readAllData(croppedStack), cropArray(imageArray, testCase.Rect));
        end

        function testPermutedDimensionOrderIsKept(testCase)
            % The stack returns data as YXTC although it is stored as YXCT.
            imageArray = createImageArray([20, 30, 2, 7]);
            imageStack = nansen.stack.ImageStack(imageArray);
            imageStack.DimensionOrder = 'YXTC';

            croppedStack = nansen.stack.crop(imageStack, testCase.Rect, ChunkLength=3);

            expected = permute(cropArray(imageArray, testCase.Rect), [1, 2, 4, 3]);
            testCase.verifyEqual(readAllData(croppedStack), expected);
            testCase.verifyEqual(croppedStack.Data.StackDimensionArrangement, 'YXTC');
        end

        function testLogicalDataTypeIsKept(testCase)
            imageArray = mod(createImageArray([20, 30, 7]), 2) == 1;
            imageStack = nansen.stack.ImageStack(imageArray);

            croppedStack = nansen.stack.crop(imageStack, testCase.Rect);

            testCase.verifyClass(readAllData(croppedStack), 'logical');
            testCase.verifyEqual(readAllData(croppedStack), cropArray(imageArray, testCase.Rect));
        end

        function testAllChannelsAreKeptRegardlessOfCurrentChannel(testCase)
            imageArray = createImageArray([20, 30, 2, 7]);
            imageStack = nansen.stack.ImageStack(imageArray);
            imageStack.CurrentChannel = 1;

            croppedStack = nansen.stack.crop(imageStack, testCase.Rect);

            testCase.verifyEqual(croppedStack.NumChannels, 2);
            testCase.verifyEqual(readAllData(croppedStack), cropArray(imageArray, testCase.Rect));
        end

        % ------------------------------------------------------------
        % Metadata
        % ------------------------------------------------------------

        function testMetadataIsCopiedToCroppedStack(testCase)
            imageStack = createStackWithMetadata();

            croppedStack = nansen.stack.crop(imageStack, testCase.Rect);

            testCase.verifyEqual(croppedStack.MetaData.PhysicalSizeX, 1.5);
            testCase.verifyEqual(croppedStack.MetaData.PhysicalSizeXUnit, 'micrometer');
            testCase.verifyEqual(croppedStack.MetaData.TimeIncrement, 0.032);
            testCase.verifyEqual(croppedStack.MetaData.StartTime, datetime(2024, 1, 2, 3, 4, 5));
        end

        function testSourceStackIsUnchanged(testCase)
            % Regression guard: StackMetadata.updateFromSource clears the
            % StartTime of the source, so crop must not copy metadata
            % through it.
            imageStack = createStackWithMetadata();
            imageArray = readAllData(imageStack);

            nansen.stack.crop(imageStack, testCase.Rect);

            testCase.verifyEqual(readAllData(imageStack), imageArray);
            testCase.verifyEqual(imageStack.MetaData.StartTime, datetime(2024, 1, 2, 3, 4, 5));
            testCase.verifyEqual(imageStack.MetaData.PhysicalSizeX, 1.5);
        end

        % ------------------------------------------------------------
        % Export to file
        % ------------------------------------------------------------

        function testExportReturnsVirtualStackForNewFile(testCase, fileExtension)
            imageArray = createImageArray([20, 30, 7]);
            imageStack = nansen.stack.ImageStack(imageArray);
            filePath = fullfile(testCase.createTemporaryFolder(), ['cropped', fileExtension]);

            croppedStack = nansen.stack.crop(imageStack, testCase.Rect, FilePath=filePath);
            testCase.addTeardown(@delete, croppedStack)

            testCase.verifyTrue(isfile(filePath));
            testCase.verifyTrue(croppedStack.IsVirtual);
            testCase.verifyEqual(croppedStack.FileName, filePath);
            testCase.verifyEqual(readAllData(croppedStack), cropArray(imageArray, testCase.Rect));
        end

        function testExportedFileCanBeReopened(testCase, fileExtension)
            imageArray = createImageArray([20, 30, 7]);
            imageStack = nansen.stack.ImageStack(imageArray);
            filePath = fullfile(testCase.createTemporaryFolder(), ['cropped', fileExtension]);
            croppedStack = nansen.stack.crop(imageStack, testCase.Rect, FilePath=filePath);
            delete(croppedStack)

            reopenedStack = nansen.stack.ImageStack(filePath);
            testCase.addTeardown(@delete, reopenedStack)

            testCase.verifyEqual(readAllData(reopenedStack), cropArray(imageArray, testCase.Rect));
        end

        function testExportedBinaryFileKeepsMetadata(testCase)
            imageStack = createStackWithMetadata();
            filePath = fullfile(testCase.createTemporaryFolder(), 'cropped.raw');
            croppedStack = nansen.stack.crop(imageStack, testCase.Rect, FilePath=filePath);
            delete(croppedStack)

            reopenedStack = nansen.stack.ImageStack(filePath);
            testCase.addTeardown(@delete, reopenedStack)

            testCase.verifyEqual(reopenedStack.MetaData.PhysicalSizeX, 1.5);
            testCase.verifyEqual(reopenedStack.MetaData.TimeIncrement, 0.032);
            testCase.verifyEqual(reopenedStack.MetaData.StartTime, datetime(2024, 1, 2, 3, 4, 5));
        end

        function testExportFromVirtualMultiChannelStack(testCase, fileExtension)
            % The main use case: a stack on disk is cropped to a new file
            % in chunks, without loading the whole stack.
            imageArray = createImageArray([20, 30, 2, 9]);
            folderPath = testCase.createTemporaryFolder();
            imageStack = testCase.createVirtualStack(folderPath, imageArray, 'YXCT');
            filePath = fullfile(folderPath, ['cropped', fileExtension]);

            croppedStack = nansen.stack.crop(imageStack, testCase.Rect, ...
                FilePath=filePath, ChunkLength=4);
            testCase.addTeardown(@delete, croppedStack)

            testCase.verifyEqual(croppedStack.NumChannels, 2);
            testCase.verifyEqual(readAllData(croppedStack), cropArray(imageArray, testCase.Rect));
        end

        function testVirtualStackIsCroppedIntoMemory(testCase)
            imageArray = createImageArray([20, 30, 2, 9]);
            folderPath = testCase.createTemporaryFolder();
            imageStack = testCase.createVirtualStack(folderPath, imageArray, 'YXCT');

            croppedStack = nansen.stack.crop(imageStack, testCase.Rect, ChunkLength=4);

            testCase.verifyFalse(croppedStack.IsVirtual);
            testCase.verifyEqual(readAllData(croppedStack), cropArray(imageArray, testCase.Rect));
        end

        function testSingleFrameVirtualStackIsCroppedIntoMemory(testCase)
            % A MATLAB array can not hold the trailing singleton dimension
            % that a file with one frame has.
            imageArray = createImageArray([20, 30, 1]);
            folderPath = testCase.createTemporaryFolder();
            imageStack = testCase.createVirtualStack(folderPath, imageArray, 'YXT');

            croppedStack = nansen.stack.crop(imageStack, testCase.Rect);

            testCase.verifyEqual(readAllData(croppedStack), cropArray(imageArray, testCase.Rect));
        end

        % ------------------------------------------------------------
        % Errors
        % ------------------------------------------------------------

        function testInvalidRectThrowsError(testCase, invalidRect)
            imageStack = nansen.stack.ImageStack(createImageArray([20, 30, 7]));

            testCase.verifyError( ...
                @() nansen.stack.crop(imageStack, invalidRect.rect), invalidRect.errorId);
        end

        function testNumericArrayInputThrowsError(testCase)
            imageArray = createImageArray([20, 30, 7]);

            testCase.verifyError( ...
                @() nansen.stack.crop(imageArray, testCase.Rect), 'MATLAB:validators:mustBeA');
        end

        function testExistingFileIsNotOverwritten(testCase)
            imageStack = nansen.stack.ImageStack(createImageArray([20, 30, 7]));
            filePath = fullfile(testCase.createTemporaryFolder(), 'existing.raw');
            writelines("existing content", filePath)

            testCase.verifyError( ...
                @() nansen.stack.crop(imageStack, testCase.Rect, FilePath=filePath), ...
                'NANSEN:Stack:Crop:FileExists');
            testCase.verifyEqual(readlines(filePath, EmptyLineRule="skip"), "existing content");
        end

        function testMissingFolderThrowsError(testCase)
            imageStack = nansen.stack.ImageStack(createImageArray([20, 30, 7]));
            filePath = fullfile(testCase.createTemporaryFolder(), 'missing', 'cropped.raw');

            testCase.verifyError( ...
                @() nansen.stack.crop(imageStack, testCase.Rect, FilePath=filePath), ...
                'NANSEN:Stack:Crop:FolderNotFound');
        end

        function testUnsupportedFileFormatThrowsError(testCase)
            imageStack = nansen.stack.ImageStack(createImageArray([20, 30, 7]));
            filePath = fullfile(testCase.createTemporaryFolder(), 'cropped.xyz');

            testCase.verifyError( ...
                @() nansen.stack.crop(imageStack, testCase.Rect, FilePath=filePath), ...
                'NANSEN:Stack:Crop:FileNotCreated');
        end

        function testTiffSeriesInTargetFolderIsNotOverwritten(testCase)
            % The TIFF adapter opens a numbered series of TIFF files in the
            % target folder in place of the new file. The frames of the
            % series have the size of the crop rectangle, so writing the
            % cropped data into them would succeed.
            folderPath = testCase.createTemporaryFolder();
            seriesArray = createImageArray([8, 10, 5]);
            nansen.stack.utility.mat2tiffstack(seriesArray, fullfile(folderPath, 'part1.tif'))
            nansen.stack.utility.mat2tiffstack(seriesArray, fullfile(folderPath, 'part2.tif'))
            imageStack = nansen.stack.ImageStack(createImageArray([20, 30, 7]) + 10000);
            filePath = fullfile(folderPath, 'cropped.tif');

            testCase.verifyError( ...
                @() nansen.stack.crop(imageStack, testCase.Rect, FilePath=filePath), ...
                'NANSEN:Stack:Crop:ExistingFileOpened');
            testCase.verifyEqual(tiffreadVolume(fullfile(folderPath, 'part1.tif')), seriesArray);
            testCase.verifyEqual(tiffreadVolume(fullfile(folderPath, 'part2.tif')), seriesArray);
        end
    end

    methods (Access = private)

        function imageStack = createVirtualStack(testCase, folderPath, imageArray, dimArrangement)
            %createVirtualStack Create a stack for a binary file holding imageArray
            filePath = fullfile(folderPath, 'source.raw');
            virtualData = nansen.stack.open(filePath, size(imageArray, 1:numel(dimArrangement)), ...
                class(imageArray), 'DataDimensionArrangement', dimArrangement);

            subs = repmat({':'}, 1, numel(dimArrangement));
            virtualData(subs{:}) = imageArray;

            imageStack = nansen.stack.ImageStack(virtualData);
            % The file must be closed before the temporary folder is removed
            testCase.addTeardown(@delete, virtualData)
        end
    end
end

function imageArray = createImageArray(arraySize)
%createImageArray Create a uint16 array where every element is unique
    imageArray = reshape(uint16(1:prod(arraySize)), arraySize);
end

function croppedArray = cropArray(imageArray, rect)
%cropArray Crop the two first dimensions of an array with up to 5 dimensions
    rowInd = rect(2):(rect(2) + rect(4) - 1);
    columnInd = rect(1):(rect(1) + rect(3) - 1);
    croppedArray = imageArray(rowInd, columnInd, :, :, :);
end

function data = readAllData(imageStack)
%readAllData Read all channels, planes and timepoints of a stack
    subs = repmat({':'}, 1, ndims(imageStack.Data));
    data = imageStack.Data(subs{:});
end

function imageStack = createStackWithMetadata()
%createStackWithMetadata Create a stack whose metadata differs from defaults
    imageStack = nansen.stack.ImageStack(createImageArray([20, 30, 7]));
    imageStack.MetaData.PhysicalSizeX = 1.5;
    imageStack.MetaData.PhysicalSizeXUnit = 'micrometer';
    imageStack.MetaData.TimeIncrement = 0.032;
    imageStack.MetaData.StartTime = datetime(2024, 1, 2, 3, 4, 5);
end
