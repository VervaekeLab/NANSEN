function [roiArray, roiImages, roiStats] = autosegmentSoma(imArray, avgIm, varargin)
    
    % Todo: 
    % Calculate temporal stats.
    % Calculate spatial stats. For donut, for disk.
    % Create a roidata file containing images, and stats.
    
    % Todo: extract dff
    
    % "import" local package using module (current folder)
    rootPath = fileparts(mfilename('fullpath'));
    %autosegment = tools.path2module(rootPath);
    
    % Also get the roimanager as a local package (1 folder up)
    rootPath = fileparts(fileparts(mfilename('fullpath')));
    %roitools = tools.path2module(rootPath);
    
    % Calculate average projection here if not given
    if nargin < 2; avgIm = mean(imArray, 3); end
    
    % Parse name, value pairs
    def = struct('RingConvolutionSearch', true); % add roiSize...
    opt = utility.parsenvpairs(def, [], varargin);
    
    % Use highjacked fprintf if available
    global fprintf 
    if isempty(fprintf); fprintf = str2func('fprintf'); end
    
    stackSize = size(imArray);

    
    tBegin = tic; % Start timer
    
    
    % Binarize stack
    fprintf(sprintf('Binarizing images...\n'))
    BW = roimanager.autosegment.binarizeStack(imArray, []);
    
    
    % Search for candidates based on activity in the binary stack
    param = [];
    S = roimanager.autosegment.getAllComponents(BW, param);
    roiArrayT = roimanager.autosegment.findUniqueRoisFromComponents(stackSize(1:2), S);
    roiArrayT = roimanager.utilities.mergeOverlappingRois(roiArrayT);
    

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
            dffS = nansen.twophoton.roisignals.computeDff(signalArrayS);
            
            % Add roi images to rois. Use to improve roi boundary estimate
            donutImageStack = roimanager.autosegment.extractRoiImages(imArray, roiArrayS, dffS');
            roiArrayS = roiArrayS.addImage(donutImageStack);
        end
    end
    
    
    % Remove candidates very close to edge of the image
    roiArrayT = roimanager.utilities.removeRoisOnBoundary(roiArrayT);
    
    
    
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
    imdata = roimanager.autosegment.extractRoiImages(imArray, roiArrayT, dffT', 'ImageType', 'correlation');
    roiArrayT = roiArrayT.addImage(imdata);
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
    
    % Finalize Results.
    fprintf('Finalizing results...\n')
    
    
    % Create roi image data stuct with different images for each roi.
    
    % Todo: This shoudl not be part of this function.......
    %[roiImageData, roiStats] = roimanager.gatherRoiData(imArray, roiArray, varargin)
    if nargout >= 2
        
        fprintf('Creating Roi Images...\n')
        
        % Add average images of roi
        %dff = autosegment.extractDff(imArray, roiArray, 'unique roi');
        signalOpts = struct('createNeuropilMask', true);
        signalArray = nansen.twophoton.roisignals.extractF(imArray, roiArray, signalOpts);
        dff = nansen.twophoton.roisignals.computeDff(signalArray);
        
        roiImA = roimanager.autosegment.extractRoiImages(imArray, roiArray, dff');
        roiImB = roimanager.autosegment.extractRoiImages(imArray, roiArray, dff', 'ImageType', 'peak dff');
        roiImC = roimanager.autosegment.extractRoiImages(imArray, roiArray, dff', 'ImageType', 'correlation');
%         roiImD = extractRoiImages(imArray, roiArray, dff, 'ImageType', 'enhanced correlation');
        
        roiArray = roiArray.addImage(roiImA);
        
        diskW = nanmean(cat(3, roiArray.enhancedImage), 3);
        
        try
            ringW = nanmean(roiImA(:, :, 1:numel(roiArrayS)), 3);
        catch
            ringW = diskW;
        end
        
        roiImA = arrayfun(@(i) roiImA(:, :, i), 1:size(roiImA,3), 'uni', 0);
        roiImB = arrayfun(@(i) roiImB(:, :, i), 1:size(roiImB,3), 'uni', 0);
        roiImC = arrayfun(@(i) roiImC(:, :, i), 1:size(roiImC,3), 'uni', 0);
%         roiImD = arrayfun(@(i) roiImD(:, :, i), 1:size(roiImD,3), 'uni', 0);

        roiImages = struct('enhancedAverage', roiImA, 'peakDff', roiImB, 'correlation', roiImC);%, 'enhancedCorrelation', roiImD);
    end
    
    if nargout >= 3
        fprintf('Calculating Roi Stats...\n')
        roiStats = roimanager.autosegment.calculateRoiStats(roiArray, roiImages, dff, ringW, diskW);
    end
    
    
    t2 = toc(tBegin);
    nRois = numel(roiArray);
    
    fprintf(sprintf('Autodetection finished. Found %d rois in %d seconds.\n', nRois, round(t2) ))
    
end

