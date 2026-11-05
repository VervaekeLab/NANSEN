function croppedStack = crop(imageStack, rect, options)
%CROP - Crop an image stack to a rectangle
%   croppedStack = nansen.stack.crop(imageStack,RECT) crops every frame
%   of the nansen.stack.ImageStack object imageStack to the rectangle
%   RECT and returns the result as a new ImageStack with the data in
%   memory. RECT is a four-element vector [XMIN,YMIN,WIDTH,HEIGHT] of
%   pixel indices, where XMIN and YMIN are the column and row of the
%   upper left pixel to keep. The cropped stack has exactly HEIGHT rows
%   and WIDTH columns, and RECT must lie within the image. All channels,
%   planes and timepoints are kept, regardless of the CurrentChannel and
%   CurrentPlane of imageStack. The metadata of imageStack is copied to
%   the cropped stack.
%
%   croppedStack = nansen.stack.crop(imageStack,RECT,FilePath=FILEPATH)
%   writes the cropped data to the file FILEPATH instead of keeping it
%   in memory, and returns a virtual ImageStack for that file. The file
%   extension selects the file format, which must be a format that
%   nansen.stack.open can create: binary (.raw) or TIFF (.tif, .tiff).
%   The file must not already exist. Creating a TIFF file allocates the
%   whole cropped stack in memory, so use a binary file for stacks that
%   are larger than the available memory.
%
%   croppedStack = nansen.stack.crop(...,ChunkLength=N) reads and writes
%   N frames at a time. Frames are counted along the time dimension, or
%   along the plane dimension for stacks without a time dimension. By
%   default, N is chosen from the available memory.
%
%   Example: Crop a 100-by-200 pixel region and save it to a binary file
%       imageStack = nansen.stack.ImageStack(rand(256,256,50,"single"));
%       filePath = [tempname, '.raw'];
%       croppedStack = nansen.stack.crop(imageStack,[31,21,200,100], ...
%           FilePath=filePath);
%       size(croppedStack.Data)
%
%   See also nansen.stack.ImageStack, nansen.stack.open, imcrop

arguments
    imageStack {mustBeA(imageStack, "nansen.stack.ImageStack"), ...
        mustBeScalarOrEmpty, mustBeNonempty}
    rect (1,4) {mustBeNumeric, mustBeReal, mustBeInteger, mustBePositive}
    options.FilePath {mustBeTextScalar} = ""
    options.ChunkLength (1,1) {mustBeNumeric, mustBeReal, mustBeInteger, ...
        mustBePositive} = chooseChunkLength(imageStack)
end

rect = double(rect);
filePath = string(options.FilePath);
saveToFile = strlength(filePath) > 0;

xInd = rect(1):(rect(1) + rect(3) - 1);
yInd = rect(2):(rect(2) + rect(4) - 1);
assertRectangleWithinImage(imageStack, rect, xInd, yInd)

if saveToFile
    assertFileCanBeCreated(filePath)
end

% Subscripts and sizes follow the dimension arrangement of the data as it
% is returned from the stack, which is not necessarily Y, X, C, Z, T.
dimArrangement = imageStack.Data.StackDimensionArrangement;
numDims = numel(dimArrangement);
dimX = imageStack.getDimensionNumber('X');
dimY = imageStack.getDimensionNumber('Y');

sourceSize = size(imageStack.Data, 1:numDims);
croppedSize = sourceSize;
croppedSize(dimX) = numel(xInd);
croppedSize(dimY) = numel(yInd);

sourceSubs = arrayfun(@(n) 1:n, sourceSize, 'UniformOutput', false);
sourceSubs{dimX} = xInd;
sourceSubs{dimY} = yInd;
croppedSubs = arrayfun(@(n) 1:n, croppedSize, 'UniformOutput', false);

if saveToFile
    croppedData = createVirtualData(filePath, croppedSize, ...
        imageStack.DataType, dimArrangement);
else
    croppedData = zeros(croppedSize, 'like', cast(0, imageStack.DataType));
end

chunkDimName = getChunkDimensionName(imageStack);
if isempty(chunkDimName)
    % A single image has no dimension to split into chunks
    croppedData(croppedSubs{:}) = imageStack.Data(sourceSubs{:});
else
    chunkDim = imageStack.getDimensionNumber(chunkDimName);
    [frameIndices, numChunks] = imageStack.getChunkedFrameIndices( ...
        options.ChunkLength, [], chunkDimName);

    for iChunk = 1:numChunks
        sourceSubs{chunkDim} = frameIndices{iChunk};
        croppedSubs{chunkDim} = frameIndices{iChunk};
        croppedData(croppedSubs{:}) = imageStack.Data(sourceSubs{:});
    end
end

if saveToFile
    croppedStack = nansen.stack.ImageStack(croppedData);
