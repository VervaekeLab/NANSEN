function imOut = std(imArray, dim)
    
    if nargin < 2; dim = 3; end

    P = double( prctile(imArray(:), [0.5, 99.5]) );
    
    if ndims(imArray) >= 3 %#ok<ISMAT>
        imOut = std(imArray, 0, dim);
    else
        imOut = imArray;
    end
    
    imOut = imOut .* range(P) + P(1);
    imOut = cast(imOut, class(imArray));
    
end