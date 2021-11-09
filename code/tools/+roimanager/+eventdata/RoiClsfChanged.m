classdef (ConstructOnLoad) RoiClsfChanged < event.EventData
   
    
    properties
        roiIndices
        classification
    end
    
    
    methods
        
        function data = RoiClsfChanged(roiIndices, classification)
            data.roiIndices = roiIndices;
            data.classification = classification;
        end
        
    end
    
end