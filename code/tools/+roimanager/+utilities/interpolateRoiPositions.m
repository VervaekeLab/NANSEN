function roiArrayDiff = interpolateRoiPositions(roiArray1, roiArray2)

    % Create vectors of x and y positions of each roi.
    
    roiArrayDiff = RoI.empty;

    if isempty(roiArray1) && isempty(roiArray2)
         return
    end
    
    roiUid1 = {roiArray1(:).uid};
    roiUid2 = {roiArray2(:).uid};
    
    [~, roiInd1, roiInd2] = intersect(roiUid1, roiUid2);
    
    rois1intersect = roiArray1(roiInd1);
    rois2intersect = roiArray2(roiInd2);

    centerCoord1 = cat(1, rois1intersect.center);
    centerCoord2 = cat(1, rois2intersect.center);
    
    roiOffsets = centerCoord2 - centerCoord1;

    if isempty(roiOffsets); return; end

    Fx = scatteredInterpolant(centerCoord1(:,1),centerCoord1(:,2), roiOffsets(:,1));
    Fy = scatteredInterpolant(centerCoord1(:,1),centerCoord1(:,2), roiOffsets(:,2));
   
    [~, roiInd] = setdiff(roiUid1, roiUid2);
    roiArrayDiff = roiArray1(roiInd);
    
    for i = 1:numel(roiArrayDiff)
        roiShiftX = Fx(roiArrayDiff(i).center);
        roiShiftY = Fy(roiArrayDiff(i).center);
                
        if any(isnan([roiShiftX, roiShiftY]))
            continue
        end
        
        roiArrayDiff(i) = roiArrayDiff(i).move([roiShiftX, roiShiftY]);
    end
    
end
