classdef panel < uim.abstract.virtualContainer & uim.mixin.assignProperties
    
    properties 
        hPanel = []
    end
    
    methods % Structors
                    
        function obj = panel(hParent, varargin)

            %obj@uim.abstract.virtualContainer(hParent)

            el = listener(hParent, 'SizeChanged', ...
                @obj.onParentContainerSizeChanged);
            obj.ParentContainerSizeChangedListener = el;
            
            obj.Parent = hParent;
            obj.Canvas = hParent;

            
            obj.parseInputs(varargin{:})

            obj.hPanel = uipanel(obj.Parent);
            obj.hPanel.BorderType = 'none';
            obj.hPanel.Units = 'pixel';
            
            obj.IsConstructed = true;
            

            % Todo: This is not perfect. Sometimes size depends on
            % location...
            
            % Check if position was set different than default. if so, mode is manual
            
            % Call onSizeChanged to trigger size update (call before location)
            obj.updateSize('auto')
            
            % Call updateLocation to trigger location update
            obj.updateLocation('auto')
            
            obj.onStyleChanged()

        end
        
        function delete(obj)
            
        end
        
    end
    
    methods
        
        function updateSize(obj, mode)
            if nargin < 2; mode = obj.PositionMode; end
            
            updateSize@uim.abstract.virtualContainer(obj, mode)
            obj.hPanel.Position = obj.Position;
        end
        
        function updateLocation(obj, mode)
            if nargin < 2; mode = obj.PositionMode; end
            
            updateLocation@uim.abstract.virtualContainer(obj, mode)
            obj.hPanel.Position = obj.Position;
        end
        
        function onStyleChanged(obj)
            if obj.IsConstructed
                obj.hPanel.BackgroundColor = obj.BackgroundColor;
            end
        end
    
        function onVisibleChanged(obj, newValue)
            obj.hPanel.Visible = newValue;
        end
    end
    
    methods
        function hContainer = getGraphicsContainer(obj)
            hContainer = obj.hPanel;
        end
    end
    
end
