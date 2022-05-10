function [tileIndices, tileCorners, tileIndexMap] = ...
    setTileIndices(nRows, nCols, imageSize, pixelPadding, plotOrder)
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

    if nargin < 5
        plotOrder = 'rowwise';
    end
    
    pixelWidth = nCols .* imageSize(2);
    pixelWidth = pixelWidth + pixelPadding .* (nCols-1);          
    pixelHeight = nRows .* imageSize(1);
    pixelHeight = pixelHeight + pixelPadding .* (nRows-1);


    % Pixel coordinate for the position of rows and columns
    x0 = ((1:nCols)-1) .* (imageSize(2)+pixelPadding) + 1;
    y0 = ((1:nRows)-1) .* (imageSize(1)+pixelPadding) + 1;

    % Pixel coordinates for all pixels that are within rows/columns
    X = arrayfun(@(x) (x-1) + (1:imageSize(2)), x0, 'uni', 0);
    Y = arrayfun(@(y) (y-1) + (1:imageSize(1)), y0, 'uni', 0);

    % Determine the ordering of tiles based on the plotOrder property
    tileOrder = 1:nRows*nCols;
    switch plotOrder
        case 'columnwise'
            tileOrder = reshape(tileOrder, nRows, nCols);
        case 'rowwise'
            tileOrder = reshape(tileOrder, nCols, nRows)';
    end

    % Flip upside down because image coordinates are flipped.
%             tileOrder = flipud(tileOrder); I dont remember why this was
%             commented out, but probably for a good reason.

    % Allocate property values.
    tileIndices = cell(size(tileOrder));
    tileCorners = zeros(numel(tileOrder), 2);
    fullSize = [pixelHeight, pixelWidth];
    tileIndexMap = nan(fullSize);

    % Assign the values. This is done so that tileIndices are assigned
    % in either a row- or a column-based manner.
    for j = 1:size(tileOrder,1)
        for i = 1:size(tileOrder,2)
            [ii, jj] = meshgrid(X{i}, Y{j});
            tileIndices{tileOrder(j,i)} = sub2ind(fullSize, jj, ii);
            tileCorners(tileOrder(j,i), :) = [X{i}(1), Y{j}(1)];

            tileNum = tileOrder(j,i);
            tileIndexMap(Y{j}, X{i}) = tileNum;
        end
    end

    if nargout == 1
        clear tileCorners tileIndexMap
    elseif nargout == 2
        clear tileIndexMap
    end

end
