% Test fastest way to get signals from pixel chunk
x = 200; y = 200; r = 6;
pad = 5;


% Get image data from imviewer app.
imArray = obj.displayApp.imArray;
imSize = [obj.displayApp.imHeight,  obj.displayApp.imWidth];


[S, L] = roimanager.imtools.getImageSubsetBounds(imSize, x, y, r, pad);
imChunk = roimanager.imtools.getPixelChunk(imArray, S, L);

% Get x- and y-coordinate for the image subset.
x_ = x - S(1)+1; 
y_ = y - S(2)+1;

% Todo: Get frames.
mask = roimanager.roitools.getCircularMask(size(imChunk), x_, y_, r);


tic; for i = 1:10000
nPixels = sum(sum(mask));
nFrames = size(imChunk,3);
tmpMask = repmat( mask, 1, 1, nFrames );
signal = mean(reshape(imChunk(tmpMask), nPixels, nFrames), 1);
end; toc


tic; for i = 1:10000
% compute roi fluorescense
mask2 = reshape(mask, 1, []);
mask2 = mask2 ./ sum(mask2, 2);
%mask2 = sparse(mask2);

imChunk2 = double(reshape(imChunk, [], nFrames));
signal2 = mask2 * imChunk2;
end; toc

