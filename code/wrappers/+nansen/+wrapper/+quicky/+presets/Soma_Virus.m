classdef Soma_Virus < nansen.wrapper.quicky.Options

    properties (Constant)
        Name = 'Soma (Virus)'
        Description = 'Autosegment neuronal somas'
    end
    
    methods (Static)
        
        function S = getOptions()
            S = getOptions@nansen.wrapper.quicky.Options();
            
            S.MorphologicalSearch = false;
            
            % Todo:
            % S.MorphologicalSearch = true;
            % S.MorphologicalFeatures = 'disk';

        end
        
    end
    
end