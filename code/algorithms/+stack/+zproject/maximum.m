function imOut = maximum(imArray, dim)

    if nargin < 2; dim = 3; end

    if ndims(imArray) >= 3 %#ok<ISMAT>
        imOut = max(imArray, [], dim);
    else
        imOut = imArray;
    end
end
