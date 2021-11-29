function roiMasksOut = removeSpatialOverlaps(roiMasksIn, roiInd)
%removeSpatialOverlaps Remove spatial overlaps from an array of roimasks
%
%   roiMasksOut = removeSpatialOverlaps(roiMasksIn) returns an array of roi
%   masks where all pixels with overlapping rois are removed.
%
%   roiMasksOut = removeSpatialOverlaps(roiMasksIn, roiInd) returns roi
%   masks for a subset of roi specified in roiInd

    % Validate input
    message = 'Roi masks must be a numeric or logical array';
    isValidType = isnumeric(roiMasksIn) || islogical(roiMasksIn);
    assert(isValidType && ndims(roiMasksIn) >= 2, message)

    [height, width, numRois] = size(roiMasksIn);

    if nargin < 2
        roiInd = 1:numRois;
    end
    
    roiMasksOut = false( height, width, numel(roiInd) );

    % Do a projection sum over masks to get number of rois in each pixel.
    footprintAllRois = sum(roiMasksIn, 3);

    % Create boolean matrix which is true for all pixels with no overlap.
    footPrintNoOverlap = footprintAllRois == 1;

    % % Loop through rois and create new masks
    for iIter = 1:numel(roiInd)
        iRoi = roiInd(iIter);
        roiMasksOut(:, :, iIter) = roiMasksIn(:, :, iRoi) & footPrintNoOverlap;
    end

end