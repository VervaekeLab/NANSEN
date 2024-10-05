classdef (ConstructOnLoad) RoiGroupChanged < event.EventData
    
    properties
        eventType   % initialize, append, insert, modify, remove
        roiArray
        roiIndices
    end
    
    methods
        
        function data = RoiGroupChanged(roiArray, roiIndices, eventType)
            data.eventType = eventType;
            data.roiArray = roiArray;
            data.roiIndices = roiIndices;
        end
    end
end
