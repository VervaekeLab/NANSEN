classdef ToolTip < uim.handle
%ToolTip Interface for adding a tooltip display in a component canvas.

    % TODO:
    %   [ ] Add style configuration...
    
    properties
        BackgroundColor
        ForegroundColor
        EdgeColor
        
        FontName
        FontSize
        
        Style
    end
    
    properties (Access = private)
        Axes
        TooltipHandle
    end
    
    properties (Hidden, Access = private)
        SiblingCreatedListener % Listener for creation of new objects in the parent axes.
        ParentDestroyedListener
    end
    
    methods
        
        function obj = ToolTip(canvasObj)
            
            obj.Axes = canvasObj.Axes;
            
            setappdata(canvasObj.Parent, 'TooltipDisplay', obj)
            
            obj.createTooltipHandle()
            obj.ensureAlwaysOnTop()
            
            deleteFunc = @(src,evt) delete(obj);
            el = addlistener(obj.Axes, 'ObjectBeingDestroyed', deleteFunc);
            obj.ParentDestroyedListener = el;
            
        end
        
        function delete(obj)
            
        end
    end
    
    methods
        
        function showTooltip(obj, text, position)
            
            if ~isempty(obj.TooltipHandle) && isvalid(obj.TooltipHandle)
                
                obj.TooltipHandle.String = text;
                obj.TooltipHandle.Visible = 'on';
                
                extent = obj.TooltipHandle.Extent;
                lim = {'XLim', 'YLim'};
                for i = 1:2
                    if position(i) < obj.Axes.(lim{i})(1)
                        position(i) = obj.Axes.(lim{i})(1);% + obj.TooltipHandle.Margin*2;
                    elseif position(i) + extent(i+2) > obj.Axes.(lim{i})(2)
                        position(i) = obj.Axes.(lim{i})(2) - extent(i+2)*1.1;% - obj.TooltipHandle.Margin*2;
                    end
                end
                
                obj.TooltipHandle.Position(1:2) = position;
                % drawnow limitrate
            end
        end
        
        function hideTooltip(obj)
            if ~isempty(obj.TooltipHandle) && isvalid(obj.TooltipHandle)
                obj.TooltipHandle.String = '';
                obj.TooltipHandle.Visible = 'off';
            end
        end
    end
    
    methods (Access = private)
        
        function createTooltipHandle(obj) %todo: Make class...
            
            hAx = obj.CanvasAxes;
            
            % Create a tooltip...
            obj.TooltipHandle = text(hAx, 1,1, '');
            obj.TooltipHandle.BackgroundColor = ones(1,3) * 0.2;
            obj.TooltipHandle.Color = ones(1,3) * 0.8;
            obj.TooltipHandle.EdgeColor = 'none';
            obj.TooltipHandle.FontName = 'Avenir Next';
            obj.TooltipHandle.FontSize = 12;
            obj.TooltipHandle.HorizontalAlignment = 'left';
            obj.TooltipHandle.VerticalAlignment = 'top';
            obj.TooltipHandle.Visible = 'off';
            obj.TooltipHandle.HitTest = 'off';
            obj.TooltipHandle.PickableParts = 'none';
            
        end
        
        function ensureAlwaysOnTop(obj)
        %ensureAlwaysOnTop Create event callback to always keep tooltip on top
        
            onChildAddedFunc = @(s,e) obj.bringTooltipToFront;
            el = addlistener(obj.Axes, 'ChildAdded', onChildAddedFunc);
            obj.SiblingCreatedListener = el;
            
        end
        
        function bringTooltipToFront(obj)
            uistack(obj.TooltipHandle, 'top')
        end
    end
end
