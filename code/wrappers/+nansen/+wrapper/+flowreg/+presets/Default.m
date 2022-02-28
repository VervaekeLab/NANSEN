classdef Default < nansen.wrapper.flowreg.Options

    properties (Constant)
        Name = 'Flowreg Preset'
        Description = 'Default preset options for nonrigid correction with flowreg'
    end
    
    methods (Static)
        
        function S = getOptions()
            S = getOptions@nansen.wrapper.flowreg.Options();
        end
        
    end
    
end