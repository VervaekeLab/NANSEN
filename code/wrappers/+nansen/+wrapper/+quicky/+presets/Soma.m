classdef Soma < nansen.wrapper.quicky.Options

    properties (Constant)
        Name = 'Soma'
        Description = 'Optimized for detecting soma-like structures'
    end
    
    methods (Static)
        
        function S = getOptions()
            S = getOptions@nansen.wrapper.quicky.Options();
        end
    end
end
