function [roiArray, roiImages, roiStats] = autosegmentAxon(imArray, varargin)
    
    % Use highjacked fprintf if available
    global fprintf 
    if isempty(fprintf); fprintf = str2func('fprintf'); end

    % Parse name value pairs
    def = struct('MaxNumRois', 300); % RoiSize
    param = utility.parsenvpairs(def, [], varargin);
    
    
    stackSize = size(imArray);
    
    tBegin = tic; % Start timer
    
    % Binarize stack
    t1=tic;
    fprintf('Binarizing images... ')    
    BW = roimanager.autosegment.binarizeStack(imArray, 'RoiType', 'axon');
    t2 = toc(t1);
    fprintf(sprintf('Elapsed time is %.2f seconds.\n', t2))
    
    % Search for candidates based on activity in the binary stack
    S = flufinder.detect.getBwComponentStats(BW, param);
    
    t1=tic;
    fprintf('Searching for unique candidates... ')
    roiArrayT = flufinder.detect.findUniqueRoisFromComponents(stackSize, S, 'filterByArea', false, 'nRoisToFind', param.MaxNumRois); %, 'roiClass', 'axon');
    roiArrayT = roimanager.utilities.mergeOverlappingRois(roiArrayT);
    t2 = toc(t1);
    fprintf('Elapsed time is %.2f seconds.\n', t2)

    
    % Remove candidates very close to edge of the image
    roiArrayT = roimanager.utilities.removeRoisOnBoundary(roiArrayT);
    
% %     % Todo: Speed this up. Dont use neuropil subtraction...
    t1=tic;
    fprintf('Extracting signals for active rois... ')
    
    % Very old version
%     fRoi = signalExtraction.multiExtractF(imArray, roiArrayT, 'unique roi'); 
%     fRoi0 = prctile(fRoi,20, 2);
%     dffT = (fRoi - fRoi0) ./ fRoi0;
    
    % Old version
    %dffT = autosegment.extractDff(imArray, roiArrayT, 'unique roi'); % <- Faster than above

    % New version:
    signalOpts = struct('createNeuropilMask', false);
    signalArray = nansen.twophoton.roisignals.extractF(imArray, roiArrayT, signalOpts);
    dffT = nansen.twophoton.roisignals.computeDff(signalArray);
    
    
    t2 = toc(t1);
    fprintf('Elapsed time is %.2f seconds.\n', t2)


% %     % Remove rois that dont have a signal. Due to being covered by other
% %     % rois. Todo. Find a better solution...
% %     discard = isnan(sum(dffT, 2));
% %     roiArrayT(discard) = [];
% %     dffT(discard, :) = [];


    % % % Improve roi estimate for active cells.
    t1=tic;
    fprintf('Creating images for detected rois...')
    %imdata = roitools.extractRoiImages(imArray, roiArrayT, dffT, 'ImageType', 'correlation');
    
    % Todo: Should dff be transposed???
    imdata = roimanager.autosegment.extractRoiImages(imArray, roiArrayT, dffT', 'ImageType', 'correlation');
    
    roiArrayT = roiArrayT.addImage(imdata);
    t2 = toc(t1);
    fprintf('Elapsed time is %.2f seconds.\n', t2)
    % %     [roiArrayT, ~] = improveMaskEstimate2(roiArrayT, 'axon');

        
    
    % Todo: Deal with multiple overlaps:
    
    % Merge overlapping rois in the activity based roi Array.
% %     roiArrayT = mergeOverlappingRois(roiArrayT, 0.7, 'intersect');

    
        
    % Remove small rois:
    areas = [roiArrayT.area];
    keep = areas > 50 & areas < 200;
%     roiArrayT = roiArrayT(keep);

    
    roiArray = roiArrayT;
    

    % Create roi image data stuct with different images for each roi.
    if nargout >= 2
        % Finalize Results.
        fprintf('Finalizing results...\n')
        
        % Todo: fixit:
        % Add average images of roi
% %         dff = roitools.extractDff(imArray, roiArray);
% %         

% %         % Old version
% %         tic; fRoi = signalExtraction.multiExtractF(imArray, roiArray, 'raw'); toc
% %         fRoi0 = prctile(fRoi,20, 2);
% %         dff = (fRoi - fRoi0) ./ fRoi0;
        
        
        % New version (nansen):
        signalOpts = struct('createNeuropilMask', false, 'excludeRoiOverlaps', false);
        signalArray = nansen.twophoton.roisignals.extractF(imArray, roiArrayT, signalOpts);
        dff = nansen.twophoton.roisignals.computeDff(signalArray);
        
        roiImA = roimanager.autosegment.extractRoiImages(imArray, roiArray, dff');
        roiImB = roimanager.autosegment.extractRoiImages(imArray, roiArray, dff', 'ImageType', 'peak dff');
        roiImC = roimanager.autosegment.extractRoiImages(imArray, roiArray, dff', 'ImageType', 'correlation');
        roiImD = roimanager.autosegment.extractRoiImages(imArray, roiArray, dff', 'ImageType', 'enhanced correlation');
        
        ringW = nanmean(roiImA(:, :, 1:numel(roiArray)), 3);
        diskW = nanmean(cat(3, roiArray.enhancedImage), 3);
        
        roiImA = arrayfun(@(i) roiImA(:, :, i), 1:size(roiImA,3), 'uni', 0);
        roiImB = arrayfun(@(i) roiImB(:, :, i), 1:size(roiImB,3), 'uni', 0);
        roiImC = arrayfun(@(i) roiImC(:, :, i), 1:size(roiImC,3), 'uni', 0);
        roiImD = arrayfun(@(i) roiImD(:, :, i), 1:size(roiImD,3), 'uni', 0);

        roiImages = struct('enhancedAverage', roiImA, 'peakDff', roiImB, 'correlation', roiImC, 'enhancedCorrelation', roiImD);
    end
    
    if nargout >= 3
        roiStats = roimanager.autosegment.calculateRoiStats(roiArray, roiImages, dff, ringW, diskW);
    end
    
    t2 = toc(tBegin);
    nRois = numel(roiArray);
    
    fprintf('Autodetection finished. Found %d rois in %d seconds.\n', nRois, round(t2) )
    
    fprintf = '';
end