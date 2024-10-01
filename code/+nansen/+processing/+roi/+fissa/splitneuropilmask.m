function splitMask = splitneuropilmask(npMask, roiMask, nSlices)
% Splits a mask into a number of approximately equal slices by area around
%     the center of the mask.
% 
%     Inputs
%     ----------
%     npMask : array (logical)
%         Neuropil mask as a 2d logical array.
%     roiMask : tuple
%         Roi mask as a 2d logical array.
%     nSlices : double (integer)
%         The number of slices into which the neuropil mask will be divided.
%     adaptive_num : bool, optional
%         If True, the `num_slices` input is treated as the number of
%         slices to use if the ROI is surrounded by valid pixels, and
%         automatically reduces the number of slices if it is on the
%         boundary of the sampled region. NOT IMPLEMENTED.
% 
%     Returns
%     -------
%     splitMask
%         Neuropil mask as a 3d logical array where the third dimension is
%         the number of slices.


if nSlices == 1; splitMask=npMask; return; end

% Make some constraints on the inputs
assert(islogical(npMask(1)) & numel(size(npMask))==2, ...
                        'Neuropil mask should be a logical matrix')
assert(islogical(roiMask(1)) & numel(size(roiMask))==2, ...
                        'Roi mask should be a logical matrix')
                    
% get the center of mass for the cell
[y, x] = find(roiMask);
centre = [mean(y), mean(x)];

% Get the (x,y) co-ordinates of the pixels in the mask
[y, x] = find(npMask);

% Find the angle of the vector from the mask centre to each pixel
theta = atan2(y - centre(1), x - centre(2));

% Find where the mask comes closest to the centre. We will put a
% slice boundary here, to prevent one slice being non-contiguous
% for masks near the image boundary.

nBins = 20;
edges = linspace(-pi, pi, nBins + 1);
% [bin_counts, bins] = np.histogram(theta, bins=bins)
[binCounts, edges] = histcounts(theta, edges); % Does this do the same in matlab?

[~, binMinIndex] = min(binCounts);

% Change theta so it is the angle relative to a new zero-point,
% the middle of the bin which is least populated by mask pixels.
thetaOffset = edges(binMinIndex) + pi / nBins;
theta = (theta - thetaOffset);

% get the boundaries
thetaBounds = arrayfun(@(i) prctile(theta, 100 * i / nSlices), 1:nSlices);

% predefine the mask
splitMask = zeros(size(npMask));

% Find the indices for pixels in the mask
ind = find(npMask);

for i = 1:nSlices
    % find which pixels are within bounds
    if i == 1
        isSlice = theta <= thetaBounds(i);
    else
        isSlice = theta > thetaBounds(i - 1) & (theta <= thetaBounds(i));
    end
    % assign slice number to pixels within bounds
    splitMask(ind(isSlice)) = i;
end

% Make a logical 3d array for the output
splitMask = arrayfun(@(i) splitMask == i, 1:nSlices, 'uni', 0);
splitMask = logical(cat(3, splitMask{:}));

end