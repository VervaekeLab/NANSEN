classdef Component < uim.handle & matlab.mixin.Heterogeneous & uim.mixin.assignProperties
%uim.Component Abstract class for ui components to place in a uim.Canvas
% This class provides basic positioning (layout) and style methods.
%
%   The component class provides a mix of functionality for positioning a
%   component and for giving it a background and border appeareance, i.e
%   layout and style. In the ideal world, these would be separate classes.
%
%   The layout of a component is a bit more advanced than the standard
%   matlab Position property.
%       1. A component can be placed relative to a location in the parent
%          container. The margin is used to offset the component from
%          this location.
%       2. A component can have a floating size in one or both dimensions. 
%          I.e it will stretch to fill up available space.
% 
%   Illustration showing layout of a component:
%
% % % % % % % Parent Container  % % % % % % % % % % % %
% o                     o                           o %
%    Margin Area                                      %
%                                                     %
%    x------------------x-------------------x Border  %
%    |  Padded Area    Top                  |         %
%    |        _ _ _ _ _ _ _ _ _ _ _         |         %      y ^
%    |       | \ \ \ \ \ \ \ \ \ \ |        |         %        |
% o  x Left  | \ \ \ Content \ \ \ | Right  x       o %        |
%    |       |_\_\_\_\_\_\_\_\_\_\_|        |         %        |
%    |                                      |         %        o-----> x
%    |               Bottom                 |         %
%    x------------------x-------------------x         %
%                                                     %
% o                     o                           o %
% % % % % % % % % % % % % % % % % % % % % % % % % % % %
%
%  x = Anchor points ( Horizontal/Vertical Alignment )
%  o = Location (south, east, north, west)
%
%
% Two subclasses are implemented, Control and Container. The Control is
% always drawn in the parent's (shared) canvas while a container can create
% its own private canvas. See Container for details.
%
%
%   ABSTRACT PROPERTIES:
%       Type (Constant) : A name to describe the component type 
%
%   ABSTRACT METHODS:


% Questions:
%       [ ] Should there be an allowed subclasses attribute? I.e Control and
%           Container would be allowed subclasses?
%       [ ] Should PositionMode and SizeMode be protected properties
%       [ ] Should PositionMode be renamed to LocationMode

