classdef imageVector < handle
%imageVector Plot a set of polygons as one object.
%
%   Methods for placing and scaling all polygons belonging to the group
    
    % NB: setting position and alignment of image has some bugs. setting
    % alignment first and then position works, but not always the other
    % way around?

    
    properties
        
        HorizontalAlignment = 'center' % left | center | right
        VerticalAlignment = 'middle' % bottom | middle | top

        Shape
        Color
        Alpha
        Parent
        
        LockAspectRatio = true
        PickableParts = 'visible'
        HitTest = 'on'
    end
    
    
    properties (Dependent)
        Position
        Angle
        Width
        Height
        Clipping
        Visible

    end
    
    
    properties (SetAccess = private)
        boundingBox
    end
    
    
    properties (Access = private) 
        numShapes
        hPolygon
        
        currentAngle = 0
        currentPosition = [0, 0]
    end
    
    
    
    methods
        
        function obj = imageVector(hParent, pathStr, varargin)

            assert(isa(hParent, 'matlab.graphics.axis.Axes') || ...
            isa(hParent, 'matlab.graphics.primitive.Group'), ...
            'Invalid parent handle for imageVector');


            if isa(pathStr, 'char')
                S = load(pathStr);
                V = S.imageVector;
            elseif isa(pathStr, 'struct')
                V = pathStr;
            end
            
            
            numShapes = numel(V);
            
            hP = gobjects(numShapes, 1);

            if ~isa(hParent, 'matlab.graphics.axis.Axes')
                hAxes = ancestor(hParent, 'axes');
                hold(hAxes, 'on')
            end
            
            for i = 1:numShapes
                hP(i) = plot(V(i).Shape, 'FaceColor', V(i).Color, 'FaceAlpha', 1, 'EdgeColor', 'none', 'Parent', hParent);
            end

            obj.numShapes = numShapes;
            obj.hPolygon = hP;
                        
            % Find out how to prevent sticking the object to the userdata
            % to avoid it being deleted when object goes out of scope...
            if isempty(hParent.UserData)
                hParent.UserData = struct();
            end
            
            if isfield(hParent.UserData, 'Handles')
                hParent.UserData.Handles(end+1) = obj;
            else
                hParent.UserData.Handles = obj;
            end
            
          
        end
        
        function delete(obj)
            
            for i = 1:obj.numShapes
                delete(obj.hPolygon(i))
            end
            
            delete(obj)
            
        end
        
        
        function V = getVectorStruct(obj)
            polyShape = arrayfun(@(h) h.Shape, obj.hPolygon, 'uni', 0);
            colors = arrayfun(@(h) h.FaceColor, obj.hPolygon, 'uni', 0);
                          
            for i = 1:numel(polyShape)
                p1 = polyShape{i};
                p2 = polyshape(p1.Vertices, 'Simplify', false); % Set simplfy to false to avoid calling check and simplify on creation
                polyShape{i} = p2;
            end
            
            V = struct('Shape', polyShape, 'Color', colors); %#ok<NASGU>
        end
        
        
        function rotate(obj, angle)
            
            origBBox = obj.boundingBox;
            %currentPosition = obj.currentPosition;
            
            offset = origBBox(1:2) + origBBox(3:4)/2;
            obj.translate(-offset);
            
            for i = 1:obj.numShapes
                obj.hPolygon(i).Shape = rotate(obj.hPolygon(i).Shape, angle);
            end
               
            obj.currentAngle = obj.currentAngle + angle;
            obj.translate(offset);

        end
       
        
        function fliplr(obj)
            
            warning('off', 'MATLAB:polyshape:repairedBySimplify')
            
            
            origBBox = obj.boundingBox;
            
            dx = -origBBox(1);
            obj.translate([-dx, 0]);
            
            
            for i = 1:obj.numShapes
                obj.hPolygon(i).Shape.Vertices = [-1, 1] .* obj.hPolygon(i).Shape.Vertices;
            end
            
            newBBox = obj.boundingBox;
            dx = origBBox(1) - newBBox(1);
            
            obj.translate([dx, 0]);
           
            warning('on', 'MATLAB:polyshape:repairedBySimplify')
            
        end
        
        
        function flipud(obj)
            
            warning('off', 'MATLAB:polyshape:repairedBySimplify')
            
            currentPositionKeep = obj.currentPosition;
            
            origBBox = obj.boundingBox;
            
            dy = -origBBox(2);
            
            obj.translate([0, -dy]);
            
            
            for i = 1:obj.numShapes
                obj.hPolygon(i).Shape.Vertices = [1, -1] .* obj.hPolygon(i).Shape.Vertices;
            end
            
            newBBox = obj.boundingBox;
            dy = origBBox(2) - newBBox(2);
            
            obj.translate([0, dy]);
           
            warning('on', 'MATLAB:polyshape:repairedBySimplify')
            
            obj.currentPosition = currentPositionKeep;

        end
           
        
        function translate(obj, shift)

            mVer = version;
            
            % if strcmp(mVer(1:5), '9.4.0')
                for i = 1:obj.numShapes
                    obj.hPolygon(i).Shape.Vertices = obj.hPolygon(i).Shape.Vertices + shift;
                end            
