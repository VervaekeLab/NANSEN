classdef virtualContainer < uim.handle & matlab.mixin.Heterogeneous
%virtualContainer Create a virtual container for placing within an 
% uicomponent canvas. This class provides basic positioning and style methods.

% Should rename. This is not virtual anymore...
%
% Todo: [ ] Make this into a component super class.
%       [ ] Remove Children property, and add that to a container subclass.
%       [ ] Inherit structadapter
%       [ ] Implement abstract method getComponentDefaults
%       [ ] Simplify positioning. 
%       [ ] Add anchoring position mode.
% 


% % % % % % % Parent Container  % % % % % % % % % % % %    
%                                                     %
%    Margin Area                                      %
%                                                     %
%    x------------------x-------------------x Border  %
%    |  Padded Area    Top                  |         %
%    |        _ _ _ _ _ _ _ _ _ _ _         |         %      y ^
%    |       | \ \ \ \ \ \ \ \ \ \ |        |         %        |
%    x Left  | \ \ \ Content \ \ \ | Right  x         %        |
%    |       |_\_\_\_\_\_\_\_\_\_\_|        |         %        |
%    |                                      |         %        o-----> x
%    |               Bottom                 |         %
%    x------------------x-------------------x         %
%                                                     %
%                                                     %
% % % % % % % % % % % % % % % % % % % % % % % % % % % %   

%  x = Anchor points ( Horizontal/Vertical Alignment )


    % Todo: 
    %   Add a sizeChangedFcn prop? Like matlab containers have?
    %   Add/implement units property?
    %
    %   Split into component and container.
    
    % Todo: rename onSizeChanged & onLocationChanged to updateSize &
    % updateLocation. onSizeChanged should be called after the position is
    % set...
    
    
    properties (Constant)
        
    end
    
    
    properties (Transient) %Todo, this should not be transient. Actually, why not...
        Canvas = [] % Rename to virtualParent?
        Parent = [] % Rename / make sure this is a matlab graphical container
        Children = [] % Container property... ( Components does not have children)
    end
    
%     properties (Abstract)
%         Type
%     end
%     Todo: Add a abstract static method called getTypeDefaults?
%       This would be a method that when implemented returns default values
%       for a specific type. Alternative to make all properties abstract,
%       and give option for having different default values of subclass
%       properties.
    
    properties (Dependent)
        Position (1,4) double = [1,1,10,10]                      % Dependent?
    end
    
    
    properties % Position properties
        
        %CanvasMode = 'integrated' % vs 'separate'
        
        PositionMode = 'auto' % Dependent Rename to location mode? Should it be protected?
        SizeMode = 'auto'
        
        Margin (1,4) double = [0,0,0,0]           % In pixel (left, bottom, right, top)
        Padding (1,4) double = [0,0,0,0]           % In pixel (left, bottom, right, top)

        Location = 'southwest'
        HorizontalAlignment = 'left'
        VerticalAlignment = 'bottom'
        
        IsFixedSize (1,2) logical = [false, false]     % True/false (x, y) Is size fixed?
        
        MinimumSize = [10,10]
        MaximumSize = [inf, inf]
    end
    
    properties (Dependent)
        Size (1,2) double = [0, 0]
    end
    
    properties (Access = private, Transient) % Internal properties
        Position_ (1,4) double = [1,1,10,10]  % Internally used position
        %AutoPosition (1,4) double = [nan, nan, nan, nan]  % Internally used position
    end
    
    properties % Style
        BackgroundColor = 'none'
        ForegroundColor = 'w'
        BackgroundAlpha = 0.3
        BorderColor = 'none'
        BorderWidth = 0.5
        CornerRadius = 0
        Visible = 'on'
        Tag = ''
    end
    
    properties (Access = protected, Transient)
        ParentContainerSizeChangedListener event.listener
        ParentContainerLocationChangedListener event.listener
        IsConstructed = false
        hAxes
        hBackground
        hBorder
    end
    
    events
        SizeChanged
        LocationChanged
        StyleChanged
    end
    
    methods % Structors
        
        % todo :modify this so it works for button, and other controls that
        % might be parented in another virtualContainer...
