classdef abstractPointer < handle & matlab.mixin.Heterogeneous
%uim.interface.abstractPointer 
%
% Abstract class framework for a pointer tool

% Todo: Implement callbacks for MousePressed, MouseMotion, MouseReleased,
% MouseScrolled etc that can be configured from gui that requests/creates
% the pointertools. At the moment, many of the tools has knowledge about
% the functions that need to be activated from the parent gui, and that is
% not good style!

    properties (Abstract, Constant)
        exitMode        % Go back to previous, or go back to default?
    end
    
    properties 
        isActive = false % Is tool doing something right now?
 
        hFigure
        hAxes
        
        buttonDownCallback % protected?
        buttonUpCallback % protected?
        buttonMotionCallback % protected?
        
%         activatedCallback  Just use toggle event instead??
%         deactivatedCallback
    end
    
    properties (Access = protected)
        state = 'off';      % on | on hold | off
        pointerCData = [];
    end
    
    events
        ToggledPointerTool
    end
    
    
    methods (Abstract)
        
        setPointerSymbol(obj)
        onButtonDown(obj, src, event)
        onButtonMotion(obj, src, event)
        onButtonUp(obj, src, event)
        
    end
    
    methods % Public methods
        
        function wasCaptured = onKeyPress(obj, src, event)
            wasCaptured = false;
        end
        
        function activate(obj)
            obj.setPointerSymbol()
            obj.state = 'on';
            
%             if ~isempty(obj.activatedCallback)
%                 obj.activatedCallback()
%             end
            
            eventData = uim.event.ToggleEvent(1);
            obj.notify('ToggledPointerTool', eventData)
        end
        
        function suspend(obj)
            eventData = uim.event.ToggleEvent(0);
            obj.notify('ToggledPointerTool', eventData)
            obj.state = 'on_hold';
        end
        
        function deactivate(obj)
            obj.state = 'off';
            eventData = uim.event.ToggleEvent(0);
            obj.notify('ToggledPointerTool', eventData)
        end

        function tf = isPointerInsideAxes(obj, currentPoint)
            
            if nargin < 2
                currentPoint = obj.hAxes.CurrentPoint(1, 1:2);
            end

            xLim = obj.hAxes.XLim;
            yLim = obj.hAxes.YLim;
            axLim = [xLim(1), yLim(1), xLim(2), yLim(2)];

            % Check if mousepoint is within axes limits.
            tf = ~any(any(diff([axLim(1:2); currentPoint; axLim(3:4)]) < 0));
        end
        
    end
    
    methods (Access = public) % These should not be public... Or there 
        %should be one method that can be accessed from Pointermanager and
        %one method that can be overridden by subclasses...
        
        function onPointerExitedAxes(obj)
            % Subclasses may override
        end
        
        function onPointerEnteredAxes(obj)
            % Subclasses may override
        end
        
    end
    
end