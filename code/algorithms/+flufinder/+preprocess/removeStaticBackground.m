function imageArray = removeStaticBackground(imageArray, varargin)
%removeStaticBackground Remove a static background image
%
%   imageArray = removeStaticBackground(imageArray) removes background from 
%   an image array. The background is computed as the mean of a set of
%   sorted pixel values in a lower percentile interval. The default
%   percentile interval is [0, 25];
%
%   imageArray = removeStaticBackground(imageArray) removes the
%   background from the image array using specified options.
%
%   Optional name/value pairs:
%
%   PrctileForBaseline : scalar or 2x1 vector specifying percentile 
%       interval to use for computing static background. If value is 
%       scalar, the interval starts at the 0th percentile.
   
    import flufinder.preprocess.computeStaticBackgroundImage

    assert( ndims(imageArray) == 3, 'Image array must be 3D')
    
    bgImage = computeStaticBackgroundImage(imageArray, varargin{:});

    % "Remove" the background
    imageArray = single(imageArray);
    imageArray = imageArray - cast(bgImage, class(imageArray));
    
    % Normalize imageArray to values between 0 and 1
    imageArray = imageArray - min(imageArray(:));
    imageArray = imageArray ./ max(imageArray(:));
end