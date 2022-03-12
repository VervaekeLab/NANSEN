function [roiImages, roiStats] = createRoiUserdata(roiArray, imArray, dff)
%createRoiUserdata
%
%   Todo: organize this and make part of roimanager. Also standardize with
%   autosegmentSoma
%   Todo: create templatesfor ringW & diskW
    import roimanager.*

    if nargin < 3
        % Add average images of roi
        f = nansen.twophoton.roisignals.extractF(imArray, roiArray);
        dff = nansen.twophoton.roisignals.computeDff(f, 'dffFcn', 'dffRoiMinusDffNpil');
    end
    
    roiImA = autosegment.extractRoiImages(imArray, roiArray, dff);
    roiImB = autosegment.extractRoiImages(imArray, roiArray, dff, 'ImageType', 'peak dff');
    roiImC = autosegment.extractRoiImages(imArray, roiArray, dff, 'ImageType', 'correlation');
%         roiImD = extractRoiImages(imArray, roiArray, dff, 'ImageType', 'enhanced correlation');

    roiArray = roiArray.addImage(roiImA);

    diskW = nanmean(cat(3, roiArray.enhancedImage), 3);

    try
        ringW = nanmean(roiImA(:, :, 1:numel(roiArray)), 3);
    catch
        ringW = diskW;
    end

    roiImA = arrayfun(@(i) roiImA(:, :, i), 1:size(roiImA,3), 'uni', 0);
    roiImB = arrayfun(@(i) roiImB(:, :, i), 1:size(roiImB,3), 'uni', 0);
    roiImC = arrayfun(@(i) roiImC(:, :, i), 1:size(roiImC,3), 'uni', 0);
%         roiImD = arrayfun(@(i) roiImD(:, :, i), 1:size(roiImD,3), 'uni', 0);

    roiImages = struct('enhancedAverage', roiImA, 'peakDff', roiImB, 'correlation', roiImC);%, 'enhancedCorrelation', roiImD);

    roiStats = autosegment.calculateRoiStats(roiArray, roiImages, dff, ringW, diskW);

end