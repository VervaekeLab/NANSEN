classdef (ConstructOnLoad) SelectionChangedEventData < event.EventData
   properties
      SelectedData
   end
   
   methods
       function data = SelectionChangedEventData(selectedData)
         data.SelectedData = selectedData;
      end
   end
end