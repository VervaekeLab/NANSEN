function [signalArray, P] = extractF(imageData, roiArray, varargin)
%extractF Extract RoI signals from an image stack in chunkwise manner
%
%   signals = extractF(imageStack, roiArray) extracts signals for rois in
%   roiArray from image frames in imageData using default settings.
%   roiArray must be a nansen.RoiArray object and imageData can be a
%   numeric array of three or more dimensions or a nansen.ImageStack
%   object.
%   
%   signals = extractF(imageStack, roiArray, params) extracts signals
%   using options specified in params. Params gan be given as a 
%   struct or as a cell array of name-value pairs.
%
%   Parameters:
%       
%   roiInd : integer vector in range [1, numRois]
%       List of roi indices (use for extraction of signals from a subset
%       of rois). Default : extract signals from all rois.
%   imageMask : logical matrix (imageHeight x imageWidth)
%       Use for excluding regions of image. Include pixels that are true 
%       and exclude pixels that are false. Default : include all pixels
%   excludeRoiOverlaps : logical scalar
%       Exclude pixels where rois are overlapping. Default = true
%   createNeuropilMask : logical scalar
%       Create mask (and extract signals) for surrounding neuropil regions
%       Default = true
%   excludeRoiFromNeuropil : logical scalar
%       Exclude rois from neuropil regions. Default = true
%
%   See also nansen.twophoton.roisignals.extract.getDefaultParameters

    % Todo:
    %   [x] Implement a standard set of options across signal extraction
    %       functions and subfunctions
    %
    %   [ ] Implemnt struct array of options for computing multiple
    %       versions of signals????
    %
    %   [x] Make sure it works to extract from subset of rois....
    %   [ ] Test that it works as expected. I.e do we get signals from
    %   requested rois, and are masks created according to options. Use
    %   imviewer/roimanager gui for this...
    %
    %   [ ] Extraction function should depend on number of rois. If nRois <
    %       140 should use looping over rois and array cropping, otherwise
    %       use the matrix multiplication method. Is 140 system
    %       independent? I.e does it depend on memory/cpu?
    %
    %   [ ] Support for multiple channels.
    %
    %   [ ] Support for multiple planes.


    % Get default parameters and assertion functions.
    
    [P, V] = nansen.twophoton.roisignals.extract.getDefaultParameters();
    P.showTimer      = false;    V.showTimer = @(x) assert(islogical(x), 'Value must be logical');
    P.signalDataType = 'single'; V.signalDataType = @(x) assert(any(strcmp(x, {'single', 'double'})), 'Value must be ''single'' or ''double''');
    
    % Parse potential parameters from input arguments
    params = utility.parsenvpairs(P, V, varargin{:});

    
    % Validate the input image data. If ImageStack, all is good, if 
    % numeric, an ImageStack object is returned, otherwise throws error.
    imageStack = nansen.stack.ImageStack.validate(imageData);
    
    validateInputDimensions(imageStack, roiArray) % Local function
    
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
            blockSize = imageStack.chooseChunkLength(class(imageStack.imageData));
        else
            blockSize = imageStack.NumTimepoints;
        end
    else
        blockSize = imageStack.chooseChunkLength('double');
    end
    
    % Get indices for different parts/blocks
    [IND, numParts] = imageStack.getChunkedFrameIndices(blockSize);
    
    elapsedTime = 0;
    signalExtractionFcn = params.extractFcn;
    
    % Loop through blocks and extract signals.
    for iPart = 1:numParts
        
        iIND = IND{iPart}; 
        imData = imageStack.getFrameSet( iIND );
        
        tInit = tic;
        signalArray(iIND, :, :) = signalExtractionFcn(imData, roiData);
        elapsedTime = elapsedTime + toc(tInit);
    end
    
    % Display elapsed time as output if requested.
    if params.showTimer
        fprintf('Signal extraction completed in %.2f seconds\n', ...
            elapsedTime)
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

