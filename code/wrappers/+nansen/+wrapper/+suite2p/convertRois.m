function [roiArray, classification, stats, images] = convertRois(S)
%convertRois Convert suite2p rois to roi data.
%
%   roiArray = nansen.wrapper.suite2p.convertRois(S) converts rois in
%   struct S to a roiArray. S must be a struct containing two fields:
%       stat : stat output from suite2p
%       ops : ops output from suite2p
%       iscell : cell classification (optional)

% Todo: Make class (and roiconverter superclass)

    % Create roi image
    imageSize = [S.ops.Ly, S.ops.Lx];
    roiArray = nansen.wrapper.suite2p.getRoiArray(S.stat, imageSize);
    
    if isa(S.stat, 'cell'); S.stat = cat(1, S.stat{:}); end
    assert(isa(S.stat, 'struct'), 'Expected suite2p "stat" to be a struct array')
    
    % Initialize classification using manual classification label.
    % Todo: implement enum?
    classification = S.iscell(:,1);
    classification(classification == 0) = 2;
    
    % Add classification to stats
    numRois = numel(roiArray);
    stats = struct;
    iscell = num2cell(S.iscell);
    [stats(1:numRois).s2pClassificationLabel] = iscell{:, 1};
    [stats(1:numRois).s2pClassificationConfidence] = iscell{:, 2};
    
    [stats(1:numRois).s2pCompactness] = deal( S.stat.compact );
    [stats(1:numRois).s2pSignalSkew] = deal( S.stat.skew );
    
    % Todo: Make a RoI method for getting these images and more?
    images = struct.empty; % Todo: Create weight image...
    [images(1:numRois).SpatialWeights] = deal([]);
    
    imageSize = cast(imageSize, 'like', S.stat(1).ypix);

    mask = zeros([imageSize, numRois], 'single');
    for i = 1:numel(S.stat)
        tmpMask = mask(:, :, i);
        ind = sub2ind(imageSize, S.stat(i).ypix, S.stat(i).xpix);
        tmpMask(ind) = S.stat(i).lam;
        mask(:, :, i) = tmpMask;
    end
    
    imArray = nansen.wrapper.extract.util.convertSpatialWeightsToThumbnails(roiArray, mask);
    imArray = stack.makeuint8(imArray);
    for i = 1:numRois
        images(i).SpatialWeights = imArray(:, :, i);
    end
end

% Skew: skewedness of neuropil subtracted roi fluoresence (dF) distribution.
% Std: standard deviation of dF

% Skew:
% Computes the skewedness of the distribution of values.
% Normal distributions, around 0, positive values indicate right tail.
% That should be expected for sparsely active cells?
% https://docs.scipy.org/doc/scipy-1.8.0/html-scipyorg/reference/generated/scipy.stats.skew.html

% % From s2p docs:
% % NAME           | DESCRIPTION
% % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
% % ypix:          | y-pixels of cell
% % xpix:          | x-pixels of cell
% % med:           | (y,x) center of cell
% % lam:           | pixel mask (sum(lam * frames[ypix,xpix,:]) = fluorescence)
% % npix:          | number of pixels in ROI
% % npix_norm:     | number of pixels in ROI normalized by the mean of npix across all ROIs
% % radius:        | estimated radius of cell from 2D Gaussian fit to mask
% % aspect_ratio:  | ratio between major and minor axes of a 2D Gaussian fit to mask
% % compact:       | how compact the ROI is (1 is a disk, >1 means less compact)
% % footprint:     | spatial extent of an ROI’s functional signal, including pixels not assigned to the ROI; a threshold of 1/5 of the max is used as a threshold, and the average distance of these pixels from the center is defined as the footprint
% % skew:          | skewness of neuropil-corrected fluorescence trace
% % std:           | standard deviation of neuropil-corrected fluorescence trace
% % overlap:       |  which pixels overlap with other ROIs (these are excluded from fluorescence computation)
% % ipix_neuropil: | pixels of neuropil mask for this cell
% % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