% %         function obj = virtualContainer(hParent)
% %             
% %             if isa(hParent, 'uim.abstract.virtualContainer')
% %                 obj.Parent = hParent.getGraphicsContainer()
% %             end
% %
% %             el = listener(hParent, 'SizeChanged', ...
% %                 @obj.onParentContainerSizeChanged);
% %             obj.ParentContainerSizeChangedListener = el;
% %             
% %             %Todo: add listener. If uicc is deleted, delete this class as
% %             % well. 
% % 
% %             obj.Parent = hParent;
% %             obj.Canvas = hParent;
% %             obj.hAxes = obj.Canvas.Axes;
% %             
% %         end
        
        
        function delete(obj)
            
            if ~isempty(obj.hBackground)
                delete(obj.hBackground)
            end
            
            if ~isempty(obj.hBorder)
                delete(obj.hBorder)
            end
            
        end
        
    end
    
    methods (Access = protected) % Creation
        
        function assignComponentCanvas(obj)
            
            obj.Canvas = getappdata(obj.Parent, 'UIComponentCanvas');
            
            if isempty(obj.Canvas)
                obj.Canvas = uim.UIComponentCanvas(obj.Parent, 'GlassMode', 'off');
                setappdata(obj.Parent, 'UIComponentCanvas', obj.Canvas);
            end
            
            obj.hAxes = obj.Canvas.Axes;

        end
        
        function createBackground(obj) % Subclasses can override
        %createBackground Plot the container background
        
            if isa(obj.Canvas, 'uim.UIComponentCanvas')
                obj.hBackground = patch(obj.Canvas.Axes, nan, nan, 'w');
            elseif isa(obj.Canvas, 'matlab.graphics.axis.Axes')
                obj.hBackground = patch(obj.Canvas, nan, nan, 'w');
            end
            
            obj.hBackground.EdgeColor = 'none';
            obj.hBackground.FaceAlpha = 0;
            obj.hBackground.HitTest = 'off';
            obj.hBackground.PickableParts = 'none';

        end
        
        function createBorder(obj) % Subclasses can override
        %createBorder Plot the container border    
 
        end
        
    end
    
    methods % Set/Get 

% %         function set.IsConstructed(obj, newValue)
% %             
% %             assert(islogical(newValue))
% %             obj.IsConstructed = newValue;
% %             
% %             if obj.IsConstructed
% %             
% %                 % Call updateSize to trigger size update (call before location)
% %                 obj.updateSize('auto')
% % 
% %                 % Call updateLocation to trigger location update
% %                 obj.updateLocation('auto') 
% %                 
% %             end
% %         end

        % Todo: Consider if this is necessary...
        function set.Size(obj, newValue)
            % Todo: check with minimum size
            obj.Position_(3:4) = newValue;
        end
        
        function size = get.Size(obj)
            size = obj.Position_(3:4);
        end
        
        function set.Position(obj, newPosition)
            obj.switchPositionMode('manual')
            obj.Position_ = newPosition;
        end
        
        function position = get.Position(obj)
            position = obj.Position_;
        end
        
        function set.Position_(obj, newPosition)
            
            oldPosition = obj.Position_;

            % Check if it was size and/or location that changed.
            isSizeChanged = any(newPosition(3:4) ~= obj.Position_(3:4));
            isLocationChanged = any(newPosition(1:2) ~= obj.Position_(1:2));
            
            % Todo: compare with min and max allowed size
            
            obj.Position_= newPosition;
            
            % if isSizeChanged && isLocationChanged
            %   obj.onPositionChanged
            % elseif isSizeChanged
            %   obj.onSizeChanged
            % elseif isLocationChanged
            %   obj.onLocationChanged
            % end
            
            
            % Update size first
            if isSizeChanged
                obj.onSizeChanged(oldPosition, newPosition)
