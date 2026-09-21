function [signalArray, params] = extractF(imageData, roiData, optionsStruct, options)
%extractF - Extract roi signals from an image stack
%   signalArray = extractF(imageData,roiData) computes the mean pixel
%   value of each roi in roiData for every frame of imageData. imageData
%   is a nansen.stack.ImageStack or a numeric array of size
%   imageHeight-by-imageWidth-by-numFrames. roiData is an array of RoI
%   objects or a roimanager.roiGroup, and the imagesize property of the
%   rois must equal [imageHeight, imageWidth]. signalArray is of size
%   numFrames-by-numSubregions-by-numRois. signalArray(:,1,:) holds the
%   signals of the rois and signalArray(:,2:end,:) holds the signals of
%   the neuropil masks that are created around each roi. Frames are read
%   and processed in chunks if imageData is a virtual stack or if there
%   are 100 rois or more. The chooseChunkLength method of
%   nansen.stack.ImageStack sets the number of frames in a chunk.
%
%   signalArray = extractF(imageData,roiData,optionsStruct) specifies
%   options as fields of the scalar struct optionsStruct. The field names
%   are the names of the name-value arguments below. Fields with other
%   names are ignored, so that optionsStruct can be the struct returned
%   by nansen.twophoton.roisignals.extract.getDefaultParameters.
%
%   signalArray = extractF(...,Name=VALUE) specifies options using one or
%   more name-value arguments. An option given by name replaces the field
%   of the same name in optionsStruct. An option that is not given takes
%   its default value from
%   nansen.twophoton.roisignals.extract.getDefaultParameters:
%       roiInd                  - Indices of the rois to extract signals
%                                 for, or "all" (default).
%       imageMask               - Logical matrix of size
%                                 imageHeight-by-imageWidth. Pixels that
%                                 are false are left out of the neuropil
%                                 masks. The roi masks are not affected.
%                                 The default includes all pixels.
%       pixelComputationMethod  - Statistic that is computed over the
%                                 pixels of a mask, "mean" (default) or
%                                 "median". "median" is always computed
%                                 by serialExtract.
%       excludeRoiOverlaps      - True (default) leaves pixels that
%                                 belong to more than one roi out of the
%                                 roi masks.
%       createNeuropilMask      - True (default) creates a neuropil mask
%                                 around each roi and extracts its
%                                 signal.
%       excludeRoiFromNeuropil  - True (default) leaves the pixels of
%                                 all rois out of the neuropil masks.
%       neuropilExpansionFactor - Number of pixels in a neuropil mask
%                                 relative to the number of pixels in
%                                 its roi. The default is 4.
%       cellNeuropilSeparation  - Number of one-pixel steps that the
%                                 rois are grown by before their pixels
%                                 are left out of the neuropil masks.
%                                 The default is 0.
%       numNeuropilSlices       - Number of slices that each neuropil
%                                 mask is split into. Each slice is one
%                                 subregion in signalArray. The default
%                                 is 1.
%       maxNeuropilRadius       - Not used.
%       extractFcn              - Handle of the function that extracts
%                                 the signals from a chunk of frames.
%                                 The default is serialExtract for fewer
%                                 than 200 rois and batchExtract for 200
%                                 rois or more. Both are in the package
%                                 nansen.twophoton.roisignals.extract.
%       roiMaskFormat           - Format of the prepared roi masks,
%                                 "struct" for serialExtract and
%                                 "sparse" for batchExtract. It is set
%                                 to match extractFcn.
%       signalDataType          - Class of signalArray, "single"
%                                 (default) or "double".
%       channelNum              - Channels to extract signals from if
%                                 imageData has more than one current
%                                 channel. The signals of the channels
%                                 are concatenated along the third
%                                 dimension of signalArray. If roiData
%                                 is an array of roimanager.roiGroup
%                                 objects, roiData(i) is used for
%                                 channel i. The default is 1.
%       verbose                 - True prints a message for each chunk
%                                 of frames and the elapsed time. The
%                                 default is false.
%       showTimer               - True prints the elapsed time. The
%                                 default is false.
%
%   [signalArray,PARAMS] = extractF(...) also returns the options that
%   were used, as a scalar struct with one field for each name-value
%   argument. PARAMS.roiInd holds the indices of the rois,
%   PARAMS.imageMask the image mask that was applied, and
%   PARAMS.extractFcn and PARAMS.roiMaskFormat the extraction function
%   and the mask format that were selected. If imageData has more than
%   one current channel, these four fields hold the values that were
%   given, because they are resolved separately for each channel.
%
%   Example: Extract the signal of one roi from a numeric array
%       imageData = rand(64,64,100);
%       roiArray = RoI("Circle",[32,32,5],[64,64]);
%       signalArray = nansen.twophoton.roisignals.extractF( ...
%           imageData,roiArray,createNeuropilMask=false);
%       plot(signalArray)
%
%   See also nansen.twophoton.roisignals.computeDff,
%   nansen.twophoton.roisignals.extract.getDefaultParameters,
%   nansen.processing.roi.prepareRoiMasks, nansen.stack.ImageStack, RoI

    % Todo:
    %   [x] Implement a standard set of options across signal extraction
    %       functions and subfunctions
    %
    %   [ ] Implement struct array of options for computing multiple
    %       versions of signals????
    %
    %   [x] Make sure it works to extract from subset of rois....
    %   [x] Test that it works as expected. I.e do we get signals from
    %   requested rois, and are masks created according to options. See
    %   nansen.unittest.roisignals.ExtractFTest
    %
    %   [ ] Extraction function should depend on number of rois. If nRois <
    %       140 should use looping over rois and array cropping, otherwise
    %       use the matrix multiplication method. Is 140 system
    %       independent? I.e does it depend on memory/cpu?
    %
    %   [ ] Support for multiple channels.
    %
    %   [ ] Support for multiple planes.

    arguments
        imageData
        roiData
        optionsStruct struct {mustBeScalarOrEmpty} = struct.empty
        options.roiInd {mustBeRoiIndices}
        options.imageMask (:,:) logical
        options.pixelComputationMethod {mustBeTextScalar, ...
            mustBeMember(options.pixelComputationMethod, ["mean", "median"])}
        options.excludeRoiOverlaps (1,1) logical
        options.createNeuropilMask (1,1) logical
        options.excludeRoiFromNeuropil (1,1) logical
        options.neuropilExpansionFactor (1,1) {mustBeNumeric, mustBeReal, mustBePositive}
        options.cellNeuropilSeparation (1,1) {mustBeNumeric, mustBeReal, mustBeInteger, mustBeNonnegative}
        options.numNeuropilSlices (1,1) {mustBeNumeric, mustBeReal, mustBeInteger, mustBeNonnegative}
        options.maxNeuropilRadius (1,1) {mustBeNumeric, mustBeReal, mustBeInteger, mustBeNonnegative}
        options.roiMaskFormat {mustBeTextScalar, ...
            mustBeMember(options.roiMaskFormat, ["sparse", "struct"])}
        options.extractFcn {mustBeFunctionHandleOrEmpty}
        options.showTimer (1,1) logical
        options.verbose (1,1) logical
        options.signalDataType {mustBeTextScalar, ...
            mustBeMember(options.signalDataType, ["single", "double"])}
        options.channelNum {mustBeNumeric, mustBeReal, mustBeInteger, mustBePositive, mustBeNonempty}
    end

    % Options in a struct are passed on as name-value arguments, so that
    % they are validated in the same way as options given by name. No
    % option has a default value in the arguments block, because a default
    % value could not be told apart from a value given by name, and would
    % replace the value in the struct.
    if ~isempty(optionsStruct)
        nvPairs = combineOptions(optionsStruct, options); % Local function
        [signalArray, params] = nansen.twophoton.roisignals.extractF( ...
            imageData, roiData, nvPairs{:});
        return
    end

    params = addDefaultValues(options); % Local function

    % Validate roidata
    if isa(roiData, 'roimanager.roiGroup')
        roiArray = roiData.roiArray;
    elseif isa(roiData, 'RoI')
        roiArray = roiData;
    else
        error('Unknown data type for roiData input')
    end

    % Validate the input image data. If ImageStack, all is good, if
    % numeric, an ImageStack object is returned, otherwise throws error.
    imageStack = nansen.stack.ImageStack.validate(imageData);

    validateInputDimensions(imageStack, roiArray) % Local function

    % If multiple channels are selected, extract from each individually
    numChannels = numel( imageStack.CurrentChannel );
    if numChannels > 1
        nvPairs = namedargs2cell(options);
        if ~isempty(params.channelNum)
            currentChannel = imageStack.CurrentChannel;
            imageStack.CurrentChannel = params.channelNum;
            signalArray = extractFromMultipleChannels(imageStack, roiData, nvPairs{:});
            imageStack.CurrentChannel = currentChannel;
        else
            signalArray = extractFromMultipleChannels(imageStack, roiData, nvPairs{:});
        end
        return
    end

    % Update some fields in parameters if they are not set.
    params = updateParameters(params, imageStack, roiArray); % Local function

    % Count number of rois to extract signals for
    numRois = numel(params.roiInd);

    % Prepare array of RoIs for efficient signal extraction:
    roiData = nansen.processing.roi.prepareRoiMasks(roiArray, params);

    % Allocate array for collecting extracted signals
    numSubRegions = params.numNeuropilSlices .* params.createNeuropilMask + 1; % Add 1 for the main roi
    signalArraySize = [ imageStack.NumTimepoints, numSubRegions, numRois ];
    signalArray = zeros(signalArraySize, params.signalDataType);

    % Determine block size for signal extraction.
    if numRois < 100
        if imageStack.IsVirtual
            %blockSize = imageStack.getBatchSize(class(imageStack.imageData));
            blockSize = imageStack.chooseChunkLength(imageStack.DataType);
        else
            blockSize = imageStack.NumTimepoints;
        end
    else
        blockSize = imageStack.chooseChunkLength('double');
    end

    % Get indices for different parts/blocks
    [IND, numParts] = imageStack.getChunkedFrameIndices(blockSize);

    [elapsedTimeLoad, elapsedTimeExtract] = deal( 0 );
    signalExtractionFcn = params.extractFcn;

    if params.verbose
        fprintf('Image stack is split in %d parts for signal extraction\n', numParts)
    end

    % Loop through blocks and extract signals.
    for iPart = 1:numParts

        tInitLoad = tic;
        iIND = IND{iPart};
        imData = imageStack.getFrameSet( iIND );
        elapsedTimeLoad = elapsedTimeLoad + toc(tInitLoad);

        tInitExtract = tic;
        signalArray(iIND, :, :) = signalExtractionFcn(imData, roiData, params);
        elapsedTimeExtract = elapsedTimeExtract + toc(tInitExtract);

        if params.verbose
            fprintf('Signal Extraction: Finished part %d/%d\n', iPart, numParts)
        end
    end

    % Display elapsed time as output if requested.
    if params.showTimer || params.verbose
        fprintf('Signal extraction completed in %.2f seconds\n', ...
            elapsedTimeLoad + elapsedTimeExtract)
    end
