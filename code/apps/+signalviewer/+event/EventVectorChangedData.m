classdef (ConstructOnLoad) EventVectorChangedData < event.EventData
   
    
    properties
        TimeSeriesIndex
        XCoordinates
    end
    
    
    methods
        
        function data = EventVectorChangedData(timeSeriesIndex, xCoordinates)
            
            data.TimeSeriesIndex = timeSeriesIndex;
            data.XCoordinates = xCoordinates;
        end
        
    end
    
end