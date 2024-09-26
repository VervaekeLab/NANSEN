classdef SizeChangedData < event.EventData
    
   properties
       OldSize
       NewSize
   end
   
   methods
       function obj = SizeChangedData(oldSize, newSize)
           obj.OldSize = oldSize;
           obj.NewSize = newSize;
       end
   end
end
