function [roiArrayOut, statOut] = improveRoiMasks(roiArrayIn, roiImageArray, roiType)
%improveRoiMasks Improve roi masks based on images of rois
%
%   [roiArrayOut, statOut] = improveRoiMasks(roiArrayIn, roiImageArray, roiType)
    
    import flufinder.binarize.getRoiMaskFromImage
    import flufinder.binarize.findSomaMaskByThresholding
    import flufinder.binarize.findSomaMaskByEdgeDetection

    if nargin < 3; roiType = 'soma'; end
    
    %params.roiDiameter = 12;
    roiDiameter = mean(2*sqrt([roiArrayIn.area]/pi));
    
    centerCoords = round(cat(1, roiArrayIn.center));
    
    fovSize = roiArrayIn(1).imagesize;
    blankFovMask = zeros(fovSize, 'logical');
    
    roiArrayOut = roiArrayIn;
    nRois = numel(roiArrayIn);
    
    keep = true(1, nRois);
    
    for i = 1:nRois

        roiImage = roiImageArray(:, :, i);
        
        switch roiType
            case 'axon'
                mask = getRoiMaskFromImage(roiImage, roiType, roiDiameter);
            case 'soma'
                % Todo: switch method
                % mask = findSomaMaskByThresholding(roiImage);
                
                %mask = findSomaMaskByEdgeDetection(roiImage, roiArrayIn(i).center, roiArrayIn(i).imagesize);
                
                [mask, s] = roimanager.roidetection.binarizeSomaImage(roiImage);

        end
        
        % Skip roi if mask came back empty.
        if sum(mask)==0
            keep(i) = false;
            continue
        end
        
        % Expand roi mask to full fov size
        roiMask = flufinder.utility.placeLocalRoiMaskInFovMask(...
            roiMaskSmall, centerCoords(i, :), blankFovMask);
        
        roiArrayOut(i) = RoI('Mask', roiMask);
    end
    
    roiArrayOut = roiArrayOut(keep);
    
    if nargout == 2
        error('Not implemented yet')
        
        % todo: compute stats.
        
        
%         statOut(i).RoiContrast = s.dff; % Salienct
%         statOut(i).RoiBrightness = s.val;
        
        
    end
    
    % statOut = struct('RoiContrast', {}, 'RoiBrightness', {});
    % statOut = statOut(keep);

end