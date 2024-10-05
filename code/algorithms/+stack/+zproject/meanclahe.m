function im = meanclahe(imArrayIn, dim, imclass)

    if isempty(imArrayIn); im = []; return; end

    if nargin < 3
        imclass = class(imArrayIn);
    end
    
    meanImage = mean(imArrayIn, 3);

    minVal = min(meanImage(:));
    maxVal = max(meanImage(:));
    
    meanImage = (meanImage - minVal) ./ (maxVal - minVal);
    
    if size(imArrayIn,1) < 32 ||  size(imArrayIn,2) < 32; im = meanImage; return; end
    
    im = adapthisteq(meanImage, 'NumTiles', [32, 32], ...
                    'ClipLimit', 0.015, ...
                    'Distribution', 'rayleigh', ...
                    'Range', 'original');
    
    im = im .* (maxVal-minVal) + minVal;
    im = cast(im, imclass);
    
end
