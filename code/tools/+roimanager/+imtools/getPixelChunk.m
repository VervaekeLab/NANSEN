function imChunk = getPixelChunk(imArray, S, L)
%getPixelChunk Get pixel chunk from image array
%
%   imChunk = getPixelChunk(imArray, S, L)
%
%   INPTUS:
%       S : smaller bounds  [x_small, y_small]
%       L : larger bounds  [x_large, y_large]

    arraySize = size(imArray);
    
    xInd = S(1):L(1);
    yInd = S(2):L(2);
    
    % Make sure to only retrieve data insize the image bounds
    isValidX = xInd >= 1 & xInd <= arraySize(2);
    isValidY = yInd >= 1 & yInd <= arraySize(1);
    
    [subsSource, subsTarget] = deal( repmat({':'}, 1, ndims(imArray)) );
    subsTarget(1:2) = {isValidY, isValidX};
    subsSource(1:2) = {yInd(isValidY), xInd(isValidX)};
       
    % Initialize output
    chunkSize = [L(2)-S(2)+1, L(1)-S(1)+1];
    imChunk = zeros( [chunkSize, arraySize(3:end)], 'like', imArray);
    
    imChunk(subsTarget{:}) = imArray(subsSource{:});
    
end
