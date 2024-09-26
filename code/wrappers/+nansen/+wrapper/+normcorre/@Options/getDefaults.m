function [P, V] = getDefaults()

% DESCRIPTION:
%   Change these parameters to change the behavior of the NoRMCorre method


% - - - - - - - - Specify parameters and default values - - - - - - - - 

% Names                         Values (default)        Description
P                               = struct();             

P.Configuration.numRows         = 4;                    % Size of non-overlapping portion of each patch in the grid (y-direction)
P.Configuration.numCols         = 4;                    % Size of non-overlapping portion of each patch in the grid (x-direction)
P.Configuration.patchOverlap    = [32,32,16];           % Size of overlapping region in each direction before upsampling
P.Configuration.gridUpsampling  = [4 4 1];              % Upsampling factor for smoothing and refinement of motion field

P.Template.initialBatchSize     = 100;                  % Number of frames to be taken for computing initial template
P.Template.updateTemplate       = true;                 % Update the template online after registering some frames
P.Template.binWidth             = 50;                   % Length of bin over which the registered frames are averaged to update the template

P.Correction.maximumShift       = [40,40,5];            % Maximum allowed shift for rigid translation (x,y,z) or y,x,z?
P.Correction.maximumDeviation   = [15,15,1];            % Maximum deviation of each patch from estimated rigid translation (x,y,z) or y,x,z?
P.Correction.subpixelUpsampling = 50;                   % Upsampling factor for subpixel registration
P.Correction.numIterations      = 1;                    % Number of times to go over the dataset
P.Correction.shiftsMethod       = 'FFT';                % Method to apply shifts ('FFT', 'cubic' or 'linear').
P.Correction.boundary           = 'copy';               % Method of boundary treatment 'NaN','copy','zero','template' (default: 'copy')
P.Correction.phaseFlag          = false;                % Flag for using phase correlation

P.Misc.Verbose                  = false;                % Flag for displaying progress
P.Misc.UseParallell             = true;                 % Use parallel processing for patches of each frame


% - - - - - - Specify customization flags (uicontrols) - - - - - - - -

P.Configuration.numRows_ = struct('type', 'slider', 'args', {{'Min', 1, 'Max', 16, 'nTicks', 15, 'TooltipPrecision', 0}});
P.Configuration.numCols_ = struct('type', 'slider', 'args', {{'Min', 1, 'Max', 16, 'nTicks', 15, 'TooltipPrecision', 0}});

P.Correction.shiftsMethod_ = {'FFT','cubic','linear'};
P.Correction.boundary_ = {'NaN','copy','zero','template'};

    
    
% - - - - Specify validation/assertion test for each parameter - - - - 

V                               = struct();
V.Configuration.numRows         = @(x) assert( isnumeric(x) && isscalar(x) && x >= 0 && round(x)==x, ...
                                    'Value must be a scalar, non-negative, integer number' );
V.Configuration.numRows         = @(x) assert( isnumeric(x) && isscalar(x) && x >= 0 && round(x)==x, ...
                                    'Value must be a scalar, non-negative, integer number' );

                                
% - - - - - Adapt output to how many outputs are requested - - - - - -

if nargout == 0
    displayParameterTable(mfilename('fullpath'))
    clear P V
elseif nargout == 1
    clear V
end

end