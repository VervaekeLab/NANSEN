function roiImageStack = extractRoiImages(imArray, roiArray, dff, varargin)
%
% Inputs
%   dff     : Signalarray (nRois x nFrames)
%
% Parameters
%   BoxSize   : size of extracted image [h, w]
%   ImageType : 'average' | 'correlation' | 'peak_dff' | 'enhanced_average' | 'enhanced_correlation' | 'correlation_product'
%   AutoAdjust : Autoadjust contrast (boolean) - Not implemented.

% Todo:
%   [ ] Dff should be nFrames x nRois!
%   [ ] move out of autosegmentation
%   [ ] autoadjust

def = struct('BoxSize', [21, 21], 'ImageType', 'enhanced_average', ...
    'AutoAdjust', true, 'SubtractBaseline', true, 'Debug', false);
opt = utility.parsenvpairs(def, [], varargin);

% Get the roimanager as a local package (1 folder up)
%rootPath = fileparts(fileparts(mfilename('fullpath')));
%roitools = tools.path2module(rootPath);
import nansen.twophoton.roi.compute.getPixelCorrelationImage

boxSize = opt.BoxSize;
assert(all(mod(boxSize,2)==1), 'Boxsize should be odd')

imageType = lower( opt.ImageType );

% Function for autoadjusting the contrast.
normalizeimage = @(im) (im-min(im(:))) ./ (max(im(:))-min(im(:))) .* 255;

% Get number of frames and number of rois.
nRois = numel(roiArray);
signalSize = size(dff);
nFrames = signalSize(signalSize~=nRois & signalSize~=1);

[numRows, numCols, ~] = size(imArray);
assert(nFrames == size(imArray,3), 'Number of frames not matching')

if opt.Debug
    nFrames = zeros(nRois, 1);
end

roiImageStack = zeros( [boxSize, nRois] );

indX = (1:boxSize(2)) - ceil(boxSize(2)/2);
indY = (1:boxSize(1)) - ceil(boxSize(1)/2);

centerCoords = round(cat(1, roiArray.center));

