function imArray = convertSpatialWeightsToThumbnails(roiArray, spatialWeights, thumbnailSize)
%convertSpatialWeightsToThumbnails Get roi images from EXTRACT's spatial w 
%
%   imArray = convertSpatialWeightsToThumbnails(roiArray, spatialWeights)
%       converts the spatial weight array to a roi thumbnail image array
%       for the given roi array.
%
%   imArray = convertSpatialWeightsToThumbnails(roiArray, spatialWeights, thumbnailSize)
%       converts to images with size given by thumbnailSize (default = 21x21)
%
%   INPUTS:
%       roiArray : array of roi objects
%       spatialWeights : array of spatial weights (imHeight x imWidth x numRois)
%       thumbnailSize : Size of roi thumbnail image (height x width)
%
%   OUTPUT:
%       imArray : Array of roi thumbnail images (thumbnailSize x numRois)


% Todo: Move to flufinder...

% Todo: % Adjust size based on average size of rois.
% roiRadius = round( mean( sqrt( [roiArray.area] / pi ) ) );
% thumbnailSize = 2*roiRadius + 1;

    import roimanager.imtools.getImageSubsetBounds
    import roimanager.imtools.getPixelChunk

    if nargin < 3 || isempty(thumbnailSize)
        thumbnailSize = [21, 21];
    end

    % Prepare some values
    r = floor(thumbnailSize/2);
    imSize = roiArray(1).imagesize;
    numRois = numel(roiArray);
    
    % Preallocate output
    imArray = zeros([thumbnailSize, numRois]);
   
    for iRoi = 1:numRois

        thisSpatialWeight = spatialWeights(:, :, iRoi);

        x0 = roiArray(iRoi).center(1);
        y0 = roiArray(iRoi).center(2);
    
        opts = {'boundaryMethod', 'none'};
        [S, L] = getImageSubsetBounds(imSize, x0, y0, r, 0, opts{:});       % imported function
        imChunk = getPixelChunk(thisSpatialWeight, S, L);                   % imported function

        % This should not be needed when boundary method is set to none...
        if any( size(imChunk) < thumbnailSize )
            imChunk = stack.reshape.imexpand(imChunk, thumbnailSize);
        end

        imArray(:, :, iRoi) = imChunk;
    end
end