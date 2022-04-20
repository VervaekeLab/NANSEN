function [S, L] = getImageSubsetBounds(imSize, x, y, r, padding, varargin)
%getImageSubsetBounds Get bounds for an image subset at point
%
%   [S, L] = getImageSubsetBounds(imSize, x, y, r, pad, name, value)
%
%   INPUTS: 
%       imSize : size of image containing point (x,y)
%       x : center coordinate of roi along x-axis
%       y : center coordinate of roi along y-axis
%       r : radius of roi ( integer for square, 2x1 [r_y, r_x] for
%       rectangle )
%       padding : optional extra padding for image (default = 0)
%           
%   OUTPUTS: 
%       S : smaller bound (xmin, ymin)
%       L : larger bound (xmax, ymax)
%
%   OPTIONS:
%       boundaryMethod : 'none' (default) or 'crop'. If crop, limits are
%       forced to be within image boundaries.


%   % Todo: make padding part of options.

    param = struct();
    param.boundaryMethod = 'crop';
    param = utility.parsenvpairs(param, [], varargin);
    
    if numel(r)==1
        r = [r,r];
    end
    
    % Round values because output should be in pixel indices
    x = round(x);
    y = round(y);
    rExtended = round( r+padding );
    
    % Compute boundary limits
    xMin = x - rExtended(2);
    yMin = y - rExtended(1);
    xMax = x + rExtended(2);
    yMax = y + rExtended(1);
    
    if strcmp(param.boundaryMethod, 'none')
        % pass
    elseif strcmp(param.boundaryMethod, 'crop')
        % Make sure bounds are within image
        xMin = max( [xMin, 1] ); 
        yMin = max( [yMin, 1] ); 
        xMax = min( [xMax, imSize(2)] );
        yMax = min( [yMax, imSize(1)] );
    else
        warning('Unknown boundary method')
    end
    
    % Assign Output
    S = [xMin, yMin];
    L = [xMax, yMax];

    % Make sure limits are same datatype
    S = double(S);
    L = double(L);
end