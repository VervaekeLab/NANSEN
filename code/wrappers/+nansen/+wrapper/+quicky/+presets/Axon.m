classdef Axon < nansen.wrapper.quicky.Options

    properties (Constant)
        Name = 'Axons'
        Description = 'Autosegment neuronal axonal boutons'
    end
    
    methods (Static)
        
        function S = getOptions()
            S = getOptions@nansen.wrapper.quicky.Options();
            
            S.RoiDiameter = 4;
            S.MorphologicalStructure = 'Axonal Bouton';
            S.MaxNumRois = 1000; % For axonal data...?

        end
        
    end
    
end