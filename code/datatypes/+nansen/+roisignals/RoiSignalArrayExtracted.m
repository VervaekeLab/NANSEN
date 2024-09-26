classdef RoiSignalArrayExtracted < nansen.roisignals.RoiSignalArray

    methods
        function obj = RoiSignalArrayExtracted(roiSignalArray, roiGroup)
            
            if isa(roiSignalArray, 'timetable')
                varNames = roiSignalArray.Properties.VariableNames;
                obj.NumFrames = size(roiSignalArray, 1);
                
            elseif isa(roiSignalArray, 'struct')
                varNames = fieldnames(roiSignalArray);
                obj.NumFrames = size(roiSignalArray.(varNames{1}), 1);
            end
            
            obj.RoiGroup = roiGroup;
            
            if obj.NumRois > 0
                obj.initializeSignalArray()
            end
            
            I = 1:obj.NumFrames;
            J = 1:obj.NumRois;
            
            for i = 1:numel(varNames)
                data = roiSignalArray.(varNames{i});
                
                switch varNames{i}
                    case 'RoiSignals_MeanF'
                        obj.Data.roiMeanF(I, J) = data;
                    case 'RoiSignals_NeuropilF'
                        obj.Data.npilMediF(I, J) = data;
                    case 'RoiSignals_Dff'
                        obj.Data.dff(I, J) = data;
                    case 'RoiSignals_Deconvolved'
                        obj.Data.deconvolved(I, J) = data;
                    case 'RoiSignals_Denoised'
                        obj.Data.denoised(I, J) = data;
                end
            end
        end
        
        function tf = isVirtual(obj)
            tf = false;
        end
    end
end
