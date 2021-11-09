function signalArray = extractSingleRoi(imArray, roiData, method)
%extractSingleRoi Extract fluorescence signal of one roi.
%
%   signalArray = extractSingleRoi(imArray, roiMask, npMask) extracts
%   the fluorescence signal of a roi in an imageArray based on the roiMask.
%   If a neuropil mask (npMask) is supplied, the signal in the neuropil
%   region will also be extracted. The signal is the mean spatial pixel 
%   intensity within the roi for each frame.
%
%   INPUTS:
%       imArray: double (nPixY, nPixX, nFrames) array of images
%       roiData: struct array (1 x nRois) containing three fields: Masks,
%           xInd & yInd. Masks is a boolean array (nPixY x nPixX x
%           numSubregions) for each roi, and xInd and yInd are the x and y
%           indices respectively for indexing the image array to get a
%           subpart tightly cropped around the roi.
%       method: 'mean' or 'median'. Default: 'mean'. Median (and 
%           percentiles) are not implemented yet.
%
%   OUTPUT:
%       signalArray : double (nFrames, 1+nSubregions). Note: The signal of 
%       the roi will be in the first column, and the the signal of neuropil
%       regions will be placed in the subsequent columns.
%
%   IMPLEMENTATION: 
%       Index the image array to get a 3D chunk of pixels tightly cropped
%       to include only the roi (and corresponding neuropil regions),
%       before extracting signals. 
%       This method produce quicker results when extracting the signals 
%       from a few number of rois.

%   TODO:
%     [ ] Implement method for getting median values instead of mean
%           i.e use implement the getPercentileSignal


    % Determine if surrounding neuropil fluorescence will be extracted
    if nargin < 3; method = 'mean'; end % Default is mean

    numSamples = size(imArray, 3);
    numSubregions = size(roiData.Masks, 3);

    % Crop image array and roi masks
    imArrayCropped = imArray(roiData.yInd, roiData.xInd, :);
    roiMaskCropped = roiData.Masks(roiData.yInd, roiData.xInd, :);

    % Create a weighted 2D sparse version of the roi mask.
    roiMaskCropped_ = reshape(roiMaskCropped, [], numSubregions)';
    roiMaskCropped_ = roiMaskCropped_ ./ sum(roiMaskCropped_, 2);
    roiMaskCropped_ = sparse(roiMaskCropped_);
    
    imArrayCropped = double(reshape(imArrayCropped, [], numSamples));
    tmpSignal = roiMaskCropped_ * imArrayCropped;

    % Return signal array as numSamples x numSubregions
    signalArray = tmpSignal';

end


function signalArray = getPercentileSignal(imArrayChunk, roiMaskChunk, p)

    if nargin < 2 || isempty(p)
        p = 50;
    end
        
    nSamples = size(imArrayChunk, 3);
    nSubregions = size(roiMaskChunk, 3);
    
    if numel(p) == 1 && nSubregions > 1
        p = repmat(p, nSubregions, 1);
    end
    
    % Preallocate signalArray
    signalArray = zeros(nSamples, nSubregions );

    % Extract roisignals
    for i = 1:nSubregions
        nPixels = sum(sum(roiMaskChunk(:,:,i)));
        tmpMask = repmat(roiMaskChunk(:,:,i), 1, 1, nSamples);
        
        % Todo: Is it signficantly faster to put this directly in the 
        % median/perctile function?
        roiPixelValues = reshape(imArrayChunk(tmpMask), nPixels, nSamples);
        
        if p(i) == 50
            signalArray(:, i) = median(roiPixelValues, 1);
        else
            signalArray(:, i) = prctile(roiPixelValues, p(i), 1);
        end
        
    end
    
end

