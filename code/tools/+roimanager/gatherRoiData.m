function [roiImageData, roiStats] = gatherRoiData(imArray, roiArray, varargin)
%roimanager.gatherRoiImages Gather set of roi image thumbnails
%
%   
%   Image Types:
%     - 'enhanced average'
%     - 'peak dff'
%     - 'correlation'
%     - 'enhanced correlation'
    
% Todo: Split in two functions???


    import roimanager.autosegment.extractRoiImages
    
    params = struct;
    params.ImageTypes = {'enhancedAverage', 'peakDff', 'correlation', 'enhancedCorrelation'};

    params = utility.parsenvpairs(params, [], varargin{:});
    
    
    % Add average images of roi
    
    % Calculate dff signals from image data and roi array.
    signalOpts = struct('createNeuropilMask', true);
    signalArray = nansen.twophoton.roisignals.extractF(imArray, roiArray, signalOpts);
    dff = nansen.twophoton.roisignals.computeDff(signalArray);
    
    % Count image types and rois and initialize variable for images
    numRois = numel(roiArray);
    numImageTypes = numel(params.ImageTypes);
    roiImages = cell(1, numImageTypes);
    
    % Use dff signals to create different types of roi images for each cell
    for i = 1:numImageTypes
        thisSmall = extractRoiImages(imArray, roiArray, dff', ...
            'ImageType', params.ImageTypes{i});
        roiImages{i} = arrayfun(@(i) thisSmall(:, :, i), 1:numRois, 'uni', 0);
    end

    % Collect output as a struct array.
    nvPairs = cat(1, params.ImageTypes, roiImages);
    roiImageData = struct(nvPairs{:});
    
    
    if nargout == 2
        
        % Todo: Add parameters for what stats to get. Make sure correct 
        % images are available for getting the stats....       
        ringW = mean(cat(3, roiImageData.enhancedAverage), 3);
        diskW = mean(cat(3, roiImageData.correlation), 3);
                
        roiStats = roimanager.autosegment.calculateRoiStats(roiArray, ...
            roiImageData, dff, ringW, diskW);

    end
    
    

end