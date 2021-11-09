function [roiArray, roiImages, roiStats] = autosegmentAxon(imArray, varargin)
    
%todo...

    % "import" local package using path2module
    rootPath = fileparts(mfilename('fullpath'));
    autosegment = tools.path2module(rootPath);

    % Also get the roimanager as a local package (1 folder up)
    rootPath = fileparts(fileparts(mfilename('fullpath')));
    roitools = tools.path2module(rootPath);
    
    % Use highjacked fprintf if available
    global fprintf 
    if isempty(fprintf); fprintf = str2func('fprintf'); end

    % Parse name value pairs
    def = struct('nRoisToFind', 300); % RoiSize
    param = utility.parsenvpairs(def, [], varargin);
    
    
    stackSize = size(imArray);
    
    tBegin = tic; % Start timer
    
    % Binarize stack
    t1=tic;
    fprintf('Binarizing images... ')    
    BW = autosegment.binarizeStack(imArray, [], 'axon');
    t2 = toc(t1);
    fprintf(sprintf('Elapsed time is %.2f seconds.\n', t2))
    
    % Search for candidates based on activity in the binary stack
    S = autosegment.getAllComponents(BW, param);
    
    t1=tic;
    fprintf('Searching for unique candidates... ')
    roiArrayT = autosegment.findUniqueRoisFromComponents(stackSize, S, 'filterByArea', false, 'nRoisToFind', param.nRoisToFind); %, 'roiClass', 'axon');
    roiArrayT = roitools.mergeOverlappingRois(roiArrayT);
    t2 = toc(t1);
    fprintf('Elapsed time is %.2f seconds.\n', t2)

    
    % Remove candidates very close to edge of the image
    roiArrayT = roitools.removeRoisOnBoundary(roiArrayT);
    
    
% %     % Todo: Speed this up. Dont use neuropil subtraction...
    t1=tic;
    fprintf('Extracting signals for active rois... ')
    
%     fRoi = signalExtraction.multiExtractF(imArray, roiArrayT, 'unique roi'); 
%     fRoi0 = prctile(fRoi,20, 2);
%     dffT = (fRoi - fRoi0) ./ fRoi0;
    
    dffT = autosegment.extractDff(imArray, roiArrayT, 'unique roi'); % <- Faster than above

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
    imdata = roitools.extractRoiImages(imArray, roiArrayT, dffT, 'ImageType', 'correlation');
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
        dff = roitools.extractDff(imArray, roiArray);
        
        tic; fRoi = signalExtraction.multiExtractF(imArray, roiArray, 'raw'); toc
        fRoi0 = prctile(fRoi,20, 2);
        dff = (fRoi - fRoi0) ./ fRoi0;
        
        roiImA = roitools.extractRoiImages(imArray, roiArray, dff);
        roiImB = roitools.extractRoiImages(imArray, roiArray, dff, 'ImageType', 'peak dff');
        roiImC = roitools.extractRoiImages(imArray, roiArray, dff, 'ImageType', 'correlation');
        roiImD = roitools.extractRoiImages(imArray, roiArray, dff, 'ImageType', 'enhanced correlation');
        
        ringW = nanmean(roiImA(:, :, 1:numel(roiArrayS)), 3);
        diskW = nanmean(cat(3, roiArrayT.enhancedImage), 3);
        
        roiImA = arrayfun(@(i) roiImA(:, :, i), 1:size(roiImA,3), 'uni', 0);
        roiImB = arrayfun(@(i) roiImB(:, :, i), 1:size(roiImB,3), 'uni', 0);
        roiImC = arrayfun(@(i) roiImC(:, :, i), 1:size(roiImC,3), 'uni', 0);
        roiImD = arrayfun(@(i) roiImD(:, :, i), 1:size(roiImD,3), 'uni', 0);

        roiImages = struct('enhancedAverage', roiImA, 'peakDff', roiImB, 'correlation', roiImC, 'enhancedCorrelation', roiImD);
    end
    
    if nargout >= 3
        roiStats = roitools.calculateRoiStats(roiArray, roiImages, dff, ringW, diskW);
    end
    
    t2 = toc(tBegin);
    nRois = numel(roiArray);
    
    fprintf('Autodetection finished. Found %d rois in %d seconds.\n', nRois, round(t2) )
    
end