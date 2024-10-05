function [BW, stats] = getRoiMaskFromImage(im, roiType, roiDiameter)
%getRoiMaskFromImage Get a binary mask from a roi image
%
%   BW = getRoiMaskFromImage(im, roiType) get a roi mask for given roi type
%   from an image. Simple thresholding with some postprocessing depending
%   on the given roiType. roiType can be 'soma' or 'axonal bouton'
%
%   BW = getRoiMaskFromImage(im, roiType, roiDiameter) additionally
%   specifies the expected roi diameter (in pixels)

    if nargin < 3 || isempty(roiDiameter)
        roiDiameter = 12;
    end
    
    getArea = @(d) pi * (d/2)^2;
    A = getArea(roiDiameter);

    % Get threshold and find mask
    T = getThreshold(im, roiType);
    BW = imbinarize(im, T);
    
    % Postprocess mask
    switch lower( roiType )
        
        case 'soma'
            % Remove very small components and fill holes.
            BW = bwareaopen(BW, round(A/10)); % < than 1/10th of roi area
            
        case 'axonal bouton'
            BW = bwareaopen(BW, round(A/10));
            %BW = imdilate(BW, ones(3,3));
    end

    BW = imfill(BW,'holes');
    BW = flufinder.utility.pickLargestComponent(BW);
    
    if nargout == 2
        stats = getStats(im, BW);
    end
end

function T = getThreshold(im, roiType)
%getThreshold Get threshold for binarization based on roi type.

    switch lower( roiType )
        
        case 'soma'
            L = prctile(im(:), 50); % lower value
            U = prctile(im(:), 95); % upper value

            T = L + (U-L)/2; % mid-value is threshold
            
        case 'axonal bouton'
            T = graythresh(im);
    end
end

function stats = getStats(im, mask)

    stats = struct;
    
    roiBrightness = nanmedian(nanmedian( im(mask) ));
    pilBrightness = nanmedian(nanmedian( im(~mask) ));

    stats.dff = (roiBrightness-pilBrightness+1) ./ (pilBrightness+1);
    stats.val = roiBrightness;
    
end
