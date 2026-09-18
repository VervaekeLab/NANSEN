classdef RegionSelector < imviewer.ImviewerPlugin
%RegionSelector Plugin for placing rectangular regions on an image
%
%   This plugin lets the user place rectangular regions on the image of an
%   imviewer app, and returns them as rectangles, for example to pick the
%   area to crop a stack to or the parts of the field of view that a
%   method should work on.
%
%   h = imviewer.plugin.RegionSelector(hImviewer) adds the plugin to the
%   imviewer app hImviewer.
%
%   h = imviewer.plugin.RegionSelector(hImviewer, Name, Value) also
%   specifies the RegionSize and the Regions to start with.
%
%   The regions are represented as rectangular polygon rois in a roi map,
%   which gives the same display and editing as roimanager provides for
%   rois. Regions are placed with the rectangleSelect pointer tool and
%   edited with the selectObject pointer tool.
%
%   See also nansen.stack.selectRectangularRegions,
%   roimanager.pointerTool.rectangleSelect

    properties (Constant) % Inherited from applify.mixin.AppPlugin
        Name = 'Region Selector'
    end

    properties
        RegionSize (1,2) double {mustBePositive} = [64, 64] % Size of the region to place, as [width, height]
        Regions (:,4) double = zeros(0, 4)  % Regions to start with, as rectangles [xmin, ymin, width, height]
    end

    properties (Dependent, SetAccess = private)
        RegionCount % Number of regions that are currently placed
    end

    properties (Access = private)
        RoiGroup roimanager.roiGroup
        RoiMap roimanager.roiMap
        PointerManager uim.interface.pointerManager
    end

    methods % Constructor

        function obj = RegionSelector(varargin)
            obj@imviewer.ImviewerPlugin(varargin{:})

            if ~nargout; clear obj; end
        end

        function delete(obj)
            if ~isempty(obj.RoiMap) && isvalid(obj.RoiMap)
                delete(obj.RoiMap)
            end
            if ~isempty(obj.RoiGroup) && isvalid(obj.RoiGroup)
                delete(obj.RoiGroup)
            end
        end
    end

    methods % Set/get

        function regionCount = get.RegionCount(obj)
            if isempty(obj.RoiGroup) || ~isvalid(obj.RoiGroup)
                regionCount = 0;
            else
                regionCount = obj.RoiGroup.roiCount;
            end
        end
    end

    methods

        function regions = getRegions(obj)
        %getRegions Get the regions that are currently placed
        %
        %   regions = getRegions(obj) returns an N-by-4 array of rectangles
        %   [xmin, ymin, width, height] of pixel indices, in the order the
        %   regions were placed.

            regions = rois2rectangles(obj.RoiGroup.roiArray);
        end
    end

    methods (Access = protected)

        function onPluginActivated(obj)
            onPluginActivated@imviewer.ImviewerPlugin(obj)

            obj.initializeRoiMap()
            obj.initializePointerTools()
        end
    end

    methods (Access = private)

        function initializeRoiMap(obj)
        %initializeRoiMap Create a roi map to hold and display the regions

            imageSize = [obj.ImviewerObj.imHeight, obj.ImviewerObj.imWidth];

            obj.RoiGroup = roimanager.roiGroup();
            if ~isempty(obj.Regions)
                obj.RoiGroup.addRois( rectangles2rois(obj.Regions, imageSize) )
            end

            obj.RoiMap = roimanager.roiMap(obj.ImviewerObj, ...
                obj.ImviewerObj.Axes, obj.RoiGroup);
        end

        function initializePointerTools(obj)
        %initializePointerTools Add the roi pointer tools to the image viewer

            obj.PointerManager = obj.PrimaryApp.PointerManager;
            hAxes = obj.PrimaryApp.Axes;

            obj.PointerManager.initializePointers(hAxes, ...
                @roimanager.pointerTool.rectangleSelect)
            obj.PointerManager.initializePointers(hAxes, ...
                @roimanager.pointerTool.selectObject)

            obj.PointerManager.pointers.rectangleSelect.RoiDisplay = obj.RoiMap;
            obj.PointerManager.pointers.selectObject.RoiDisplay = obj.RoiMap;
            obj.PointerManager.pointers.rectangleSelect.setRectangleSize(obj.RegionSize)

            % Placing regions is the default mode, so that toggling the
            % select tool off with the s key returns to placing regions.
            obj.PointerManager.defaultPointerTool = ...
                obj.PointerManager.pointers.rectangleSelect;
            obj.PointerManager.togglePointerMode('rectangleSelect')
        end
    end
end

function rectangles = rois2rectangles(roiArray)
%rois2rectangles Get the bounding rectangle of each roi

    numRois = numel(roiArray);
    rectangles = zeros(numRois, 4);

    for i = 1:numRois
        xCoordinates = roiArray(i).coordinates(:, 1);
        yCoordinates = roiArray(i).coordinates(:, 2);

        xMin = round( min(xCoordinates) );
        yMin = round( min(yCoordinates) );
        width = round( max(xCoordinates) ) - xMin + 1;
        height = round( max(yCoordinates) ) - yMin + 1;

        rectangles(i, :) = [xMin, yMin, width, height];
    end
end

function roiArray = rectangles2rois(rectangles, imageSize)
%rectangles2rois Create one rectangular polygon roi per rectangle

    numRectangles = size(rectangles, 1);
    roiArray = RoI.empty;

    for i = 1:numRectangles
        xMin = rectangles(i, 1);
        yMin = rectangles(i, 2);
        xMax = xMin + rectangles(i, 3) - 1;
        yMax = yMin + rectangles(i, 4) - 1;

        xCorners = [xMin, xMax, xMax, xMin];
        yCorners = [yMin, yMin, yMax, yMax];

        roiArray(i) = RoI('Polygon', [xCorners; yCorners], imageSize);
    end
end
