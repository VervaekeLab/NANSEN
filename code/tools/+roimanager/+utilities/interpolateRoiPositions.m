function roiArrayDiff = interpolateRoiPositions(roiArray1, roiArray2)
%interpolateRoiPositions Interpolate positions of rois between two roi
%arrays
%
%   This functions finds the group of rois that are present in both roi
%   arrays (1 and 2) and use these for interpolating positions for those
%   rois that are only present in roi array 1. The rois that are only
%   present in roiArray1 are shifted to new interpolated positions and
%   returned in a new roi array (roiArrayDiff)

% Notes:
%   2023-09-22 : Updated to support multi channel rois (represented as cell
%   arrays of roi arrays). Interpolation should take all rois into
%   consideration, but the output rois need to be a cell array of rois with one
%   cell per channel.

    % Create vectors of x and y positions of each roi.
    
    roiArrayDiff = RoI.empty;

    if isempty(roiArray1) && isempty(roiArray2)
         return
    end

    % If roiArray1 is a cell, roiArray2 and roiArrayDiff (output) must be as well.
    if isa(roiArray1, 'cell')
        assert(isa(roiArray2, 'cell'), ...
            'If array of reference rois (roiArray1) is a cell array, target rois (roiArray2) must also be a cell array')
        roiArrayDiff = cell(size(roiArray1));
        [roiArrayDiff{:}] = deal(RoI.empty);
    end
   
    [Fx, Fy] = getRoiPositionInterpolant(roiArray1, roiArray2);
    if isempty(Fx); return; end

    tempUseCellArray = false;
    if ~isa(roiArray1, 'cell')
        roiArray1 = {roiArray1}; roiArray2 = {roiArray2}; roiArrayDiff = {roiArrayDiff};
        tempUseCellArray = true;
    end

    for iCell = 1:numel(roiArray1)
        
        roiUid1 = {roiArray1{iCell}(:).uid};
        roiUid2 = {roiArray2{iCell}(:).uid};

        [~, roiInd] = setdiff(roiUid1, roiUid2);
        tempRoiSubset = roiArray1{iCell}(roiInd);

        for jRoi = 1:numel(tempRoiSubset)
            roiShiftX = Fx(tempRoiSubset(jRoi).center);
            roiShiftY = Fy(tempRoiSubset(jRoi).center);
                    
            if any(isnan([roiShiftX, roiShiftY]))
                continue
            end
            
            tempRoiSubset(jRoi) = tempRoiSubset(jRoi).move([roiShiftX, roiShiftY]);
        end

        roiArrayDiff{iCell} = tempRoiSubset;
    end

    if tempUseCellArray
        roiArrayDiff = roiArrayDiff{1};
    end
end

function [Fx, Fy] = getRoiPositionInterpolant(roiArrayA, roiArrayB)
%getRoiPositionInterpolant Get scattered interpolants for interpolating roi positions
%
%   Use positions of all intersecting rois (intersection is based on uuids)
%   to create a scattered interpolant that can be used for estimating
%   positions of rois in roiArrayA if they are copied to roiArrayB

    [Fx, Fy] = deal([]);
    
    if isa(roiArrayA, 'cell')
        assert(isa(roiArrayB, 'cell'), 'If array of reference rois (roiArray1) is a cell, target rois (roiArray2) must also be a cell')
        [roiArrayA, ~] = utility.cell.flatten(roiArrayA);
        [roiArrayB, ~] = utility.cell.flatten(roiArrayB);
    end
    
    roiUidA = {roiArrayA(:).uid};
    roiUidB = {roiArrayB(:).uid};
    
    [~, roiIndA, roiIndB] = intersect(roiUidA, roiUidB);
    
    if isempty(roiIndA); return; end

    roiIntersectionA = roiArrayA(roiIndA);
    roiIntersectionB = roiArrayB(roiIndB);

    centerCoordsA = cat(1, roiIntersectionA.center);
    centerCoordsB = cat(1, roiIntersectionB.center);
    
    roiOffsets = centerCoordsB - centerCoordsA;

    Fx = scatteredInterpolant(centerCoordsA(:,1), centerCoordsA(:,2), roiOffsets(:,1));
    Fy = scatteredInterpolant(centerCoordsA(:,1), centerCoordsA(:,2), roiOffsets(:,2));
end
