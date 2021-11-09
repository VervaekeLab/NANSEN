classdef (ConstructOnLoad) RoiSelectionChanged < event.EventData
   
    
    properties
        eventType   % select, unselect
        roiIndices
        zoomOnRoi = false
    end
    
    
    methods
        
        function data = RoiSelectionChanged(roiIndices, eventType, zoomOnRoi)
            data.eventType = eventType;
            data.roiIndices = roiIndices;
            
            if nargin == 3
                data.zoomOnRoi = zoomOnRoi;
            end
            
        end
        
    end
    
end