function roiStat = computeRoiStats(roiArray, roiImageData, dff, ringKernel, diskKernel)

boxSize = size(roiImageData(1).enhancedAverage);
maxSize = roiArray(1).imagesize;

centerCoords = round(cat(1, roiArray.center));

indX = (1:boxSize(2)) - ceil(boxSize(2)/2);
indY = (1:boxSize(1)) - ceil(boxSize(1)/2);

nRois = numel(roiArray);

roiStat = struct.empty;

for i = 1:nRois
    % Image coordinates for a square box centered on the roi
    tmpX = indX + centerCoords(i, 1);
    tmpY = indY + centerCoords(i, 2);
    
    roiMask = roiArray(i).mask;
    if any([tmpX,tmpY]<1) || any(tmpX>maxSize(2)) || any(tmpY>maxSize(1))
        smallMask = false(boxSize);
        isValidX = tmpX >= 1 & tmpX<=maxSize(2);
        isValidY = tmpY >= 1 & tmpY<=maxSize(1);
        smallMask(isValidY,isValidX) = roiMask(tmpY(isValidY), tmpX(isValidX));
    else
        smallMask = roiMask(tmpY, tmpX);
    end
    
    roiStat(i).ringCorrelation = corr2(roiImageData(i).enhancedAverage, ringKernel);
    roiStat(i).diskCorrelation = corr2(roiImageData(i).correlation, diskKernel);
    
    roiStat(i).meanPixelCorrelation = mean(mean(roiImageData(i).correlation(smallMask)./255));
    corrIntensityRoi = mean(mean(roiImageData(i).correlation(smallMask)./255));
    corrIntensityPil = mean(mean(roiImageData(i).correlation(~smallMask)./255));
    peakIntensityRoi = mean(mean(roiImageData(i).peakDff(smallMask)));
    peakIntensityPil = mean(mean(roiImageData(i).peakDff(~smallMask)));
    
    roiStat(i).spatialCorrelationDff = (corrIntensityRoi-corrIntensityPil+1)./(corrIntensityPil+1);
    roiStat(i).spatialPeakDff = (peakIntensityRoi-peakIntensityPil+1)./(peakIntensityPil+1);
    roiStat(i).temporalPeakDff = max(dff(:, i));
    
end
end
