classdef Axon < nansen.wrapper.quicky.Options

    properties (Constant)
        Name = 'Axons'
        Description = 'Autosegment neuronal axonal boutons'
    end
    
    methods (Static)
        
        function S = getOptions()
            S = getOptions@nansen.wrapper.quicky.Options();
            
            S.MorphologicalStructure = 'Axonal Bouton';
            
        end
        
    end
    
end