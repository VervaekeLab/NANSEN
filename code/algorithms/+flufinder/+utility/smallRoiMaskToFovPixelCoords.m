function varargout = smallRoiMaskToFovPixelCoords(roiMask, fovSize, roiCenter)
%smallRoiMaskToFovPixelCoords Get pixel coordinates in fov of small roi mask
%
%   coords = smallRoiMaskToFovPixelCoords(roiMask, fovSize, roiCenter)
%   returns the pixel coordinates of a small (cropped) roi mask.
%
%   INPUTS:
%       roiMask : a cropped roimask
%       fovSize : Size of the FOV
%       roiCenter : Center coordinates of the roimask in the fov (x,y)
%
%   OUTPUT:
%       coords : coordinates (numPoints x 2). X is 1st col, Y is 2nd col

    [Y, X] = find(roiMask);

    xCoords = roiCenter(1) + X;
    yCoords = roiCenter(2) - Y;

    keepX = xCoords >= 1 & xCoords <= fovSize(2);
    keepY = yCoords >= 1 & yCoords <= fovSize(1);
    keep = keepX & keepY;
 
    if nargout == 1
        varargout{1} = [xCoords(keep), yCoords(keep)];
    elseif nargout == 2
        varargout{1} = xCoords(keep);
        varargout{2} = yCoords(keep);
    else
        error('Too many output arguments')
    end
end
