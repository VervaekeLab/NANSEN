classdef (ConstructOnLoad) RoiSignalsChanged < event.EventData
   
    
    properties
        signalType   % select, unselect
        roiIndices
        action
    end
    
    
    methods
        
        function data = RoiSignalsChanged(roiIndices, signalType, action)
            
            data.roiIndices = roiIndices;
            data.signalType = signalType;
            data.action = action;
        end
        
    end
    
end