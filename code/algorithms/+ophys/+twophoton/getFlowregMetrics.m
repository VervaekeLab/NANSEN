% Adapted from get_metrics by Philipp Flotho from the flowregistration
% toolbox: https://github.com/phflot/flow_registration

function results = getFlowregMetrics(imArray, refIdx)
%getFlowregMetrics Get metrics using flowregistration method

    if nargin < 2; refIdx = 1; end

    if ndims(imArray)==4 % Combine channels if multichannel
        imArray = squeeze(mean(imArray, 3));
    end
   
    [h, w, numFrames] = size(imArray);

    sigma = [3 3 0.0001];
    b = 25; % Amount of image borders to ignore during psnr calculation
   
    xInd = b:w-b;
    yInd = b:h-b;

    imArrayLow = imgaussfilt3(double(imArray), sigma);
    
    notIdx = setdiff(1:numFrames, refIdx);
    
    referenceImage = mean(imArrayLow(:, :, refIdx), 3);
    
    imArrayLow = imArrayLow(:, :, notIdx);
    
    avg_psnr = zeros(1, length(notIdx));
    avg_mse = zeros(1, length(notIdx));
    
    for i = 1:length(notIdx)
        avg_psnr(i) = psnr(referenceImage(yInd, xInd), imArrayLow(yInd, xInd, i)) ;
        avg_mse(i) = immse(referenceImage(yInd, xInd), imArrayLow(yInd, xInd, i)) ;
    end
    
    avg_std = mean(mean(std(imArrayLow, 0, 3), 1), 2);
    
    results = struct;
    results.AvgPeakSnr = avg_psnr;
    results.AvgMse = avg_mse;
    results.AvgStd = avg_std;
end
