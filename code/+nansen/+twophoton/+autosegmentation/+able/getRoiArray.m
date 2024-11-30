function roiArray = getRoiArray(all_ROIs, imSize)

    % convert to array of RoI objects
    roiArray = RoI.empty;
    
    for i = 1:size(all_ROIs, 3)
        roiArray(end+1) = RoI('Mask', all_ROIs(:,:,i), imSize);
    end
end
