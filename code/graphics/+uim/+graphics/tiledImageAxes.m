classdef tiledImageAxes < uim.handle
%clib.tiledImageAxes
%
%   Create an axes with a grid of tiles, where each tile can hold an image,
%   a line/patch and a text object. Additionally tiles can be selected
%   and it is possible to add custom callback functions to the action of
%   selecting a tile.
%   
%   This class will function like a virtual subplot in the sense that you
%   can plot into multiple small subplots whereas the actual axes object is
%   one "matlab.graphics.axis.Axes" object. This means that the class is
%   much less flexible than having a figure with real subplots, but on the
%   other hand it can provide a powerful engine for plotting e.g. 100s of
%   images in a montage/mosaic, with added functionality like plotting
%   something on top and adding textlabels. And as stated before, tiles can
%   be selected and trigger custom callback functions.
%
%   Making a figure with 10s to hundreds of subplots in a figure, would
%   update much slower than what is possible with this class.
%
%
%   Examples:
%       See clib.manualClassifier &
%       imviewer.widgets.ThumbnailSelector for practical examples.


% "Persistent settings" Consider if it should be configurable for objects.
properties (Constant = true)
    plotOrder = 'rowwise'       % rowwise | columnwise 
end


properties % Properties to configure axes layout (Default values are preset)
    gridSize = [3, 5]           % [nRows, nCols]
    imageSize = [128, 128]      % [imHeight, imWidth] Size (Reso) in px per tile
    padding = 10                % Number of pixels between each tile. Todo: Rename to spacing
    numChan = 1;                % Number of color channels. 

    normalizedPadding = 0.012;  % Padding between tiles in normalized units.
    tileUnits = 'pixel'         % pixel | scaled. scaled units will set axes coordinates in a scaled unit vis a vis pixels.
    
    Visible = 'on'
end

properties % Properties for configuration of appearance

    tileConfiguration = struct('DefaultTileColor', ones(1,3)*0.7, ...
                               'SelectedTileColor', ones(1,3)*0.5, ...
                               'DefaultColorMap', 'viridis', ...
                               'TextColor', ones(1,3)*0.8 )
    highlightTileOnMouseOver = false
        
end

properties (SetAccess = protected) % Properties for public access
    selectedTiles  % Number of tiles that are selected 
    axesRange      % Store the range of axes limits for quick retrieval ([x,y])
end

properties (Dependent = true) % General info about class objects
    Figure
    Axes
    nTiles
    nRows
    nCols
end

% Properties that are used internally
properties (Access = private, Hidden)
    tileCorners
    tileCenters
    tileIndices
    tileIndexMap
    
    imageSize_ = [128, 128]     % Original size of images that are plotted. % Todo. Set this on construction?
    scaleFactor = [1, 1]        % Internal scalefactor (convert pixel to coord)
    
    tilePixelSize
    tileLineWidth = 2
    
    axesPositionChangedListener
    
    IsConstructed = false
end

% Dependent properties that are used internally 
properties (Dependent = true, Access = private) 
    pixelWidth          % Number of pixels in x for the whole mosaic image
    pixelHeight         % Number of pixels in y for the whole mosaic image
    pixelPadding        % Number of pixels for padding between tiles.
end

% Properties to store for graphical handles
properties (Access = private, Hidden)
    hParent
    hFigure
    hAxes
    hImage

    hTileText           % Handle for text object belonging to a tile
    hTilePlot           % Handle for line/patch object belonging to a tile
        
    hTileOutline        % Handle for tile outline
    
    debug = false
end


