function results = computeDriftSummary(avgProjImageArray)
%computeDriftSummary Compute different indicators of drift in 2p recording
%
%   INPUT:
%       avgProjImageArray : a 3D image array with an average projection for
%           each of a set of subparts of an imageStack (downsampled binned
%           average)


    numParts = size(avgProjImageArray, 3);

    fprintf('Computing image frame statistics...'); fprintf(newline)
    meanFluorescence = mean(mean(avgProjImageArray, 1), 2); %(1x1xn)
    meanFluorescenceSmooth = smoothdata(meanFluorescence); %(1x1xn)

    getPercentileValues = @(IM, p) prctile(prctile(IM, p, 1), p, 2);
    
    %minFluorescence = getPercentileValues( avgProjectionImageArray, 5);
    maxFluorescence = getPercentileValues( avgProjImageArray, 95);
    %maxFluorescenceSmooth = smoothdata(maxFluorescence);

    % Correct for mean fluorescence changes across the recording
    avgProjImageArray = avgProjImageArray ./ meanFluorescenceSmooth;
    
    imageCorrelation = zeros(numParts, numParts);
    
    fprintf('Computing image correlations...'); fprintf(newline)
    for i = 1:numParts
        for j = 1:numParts
            if imageCorrelation(j, i) ~= 0
                % No need to calculate values twice
                imageCorrelation(i, j) = imageCorrelation(j, i);
                continue
            end
            imageCorrelation(i, j) = corr2(avgProjImageArray(:, :, i), ...
                                           avgProjImageArray(:, :, j));
        end
    end
    
    % Prepare summary images:
    avgProjImageArray = avgProjImageArray ./ sqrt(avgProjImageArray);       % Not sure if this is useful
    
    % 1) Colorcode first and last frame with different colors
    cMap = [ 1, 0.5, 0; 
             0, 0.5, 1 ];
    imageMerged = stack.colorCodeImageStack(...
        avgProjImageArray(:, :, [1,end]), cMap);
    
    imageMerged = imageMerged - min(imageMerged(:));
    imageMerged = uint8( imageMerged ./ max(imageMerged(:)) .* 255 );

    % 2) Create a difference image between first and last frame 
    imageDiff = avgProjImageArray(:, :, 1) - avgProjImageArray(:, :, end);

    % Gather results in a struct
    results = struct;
    results.NumParts = numParts;
    results.ImagesMerged = imageMerged;
    results.ImagesDiff = imageDiff;
    results.ImageCorrelations = imageCorrelation;
    results.MeanFluoresence = squeeze( meanFluorescence );
    results.MeanFluoresenceSmooth = squeeze( meanFluorescenceSmooth );
    results.PeakFluorescence = max(maxFluorescence);
end
