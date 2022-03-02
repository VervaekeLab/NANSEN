classdef Control < uim.abstract.Component
    
    % Add showTooltip and hideTooltip should be methods of this class?
    
    
    properties
        
        Callback = []
        
        Label = '' % Todo: Create label class
        
        %HorizontalAlignment
        %VerticalAlignment
        
        Tooltip = ''
        ContextMenu = []
    end
    
    properties (Hidden)
        TooltipYOffset = 15;
    end
    
    properties (Hidden, Access = protected, Transient)
        TooltipPosition = [0, 0]
        
        IsMousePressed = false
        IsMouseOver = false
        
        MouseReleasedListener
        
    end
    
    
    methods
        function obj = Control(varargin)
            obj@uim.abstract.Component( varargin{:} )
        end
        
        function delete(obj)
            
            % Reset pointerbehavior
            if isvalid(obj.hBackground)
                iptSetPointerBehavior(obj.hBackground, [])
            end
            
            if ~isempty(obj.MouseReleasedListener)
                delete(obj.MouseReleasedListener)
            end
        end
        
    end
    
    methods
        function set.Tooltip(obj, newValue)
            
            assert(ischar(newValue), 'Tooltip must be a character vector')
            
            obj.Tooltip = newValue;
            obj.onTooltipChanged()
        end
        
    end
    
    methods
        
        function relocate(obj, shift)
            relocate@uim.abstract.Component(obj, shift)
            obj.setTooltipPosition()
        end
        
    end
    
    methods (Hidden, Access = private)
        
        function setPointerBehavior(obj)
        %setPointerBehavior Set pointer behavior of background.

            pointerBehavior.enterFcn    = @obj.onMouseEntered;
            pointerBehavior.exitFcn     = @obj.onMouseExited;
            pointerBehavior.traverseFcn = [];%@obj.moving;
            
            try % Use try/catch because this reqiures image processing toolbox.
                iptPointerManager(ancestor(obj.hBackground, 'figure'));
                iptSetPointerBehavior(obj.hBackground, pointerBehavior);
            catch
                disp('failed to set pointerbehavior')
            end
        end

        function showTooltip(obj)
            %Todo: Should always be the figures main canvas?
            obj.Canvas.showTooltip(obj.Tooltip, obj.TooltipPosition)
            
        end
        
        function hideTooltip(obj)
            obj.Canvas.hideTooltip()
        end
        
        function onTooltipChanged(obj)
            
            if obj.IsMouseOver && ~isempty(obj.Tooltip) 
                obj.showTooltip()
            end
            
        end
    end
        
        
    methods (Hidden, Access = protected)
        
        function setTooltipPosition(obj)
        %setTooltipPosition Set position of tooltip on the canvas axes.
            
            if isempty(obj.Tooltip); return; end
            
            centerX = mean(obj.hBackground.XData);
            centerY = mean(obj.hBackground.YData);

            obj.TooltipPosition = [centerX, centerY - 0.5*obj.Size(2)-obj.TooltipYOffset];
        end
        
        function changeAppearance(obj)
        end
        
        function onMouseEntered(obj, hSource, eventData)
            
            if ~isvalid(obj); return; end
            
            obj.IsMouseOver = true;
            obj.changeAppearance()
            
            hFig = ancestor(obj.hBackground, 'figure');
            hFig.Pointer = 'hand';
            
            if ~isempty(obj.Tooltip)
                obj.showTooltip()
            end
        end

        function onMouseExited(obj, hSource, eventData)
            
            % Need this here in case the obj was deleted while the pointer
            % was still on it.
            if ~isvalid(obj); return; end
            
            obj.IsMouseOver = false;
           
            obj.changeAppearance()
            
            hFig = ancestor(obj.hBackground, 'figure');
            hFig.Pointer = 'arrow';
            
            if ~isempty(obj.Tooltip)
                obj.hideTooltip()
            end
        end
        
        function onMousePressed(obj, ~, event)
        %onButtonPressed Event handler for mouse press on button
            
            obj.IsMousePressed = true;
            
            if isempty(obj.MouseReleasedListener)
                hFig = ancestor(obj.hBackground, 'figure');
                el = addlistener(hFig, 'WindowMouseRelease', @obj.onMouseReleased);
                obj.MouseReleasedListener = el;
            end
            
            obj.changeAppearance()
            
        end
        
        function onMouseReleased(obj, src, event)
        % Event handler for mouse release from button
        
            obj.IsMousePressed = false;
            
            delete(obj.MouseReleasedListener)
            obj.MouseReleasedListener = [];
            
            obj.changeAppearance()

        end
        
        function onConstructed(obj)
            
            if obj.IsConstructed
                onConstructed@uim.abstract.Component(obj)
                obj.setPointerBehavior()
                obj.setTooltipPosition()
            end
    end
    
    end

%     methods (Access = protected)
%        function onStyleChanged(obj)
%        end
%     end
end