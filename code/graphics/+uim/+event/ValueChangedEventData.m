classdef ValueChangedEventData < event.EventData
    
   properties
       OldValue
       NewValue
   end
   
   methods
       function obj = ValueChangedEventData(oldValue, newValue)
           obj.OldValue = oldValue;
           obj.NewValue = newValue;
       end
   end
   
end