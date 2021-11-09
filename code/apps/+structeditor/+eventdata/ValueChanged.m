classdef (ConstructOnLoad) ValueChanged < event.EventData
   
    
    properties
        Name
        OldValue
        NewValue
        UIControls
    end
    
    
    methods
        
        function data = ValueChanged(Name, OldValue, NewValue, UIControls)
            data.Name = Name;
            data.OldValue = OldValue;
            data.NewValue = NewValue;
            data.UIControls = UIControls;
        end
        
    end
    
end