% %                 obj.resize()
% %                 evtData = uim.event.SizeChangedData(oldPosition(3:4), newPosition(3:4));
% %                 obj.notify('SizeChanged', evtData)
            end
            
            % Update location second
            if isLocationChanged
                obj.onLocationChanged(oldPosition, newPosition)
            end
        end
            
        function set.Location(obj, newValue)
            obj.Location = newValue;
            %obj.switchPositionMode('auto')
            obj.updateLocation('auto')
        end
        
        function set.Margin(obj, newValue)
            obj.Margin = newValue;
            obj.updateSize()
            obj.updateLocation('auto')
        end

        function set.HorizontalAlignment(obj, newValue)
            obj.HorizontalAlignment = newValue;
            obj.updateLocation('auto')
        end
        
        function set.VerticalAlignment(obj, newValue)
            obj.VerticalAlignment = newValue;
            obj.updateLocation('auto')
        end

        function set.Padding(obj, newValue)
            obj.Padding = newValue;
            obj.redraw() % todo...
        end
        
        function set.BackgroundColor(obj, newValue)
            obj.BackgroundColor = newValue;
            obj.onStyleChanged()
        end
        
        function set.ForegroundColor(obj, newValue)
            obj.ForegroundColor = newValue;
            obj.onStyleChanged()
        end
        
        function set.BackgroundAlpha(obj, newValue)
            obj.BackgroundAlpha = newValue;
            obj.onStyleChanged()
        end
        
        function set.BorderColor(obj, newValue)
            obj.BorderColor = newValue;
            obj.onStyleChanged()
        end
        
        function set.CornerRadius(obj, newValue)
            obj.CornerRadius = newValue;
            obj.onShapeChanged()
        end
        
        function set.Visible(obj, newValue)
            assert(strcmp(newValue, 'on') || strcmp(newValue, 'off'), ...
                'uim:InvalidPropertyValue', ...
                'Visible property can be set to ''on'' or ''off'' ')
            
            if ~isequal(obj.Visible, newValue)
                obj.Visible = newValue;
                obj.onVisibleChanged(newValue)
            end
            
        end
    end
    
    methods % Update position / size / appearance
        
        function redraw(obj)
            
        end
        
        function resize(obj)
        	obj.updateBackgroundSize()
            obj.updateBorderSize()
        end
        
        function relocate(obj, shift)
            obj.shiftBackground(shift)
        end
        
        function updateSize(obj, mode)
        %updateSize Handler of conditions that adjust container size  
        %
        %   Calculate new size based on size of parent container and
        %   internal properties (margins) that determine the size.
        
            if ~obj.IsConstructed; return; end
            
            if nargin == 2; obj.switchPositionMode(mode); end
            if strcmp(obj.SizeMode, 'manual'); return; end
            
            if isa(obj.Parent, 'uim.UIComponentCanvas')
                parentSize = obj.Parent.Size;
            elseif isa(obj.Parent, 'uim.abstract.virtualContainer')
                parentSize = obj.Parent.Position(3:4);
            elseif isa(obj.Parent, 'matlab.graphics.Graphics')
                parentPosition = getpixelposition(obj.Parent);
                parentSize = parentPosition(3:4);
            elseif isa(obj.Parent, 'matlab.graphics.axis.Axes')
                parentSize = obj.Parent.Position(3:4);
            elseif isa(obj.Parent, 'matlab.ui.Figure')
                parentSize = obj.Parent.Position(3:4);
            else
                parentSize = obj.Parent.Position(3:4);
            end
            
            % Initialize newSize based on current size
            newSize = obj.Size;
            
            % Then recalculate based on parent size and margins.
            if ~obj.IsFixedSize(1)
                newSize(1) = parentSize(1) - sum(obj.Margin([1,3]));
            end
            
            if ~obj.IsFixedSize(2)
                newSize(2) = parentSize(2) - sum(obj.Margin([2,4]));
            end
            
            % Todo: Consider minimum and maximum size
            
            obj.Position_(3:4) = newSize;
            
        end
        
        function updateLocation(obj, mode)
        %updateLocation Handler of conditions that change container location 
                    
            if ~obj.IsConstructed; return; end
            
            if nargin == 2
                obj.PositionMode = mode;
            end
                        
            switch obj.PositionMode
                case 'auto'
                    obj.setAutoLocation()
                case 'manual'
                    % Location should stay the same.
            end
                        
        end
        
        
        function onStyleChanged(obj)
            if obj.IsConstructed
                obj.hBackground.FaceColor = obj.BackgroundColor;
                obj.hBackground.FaceAlpha = obj.BackgroundAlpha;
            end
        end
        
        function onShapeChanged(obj)
            % todo: create an updateBackground method in addition to
            % updateSize
            try
                obj.updateBackground()
            catch
                obj.updateBackgroundSize()
            end
        end
        
    end
    
    methods (Access = private) % Internal Updates
        
        function setAutoLocation(obj)
            if ~obj.IsConstructed; return; end
            
            if isa(obj.Parent, 'uim.UIComponentCanvas')
                parentSize = obj.Parent.Size;
                locationPoint = obj.Parent.getLocationPoint(obj.Location);
            elseif isa(obj.Parent, 'matlab.graphics.axis.Axes') || isa(obj.Parent, 'matlab.ui.Figure') || isa(obj.Parent, 'matlab.ui.container.Panel')
                parentPos = getpixelposition(obj.Parent);
                parentSize = parentPos(3:4);
                locationPoint = obj.location2point(parentSize, obj.Location);
            else
                locationPoint = [1,1];
            end

            
            newLocation = locationPoint;
            
            if contains(obj.Location, 'west')
                newLocation(1) = locationPoint(1) + obj.Margin(1);
            elseif contains(obj.Location, 'east')
                newLocation(1) = locationPoint(1) - obj.Size(1) - obj.Margin(3);                
            end

            if contains(obj.Location, 'south')
                newLocation(2) = locationPoint(2) + obj.Margin(2);
            elseif contains(obj.Location, 'north')
                newLocation(2) = locationPoint(2) - obj.Size(2) - obj.Margin(4);
            end

            % Centered along horizontal dimension
            if strcmp(obj.Location, 'south') || strcmp(obj.Location, 'south')
                newLocation(1) = (parentSize(1)-obj.Size(1)) / 2;
            end

            % Centered along vertical dimension
            if strcmp(obj.Location, 'east') || strcmp(obj.Location, 'west')
                newLocation(2) = (parentSize(2)-obj.Size(2)) / 2;
            end

            switch obj.HorizontalAlignment
                case 'left'
                    % Do nothing
                case 'center'
                    newLocation(1) = newLocation(1) - obj.Size(1)/2;
                case 'right'
                    newLocation(1) = newLocation(1) - obj.Size(1);
            end

            switch obj.VerticalAlignment
                case 'bottom'
                    % Do nothing
                case 'middle'
                    newLocation(2) = newLocation(2) - obj.Size(2)/2;
                case 'top'
                    newLocation(2) = newLocation(2) - obj.Size(2);
            end
            
            obj.Position_(1:2) = newLocation;
        end
        
        function switchPositionMode(obj, newMode)
        %switchPositionMode Update position mode
        
            obj.PositionMode = newMode;
        end

        function updateBackgroundSize(obj)
            
            if ~isempty(obj.hBackground) && obj.IsConstructed
                
                [X, Y] = obj.createBoxCoordinates(obj.Size, obj.CornerRadius);
                X = X+obj.Position_(1);
                Y = Y+obj.Position_(2);

                set(obj.hBackground, 'XData', X, 'YData', Y)
            
            end
            
            %drawnow limitrate
            
        end
        
        function updateBorderSize(obj)
            % Should this be done together with updateBackgroundSize
        end
        
        function shiftBackground(obj, shift)
            if ~isempty(obj.hBackground) && obj.IsConstructed
                if shift(1) ~= 0
                    obj.hBackground.XData = obj.hBackground.XData + shift(1);
                end
                if shift(2) ~= 0
                    obj.hBackground.YData = obj.hBackground.YData + shift(2);
                end
            end
            %drawnow limitrate
        end
        
    end
    
    methods (Access = protected)
        function updateBackground(obj)
        end
        
        function onSizeChanged(obj, oldPosition, newPosition)
            if ~obj.IsConstructed; return; end
            obj.resize()
            evtData = uim.event.SizeChangedData(oldPosition(3:4), newPosition(3:4));
            obj.notify('SizeChanged', evtData)
        end
        
        function onLocationChanged(obj, oldPosition, newPosition)
            if ~obj.IsConstructed; return; end
            obj.relocate(newPosition-oldPosition)
            evtData = uim.event.LocationChangedData(oldPosition(1:2), newPosition(1:2));
            obj.notify('LocationChanged', evtData)
        end
        
    end
    
    methods % Callbacks for listeners on parent container
        
        function onParentContainerSizeChanged(obj, src, evt)
            persistent i
            if isempty(i); i = 0; end
            obj.updateSize()
            obj.updateLocation()
            %obj.notify('SizeChanged', evt)
            i = i+1;
            
            if mod(i, 2000)==0
                fprintf('\n\n %%%%%% \n FINISH \n\n %%%%%%\n')
            end
            
        end
        
        
        function onParentContainerLocationChanged(obj, src, evt)
            shift = evt.NewLocation - evt.oldLocation;
            obj.Position_(1:2) = obj.Position_(1:2) + shift;
        end
        
    end
    
    methods % Wrappers for placing matlab components
        
        function hContainer = getGraphicsContainer(obj)
            hContainer = obj.Parent;
        end
        
        function pos = getpixelposition(obj)
            hContainer = obj.getGraphicsContainer();
            pos = getpixelposition(hContainer);
        end
        
        function h = uicontrol(obj, varargin)
            hContainer = obj.getGraphicsContainer();
            h = uicontrol(hContainer, varargin{:});
        end
        
        function h = uitable(obj, varargin)
            hContainer = obj.getGraphicsContainer();
            h = uitable(hContainer, varargin{:});
        end
        
        function h = axes(obj, varargin)
            hContainer = obj.getGraphicsContainer();
            h = axes(hContainer, varargin{:});
        end
    
    end
    
    methods (Static)
        
        function locationPoint = location2point(containerSize, locationKey)
            % todo: merge with getLocationPoint method. Should this be a
            % methods of this class or virtual container or hust a
            % utilities function?
            
            
            locationPoint = [1,1]; % Southwest
            
            if contains(locationKey, 'north')
                locationPoint(2) = containerSize(2);
            end
            
            if contains(locationKey, 'east')
                locationPoint(1) = containerSize(1);

            end
            
            % Center along x-dimension
            if strcmp(locationKey, 'south') || strcmp(locationKey, 'north')
                locationPoint(1) = containerSize(1)/2;
            end
            
            % Center along y-dimension
            if strcmp(locationKey, 'west') || strcmp(locationKey, 'east')
                locationPoint(2) = containerSize(2)/2;
            end
            
            if strcmp(locationKey, 'center')
                locationPoint = containerSize/2;
            end
            
            locationPoint = round( locationPoint );

        end
        
        function varargout = createBoxCoordinates(boxSize, cornerRadius)
        %utilities.createBoxCoordinates Create edgecoordinates for a box
        % 
        %   [edgeCoordinates] = utilities.createBoxCoordinates(boxSize) creates 
        %   edgeCoordinates for a box of size boxSize ([width, height]). This function 
        %   creates edgeCoordinates for each unit length of width and height.
        %   edgeCoordinates is a nx2 vector of x and y coordinates where 
        %   n = 2 x (height+1) + 2 x (width+1)
        %
        %   [xCoords, yCoords] = createBox(boxSize) returns xCoords and yCoords are
        %   separate vectors.
        %
        %   [xCoords, yCoords] = createBox(boxSize, Name, Value) creates the
        %   coordinates and specifies specifies additional parameters for
        %   customizing the coordinates / box appearance.
        %
        %   Name, Value parameters:
        %       nPointsCurvature   : number of corner points to make curved.
        %   
        %
        % Coordinates starts in the upper left corner and traverses the box ccw
        %
        %        <--
        %  ul _ _ _ _ _          y ^
        %    |         | ^         |
        %  | |         | |         |
        %  v |_ _ _ _ _|            -------> x
        %        -->               0

        %   Written by Eivind Hennestad | Vervaeke Lab

        if nargin < 2; cornerRadius = 5; end
        
        [boxXs, boxYs] = uim.shape.rectangle(boxSize, cornerRadius);

        if nargout == 1
            varargout = {[boxXs', boxYs']};
        elseif nargout == 2
            varargout = {boxXs, boxYs};
        end
        
        return
        
        
        % More intuitive code, but not symmetric 
        % % % [xx, yy] = meshgrid(0:pixelSize(1), 0:pixelSize(2));
        % % % k = boundary(xx(:), yy(:));
        % % % 
        % % % boxX = flipud( xx(k) );
        % % % boxY = flipud( yy(k) );

        boxSize = round(boxSize);

        if cornerRadius == 0
            boxX = [0, 0, boxSize(1), boxSize(1)];
            boxY = [boxSize(2), 0, 0, boxSize(2)];
            
        else
            boxX = cat(2, zeros(1, boxSize(2)+1), ...
                          0:boxSize(1), ...
                          ones(1, boxSize(2)+1) * boxSize(1), ...
                          boxSize(1):-1:0 );

            boxY = cat(2, boxSize(2):-1:0, ...
                          zeros(1, boxSize(1)+1), ...
                          0:boxSize(2), ...
                          ones(1, boxSize(1)+1) * boxSize(2) );
        end
        if ~cornerRadius==0      
            boxXs = utility.circularsmooth(boxX, round( cornerRadius*2) );
            boxYs = utility.circularsmooth(boxY, round( cornerRadius*2) );
        else
            boxXs = boxX;
            boxYs = boxY;
        end
        
        if ~cornerRadius == 0
            indX = boxXs==0 | boxXs == boxSize(1);
            indY = boxXs==0 | boxXs == boxSize(2);
            boxXs(indX|indY)=[];
            boxYs(indX|indY)=[];

            boxXs = boxXs(1:2:end);
            boxYs = boxYs(1:2:end);
        end
        
        if nargout == 1
            varargout = {[boxXs', boxYs']};
        elseif nargout == 2
            varargout = {boxXs, boxYs};
        end
        
        
        end


    end
        
    
    
end