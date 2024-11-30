function [roiArrayOut, statOut] = improveMaskEstimate2(roiArrayIn, roiType)

    if nargin < 2; roiType = 'soma'; end

    roiImages = cat(3, roiArrayIn.enhancedImage);
    
    boxSize = size(roiImages);
    boxSize = boxSize(1:2);
    
    indX = (1:boxSize(2)) - ceil(boxSize(2)/2);
    indY = (1:boxSize(1)) - ceil(boxSize(1)/2);

    centerCoords = round(cat(1, roiArrayIn.center));
    tmpMask = zeros(roiArrayIn(1).imagesize, 'logical');
    
    roiArrayOut = roiArrayIn;
    nRois = numel(roiArrayIn);
    keep = true(1, nRois);
    
    statOut = struct('RoiContrast', {}, 'RoiBrightness', {});
    
    for i = 1:nRois
        
        tmpX = indX + centerCoords(i, 1);
        tmpY = indY + centerCoords(i, 2);
        
        switch roiType
            case 'axon'
                im = roiArrayIn(i).enhancedImage;
                roiDiameter = 2; %Todo: add roi diameter from options
                [mask, s] = flufinder.binarize.getRoiMaskFromImage(im, roiType, roiDiameter);

            case 'soma'
                [mask, s] = flufinder.binarize.findSomaMaskByThresholding(roiImages(:, :, i));
                
        end
        
        statOut(i).RoiContrast = s.dff;
        statOut(i).RoiBrightness = s.val;
        
        if sum(mask)==0
            keep(i) = false;
            continue
        end
        
        tmpMask(tmpY, tmpX) = mask;
%         tmpMask = mask;

        roiArrayOut(i) = RoI('Mask', tmpMask);
        offset = roiArrayIn(i).center - roiArrayOut(i).center;
        
        roiArrayOut(i).enhancedImage = circshift(roiArrayIn(i).enhancedImage, fliplr(round(offset)));

        tmpMask(tmpY, tmpX) = 0;
        
    end
    
    roiArrayOut = roiArrayOut(keep);
    statOut = statOut(keep);

end
