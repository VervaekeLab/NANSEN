classdef (ConstructOnLoad) RoiSelectionChanged < event.EventData
   
    
    properties
        eventType   % select, unselect
        roiIndices
        zoomOnRoi = false
        origin              % The class (app) which is the original source of the event notification
    end
    
    
    methods
        
        function data = RoiSelectionChanged(roiIndices, eventType, zoomOnRoi, origin)
            data.eventType = eventType;
            data.roiIndices = roiIndices;

            if nargin >= 3
                data.zoomOnRoi = zoomOnRoi;
            end
            
            if nargin >= 4
                data.origin = origin;
            end
                        
        end
        
    end
    
end