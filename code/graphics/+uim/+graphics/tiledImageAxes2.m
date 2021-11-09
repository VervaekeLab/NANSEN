classdef tiledImageAxes2 < uim.handle
%clib.tiledImageAxes2
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


% Properties to configure axes layout (Default values are preset)
properties
    gridSize = [3, 5]           % [nRows, nCols]
    imageSize = [128, 128]      % [imHeight, imWidth] Size in px per tile
    padding = 10                % Number of pixels between each tile
    numChan = 1;

    normalizedPadding = 0.012;  % Padding between tiles in normalized units.
    
end


properties (Constant = true)
    plotOrder = 'rowwise' % columnwise 
end


properties % Settings

    tileConfiguration = struct('DefaultTileColor', ones(1,3)*0.7, ...
                               'SelectedTileColor', ones(1,3)*0.5, ...
                               'DefaultColorMap', 'viridis', ...
                               'TextColor', ones(1,3)*0.8 )
    highlightTileOnMouseOver = true
    
end


properties
    selectedTiles
end


properties (Access = private)
    tileCorners
    tileCenters
    tileIndices
    tileMap
    
    activeTile = nan
end


% Properties that depend on the layout configuration
properties (Dependent = true)
    Figure
    Axes
    nTiles
    nRows
    nCols
end


properties (Dependent = true, Access = private)    
    pixelWidth          % Number of pixels in x for the whole mosaic image
    pixelHeight         % Number of pixels in y for the whole mosaic image
    pixelPadding        % Number of pixels for padding between tiles.
end


% Properties for graphic handles
properties (Access = private)
    hParent
    hFigure
    hAxes
    hImage

    hTileText           % Handle for text object belonging to a tile
    hTilePlot           % Handle for line/patch object belonging to a tile
        
    hTileOutline        % Handle for tile outline
    mouseMotionListener
end


% Methods for setting up gui.
methods (Access = private)


    % Initialize figure/axes

    function createFigure(obj)

        % Create figure:
        obj.hFigure = figure();
        obj.hFigure.MenuBar = 'none';
        obj.hFigure.KeyPressFcn = @obj.keypress;

        obj.hParent = obj.hFigure;
        
    end


    function parseVarargin(obj, cellOfVarargin)

        fields = {'gridSize', 'padding', 'imageSize', 'tileConfiguration', 'numChan', 'normalizedPadding'};

        isInputName = cellfun(@(argin) isa(argin, 'char'), cellOfVarargin);
        inputNames = cellOfVarargin(isInputName);
        arginInd = find(isInputName);

        for i = 1:numel(fields)
            if contains(fields{i}, inputNames)
                match = contains(inputNames, fields{i});
                obj.(fields{i}) = cellOfVarargin{arginInd(match)+1};
            else
                continue
            end
        end

    end


    function createAxes(obj)

        % Create axes:
        obj.hAxes = axes('Parent', obj.hParent);
        obj.hAxes.Position = [0.02,0.02,0.96,0.96];

        hold(obj.hAxes, 'on')

        set(obj.hAxes, 'xTick', [], 'YTick', []);
        obj.hAxes.XAxis.Visible = 'off';
        obj.hAxes.YAxis.Visible = 'off';
        obj.hAxes.Visible = 'off';

        obj.hAxes.YDir = 'reverse';
        colormap(obj.hAxes, obj.tileConfiguration.DefaultColorMap)

    end


    function configureAxesLayout(obj)

        if isempty(obj.hAxes); return; end % Skip during initialization

        obj.hAxes.XLim = [1, obj.pixelWidth+1];
        obj.hAxes.YLim = [1, obj.pixelHeight+1];
        
        
        % Setting axes positions.... Seems to not be used.
