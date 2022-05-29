function [P, V] = getDefaults()


% DESRIPTION:
%   Change these parameters to change the behavior of the autosegmentation


% - - - - - - - - Specify parameters and default values - - - - - - - - 

% Names                                 Values (default)        Description
P                                       = struct();             %
P.tau               = 1;                                        % Default tau values to be spatially varying
P.lambda            = 0.6;                                      % Sparsity parameter. Default lambda parameter is 0.6
P.lamForb           = 0;                                        % Parameter to control how much to weigh extra time-traces. Default Forbenius norm parameter is 0 (don't use)
P.lamCont           = 0;                                        % Parameter to control how much to weigh the previous estimate (continuity term). Default Dictionary continuation term parameter is 0 (don't use)
P.lamContStp        = 1;                                        % Decay rate of the continuation parameter. Default multiplicative change to continuation parameter is 1 (no change)
P.lamCorr           = 0;                                        % Parameter to prevent overly correlated dictionary elements. Default Dictionary correlation regularization parameter is 0 (don't use)
P.beta              = 0.09;                                     % Default beta parameter to 0.09
P.maxiter           = 0.01;                                     % Default the maximum iteration to whenever Delta(Dictionary)<0.01
P.numreps           = 2;                                        % Default number of repetitions for RWL1 is 2
P.tolerance         = 1e-8;                                     % Default tolerance for TFOCS calls is 1e-8
P.verbose           = 10;                                       % Level of verbose output. Default to full verbosity level
P.likely_form       = 'gaussian';                               % Default to a gaussian likelihood ('gaussian' or 'poisson')
P.step_s            = 1;                                        % Default step to reduce the step size over time (only needed for grad_type = 'norm')
P.step_decay        = 0.995;                                    % Default step size decay (only needed for grad_type = 'norm')
P.max_learn         = 1e3;                                      % Maximum number of steps in learning is 1000 
P.learn_eps         = 0.01;                                     % Default learning tolerance: stop when Delta(Dictionary)<0.01
%P.n_dict          = selectDictSize(data_obj);                  % Choose how many components (per patch) will be initialized. Note: the final number of coefficients may be less than this due to lack of data variance and merging of components. Default number of dictionary elements is a function of the data
P.verb              = 1;                                        % Default to no verbose output
P.grad_type         = 'full_ls_cor';                            % Type of dictionary update. Default to optimizing a full optimization on all dictionary elements at each iteration
P.GD_iters          = 1;                                        % Default to one GD step per iteration
P.bshow             = 0;                                        % Default to no plotting
P.nneg_dict         = 1;                                        % Default to not having negativity constraints
P.nonneg            = true;                                     % Default to not having negativity constraints on the coefficients
P.plot              = false;                                    % Set whether to plot intermediary variables. Default to not plot spatial components during the learning
P.updateEmbed       = false;                                    % Default to not updateing the graph embedding based on changes to the coefficients
P.mask              = [];                                       % for masked images (widefield data)
P.normalizeSpatial  = false;                                    % default behavior - time-traces are unit norm. when true, spatial maps normalized to max one and time-traces are not normalized

P.patchSize         = 50;                                       % Choose the size of the patches to break up the image into (squares with patchSize pixels on each side)  


% - - - - - - - - - - Specify customization flags - - - - - - - - - - -

P.likely_form_ = {'gaussian', 'poisson'};
P.grad_type_ = {'norm', 'forb', 'full_ls', 'anchor_ls', 'anchor_ls_forb', 'full_ls_cor', 'full_ls_forb', 'sparse_deconv'};


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