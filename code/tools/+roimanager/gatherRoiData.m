function [roiImageData, roiStats] = gatherRoiData(imArray, roiData, varargin)
%roimanager.gatherRoiImages Gather set of roi image thumbnails and roistats
%
%   
%   Image Types:
%     - 'enhanced average'
%     - 'peak dff'
%     - 'correlation'
%     - 'enhanced correlation'
    
% % 'Activity Weighted Mean'
% % 'Diff Surround'
% % 'Top 99th Percentile'
% % 'Local Correlation'

% Todo: Split in two functions???

    import nansen.twophoton.roisignals.extractF
    import nansen.twophoton.roisignals.computeDff
    
    import nansen.twophoton.roi.compute.computeRoiImages
    
    import roimanager.autosegment.extractRoiImages
    import roimanager.autosegment.calculateRoiStats
    
    params = struct;
    params.ImageTypes = {'Activity Weighted Mean', 'Diff Surround', 'Top 99th Percentile', 'Local Correlation'};
    
    params = utility.parsenvpairs(params, [], varargin{:});
    
    if isa(roiData, 'roimanager.roiGroup')
        roiArray = roiData.roiArray;
    elseif isa(roiData, 'RoI')
        roiArray = roiData;
    else
        error('Roi input is not valid.')
    end
    
    
    % Add average images of roi
    
    % Calculate dff signals from image data and roi array.
    signalOpts = struct('createNeuropilMask', true);
    signalArray = extractF(imArray, roiArray, signalOpts);
    dff = computeDff(signalArray);
    
    % Count image types and rois and initialize variable for images
    numRois = numel(roiArray);
    numImageTypes = numel(params.ImageTypes);
    roiImages = cell(1, numImageTypes);
    
    tic
    % Use dff signals to create different types of roi images for each cell
    for i = 1:numImageTypes
        thisSmall = extractRoiImages(imArray, roiArray, dff', ...
            'ImageType', params.ImageTypes{i});
        roiImages{i} = arrayfun(@(i) thisSmall(:, :, i), 1:numRois, 'uni', 0);
    end
    toc
    
    tic
    imageData = computeRoiImages(imArray, roiArray, signalArray, ...
        'ImageType', params.ImageTypes);
    toc

    % Collect output as a struct array.
    nvPairs = cat(1, params.ImageTypes, imageData);
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