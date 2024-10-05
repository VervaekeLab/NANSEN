function [P, V] = getDeconvolutionParameters()
%getDeconvolutionParameters Get parameters for signal deconvolution
%
%   P = nansen.twophoton.roisignals.getDeconvolutionParameters() returns
%       a struct (P) with default parameters for signal deconvolution
%
%   [P, V] = nansen.twophoton.roisignals.getDeconvolutionParameters()
%       returns an additional struct (V) containing assertions for each
%       parameter, for use with an input parser etc.
%
%   SELECTED PARAMETERS:
%   --------------------
%   modelType : char ( 'ar1' | 'ar2' (default) | 'exp2' | 'kernel' )
%       Defines the model of the deconvolution kernel. See decovolveCa
%   modelParams : depends on modelType
%       Parameters for the specified convolution kernel. See decovolveCa
%
%
%   Note: for full list of parameters, run function without output, i.e
%       nansen.twophoton.roisignals.getDeconvolutionParameters()

%   TODO:
%    [ ] Rename to caiman.deconvolution.parameters
%    [ ] Rename to caiman.deconvolution.options

% DESCRIPTION:
%   Change these parameters to change the behavior of the deconvolution
%   method.

    % - - - - - - - - Specify parameters and default values - - - - - - - -
    
    % Names                       Values (default)      Description
    P                           = struct();             %
    P.modelType                 = 'ar2';                % Defines the model of the deconvolution kernel. See decovolveCa
    P.modelParams               = [];                   % Model parameters. Depends on the model.
    P.spikeSnr                  = 1;                    % Spike snr threshold
    P.lambdaPr                  = 0.5;                  % Lambd pr
    P.estimateTimeConstants     = false;                % Optimize time constants (ignores preset values)
    P.optimizeTimeConstants     = false;                % Estimate time constant from data or use hardcoded values Todo: remove
    P.tauRise                   = 180;                  % Rise time constant (ms)
    P.tauDecay                  = 550;                  % Decay time constant (ms)
    P.sampleRate                = 31;                   % Number of samples per second
       
    % - - - - - - - - - - Specify customization flags - - - - - - - - - - -
    P.modelType_                = {'ar1', 'ar2', 'exp2'};
    P.modelParams_              = 'internal';
    
    % - - - - Specify validation/assertion test for each parameter - - - -
    
    V                           = struct();
    V.modelType                 = @(x) assert(any(strcmp(x, {'ar1', 'ar2', 'exp2', 'kernel', 'autoar'})), ...
                                    'modelType must be ''ar1'', ''ar2'', ''exp2'' or ''kernel''');
    V.modelParams               = @(x) assert(isempty(x) || (ismatrix(x) && islogical(x)), ...
                                    'Value must be a logical matrix');
    V.spikeSnr                  = @(x) assert( isnumeric(x) && isscalar(x), ...
                                    'Value must be a scalar' );
    V.lambdaPr                  = @(x) assert( isnumeric(x) && isscalar(x), ...
                                    'Value must be a scalar' );
    V.tauRise                   = @(x) assert( isnumeric(x) && isscalar(x) && x >= 0 && round(x)==x, ...
                                    'Value must be a scalar, non-negative, integer number' );
    V.tauDecay                  = @(x) assert( isnumeric(x) && isscalar(x) && x >= 0 && round(x)==x, ...
                                    'Value must be a scalar, non-negative, integer number' );
    V.sampleRate                = @(x) assert( isnumeric(x) && isscalar(x) && x >= 0, ...
                                    'Value must be a scalar, non-negative number' );
                                
    % - - - - - Adapt output to how many outputs are requested - - - - - -
    
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
