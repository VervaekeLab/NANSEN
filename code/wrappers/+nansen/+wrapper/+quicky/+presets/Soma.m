classdef Soma < nansen.wrapper.quicky.Options

    properties (Constant)
        Name = 'Soma'
        Description = 'Autosegment neuronal somas'
    end
    
    methods (Static)
        
        function S = getOptions()
            S = getOptions@nansen.wrapper.quicky.Options();
        end
        
    end
    
end