for i = 1:nRois
    
    currentRoiIm = zeros(boxSize);
    
    % Image coordinates for a square box centered on the roi
    tmpX = indX + centerCoords(i, 1);
    tmpY = indY + centerCoords(i, 2);

    frameInd = 1:nFrames;

    % Some preparation
    if contains(imageType, 'enhanced')
        % Set activity threshold. Todo: Optimize this based on more
        % informed methods.
        val = prctile(dff(i, :), [5, 50]);
        thresh = val(2) + val(2)-val(1);

        frameInd = dff(i, :) > thresh;
        frameInd = imdilate(frameInd, ones(1,5) );
       
    elseif contains(imageType, 'multipeak')
        [~, peakSortedFrameInd] = sort(dff(i, :), 'descend');
        frameInd = peakSortedFrameInd(1:min([20, nFrames]));
        %error('Not Implemented')
        
    elseif contains(imageType, 'top 99th percentile')
        [~, peakSortedFrameInd] = sort(dff(i, :), 'descend');
        nFrames10 =  round(nFrames .* 0.01);
        frameInd = peakSortedFrameInd(1:nFrames10);

    elseif contains(imageType, 'peak')
        % Find the frame number of peak dff
        [~, frameInd] = max(dff(i, :));
            
    elseif contains(imageType, 'weighted')
        dff_tmp = dff(i,:);
        dff_norm = (dff_tmp - min(dff_tmp)) ./ (max(dff_tmp)-min(dff_tmp));
        W = getWeights(dff_norm);

    elseif contains(imageType, 'percentile90')
        
    else
        % pass...
    end
    
    if sum(frameInd) < 50
        [~, peakSortedFrameInd] = sort(dff(i, :), 'descend');
        frameInd = peakSortedFrameInd(1:min([50,numel(peakSortedFrameInd)]));
    end
    
    if opt.Debug
        nFrames(i) = sum(frameInd);
    end
    
    isValidX = tmpX >= 1 & tmpX <= numCols;
    isValidY = tmpY >= 1 & tmpY <= numRows;
    tmpX = tmpX(isValidX);
    tmpY = tmpY(isValidY);
    
    % Create the image
    switch lower(opt.ImageType)
        case {'average', 'enhanced average', 'peak dff', 'enhancedaverage', 'peakdff', 'enhanced_average'}
            currentRoiIm = mean(imArray(tmpY, tmpX, frameInd), 3);
            currentRoiIm = normalizeimage(currentRoiIm);
        case {'correlation', 'enhanced correlation', 'enhancedcorrelation', 'enhanced_correlation'}
            [rhoIm, ~] = getPixelCorrelationImage(dff(i, frameInd)', imArray(tmpY, tmpX, frameInd));
            rhoIm(isnan(rhoIm)) = 0;
            currentRoiIm = rhoIm.*255;
    end
    
    isValidX = tmpX >= 1 & tmpX <= numCols;
    isValidY = tmpY >= 1 & tmpY <= numRows;
    tmpX = tmpX(isValidX);
    tmpY = tmpY(isValidY);
    
    imArrayChunk = imArray(tmpY, tmpX, :);
    if opt.SubtractBaseline
        imArrayChunk = imArrayChunk - median(imArrayChunk(:));
    end
    
    try
        % Create the image
        switch imageType
            case 'activity weighted mean'
                imArrayChunkW = double(imArrayChunk) .* reshape(W, 1, 1, []);
                currentRoiIm = mean(imArrayChunkW, 3);
                currentRoiIm = normalizeimage(currentRoiIm);
                
            case 'activity weighted std' % not as good as mean
                imArrayChunkW = double(imArrayChunk) .* reshape(W, 1, 1, []);
                currentRoiIm = std(imArrayChunkW, 0, 3);
                currentRoiIm = normalizeimage(currentRoiIm);
                
            case 'std' % not good
                currentRoiIm = std(double(imArrayChunk(:, :, frameInd)), 0, 3);
                currentRoiIm = normalizeimage(currentRoiIm);
                
            case 'activity weighted max' % crap if cell is not active
                imArrayChunkW = double(imArrayChunk) .* reshape(W, 1, 1, []);
                currentRoiIm = max(imArrayChunkW, [], 3);
                currentRoiIm = normalizeimage(currentRoiIm);
            
            case {'average', 'enhanced average', 'peak dff', 'enhancedaverage', 'peakdff', 'enhanced_average', 'peak activity', 'multipeak', 'top 99th percentile'}
                %imArrayChunk = imArray(tmpY, tmpX, :);
                %if opt.SubtractBaseline
                    %imArrayChunk = imArrayChunk - median(imArrayChunk(:));
                %end
                currentRoiIm = mean(imArrayChunk(:, :, frameInd), 3);
                currentRoiIm = normalizeimage(currentRoiIm);
                
            case 'local correlation'
                currentRoiIm = stack.zproject.localCorrelation(double(imArrayChunk));
                currentRoiIm = normalizeimage(currentRoiIm);
            
            case 'global correlation'
                currentRoiIm = stack.zproject.globalCorrelation(double(imArrayChunk));
                currentRoiIm = normalizeimage(currentRoiIm);
                
            case {'correlation', 'enhanced correlation', 'enhancedcorrelation', 'enhanced_correlation', 'correlation image'}

                %f = nansen.twophoton.roisignals.extractF(imArray, roiArray(i));
                %f_ = nansen.twophoton.roisignals.extractF(imArray, roiArray(i), 'pixelComputationMethod', 'median');
                
                % This is a really bad idea. Always shows correlation
% %                 [rhoIm, ~] = getPixelCorrelationImage(dff(i, frameInd)', imArray(tmpY, tmpX, frameInd));
% %                 rhoIm(isnan(rhoIm)) = 0;
% %                 currentRoiIm = rhoIm.*255;
            case 'median correlation'
                f_ = nansen.twophoton.roisignals.extractF(imArray, roiArray(i), 'pixelComputationMethod', 'median');
                [rhoIm, ~] = getPixelCorrelationImage(f_(frameInd, 1), imArray(tmpY, tmpX, frameInd));
                rhoIm(isnan(rhoIm)) = 0;
                currentRoiIm = rhoIm.*255;
                
            case 'enhanced dff' % not very good...
                dff = calculateDFFStack(imArray(tmpY, tmpX, :));
                currentRoiIm = mean(dff(:, :, frameInd), 3);
                currentRoiIm = normalizeimage(currentRoiIm);
            
            case 'percentile90'
                % not a good idea.
                imArrayChunk = sort(imArrayChunk, 3, 'descend');
                numFrames =  round(numel(frameInd) .* 0.1);
                currentRoiIm = mean(imArrayChunk(:, :, 1:numFrames), 3);
                currentRoiIm = normalizeimage(currentRoiIm);
                
            case 'diff surround'
                % NB : can show signal when there is none
                f = nansen.twophoton.roisignals.extractF(imArray, roiArray(i));
                froi = smoothdata(f(:,1));
                fpil = smoothdata(f(:,2));
                
                fdiff = froi - fpil;
                fdiff = (fdiff - min(fdiff)) ./ (max(fdiff)-min(fdiff));

                W = getWeights(fdiff);

                imArrayChunkW = double(imArrayChunk) .* reshape(W(:,1), 1, 1, []);
                currentRoiIm = mean(imArrayChunkW, 3);
                currentRoiIm = normalizeimage(currentRoiIm);
                
            case 'diff surround orig'
                % NB : can show signal when there is none
                f = nansen.twophoton.roisignals.extractF(imArray, roiArray(i));
                
                f_ = (f - min(f)) ./ (max(f)-min(f));
                W = getWeights(f_);
                
                imArrayChunkW1 = double(imArrayChunk) .* reshape(W(:,1), 1, 1, []);
                currentRoiIm1 = mean(imArrayChunkW1, 3);
                %currentRoiIm1 = normalizeimage(currentRoiIm1);
                
                imArrayChunkW2 = double(imArrayChunk) .* reshape(W(:,2), 1, 1, []);
                currentRoiIm2 = mean(imArrayChunkW2, 3);
                %currentRoiIm2 = normalizeimage(currentRoiIm2);
                
                if sum(currentRoiIm1(:)) > sum(currentRoiIm2(:))
                    currentRoiIm = currentRoiIm1-currentRoiIm2;
                else
                    currentRoiIm = currentRoiIm2-currentRoiIm1;
                end
                currentRoiIm = normalizeimage(currentRoiIm);
                
        end
    catch %ME
        fprintf('Failed to create roi thumbnail image.\n')
    end
    
    % Add image to the stack
    roiImageStack(isValidY, isValidX, i) = currentRoiIm;
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
