function neuropilMasks = estimateNeuropilMasks(roiMasksIn, varargin)
%estimateNeuropilMasks Estimate neuropil masks for RoIs.
%
    % TODO
    %   [ ] Instead of using max count of 100 to stop, use a parameter
    %       called max neuropil radius....
    %   [ ] Add doc
    %   [ ] test the max radius
    %   [ ] add warning if mask can't be created (i.e not enough neuropil available)
    
    % Get default parameters and assertion functions.
    [P, V] = nansen.twophoton.roisignals.extract.getDefaultParameters();
    
    % Parse potential parameters from input arguments
    params = utility.parsenvpairs(P, V, varargin{:});

    % Create mask of pixel to ignore when creating neuropil masks
    if params.excludeRoiFromNeuropil
        % Create an array with all rois overlapping.
        footprintAllRois = sum(roiMasksIn, 3) >= 1;
    
        % Use binary erosion to remove pixels in the vicinity of main rois
        for i = 1:params.cellNeuropilSeparation
            footprintAllRois = imdilateoddeven(footprintAllRois, i);
        end
    
        if ~isempty(params.imageMask)
            pixelsToIgnore = footprintAllRois & ~params.imageMask;
        else
            pixelsToIgnore = footprintAllRois;
        end
    else
        if ~isempty(params.imageMask)
            pixelsToIgnore = ~params.imageMask;
        else
            pixelsToIgnore = [];
        end
    end
    
    % Allocate array for neuropil masks.
    [height, width, ~] = size(roiMasksIn);
    neuropilMasks = false( height, width, numel(params.roiInd) );
    
    % Loop through rois
    for n = 1:numel(params.roiInd)
        
        currentRoiInd = params.roiInd(n);
        currentRoiMask = roiMasksIn(:, :, currentRoiInd);
    
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
