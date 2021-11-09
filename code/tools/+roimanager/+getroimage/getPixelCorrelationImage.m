function [rhoIm, pIm] = getPixelCorrelationImage(signal, imChunk)

imSize = size(imChunk);

% Make the imchunk into a matrix of nPixels x nSamples
pixelSignals = reshape(imChunk, prod(imSize(1:2)), imSize(3));

% Make sure both data arrays are single
pixelSignals = single(pixelSignals);
signal = single(signal);

% Preallocate arrays for images.
[rhoIm, pIm] = deal( zeros(imSize(1), imSize(2)) );


% % % % % % Find the correlation and pValue between all pixels. This is slower,
% % % % % but will yield pairwise correlation coefficients between all pixels as well.
% % % [RHO, P] = corr([signal, pixelSignals'], 'tail', 'right', 'rows', 'all');
% % % rhoIm(:) = RHO(2:end, 1);
% % % pIm(:) = P(2:end, 1);
% % % 
% % % 
% % % % To prevent negative values. Maybe this should be reconsidered...
% % % rhoIm(rhoIm<0)=0.001;
% % % 
% % % % Create color coded image based on clusters of correlating pixels
% % % corrMat = RHO(2:end, 2:end);
% % % Z = linkage(corrMat,'complete','correlation');
% % % % dendrogram(Z);
% % % 
% % % rhoIm = rhoIm - min(rhoIm(:)) ./ max(rhoIm(:)-min(rhoIm(:)));
% % % 
% % % T = cluster(Z, 'Cutoff', 1.3, 'Criterion', 'distance');
% % % nClusters = max(T);
% % % 
% % % rhoImN = repmat(rhoIm, 1, 1, nClusters);
% % % rhoImRGB = repmat(rhoImN, 1,1,1,3);
% % % 
% % % colors = hsv(nClusters);
% % % 
% % % for i = 1:nClusters
% % %     for j = 1:3
% % %         tmpIm = rhoImN(:, :, i);
% % %         tmpIm(T==i) = tmpIm(T==i) .* colors(i,j);
% % %         rhoImRGB(:,:,i,j) = tmpIm;
% % %     end
% % % end
% % % rhoImRGB = squeeze(mean(rhoImRGB, 3));
% % % imviewer(imresize( uint8(rhoImRGB*255), 4));


[RHO, P] = corr(signal, pixelSignals', 'tail', 'right', 'rows', 'all');
rhoIm(:) = RHO(:);
pIm(:) = P(:);

% To prevent negative values. Maybe this should be reconsidered...
rhoIm(rhoIm<0)=0.001;

end

