classdef LocationChangedData < event.EventData
    
   properties
       OldLocation
       NewLocation
   end
   
   methods
       function obj = LocationChangedData(oldLocation, newLocation)
           obj.OldLocation = oldLocation;
           obj.NewLocation = newLocation;
       end
   end
   
end