% Todo:
%       [ ] Simplify positioning. ie remove size and use position(3:4)?         (Not sure if this is needed).
%       [x] Remove hAxes property and replace with CanvasAxes
%       [ ] Implement a set.Parent method
%       [ ] Implement a set.IsFixedSize method
%       [ ] Implement a getpixelposition method.
%       [ ] Implement a set methods for PositionMode, SizeMode
%       [ ] Implement a set methods for MinimumSize, MaximumSize
%       [ ] Make a component style... which is basically all the
%           backgroundstyles...


    properties (Abstract, Constant)
        Type % Should rename to name????
    end
    
    properties (Transient) % Todo, this should not be transient. Actually, why not...
        Canvas = [] % Rename to virtualParent? Hide?
        Parent = [] % Rename / make sure this is a matlab graphical container
    end
    
    properties (Dependent)
        Position (1,4) double = [1,1,10,10]     % Dependent?
    end
    
    properties (Dependent) % SetAccess = private?
        Size (1,2) double = [0, 0] % necessary??
        %CanvasAxes
    end
    
    properties % Position properties

        PositionMode = 'auto'        % Calculate position based on layout or use the values of the Position property.
        SizeMode = 'auto'            % Calculate size based on layout or used the values of the Position property.
        
        Margin (1,4) double = [0,0,0,0]           % In pixels (left, bottom, right, top)
        Padding (1,4) double = [0,0,0,0]          % In pixels (left, bottom, right, top)

        Location = 'southwest'       % Location of component in the parent container. See layout description above.
        
        % Anchor points....
        HorizontalAlignment = 'left' % Horizontal reference point (anchor point) in the parent container. See layout description above.
        VerticalAlignment = 'bottom' % Vertical reference point (anchor point) in the parent container. See layout description above.
        
        IsFixedSize (1,2) logical = [false, false]     % True/false (x, y) Is size fixed?
        
        MinimumSize = [10, 10]
        MaximumSize = [inf, inf]
    end
    
    properties % Style properties
        BackgroundColor = 'none'
        ForegroundColor = 'w'
        BackgroundAlpha = 0.3
        BorderColor = 'none'
        BorderWidth = 0.5
        CornerRadius = 0
    end
    
    properties % Graphics objects properties
        Visible = 'on'
        Tag = ''
        UserData = []
    end
    
    properties (SetAccess = protected)
        CanvasMode = 'shared' % vs 'private' % Should be container property.
    end
    
    properties (Access = protected, Dependent, Transient)
        CanvasPosition % Position in Canvas
    end
    
    properties (Access = protected, Transient) % Internal properties
        Position_ (1,4) double = [1,1,80,20]  % Internally used position
    end
    
    properties (Access = protected, Dependent, Transient) % SetAccess = private?
        CanvasAxes
    end
    
    properties (Hidden, Access = protected, Transient)
        ParentContainerSizeChangedListener event.listener
        ParentContainerLocationChangedListener event.listener
        ParentContainerDestroyedListener event.listener
        IsConstructed = false
        IsDrawCompleted = false
        hAxes  % Make this dependent property?
        hBackground
        hBorder
    end
    
    properties (Hidden, Access = private, Transient)
        IsConstructed_ = false % Constructed flag internal to the component superclass
    end
    
    
    events
        LocationChanged
        SizeChanged
        StyleChanged
    end
    
   
    methods % Structors
        
        % todo :modify this so it works for button, and other controls that
        % might be parented in another virtualContainer...
        function obj = Component(hParent, varargin)
            
            if isa(hParent, 'uim.abstract.Container')
                obj.Parent = hParent.getGraphicsContainer();
            elseif isgraphics(hParent)
                obj.Parent = hParent;
            else 
                error('Parent must be this or that')
            end
            
            obj.createListeners()
            
            obj.parseInputs(varargin{:})

            obj.assignComponentCanvas()

            obj.createBackground()
            
            obj.IsConstructed_ = true;
            
            % Call updateSize to trigger size update (call before location)
            obj.updateSize(obj.SizeMode)

            % Call updateLocation to trigger location update
            obj.updateLocation(obj.PositionMode) 

            
            % Todo: add listener. If uicc is deleted, delete this class as
            % well. 

            %obj.Canvas = hParent;
            %obj.hAxes = obj.Canvas.Axes;
            
        end
        
        function delete(obj)
            
            if ~isempty(obj.hBackground) && isvalid(obj.hBackground)
                delete(obj.hBackground)
            end
            
            if ~isempty(obj.hBorder) && isvalid(obj.hBorder)
                delete(obj.hBorder)
            end
            
        end
        
    end
    
    methods (Access = protected) % Creation
        
        function createListeners(obj)
        %createListeners Create listeners relevant for component
            el = listener(obj.Parent, 'SizeChanged', ...
                @obj.onParentContainerSizeChanged);
            
            obj.ParentContainerSizeChangedListener = el;
            
            obj.ParentContainerDestroyedListener = addlistener(obj.Parent, ...
                'ObjectBeingDestroyed', @(s,e) obj.delete());
            
        end
        
        function parseInputs(obj, varargin)
        %parseInputs Collect type defaults and name-value pairs and assign.
        
            S = obj.getTypeDefaults();
            
            propNames = varargin(1:2:end);
            propValues = varargin(2:2:end);
            
            for i = 1:numel(propNames)
                S.(propNames{i}) = propValues{i};
            end
            
            C = cat(1, fieldnames(S)', struct2cell(S)');
            C = C(:)';
            
            % Special treatment because this has protected setAccess
            if strcmp('CanvasMode', C(1:2:end))
                ind = find(strcmp(C(1:2:end), 'CanvasMode'));
                obj.CanvasMode = C{ind*2};
                C(ind*2 - [1,0])=[];
            end
            
            parseInputs@uim.mixin.assignProperties(obj, C{:})
        end
        
        function assignComponentCanvas(obj)
        %assignComponentCanvas Assign component canvas    
            obj.Canvas = getappdata(obj.Parent, 'UIComponentCanvas');
            
            if isempty(obj.Canvas)
                obj.Canvas = uim.UIComponentCanvas(obj.Parent, 'GlassMode', 'off');
                setappdata(obj.Parent, 'UIComponentCanvas', obj.Canvas);
            end
            
            obj.hAxes = obj.Canvas.Axes;

        end
        
        function createBackground(obj) % Subclasses can override
        %createBackground Plot the component background
        
            % Make a patch, without spatial extent
            obj.hBackground = patch(obj.CanvasAxes, nan, nan, 'w');
            
            % Set interactive properties
            obj.hBackground.HitTest = 'off';
            obj.hBackground.PickableParts = 'none';
            
            % Set style properties
            obj.hBackground.EdgeColor = 'none';
            obj.hBackground.FaceAlpha = 0;

        end
        
        function createBorder(obj) % Subclasses can override
        %createBorder Plot the component border    
            
            % Why not just use the edge of the patch?? 
            %   -If we want to create more advanced borders...
        end
        
    end
    
    methods % Set/Get 

        function set.IsConstructed(obj, newValue)
            
            assert(islogical(newValue), 'Property value must be a logical')
            obj.IsConstructed = newValue;
            
            if obj.IsConstructed
                obj.onConstructed()
            end
        end

        function set.CanvasMode(obj, newValue)

            % Canvasmode can only be changed for containers.
            if isa(obj, 'uim.abstract.Control')
                error('Can not set CanvasMode for components derived from Control')
            elseif isa(obj, 'uim.abstract.Container')
                newValue = validatestring(newValue, {'shared', 'private'});
                obj.CanvasMode = newValue;
            end

        end
        
        function pos = get.CanvasPosition(obj)
            switch obj.CanvasMode
                case 'shared'
                    pos = obj.Position;
                case 'private'
                    pos = [0,0,obj.Position(3:4)];
            end
        end
        
        % Todo: Consider if this is necessary...
        function set.Size(obj, newValue)
            % Todo: check with minimum size
            obj.switchSizeMode('manual')
            obj.Position_(3:4) = newValue;
            if strcmp(obj.PositionMode, 'auto')
                obj.setAutoLocation()
            end
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

        function set.Padding(obj, newValue)
            obj.Padding = newValue;
            obj.redraw() % todo...
        end
                
        function set.HorizontalAlignment(obj, newValue)
            obj.HorizontalAlignment = newValue;
            obj.updateLocation('auto')
        end
        
        function set.VerticalAlignment(obj, newValue)
            obj.VerticalAlignment = newValue;
            obj.updateLocation('auto')
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
        
        function hAx = get.CanvasAxes(obj)
            hAx = obj.hAxes; 
            return;
        
