function [P, V] = getDefaultOptions()

% DESCRIPTION:
%   Change these parameters to change the behavior of the autosegmentation

% - - - - - - - - Specify parameters and default values - - - - - - - -

% Names                                 Values (default)        Description
P                                           = struct();             %

% Main (important) parameters
P.Main.avg_cell_radius                      = 7;                    % Radius estimate for an average cell in the movie. It does not have to be precise; however, setting it to a significantly larger or lower value will impair performance. It needs to be set at the start for any movie. A recommended way to set this is to consider the maximum projections of the video across time and pick the radius there (see [Example movie extraction](#example-movie-extraction)).
P.Main.num_partitions_x                     = 1;                    % User specified number of movie partitions in x and y dimensions. Running EXTRACT on the whole movie at once could be computationally too expensive or simply impossible. In this case, we divide the input movie into smaller parts. Heuristics suggest that the size of the smaller FOV should not be smaller than 128 pixels in any of the x/y dimensions.
P.Main.num_partitions_y                     = 1;                    % User specified number of movie partitions in x and y dimensions. Running EXTRACT on the whole movie at once could be computationally too expensive or simply impossible. In this case, we divide the input movie into smaller parts. Heuristics suggest that the size of the smaller FOV should not be smaller than 128 pixels in any of the x/y dimensions.
P.Main.cellfind_min_snr                     = 1;                    % Minimum peak SNR (defined as peak value/noise std) value for an object to be considered as a cell. Increase this if you want to decrease the ratio of false-positives at the expense of losing some low SNR cells in the process. Default: `1`.
P.Main.use_gpu                              = true;                 % This needs to be 1 to run EXTRACT on GPU, 0 to run EXTRACT on CPU. It is preferably, time-wise, to run EXTRACT on GPU. Default: `1`.
P.Main.trace_output_option                  = 'nonneg';             % Choose 'raw' for raw traces, 'nonneg' for non-negative traces. Check [Frequently Asked Questions](#frequently-asked-questions) before using the option 'raw'. Default: `nonneg`.
P.Main.verbose                              = 2;                    % Log output to commandline

% General parameters (preprocessing)
P.Preprocess.preprocess                     = true;                 % Run preprocessing of movie
P.Preprocess.fix_zero_FOV_strips            = false;                % Find and fix spatial slices that are occasionally zero due to frame registration (e.g. turboreg)
P.Preprocess.medfilt_outlier_pixels         = false;                % Flag that determines whether outlier pixels in the movie should be replaced with their neighborhood median.
P.Preprocess.spatial_highpass_cutoff        = 5;                    % This cutoff determines the strength of butterworth spatial filtering of the movie (higher values = more lenient filtering), and is relative to the average cell radius
P.Preprocess.remove_background              = true;
P.Preprocess.temporal_denoising             = false;                % Boolean flag that determines whether to apply temporal wavelet denoising. This functionality is experimental; expect it to increase runtime considerably if the input movie has >10K frames and has larger field of view than 250x250 pixels.
P.Preprocess.skip_dff                       = false;
    
% General parameters (downsampling)
P.Downsample.downsample_time_by             = 1;                    %
P.Downsample.downsample_space_by            = 1;                    %
P.Downsample.min_radius_after_downsampling  = 5;
P.Downsample.min_tau_after_downsampling     = 5;
P.Downsample.reestimate_S_if_downsampled    = false;
P.Downsample.reestimate_T_if_downsampled    = true;

% General parameters (Commputation / hardware)
P.Computation.use_default_gpu               = false;
P.Computation.multi_gpu                     = false;
P.Computation.parallel_cpu                  = false;
P.Computation.num_parallel_cpu_workers      = inf;

% Fov preferences
P.Fov.crop_circular                       	= false;
P.Fov.movie_mask                            = [];
P.Fov.smoothing_ratio_x2y                   = 1;

% Cell finding parameters
P.CellFind.min_snr                          = 1;
P.CellFind.dendrite_aware                   = false;
P.CellFind.max_steps                        = 1000;
P.CellFind.kappa_std_ratio                  = 1;
P.CellFind.adaptive_kappa                   = false;
P.CellFind.spatial_lowpass_cutoff           = 2;
P.CellFind.init_with_gaussian               = false;
P.CellFind.filter_type                      = 'butter';
P.CellFind.moving_radius                    = 3;
P.CellFind.numpix_threshold                 = 9;  % 3x3 region
P.CellFind.high2low_brightness_ratio        = inf;
P.CellFind.S_init                           = [];

% Alternating estimation parameters
P.Estimation.smooth_T                       = false;
P.Estimation.smooth_S                       = true;
P.Estimation.max_iter                       = 6;
P.Estimation.plot_loss                      = false;
P.Estimation.l1_penalty_factor              = 0;
P.Estimation.hyperparameter_tuning_flag     = false;

% Cell elimination parameters
P.CellElimination.T_lower_snr_threshold     = 10;
P.CellElimination.remove_duplicate_cells    = true;

% Optimizer parameters
P.Optimization.max_iter_S                   = 100;
P.Optimization.max_iter_T                   = 100;
P.Optimization.TOL_sub                      = 1e-6;
P.Optimization.kappa_std_ratio              = 1;
P.Optimization.TOL_main                     = 1e-2;

% Output preferences
P.Output.compact_output                     = true;
P.Output.save_all_found                     = false;
P.Output.use_sparse_arrays                  = false;

% - - - - - - - - - - Specify customization flags - - - - - - - - - - -
P.Main.avg_cell_radius_ = struct('type', 'slider', 'args', {{'Min', 1, 'Max', 20, 'nTicks', 19}});
P.Main.num_partitions_x_ = struct('type', 'slider', 'args', {{'Min', 1, 'Max', 8, 'nTicks', 7}});
P.Main.num_partitions_y_ = struct('type', 'slider', 'args', {{'Min', 1, 'Max', 8, 'nTicks', 7}});
P.Main.trace_output_option_ = {'nonneg', 'raw'};
P.Main.verbose_ = {0,1,2};
P.CellFind.filter_type_ = {'butter', 'gauss', 'wiener', 'movavg', 'none'};

% P.Fov.movie_mask Make interactive tool for creating this...
    
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
