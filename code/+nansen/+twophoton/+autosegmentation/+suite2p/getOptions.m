function ops = getOptions()

ops = struct;

% ---- cell detection options ------------------------------------------%
ops.ShowCellMap            = 1;         % during optimization, show a figure of the clusters
ops.sig                    = 0.5;       % spatial smoothing length in pixels; encourages localized clusters
ops.nSVDforROI             = 1000;      % how many SVD components for cell clustering
ops.nSVD                   = 1000;      % how many SVD components for cell clustering
ops.NavgFramesSVD          = 5000;      % how many (binned) timepoints to do the SVD based on
ops.signalExtraction       = 'surround';% how to extract ROI and neuropil signals: 
%  'raw' (no cell overlaps), 'regression' (allows cell overlaps), 
%  'surround' (no cell overlaps, surround neuropil model)
ops.refine                 = 1; % whether or not to refine ROIs (refinement uses unsmoothed PCs to compute masks)

% ----- neuropil options (if 'surround' option) ------------------- %
% all are in measurements of pixels
ops.innerNeuropil  = 1; % padding around cell to exclude from neuropil
ops.outerNeuropil  = Inf; % radius of neuropil surround
% if infinity, then neuropil surround radius is a function of cell size
if isinf(ops.outerNeuropil)
    ops.minNeuropilPixels = 400; % minimum number of pixels in neuropil surround
    ops.ratioNeuropil     = 5; % ratio btw neuropil radius and cell radius
    % radius of surround neuropil = ops0.ratioNeuropil * (radius of cell)
end

% ----- spike deconvolution and neuropil subtraction options ----- %
ops.imageRate              = 30;   % imaging rate (cumulative over planes!). Approximate, for initialization of deconvolution kernel.
ops.sensorTau              = 2; % decay half-life (or timescale). Approximate, for initialization of deconvolution kernel.
ops.maxNeurop              = 1; % for the neuropil contamination to be less th

end