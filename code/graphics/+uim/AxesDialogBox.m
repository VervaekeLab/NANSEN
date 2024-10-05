classdef AxesDialogBox < applify.DialogBox
    
    properties (Access = protected)
        MessageBox
    end
    
    properties (Access = private)
        ReferenceAxes
        ReferenceAxesSizeChangedListener
    end
    
    methods
        
        function obj = AxesDialogBox(referenceAxes)
            
            obj.ReferenceAxes = referenceAxes;
            
            % Todo: Store some axes properties like size etc.
            obj.MessageBox = uim.widget.messageBox(referenceAxes);
        
            obj.ReferenceAxesSizeChangedListener = listener(obj.ReferenceAxes, ...
                'SizeChanged', @obj.onReferenceAxesSizeChanged);
        end
    end
    
    methods
        
        function displayMessage(obj, messageString, messageDuration)
            if nargin < 3; messageDuration = []; end
            obj.MessageBox.displayMessage(messageString, messageDuration)
        end
        
        function clearMessage(obj)
            obj.MessageBox.clearMessage()
        end
    end
    
    methods (Access = private)
        
        function onReferenceAxesSizeChanged(obj, src, evt)
            
            pos = obj.ReferenceAxes.Position;
            obj.MessageBox.centerInWindow(pos)

        end
    end
end
