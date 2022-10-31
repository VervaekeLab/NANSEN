function shiftedRoiArray = warpRois(roiArray, fovShifts)
%warpRois Change roi positions based on shifts from image registration.
%   shiftedRoiArray = warpRois(roiArray, sessionFovShifts)
%       
%   fovShifts is a struct which is created by alignSessionFov. 
%   NB: This function should be called once for each of the elements in
%   fovShifts if fovShifts is a struct array.
%
%   See also: alignSessionFov

% Todo: Check if rois end up outside of or on the image border.
% Todo: Test with a smiluated case the the rotation is the right way.

nRois = numel(roiArray);

shiftedRoiArray = roiArray;
    
% Get the number of patches/squares of nonrigid displacements.s
fovShifts.ShiftsNr.shifts_up = imresize(fovShifts.ShiftsNr.shifts, roiArray(1).imagesize);
[nrows, ncols, ~, ~] = size(fovShifts.ShiftsNr.shifts_up);


% Go through each roi and find how much it should be shifted.
for i = 1:nRois

%     if i == 39
%         disp('debug')
%     end
    
    % Get the center of the roi object.
    roi = roiArray(i);
    imCenter = roi.imagesize/2;
    centerOld = roi.center;
    
    % 1. Add rigid shifts.
    centerNew = centerOld + fovShifts.ShiftsRig; % (x, y)
    
    % 2. Add rotation shifts.
    [th, rho] = cart2pol(centerNew(1)-imCenter(2), centerNew(2)-imCenter(1));
    th = th - deg2rad(fovShifts.ShiftsRot); % Add the angular shift
    [centerNew(1), centerNew(2)] = pol2cart(th, rho); % TODO: Check if angle should be added or subtracted.
    centerNew = centerNew + fliplr(imCenter);
    
    % 3. Add nonrigid shift. First, determine which subsquare the roi belongs
%     % to in the array of shifts.
%     offset = [fovShifts.CropLR(1), fovShifts.CropUD(1)]; % offset du to cropping of images before nonrigid alignment
%     roiNrSub = floor( fliplr(centerNew-offset) ./  (fovShifts.NrShiftsSz ./ [nrows, ncols] ) ) + [1,1] ;
    
    roiNrSub = fliplr(round(centerNew)); % y, x position in matrix.

    if roiNrSub(1) < 1; roiNrSub(1) = 1; end
    if roiNrSub(2) < 1; roiNrSub(2) = 1; end
    if roiNrSub(1) > ncols; roiNrSub(1) = ncols; end
    if roiNrSub(2) > nrows; roiNrSub(2) = nrows; end
    
    % Find the nonrigid shifts for the part of the image which roi belongs to.
    % flip left right because normcorre shifts are y, x.
    nrShift = fliplr( squeeze( fovShifts.ShiftsNr.shifts_up(roiNrSub(1), roiNrSub(2), 1, :))');
    
    centerNew = centerNew + nrShift;
    
    % The calculated new position is actually the shift of the image. The
    % roi needs to be shifted the other way.
    roiShift = centerOld - centerNew;
    shiftedRoiArray(i) = roi.move(roiShift);

end


isEmpty = arrayfun(@(roi) isempty(roi.boundary), shiftedRoiArray);
shiftedRoiArray(isEmpty) = [];
    
end

