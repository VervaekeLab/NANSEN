classdef WidgetContainer < uim.abstract.virtualContainer
    
    % Questions:
    %   IS this just the same as container?
    %   What (if any) are the differences between a container and a widget?
    %
    %   Should canvasMode and canvasPosition just be properties of
    %   Container class?
    
    % The Container class extands the Component class providing functionality
    % for adding children. For better performance in guis that are resizeable,
    % the container class can be created in its own canvas.
    
    % Todo: Extend canvas class to create a canvas for individual
    % containers.
    
    properties
        CanvasMode = 'integrated' % vs 'separate' 'common', 'shared', 'main', 'private'
    end
    
    properties (Access=protected, Dependent, Transient)
        CanvasPosition % Position in Canvas
    end
    
    methods
        
        function obj = WidgetContainer(hParent, varargin)
            
            % Assign listener for size changes on parent
            el = listener(hParent, 'SizeChanged', ...
                @obj.onParentContainerSizeChanged);
            obj.ParentContainerSizeChangedListener = el;
            
            obj.Parent = hParent;
            
            if contains('CanvasMode', varargin(1:2:end))
                ind = find(contains(varargin(1:2:end), 'CanvasMode'));
                obj.CanvasMode = varargin{ind*2};
            end
            
            switch obj.CanvasMode
                case 'integrated'
                    obj.Canvas = hParent;
                    obj.hAxes = obj.Canvas.Axes;
                case 'separate'
                    obj.createAxes()
                    obj.Canvas = obj.hAxes;
            end
        end
        
        function createAxes(obj)
            
            matlabVersion = version('-release');
            doDisableToolbar = str2double(matlabVersion(1:4))>2018 || ...
                                       strcmp(matlabVersion, '2018b');

            if doDisableToolbar
                args = {'Toolbar', []};
            else
                args = {};
            end
            
            % Create an axes which will be the container for this widget.
            obj.hAxes = axes('Parent', obj.Parent, args{:});
            hold(obj.hAxes, 'on');
            
            set(obj.hAxes, 'XTick', [], 'YTick', [])
            obj.hAxes.Visible = 'off';
            obj.hAxes.Units = 'pixel';
            obj.hAxes.HandleVisibility = 'off';
            obj.hAxes.Tag = 'Widget Container';
            
            axis(obj.hAxes, 'equal')

            if ~any(isnan(obj.Position))
                obj.hAxes.Position = obj.Position;
                obj.hAxes.YLim = [1,obj.Position(4)];
                obj.hAxes.XLim = [1,obj.Position(3)];
            end
            
            if doDisableToolbar
                disableDefaultInteractivity(obj.hAxes)
            end
        end
        
        function resize(obj)
        	obj.updateBackgroundSize()
            %obj.updateBorderSize()
        end
        
        function pos = get.CanvasPosition(obj)
            
            switch obj.CanvasMode
                case 'integrated'
                    pos = obj.Position;
                case 'separate'
                    pos = [1,1,obj.Position(3:4)];
            end
        end
        
%         function onParentContainerSizeChanged(obj, src, evt)
%
%
%         end
        
    end
        
    methods (Access = protected)
        
        function updateBackgroundSize(obj)
            
            if ~isempty(obj.hBackground) && obj.IsConstructed
                
                [X, Y] = obj.createBoxCoordinates(obj.Size, obj.CornerRadius);
                
                if strcmp(obj.CanvasMode, 'integrated')
                    X = X+obj.Position(1);
                    Y = Y+obj.Position(2);
                end
                
                set(obj.hBackground, 'XData', X, 'YData', Y)
            
            end
            
            %drawnow limitrate
            
        end
        
%         function onSizeChanged(obj, oldPosition, newPosition)
%             if ~obj.IsConstructed; return; end
%             obj.resize()
%             evtData = uim.event.SizeChangedData(oldPosition(3:4), newPosition(3:4));
%             obj.notify('SizeChanged', evtData)
%         end
        
        function onSizeChanged(obj, oldPosition, newPosition)
            if ~obj.IsConstructed; return; end
            
            switch obj.CanvasMode
                case 'integrated'
                    obj.resize()
                    evtData = uim.event.SizeChangedData(oldPosition(3:4), newPosition(3:4));
                    obj.notify('SizeChanged', evtData)
                case 'separate'
                    obj.hAxes.Position = newPosition;
                    obj.hAxes.XLim = [1, newPosition(3)];
                    obj.hAxes.YLim = [2, newPosition(4)];
                    obj.resize()
            end
        end
        
        function onLocationChanged(obj, oldPosition, newPosition)
            if ~obj.IsConstructed; return; end
        
            switch obj.CanvasMode
                case 'integrated'
                    obj.relocate(newPosition-oldPosition)
                    evtData = uim.event.LocationChangedData(oldPosition(1:2), newPosition(1:2));
                    obj.notify('LocationChanged', evtData)
                case 'separate'
                    setpixelposition(obj.hAxes, newPosition)
                    %obj.hAxes.Position = newPosition;
                    
            end
        end
    end
end
