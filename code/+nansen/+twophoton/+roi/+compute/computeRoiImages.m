function roiImageStack = computeRoiImages(imArray, roiArray, roiSignals, varargin)
%computeRoiImages Compute roi images for rois
%
%   Inputs
%       imArray    : image array (nRows x nCols x nFrames)
%       roiArray   : array of rois (nRois x 1)
%       roiSignals : Signalarray (nFrames x nSubRegions x nRois)
%
%   Parameters
%       BoxSize   : size of extracted image [h, w]
%       ImageType : Name of image type to compute, see list below:
%           - 'Activity Weighted Mean'  : Mean projection image where all
%                                         frames are weighted by the signal
%                                         within the roi.
%           - 'Diff Surround'           : Difference of activity weighted
%                                         mean of roi interior and roi
%                                         surround.
%           - 'Top 99th Percentile'     : Mean projection of frames where
%                                         the roi signal is within the top
%                                         99th percentile.
%           - 'Local Correlation'       : Correlation measure of
%                                         neighboring pixels.
%           - More options are available, but either not working well or
%             should be optimized
%
%       AutoAdjust : Autoadjust contrast (boolean) - Not implemented.
%       SubtractBaseline : Subtract baseline from image array
%        
%   OUTPUTS:
%
%       roiImageStack : array or struct. If only one image is requested,
%           roiImageStack is a 3D array, otherwise it is a struct where
%           each field is the name of the image and each value is a 3D
%           array.

    
    import nansen.twophoton.roi.compute.getPixelCorrelationImage
    import nansen.twophoton.roisignals.extractF

    global fprintf % Use global fprintf if available
    if isempty(fprintf); fprintf = str2func('fprintf'); end

    % % Set default parameters and parse name value pairs.
    %  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

    def = struct();
    def.BoxSize             = [21, 21];
    def.ImageType           = 'Activity Weighted Mean';
    def.dffFcn              = 'dffClassic';
    def.AutoAdjust          = true;
    def.SubtractBaseline    = true;
    def.Debug               = false;
    def.MinNumFrames        = 50;
    def.Verbose             = true;
    
    opt = utility.parsenvpairs(def, [], varargin);

    % Check that image thumbnail size is odd (symmetry around center pixel)
    boxSize = opt.BoxSize;
    assert(all( mod(boxSize, 2) == 1), 'Boxsize should be odd')
    
    if ~opt.Verbose; fprintf = @(x) false; end
    
    % % Check size of input data and check that they correspond
    %  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    
    % Get number of frames and number of rois.
    numRois = numel(roiArray);
    [numTimepoints, ~, numRois_] = size(roiSignals);
    
    assert(numRois == numRois_, 'roiSignal must have same number or rois as roiarray')
    
    [numRows, numCols, numFrames] = size(imArray);
    assert(numFrames == numTimepoints, 'Number of frames not matching number of timepoints')
    

    % % Prepare for computing images
    %  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    
    if opt.Debug; numFrames = zeros(numRois, 1); end

    % Function for autoadjusting the contrast.
    normalizearray = @(X) (X-min(X(:))) ./ (max(X(:))-min(X(:)));
    
    % Initialise output
    if ischar(opt.ImageType); opt.ImageType = {opt.ImageType}; end
    numImages = numel(opt.ImageType);
    
    roiImageStack = cell(numImages, 1);
    roiImageStack(1:numImages) = {zeros( [boxSize, numRois], 'uint8' )};

    indX = (1:boxSize(2)) - ceil(boxSize(2)/2);
    indY = (1:boxSize(1)) - ceil(boxSize(1)/2);

    centerCoords = round(cat(1, roiArray.center));

    % % Compute dffs
    %  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    dffOpts = struct('dffFcn', opt.dffFcn);
    dff = nansen.twophoton.roisignals.computeDff(roiSignals, dffOpts);

    
    % % Loop through all images to compute and all provided rois
    %  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    
    for iRoi = 1:numRois
        
        currentRoiIm = zeros(boxSize); % initialize

        % Image coordinates for a square box centered on the roi
        tmpX = indX + centerCoords(iRoi, 1);
        tmpY = indY + centerCoords(iRoi, 2);

        % Get valid coordinates (inside image bounds)
        isValidX = tmpX >= 1 & tmpX <= numCols;
        isValidY = tmpY >= 1 & tmpY <= numRows;
        tmpX = tmpX(isValidX);
        tmpY = tmpY(isValidY);
        
        % Get image array chunk centered on roi center point
        imArrayChunk = double( imArray(tmpY, tmpX, :) );
        if opt.SubtractBaseline
            imArrayChunk = imArrayChunk - mean(imArrayChunk(:));
        end
        
        for jImage = 1:numImages
            
            imageType = lower( opt.ImageType{jImage} );

            frameInd = 1:numFrames;

            % % Get subset of frame indices and/or weights for each frame:
            %  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            
            if contains(imageType, 'enhanced')
                % Set activity threshold. Todo: Optimize this based on more
                % informed methods.
                val = prctile(dff(:, iRoi), [5, 50]);
                thresh = val(2) + val(2)-val(1);

                frameInd = dff(:, iRoi) > thresh; 
                frameInd = imdilate(frameInd, ones(1,5) );

            elseif contains(imageType, 'top 99th percentile')
                [~, descendingFrameInd] = sort(dff(:, iRoi), 'descend');
                nFramesSubset =  round(numFrames .* 0.01);
                frameInd = descendingFrameInd(1:nFramesSubset);

            elseif contains(imageType, 'peak')
                % Find the frame number of peak dff
                [~, frameInd] = max(dff(:, iRoi));

            elseif contains(imageType, 'weighted')
                W = getWeights( normalizearray(dff(:, iRoi)) );
                
            else
                % pass...
            end

            % Try to use at least minimum number of frames
            if sum(frameInd) < opt.MinNumFrames
                [~, sortedFrameInd] = sort(dff(:, iRoi), 'descend');
                nFramesSubset = min( [opt.MinNumFrames, numel(sortedFrameInd)]);
                frameInd = sortedFrameInd(1:nFramesSubset);
            end

            if opt.Debug
                numFrames(iRoi) = sum(frameInd);
            end
            
            if contains(imageType, 'weighted')
                imArrayChunkTmp = imArrayChunk .* reshape(W, 1, 1, []);
            else
                imArrayChunkTmp = imArrayChunk(:, :, frameInd);
            end
            
            
            % % Create the image:
            %  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            
            switch imageType
                case {'mean', 'activity weighted mean', 'top 99th percentile'}
                    currentRoiIm = mean(imArrayChunkTmp, 3);                

                case {'std', 'activity weighted std'} % not as good as mean
                    currentRoiIm = std(imArrayChunkTmp, 0, 3);                

                case {'max', 'activity weighted max'} % crap if cell is not active
                    currentRoiIm = max(imArrayChunkTmp, [], 3);
                    
                case 'local correlation'
                    currentRoiIm = stack.zproject.localCorrelation(imArrayChunkTmp);

                case 'global correlation'
                    currentRoiIm = stack.zproject.globalCorrelation(imArrayChunkTmp);

                case 'median correlation' % use lower percentile for signal extraction to avoid selection bias?
                    f_ = extractF(imArray, roiArray(iRoi), 'pixelComputationMethod', 'median');
                    [rhoIm, ~] = getPixelCorrelationImage(f_(frameInd, 1), imArrayChunkTmp);
                    rhoIm(isnan(rhoIm)) = 0;
                    currentRoiIm = rhoIm;

                case 'enhanced dff' % not very good...
                    dffStack = calculateDFFStack(imArray(tmpY, tmpX, :));
                    currentRoiIm = mean(dffStack(:, :, frameInd), 3);

                case 'diff surround'
                    f = roiSignals(:, :, iRoi);
                    froi = smoothdata(f(:,1));
                    fpil = smoothdata(f(:,2));

                    fdiff = normalizearray( froi - fpil );
                    W = getWeights(fdiff);

                    imArrayChunkW = imArrayChunkTmp .* reshape(W, 1, 1, []);
                    currentRoiIm = mean(imArrayChunkW, 3);                

                case 'diff surround orig'
                    % NB : can show signal when there is none
                    f = roiSignals(:, :, iRoi);
                    
                    % Normalize each column of f:
                    f_ = (f - min(f)) ./ (max(f)-min(f));
                    W = getWeights(f_);

                    imArrayChunkW1 = double(imArrayChunkTmp) .* reshape(W(:,1), 1, 1, []);
                    currentRoiIm1 = mean(imArrayChunkW1, 3);                
                    %currentRoiIm1 = normalizeimage(currentRoiIm1);

                    imArrayChunkW2 = double(imArrayChunkTmp) .* reshape(W(:,2), 1, 1, []);
                    currentRoiIm2 = mean(imArrayChunkW2, 3);                
                    %currentRoiIm2 = normalizeimage(currentRoiIm2);

                    if sum(currentRoiIm1(:)) > sum(currentRoiIm2(:))
                        currentRoiIm = currentRoiIm1-currentRoiIm2;
                    else
                        currentRoiIm = currentRoiIm2-currentRoiIm1;
                    end

            end
            
            if opt.AutoAdjust
                currentRoiIm = normalizearray(currentRoiIm);
                currentRoiIm = uint8(currentRoiIm.*255); % Todo: cast to other types?
            end
            
            % Add image to the stack
            roiImageStack{jImage}(isValidY, isValidX, iRoi) = currentRoiIm;
            
        end
        
        % Display message indicating progress
        if mod(iRoi, 10)==0 || iRoi == numRois
            if exist('str', 'var')
                fprintf( char(8*ones(1,length(str))));
            end
            
            str = sprintf('Created images for %d/%d rois...', iRoi, numRois);
            fprintf(str)
        end
    end
    
    if exist('str', 'var'); fprintf(newline); end
    
    if numImages == 1
        roiImageStack = roiImageStack{1};
    else
        imageNames = cellfun(@(str) strrep(str, ' ', ''), opt.ImageType, 'uni', 0);
        roiImageStack = cell2struct(roiImageStack, imageNames);
    end

end


function dff = calculateDFFStack(im)

    baseline = double(prctile(im, 25, 3));
    baseline(baseline<1) = 1;
    
    im = double(im);
    dff = (im-baseline) ./ baseline;
    dff = dff ./ max(dff(:));

end


function W = getWeights(f)
%getWeights Get weights from signal using a sigmoidal function.
    c1 = 10;
    c2 = 0.5;

    W = 1 ./ (1 + exp(-c1 .* (f-c2) ));
end
