function cellOfMasks = createMasks(roiArray, varargin)
%createMasks Create a struct array of roimasks for signal extraction
%
%   roiData = prepareMasks(roiArray) returns ...
%
%   roiData = prepareMasks(roiArray, options) returns ...
%
%   INPUTS:
%       roiArray
%       options
%   OUTPUT:
%       cellOfMasks
%
%   Eivind Hennestad | Vervaeke Lab | Sept 2018


%   TODO
%     [ ] fix implementation for only getting subset of rois
%     [ ] function for fissa style mask dilation


    import nansen.processing.roi.removeSpatialOverlaps
    import nansen.processing.roi.estimateNeuropilMasks
    import nansen.processing.roi.splitNeuropilMasks

    
    % Get default parameters and assertion functions.
    [P, V] = nansen.twophoton.roisignals.extract.getDefaultParameters();
    
    % Parse potential parameters from input arguments
    params = utility.parsenvpairs(P, V, varargin{:});    

    roiMaskArrayOrig = cat(3, roiArray(:).mask);
    
    if params.excludeRoiOverlaps
        roiMaskArray = removeSpatialOverlaps(roiMaskArrayOrig, ...
            params.roiInd); % From import
    else
        roiMaskArray = roiMaskArrayOrig(:, :, params.roiInd);
    end
    
    cellOfMasks = {roiMaskArray};
    
    if ~params.createNeuropilMask
        return 
    end
    
    neuropilMaskArray = estimateNeuropilMasks(roiMaskArrayOrig, params);
    
    if params.numNeuropilSlices > 1
        neuropilMasks = splitNeuropilMasks(neuropilMaskArray, ...
            roiMaskArrayOrig, params.numNeuropilSlices);
    else
        neuropilMasks = {neuropilMaskArray};
    end
    
    cellOfMasks = [cellOfMasks, neuropilMasks];

    
end