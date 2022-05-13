function [roiArray, summary] = runAutoSegmentation(imArray, varargin)
    
    % option for what to return:
    %   roiarray, or spatial segments... Should depend on whether
    %   segmentation is run on full recording or it is divided in subparts.
    
    % todo
    %   [ ] extended results
    
    %[params, validators] = flufinder.getDefaultOptions();
    %params = utility.parsenvpairs(params, validators, varargin{:});
    
    params = struct(); 
    params.RoiType = 'soma';
    params.RoiDiameter = 12;
    params.BackgroundBinningSize = 5;
    params.BackgroundSmoothingSigma = 20;
    params.BwThresholdPercentile = 92;
    
    params.UseShapeDetection = true;
    params.MorphologicalShape = 'ring';
    
    
    params.PercentOverlapForMerge = 75; % todo.
    
    params = utility.parsenvpairs(params, [], varargin{:});
    
    
    stackSize = size(imArray);
    imageSize = stackSize(1:2);
    
    tBegin = tic; % Start timer

    % Initialize appendix
    summary = struct;
    
    % % Preprocess image data
    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    fprintf('Preprocessing image data...\n')
    % imArray = flufinder.module.preprocessImages(imArray, params)
    
    imArray = single(imArray);

    % Create a temporally downsampled stack (binned by maximum)
    imArray = stack.process.framebin.max(imArray, 5);
    
    % Preprocess (subtract dynamic background)
    %optsNames = {'FilterSize'};
    %opts = utility.struct.substruct(params, optsNames);
    opts = {'FilterSize', 20};
    imArray = flufinder.preprocess.removeBackground(imArray, opts{:});
    
    % Preprocess (subtract static background)
    opts = {'Percentile', 25};
    imArray = flufinder.preprocess.removeStaticBackground(imArray, opts{:});
    
    
    % % Binarize image data
    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    fprintf('Binarizing image data...\n')
    % bwArray = flufinder.module.binarizeImages(imArray, params)
    
    optsNames = {'RoiDiameter', 'BwThresholdPercentile'};
    bwOpts = utility.struct.substruct(params, optsNames);
    
    switch params.RoiType
        case 'soma'
            BW = flufinder.binarize.binarizeSomaStack(imArray, bwOpts);
        case 'axon'
            BW = flufinder.binarize.binarizeAxonStack(imArray, bwOpts);
        otherwise 
            error('Unsupported roi type.')
    end

    
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
        
        roiArrayS = flufinder.detect.shapeDetection(averageImage, roiArrayT, opts);
        roiArray = flufinder.utility.combineRoiArrays(roiArrayT, roiArrayS, opts);
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