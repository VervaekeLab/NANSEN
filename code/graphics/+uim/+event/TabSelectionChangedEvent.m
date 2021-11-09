classdef TabSelectionChangedEvent < event.EventData
    
   properties
       OldValue
       NewValue
   end
   
   methods
       function obj = TabSelectionChangedEvent(oldValue, newValue)
           obj.OldValue = oldValue;
           obj.NewValue = newValue;
       end
   end
   
end

