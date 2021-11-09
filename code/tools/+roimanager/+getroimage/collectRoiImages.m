function roiImages = collectRoiImages(roiArray, imArray, dff)

    % todo: create disk and ring kernel
    
    
    roiImA = extractRoiImages(imArray, roiArray, dff);
    roiImB = extractRoiImages(imArray, roiArray, dff, 'ImageType', 'peak dff');
    roiImC = extractRoiImages(imArray, roiArray, dff, 'ImageType', 'correlation');
%         roiImD = extractRoiImages(imArray, roiArray, dff, 'ImageType', 'enhanced correlation');
        
%     roiArray = roiArray.addImage(roiImA);

%     diskW = nanmean(cat(3, roiArray.enhancedImage), 3);
% 
%     try
%         ringW = nanmean(roiImA(:, :, 1:numel(roiArrayS)), 3);
%     catch
%         ringW = diskW;
%     end

    roiImA = arrayfun(@(i) roiImA(:, :, i), 1:size(roiImA,3), 'uni', 0);
    roiImB = arrayfun(@(i) roiImB(:, :, i), 1:size(roiImB,3), 'uni', 0);
    roiImC = arrayfun(@(i) roiImC(:, :, i), 1:size(roiImC,3), 'uni', 0);
%         roiImD = arrayfun(@(i) roiImD(:, :, i), 1:size(roiImD,3), 'uni', 0);

    roiImages = struct('enhancedAverage', roiImA, 'peakDff', roiImB, 'correlation', roiImC);%, 'enhancedCorrelation', roiImD);
        
        
end