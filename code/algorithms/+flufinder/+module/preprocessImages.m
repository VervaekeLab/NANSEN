function imArray = preprocessImages(imArray, varargin)
%preprocessImages Combine all preprocessing steps in one function 
%
%   imArray = preprocessImages(imArray, name, value, ...)
%
%   Parameters:
%       
%       SmoothingSigma      : Sigma (std) for gaussian filter to use for
%                             making a smoothed stack for bg subtraction.
%   
%       PrctileForBaseline  : Percentile values to use for creating a
%                             static image for for bg subtraction.

    params = struct();
    params.BinningMethod = 'maximum';          % Method for frame binning. Alternatives: 'maximum' (default) or 'average' (not implemented)
    params.BinningSize = 5;
    params.SpatialFilterType = 'gaussian'; % Not implemented
    params.SmoothingSigma = 20; % Todo: Depend on roisize?
    params.PrctileForBaseline = 25;
    
    params = utility.parsenvpairs(params, [], varargin{:});
    
    imArray = single(imArray);

    % Create a temporally downsampled stack (binned by maximum)
    switch params.BinningMethod
        case 'average'
            imArray = stack.process.framebin.mean(imArray, params.BinningSize);
        case 'maximum'
            imArray = stack.process.framebin.max(imArray, params.BinningSize);
    end
    
    % Preprocess (subtract dynamic background)
    optsNames = {'SpatialFilterType', 'SmoothingSigma'};
    opts = utility.struct.substruct(params, optsNames);
    imArray = flufinder.preprocess.removeBackground(imArray, opts);
    
    % Preprocess (subtract static background)
    optsNames = {'PrctileForBaseline'};
    opts = utility.struct.substruct(params, optsNames);
    %imArray = flufinder.preprocess.removeStaticBackground(imArray, opts);
    % Todo: Bin size should be part of options...
    imArray = flufinder.preprocess.removeDynamicBackground(imArray);

end