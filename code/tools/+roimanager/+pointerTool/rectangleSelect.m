classdef rectangleSelect < uim.interface.abstractPointer & ...
        roimanager.pointerTool.RoiDisplayInputHandler
%rectangleSelect Pointer tool for creating rectangular rois
%
%   This tool shows a rectangle of a fixed size at the pointer location and
%   creates a rectangular roi centered on the point that is clicked. The
%   size of the rectangle is adjusted with the keyboard, or by the
%   changeRectangleSize method.
%
%   Keyboard shortcuts:
%       g / h : Grow / shrink the rectangle in both directions
%       shift + g / h : Grow / shrink the rectangle in the y-direction only
%
%   See also roimanager.pointerTool.circleSelect

    properties (Constant)
        exitMode = 'default';
    end

    properties % Properties related to displaying the rectangle during creation
        rectangleToolCoords % Current rectangle as [xCenter, yCenter, width, height]
        hRectangle          % Patch handle for the temporary rectangle
        defaultSize = [64, 64] % Default rectangle size as [width, height]
    end

    properties (Constant, Access = private)
        MIN_SIZE = 4        % Smallest rectangle size (pixels) in each direction
        SIZE_INCREMENT = 4  % Change in size (pixels) per keypress
    end

    methods

        function obj = rectangleSelect(hAxes)
            obj.hFigure = ancestor(hAxes, 'figure');
            obj.hAxes = hAxes;
        end

        function activate(obj)
            activate@uim.interface.abstractPointer(obj)
            showRectangle(obj)
        end

        function deactivate(obj)
            deactivate@uim.interface.abstractPointer(obj)
            hideRectangle(obj)
        end

        function suspend(obj)
            suspend@uim.interface.abstractPointer(obj)
            hideRectangle(obj)
        end

        function setPointerSymbol(obj)
            obj.hFigure.Pointer = 'crosshair';
        end

        function onButtonDown(obj, ~, ~)

            if strcmp(obj.hFigure.SelectionType, 'alt')
                return
            end

            obj.isActive = true;

            currentPoint = obj.hAxes.CurrentPoint(1, 1:2);
            x = currentPoint(1);
            y = currentPoint(2);
            w = obj.rectangleToolCoords(3);
            h = obj.rectangleToolCoords(4);

            obj.RoiDisplay.createRectangularRoi(x, y, w, h);
        end

        function onButtonMotion(obj, ~, ~)

            persistent prevValue
            if isempty(prevValue); prevValue = 0; end

            currentPoint = obj.hAxes.CurrentPoint(1, 1:2);

            % Hide the rectangle tool if the pointer is not in a "valid"
            % position.
            x = round(currentPoint(1)); y = round(currentPoint(2));
            tf = obj.RoiDisplay.isPointValid(x, y);

            if tf == 0 && prevValue ~= 0
                obj.hideRectangle()
            elseif tf ~= 0 && prevValue == 0
                obj.showRectangle()
            end
            prevValue = tf;

            tmpCoords = [currentPoint, obj.rectangleToolCoords(3:4)];
            obj.plotRectangleTool(tmpCoords);
        end

        function onButtonUp(obj, ~, ~)
            obj.isActive = false;
        end

        function wasCaptured = onKeyPress(obj, src, event)
            wasCaptured = true;

            switch event.Key
                case {'g', 'h'}
                    deltaSize = obj.SIZE_INCREMENT .* [1, 1];
                    if contains('shift', event.Modifier)
                        % Change the height only, to make a rectangle that
                        % is not square.
                        deltaSize(1) = 0;
                    end

                    if isequal(event.Key, 'h')
                        deltaSize = -1*deltaSize;
                    end

                    changeRectangleSize(obj, deltaSize)
                otherwise
                    wasCaptured = false;
            end

            if wasCaptured
                return
            else % Pass on to roi keypress handler
                wasCaptured = obj.roiKeypressHandler(src, event);
            end
        end
    end

    methods

        function showRectangle(obj)
            if isempty(obj.hRectangle)
                obj.plotRectangleTool()
            end

            obj.hRectangle.Visible = 'on';
        end

        function hideRectangle(obj)
            obj.hRectangle.Visible = 'off';
        end

        function changeRectangleSize(obj, deltaSize)
        %changeRectangleSize Change the size of the rectangle tool
        %
        %   changeRectangleSize(obj, deltaSize) changes the size of the
        %   rectangle by deltaSize, given as [deltaWidth, deltaHeight].

            tmpCoords = obj.rectangleToolCoords;
            tmpCoords(3:4) = tmpCoords(3:4) + deltaSize;
            obj.plotRectangleTool(tmpCoords)
        end

        function setRectangleSize(obj, newSize)
        %setRectangleSize Set the size of the rectangle tool
        %
        %   setRectangleSize(obj, newSize) sets the size of the rectangle
        %   to newSize, given as [width, height].

            obj.defaultSize = newSize;

            if isempty(obj.rectangleToolCoords)
                obj.plotRectangleTool()
            else
                tmpCoords = obj.rectangleToolCoords;
                tmpCoords(3:4) = newSize;
                obj.plotRectangleTool(tmpCoords)
            end
        end
    end

    methods (Access = protected)

        function plotRectangleTool(obj, coords)

            if nargin < 2 && ~obj.isPointerInsideAxes()
                if isempty(obj.rectangleToolCoords)
                    x = obj.hAxes.XLim(1) + nansen.util.range(obj.hAxes.XLim)/2;
                    y = obj.hAxes.YLim(1) + nansen.util.range(obj.hAxes.YLim)/2;
                    rectangleSize = obj.defaultSize;
                    obj.rectangleToolCoords = [x, y, rectangleSize];
                else
                    x = obj.rectangleToolCoords(1);
                    y = obj.rectangleToolCoords(2);
                    rectangleSize = obj.rectangleToolCoords(3:4);
                end

            elseif nargin < 2 && obj.isPointerInsideAxes()
                point = obj.hAxes.CurrentPoint;
                x = point(1,1);
                y = point(1,2);
                if isempty(obj.rectangleToolCoords)
                    rectangleSize = obj.defaultSize;
                else
                    rectangleSize = obj.rectangleToolCoords(3:4);
                end
            else
                x = coords(1); y = coords(2); rectangleSize = coords(3:4);
            end

            if any(rectangleSize < obj.MIN_SIZE)
                return
            else
                obj.rectangleToolCoords = [x, y, rectangleSize];
            end

            % Create the corners of the rectangle, centered on x and y.
            w = rectangleSize(1); h = rectangleSize(2);
            xData = x + [-1, 1, 1, -1] * w/2;
            yData = y + [-1, -1, 1, 1] * h/2;

            if isempty(obj.hRectangle)
                edgeColor = ones(1,3)*0.5;
                obj.hRectangle = patch(obj.hAxes, xData, yData, 'w', ...
                    'EdgeColor', edgeColor);
                obj.hRectangle.FaceAlpha = 0.15;
                obj.hRectangle.PickableParts = 'none';
                obj.hRectangle.HitTest = 'off';
            else
                set(obj.hRectangle, 'XData', xData, 'YData', yData)
            end
        end
    end
end
