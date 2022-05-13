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
%   Percentile : scalar or 2x1 vector specifying percentile interval to use
%       for computing static background. If value is scalar, the interval
%       starts at the 0th percentile.
   

    assert( ndims(imageArray) == 3, 'Image array must be 3D')
    numFrames = size(imageArray, 3);
    
    imageArray = single(imageArray);
    
    % Set default parameters and parse name/value pairs from varargin
    params = struct();
    params.PrctileForBaseline = 25;
    
    params = utility.parsenvpairs(params, [], varargin{:});
    
    if numel(params.PrctileForBaseline) == 1
        params.PrctileForBaseline = [0, params.PrctileForBaseline];
    end
    
    % Assign and validate percentile interval
    prctInterval = params.PrctileForBaseline(1):params.PrctileForBaseline(2);
    assert(all(prctInterval >= 0 & prctInterval <= 100), ...
        'Percentile values must be between 0 and 100')
    
    % Sort pixel values along the 3rd (frame) dimension
    sortedPixelValues = sort(imageArray, 3);
    
    % Create background from mean of lower end of pixel values. 
    pixelIdxKeep = round( numFrames .* prctInterval ./ 100 );
    pixelIdxKeep(pixelIdxKeep<1) = [];
    sortedPixelValuesLow = sortedPixelValues(:, :, pixelIdxKeep);
    staticBackgroundImage = mean(sortedPixelValuesLow, 3);
    
    % "Remove" the background
    imageArray = imageArray - staticBackgroundImage;
    
    % Normalize imageArray to values between 0 and 1
    imageArray = imageArray - min(imageArray(:));
    imageArray = imageArray ./ max(imageArray(:));

end


