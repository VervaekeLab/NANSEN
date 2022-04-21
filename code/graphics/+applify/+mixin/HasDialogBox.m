classdef HasDialogBox < uim.handle
    
    properties
        DialogBox
    end
    
    methods
        
        function C = activateGlobalMessageDisplay(obj, mode)

            if nargin < 2
                mode = 'update';
            end

            global fprintf

            switch mode
                case 'display'
                    fprintf = @(msg)obj.DialogBox.displayMessage(msg);
                case 'update'
                    fprintf = @(varargin)obj.DialogBox.displayMessage(varargin{:});
            end

            C = onCleanup(@obj.deactivateGlobalMessageDisplay);

        end
        
        function deactivateGlobalMessageDisplay(obj)
            global fprintf
            fprintf = str2func('fprintf');
            obj.DialogBox.clearMessage()
        end
        
        
        function displayMessage(obj, message, msgDuration)
            
            if isempty(obj.DialogBox)
                fprintf([message, '\n']); return
            end
            
            if nargin < 3; msgDuration = []; end

            obj.DialogBox.displayMessage(message, msgDuration)

        end

        function clearMessage(obj)
            
            if isempty(obj.DialogBox)
                return
            end
            
            if isvalid(obj) && ~isempty(obj.DialogBox)
                obj.DialogBox.clearMessage()
            end

        end
        
    end
    
end