end

function params = addDefaultValues(options)
%addDefaultValues - Add the default value of each option that is not given
    params = nansen.twophoton.roisignals.extract.getDefaultParameters();

    % Remove the fields that configure the options editor. The name of
    % such a field is the name of a parameter followed by an underscore.
    names = string(fieldnames(params));
    isConfigField = endsWith(names, "_") & ...
        ismember(extractBefore(names, strlength(names)), names);
    params = rmfield(params, names(isConfigField));

    % Options of extractF that are not parameters of the extraction
    % functions
    params.showTimer = false;
    params.verbose = false;
    params.signalDataType = "single";
    params.channelNum = 1;

    names = fieldnames(options);
    for i = 1:numel(names)
        params.(names{i}) = options.(names{i});
    end
end

function nvPairs = combineOptions(optionsStruct, options)
%combineOptions - Combine an options struct with name-value arguments
%   Fields of optionsStruct that are not options of extractF are left out.
%   A field of options replaces the field of the same name in
%   optionsStruct.
    optionNames = fieldnames(addDefaultValues(struct()));

    fieldNames = fieldnames(optionsStruct);
    isOption = ismember(fieldNames, optionNames);
    combined = rmfield(optionsStruct, fieldNames(~isOption));

    names = fieldnames(options);
    for i = 1:numel(names)
        combined.(names{i}) = options.(names{i});
    end

    nvPairs = namedargs2cell(combined);
