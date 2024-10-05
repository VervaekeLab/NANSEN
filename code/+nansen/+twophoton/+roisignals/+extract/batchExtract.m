function signalArray = batchExtract(imArray, roiData, varargin)
%batchExtract Extract signals of RoIs from an image array in one operation
%
%   signalArray = batchExtract(imArray, roiData) uses matrix multiplication
%   to compute the signals of rois within an image array.
%
%   signalArray = batchExtract(imArray, roiData, options) performs the
%   extraction using specified optional parameters. See
%   nansen.twophoton.roisignals.extract.getDefaultParameters for default
%   parameters and potential options. options can either be a struct
%   containing a subset of parameters as fields, or a cell array of name
%   value pairs. If parameters are missing in input, the default values are
%   used.
%
%   INPUTS:
%     imArray : 3D (imHeight, imWidth, numFrames) matlab array.
%     roiData : array of RoI objects or a cell array of masks, where
%         each cell contains a sparse matrix of masks (numRois x
%         numPixelsPerImage) for a subregion of each roi. The first cell
%         contains masks of the main roi and potential successive cells
%         correspond to masks of related subregions like one or more
%         neighboring neuropil rois. See prepareRoiMasks for more details
%
%   OUTPUT:
%     signalArray : 3D array (nSamples x nSubregions x nRois) of the mean
%         pixel intensities within each subregion of each roi. If there
%         is only one subregion (i.e only the main roi) the 2nd dim is a
%         singleton dimension
%
%   NOTE1:
%       This function will cast the image array to double. If the image
%       array is of type uint8, the required memory will increase 8-fold
%       (or 4-fold for uint16). Therefore, if the input array is very
%       large, consider splitting it into batches before processing.
%
%       Anecdotally, on a mac with 16 GB memory, a good batch size is
%       something like 1000 frames for an image array with pixel resolution
%       of 512 x 512. (Requires ~2GB of system memory).
%
%   NOTE2:
%       Efficient for computing signals for 100s of rois. If computing
%       signals for fewer rois (<100) see serialExtract
%
%   See also nansen.twophoton.roisignals.extract.getDefaultParameters
%            nansen.processing.roi.prepareRoiMasks
%            nansen.processing.signal.serialExtract
%

%   Eivind Hennestad | Vervaeke Lab | August 2021

%   TODO:
%       [ ] Is it fine with current roi format (i.e struct with Masks field
%       or should it just be a simple cell array???
%       [ ] Add support for weighted masks.
%       [ ] Add support for getting median or percentile values instead of
%           weighted mean? See serialExtract...
    
    assert( ndims(imArray) == 2 || ndims(imArray) == 3, 'Image array must be 3D')
    
    % If roidata is an array of RoIs, it must be prepared for extraction.
    if isa(roiData, 'RoI')
        [P, V] = nansen.twophoton.roisignals.extract.getDefaultParameters();
        params = utility.parsenvpairs(P, V, varargin{:});
        params.RoiOutputFormat = 'sparse';
        roiData = nansen.processing.roi.prepareRoiMasks(roiData, params);
    end
    
    % Reshape image array to a 2D matrix of nPixelsPerImage x nSamples
    numSamples = size(imArray, 3);
    imArray = double(reshape(imArray, [], numSamples));
    
    % Concatenate masks to create a matrix of nSubregions x nPixelsPerImage
    roiMaskMatrix = cat(1, roiData.Masks{:});
    
    % Multiply matrices to get a nSubregions x nSamples matrix of signals
    signals = roiMaskMatrix * imArray;
    
    signals = signals'; % --> nSamples x nSubregions
    
    % Reshape to get signals as an array of nSamples x nRois x nSubregions
    numRois = size(roiData.Masks{1}, 1);
    numSubRegions = numel(roiData.Masks);
    signalArray = reshape(signals, numSamples, numRois, numSubRegions);
    
    % Rearrange 2nd and 3rd dim to get nSamples x nSubregions x nRois.
    signalArray = permute(signalArray, [1, 3, 2]);
    
end
