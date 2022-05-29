classdef Default < nansen.wrapper.graft.Options

    properties (Constant)
        Name = 'GRaFT Default Preset'
        Description = 'Default preset options for GRaFT signal extraction'
    end
    
    methods (Static)
        
        function S = getOptions()
            S = getOptions@nansen.wrapper.graft.Options();
        end
        
    end
    
end