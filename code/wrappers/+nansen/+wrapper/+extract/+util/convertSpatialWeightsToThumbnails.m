function imArray = convertSpatialWeightsToThumbnails(roiArray, spatialWeights, thumbnailSize)

% Todo: % Adjust size based on average size of rois.
% roiRadius = round( mean( sqrt( [roiArray.area] / pi ) ) );
% thumbnailSize = 2*roiRadius + 1;

thumbnailSize = [21, 21];
r = floor(thumbnailSize/2);

imSize = roiArray(1).imagesize;
numRois = numel(roiArray);
imArray = zeros([thumbnailSize, numRois]);


for iRoi = 1:numRois
    
    thisSpatialWeight = spatialWeights(:, :, iRoi);
    
    x = roiArray(iRoi).center(1);
    y = roiArray(iRoi).center(2);
    
    [S, L] = roimanager.imtools.getImageSubsetBounds(imSize, x, y, r, 0, 'boundaryMethod', 'none');
    imChunk = roimanager.imtools.getPixelChunk(thisSpatialWeight, S, L);


    if size(imChunk, 1) < thumbnailSize(1) || size(imChunk, 2) < thumbnailSize(2)
        imChunk = stack.reshape.imexpand(imChunk, thumbnailSize);
    end
    
    imArray(:, :, iRoi) = imChunk;

end