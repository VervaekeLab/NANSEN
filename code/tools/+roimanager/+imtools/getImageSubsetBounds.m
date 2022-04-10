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
    
    xMin = round(x-rExtended(2));
    yMin = round(y-rExtended(2));
    xMax = round(x+rExtended(1));
    yMax = round(y+rExtended(1));
    
    if strcmp(param.boundaryMethod, 'none')
        % pass
    else
        % Make sure bounds are within image
        xMin = max( [xMin, 1] ); 
        yMin = max( [yMin, 1] ); 
        xMax = min( [xMax, imSize(2)] );
        yMax = min( [yMax, imSize(1)] );
    end
    
    
    % Assign Output
    S = [xMin, yMin];
    L = [xMax, yMax];

    % Make sure limits are same datatype
    S = double(S);
    L = double(L);
end