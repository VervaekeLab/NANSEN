classdef DialogBox < handle
    
    methods (Abstract)
        
        displayMessage(obj, messageString, messageDuration)
        
        clearMessage(obj)
        
    end

end