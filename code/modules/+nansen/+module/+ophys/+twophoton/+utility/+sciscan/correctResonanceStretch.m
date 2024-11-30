function [ new_im ] = correctResonanceStretch(im, scanParam, method, binSize)
%correctResonanceStretch Corrects the resonance scanning "stretch effect".
%   IM = correctResonanceStretch( IM, SCANPARAM, METHOD) corrects
%   stretch in images due to the sinusoidal speed profile of the resonance
%   mirror.
%
%   Inputs:
%       IM : Single image (2d array) or stack of images (3d array)
%       SCANPARAM : Struct with two fields, zoom and xcorrect.
%       METHOD : 'imwarp' or 'imresize'. Imwarp gives better results,
%       imresize is faster. See google drive/osloscope/stretch correction
%       BINSIZE : optional, only needed for 'imresize'. Width of image
%       strips that are stretched or destretched.
%
%   How it works:
%       For IMRESIZE: The image is split into strips spanning the
%       entire height where width is determined by binSize (default, 8).
%       Each image strip is stretched or destretched using matlabs imresize
%       function based on a stretch profile which is loaded from lookup
%       table.
%
%       For IMWARP: The image is warped using matlabs imwarp function. The
%       displacement matrix is loaded from the destretch lookup table. It
%       will take some more time because it need to run a few iterations on
%       each image.
%
%   See also: findStretchProfileFromMicrogrid, findStretchProfilesBatch

% Todo: Find profile which is recorded on the closest date.

if nargin < 4
    binSize = 8;
end

if nargin < 3
    method = 'imwarp';
end

% Get size of images
imSize = size(im);
height = imSize(1); width = imSize(2);
if numel(imSize) == 2
    nFrames = 1;
else
    nFrames = imSize(3);
end

zoom = scanParam.zoom;
xcorrect = scanParam.xcorrect;
scanParam.width = width;
zoom = scanParam.zoom;
xcorrect = scanParam.xcorrect;

% Load destretching lookup table
folder = fileparts( mfilename('fullpath') );
LUTFILENAME = fullfile(folder, '_lookup', 'destretch_lut.mat');
S = load(LUTFILENAME, 'destretchLookup');
destretchLookup = S.destretchLookup;

% Find best zoomfactor based on image resolution
xPixelResolution = [destretchLookup.ImageWidth];
lutCandidates = find(xPixelResolution == width);

availableZooms = [destretchLookup(lutCandidates).ZoomFactor];

bestZoomInd = find((availableZooms-zoom)==0);

if isempty(bestZoomInd)
    [zoomDiff, bestZoomInd] = min(abs(availableZooms-zoom));
else
    bestZoomInd = bestZoomInd(end);
    zoomDiff = 0;
end

% Display warning if current zoom factor is not available.
if zoomDiff ~= 0
    warning('SciScan:StretchProfileMissing', 'Could not find stretch correction profile for current zoom factor (%.3f). Stretch correction will use the profile for the closest available zoom factor (%.3f)', ...
             zoom, availableZooms(bestZoomInd) )
end

lookupIdx = lutCandidates(bestZoomInd);

% Display warning if the x.correct values does not match.
if destretchLookup(lookupIdx).XCorrection ~= xcorrect
    % warning('Correcting stretch beased on a different value of the SciScan parameter x.correct. Result might be suboptimal.')
end

stackSize = size(im);
im = reshape(im, stackSize(1), stackSize(2), []);

% prevstr=[];
switch method
    case 'imresize'
        % BinSize should be factor of image width
        assert( mod(width, binSize) == 0, 'BinSize should be a factor of image width' )

        y = destretchLookup(lookupIdx).XOffset;

        % Find the incremental changes in speed of mirror
        diffY = diff(y);
        diffY = horzcat(diffY(1), diffY);

        nBins = width / binSize;
        
        % Calculate new binsizes for all the bins.
        newBinSizes = binSize - round(sum(reshape(diffY,  [], nBins), 1));
        newBinSizes(newBinSizes<=0) = 1;

        % Create empty image stack (preallocate)
        newWidth = sum(newBinSizes);
        new_im = zeros(height, newWidth, nFrames, 'like', im);

        % Create indices for putting image stripes into new image stack
        newBinStartIdx = horzcat(1, cumsum(newBinSizes) + 1);
        newBinStopIdx = horzcat(cumsum(newBinSizes));

        % Loop through images. Split into stripes and compress each
        % stripe based on the new calculated binsize
        c = 0;
        for bin = 1:binSize:width
            imStrip = im(:, bin:bin+binSize-1, :);
            c = c+1;
            imStrip = imresize(imStrip, [height, newBinSizes(c)]);
            new_im(:, newBinStartIdx(c):newBinStopIdx(c), :) = imStrip;
        end
        
    case 'imwarp'
        
        % Create displacement grid.
        
        displacementX = destretchLookup(lookupIdx).DisplacementX;
        if ~isa(displacementX, 'cell'); displacementX = {displacementX}; end
        nIter = numel(displacementX);
        
        for iter = 1%:nIter
            Dx = repmat(displacementX{iter}, size(im, 1), 1);
            Dy = zeros(size(Dx));
            
            % Fixed the displacementfield, no need for multiple
            % iterations. Important that the dim argument is 2, so that
            % interpolation happens along the xaxis.
            D = createDisplacementFieldFromPixelShifts(-Dx, -Dy, 2);
            
