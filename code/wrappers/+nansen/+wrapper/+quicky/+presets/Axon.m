classdef Axon < nansen.wrapper.quicky.Options

    properties (Constant)
        Name = 'Axons'
        Description = 'Autosegment neuronal axonal boutons'
    end
    
    methods (Static)
        
        function S = getOptions()
            S = getOptions@nansen.wrapper.quicky.Options();
            
            S.General.RoiDiameter = 4;
            S.General.RoiType = 'Axonal Bouton';
            S.Detection.MaxNumRois = 1000; % For axonal data...
            S.Detection.PrctileForBinarization = 95; % Axonal data is typically more sparse..
            S.Detection.UseShapeDetection = false;
        end
    end
end
