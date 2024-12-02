classdef Soma_Virus < nansen.wrapper.quicky.Options

    properties (Constant)
        Name = 'Soma (Virus)'
        Description = 'Optimized for viral GCaMP expression'
    end
    
    methods (Static)
        
        function S = getOptions()
            S = getOptions@nansen.wrapper.quicky.Options();
            S.Detection.UseShapeDetection       = false;
            S.Detection.MorphologicalShape      = 'disk';
        end
    end
end
