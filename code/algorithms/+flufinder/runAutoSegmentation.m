function [roiArray, summary] = runAutoSegmentation(imArray, varargin)
    
    % option for what to return:
    %   roiarray, or spatial segments... Should depend on whether
    %   segmentation is run on full recording or it is divided in subparts.
    
    % todo
    %   [ ] summary/results
    
    global fprintf % Use global fprintf if available
    if isempty(fprintf); fprintf = str2func('fprintf'); end

    % Get default options and update based on optional name-value pairs.
    [params, validators] = flufinder.getDefaultOptions('ungrouped');
    params = utility.parsenvpairs(params, validators, varargin{:});
    
    stackSize = size(imArray);
    imageSize = stackSize(1:2);
    
    tBegin = tic; % Start timer

    % Initialize struct for summary
    summary = struct;
    summary.MeanImageOriginal = mean(imArray, 3);
    
    % % Preprocess image data
    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    fprintf('Preprocessing image data...\n')
    imArray = flufinder.module.preprocessImages(imArray, params);
    
    summary.MeanImageProcessed = mean(imArray, 3);
    
    % % Binarize image data
    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    fprintf('Binarizing image data...\n')
    BW = flufinder.module.binarizeImages(imArray, params);
    
    % % Detect binary components based on brightness values of pixels
    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    fprintf('Detecting binary components...\n')
    
    S = flufinder.detect.getBwComponentStats(BW, params);
    roiArrayT = flufinder.detect.findUniqueRoisFromComponents(imageSize, S);
    
    % % Improve estimates of rois which were detected based on activity
    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    import nansen.twophoton.roi.compute.computeRoiImages

% % %     fMean = nansen.twophoton.roisignals.extractF(imArray, roiArrayT);
% % %     [fMean, roiArrayT] = flufinder.utility.removeIsNanDff(fMean, roiArrayT);
% % %
% % %     % get images:
% % % %     roiImages = computeRoiImages(imArray, roiArrayT, fMean, ...
% % % %        'ImageType', {'Activity Weighted Mean', 'Local Correlation'});
% % %     roiImages = computeRoiImages(imArray, roiArrayT, fMean, ...
% % %         'ImageType', 'Activity Weighted Mean');
% % %
% % %
% % %     roiArrayT = flufinder.module.improveRoiMasks(roiArrayT, roiImages);
    
    % % Detect rois from a shape-based kernel convolution
    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    if params.UseShapeDetection
        fprintf('Searching for %s-shaped cells...\n', ...
            params.MorphologicalShape)
        averageImage = mean(imArray, 3);
        
        roiArrayS = flufinder.detect.shapeDetection(averageImage, roiArrayT, params);
        roiArray = flufinder.utility.combineRoiArrays(roiArrayT, roiArrayS, params);
    else
        roiArray = roiArrayT;
    end
    
    %roiArrayS = roimanager.utilities.removeRoisOnBoundary(roiArrayS);

    % Remove small rois:
% %     areas = [roiArrayT.area];
% %     keep = areas > 50 & areas < 200;
% %     roiArray = roiArray(keep);
    
    % % Display elapsed time and number of rois detected.
    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    fprintf('Autosegmentation finished. Found %d rois in %d seconds.\n', ...
        numel(roiArray), round(toc(tBegin)) )
    
    if nargout == 1
        clear summary
    end
end
