classdef GRaFTWrapper < nansen.NansenToolboxWrapper
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        ToolboxName
    end
    
    methods
        function obj = GRaFTWrapper(inputArg1)
            %UNTITLED Construct an instance of this class
            %   Detailed explanation goes here
            obj.Property1 = inputArg1;
        end
        
        function outputArg = method1(obj,inputArg)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            outputArg = obj.Property1 ;
        end
    end
    
    
    
    methods (Static)
        function checkDependencies(mode)
            % Default is to do nothing
            
            if nargin < 1
                mode = 'assert';
            end
            
            requiredToolboxes = {...
                'Wavelet Toolbox'
                }; 
            
            TF = nansen.setup.isToolboxInstalled(requiredToolboxes);
            
            if TF
                switch mode
                    case 'assert'
                        assert(TF, 'The GRaFT Toolbox requires the ')
                    case 'prompt'
                        % Todo
                end
            end
            
        end
    end
    
    
    
end