%             else
%                 for i = 1:obj.numShapes
%                     obj.hPolygon(i).Shape = translate(obj.hPolygon(i).Shape, shift);
%                 end
%             end
            
            obj.currentPosition =  obj.currentPosition + shift;
            
        end
        
        
        function scale(obj, scaleFactor)
            
            if numel(scaleFactor) == 1
                scaleFactor = repmat(scaleFactor, 1, 2);
            end
            
            for i = 1:obj.numShapes
                obj.hPolygon(i).Shape = scale(obj.hPolygon(i).Shape, scaleFactor);
            end
            
        end
       
       
        function place(obj, position, varargin)
           
           
           
        end
        
        
        function reposition(obj, newAlignment)
            
            bbox = obj.boundingBox;
            [dx,dy] = deal(0);
            
            switch newAlignment
                
                case 'left'
                    dx = obj.currentPosition(1) - bbox(1);
                case 'right'
                    dx = obj.currentPosition(1) - bbox(1)+bbox(3);
                case 'center'
                    dx = obj.currentPosition(1) - bbox(1)+bbox(3)/2;
                case 'top'
                    dy = obj.currentPosition(2) - bbox(2)+bbox(4);
                case 'bottom'
                    dy = obj.currentPosition(2) - bbox(2);
                case 'middle'
                    dy = obj.currentPosition(2) - bbox(2)+bbox(4)/2;
            end
            
            obj.translate([dx, dy]);
            
        end
    end
    
    
    methods (Access = private) % Callbacks for property changes
        
        function onColorChanged(obj, color)
            for i = 1:numel(obj.hPolygon)
                obj.hPolygon(i).FaceColor = color;
            end
        end
        
        function onAlphaChanged(obj, value)
            for i = 1:numel(obj.hPolygon)
                obj.hPolygon(i).FaceAlpha = value;
            end
        end
        
    end
    
    
    methods % set/get
        
        function set.Clipping(obj, newValue)
            
            for i = 1:numel(obj.hPolygon)
                obj.hPolygon(i).Clipping = newValue;
            end
            
        end
        
        function set.Visible(obj, newValue)
            
            for i = 1:numel(obj.hPolygon)
                obj.hPolygon(i).Visible = newValue;
            end
                        
        end
        
        
        function set.HorizontalAlignment(obj, value)
            % Todo validatestring ('left', 'center', 'right');
            
            oldValue = obj.HorizontalAlignment;
            
            if ~strcmp(oldValue, value)
                obj.reposition(value)
                obj.HorizontalAlignment = value;

            end
        end
        
        
        function set.VerticalAlignment(obj, value)
            % Todo validatestring ('top', 'middle', 'bottom');
            
            oldValue = obj.VerticalAlignment;
            obj.VerticalAlignment = value;
            
            if ~strcmp(oldValue, value)
                obj.reposition(value)
                obj.VerticalAlignment = value;
            end
        end
        
        
        function set.Width(obj, width)
            
            currentWidth = obj.Width;
            scaleFactorX = width / currentWidth;
            
            if obj.LockAspectRatio
                scaleFactorY = scaleFactorX;
            else
                scaleFactorY = 1;
            end
            
            scaleFactor = [scaleFactorX, scaleFactorY];
           
            obj.scale(scaleFactor)
           
        end
        
        
        function width = get.Width(obj)
            bbox = obj.boundingBox;
            width = bbox(3);
            
%             shapes = cat(1, [obj.hPolygon.Shape] );
%             coords = cat(1, shapes.Vertices);
%             width = range(coords(:, 1));
            
        end
       
        
        function set.Height(obj, height)
           
            currentHeight = obj.Height;
            scaleFactorY = height / currentHeight;
            
            if obj.LockAspectRatio
                scaleFactorX = scaleFactorY;
            else
                scaleFactorX = 1;
            end
            
            scaleFactor = [scaleFactorX, scaleFactorY];
            obj.scale(scaleFactor)
           
        end

        
        function height = get.Height(obj)
            bbox = obj.boundingBox;
            height = bbox(4);
            
%             shapes = cat(1, [obj.hPolygon.Shape] );
%             coords = cat(1, shapes.Vertices);
%             height = range(coords(:, 2));
            
        end
        
        
        function set.Position(obj, value)
            
            bbox = obj.boundingBox;
            currentPosition = [0,0];
            
            switch obj.VerticalAlignment
                case 'top'
                    currentPosition(2) = bbox(2)+bbox(4);
                case 'bottom'
                    currentPosition(2) = bbox(2);
                case 'middle'
                    currentPosition(2) = bbox(2)+bbox(4)/2;
            end
            
            switch obj.HorizontalAlignment

                case 'left'
                    currentPosition(1) = bbox(1);
                case 'right'
                    currentPosition(1) = bbox(1)+bbox(3);
                case 'center'
                    currentPosition(1) = bbox(1)+bbox(3)/2;
            end
            
            
            shift = value - currentPosition;
            obj.translate(shift);
            
            obj.currentPosition = obj.boundingBox(1:2) + obj.boundingBox(3:4)/2;
            
        end

        
        function position = get.Position(obj)
            position = obj.currentPosition;
        end
        
        
        function set.Color(obj, newValue)
            obj.onColorChanged(newValue)
            obj.Color = newValue;
        end
        
        
        function set.Angle(obj, value)
            
            deltaAngle = value - obj.currentAngle;
            obj.rotate(deltaAngle)
            
        end
        
        function set.Alpha(obj, newValue)
            obj.onAlphaChanged(newValue)
            obj.Alpha = newValue;
        end
        
        
        function set.PickableParts(obj, newValue)
            set(obj.hPolygon, 'PickableParts', newValue)
            obj.PickableParts = newValue;
        end
        
        
        function set.HitTest(obj, newValue)
            set(obj.hPolygon, 'HitTest', newValue)
            obj.HitTest = newValue;
        end
        
        function bbox = get.boundingBox(obj)
            
            shapes = cat(1, [obj.hPolygon.Shape] );
            coords = cat(1, shapes.Vertices);
            
            coordinateRange = max(coords) - min(coords);
            
            bbox = [min(coords), coordinateRange];

        end

        
    end
    
    
    
end