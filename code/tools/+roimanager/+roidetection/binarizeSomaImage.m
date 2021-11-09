function [roiMask, s] = binarizeSomaImage(im, varargin)

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

    % Generate grid with binary mask representing the outer circle. 
    [yy, xx] = ndgrid((1:imSize(1)) - center(1), (1:imSize(2)) - center(2));
    
    mask1 = (xx.^2 + yy.^2) < r1^2; % Nuclues of roi
    mask2 = (xx.^2 + yy.^2) < r2^2; % Nucleus + cytosol
    mask3 = logical(mask2-mask1);   % Cytosol excluding nucleus

    nucleus_values = im(mask1);
    soma_values = im(mask2);
    ring_values = im(mask3);
    surround_values = im(~mask2);

    
    if ~isempty(nucleus_values)
        %  nucleus_val = median(nucleus_values);
        ring_val = nanmedian(ring_values);
        surround_val = nanmedian(surround_values(1:round(end*0.6)));
        threshold = double((ring_val - surround_val) / 2 + surround_val);
        
%         s = (ring_val - surround_val) / surround_val;

    else 
        high_val = nanmedian(soma_values);
        low_val = nanmedian(surround_values);
%         s = (high_val - low_val) / low_val;
        
        threshold = double((high_val - low_val) / 2 + low_val);
        % Create roimask

    end 
    
    im = medfilt2(im, [5, 5]);

    % Create roimask
    roiMask = imbinarize(im, threshold);
    if ~isempty(nucleus_values)
        roiMask(mask1) = 1;
    end
    
    % remove small "holes"
    roiMask = bwareaopen(roiMask, minRoiArea);
    roiMask = imfill(roiMask, 'holes');

    roiBrightness = nanmedian(nanmedian( im(roiMask) ));
    pilBrightness = nanmedian(nanmedian( im(~roiMask) ));
    s.dff = (roiBrightness-pilBrightness+1) ./ (pilBrightness+1);
    s.val = roiBrightness;
    
    if nargout == 1
        clear s
    end
     
    
end