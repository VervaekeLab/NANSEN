function roiArray = combineRoiArrays(roiArrayA, roiArrayB, varargin)
%combineRoiArrays Combine two roi arrays while merging overlapping rois
%
%   DESCRIPTION: 
%   Merge rois that overlap more than a specific percentage.
%   The current behavior does not merge, only removes one of the
%   overlapping rois. A future version should implement actual merging.
%
%   SYNTAX:
%   roiArray = combineRoiArrays(roiArrayA, roiArrayB)
%
%   roiArray = combineRoiArrays(roiArrayA, roiArrayB, name, value, ...)
%
%   NAME/VALUE PAIRS:
%   PercentOverlapForMerge : Scalar integer between 0 and 100 that
%                            specifies a threshold for merging of rois.
%                            Rois whos area overlap by more than the
%                            given value will be merged. Default is 75.
%             
%   
%   MergeMethod            : Character vector that specifies a method for
%                            merging rois. (Not implemented yet).

    import flufinder.utility.findOverlappingRois

    params = struct;
    params.PercentOverlapForMerge = 75;    
    params.MergeMethod      = 'remove';

    params = utility.parsenvpairs(params, [], varargin);
    
    % Return if one of the roi arrays are empty
    if isempty(roiArrayA) || isempty(roiArrayB)
        if isempty(roiArrayA)
            roiArray = roiArrayB;
        else
            roiArray = roiArrayA;
        end
        return
    end

    % Remove candidates that are overlapping...
    overlap = params.PercentOverlapForMerge ./ 100;
    [~, iB] = findOverlappingRois(roiArrayA, roiArrayB, overlap);          % Imported function
    roiArrayB(iB) = [];

    % Concatenate roi arrays
    roiArray = [roiArrayA, roiArrayB];

end