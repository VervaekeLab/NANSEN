function roiImageStack = extractRoiImages(imArray, roiArray, dff, varargin)
% 
% Inputs
%   dff     : Signalarray (nRois x nFrames)
%
% Parameters
%   BoxSize   : size of extracted image [h, w]
%   ImageType : 'average' | 'correlation' | 'peak dff' | 'enhanced average' | 'enhanced correlation' | 'correlation product' 
%   AutoAdjust : Autoadjust contrast (boolean) - Not implemented.


def = struct('BoxSize', [21, 21], 'ImageType', 'enhanced average', 'AutoAdjust', true, 'Debug', false);
opt = utility.parsenvpairs(def, [], varargin);

% Get the roimanager as a local package (1 folder up)
rootPath = fileparts(fileparts(mfilename('fullpath')));
roitools = tools.path2module(rootPath);


boxSize = opt.BoxSize;
assert(all(mod(boxSize,2)==1), 'Boxsize should be odd')


% Function for autoadjusting the contrast.
normalizeimage = @(im) (im-min(im(:))) ./ (max(im(:))-min(im(:))) .* 255;


% Get number of frames and number of rois.
nRois = numel(roiArray);
signalSize = size(dff);
nFrames = signalSize(signalSize~=nRois & signalSize~=1);


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
    
    % Todo: Adapt to work also for rois close to edges of image. E.g pad by
    % nans or zeros

    
    % Some preparation
    if contains(opt.ImageType, 'enhanced')
        % Set activity threshold. Todo: Optimize this based on more
        % informed methods.
        val = prctile(dff(i, :), [5, 50]);
        thresh = val(2) + val(2)-val(1);

        frameInd = dff(i, :) > thresh; 
        frameInd = imdilate(frameInd, ones(1,5) );
        
    elseif contains(opt.ImageType, 'peak')
        % Find the frame number of peak dff
        [~, frameInd] = max(dff(i, :));
        
    elseif contains(opt.ImageType, 'multipeak')
        [~, peakSortedFrameInd] = sort(dff(i, :), 'descend');
        frameInd = peakSortedFrameInd(1:20);
        error('Not Implemented')
        
    else
        frameInd = 1:nFrames;
    end
    
    
    if sum(frameInd) < 50
        [~, peakSortedFrameInd] = sort(dff(i, :), 'descend');
        frameInd = peakSortedFrameInd(1:min([50,numel(peakSortedFrameInd)]));
    end
    
    
    if opt.Debug
        nFrames(i) = sum(frameInd);
    end
    
    try
    % Create the image
    switch lower(opt.ImageType)
        case {'average', 'enhanced average', 'peak dff'}
            currentRoiIm = mean(imArray(tmpY, tmpX, frameInd), 3);
            currentRoiIm = normalizeimage(currentRoiIm);
        case {'correlation', 'enhanced correlation'}
            [rhoIm, ~] = roitools.getPixelCorrelationImage(dff(i, frameInd)', imArray(tmpY, tmpX, frameInd));
            rhoIm(isnan(rhoIm)) = 0;
            currentRoiIm = rhoIm.*255;
    end
    end
       
    % Add image to the stack
    roiImageStack(:, :, i) = currentRoiIm;
end
