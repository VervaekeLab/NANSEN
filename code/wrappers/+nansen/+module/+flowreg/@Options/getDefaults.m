function [P, V] = getDefaults()

% DESRIPTION:
%   Change these parameters to change the behavior of the NoRMCorre method


% - - - - - - - - Specify parameters and default values - - - - - - - - 

% Names                         Values (default)        Description
P                               = struct();             

P.General.smoothness            = 1.5;                                                  % smoothness parameter
P.General.verbose               = false;

P.General.symmetricKernel       = true;
P.General.sigmaX                = 1;
P.General.sigmaY                = 1;
P.General.sigmaZ                = 0.1;

P.General.binSize               = 1;

P.Channel.weighting             = [0.5, 0.5];
P.Channel.normalization         = 'joint';

P.Quality.registrationQuality   = 'quality';

% Display the resized image that shows the "resolution" of shifts...
P.Quality.levels                = 100;
%P.Quality.minimumLevel          = -1;               % Min level overrides the quality setting! 1-6?

%S.SolverParams %?

P.Model.downsamplingFactor      = 0.8;

P.Model.updateLag               = 5;
P.Model.iterations              = 50;
P.Model.aSmooth                 = 1;                  % 
P.Model.aData                   = 0.45;
P.Model.sigma                   = [1, 1, 0.1];%; ...
            % 1, 1, 0.1];


% - - - - - - Specify customization flags (uicontrols) - - - - - - - -

P.General.sigmaX_ = struct('type', 'slider', 'args', {{'Min', 0.1, 'Max', 5, 'nTicks', 49}}); 
P.General.sigmaY_ = struct('type', 'slider', 'args', {{'Min', 0.1, 'Max', 5, 'nTicks', 49}}); 
P.General.sigmaZ_ = struct('type', 'slider', 'args', {{'Min', 0.1, 'Max', 5, 'nTicks', 49}}); 
P.Channel.normalization_    = {'joint', 'separate'}; 
P.Quality.registrationQuality_ = {'quality', 'balanced', 'fast'};
P.Model.downsamplingFactor_ = struct('type', 'slider', 'args', {{'Min', 0, 'Max', 1, 'nTicks', 99}});


% - - - - Specify validation/assertion test for each parameter - - - - 

V                               = struct();
V.Configuration.sigmaX         = @(x) assert( isnumeric(x) && isscalar(x) && x >= 0, ...
                                    'Value must be a scalar, non-negative number' );
V.Configuration.sigmaY         = @(x) assert( isnumeric(x) && isscalar(x) && x >= 0, ...
                                    'Value must be a scalar, non-negative number' );

                                
% - - - - - Adapt output to how many outputs are requested - - - - - -

if nargout == 0
    displayParameterTable(mfilename('fullpath'))
    clear P V
elseif nargout == 1
    clear V
end

end