%             if isa(obj.Canvas, 'uim.UIComponentCanvas')
%                 hAx = obj.Canvas.Axes;
%             elseif isa(obj.Canvas, 'matlab.graphics.axis.Axes')
%                 hAx = obj.Canvas;
%             else
%                 error('This should not happen...')
%             end
        end
    end
    
    methods % Update position / size / appearance
        
        function redraw(obj)
            if obj.IsConstructed
                if ~obj.IsDrawCompleted; obj.IsDrawCompleted = true; end
                obj.redrawBackground()
            end
        end
        
        function resize(obj)
        	obj.redrawBackground()
            obj.redrawBorder()
        end
        
        function relocate(obj, shift)
            obj.redrawBackground()
            %obj.moveBackground(shift)
        end
        
        function move(obj, shift)
            obj.relocate(shift)
        end
        
        function updateSize(obj, mode)
        %updateSize Handler of conditions that update component size  
        %
        %   Calculate new size based on size of parent container and
        %   internal properties (margins) that determine the size.
        
            % Abort if component has not finished construction. No need to 
            % go through this before all position-related properties are set.
            if ~obj.IsConstructed_; return; end
            
            if nargin == 2; obj.switchSizeMode(mode); end
            if strcmp(obj.SizeMode, 'manual'); return; end
            
            if isa(obj.Parent, 'uim.UIComponentCanvas')
                parentSize = obj.Parent.Size;
            elseif isa(obj.Parent, 'uim.abstract.Component')
                parentSize = obj.Parent.Position(3:4);
            elseif isa(obj.Parent, 'matlab.graphics.Graphics')
                parentPosition = getpixelposition(obj.Parent);
                parentSize = parentPosition(3:4);
