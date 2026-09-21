function neuropilMasks = estimateNeuropilMasks(roiMasks, options)
%estimateNeuropilMasks - Create a mask of the neuropil around each roi
%   neuropilMasks = estimateNeuropilMasks(roiMasks) creates one neuropil
%   mask for each roi mask. roiMasks is a logical array of size
%   imageHeight-by-imageWidth-by-numRois and neuropilMasks is a logical
%   array of the same size. A neuropil mask is grown from its roi mask in
%   steps of one pixel. The first step adds the four edge neighbors of
%   each mask pixel, the second step adds the four corner neighbors, and
%   the following steps alternate between the two. Growing stops when
%   the mask holds at least neuropilExpansionFactor times as many pixels
%   as the roi, or after 101 steps. The pixels of a roi are never part of
%   its own neuropil mask. Pixels that imageMask or excludeRoiFromNeuropil
%   leave out of the neuropil masks are not counted.
%
%   neuropilMasks = estimateNeuropilMasks(roiMasks,Name=VALUE) specifies
%   options using one or more name-value arguments. An option that is not
%   given takes its default value from
%   nansen.twophoton.roisignals.extract.getDefaultParameters:
%       roiInd                  - Indices of the rois to create neuropil
%                                 masks for, or "all" (default). The
%                                 third dimension of neuropilMasks
%                                 follows the order of roiInd.
%       imageMask               - Logical matrix of size
%                                 imageHeight-by-imageWidth. Pixels that
%                                 are false are left out of all neuropil
%                                 masks. The default is empty, which
%                                 leaves out no pixels.
%       excludeRoiFromNeuropil  - True (default) leaves the pixels of
%                                 all rois in roiMasks out of all
%                                 neuropil masks.
%       neuropilExpansionFactor - Number of pixels in a neuropil mask
%                                 relative to the number of pixels in its
%                                 roi. The default is 4.
%       cellNeuropilSeparation  - Number of one-pixel steps that the
%                                 rois are grown by before their pixels
%                                 are left out of the neuropil masks. It
%                                 has no effect if excludeRoiFromNeuropil
%                                 is false. The default is 0.
%
%   Example: Neuropil mask around one of two neighboring rois
%       roiMasks = false(64,64,2);
%       roiMasks(20:30,20:30,1) = true;
%       roiMasks(20:30,34:44,2) = true;
%       neuropilMasks = nansen.processing.roi.estimateNeuropilMasks( ...
%           roiMasks,roiInd=1);
%       imagesc(neuropilMasks + 2*any(roiMasks,3))
%
%   See also nansen.processing.roi.createMasks,
%   nansen.processing.roi.prepareRoiMasks,
%   nansen.twophoton.roisignals.extractF,
%   nansen.twophoton.roisignals.extract.getDefaultParameters

    % TODO
    %   [ ] Stop growing at the maxNeuropilRadius parameter instead of
    %       after a fixed number of steps.
    %   [ ] Add warning if mask can't be created (i.e not enough neuropil
    %       available)

    arguments
        roiMasks logical
        options.roiInd {mustBeRoiIndices}
        options.imageMask (:,:) logical
        options.excludeRoiFromNeuropil (1,1) logical
        options.neuropilExpansionFactor (1,1) {mustBeNumeric, mustBeReal, mustBePositive}
        options.cellNeuropilSeparation (1,1) {mustBeNumeric, mustBeReal, mustBeInteger, mustBeNonnegative}
    end

    [height, width, numRois] = size(roiMasks);

    params = addDefaultValues(options);

    if isIndexOfAllRois(params.roiInd)
        params.roiInd = 1:numRois;
    end

    hasImageMask = ~isempty(params.imageMask);
    if hasImageMask && ~isequal(size(params.imageMask), [height, width])
        error("NANSEN:RoiSignals:ImageMaskSizeMismatch", ...
            "The size of imageMask is %s, but the size of the roi masks is %s. " + ...
            "Give an imageMask with one element for each pixel of a roi mask.", ...
            mat2str(size(params.imageMask)), mat2str([height, width]))
    end

    % Create mask of pixel to ignore when creating neuropil masks
    if params.excludeRoiFromNeuropil
        % Create an array with all rois overlapping.
        footprintAllRois = sum(roiMasks, 3) >= 1;

        % Use binary dilation to add pixels in the vicinity of main rois
        for i = 1:params.cellNeuropilSeparation
            footprintAllRois = imdilateoddeven(footprintAllRois, i);
        end

        % Ignore a pixel if it belongs to a roi or if it is excluded by
        % the image mask
        if hasImageMask
            pixelsToIgnore = footprintAllRois | ~params.imageMask;
        else
            pixelsToIgnore = footprintAllRois;
        end
    else
        if hasImageMask
            pixelsToIgnore = ~params.imageMask;
        else
            pixelsToIgnore = [];
        end
    end

    % Allocate array for neuropil masks.
    neuropilMasks = false( height, width, numel(params.roiInd) );

    % Loop through rois
    for n = 1:numel(params.roiInd)

        currentRoiInd = params.roiInd(n);
        currentRoiMask = roiMasks(:, :, currentRoiInd);

        thisMask = currentRoiMask;
        origArea = sum(currentRoiMask(:));  % original area
        maxArea = numel(currentRoiMask) - origArea;

        targetArea = min([maxArea, params.neuropilExpansionFactor * origArea]);

        currentArea = 0;                    % current area
        count = 0;

        while currentArea < targetArea && count <= 100

            % Grow mask using odd-even dilation from fissa
            thisMask = imdilateoddeven(thisMask, count);

            % Don't include pixels which are not in the original roi
            thisMask(currentRoiMask) = false;

            % Also, don't include pixels that are in the mask containing
            % the foot print of all rois (with margins...) when updating
            % the area.
            tmpMask = thisMask;

            if ~isempty(pixelsToIgnore)
                tmpMask(pixelsToIgnore) = false;
            end

            % Update area
            currentArea = sum(tmpMask(:));

            % iterate counter
            count = count + 1;

            if count == 99
                warning('Could not create npmask for roi %d', currentRoiInd)
            end
        end

        % Refine the final neuropil mask
        if ~isempty(pixelsToIgnore)
            thisMask(pixelsToIgnore) = false;
        end

        neuropilMasks(:, :, n) = thisMask;
    end
