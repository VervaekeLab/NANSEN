function [P, V] = getDefaultOptions()

% DESCRIPTION:
%   Change these parameters to change the behavior of the autosegmentation

% - - - - - - - - Specify parameters and default values - - - - - - - -

% Names                                 Values (default)        Description
P                                       = struct();             %
P.CellDetection.cellDiameter            = 12;                   % Diameter of cell
P.CellDetection.smoothingSigma          = 0.5;                  % spatial smoothing length in pixels; encourages localized clusters
P.CellDetection.numSvdComponents        = 1000;                 % how many SVD components for cell clustering
P.CellDetection.svdFrameBinningSize     = 5000;                 % how many (binned) timepoints to do the SVD based on
P.CellDetection.signalExtractionType    = 'surround';           % how to extract ROI and neuropil signals: 'raw' (no cell overlaps), 'regression' (allows cell overlaps), 'surround' (no cell overlaps, surround neuropil model)
P.CellDetection.refineDetectedRois      = true;                 % whether or not to refine ROIs (refinement uses unsmoothed PCs to compute masks)

P.Neuropil.neuropilPadding              = 1;                    % padding (pixels) around cell to exclude from neuropil
P.Neuropil.radius                       = inf;                  % radius of neuropil surround. If infinity, then neuropil surround radius is a function of cell size
P.Neuropil.minNeuropilPixels            = 400;                  % minimum number of pixels in neuropil surround (Only used if neuropil radius is inf)
P.Neuropil.neuropilCellRatio            = 5;                    % Ratio btw neuropil radius and cell radius. Radius of surround neuropil = neuropilCellRatio * (radius of cell)

P.Deconvolution.imagingRate             = 30;                   % imaging rate (cumulative over planes!). Approximate, for initialization of deconvolution kernel.
P.Deconvolution.sensorTimeConstant      = 2;                    % decay half-life (or timescale). Approximate, for initialization of deconvolution kernel.
P.Deconvolution.maxNeuropil             = 1;                    % for the neuropil contamination to be less th

% - - - - - - - - - - Specify customization flags - - - - - - - - - - -

P.CellDetection.signalExtractionType_    = {'surround', 'raw', 'regression'};
    
% - - - - Specify validation/assertion test for each parameter - - - -

V                           = struct();

% - - - - - Adapt output to how many outputs are requested - - - - - -

if nargout == 0
    displayParameterTable(mfilename('fullpath'))
    clear P V
elseif nargout == 1
    clear V
end
end
