function imageOut = translateImage(imageIn, varargin)
%translateImage Translate an image in x and y with subpixel resolution
%
%   imTranslated = translateImage(im, [dx, dy]) translates the image 
%
%   imTranslated = translateImage(im, dx, dy)

    % Get shift values from varargin
    if numel(varargin) == 2
        dx = varargin{1};
        dy = varargin{2};
    elseif numel(varargin) == 1 && numel(varargin{1}) == 2
        dx = varargin{1}(1);
        dy = varargin{1}(2);
    end

    % Create displacement field
    Dx = ones(size(imageIn,1), size(imageIn,2)) .* -dx;
    Dy = ones(size(imageIn,1), size(imageIn,2)) .* -dy;
    D = cat(3, Dx, Dy); % Displacement field

    % Use imwarp to translate image with subpixel resolution
    imageOut = imwarp(imageIn, D, 'cubic');
    
end


