function [roiMask, npMask] = getMasks(roiArray, roiInd, imageMask, param)
%getMasks Return modified roi mask and surrounding neuropil mask
%
% TODO: Fix neuropil mask generation. (sometimes it got stuck in the loop forever)



% % def = struct(...
% %     'roiNeuropilSeparation', 0, ...
% %     'neuropilExpansionFactor', 4 ...
% %     );
% % 
% % 
% % param = parsenvpairs(def, [], varargin);




% Check if roiArray input is a RoI/struct or an array of masks
if isa(roiArray, 'RoI') || isa(roiArray, 'struct')
    [height, width] = size(roiArray(1).mask);
%     roiMaskOrig = roiArray(roiInd).mask;
    roiMaskArray = cat(3, roiArray.mask);

elseif isa(roiArray, 'logical') 
    [height, width, ~] = size(roiArray);
%     roiMaskOrig = roiArray(:, :, roiInd);
    roiMaskArray = roiArray;
else
    error('roiArray is wrong class, should be RoI array, struct array or a logical array of masks')
end



% Set default values to 3rd and 4th input.
if nargin < 3 || isempty(imageMask); imageMask = true(height, width); end
if nargin < 4 || isempty(param)
    neuropilExpansionFactor = 4;
    roiNeuropilSeparation = 0;
else
    neuropilExpansionFactor = param.neuropilExpansionFactor;
    roiNeuropilSeparation = param.roiNeuropilSeparation;
end


% preallocate logical arrays for output.
if nargout == 1
    roiMask = false(height, width, numel(roiInd));
elseif nargout == 2
    [roiMask, npMask] = deal(false(height, width, numel(roiInd)));
end


% Create an array with all rois overlapping.
footprintAllRois = sum(roiMaskArray, 3);

% Loop through rois
for n = 1:numel(roiInd)
    
    currentRoiInd = roiInd(n);
    currentRoiMask = roiMaskArray(:, :, currentRoiInd);
    
    maskAllOtherRois = logical(footprintAllRois - currentRoiMask);
    
    % Remove surrounding rois from the roi mask
    roiMask(:, :, n) = currentRoiMask & xor(currentRoiMask, maskAllOtherRois); % Remove parts with overlap.

    if nargout == 1; continue; end

    % Create a mask where all rois are excluded. Erode avoid spillover.
    tmpNpMask = ~(logical(footprintAllRois) | roiMask(:, :, n) );

    % Erode the neuropil mask to create some separation between roi and
    % neuropil
    erodedNpMask = tmpNpMask;
    for i = 1:roiNeuropilSeparation+1
        if mod(i, 2) == 0 
            % Imdilate 1 pixel in each direction: N, E, S, W.
            nhood = [0,1,0;1,1,1;0,1,0];
            erodedNpMask = imerode(erodedNpMask, nhood);

        elseif mod(i, 2) == 1
            % Imdilate 1 pixel in each direction:  NE, SE, SW, NW
            nhood = [1,0,1;0,1,0;1,0,1];
            erodedNpMask = imerode(erodedNpMask, nhood);

        end

    end
    % se = strel('square', 3);
    % erodedNpMask = imerode(npMask, se); 

    % Make a mask for the neuropil surrounding the current RoI

    % Inspired by fissa

    tmpNpMask = currentRoiMask;
    origArea = sum(currentRoiMask(:));     % original area
    currentArea = 0;                    % current area
    maxArea = numel(currentRoiMask) - origArea;

    count = 0;


    while (currentArea < neuropilExpansionFactor * origArea) && (currentArea < maxArea) && count < 100

        % Check which case to use. In current version, we alternate
        % between case 0 (cardinals) and case 1 (diagonals).

        if mod(count, 2) == 0 
            % Imdilate 1 pixel in each direction: N, E, S, W.
            nhood = [0,1,0;1,1,1;0,1,0];
            tmpNpMask = imdilate(tmpNpMask, nhood);

        elseif mod(count, 2) == 1
            % Imdilate 1 pixel in each direction:  NE, SE, SW, NW
            nhood = [1,0,1;0,1,0;1,0,1];
            tmpNpMask = imdilate(tmpNpMask, nhood);

        end

        % Don't include pixels which are not in the original roi
        tmpNpMask(currentRoiMask) = false;

        % Also, don't include pixels that are not in the eroded neuropil mask
        % when checking the area.
        npMaskTmp = tmpNpMask;

        npMaskTmp(~erodedNpMask) = false;
        npMaskTmp(~imageMask) = false;

        % update area
        currentArea = sum(npMaskTmp(:));

        % iterate counter
        count = count + 1;

        if count == 99
            warning('Could not create npmask for roi %d', roiInd)
        end

    end

    % Refine the final neuropil mask
    tmpNpMask(~erodedNpMask) = false;
    tmpNpMask(~imageMask) = false;
    
    npMask(:, :, n) = tmpNpMask;

end

end
