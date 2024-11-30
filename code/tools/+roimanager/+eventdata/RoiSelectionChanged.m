classdef (ConstructOnLoad) RoiSelectionChanged < event.EventData
%RoiSelectionChanged Eventdata for "roi selection changed" event.
    
    properties
        OldIndices      % Indices of rois that were selected before
        NewIndices      % Indices of rois that are newly selected
        OriginSource    % Handle to app that originated this event.
    end
    
    methods
        
        function data = RoiSelectionChanged(oldInd, newInd, origin)
            
            if nargin < 3; origin = []; end
            
            data.OldIndices = oldInd;
            data.NewIndices = newInd;
            data.OriginSource = origin;
            
        end
    end
end
