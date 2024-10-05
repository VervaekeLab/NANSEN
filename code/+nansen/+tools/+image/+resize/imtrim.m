function [imArrayOut, yLim, xLim] = imtrim(imArrayIn, backgroundValue, polarity, mode)
%imtrim  Trim away background around image borders
%
% imArrayOut = imtrim(imArrayIn) crops images so that all excessive
% background along the borders are removed. By default, the background
% value is zero. imArray is a 2D or 3D array
%
% imArrayOut = imtrim(imArrayIn, backgroundValue) crops all pixels which
% value is below the background value
%
%   NOTE: If a 3D array is provided, the trimming is done based on the
%   first image frame of the array. Therefore, do not use this function if
%   trimming should be dependent on all frames of a stack

    if nargin < 2 || isempty(backgroundValue);  backgroundValue = 0;    end
    if nargin < 3 || isempty(polarity);         polarity = 'dark';      end
    if nargin < 4 || isempty(mode);             mode = 'ne';            end
    
    % todo: get bg value automatically from polarity and data type
    % todo: convert operators '<=' etc to function names
    
    mode = validatestring(mode, {'ne', 'ge', 'gt', 'le', 'lt'});
    op = str2func(mode);
    
    val = cast(backgroundValue, 'like', imArrayIn);
    
    % Crop left and right
    [height, width, ~] = size(imArrayIn);
    imRef = imArrayIn(:, :, 1);

    A = arrayfun(@(i) find( op(imRef(i, :), val), 1, 'first')-1, 1:height, 'uni', 0 );
    B = arrayfun(@(i) find( op(imRef(i, :), val), 1, 'last')+1, 1:height, 'uni', 0);

    cropLeft = min([A{:}]);
    cropRight = max([B{:}]);
    
    if cropLeft == 0; cropLeft = 1; end
    if cropRight > width; cropRight = width; end

    imArrayOut = imArrayIn(:, cropLeft:cropRight, :);

    % Crop top and bottom
    [height, width, ~] = size(imArrayOut);
    imRef = imArrayOut(:, :, 1);

    C = arrayfun(@(i) find( op(imRef(:, i), val), 1, 'first')-1, 1:width, 'uni', 0 );
    D = arrayfun(@(i) find( op(imRef(:, i), val), 1, 'last')+1, 1:width, 'uni', 0 );

    cropTop = min([C{:}]);
    cropBot = max([D{:}]);
    if cropTop == 0; cropTop = 1; end
    if cropBot > height; cropBot = height; end

    imArrayOut = imArrayOut(cropTop:cropBot, :, :);
    
    if nargout > 1
        yLim = [cropTop, cropBot];
        xLim = [cropLeft, cropRight];
    end
end
