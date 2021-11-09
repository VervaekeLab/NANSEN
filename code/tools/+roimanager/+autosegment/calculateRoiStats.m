function roiStat = calculateRoiStats(roiArray, roiImageData, dff, ringKernel, diskKernel)


boxSize = size(roiImageData(1).enhancedAverage);

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
    smallMask = roiMask(tmpY, tmpX);
    
    roiStat(i).ringCorrelation = corr2(roiImageData(i).enhancedAverage, ringKernel);
    roiStat(i).diskCorrelation = corr2(roiImageData(i).correlation, diskKernel);
    
    roiStat(i).meanPixelCorrelation = mean(mean(roiImageData(i).correlation(smallMask)./255));
    corrIntensityRoi = mean(mean(roiImageData(i).correlation(smallMask)./255));
    corrIntensityPil = mean(mean(roiImageData(i).correlation(~smallMask)./255));
    peakIntensityRoi = mean(mean(roiImageData(i).peakDff(smallMask)));
    peakIntensityPil = mean(mean(roiImageData(i).peakDff(~smallMask)));
    roiStat(i).spatialCorrelationDff = (corrIntensityRoi-corrIntensityPil+1)./(corrIntensityPil+1);
    roiStat(i).spatialPeakDff = (peakIntensityRoi-peakIntensityPil+1)./(peakIntensityPil+1);
    roiStat(i).temporalPeakDff = max(dff(i, :));
    
end


end