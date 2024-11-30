function bgImage = computeStaticBackgroundImage(imArray, varargin)

    assert( ndims(imArray) == 3, 'Image array must be 3D')
    numFrames = size(imArray, 3);
    
    imArray = single(imArray);
    
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
    sortedPixelValues = sort(imArray, 3);
    
    % Create background from mean of lower end of pixel values.
    pixelIdxKeep = round( numFrames .* prctInterval ./ 100 );
    pixelIdxKeep(pixelIdxKeep<1) = [];
    sortedPixelValuesLow = sortedPixelValues(:, :, pixelIdxKeep);
    bgImage = mean(sortedPixelValuesLow, 3);

end
