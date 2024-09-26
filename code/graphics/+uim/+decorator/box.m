classdef box < uim.abstract.virtualContainer & uim.mixin.assignProperties
    
    methods % Structors
                    
        function obj = box(hParent, varargin)

            %obj@uim.abstract.virtualContainer(hParent)

            el = listener(hParent, 'SizeChanged', ...
                @obj.onParentContainerSizeChanged);
            obj.ParentContainerSizeChangedListener = el;
            
            obj.Parent = hParent;
            obj.Canvas = hParent;
            obj.hAxes = obj.Canvas.Axes;
            
            obj.parseInputs(varargin{:})

            obj.createBackground()

            obj.IsConstructed = true;
            
            % Todo: This is not perfect. Sometimes size depends on
            % location...
            
            % Check if position was set different than default. if so, mode is manual
            
            % Call updateSize to trigger size update (call before location)
            obj.updateSize('auto')
            
            % Call updateLocation to trigger location update
            obj.updateLocation('auto')
            
            obj.onStyleChanged()

        end
        
        function updateSize(obj, mode)
            if nargin < 2; mode = obj.PositionMode; end
            updateSize@uim.abstract.virtualContainer(obj, mode)
            obj.resize()
        end
    end
end
