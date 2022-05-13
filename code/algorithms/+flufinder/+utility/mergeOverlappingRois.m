function roiArray = mergeOverlappingRois(roiArray, overlap, method)
%mergeOverlappingRois Merge overlapping rois in a roiArray
%
%   roiArray = mergeOverlappingRois(roiArray, overlap, method)
%
%   Inputs
%       roiArray : array of rois
%       overlap  : [0,1] default = 0.8
%       method   : intersect (default) or union
%
%   See also RoI


    if nargin < 2; overlap = 0.8; end
    if nargin < 3; method = 'intersect'; end
    
    % Merge overlapping rois in the activity based roi Array.
    [iA, iB] = roimanager.utilities.findOverlappingRois(roiArray, roiArray, overlap);
    IND = [iA, iB];
    
    mergedRois = RoI.empty;
    while ~isempty(IND)
        ia = IND(1,1);
        ib = IND(1,2);
        mergedRois(end+1) = RoI.mergeRois([roiArray(ia), roiArray(ib)], method);
        IND(1, :) = [];
        [row, ~] = find(IND == [ib, ia]);
        IND(row(1), :) = [];
    end
    
    roiArray(iA) = [];
    roiArray = cat(2, roiArray, mergedRois);

end