methods %Structors
    
    % % Constructor
    function obj = tiledImageAxes(varargin)
    %tiledImageAxes Crate and configure the tileImageAxes object
    %   
    %   tiledImageAxes Creates a tiled image axes in a new figure.
    %
    %   tiledImageAxes(parent) Creates a tiled images axes in an existing
    %   figure or uipanel.
    %
    %   tiledImageAxes(..., Name, Value) creates a tiled images given
    %   additional parameters.
    %
    %   Parameters: 
    %       gridSize            : size of grid with tiles [nRows, nCols]
    %       imageSize           : nPixels for image in each tile [h, w]
    %       padding             : nPixels of padding between tiles (int) -- Not scale invariant :(
    %       tileConfiguration   : 'rowwise' (default) | 'columnwise'
    
    
        isFigCreated = false;
        if nargin == 0
            createFigure(obj)
            
        elseif ~isa(varargin{1}, 'matlab.ui.Figure') && ...
                    ~isa(varargin{1}, 'matlab.ui.container.Panel') && ...
                         ~isa(varargin{1}, 'matlab.ui.container.Tab')

            createFigure(obj)
            isFigCreated = true;
        else
            parent = varargin{1};
            varargin = varargin(2:end);

            obj.hFigure = ancestor(parent, 'figure');
            obj.hParent = parent;
        end

        if nargin > 0 && ~isempty(varargin)
            obj.parseVarargin(varargin)
        end

        createAxes(obj)

        % Initialize grid. 
        % The changeGridSize method also takes care of the initialization
        obj.changeGridSize()
        
        if isFigCreated; obj.fitFigure; end
        obj.IsConstructed = true;

        
        if ~nargout
            clear obj
        end

    end

    % % Destructor
    function delete(obj)
        if isvalid(obj.hAxes)
            delete(obj.hAxes)
        end
    end
    
end


methods (Access = private) % Methods for setting up gui
    
    function parseVarargin(obj, cellOfVarargin)

        fields = {'gridSize', 'padding', 'imageSize', 'tileConfiguration', ...
            'numChan', 'normalizedPadding', 'tileUnits', 'Visible'};

        isInputName = cellfun(@(argin) isa(argin, 'char'), cellOfVarargin);
        inputNames = cellOfVarargin(isInputName);
        arginInd = find(isInputName);

        for i = 1:numel(fields)
            if any(contains(inputNames, fields{i})) %contains(fields{i}, inputNames)
                match = contains(inputNames, fields{i});
                obj.(fields{i}) = cellOfVarargin{arginInd(match)+1};
            else
                continue
            end
        end

    end

    function createFigure(obj)

        % Create figure:
        obj.hFigure = figure('Visible', obj.Visible);
        obj.hFigure.MenuBar = 'none';
        obj.hFigure.KeyPressFcn = @obj.keypress;

        obj.hParent = obj.hFigure;
        
    end

    function createAxes(obj)
    %createAxes Create the axes for plotting tiles in
    
        obj.hAxes = axes(obj.hParent);
        obj.hAxes.Position = [0.02,0.02,0.96,0.96];
        hold(obj.hAxes, 'on')

        % Make sure axes is not visible
        set(obj.hAxes, 'xTick', [], 'YTick', []);
        obj.hAxes.XAxis.Visible = 'off';
        obj.hAxes.YAxis.Visible = 'off';
        obj.hAxes.Visible = 'off';

        % Since axes will hold image data, the yaxis is reversed.
        obj.hAxes.YDir = 'reverse';
        
        % Set colormap
        colormap(obj.hAxes, obj.tileConfiguration.DefaultColorMap)

        % Add a listener for axes position changes, which will require
        % internal updates.
        el = addlistener(obj.hAxes, 'Position', 'PostSet', ...
            @(s,e) obj.onAxesPositionChanged);
        obj.axesPositionChangedListener = el;
        
        if obj.debug
            obj.showAxesGrid()
        end
    end

    function showAxesGrid(obj)
    %showAxesGrid Show XGrid of axes (for debugging)
    
        obj.Axes.Visible = 'on';
        obj.Axes.XAxis.Visible = 'on';

        obj.Axes.XAxis.Color = 'r';%ones(1,3).*0.5;%'r';
        obj.Axes.XAxis.TickDirection = 'out';
        
        obj.Axes.XMinorTick = 'on';
        
        obj.Axes.XGrid = 'on';
        obj.Axes.XMinorGrid = 'on';
        obj.Axes.GridAlpha = 0.5;
        obj.Axes.MinorGridAlpha = 0.25;
        obj.Axes.MinorGridLineStyle = '--';
        
        obj.Axes.Layer = 'top';
    end
    
    function updateAxesLimits(obj)
    %updateAxesLimits % Update axes limits based on grid configuration
    
        if isempty(obj.hAxes); return; end % Skip during initialization
        
        numOriginalPixelsX = obj.pixelWidth ./ obj.scaleFactor(1);
        numOriginalPixelsY = obj.pixelHeight ./ obj.scaleFactor(2);

        % Set x- and y- limits according to the size of the original
        % (unscaled) image data (in pixel coordinates).
        obj.hAxes.XLim = ([0, numOriginalPixelsX] + 0.5 );
        obj.hAxes.YLim = ([0, numOriginalPixelsY] + 0.5 );
        obj.hAxes.XTick = obj.hAxes.XLim(1):5:obj.hAxes.XLim(2);

        % Place image data so that it fills the axes limits. This way, the
        % coordinates of the original data is kept.
        if ~isempty(obj.hImage)
            pixelSize = 1 ./ obj.scaleFactor;
            
            % Find positions where to place corner pixels of image in order
            % to fill out the x-limits and y-limits. Should be offset from
            % the limits by half a pixel size (scaled pixel units).
            xA = obj.hAxes.XLim(1) + pixelSize(1)/2;
            xB = obj.hAxes.XLim(2) - pixelSize(1)/2;
            
            yA = obj.hAxes.YLim(1) + pixelSize(2)/2;
            yB = obj.hAxes.YLim(2) - pixelSize(2)/2;
            
            obj.hImage.XData = [xA, xB] ;
            obj.hImage.YData = [yA, yB];
        end
        
        % Update axesRange property.
        obj.axesRange = [range(obj.hAxes.XLim), range(obj.hAxes.YLim)];
        
    end
    
    function configurePointerBehavior(obj)
    %configurePointerBehavior Configure behavior if mouse moves over a tile
        
        if isempty(obj.hTileOutline); return; end
        
        if obj.highlightTileOnMouseOver  % Add callback functions
            pointerBehavior = struct('enterFcn', [], 'exitFcn', [], 'traverseFcn', []);
            
            for i = 1:numel(obj.hTileOutline)
                pointerBehavior.enterFcn    = @(s,e,num)obj.onMouseEnteredTile(i);
                pointerBehavior.exitFcn     = @(s,e,num)obj.onMouseExitedTile(i);

                iptSetPointerBehavior(obj.hTileOutline(i), pointerBehavior);
            end
            
        else % Reset
            for i = 1:numel(obj.hTileOutline)
                iptSetPointerBehavior(obj.hTileOutline(i), []);
            end
            
        end
        
        iptPointerManager(obj.hFigure);
        
    end
    
    function updateGraphicsObjects(obj)
    %updateGraphicsObjects Create/update handles & positions of gobjects
    %
    %   Initializes and updates all handles that are used for plotting in
    %   tiles. Creates CData of the image object which will contain image
    %   data for all the plotted tiles, as well as boxes around each tiles
    %   and handles for adding lines or text to the interior of each tile.
    %
    %   NOTE! This function will reset any tilecallback functions that are
    %   assigned externally. % Todo: Should fix this...
    
        if isempty(obj.hAxes); return; end % Skip during initialization

        % Initialize empty image data.
        imdata = zeros(obj.pixelHeight, obj.pixelWidth, obj.numChan, 'uint8');
        
        
        % % Initialize/Update image object.
        if isempty(obj.hImage)
            obj.hImage = image(imdata, 'Parent', obj.hAxes);            
            obj.hImage.Visible = obj.Visible;
            obj.updateAxesLimits()
            
            % Add context menu to image.
            obj.hImage.UIContextMenu = uicontextmenu(obj.hFigure);
            applify.menu.createColormapList(obj.hImage.UIContextMenu, obj.hAxes)
        else
            obj.hImage.CData = imdata;
        end
        

        obj.hImage.AlphaData = zeros(obj.pixelHeight, obj.pixelWidth);

        % Set alphadata for all tile indices to 1. Effect: invisible
        % padding/spacing
        ind = cat(3, obj.tileIndices{:});
        obj.hImage.AlphaData(ind(:)) = 1;
        
        
        % % Initialize/update tile outline
        if isempty(obj.hTileOutline)
            obj.hTileOutline = obj.initializePlotHandles('patch', obj.nTiles);
        else
            obj.hTileOutline = obj.updateNumHandles(obj.hTileOutline, obj.nTiles);
        end
        
        % Set some properties on the tile outline handles.
        set(obj.hTileOutline, 'EdgeColor', ones(1,3)*0.7); 
        set(obj.hTileOutline, 'FaceAlpha', 0.05); 
        set(obj.hTileOutline, 'LineWidth', obj.tileLineWidth);
        set(obj.hTileOutline, 'Clipping', 'off')
        
        tileTags = arrayfun(@(i) num2str(i), 1:obj.nTiles, 'uni', 0);
        set(obj.hTileOutline, {'Tag'}, tileTags')
        
        % Set pointer behavior.
        if obj.highlightTileOnMouseOver
            obj.configurePointerBehavior()
        end
        
        % Create coordinates (xdata/ydata) for the outline of each tile.
        fullSize = [obj.pixelHeight, obj.pixelWidth];
        [xData, yData] = deal(cell(numel(obj.tileIndices), 1));
        
        for i = 1:numel(obj.tileIndices)

            upperLeft = obj.tileIndices{i}(1);
            [y0, x0] = ind2sub(fullSize, upperLeft);
            
            pixelSize = 1 ./ obj.scaleFactor;
            %x0 = x0 - pixelSize(1)/2;
            %y0 = y0 - pixelSize(2)/2;

            bbox = [x0, y0, obj.imageSize(2), obj.imageSize(1)];
            bbox = bbox ./ repmat(obj.scaleFactor, 1, 2);
            bbox(1:2) = bbox(1:2) - pixelSize/2;
            
            coords = obj.bbox2points(bbox) ;
            coords = coords + (obj.scaleFactor-1).*pixelSize/2; % dont understand this...

            % Calculate and update position 
            xData{i} = coords(:, 1);
            yData{i} = coords(:, 2);
            
            % Set additional props while looping to create xdata/ydata
            obj.hTileOutline(i).ButtonDownFcn = {@obj.selectTile, i};
            setappdata(obj.hTileOutline(i), 'OrigColor', ones(1,3)*0.7)
        end
        
        set(obj.hTileOutline, {'XData'}, xData, {'YData'}, yData)
        set(obj.hTileOutline, 'LineWidth', 3)
        
        % % Initialize/update text and plot handles
        
        if isempty(obj.hTileText)
            obj.hTileText = obj.initializePlotHandles('text', obj.nTiles);
        else
            obj.hTileText = obj.updateNumHandles(obj.hTileText, obj.nTiles);
        end
       
        if isempty(obj.hTilePlot)
            obj.hTilePlot = obj.initializePlotHandles('patch', obj.nTiles);
        else
            obj.hTilePlot = obj.updateNumHandles(obj.hTilePlot, obj.nTiles);
        end
        
        set(obj.hTileText, 'Tag', 'TileTextHandle')
        set(obj.hTilePlot, 'Tag', 'TilePlotHandle')
        
        % Update position of text based on gridsize and tile positions
        pixOffset = round(obj.imageSize(1).*0.05);
        newPos = arrayfun(@(i) [obj.tileCorners(i,:) + pixOffset, 0] ./ ...
                            [obj.scaleFactor, 1], 1:obj.nTiles, 'uni', 0);
        set(obj.hTileText, {'Position'}, newPos')
        
        % Reset plot data
        set(obj.hTilePlot, 'XData', nan, 'YData', nan)
        
    end
    
    function setTileIndices(obj)
    %setTileIndices Create indices for referencing data in tiles
    %
    %   This method is used for setting up an interface for easily updating
    %   data within individual tiles.
    %
    %   The following properties are set:
    %
    %       tileIndices  : Cell array of linear indices for each pixel in a
    %                      tile. Size is nRows x nCols
    %       tileCorners  : Matrix with x- and y- pixel coordinates for each
    %                      tile's corner. Size is nTiles x 2 (x = 1st col, 
    %                      y = 2nd col)
    %       tileCenters  : Not implemented here.
    %       tileIndexMap : A matrix with same size as the image object's
    %                      CData. The value of each element is the tile
    %                      number corresponding to the pixel at that
    %                      position. Pixels between tiles are set to NaN
    
        % Pixel coordinate for the position of rows and columns
        x0 = ((1:obj.nCols)-1) .* (obj.imageSize(2)+obj.pixelPadding) + 1;
        y0 = ((1:obj.nRows)-1) .* (obj.imageSize(1)+obj.pixelPadding) + 1;

        % Pixel coordinates for all pixels that are within rows/columns
        X = arrayfun(@(x) (x-1) + (1:obj.imageSize(2)), x0, 'uni', 0);
        Y = arrayfun(@(y) (y-1) + (1:obj.imageSize(1)), y0, 'uni', 0);

        % Determine the ordering of tiles based on the plotOrder property
        tileOrder = 1:obj.nRows*obj.nCols;
        switch obj.plotOrder
            case 'columnwise'
                tileOrder = reshape(tileOrder, obj.nRows, obj.nCols);
            case 'rowwise'
                tileOrder = reshape(tileOrder, obj.nCols, obj.nRows)';
        end

        % Flip upside down because image coordinates are flipped.
%             tileOrder = flipud(tileOrder); I dont remember why this was
%             commented out, but probably for a good reason.

        % Allocate property values.
        obj.tileIndices = cell(size(tileOrder));
        obj.tileCorners = zeros(numel(tileOrder), 2);
        fullSize = [obj.pixelHeight, obj.pixelWidth];
        obj.tileIndexMap = nan(fullSize);
        
        % Assign the values. This is done so that tileIndices are assigned
        % in either a row- or a column-based manner.
        for j = 1:size(tileOrder,1)
            for i = 1:size(tileOrder,2)
                [ii, jj] = meshgrid(X{i}, Y{j});
                obj.tileIndices{tileOrder(j,i)} = sub2ind(fullSize, jj, ii);
                obj.tileCorners(tileOrder(j,i), :) = [X{i}(1), Y{j}(1)];
                
                tileNum = tileOrder(j,i);
                obj.tileIndexMap(Y{j}, X{i}) = tileNum;
            end
        end
        
    end
    
    function h = initializePlotHandles(obj, hClass, n)
    %initializePlotHandles Create plot handles based on a class
    %
    %   This method is used for initializing plot handles on startup and
    %   creating more plot handles on request when the number of tiles
    %   change due to changes to grid-size.
    %
    %   Currently supports text, line and patches.
    
        switch hClass

            case {'text', 'matlab.graphics.primitive.Text'}

                h = text(ones(1,n), ones(1,n), '');
                set(h, 'Parent', obj.hAxes)
                set(h, 'Color', obj.tileConfiguration.TextColor) 
                set(h, 'FontSize', 12)
                set(h, 'VerticalAlignment', 'top')
                set(h, 'HitTest', 'off', 'PickableParts', 'none')
                set(h, 'Clipping', 'on')
                
            case {'line', 'matlab.graphics.chart.primitive.Line'}

                h = plot(nan(2,n), nan(2,n));
                set(h, 'Parent', obj.hAxes)
                
            case {'patch', 'matlab.graphics.primitive.Patch'}
                h = arrayfun(@(i) patch(obj.hAxes, nan, nan, 'w'), 1:n);
                %set(h, 'Parent', obj.hAxes)
                set(h, 'FaceAlpha', 0.01, 'LineWidth', 1, 'EdgeColor', 'w')

        end
        
        set(h, 'Visible', obj.Visible)


    end
    
    function handles = updateNumHandles(obj, handles, n)
    %updateNumHandles Update number of handles if gridsize changes
    %
    %   handles = updateNumHandles(obj, handles, n) updates the handles
    %   vector to contains n elements, either through adding or removing 
    %   handles
        
        if numel(handles) < n
            hClass = class(handles);
            newHandles = obj.initializePlotHandles(hClass, n-numel(handles));
            handles((numel(handles)+1):n) = newHandles;

        elseif numel(handles) > n
            delete( handles((n+1):end) )
            handles((n+1):end) = [];
        else
            return
        end

    end
    
    function changeGridSize(obj)
    %changeGridSize Take care of updates required when grid size is changed 
    
        if isempty(obj.hAxes); return; end % Skip during initialization
        
        % Todo: Update padding size based on pixel resolution.
        obj.updateAxesLimits()
        
        obj.setTileIndices()
        obj.updateGraphicsObjects()

        obj.updateTileLineWidth()
    end
    
    function updateTileLineWidth(obj)
    %updateTileLineWidth Update linewidth of outline based on tile's size
    %
    %   Set the line with for the tile's outline based on its "physical", 
    %   i.e pixel size.
    
        axesPixelPosition = getpixelposition(obj.Axes);
        obj.tilePixelSize = axesPixelPosition(3:4) ./ fliplr(obj.gridSize);
        obj.tileLineWidth = min([3, ceil( mean(obj.tilePixelSize) / 50 )]);
    
    end

    function makeFigureTight(obj)
    %makeFigureTight Set position of figure to wrap tighly around axes.
        
        obj.fitAxes()
        
        axesPixelPosition = getpixelposition(obj.hAxes);
        figPixelPosition = axesPixelPosition(3:4) + 2*axesPixelPosition(1:2);
        
        obj.hFigure.Position(3:4) = figPixelPosition;
                
    end
    
end


methods

    function tileNum = hittest(obj, x, y)
        
        if nargin < 3
            mousePoint = obj.Axes.CurrentPoint(1,2);
            mousePoint = round(mousePoint);
            x = mousePoint(1); y = mousePoint(2);
        end
        
        x = round(x .* obj.scaleFactor(1));
        y = round(y .* obj.scaleFactor(2));
        
        if x >= 1 && x <= obj.pixelWidth && y >= 1 && y <= obj.pixelHeight
            tileNum = obj.tileIndexMap(y, x);
        else
            tileNum = nan;
        end
    end

% % Methods to get dependent properties
    function nRows = get.nRows(obj)
        nRows = obj.gridSize(1);
    end


    function nCols = get.nCols(obj)
        nCols = obj.gridSize(2);
    end


    function pixelWidth = get.pixelWidth(obj)
%         pixelWidth = obj.nCols .* obj.imageSize(2) + ...
%                             (obj.nCols-1) .* obj.padding;
                        
        pixelWidth = obj.nCols .* obj.imageSize(2);
        pixelWidth = pixelWidth + obj.pixelPadding .* (obj.nCols-1);
    end


    function pixelHeight = get.pixelHeight(obj)
%          pixelHeight = obj.nRows .* obj.imageSize(1) + ...
%                             (obj.nRows-1) .* obj.padding;
                        
        pixelHeight = obj.nRows .* obj.imageSize(1);
        pixelHeight = pixelHeight + obj.pixelPadding .* (obj.nRows-1);
    end
    
    
    function pixelPadding = get.pixelPadding(obj)
        pixelPadding = round(obj.nRows .* obj.imageSize(1) .* obj.normalizedPadding);
        
    end


    function nTiles = get.nTiles(obj)
        nTiles = numel(obj.tileIndices);    
    end


    function hAx = get.Axes(obj)
        hAx = obj.hAxes;
    end
    

    function hFig = get.Figure(obj)
        hFig = obj.hFigure;
    end
    
    
    function pos = getTileOffset(obj, tileNum)
        
        %Position of tile center.
        
        fullSize = [obj.pixelHeight, obj.pixelWidth];
        
        [y, x] = ind2sub(fullSize, obj.tileIndices{tileNum} );
        tileCenter = [mean(x(:)), mean(y(:))];
        
        pos = tileCenter;
        
    end
    

    function pos = getTileCenter(obj, tileNum)
        
        %Position of tile center.
        
        fullSize = [obj.pixelHeight, obj.pixelWidth];
        
        [y, x] = ind2sub(fullSize, obj.tileIndices{tileNum} );
        tileCenter = [mean(x(:)), mean(y(:))];
        
        pos = tileCenter ./ obj.scaleFactor;
        
    end

    function pos = getTileCenterAxesCoords(obj, tileNum)
        
        %Position of tile center.
        
        pad = obj.pixelPadding ./ obj.scaleFactor;
        origImSize = obj.imageSize ./ obj.scaleFactor;
        
        iRow = ceil( tileNum / obj.nCols );
        iCol = mod(tileNum-1, obj.nCols)+1;
        
        pos = zeros(1,2);
        pos(1) = origImSize(2)*(iCol-1) + pad(1)*(iCol-1) + origImSize(2)/2;
        pos(2) = origImSize(1)*(iRow-1) + pad(2)*(iRow-1) + origImSize(1)/2;
        
        pos = pos + 0.5;
        
        return
        fullSize = [obj.pixelHeight, obj.pixelWidth];
        
        [y, x] = ind2sub(fullSize, obj.tileIndices{tileNum} );
        tileCenter = [mean(x(:)), mean(y(:))];
        
        pos = tileCenter ./ obj.scaleFactor;
        
    end
    
    
% % Methods to set properties
    function set.gridSize(obj, gridSize)

        validateattributes(gridSize, {'numeric'}, {'numel', 2})

        if any(obj.gridSize ~= gridSize)
            obj.gridSize = gridSize;
            obj.changeGridSize()
        end

    end

    function set.imageSize(obj, imageSize)
        validateattributes(imageSize, {'numeric'}, {'numel', 2})

        obj.imageSize = imageSize;
        obj.updateScaleFactor()
        obj.changeGridSize()

    end

    function set.tileUnits(obj, newValue)
        
        validatestring(newValue, {'pixel', 'scaled'});
        
        obj.tileUnits = newValue;
        obj.updateScaleFactor()
        
    end
    
    function set.Visible(obj, newValue)
        validatestring(newValue, {'on', 'off'});
        obj.Visible = newValue;
        
        obj.onVisibleChanged()
        
    end
    
    function set.tileLineWidth(obj, newValue)
        obj.tileLineWidth = newValue;
        obj.onTileStyleChanged()
    end
    
    function set.highlightTileOnMouseOver(obj, newValue)
        assert(isa(newValue, 'logical'), 'Property Value must be true or false')
        
        obj.highlightTileOnMouseOver = newValue;
        obj.configurePointerBehavior()
        
    end

    function fitAxes(obj)
    %fitAxes Todo: Rename, and make sure it does not exceed screen size...
    
        fullSize = [obj.pixelWidth, obj.pixelHeight];
        
        % Set position of axes to the same as the full size of the
        % imagedata.
        
        axUnits = obj.hAxes.Units;
        obj.hAxes.Units = 'pixel';
        obj.hAxes.Position(3:4) = fullSize;
        obj.hAxes.Units = axUnits;
    end
 
% % Reset imagedata, e.g before an update
    function resetAxes(obj)
    %resetAxes Reset children of axes. Useful before running updates.
        obj.hImage.CData(:) = 255;
        set(obj.hTilePlot, 'XData', nan, 'YData', nan)
        set(obj.hTileText, 'String', '')

    end
    
    function resetTile(obj, tileNum)
    %resetTile Reset graphic data in tiles given by tileNum
    %
    %   tileNum can be a vector or tileNumbers.
    
        % Todo: Avoid looping
        for i = tileNum
            obj.setTileOutlineColor(i)
            obj.removeTileImage(i)
        end
        
        set(obj.hTilePlot(tileNum), 'XData', nan, 'YData', nan)
        set(obj.hTileText(tileNum), 'String', '')
    end
    

% % Update image or plot data within a tile.
    
    function updateTileImage(obj, imdata, tileNum)
    %updateTileImage Update image data in given tile(s)
        
        [h, w, ~] = size(imdata);
        
        % Update imageSize_ property and scaleFactor.
        if ~isequal([h, w], obj.imageSize)
            imdata = imresize(imdata, obj.imageSize);
            obj.imageSize_ = [h, w];
            obj.updateScaleFactor()
            
            numOriginalPixelsX = obj.pixelWidth ./ obj.scaleFactor(1);
            numOriginalPixelsY = obj.pixelHeight ./ obj.scaleFactor(2);
        
            %obj.hAxes.XLim = ([0, numOriginalPixelsX] + 0.5 );
            %obj.hAxes.YLim = ([0, numOriginalPixelsY] + 0.5 );
            
        end
        
        
        % Update image data for the specified tiles.
        if obj.numChan == 1
            obj.hImage.CData([obj.tileIndices{tileNum}]) = imdata;
        else
            for i = 1:obj.numChan
                tmpIm = obj.hImage.CData(:, :, i);
                tmpIm( [obj.tileIndices{tileNum}] ) = imdata(:, :, i, :);
                obj.hImage.CData(:, :, i) = tmpIm;
            end 
        end
        obj.hImage.AlphaData([obj.tileIndices{tileNum}]) = 1;
        
    end
   

    function removeTileImage(obj, tileNum)

        
        if obj.numChan == 1
            obj.hImage.CData([obj.tileIndices{tileNum}]) = 0;
        else
            for i = 1:obj.numChan
                tmpIm = obj.hImage.CData(:, :, i);
                tmpIm( [obj.tileIndices{tileNum}] ) = 0;
                obj.hImage.CData(:, :, i) = tmpIm;
            end 
        end
        
        obj.hImage.AlphaData([obj.tileIndices{tileNum}]) = 0;
        
        
    end
    
    
    function updateTileText(obj, textString, tileNum, varargin)
    %updateTileText Update displayed text in given tile(s)
    %
    %   Input: textString : string or cell array of strings.
    
        if isa(textString, 'cell') && isrow(textString)
            textString = textString';
        end
        
        if isa(textString, 'char'); textString = {textString}; end
        
        set(obj.hTileText(tileNum), {'String'}, textString);
        
        if ~isempty(varargin)
            set(obj.hTileText(tileNum), varargin{:})
        end
        
    end
    
    
    function updateTilePlot(obj, xData, yData, tileNum)
    %updateTilePlot Update displayed plot in given tile(s)
    %
    %   Input:  xData : vector or cell array of vectors.
    %           yData : vector or cell array of vectors.
    
        % Shift plot coordinates to center of current tile
        fullSize = [obj.pixelHeight, obj.pixelWidth];
        
        for i = 1:numel(tileNum)
            [y, x] = ind2sub(fullSize, obj.tileIndices{tileNum(i)} );
            x = x ./ obj.scaleFactor(1);
            y = y ./ obj.scaleFactor(2);
            tileCenter = [mean(x(:)), mean(y(:))];
            
            tileCenter = obj.getTileCenter( tileNum(i) );
            tileCenter = obj.getTileCenterAxesCoords( tileNum(i) );
            
            % Calculate and update position 
            xData{i} = xData{i} + tileCenter(1);
            yData{i} = yData{i} + tileCenter(2);
            
            % Set movement limits.... Should that be done in caller?
            obj.hTilePlot(tileNum(i)).UserData.XLim = [min(x(:)), max(x(:))];
            obj.hTilePlot(tileNum(i)).UserData.YLim = [min(y(:)), max(y(:))];
            
        end
        
        % Update plot data
        if isrow(tileNum); tileNum = tileNum'; end
        if isrow(xData); xData = xData'; end
        if isrow(yData); yData = yData'; end
        
        set(obj.hTilePlot(tileNum), {'XData'}, xData, {'YData'}, yData)

    end

    
    function updateTilePlotLinewidth(obj, tileNum, lineWidth)
        set(obj.hTilePlot(tileNum), 'LineWidth', lineWidth')
    end
    
    
    % TODO: Rename these methods to setCallbacks
    function tileCallbackFcn(obj, funHandle, tileNum)
    %tileCallbackFcn Add a callback to mouse press within given tile.
        obj.hTileOutline(tileNum).ButtonDownFcn = funHandle;
    end

    function tilePlotButtonDownFcn(obj, funHandle, tileNum)
        obj.hTilePlot(tileNum).ButtonDownFcn = funHandle;
    end

    % % % Keypress callback
    
    function keypress(obj, ~, event)

        switch event.Key
            case 'return'
                if isfield( obj.hFigure.UserData, 'uiwait') && obj.hFigure.UserData.uiwait
                    uiresume(obj.hFigure)
                    obj.hFigure.UserData.uiwait = false;
                    obj.hFigure.UserData.lastKey = event.Key;
                end
            case 'escape'
                if isfield( obj.hFigure.UserData, 'uiwait') && obj.hFigure.UserData.uiwait
                    uiresume(obj.hFigure)
                    obj.hFigure.UserData.uiwait = false;
                end
        end

    end

    function ind = uiwait(obj)
    %uiwait Implements uiwait on the gui figure and returns selected tile ind   
    
    % Dont remember what this is used for.
    
        obj.hFigure.UserData.uiwait = true;
        uiwait(obj.hFigure)
        
        if isvalid(obj.hFigure)
        
            switch obj.hFigure.UserData.lastKey
                case 'return'
                    uiresume(obj.hFigure)
                    ind = obj.selectedTiles;
                    close(obj.hFigure)
                case 'escape'
                    uiresume(obj.hFigure)
                    ind = nan;
                    close(obj.hFigure)
            end
        else
            ind = nan;
        end
        
    end
    
    % % % User callbacks

    function selectTile(obj, ~, ~, tileNum)
    %selectTile Select tile on mousepress and change its color.
    
        % Todo: toggle select/unselect
    
        color = obj.tileConfiguration.SelectedTileColor;
        
        if ~isequal(obj.selectedTiles, tileNum) && ~isempty(obj.selectedTiles)
            setTileOutlineColor(obj, obj.selectedTiles)
        end
        
        obj.selectedTiles = tileNum;
        setTileOutlineColor(obj, obj.selectedTiles, color)

    end

    function setTileOutlineColor(obj, tileNum, color)
    %setTileOutlineColor Set color of tile outline
   
    % NB: Only works for one tile at a time.
    % Todo: Adapt to work for more than one tile.
        tmpH = obj.hTileOutline(tileNum);

        % Default color / no coloring of tile
        if nargin < 3 || isempty(color)
            tmpH.EdgeColor = obj.tileConfiguration.DefaultTileColor;
            tmpH.FaceAlpha = 0.05;
            tmpH.FaceColor = tmpH.EdgeColor;
            setappdata(tmpH, 'OrigColor',  obj.tileConfiguration.DefaultTileColor);

        % Custom color, tile is also colored.
        else
            tmpH.EdgeColor = color;
            tmpH.FaceAlpha = 0.4;
            tmpH.FaceColor = color;
            setappdata(tmpH, 'OrigColor', color);
        end

    end
    
    function setTextColor(obj, newColor)
        obj.tileConfiguration.TextColor = newColor;
        set(obj.hTileText, 'Color', newColor)
    end

    function setPlotVisibility(obj, mode)
        set(obj.hTilePlot, 'Visible', mode)
    end
    
    function setTileTransparency(obj, tileNum, alphaLevel)
        set(obj.hTileOutline(tileNum), 'FaceAlpha', alphaLevel)
    end
    
    
end


methods (Access = private) % Internal gui management
    
    function updateScaleFactor(obj)
    %updateScaleFactor Update internal scalefactor mapping pixels to coords
    %
    %   Tiled images are resized to fit the resolution of a tile. This is
    %   practical for internal updates, and it was the way the interface
    %   was originally constructed. However, this setup can create problems 
    %   when other interfaces are dependent on a specific coordinate system. 
    %   To keep backwards compatibility, pixel units and are used by
    %   default, but scaled units can be optionally used. This methods 
    %   updates the internal scalefactor.
    
        switch obj.tileUnits
            case 'scaled'
                newScaleFactor = obj.imageSize ./ obj.imageSize_;
            case 'pixel'
                newScaleFactor = [1, 1];
        end
        
        % This is a trainwreck solution. Calling change grid size will call
        % updateGraphicsObjects which will reset any tileCallback assigned
        % from external interface. Need to fix. BIG Todo!
        if any(obj.scaleFactor ~= newScaleFactor)
            obj.scaleFactor = newScaleFactor;
            % Todo: Change this. Dont need to change the whole grid, just axes
            % limits and update graphics object
            obj.changeGridSize()
        end
    end
    
    function onVisibleChanged(obj)
        
        if ~obj.IsConstructed; return; end

        set(obj.hImage, 'Visible', obj.Visible);
        set(obj.hTileOutline, 'Visible', obj.Visible);
        set(obj.hTilePlot, 'Visible', obj.Visible);
        set(obj.hTileText, 'Visible', obj.Visible);
        
    end
        
    function onTileStyleChanged(obj)
        if ~isempty(obj.hTileOutline)
            set(obj.hTileOutline, 'LineWidth', obj.tileLineWidth)
            %set(obj.hTileOutline, 'LineWidth', 1); % Todo: remove

        end
    end
    
    function onAxesPositionChanged(obj)
        obj.updateTileLineWidth()
    end

    function onMouseEnteredTile(obj, tileNum)
        tileColor = obj.hTileOutline(tileNum).EdgeColor;
        % Note: This is set on tile creation and updated if tile is
        % changed.
        %setappdata(obj.hTileOutline(tileNum), 'OrigColor', tileColor);
        obj.hTileOutline(tileNum).EdgeColor = min([tileColor+0.15; [1,1,1]]);
    end
    
    function onMouseExitedTile(obj, tileNum)
        tileColor = getappdata(obj.hTileOutline(tileNum), 'OrigColor');
        obj.hTileOutline(tileNum).EdgeColor = tileColor;        
    end
    
end

methods(Static)

    % Matlab function belonging to image processing toolbox. Should have
    % been a generic function....
    
    function points = bbox2points(bbox)
        % BBOX2POINTS Convert a rectangle into a list of points
        % 
        %   points = BBOX2POINTS(rectangle) converts a bounding box
        %   into a list of points. rectangle is either a single
        %   bounding box specified as a 4-element vector [x y w h],
        %   or a set of bounding boxes specified as an M-by-4 matrix.
        %   For a single bounding box, the function returns a list of 4 points 
        %   specified as a 4-by-2 matrix of [x,y] coordinates. For multiple
        %   bounding boxes the function returns a 4-by-2-by-M array of
        %   [x,y] coordinates, where M is the number of bounding boxes.
        %
        %   Class Support
        %   -------------
        %   bbox can be int16, uint16, int32, uint32, single, or double. 
        %   points is the same class as rectangle.
        %
        %   Example
        %   -------
        %   % Define a bounding box
        %   bbox = [10 20 50 60];
        %   
        %   % Convert the bounding box to a list of 4 points
        %   points = bbox2points(bbox);
        %
        %   % Define a rotation transformation
        %   theta = 10;
        %   tform = affine2d([cosd(theta) -sind(theta) 0; sind(theta) cosd(theta) 0; 0 0 1]);
        %
        %   % Apply the rotation
        %   points2 = transformPointsForward(tform, points);
        %
        %   % Close the polygon for display
        %   points2(end+1, :) = points2(1, :);
        %
        %   % Plot the rotated box
        %   plot(points2(:, 1), points2(:, 2), '*-');
        %
        %   See also affine2d, projective2d

        %#codegen
        
        validateattributes(bbox, ...
            {'int16', 'uint16', 'int32', 'uint32', 'single', 'double'}, ...
            {'real', 'nonsparse', 'nonempty', 'finite', 'size', [NaN, 4]}, ...
            'bbox2points', 'bbox');

        validateattributes(bbox(:, [3,4]), {'numeric'}, ...
            {'>=', 0}, 'bbox2points', 'bbox(:,[3,4])');
        

        numBboxes = size(bbox, 1);
        points = zeros(4, 2, numBboxes, 'like', bbox);

        % upper-left
        points(1, 1, :) = bbox(:, 1);
        points(1, 2, :) = bbox(:, 2);

        % upper-right
        points(2, 1, :) = bbox(:, 1) + bbox(:, 3);
        points(2, 2, :) = bbox(:, 2);

        % lower-right
        points(3, 1, :) = bbox(:, 1) + bbox(:, 3);
        points(3, 2, :) = bbox(:, 2) + bbox(:, 4);

        % lower-left
        points(4, 1, :) = bbox(:, 1);
        points(4, 2, :) = bbox(:, 2) + bbox(:, 4);
    end

end

end