% %             elseif isa(obj.Parent, 'matlab.graphics.axis.Axes')
% %                 parentSize = obj.Parent.Position(3:4);
% %             elseif isa(obj.Parent, 'matlab.ui.Figure')
% %                 parentSize = obj.Parent.Position(3:4);
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
        %updateLocation Handler of conditions that change component location
        %
        % This method is triggered either if the parent size changes or if
        % any of the location related properties are set to new values.
        %
        % If PositionMode is auto, the position of the component is
        % calculated based on Location, Anchorpoint and margins.
        % If PositionMode is manual, the values of the position property is
        % used.
            
            % Abort if component has not finished construction. No need to 
            % go through this before all position-related properties are set.
            if ~obj.IsConstructed_; return; end
            
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

    end
    
    methods (Access = private) % Internal Updates
        
        function setAutoLocation(obj)
        %setAutoLocation Calculate component's location based on properties

            % Find the reference point in the parent container based on the
            % value of the Location property.
            if isa(obj.Parent, 'uim.UIComponentCanvas')
                %parentSize = obj.Parent.Size;
                locationPoint = obj.Parent.getLocationPoint(obj.Location);
                
            elseif obj.isMatlabGraphicsParent(obj.Parent)
                parentPos = getpixelposition(obj.Parent);
                parentSize = parentPos(3:4);
                locationPoint = obj.location2point(parentSize, obj.Location);
            else
                warning('Parent of type %s is supported', class(obj.Parent))
                locationPoint = [1,1];
            end

            
            % Find the new location (Position(1:2)) based on the values of
            % anchoring properties (Horizontal/Vertical alignment)
            newLocation = locationPoint;
            
            % Todo: Is this needed ???
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
            
            % Set horizontal offset based on margin properties
            if strcmp(obj.Location, 'south') || strcmp(obj.Location, 'north')
                newLocation(1) = locationPoint(1) + obj.Margin(1);
            end
            
            if strcmp(obj.Location, 'center')
                newLocation(1) = locationPoint(1) + obj.Margin(1);
                newLocation(2) = locationPoint(2) + obj.Margin(2);
            end
            
            
