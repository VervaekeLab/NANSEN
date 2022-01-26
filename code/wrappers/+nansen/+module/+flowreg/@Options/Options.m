classdef Options < nansen.module.abstract.OptionsAdapter

    
    properties (Constant)
        ToolboxName = 'FlowRegistration'
    end
    
    methods (Static)
        
        % Static method for getting default options (in separate file)
        [P, V] = getDefaults()
        
        % Static method for getting conversion adapter (in separate file)
        M = getAdapter()
        
    end
    
    methods (Static)
        
        function S = getOptions()
            S = nansen.module.flowreg.Options.getDefaults();
            
            % Temp fix???
            className = 'nansen.module.flowreg.Processor';
            superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
            S = nansen.mixin.HasOptions.combineOptions(S, superOptions{:});
        end
        
        
        function options = convert(S, ~)
        %getToolboxOptions Get options compatible with the toolbox.
        %
        %   options = convert(S) given a struct S of options,
        %   will convert to a struct which is used in the flowregistration
        %   pipeline.
        
            import nansen.module.flowreg.*

            nameMap = nansen.module.flowreg.Options.getAdapter();
            nvPairs = nansen.module.abstract.OptionsAdapter.rename(S, nameMap, 'nvPairs');
            
            
            %nvPairs = Options.getToolboxNvPairs(S);
                        
            options = OF_options(nvPairs{:});
                        
        end

    end
    
end

% % % Original flowreg options
% %     properties
% %         %input_file; iNansen
% %         %output_path = 'results'; iNansen
% %         %output_format = 'MAT'; iNansen

% %         channel_idx = [];
% %         %output_file_name = []; iNansen
% %         %output_file_writer = []; iNansen

% %         alpha       = 1.5;                  smoothness parameter, regularization parameter
% %         weight      = [0.5, 0.5];           Channel weight
% %         levels      = 100;
% %         min_level   = -1;                   % Something about performance 
% %         quality_setting = 'quality'; warping depth
% %         eta         = 0.8;                  downsampling factor
% %         update_lag  = 5;
% %         iterations  = 50;
% %         a_smooth    = 1;                    penalizer power?
% %         a_data      = 0.45;


% %         sigma       = [1, 1, 0.1; ...       % Gaussian smoothing? Preprocessing
% %                        1, 1, 0.1];          % Per channel

% %         bin_size = 1;                       % For temporal(?) downsampling?
% %         buffer_size = 400; % iNansen        % How many frames to batch
% %         verbose = false;  %iNansen?
% %         reference_frames = 50:500;

% %         % save_meta_info = true; % (stats) iNansen
% %         % save_w = false; % (shifts) iNansen
% %         % output_typename = 'double'; iNansen
% %         channel_normalization = 'joint';
% %     end