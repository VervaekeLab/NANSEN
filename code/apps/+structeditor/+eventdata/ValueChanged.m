classdef (ConstructOnLoad) ValueChanged < event.EventData
   
    
    properties
        Name
        OldValue
        NewValue
        UIControls
        PageNumber
    end
    
    
    methods
        
        function data = ValueChanged(Name, OldValue, NewValue, UIControls, pageNumber)
            if nargin < 5;  pageNumber = 1; end
            data.Name = Name;
            data.OldValue = OldValue;
            data.NewValue = NewValue;
            data.UIControls = UIControls;
            data.PageNumber = pageNumber;
        end
        
    end
    
end