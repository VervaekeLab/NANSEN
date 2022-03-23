classdef HasDialogBox < uim.handle
    
    properties
        DialogBox
    end
    
    methods 
        
        function displayMessage(obj, message, target, msgDuration)
            
            if isempty(obj.DialogBox)
                fprintf([message, '\n']); return
            end
            
            if nargin < 4; msgDuration = []; end

            obj.DialogBox.displayMessage(message, msgDuration)

        end

        function clearMessage(obj)
            
            if isempty(obj.DialogBox)
                fprintf([message, '\n']); return
            end
            
            if isvalid(obj) && ~isempty(obj.DialogBox)
                obj.DialogBox.clearMessage()
            end

        end
        
    end
    
end