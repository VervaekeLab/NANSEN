function [rhoIm, pIm] = getPixelCorrelationImage(signal, imChunk)

imSize = size(imChunk);

% Make the imchunk into a matrix of nPixels x nSamples
pixelSignals = reshape(imChunk, prod(imSize(1:2)), imSize(3));

% Make sure both data arrays are single
pixelSignals = single(pixelSignals);
signal = single(signal);

% Preallocate arrays for images.
[rhoIm, pIm] = deal( zeros(imSize(1), imSize(2)) );

[RHO, P] = corr(signal, pixelSignals', 'tail', 'right', 'rows', 'all');
rhoIm(:) = RHO(:);
pIm(:) = P(:);

% To prevent negative values. Maybe this should be reconsidered...
rhoIm(rhoIm<0)=0.001;

% Remove nans
rhoIm(isnan(rhoIm)) = 0;

end