% %             % Centered along horizontal dimension
% %             if strcmp(obj.Location, 'south') || strcmp(obj.Location, 'north')
% %                 newLocation(1) = (parentSize(1)-obj.Size(1)) / 2;
% %             end
% % 
% %             % Centered along vertical dimension
% %             if strcmp(obj.Location, 'east') || strcmp(obj.Location, 'west')
% %                 newLocation(2) = (parentSize(2)-obj.Size(2)) / 2;
% %             end

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
            %obj.SizeMode = newMode; Todo: Need to test this. 
        end % protected?
        
        function switchSizeMode(obj, newMode)
        %switchSizeMode Update position mode
            obj.SizeMode = newMode;
        end % protected?

        % Todo: remove
        function updateBackgroundSize(obj)
            obj.redrawBackground()
            %drawnow limitrate
        end
        
        function redrawBorder(obj)
            % Should this be done together with redrawBackground
        end
        
        function moveBackground(obj, shift)
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
        
        function moveBorder(obj, shift)
            
        end
        
    end
    
    methods (Access = protected)
                
        function redrawBackground(obj)
            
            if ~isempty(obj.hBackground) && obj.IsConstructed
            
                [X, Y] = uim.shape.rectangle(obj.Size, obj.CornerRadius);
                
                if strcmp(obj.CanvasMode, 'shared')
                    X = X + obj.Position_(1);
                    Y = Y + obj.Position_(2);
                end
                
                set(obj.hBackground, 'XData', X, 'YData', Y)
            end
            
        end
        
        % Todo: remove
        function updateBackground(obj)
            warning('this should be removed')
        end 

        function onConstructed(obj)
            
            if obj.IsConstructed
            
            	% Todo: This is not perfect. Sometimes size depends on
                % location...
            
                % Check if position was set different than default. if so, mode is manual
                
                % Call updateSize to trigger size update (call before location)
                obj.updateSize(obj.SizeMode)

                % Call updateLocation to trigger location update
                obj.updateLocation(obj.PositionMode) 
                
                % Set style
                obj.onStyleChanged()
                
                if ~obj.IsDrawCompleted
                    obj.redraw()
                end
                
            end
        end
        
        function onSizeChanged(obj, oldPosition, newPosition)
            if ~obj.IsConstructed; return; end
            
            switch obj.CanvasMode
                case 'shared'
                    obj.resize()
                    evtData = uim.event.SizeChangedData(oldPosition(3:4), newPosition(3:4));
                    obj.notify('SizeChanged', evtData)
                case 'private'
                    obj.CanvasAxes.Position = newPosition;
                    obj.CanvasAxes.XLim = [1, newPosition(3)];
                    obj.CanvasAxes.YLim = [1, newPosition(4)];
                    obj.resize()
            end
            

        end
        
        function onLocationChanged(obj, oldPosition, newPosition)
            if ~obj.IsConstructed; return; end
        
            switch obj.CanvasMode
                case 'shared'
                    obj.relocate(newPosition-oldPosition)
                    evtData = uim.event.LocationChangedData(oldPosition(1:2), newPosition(1:2));
                    obj.notify('LocationChanged', evtData)
                case 'private' 
                    % Only need to set new position of axes in parent
                    setpixelposition(obj.CanvasAxes, newPosition)
                    %obj.CanvasAxes.Position = newPosition;
            end
            
        end        
        
        function onStyleChanged(obj)
            if ~isempty(obj.hBackground) && obj.IsConstructed
                obj.hBackground.FaceColor = obj.BackgroundColor;
                obj.hBackground.FaceAlpha = obj.BackgroundAlpha;
                obj.hBackground.EdgeColor = obj.BorderColor;
                obj.hBackground.LineWidth = obj.BorderWidth;
            end
        end
        
        function onShapeChanged(obj)
            % todo: create an updateBackground method in addition to
            % updateSize
            
            obj.redrawBackground()
            %obj.redrawBorder() Not imlemented yet
        end
        
    end
    
    methods (Hidden, Access = protected)
        
        function onVisibleChanged(obj)
            % Subclass should override
        end
    end
    
    methods (Access = private) % Callbacks for listeners on parent container
        
        function onParentContainerSizeChanged(obj, src, evt)
            obj.updateSize()
            obj.updateLocation()
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
        
        function pos = getpixelposition(obj, recursive)
            if nargin < 2; recursive=false; end
            
            hContainer = obj.getGraphicsContainer();
            parentPos = getpixelposition(hContainer, recursive);
            
            pos = obj.Position;
            pos(1:2) = pos(1:2) + parentPos(1:2);
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
        
        function S = getTypeDefaults() % Subclasses can override
            S = struct();
        end
        
        function locationPoint = location2point(containerSize, locationKey)
            % todo: merge with getLocationPoint method. Should this be a
            % methods of this class or virtual container or just a
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
        
        function tf = isMatlabGraphicsParent(h)
        %isMatlabGraphicsParent Test if handle h can contain graphics.
        
        % Todo: Can I generalize this... Is there a shared superclass? Are
        % there any obvious types missing from the list?
        
            validGraphicsParents = {...
                'matlab.ui.Figure', ...
                'matlab.graphics.axis.Axes', ...
                'matlab.ui.container.Panel', ...
                'matlab.ui.container.Tab' ...
                };
            
            tf = false;
            
            % Check if given handle is any of the allowed parents
            for i = 1:numel(validGraphicsParents)
            
                if isa(h, validGraphicsParents{i})
                    tf = true; 
                    return
                end
                
            end
                        
        end
    end
        
    
    
end




% Dones
%       [x] Make this into a component super class. (from virtualContainer
%       [x] Remove Children property, and add that to a container subclass.
%       [x] Rename adjustSize to updateSize
%       [-] Inherit structadapter
%       [x] Add anchoring position mode. (Think this is done)
%       [-] Add a sizeChangedFcn prop? Like matlab containers have? Why???
%       [-] Add/implement units property? NO! This is pixelbased!
%     
%       [x] Split into component and container.
%     
%       [x] rename onSizeChanged & onLocationChanged to updateSize &
%           updateLocation. onSizeChanged should be called after the 
%           position is set...
%       [x] Add a abstract static method called getTypeDefaults?
%       This would be a method that when implemented returns default values
%       for a specific type. Alternative to make all properties abstract,
%       and give option for having different default values of subclass
%       properties.