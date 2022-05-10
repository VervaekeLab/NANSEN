function [signalArray, roiArray] = removeIsNanDff(signalArray, roiArray)
%removeIsNanDff Remove elements where dff of signal array has nans
    
    assert(numel(roiArray) == size(signalArray, 3), ...
        'Third dimension of signal array must match number of rois')
    
    dffOpts = {'dffFcn', 'dffRoiMinusDffNpil'};
    dff = nansen.twophoton.roisignals.computeDff(signalArray, dffOpts{:});
    
    discard = isnan(sum(dff, 1));
    
    roiArray(discard) = [];
    signalArray(:, discard) = [];
end