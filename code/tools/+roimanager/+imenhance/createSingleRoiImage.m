 function [im, ul] = createSingleRoiImage(imArray, roiMask, frames, marg)
            
    % Todo: remove.
 
    if nargin < 4; marg = 7; end      

    [imHeight, imWidth] = size(roiMask);
    
    [y, x] = find(roiMask);

    minX = min(x)-marg; maxX = max(x)+marg;
    minY = min(y)-marg; maxY = max(y)+marg;

    if minX < 1; minX = 1; end 
    if minY < 1; minY = 1; end 
    if maxX > imWidth; maxX = imWidth; end 
    if maxY > imHeight; maxY = imHeight; end
    
    ul = [minX, minY];

    dff = signalExtraction.extractRoiFluorescence(imArray, roiMask);
    
%     [sorted, sortInd] = sort(dff);
    
    if ~exist('frames', 'var') || isempty(frames)
        f0 = prctile(dff, 20);
        fmax = max(dff);
        frames = dff > ((fmax-f0)/2) + f0;
    end

    im = imArray(minY:maxY, minX:maxX, frames);
    im = mean(im, 3);
    
    im = uint8( (im - min(im(:))) ./ (max(im(:)) - min(im(:)) ) * 255 );

 end
    
 