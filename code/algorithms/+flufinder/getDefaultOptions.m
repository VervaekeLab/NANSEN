function [P, V] = getDefaultOptions()
%getDefaultOptions Get parameters for flufinder autosegmentation
%
%   P = flufinder.getDefaultOptions() returns a struct (P) with default 
%       parameters for running flufinder's autosegmentation algorithm.
%
%   [P, V] = flufinder.getDefaultOptions() returns an additional struct (V) 
%       containing assertions for each parameter, for use with an input 
%       parser etc.
%
%   SELECTED PARAMETERS:
%   --------------------
%   RoiDiameter : [numeric scalar] Expected diameter of rois in FoV
%   modelParams : depends on modelType
%
%
%   Note: for full list of parameters, run function without output, i.e
%       flufinder.getDefaultOptions() ()


% DESRIPTION:
%   Change these parameters to change the behavior of the autosegmentation.

    % - - - - - - - - Specify parameters and default values - - - - - - - - 

    % Names                         Values (default)      Description
    P                               = struct();
    
    P.RoiDiameter                   = 12;                 % Expected diameter of rois in pixels
    P.MinimumDiameter               = 4;                  % Minimum allowed roi diameter in pixels
    P.MaximumDiameter               = 16;                 % Maximum allowed roi diameter in pixels
    
    P.MaxNumRois                    = 300;                % Maximum number of rois to detect

    P.MorphologicalStructure        = 'Soma';             % Morphological structure to detect. Alternatives: 'Soma' (default), 'Axonal Bouton'.
    
    P.MorphologicalSearch           = true;               % Boolean flag. Do a morphological search, i.e use a convolutional filter to detect specific shapes
    P.MorphologicalShape            = 'ring';             % Type of shape to use for morphological search. Alternatives: 'ring' (default), 'disk'.
    P.MorphologicalSearchFrequency  = 1;                  % I.e Do this for an average of each chunk, or only once, or something in between??
    
    % Background subtraction
    P.TemporalDownsamplingFactor    = 10;                 % Temporal downsampling for pixel background subtraction
    P.TemporalDownsamplingMethod    = 'maximum';          % Method for downsampling. Alternatives: 'maximum' (default) or 'average'
    P.SpatialFilterType             = 'gaussian';         % todo...
    P.SpatialFilterSize             = 20;                 % "Size" (standard deviation/sigma) of the gaussian kernel for creating background image % todo: sigma = (size - 1) / 4 
    P.PrctileForBaseline            = 25;                 % For background when computing Dff stack..
    
    % Binarization
    P.PrctileForThresholding        = 93;                 % Percentile of pixel values to use for thresholding grayscale images to BW
    
    
    params = struct(); 
    params.RoiType = 'soma';
    params.RoiDiameter = 12;
    params.BackgroundBinningSize = 5;
    params.BackgroundSmoothingSigma = 20;
    params.BwThresholdPercentile = 92;
    
    params.UseShapeDetection = true;
    params.MorphologicalShape = 'ring';
    
    
    params.PercentOverlapForMerge = 75; % todo.
    
    

    % - - - - - - - - - - Specify customization flags - - - - - - - - - - -
    P.MorphologicalStructure_       = {'Soma', 'Axonal Bouton'};
    P.MorphologicalShape_           = {'ring', 'disk'};
    P.TemporalDownsamplingMethod_   = {'maximum', 'average'};
    P.SpatialFilterType_            = {'gaussian'};
    
    % - - - - Specify validation/assertion test for each parameter - - - -
    
    V                           = struct();
    V.SpatialFilterSize         = @(x) assert( isnumeric(x) && isscalar(x) && x >= 0 && round(x)==x && mod(x,2)==1,  ...
                                    'Value must be a scalar, non-negative, odd integer number' );
    
    if nargout == 0
        displayParameterTable(mfilename('fullpath'))
        
%         S = utility.convertParamsToStructArray(mfilename('fullpath'));
%         T = struct2table(S);
%         fprintf('\nSignal extraction default parameters and descriptions:\n\n')
%         disp(T)
        
        clear P V
    elseif nargout == 1
        clear V
    end
    
end



