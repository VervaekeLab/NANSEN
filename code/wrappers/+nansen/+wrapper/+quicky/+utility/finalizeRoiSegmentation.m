function roiArray = finalizeRoiSegmentation(imArray, avgIm, roiArrayT, varargin)
%finalizeRoiSegmentation Finalize roi segmentation
    
    % Todo: extract dff

    import nansen.twophoton.roi.compute.computeRoiImages
    
    % Calculate average projection here if not given
    if nargin < 2; avgIm = mean(imArray, 3); end
    
    % Parse name, value pairs
    def = struct('RingConvolutionSearch', true); % add roiSize...
    opt = utility.parsenvpairs(def, [], varargin);
    
    
    tBegin = tic; % Start timer

    
    roiArrayT = roimanager.utilities.mergeOverlappingRois(roiArrayT);
        
    % Remove candidates very close to edge of the image
    roiArrayT = roimanager.utilities.removeRoisOnBoundary(roiArrayT);
    
    
    if opt.RingConvolutionSearch
        % Search for ring shaped candidates (spatial footprint only)
        fprintf('Searching for ring-shaped cells...\n')
        param = struct('InnerRadius', 4, 'OuterRadius', 6, 'BoxSize', [21,21]);
        roiArrayS = roimanager.autosegment.spatialDonutDetection(single(avgIm), [], param);
        
        if ~isempty(roiArrayS)
            roiArrayS = roimanager.utilities.mergeOverlappingRois(roiArrayS);
            roiArrayS = roimanager.utilities.removeRoisOnBoundary(roiArrayS);


            % Remove candidates that are overlapping...
            [~, iB] = roimanager.utilities.findOverlappingRois(roiArrayS, roiArrayT, 0.75);
            roiArrayT(iB) = [];


            % Extract signals for detected rois
            fprintf('Extracting signals for ring-shaped cells...\n')
            %dffS = autosegment.extractDff(imArray, roiArrayS, 'unique roi');

            % Todo: Use temporally downsampled stack for extracting signals
            % and roi images for improving estimates
            signalOpts = struct('createNeuropilMask', true);
            signalArrayS = nansen.twophoton.roisignals.extractF(imArray, roiArrayS, signalOpts);
            
            % Add roi images to rois. Use to improve roi boundary estimate
            roiImageArray = computeRoiImages(imArray, roiArrayS, signalArrayS);
            roiArrayS = roiArrayS.addImage(roiImageArray);
        end
    end
    

    fprintf('Extracting signals for temporally active cells...\n')
    
    signalOpts = struct('createNeuropilMask', true);
    signalArray = nansen.twophoton.roisignals.extractF(imArray, roiArrayT, signalOpts);
    dffT = nansen.twophoton.roisignals.computeDff(signalArray);
    %dffT = autosegment.extractDff(imArray, roiArrayT, 'unique roi');

    % Remove rois that dont have a signal. Due to being covered by other
    % rois. Todo. Find a better solution...
    discard = isnan(sum(dffT, 1));
    roiArrayT(discard) = [];
    dffT(:, discard) = [];


    %%% Improve roi estimate for active cells.
    fprintf('Improving estimates for temporally active cells...\n')
    roiImageArray = roimanager.autosegment.extractRoiImages(imArray, roiArrayT, dffT', 'ImageType', 'correlation');
    roiArrayT = roiArrayT.addImage(roiImageArray);
    [roiArrayT1, ~] = roimanager.binarize.improveMaskEstimate2(roiArrayT);
    
    
    % Merge overlapping rois in the activity based roi Array.
    roiArrayT = roimanager.utilities.mergeOverlappingRois(roiArrayT);
    
    
    % Do a final check for overlapping rois...
    if opt.RingConvolutionSearch && ~isempty(roiArrayS)
        [iA, iB] = roimanager.utilities.findOverlappingRois(roiArrayS, roiArrayT, 0.75);
        roiArrayT(iB) = [];
    end

        
    % Remove small rois:
    areas = [roiArrayT.area];
    keep = areas > 50 & areas < 200;
    roiArrayT = roiArrayT(keep);

    
    if opt.RingConvolutionSearch
        roiArrayS = roiArrayS.addTag('spatial_segment');
        roiArrayT = roiArrayT.addTag('temporal_segment'); % To distinguish when loading to roimanager

        % Combine Rois from two different methods
        roiArray = [roiArrayS, roiArrayT];
    else
        roiArray = roiArrayT;
    end

    
    t2 = toc(tBegin);
    nRois = numel(roiArray);
    
    fprintf(sprintf('Autodetection finished. Found %d rois in %d seconds.\n', nRois, round(t2) ))
    
end

