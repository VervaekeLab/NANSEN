classdef Demo < nansen.wrapper.graft.Options

    properties (Constant)
        Name = 'GRaFT Demo Preset'
        Description = 'Demo preset options for GRaFT signal extraction'
    end
    
    methods (Static)
        
        function S = getOptions()
            S = getOptions@nansen.wrapper.graft.Options();

            S.lambda    = 0.05;                                                   % Sparsity parameter
            S.lamForb   = 0.2;                                                    % parameter to control how much to weigh extra time-traces
            S.lamCorr   = 0.1;                                                    % Parameter to prevent overly correlated dictionary elements 
            S.n_dict    = 20;                                                     % Choose how many components (per patch) will be initialized. Note: the final number of coefficients may be less than this due to lack of data variance and merging of components.
            S.patchSize = 50;                                                     % Choose the size of the patches to break up the image into (squares with patchSize pixels on each side)

            S.lamCont       = 0.1;                                                % parameter to control how much to weigh the previous estimate (continuity term)
            S.grad_type     = 'full_ls_cor';                                      % type of dictionary update
            S.lamContStp    = 0.9;                                                % Decay rate of the continuation parameter
            S.plot          = true;                                               % Set whether to plot intermediary variables
            S.create_memmap = false;                                              % 
            S.verbose       = 0;                                                  % Level of verbose output 
            S.normalizeSpatial = true;
        end
        
    end
    
end