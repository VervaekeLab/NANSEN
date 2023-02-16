function imArrayOut = imcropcenter(imArrayIn, newSize)
%imcropcenter Return a center cropped version of image/stack
%
% imArrayOut = imcropcenter(imArrayIn, newSize) crops the center part of the
% imArray. The size of the new image/stack is set by newSize;

origSize = size(imArrayIn);

% Calculate center of original images.
centerOrig = round( (origSize(1:2)+1) ./ 2);

% Calculate center of new images.
centerNew = round( (newSize(1:2)+1) ./ 2);

% Determine center symmetric crop indices...
xInd = (1:newSize(2)) - centerNew(2) + centerOrig(2);
yInd = (1:newSize(1)) - centerNew(1) + centerOrig(1);

% Crop original array
ind = repmat({':'}, 1, ndims(imArrayIn));
ind(1:2) = {yInd, xInd};

imArrayOut = imArrayIn(ind{:});

end