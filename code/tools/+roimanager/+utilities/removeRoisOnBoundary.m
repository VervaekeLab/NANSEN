function [roiKeep, roiBnd] = removeRoisOnBoundary(roiArray, varargin)
% Pop boundary rois from roiArray
%
%   Parameters: margin (default=15) pixels from image boundary

    def = struct('margin', 15);
    opt = utility.parsenvpairs(def, [], varargin);

    margin = opt.margin;
    
    imSize = roiArray(1).imagesize;
    
    nRois = numel(roiArray);
    keep = true(nRois, 1);
    
    centerCoords = cat(1, roiArray.center);
    keep = keep & all(centerCoords > margin, 2);
    keep = keep & all(centerCoords < fliplr(imSize(1:2))-margin, 2);

    roiKeep = roiArray(keep);
    roiBnd = roiArray(~keep);
    
    if nargout == 1
        clear roiBnd
    end
end
