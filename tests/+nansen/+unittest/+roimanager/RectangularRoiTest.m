classdef RectangularRoiTest < matlab.unittest.TestCase
    %RectangularRoiTest Unit tests for creating rectangular rois.
    %
    %   Covers roimanager.roiMap/createRectangularRoi and the size that the
    %   rectangleSelect pointer tool creates rois with: where a rectangle
    %   ends up for a given point, what happens at the edge of the image,
    %   and how the size of the tool is changed.
    %
    %   The roi map is given a struct in place of the image viewer, because
    %   the only thing it needs from the viewer here is the image size.
    %
    %   Run tests:
    %       runtests('nansen.unittest.roimanager.RectangularRoiTest')

    properties (Constant)
        ImageHeight = 200
        ImageWidth = 300
        RegionSize = [64, 48] % [width, height]
    end

    methods (Test)

        % ------------------------------------------------------------
        % Where the rectangle ends up
        % ------------------------------------------------------------

        function testRectangleIsCenteredOnThePoint(testCase)
            [roiMap, roiGroup] = testCase.createRoiMap();

            roiMap.createRectangularRoi(100, 120, 64, 48);

            testCase.verifyEqual(getRectangle(roiGroup, 1), [68, 96, 64, 48]);
        end

        function testRectangleIsCreatedAsAPolygonWithFourCorners(testCase)
            [roiMap, roiGroup] = testCase.createRoiMap();

            roiMap.createRectangularRoi(100, 120, 64, 48);

            testCase.verifyEqual(roiGroup.roiArray(1).shape, 'Polygon');
            testCase.verifyEqual(size(roiGroup.roiArray(1).coordinates), [4, 2]);
        end

        function testRectangleAtTheUpperLeftIsMovedInsideTheImage(testCase)
            % The rectangle keeps its size and is moved, rather than being
            % cut down to what fits where it was clicked.
            [roiMap, roiGroup] = testCase.createRoiMap();

            roiMap.createRectangularRoi(5, 5, 64, 48);

            testCase.verifyEqual(getRectangle(roiGroup, 1), [1, 1, 64, 48]);
        end

        function testRectangleAtTheLowerRightIsMovedInsideTheImage(testCase)
            [roiMap, roiGroup] = testCase.createRoiMap();

            roiMap.createRectangularRoi(testCase.ImageWidth - 1, ...
                testCase.ImageHeight - 1, 64, 48);

            expectedRectangle = [testCase.ImageWidth - 64 + 1, ...
                testCase.ImageHeight - 48 + 1, 64, 48];
            testCase.verifyEqual(getRectangle(roiGroup, 1), expectedRectangle);
        end

        function testRectangleLargerThanTheImageIsCutDownToIt(testCase)
            [roiMap, roiGroup] = testCase.createRoiMap();

            roiMap.createRectangularRoi(150, 100, 400, 300);

            testCase.verifyEqual(getRectangle(roiGroup, 1), ...
                [1, 1, testCase.ImageWidth, testCase.ImageHeight]);
        end

        function testCornersAreWholePixelsForAPointBetweenThem(testCase)
            [roiMap, roiGroup] = testCase.createRoiMap();

            roiMap.createRectangularRoi(100.4, 120.6, 65, 49);

            rectangle = getRectangle(roiGroup, 1);
            testCase.verifyEqual(rectangle, round(rectangle));
        end

        function testEveryRectangleIsKeptInTheOrderItWasCreated(testCase)
            [roiMap, roiGroup] = testCase.createRoiMap();

            roiMap.createRectangularRoi(100, 120, 64, 48);
            roiMap.createRectangularRoi(200, 60, 32, 32);

            testCase.verifyEqual(roiGroup.roiCount, 2);
            testCase.verifyEqual(getRectangle(roiGroup, 1), [68, 96, 64, 48]);
            testCase.verifyEqual(getRectangle(roiGroup, 2), [184, 44, 32, 32]);
        end

        % ------------------------------------------------------------
        % The size that the pointer tool creates rois with
        % ------------------------------------------------------------

        function testToolKeepsTheSizeItIsSetTo(testCase)
            hTool = testCase.createPointerTool();

            hTool.setRectangleSize(testCase.RegionSize)

            testCase.verifyEqual(hTool.rectangleToolCoords(3:4), testCase.RegionSize);
        end

        function testToolGrowsAndShrinksInBothDirections(testCase)
            hTool = testCase.createPointerTool();
            hTool.setRectangleSize(testCase.RegionSize)

            hTool.changeRectangleSize([8, 8])
            testCase.verifyEqual(hTool.rectangleToolCoords(3:4), ...
                testCase.RegionSize + 8);

            hTool.changeRectangleSize([-8, -8])
            testCase.verifyEqual(hTool.rectangleToolCoords(3:4), testCase.RegionSize);
        end

        function testToolGrowsInOneDirectionOnly(testCase)
            hTool = testCase.createPointerTool();
            hTool.setRectangleSize(testCase.RegionSize)

            hTool.changeRectangleSize([0, 8])

            testCase.verifyEqual(hTool.rectangleToolCoords(3:4), ...
                testCase.RegionSize + [0, 8]);
        end

        function testToolDoesNotShrinkBelowTheMinimumSize(testCase)
            hTool = testCase.createPointerTool();
            hTool.setRectangleSize(testCase.RegionSize)

            hTool.changeRectangleSize([-1000, -1000])

            testCase.verifyEqual(hTool.rectangleToolCoords(3:4), testCase.RegionSize);
        end

        function testRoiIsCreatedWithTheSizeOfTheTool(testCase)
            % What the tool does on a click, without moving the mouse
            [roiMap, roiGroup] = testCase.createRoiMap();
            hTool = testCase.createPointerTool(roiMap);
            hTool.setRectangleSize(testCase.RegionSize)
            hTool.changeRectangleSize([8, 8])

            toolSize = hTool.rectangleToolCoords(3:4);
            hTool.RoiDisplay.createRectangularRoi(150, 100, toolSize(1), toolSize(2));

            rectangle = getRectangle(roiGroup, 1);
            testCase.verifyEqual(rectangle(3:4), testCase.RegionSize + 8);
        end
    end

    methods (Access = private)

        function [roiMap, roiGroup] = createRoiMap(testCase)
            %createRoiMap Create a roi map on an invisible figure
            hAxes = testCase.createAxes();
            roiGroup = roimanager.roiGroup();

            % The roi map only needs the image size from the viewer
            displayAppStub = struct('imHeight', testCase.ImageHeight, ...
                'imWidth', testCase.ImageWidth);

            roiMap = roimanager.roiMap(displayAppStub, hAxes, roiGroup);
            testCase.addTeardown(@delete, roiMap)
        end

        function hTool = createPointerTool(testCase, roiMap)
            %createPointerTool Create the rectangleSelect tool for an axes
            if nargin < 2
                hAxes = testCase.createAxes();
            else
                hAxes = roiMap.hAxes;
            end

            hTool = roimanager.pointerTool.rectangleSelect(hAxes);
            if nargin >= 2
                hTool.RoiDisplay = roiMap;
            end
        end

        function hAxes = createAxes(testCase)
            %createAxes Create axes on a figure that never opens on screen
            hFigure = figure('Visible', 'off');
            testCase.addTeardown(@close, hFigure)

            hAxes = axes(hFigure);
            hAxes.XLim = [1, testCase.ImageWidth];
            hAxes.YLim = [1, testCase.ImageHeight];
        end
    end
end

function rectangle = getRectangle(roiGroup, roiNumber)
%getRectangle Get the bounding rectangle of a roi as [x, y, width, height]

    coordinates = roiGroup.roiArray(roiNumber).coordinates;

    xMin = min(coordinates(:, 1));
    yMin = min(coordinates(:, 2));
    width = max(coordinates(:, 1)) - xMin + 1;
    height = max(coordinates(:, 2)) - yMin + 1;

    rectangle = [xMin, yMin, width, height];
end