%             D = round(cat(3, Dx, Dy));
        
%             % Apply displacement field
%             for i = 1:nFrames
%                 im(:,:,i) = imwarp(im(:,:,i), D, 'cubic');
%             end

            im = imwarp(im, D, 'cubic');
            
            if isa(im, 'logical')
                dummy = ones(size(im)); dummy = imwarp(dummy, D, 'cubic');
                cropLeft = find(dummy(round(size(im, 1)/2),:,1) ~= 0, 1, 'first') - 1;
                cropRight = width - find(dummy(round(size(im, 1)/2),:,1) ~= 0, 1, 'last');
            else
                cropLeft = find(im(round(size(im, 1)/2),:,1) ~= 0, 1, 'first') - 1;
                cropRight = width - find(im(round(size(im, 1)/2),:,1) ~= 0, 1, 'last');
            end
            
            im = im(:, cropLeft+1:end-cropRight, :);
            [height, width, nFrames] = size(im);
        end
        
        new_im = im;

end

%     % Print progress in command window
%     if mod(n, 50) == 0 && nFrames > 1
%         str=['squeezing frame ' num2str(n) '/' num2str(nFrames)];
%         refreshdisp(str, prevstr, n);
%         prevstr=str;
%     end

% % Print finish message in command window
% if  nFrames > 1
%     fprintf(char(8*ones(1,length(prevstr))));
%     fprintf('Squeezed all images.');
%     fprintf('\n');
% end

% Todo move this to load SciScanStack
% Make image square
% new_im = new_im((1:newWidth) + floor((height-newWidth)/2), :, :);

% Restore original size (but make sure to update the length of the
% dimension that was destretched)
stackSize(2) = size(new_im, 2);
new_im = reshape(new_im, stackSize);

% Remove singleton dimension...
new_im = squeeze(new_im);

end

function [D, BW] = createDisplacementFieldFromPixelShifts(shiftX, shiftY, dim)

if nargin < 3; dim = 1; end

imSize = size(shiftX);
imCenter = mean([1, imSize(1); 1, imSize(2)], 2);

% Create a grid of original x and y coordinates.
[yy1, xx1] = ndgrid((1:imSize(1)) - imCenter(1), (1:imSize(2)) - imCenter(2));
xx2 = xx1 + shiftX;
yy2 = yy1 + shiftY;

% Find old and new indices of each image pixel.
[row, col] = ndgrid(1:imSize(1), 1:imSize(2));

% Find pixel coordinates from the cartesian coordinates.
xx2im = xx2 + imCenter(2); % shift right
yy2im = yy2 + imCenter(1); % shift down

% yy2im = imSize(1) - (yy2 + imCenter(1)) + 1; % Shift up and reverse

% Find linear indices of initial (old) pixel coordinates
oldIND = sub2ind(imSize(1:2), row(:), col(:));

% Ignore pixel indices which have been shifted outside of image boundary.
valid = yy2im(:) >= 1 & yy2im(:) <= imSize(1) & xx2im(:) >= 1 & xx2im(:) <= imSize(2);
yy2im(~valid) = 1;
xx2im(~valid) = 1;

% Find linear indices of shifted (new) pixel coordinates
newIND = sub2ind(imSize(1:2), round(yy2im(:)), round(xx2im(:)));

% Initialize Dx and Dy.
Dx = nan(imSize(1:2));
Dy = nan(imSize(1:2));

% "Invert" the shifts, to fit with the displacementfield convention.
Dx(newIND) = -shiftX(oldIND);
Dy(newIND) = -shiftY(oldIND);

% Create a mask representing area outside the image borders of warped image.
BW = ~isnan(Dx);
BW = imdilate(BW, ones(3,3));
BW = imerode(BW, ones(3,3));

% Fill in missing values
Dx = fillmissing(Dx, 'linear', dim);
Dy = fillmissing(Dy, 'linear', dim);

% Put Dx and Dy into displacement matrix:
D = cat(3, Dx, Dy); % Displacement field...
D(isnan(D)) = 0;

BW = repmat(BW, 1,1,2);
D(~BW) = 2000;

if nargout == 1
   clear BW
end
end