end

function params = addDefaultValues(options)
%addDefaultValues - Add the default value of each option that is not given
    defaults = nansen.twophoton.roisignals.extract.getDefaultParameters();

    optionNames = ["roiInd", "imageMask", "excludeRoiFromNeuropil", ...
        "neuropilExpansionFactor", "cellNeuropilSeparation"];

    params = options;
    for name = optionNames
        if ~isfield(params, name)
            params.(name) = defaults.(name);
        end
    end
end

function tf = isIndexOfAllRois(roiInd)
%isIndexOfAllRois - Check if roiInd is the text "all"
    tf = (ischar(roiInd) || isstring(roiInd)) && isequal(string(roiInd), "all");
end

function mustBeRoiIndices(value)
%mustBeRoiIndices - Validate that value is "all" or a vector of indices
    isIndexVector = isnumeric(value) && isvector(value) && isreal(value) ...
        && all(value == round(value)) && all(value >= 1);

    if ~(isIndexOfAllRois(value) || isIndexVector)
        error("NANSEN:RoiSignals:InvalidRoiIndices", ...
            "Value must be ""all"" or a vector of positive integers.")
    end
end

function mask = imdilateoddeven(mask, count)
%imdilateoddeven imdilate using different nhood on odd and even iterations
%
%   Method for dilation is from Fissa. In current version, we alternate
%   between case 0 (cardinals) and case 1 (diagonals). Will preserve shape
%   of mask.
%   Todo: add proper credit.

    if mod(count, 2) == 0
        % Imdilate 1 pixel in each direction: N, E, S, W.
        nhood = [0,1,0; 1,1,1; 0,1,0];
        mask = imdilate(mask, nhood);

    elseif mod(count, 2) == 1
        % Imdilate 1 pixel in each direction:  NE, SE, SW, NW
        nhood = [1,0,1; 0,1,0; 1,0,1];
        mask = imdilate(mask, nhood);
    end
end
