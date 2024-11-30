function salience = roiSalience(roiArray, roiImageArray)
%roiSalience Get salience of image pixels located in roi interior
%   Detailed explanation goes here
    
    [cropSize(1), cropSize(2), ~] = size(roiImageArray);
    
    fovImageSize = roiArray(1).imagesize;
    centerCoords = round(cat(1, roiArray.center));

    indX = (1:cropSize(2)) - ceil(cropSize(2)/2);
    indY = (1:cropSize(1)) - ceil(cropSize(1)/2);

    numRois = numel(roiArray);
    salience = zeros(numRois, 1);
    
    for i = 1:numRois
    
        % Image coordinates for a square box centered on the roi
        tmpX = indX + centerCoords(i, 1);
        tmpY = indY + centerCoords(i, 2);
        
        currentRoiMask = roiArray(i).mask;
        currentRoiImage = roiImageArray(:, :, i);
        
        [croppedMaskRoi, croppedMaskPil] = deal( false(cropSize) );
        
        % Make sure to only include pixels that are within fov image.
        isValidX = tmpX >= 1 & tmpX<=fovImageSize(2);
        isValidY = tmpY >= 1 & tmpY<=fovImageSize(1);

        croppedMaskRoi(isValidY, isValidX) = currentRoiMask(tmpY(isValidY), tmpX(isValidX));
        croppedMaskPil(isValidY, isValidX) = ~currentRoiMask(tmpY(isValidY), tmpX(isValidX));

        meanIntensityRoi = mean(mean(currentRoiImage(croppedMaskRoi)));
        meanIntensityPil = mean(mean(currentRoiImage(croppedMaskPil)));

        salience(i) = (meanIntensityRoi-meanIntensityPil+1)./(meanIntensityPil+1);
    end
end
