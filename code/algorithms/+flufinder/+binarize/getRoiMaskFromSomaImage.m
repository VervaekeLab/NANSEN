function roiMask = getRoiMaskFromSomaImage(im, varargin)
%getRoiMaskFromSomaImage Find mask for an image of a soma with a darker nucleus
%
%   This function detects the threshold level for a soma with a darker
%   nucleus, then binarizes the image, and finally processes the mask to
%   fill nucleus and smaller holes and remove small objects.

    def = struct('InnerDiameter', 6, 'OuterDiameter', 11);
    opt = utility.parsenvpairs(def, [], varargin);
    
    d1 = opt.InnerDiameter; d2 = opt.OuterDiameter;

    % Ignore zero values
    im = double(im);
    im(im==0) = nan;
    
    % Define center coordinates and radius
    imSize = size(im);
    center = imSize / 2;
    
    r1 = d1/2;
    r2 = d2/2;
    minRoiArea = round(pi*(r2^2)/2);

    % Generate grid with coordinates centered on image center
    [yy, xx] = ndgrid((1:imSize(1)) - center(1), (1:imSize(2)) - center(2));
    
    mask1 = (xx.^2 + yy.^2) < r1^2; % Nucleus of soma
    mask2 = (xx.^2 + yy.^2) < r2^2; % Nucleus + cytosol
    mask3 = logical(mask2 - mask1); % Cytosol excluding nucleus

    nucleusValues = im(mask1);
    somaValues = im(mask2);
    cytosolValues = im(mask3);
    surroundValues = im(~mask2);

    if ~isempty(nucleusValues)
        %  nucleus_val = median(nucleus_values);
        mediCytosolValue = nanmedian(cytosolValues);
        mediSurroundValue = nanmedian(surroundValues(1:round(end*0.6)));
        T = mediSurroundValue + (mediCytosolValue - mediSurroundValue) / 2;
        
    else 
        high_val = nanmedian(somaValues);
        low_val = nanmedian(surroundValues);
        
        T = low_val + (high_val - low_val) / 2;
    end 
    
    im = medfilt2(im, [5, 5]);

    % Create roimask
    roiMask = imbinarize(im, double(T));
    if ~isempty(nucleusValues)
        roiMask(mask1) = 1;
    end
    
    % remove small "holes"
    roiMask = bwareaopen(roiMask, minRoiArea);
    roiMask = imfill(roiMask, 'holes');

end