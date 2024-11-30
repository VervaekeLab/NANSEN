function dtheta = findRotationOffsetsFFT(IM, rotating, refIm)
%rotationCorrectionFFT Find angular offset of stack using FFT
%
%   dtheta = findRotationOffsetsFFT(IM, rotating, refIm)
%
% Unfold image by cutting the image from the center to the right side along
% a horizontal line (the positive x-axis) and then open it up around
% itself, effectively making a disk of the image into a rectangle.
% since each line in the new image is a concentric circle in the original,
% the xoffset of the new image can be transformed to an angular offset in
% the original.
% Note1: the disk is chosen to have the radius of the shortest image
% dimension.
% Note2: Upsampling can be done to get avoid jagged images after the
% unrolling step, but this seems to have a minor effect on the alignment.
%
% NB: Very important that images are cropped to remove black edges before
% passed to this function (e.g. if it has been aligned rigidly beforehand).
% Any moving edges will give supoptimal (sometimes bogus) results.
%
% Written by Eivind Hennestad, 2018 | Vervake Lab

import nansen.wrapper.normcorre.utility.rigid

assert(ndims(IM) == 3, 'First input must be a 3D array.')

% Get size of input image array
[imHeight, imWidth, nFrames] = size(IM);
usFactor = 2;

% Set rotating to true for all frames by default.
if nargin < 2 || isempty(rotating)
    rotating = true(nFrames, 1);
else
    if ~isrow(rotating); rotating = rotating'; end
    rotating = imdilate(rotating, ones(1,9));
end

if nargin < 3; refIm = []; end

rotating = logical(rotating);
dtheta = zeros(size(rotating));

if ~any(rotating); return; end

IM = IM(:, :, rotating);

% Add refIm on the end on the imarray so that it is unfolded with the rest
% of the images.
if ~isempty(refIm)
    IM = cat(3, IM, refIm);
end

% Upsample to minimize offsets in the concentric lines due to diameter
% differences.
IM = imresize(IM, usFactor);
[imHeight, imWidth, nFrames] = size(IM);

% Calculate center of image
imCenter = [(imHeight+1)/2, (imWidth+1)/2];

% Create cartesian coordinate system centered on the image center
[xx, yy] = meshgrid( (1:imWidth)-imCenter(2), (1:imHeight)-imCenter(1) );
yy = flipud(yy); % Reverse y-axis from array indices to coordinates.

% Get corresponding polar coordinates for each pixel of the image.
[theta, rho] = cart2pol(xx, yy);

% Find the radius of the shortest dimension
rad = round(min([max(xx(:)), max(yy(:))]));

% Convert theta from radians (+/- pi) to degrees from 0 to 360
theta = rad2deg(theta);
theta(theta<0) = 180 + (180 - abs(theta(theta<0)));

% Round off the radius to integers
rho = round(rho);

% Preallocate array for the indices conversion when "unfolding" the image
IND = cell(rad, 1);

% Unroll
% Starting from the center, and going counterclockwise, assign each pixel
% to a new index. The index should be the position in an "unrolled" image
for r = 1:rad
    rhoIND = find(rho==r);
    [~, order] = sort(theta(rhoIND));
    rhoIND = rhoIND(order);
    IND{r} = rhoIND;
end

% Calculate the number of pixels
pixPerImage = imHeight*imWidth;

% Allocate the array for the unfolded image % TODO: Use imunroll.
unfoldedIm = zeros([rad, imWidth, nFrames], 'like', IM);

% Divide the image into concentric circles where each circle
% is one row in the new image. Each column is one angle.
% Pixels on the top row will be very stretched out, and pixels on the
% bottom will be squeezed.

for j = 1:rad
    % Repeat the indices for the current radius across all images
    tmpInd = repmat( IND{j}', nFrames, 1 ) + (0:(nFrames-1))'*pixPerImage;
    
    tmpInd = tmpInd';
    imLin = IM(tmpInd(:));
    imLin = reshape(imLin, [], nFrames);
    imLin = imresize(imLin, [imWidth, nFrames]);
    unfoldedIm(j, :, :) = imLin;

end

% Downsample to original image size before running the fft.
unfoldedIm = imresize(unfoldedIm, 1/usFactor);
imWidth = imWidth ./ usFactor;

% Remove the inner part of the disk/the upper part of the unfolded image
unfoldedImSize = size(unfoldedIm);
unfoldedIm = unfoldedIm(round(unfoldedImSize(1)/2):end, :,:);

if ~isempty(refIm)
    unfoldedRef = unfoldedIm(:,:,end);
    unfoldedIm = unfoldedIm(:,:,1:end-1);
else
    unfoldedRef = [];
end

% Run rigid alignment on depolar images and calculate angular offset from
% xshift.
[~, ~, ncShifts] = rigid(unfoldedIm, unfoldedRef);

xshifts = arrayfun(@(row) row.shifts(:,:,:,2), ncShifts, 'uni', 1);
% yshifts = shifts(:, 2); % Radial shifts, corresponding to x and y...
% If these are big, could run a second step of rigid aligning.

dtheta(rotating) = xshifts ./ imWidth * 360;

end
