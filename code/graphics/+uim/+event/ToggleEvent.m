classdef ToggleEvent < event.EventData
    
   properties
       Value
   end
   
   methods
       function obj = ToggleEvent(value)
           obj.Value = value;
       end
   end
   
end

