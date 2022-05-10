function BW = getRoiMaskFromImage(im, roiType, roiDiameter)
%getRoiMaskFromImage Get a binary mask from a roi image
%
%   BW = getRoiMaskFromImage(im, roiType) get a roi mask for given roi type
%   from an image. Simple thresholding with some postprocessing depending
%   on the given roiType. roiType can be 'soma' or 'axon'
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
    switch roiType
        
        case 'soma'
            % Remove very small components and fill holes.
            BW = bwareaopen(BW, round(A/10)); % < than 1/10th of roi area
            BW = imfill(BW, 'holes');
            
        case 'axon'
            BW = imdilate(BW, ones(3,3));
    end
    
    BW = flufinder.utility.pickLargestComponent(BW);

end

function T = getThreshold(im, roiType)
%getThreshold Get threshold for binarization based on roi type.

    switch roiType
        
        case 'soma'
            L = prctile(im(:), 50); % lower value
            U = prctile(im(:), 95); % upper value

            T = L + (U-L)/2; % mid-value is threshold
            
        case 'axon'
            % Very subjective...
            T = graythresh(im);
            %T = max(im(:)) / 3;
    end
end