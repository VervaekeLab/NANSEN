function fovMask = placeLocalRoiMaskInFovMask(roiMask, roiCenter, fovMask)
%placeLocalRoiMaskInFovMask Place a local roi mask in a global fov mask
%
%   fovMask = placeLocalRoiMaskInFovMask(roiMask, roiCenter, fovMask)
%   places the roiMask in the fovMask centered on the coordinates given by
%   roiCenter.
%
%   INPTUS:
%       roiMask   : Local mask of RoI (height x with)
%       roiCenter : Pixel coordinates of center of roiMask in the fovMask (x, y)
%       fovMask   : Global mask for the whole FoV (fovHeight x fovWidth)
%
%   OUTPUT:
%       fovMask   : Global mask for the whole FoV (fovHeight x fovWidth)
    
    roiImageSize = size(roiMask);
    fovImageSize = size(fovMask);

    % Get indices centered on origo
    indX = (1:roiImageSize(2)) - ceil(roiImageSize(2)/2);
    indY = (1:roiImageSize(1)) - ceil(roiImageSize(1)/2);
    
    % Offset the coordinates to the roi center.
    indX = round( indX + roiCenter(1) );
    indY = round( indY + roiCenter(2) );
    
    % Make sure all coordinates are valid (might not be the case close to
    % edges of the fov).
    isValidX = indX >= 1 & indX <= fovImageSize(2);
    isValidY = indY >= 1 & indY <= fovImageSize(1);
    
    % Place the roi mask
    fovMask(indY(isValidY), indX(isValidX)) = roiMask(isValidY, isValidX);

end