%             obj.hParent.Position(3:4) = [obj.pixelWidth, obj.pixelHeight];
%         aspectR = obj.pixelWidth / obj.pixelHeight;
% 
%         parentUnits = obj.hParent.Units;
%         obj.hParent.Units = 'pixel';
%         axUnits = obj.hAxes.Units;
%         obj.hAxes.Units = 'pixel';
% 
%         margins = 10;
% 
%             if obj.hParent.Position(3)/obj.hParent.Position(4) > aspectR
%                 obj.hAxes.Position(4) = (obj.hParent.Position(4) - margins);
%                 obj.hAxes.Position(3) = (obj.hParent.Position(4) - margins) .* aspectR;
%                 obj.hAxes.Position(1) = (obj.hParent.Position(3) - obj.hAxes.Position(3))/2;
%             else
%                 obj.hAxes.Position(4) = obj.hAxes.Position(3) ./ aspectR;
%             end
% 
%         obj.hAxes.Units = axUnits;
%         obj.hParent.Units = parentUnits;

    end
    
    
    function updateGraphicsObjects(obj)

        % Initialize empty image data.
        imdata = ones(obj.pixelHeight, obj.pixelWidth, obj.numChan, 'uint8') * 0;

        
        % % Initialize/Update image object.
        if isempty(obj.hImage)
            obj.hImage = image(imdata, 'Parent', obj.hAxes);
            % Add context menu to image.
            obj.hImage.UIContextMenu = uicontextmenu(obj.hFigure);
            addColormapSelectionToMenu(obj.hImage.UIContextMenu, obj.hAxes)
        else
            obj.hImage.CData = imdata;
        end

        obj.hImage.AlphaData = zeros(obj.pixelHeight, obj.pixelWidth);

        % Set alphadata to all tile indices. Effect: invisible
        % padding/spacing
        ind = cat(3, obj.tileIndices{:});
        obj.hImage.AlphaData(ind(:)) = 1;
        
        
        % % Initialize/update tile outline
        
        if isempty(obj.hTileOutline)
            obj.hTileOutline = obj.initializePlotHandles('line', obj.nTiles);
        else
            obj.hTileOutline = obj.updateNumHandles(obj.hTileOutline, obj.nTiles);
        end
        
        
        switch class(obj.hTileOutline)
            case  'matlab.graphics.chart.Patch'
                % Set some properties on the tile outline handles.
                set(obj.hTileOutline, 'EdgeColor', ones(1,3)*0.7); 
                set(obj.hTileOutline, 'FaceAlpha', 0.05); 
            case 'matlab.graphics.chart.primitive.Line'
                set(obj.hTileOutline, 'Color', ones(1,3)*0.7); 

        end
        set(obj.hTileOutline, 'HitTest', 'off');
        set(obj.hTileOutline, 'PickablePart', 'none');
        set(obj.hTileOutline, 'LineWidth', 3);
        set(obj.hTileOutline, {'Tag'}, arrayfun(@(i) num2str(i), 1:obj.nTiles, 'uni', 0)')
        
        
        if obj.highlightTileOnMouseOver
            pointerBehavior = struct('enterFcn', [], 'exitFcn', [], 'traverseFcn', []);
            for i = 1:numel(obj.hTileOutline)
                pointerBehavior.enterFcn    = @(s,e,num)obj.onMouseEnteredTile(i);
                pointerBehavior.exitFcn     = @(s,e,num)obj.onMouseExitedTile(i);

                iptSetPointerBehavior(obj.hTileOutline(i), pointerBehavior);
            end
            iptPointerManager(obj.hFigure);
        end
        
        
        fullSize = [obj.pixelHeight, obj.pixelWidth];
        [xData, yData] = deal(cell(numel(obj.tileIndices), 1));
        
        
        for i = 1:numel(obj.tileIndices)
            upperLeft = obj.tileIndices{i}(1);
            [y0, x0] = ind2sub(fullSize, upperLeft);
            
            bbox = [x0, y0, obj.imageSize(2), obj.imageSize(1)];
            coords = uim.graphics.tiledImageAxes2.bbox2points(bbox);
            
            % Calculate and update position 
            xData{i} = coords(:, 1);
            yData{i} = coords(:, 2);
            
            %obj.hTileOutline(i).ButtonDownFcn = {@obj.selectTile, i};
        end
        
        set(obj.hTileOutline, {'XData'}, xData, {'YData'}, yData)
        

        % % Initialize/update text and plot handles
        
        if isempty(obj.hTileText)
            obj.hTileText = obj.initializePlotHandles('text', obj.nTiles);
        else
            obj.hTileText = obj.updateNumHandles(obj.hTileText, obj.nTiles);
        end
       
        if isempty(obj.hTilePlot)
            obj.hTilePlot = obj.initializePlotHandles('line', obj.nTiles);
        else
            obj.hTilePlot = obj.updateNumHandles(obj.hTilePlot, obj.nTiles);
        end
        set(obj.hTilePlot, 'Tag', 'TilePlotHandle')
        
        
        % Update position of text based on gridsize and tile positions
        pixOffset = round(obj.imageSize(1).*0.05);
        newPos = arrayfun(@(i) [obj.tileCorners(i,:) + pixOffset, 0], 1:obj.nTiles, 'uni', 0);
        set(obj.hTileText, {'Position'}, newPos')
        
        % Reset plot data
        set(obj.hTilePlot, 'XData', nan, 'YData', nan)
        
    end


    function setTileIndices(obj)

        x0 = ((1:obj.nCols)-1) .* (obj.imageSize(2)+obj.pixelPadding) + 1;
        y0 = ((1:obj.nRows)-1) .* (obj.imageSize(1)+obj.pixelPadding) + 1;

        X = arrayfun(@(x) (x-1) + (1:obj.imageSize(2)), x0, 'uni', 0);
        Y = arrayfun(@(y) (y-1) + (1:obj.imageSize(1)), y0, 'uni', 0);

        tileOrder = 1:obj.nRows*obj.nCols;
        switch obj.plotOrder
            case 'columnwise'
                tileOrder = reshape(tileOrder, obj.nRows, obj.nCols);
            case 'rowwise'
                tileOrder = reshape(tileOrder, obj.nCols, obj.nRows)';
        end

        % Flip upside down because image coordinates are flipped.
%             tileOrder = flipud(tileOrder);

        obj.tileIndices = cell(size(tileOrder));
        obj.tileCorners = zeros(numel(tileOrder), 2);
        fullSize = [obj.pixelHeight, obj.pixelWidth];
        
        obj.tileMap = nan(fullSize);
        tileNum = 0;
        for j = 1:size(tileOrder,1)
            for i = 1:size(tileOrder,2)
                [ii, jj] = meshgrid(X{i}, Y{j});
                obj.tileIndices{tileOrder(j,i)} = sub2ind(fullSize, jj, ii);
                obj.tileCorners(tileOrder(j,i), :) = [X{i}(1), Y{j}(1)];
                
                tileNum = tileNum+1;
                obj.tileMap(Y{j}, X{i}) = tileNum;
            end
        end
    end
    
    function tileNum = hittest(obj)
        mousePoint = obj.Axes.CurrentPoint(1,2);
        mousePoint = round(mousePoint);
        x = mousePoint(1); y = mousePoint(2);
        
        if x >= 1 && x <= obj.pixelWidth && y >= 1 && y <= obj.pixelHeight
            tileNum = obj.tileMap(mousePoint(2), mousePoint(1));
        else
            tileNum = nan;
        end
    end
    
    
    % % Initialize plot handles.
    function h = initializePlotHandles(obj, hClass, n)

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

    end
    
    
    function handles = updateNumHandles(obj, handles, n)
    %updateNumHandles Update number of handles if gridsize changes

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
    
    
     % % Update gridsize
    function changeGridSize(obj)
        
        if isempty(obj.hAxes); return; end % Skip during initialization

        % Update padding size based on pixel resolution.
        
        configureAxesLayout(obj)
        
        obj.setTileIndices()
        obj.updateGraphicsObjects()
        
    end
    
    
end


methods

% % Constructor
    function obj = tiledImageAxes2(varargin)
    %tiledImageAxes2 Crate and configure the tileImageAxes object
    %   
    %   tiledImageAxes2 Creates a tiled image axes in a new figure.
    %
    %   tiledImageAxes2(parent) Creates a tiled images axes in an existing
    %   figure or uipanel.
    %
    %   tiledImageAxes2(..., Name, Value) creates a tiled images given
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
            
        elseif ~isa(varargin{1}, 'matlab.ui.Figure') && ~isa(varargin{1}, 'matlab.ui.container.Panel')
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
        
        if obj.highlightTileOnMouseOver
            el = listener(obj.hFigure, 'WindowMouseMotion', @obj.onMouseMotion);
            obj.mouseMotionListener = el;
        end
        
        if ~nargout
            clear obj
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
    
    
% % Methods to set properties
    function set.gridSize(obj, gridSize)

        validateattributes(gridSize, {'numeric'}, {'numel', 2})
        
        obj.gridSize = gridSize;
        
        obj.changeGridSize()

    end


    function set.imageSize(obj, imageSize)
        validateattributes(imageSize, {'numeric'}, {'numel', 2})

        obj.imageSize = imageSize;
        obj.changeGridSize()

    end


    function fitFigure(obj)
        
%         fullSize = [obj.pixelWidth, obj.pixelHeight];
%         obj.hFigure.Position(3:4) = fullSize;
%         
        obj.fitAxes()
        
        axUnits = obj.hAxes.Units;
        obj.hAxes.Units = 'pixel';
        
        figPos = obj.hAxes.Position(3:4) + 2*obj.hAxes.Position(1:2);
        obj.hFigure.Position(3:4) = figPos;
        
        obj.hAxes.Units = axUnits;

        
    end
    
    
    function fitAxes(obj)
        fullSize = [obj.pixelWidth, obj.pixelHeight];
        axUnits = obj.hAxes.Units;
        obj.hAxes.Units = 'pixel';
        obj.hAxes.Position(3:4) = fullSize;
        obj.hAxes.Units = axUnits;
    end
 

% % Reset imagedata, e.g before an update
    function resetAxes(obj)

        obj.hImage.CData(:) = 255;
        set(obj.hTilePlot, 'XData', nan, 'YData', nan)
        set(obj.hTileText, 'String', '')

    end
    

    function resetTile(obj, tileNum)
    %resetTile Reset graphic data in tiles given by tileNum
    
        % Todo: Avoid looping
        for i = tileNum
            obj.setTileOutlineColor(i)
            obj.removeTileImage(i)
        
            set(obj.hTilePlot(i), 'XData', nan, 'YData', nan)
            set(obj.hTileText(i), 'String', '')
        end
    end
    

% % Update image or plot data within a tile.
    
    function updateTileImage(obj, imdata, tileNum)
    %updateTileImage Update image data in given tile(s)
        
        [h, w, ~] = size(imdata);
    
        if ~isequal([h, w], obj.imageSize)
            imdata = imresize(imdata, obj.imageSize);
        end
        
% % %         % Faster updating:
% % %         obj.hImage.CData([obj.tileIndices{tileNum}]) = imdata;
% % %         obj.hImage.AlphaData([obj.tileIndices{tileNum}]) = 1;
        
         % Faster updating:
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
        
        
        
        
%         tic
%         for i = tileNum
%             obj.hImage.CData(obj.tileIndices{i}) = imdata(:, :, i);
%             obj.hImage.AlphaData(obj.tileIndices{i}) = 1;
%         end
%         toc
        
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
            tileCenter = [mean(x(:)), mean(y(:))];
            
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

%             obj.hFigure.SelectionType

    end


    function setTileOutlineColor(obj, tileNum, color)

        tmpH = obj.hTileOutline(tileNum);

        switch class(tmpH)
            case 'matlab.graphics.primitive.Patch'
                % Default color / no coloring of tile
                if nargin < 3 || isempty(color)
                    tmpH.EdgeColor = obj.tileConfiguration.DefaultTileColor;
                    tmpH.FaceAlpha = 0.05;
                    tmpH.FaceColor = tmpH.EdgeColor;

                % Custom color, tile is also colored.
                else
                    tmpH.EdgeColor = color;
                    tmpH.FaceAlpha = 0.4;
                    tmpH.FaceColor = color;
                end
            case 'matlab.graphics.primitive.chart.Line'
                if nargin < 3 || isempty(color)
                    tmpH.Color = obj.tileConfiguration.DefaultTileColor;
                else
                    tmpH.Color = color;
                end
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
        if isa(obj.hTileOutline, 'matlab.graphics.primitive.Patch')
            set(obj.hTileOutline(tileNum), 'FaceAlpha', alphaLevel)
        end
        
    end
    
    
end


methods (Access = private) % Internal gui management
    
    function point = getAxesCurrentPoint(obj, hFig)
        
        % More work needed. E.g. wehn axis equal is used, the pixelposition
        % property of the axes is not correct.
        % Also, need to flag so that position values are updated if they
        % change.
        
        persistent figSize axSize xRange yRange
        if isempty(figSize)
            figSize = hFig.Position(3:4);
        end
        
        if isempty(axSize)
            axSize = getpixelposition(obj.Axes);
            axSize = axSize(3:4);
        end
        
        if isempty(xRange)
            xRange = range(obj.Axes.XLim);
        end
        
        if isempty(yRange)
            yRange = range(obj.Axes.YLim);
        end
        
        aa = hFig.CurrentPoint;
        bb = aa  - (figSize .* [0.01,0.01]);
        
        point = bb ./ axSize .* [xRange, yRange];
        
    end
    
    
    
    function onMouseMotion(obj, src, event)
        
        % Getting the current point from the axes property is slow. Is it
        % quicker to compute it manually? From figure's current point, axes
        % position and limits. Using persistent properties...
        
        %point = getAxesCurrentPoint(obj, src);
        
        mousePoint = obj.Axes.CurrentPoint(1, 1:2);
        mousePoint = round(mousePoint);
        x = mousePoint(1); y = mousePoint(2);
        
        if x >= 1 && x <= obj.pixelWidth && y >= 1 && y <= obj.pixelHeight
            tileNum = obj.tileMap(mousePoint(2), mousePoint(1));
        else
            tileNum = nan;
        end
        
        
        if ~isnan(obj.activeTile) && obj.activeTile ~= tileNum
            % Mouse left tile
            obj.onMouseExitedTile(obj.activeTile)
            obj.activeTile = nan;
        end
        
        if isnan(obj.activeTile) && ~isnan(tileNum)
            obj.onMouseEnteredTile(tileNum)
            obj.activeTile = tileNum;
        end
        
        
    end
    
    
    function onMouseEnteredTile(obj, tileNum)
        
        switch class(obj.hTileOutline)
            case  'matlab.graphics.chart.Patch'
                propName = 'EdgeColor';
            case 'matlab.graphics.chart.primitive.Line'
                propName = 'Color';
        end
        
        tileColor = obj.hTileOutline(tileNum).(propName);
        setappdata(obj.hTileOutline(tileNum), 'OrigColor', tileColor);
        obj.hTileOutline(tileNum).(propName) = min([tileColor+0.15; [1,1,1]]);

    end
    
    function onMouseExitedTile(obj, tileNum)
        
        switch class(obj.hTileOutline)
            case  'matlab.graphics.chart.Patch'
                propName = 'EdgeColor';
            case 'matlab.graphics.chart.primitive.Line'
                propName = 'Color';
        end
        
        tileColor = getappdata(obj.hTileOutline(tileNum), 'OrigColor');
        obj.hTileOutline(tileNum).(propName) = tileColor;
        
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
        
        points(5, :, :) = points(1, :, :);
        points(6, :, :) = points(2, :, :);

        
    end

end

end