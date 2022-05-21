function [P, V] = getDefaultOptions(mode)
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

    % Names                             Values (default)      Description
    P                                   = struct();
    
    P.General.RoiDiameter               = 12;                 % Expected diameter of rois in pixels
%     P.NucleusDiameter                 = 6;                  % Todo
    P.General.RoiType                   = 'Soma';             % Morphological structure to detect. Alternatives: 'Soma' (default), 'Axonal Bouton'.
        
    % Binarization
    P.Detection.PrctileForBinarization  = 93;                 % Percentile of pixel values to use for thresholding grayscale images to BW
    P.Detection.NumObservationsRequired = 2;                  % Number of times a component should be observed in order to detect.
    P.Detection.MaxNumRois              = 300;                % Maximum number of rois to detect

    % Image stack preprocessing
    P.Preprocessing.BinningMethod       = 'maximum';          % Method for fram binning. Alternatives: 'maximum' (default) or 'average' (not implemented)
    P.Preprocessing.BinningSize         = 5;
    P.Preprocessing.SpatialFilterType   = 'gaussian';         % todo...
    P.Preprocessing.SmoothingSigma      = 20;                 % "Size" (standard deviation/sigma) of the gaussian kernel for creating background image
    P.Preprocessing.PrctileForBaseline  = 25;                 % For background when computing Dff stack..
    
    % Morphological shape detection
    P.Detection.UseShapeDetection       = true;
    P.Detection.MorphologicalShape      = 'ring';             % Type of shape to use for morphological search. Alternatives: 'ring' (default), 'disk'.
    P.Detection.InnerRadius             = 3;                  % Inner diameter of ring
    P.Detection.OuterRadius             = 5;                  % Outer diameter of ring/disk

    % Curation of results
    P.Curation.MinimumDiameter          = 4;                  % Minimum allowed roi diameter in pixels
    P.Curation.MaximumDiameter          = 16;                 % Maximum allowed roi diameter in pixels
    P.Curation.PercentOverlapForMerge   = 75;                 % todo.
    
% %     P.Preview.Show = 'Preprocessed';
% %     P.Preview.Show_ = {'Preprocessed', 'Binarized', 'Static Background'};

    % - - - - - - - - - - Specify customization flags - - - - - - - - - - -
    P.General.RoiType_                  = {'Soma', 'Axonal Bouton'};
    P.General.RoiDiameter_              = struct('type', 'slider', 'args', {{'Min', 1, 'Max', 20, 'nTicks', 19, 'TooltipPrecision', 0, 'TooltipUnits', 'pixels'}});
    P.Detection.MorphologicalShape_     = {'ring', 'disk'};
    P.Preprocessing.BinningMethod_      = {'maximum', 'average'};
    P.Preprocessing.SpatialFilterType_  = {'gaussian'};
    P.Preprocessing.PrctileForBaseline_ = struct('type', 'slider', 'args', {{'Min', 1, 'Max', 100, 'nTicks', 99, 'TooltipPrecision', 0}});
    P.Detection.PrctileForBinarization_ = struct('type', 'slider', 'args', {{'Min', 1, 'Max', 100, 'nTicks', 99, 'TooltipPrecision', 0}});
    
    
    % - - - - Specify validation/assertion test for each parameter - - - -
    
    V                           = struct();
    V.Detection.MaxNumRois      = @(x) assert( isnumeric(x) && isscalar(x) && x >= 0,  ...
                                    'Value must be a scalar, non-negative, integer number' );
    
    if nargin == 1 && strcmp(mode, 'ungrouped')
        P = nansen.wrapper.abstract.OptionsAdapter.ungroupOptions(P);
        V = nansen.wrapper.abstract.OptionsAdapter.ungroupOptions(V);
    end
                                
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



