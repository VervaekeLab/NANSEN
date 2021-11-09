function [S, L] = getImageSubsetBounds(imSize, x, y, r, padding, varargin)
%getImageSubsetBounds Get bounds for an image subset at point
%
%   [S, L] = getImageSubsetBounds(imSize, x, y, r, pad)
%           
%   Outputs: S = smaller bound, L = larger bound


    % Should this function always return the same size or should it return
    % a assymmetric box relative to center if the point is too close to the
    % edges of the image?

    param = struct();
    param.boundaryMethod = ''; 
    param = utility.parsenvpairs(param, [], varargin);
    
    
    rExtended = r+padding;
    
    % Make sure bounds are within image
    xMin = max( [round(x-rExtended), 1] ); 
    yMin = max( [round(y-rExtended), 1] ); 
    xMax = min( [round(x+rExtended), imSize(2)] );
    yMax = min( [round(y+rExtended), imSize(1)] );
    
    % Assign Output
    S = [xMin, yMin];
    L = [xMax, yMax];

end