end

function mustBeRoiIndices(value)
%mustBeRoiIndices - Validate that value is "all" or a vector of indices
    isAll = (ischar(value) || isstring(value)) && isequal(string(value), "all");
    isIndexVector = isnumeric(value) && isvector(value) && isreal(value) ...
        && all(value == round(value)) && all(value >= 1);

    if ~(isAll || isIndexVector)
        error("NANSEN:RoiSignals:InvalidRoiIndices", ...
            "Value must be ""all"" or a vector of positive integers.")
    end
end

function mustBeFunctionHandleOrEmpty(value)
%mustBeFunctionHandleOrEmpty - Validate that value is a function handle or empty
    if ~(isempty(value) || isa(value, "function_handle"))
        error("NANSEN:RoiSignals:InvalidExtractFcn", ...
            "Value must be a function handle or empty.")
    end
end

function validateInputDimensions(imageStack, roiArray)
%validateInputDimensions Check that ImageStack and roiArray has matching
% dimensions.

    msg = 'Dimensions of ImageStack and RoiArray are not matching';

    imageSize = [imageStack.ImageHeight, imageStack.ImageWidth];
    roiSize = roiArray(1).imagesize;

    assert( isequal(roiSize, imageSize), msg);
end

function params = updateParameters(params, imageStack, roiArray)
%updateParameters Update parameters that depend on data dimensions
%
%   Set value of imageMask if it is empty. (Depends on imageStack)
%   Set roi indices if roiInd is set to 'all'. (Depends on roiArray)
%   Set extractionFcn and roiMaskFormat if they are not set. (Depends on number of rois)

    % Create the imageMask if it is empty
    if isempty(params.imageMask)
        imageSize = [imageStack.ImageHeight, imageStack.ImageWidth];
        params.imageMask = true(imageSize);
    end

    % Specify roi indices if the value is set to 'all'
    if strcmp(params.roiInd, 'all')
        numRois = numel(roiArray);
        params.roiInd = 1:numRois;
    end

    % Only serial extract supports median/percentile methods.
    if ~strcmp( params.pixelComputationMethod, 'mean' )
        params.extractFcn = @nansen.twophoton.roisignals.extract.serialExtract;
    end

    % Count number of rois to extract signals for.
    numRois = numel(params.roiInd);

    % Determine which extraction function to use. SerialExtract is faster
    % for fewer rois and batchExtract is faster for more rois.
    % Todo: Find out if the 200 threshold depends on memory/cpu
    if numRois < 200 && isempty(params.extractFcn)
        params.extractFcn = @nansen.twophoton.roisignals.extract.serialExtract;
        params.roiMaskFormat = 'struct';

    elseif numRois >= 200 && isempty(params.extractFcn)
        params.extractFcn = @nansen.twophoton.roisignals.extract.batchExtract;
        params.roiMaskFormat = 'sparse';

    elseif isequal(params.extractFcn, @nansen.twophoton.roisignals.extract.serialExtract)
        if ~strcmp(params.roiMaskFormat, 'struct')
            params.roiMaskFormat = 'struct';
            msg = ['Roi mask format was changed to ''struct'' because ', ...
                'the selected extraction function is "serialExtract".'];
            warning(msg);
        end

    elseif isequal(params.extractFcn, @nansen.twophoton.roisignals.extract.batchExtract)
        if ~strcmp(params.roiMaskFormat, 'sparse')
            params.roiMaskFormat = 'sparse';
            msg = ['Roi mask format was changed to ''sparse'' because ', ...
                'the selected extraction function is "batchExtract".'];
            warning(msg);
        end
    end
end

function signalArray = extractFromMultipleChannels(imageStack, roiData, varargin)
    currentChannels = imageStack.CurrentChannel;
    numChannels = numel(currentChannels);
    signalArray = cell(numChannels, 1);

    for i = currentChannels
        imageStack.CurrentChannel = i;
        if isa(roiData, 'roimanager.roiGroup')
            iRoiData = roiData(i);
        elseif isa(roiData, 'RoI')
            iRoiData = roiData;
        else
            error('Unknown roi format for multichannel signal extraction. Please contact support.')
        end
        signalArray{i} = nansen.twophoton.roisignals.extractF(imageStack, iRoiData, varargin{:});
    end
    %signalArray = cellfun(@(c) reshape(c, [1, size(c)]), signalArray, 'UniformOutput', false);
    signalArray = cat(ndims(signalArray)+1, signalArray{:});
    imageStack.CurrentChannel = currentChannels;
end
