classdef Soma_Virus < nansen.module.twophoton.autosegmentation.flufinder.Options

    properties (Constant)
        Name = 'Soma (Virus)'
        Description = 'Optimized for viral GCaMP expression'
    end

    methods (Static)

        function S = getOptions()
            S = getOptions@nansen.module.twophoton.autosegmentation.flufinder.Options();
            S.Detection.UseShapeDetection       = false;
            S.Detection.MorphologicalShape      = 'disk';
        end
    end
end