else
    % MATLAB drops trailing singleton dimensions from arrays, so the
    % arrangement is shortened to the dimensions the array has.
    arrayDimArrangement = dimArrangement(1:ndims(croppedData));
    croppedStack = nansen.stack.ImageStack(croppedData, ...
        'DataDimensionOrder', arrayDimArrangement);
end

copyMetadata(imageStack.MetaData, croppedStack.MetaData)
if saveToFile
    croppedStack.Data.writeMetadata()
end
end

function assertRectangleWithinImage(imageStack, rect, xInd, yInd)
%assertRectangleWithinImage Throw error if rectangle exceeds the image
    imageWidth = imageStack.ImageWidth;
    imageHeight = imageStack.ImageHeight;

    if xInd(end) > imageWidth || yInd(end) > imageHeight
        error('NANSEN:Stack:Crop:RectangleOutOfBounds', ...
            ['The crop rectangle %s extends outside the image, which ', ...
            'is %d pixels wide and %d pixels high. Specify a rectangle ', ...
            '[xmin, ymin, width, height] that lies within the image.'], ...
            mat2str(rect), imageWidth, imageHeight)
    end
end

function virtualData = createVirtualData(filePath, dataSize, dataType, dimArrangement)
%createVirtualData Create a file for a stack and return its virtual data
    try
        virtualData = nansen.stack.open(char(filePath), dataSize, ...
            dataType, 'DataDimensionArrangement', dimArrangement);
    catch cause
        exception = MException('NANSEN:Stack:Crop:FileNotCreated', ...
            ['Could not create the file "%s". The file formats that can ', ...
            'be created are binary (.raw) and TIFF (.tif, .tiff).'], ...
            filePath);
        exception = exception.addCause(cause);
        throw(exception)
    end

    % A file adapter can resolve the path to other files. The TIFF adapter
    % does this when the folder holds a numbered series of TIFF files,
    % which it opens as one multi-part stack. Writing the cropped data
    % would then overwrite those files.
    [~, requestedName, requestedExt] = fileparts(filePath);
    [~, openedName, openedExt] = fileparts(virtualData.FilePath);
    if ~strcmp(requestedName + requestedExt, [openedName, openedExt])
        error('NANSEN:Stack:Crop:ExistingFileOpened', ...
            ['The file "%s" was not created, because the existing file ', ...
            '"%s" was opened in its place. This happens when the folder ', ...
            'holds a numbered series of TIFF files. Specify a file path ', ...
            'in another folder.'], filePath, virtualData.FilePath)
    end

    % Make the file return data in the same arrangement as the source, so
    % that the same subscripts address both.
    virtualData.StackDimensionArrangement = dimArrangement;
end

function assertFileCanBeCreated(filePath)
%assertFileCanBeCreated Throw error if file exists or folder is missing
    if isfile(filePath)
        % An existing file would be opened and written into instead of
        % being created with the size of the cropped stack.
        error('NANSEN:Stack:Crop:FileExists', ...
            ['The file "%s" already exists. Delete the file or specify ', ...
            'another file path.'], filePath)
    end

    folderPath = fileparts(filePath);
    if strlength(folderPath) > 0 && ~isfolder(folderPath)
        error('NANSEN:Stack:Crop:FolderNotFound', ...
            ['The folder "%s" does not exist. Create the folder or ', ...
            'specify another file path.'], folderPath)
    end
end

function chunkDimName = getChunkDimensionName(imageStack)
%getChunkDimensionName Get letter of the dimension to split into chunks
    dimArrangement = imageStack.Data.StackDimensionArrangement;

    if contains(dimArrangement, 'T')
        chunkDimName = 'T';
    elseif contains(dimArrangement, 'Z')
        chunkDimName = 'Z';
    else
        chunkDimName = '';
    end
end

function chunkLength = chooseChunkLength(imageStack)
%chooseChunkLength Choose number of frames per chunk from available memory
    chunkDimName = getChunkDimensionName(imageStack);

    if isempty(chunkDimName)
        chunkLength = 1;
    else
        chunkLength = imageStack.chooseChunkLength([], [], chunkDimName);
        % The ImageStack method can return a fractional or non-finite
        % number of frames
        chunkLength = max(1, floor(chunkLength));
    end
end

function copyMetadata(sourceMetadata, croppedMetadata)
%copyMetadata Copy the metadata that stays valid when a stack is cropped
%
%   StackMetadata.updateFromSource is not used for this, because it clears
%   the StartTime of the source metadata.

    propertyNames = ["PhysicalSizeX", "PhysicalSizeXUnit", ...
        "PhysicalSizeY", "PhysicalSizeYUnit", ...
        "PhysicalSizeZ", "PhysicalSizeZUnit", ...
        "TimeIncrement", "TimeIncrementUnit", "StartTime", ...
        "SpatialPosition", "ChannelDescription", "ChannelIndicator", ...
        "ChannelColor", "FrameTimes", "FramePositions"];

    for propertyName = propertyNames
        croppedMetadata.(propertyName) = sourceMetadata.(propertyName);
    end
end
