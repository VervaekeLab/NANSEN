classdef ManualClassification
%ManualClassification Enumeration for manual classification labels for rois

    enumeration
        Unclassified(0)
        Accepted(1)
        Rejected(2)
        Unresolved(3)
    end
    
    properties
        Color
        Index
    end
       
    methods

        function obj = ManualClassification(classificationIndex)
            
            obj.Index = classificationIndex;
            
            switch obj.Index
                case 0
                    obj.Color = [0.900, 0.900, 0.900];
                case 1
                    obj.Color = [0.174, 0.697, 0.492];
                case 2
                    obj.Color = [0.920, 0.339, 0.378];
                case 3
                    obj.Color = [0.176, 0.374, 0.908];
            end
        end
    end
    
    methods (Static)
            
        function labels = index2labels(indexVector)
            
            enums = enumeration('roimanager.enum.ManualClassification');
            labels = cell(1, numel(indexVector));
            
            for i = 1:numel(enums)
                labels(indexVector == enums(i).Index) = {char(enums(i))};
            end
        end
    end
end
