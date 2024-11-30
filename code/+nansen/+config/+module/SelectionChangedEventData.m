classdef (ConstructOnLoad) SelectionChangedEventData < event.EventData
   properties
      SelectedData (1,:) struct
   end
   
   methods
       function data = SelectionChangedEventData(selectedData)
         data.SelectedData = selectedData;
      end
   end
end
