classdef Axon < nansen.module.twophoton.autosegmentation.flufinder.Options

    properties (Constant)
        Name = 'Axons'
        Description = 'Tuned to detect smaller axonal bouton-like structures'
    end

    methods (Static)

        function S = getOptions()
            S = getOptions@nansen.module.twophoton.autosegmentation.flufinder.Options();

            S.General.RoiDiameter = 4;
            S.General.RoiType = 'Axonal Bouton';
            S.Detection.MaxNumRois = 1000; % For axonal data...
            S.Detection.PrctileForBinarization = 95; % Axonal data is typically more sparse..
            S.Detection.UseShapeDetection = false;
        end
    end
end
