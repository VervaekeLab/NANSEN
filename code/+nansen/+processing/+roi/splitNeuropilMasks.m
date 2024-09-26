function npMasksSplit = splitNeuropilMasks(npMasks, roiMasks, numSlices)
%splitNeuropilMasks Split a neuropil mask into N slices (Inspired by FISSA)
%
%   npMasksSplit = splitNeuropilMasks(npMasks, roiMasks, numSlices) splits
%   neuropil masks (npMasks) corresponding to a group of rois (roiMasks)
%   into n slices.
%
%   INPUTS:
%       npMasks : A boolean matrix or 3D array containing neuropil masks
%           for one or multiple rois. If multiple rois, masks are stacked
%           along the 3rd dimension
%       roiMasks : A boolean matrix or 3D array containing rois masks
%           for one or multiple rois. If multiple rois, masks are stacked
%           along the 3rd dimension
%       numSlices : Number of slices to split each mask into. Default is 4
%
%   OUTPUTS:
%       npMasksSplit: A (nx1) cell array where each cell contains a 2D/3D 
%           boolean array of masks corresponding to one of the n slices

%   See also nansen.adapter.fissa.splitneuropilmask

    import nansen.adapter.fissa.splitneuropilmask
   
    if nargin < 3 || isempty(numSlices)
        numSlices = 4;
    end
    
    [h, w, numRois] = size(npMasks);
    npMasksSplit = false( [h, w, numSlices, numRois] );

    for i = 1:numRois
        roiMask = roiMasks(:, :, i);
        npMask = npMasks(:, :, i);
        npMasksSplit(:, :, :, i) = splitneuropilmask(npMask, roiMask, numSlices);
    end
    
    % Create cell array where each cell contains one slice for all rois
    getSlicedMasks = @(i) squeeze(npMasksSplit(:, :, i, :));
    npMasksSplit = arrayfun(@(i) getSlicedMasks(i), 1:numSlices, 'un', 0);
    
end


% Questions:
%     What's the best way to arrange output? Cell or 4D array?
