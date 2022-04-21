function signalArray = serialExtract(imArray, roiMasks, varargin)
%serialExtract Extract signals of RoIs from an image array one by one
%
%   signalArray = serialExtract(imArray, roiData)
%
%   signalArray = serialExtract(imArray, roiData, options) performs the
%   extraction using specified optional parameters. options can be a struct
%   of parameters, or a list of name-value pairs. See
%   nansen.twophoton.roisignals.extract.getDefaultParameters for a list of 
%   available parameters
%   
%   INPUTS:
%       imArray  : 3D (imHeight, imWidth, numFrames) matlab array.
%       roiMasks : array of RoI objects or a struct array of masks and
%           other information for each roi.
%
%   NOTE: 
%       Efficient for computing signals of fewer (~100) rois. If computing
%       signals for more rois (>100) see batchExtract
%
%   See also nansen.twophoton.roisignals.extract.getDefaultParameters

% TODO:
% [ ] Simplify roi mask format.

    assert( ndims(imArray) == 3, 'Image array must be 3D')

    [P, V] = nansen.twophoton.roisignals.extract.getDefaultParameters();
    if ~isempty(varargin)
        params = utility.parsenvpairs(P, V, varargin{:});
    else
        params = P;
    end
    
    % If roiMasks is an array of RoIs, it must be prepared for extraction.
    if isa(roiMasks, 'RoI')

        params.RoiOutputFormat = 'struct';
        roiMasks = nansen.processing.roi.prepareRoiMasks(roiMasks, params);
    end
    
    numSamples = size(imArray, 3);
    numSubregions = size(roiMasks(1).Masks, 3);
    numRois = numel(roiMasks);
    
    signalArray = zeros(numSamples, numSubregions, numRois);
    
    % Loop through rois
    for jRoi = 1:numRois
        
        signalArray(:, :, jRoi) = ...
            nansen.twophoton.roisignals.extract.extractSingleRoi(...
            imArray, roiMasks(jRoi), params.pixelComputationMethod);

    end

end
