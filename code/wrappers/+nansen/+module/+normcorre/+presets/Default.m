classdef Default < nansen.module.normcorre.Options

    properties (Constant)
        Name = 'Nonrigid (4x4)'
        Description = 'The original preset options for nonrigid correction'
    end
    
    methods (Static)
        
        function S = getOptions()
            S = getOptions@nansen.module.normcorre.Options();
        end
        
    end
    
end