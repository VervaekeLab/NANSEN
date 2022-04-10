function imChunk = getPixelChunk(imArray, S, L)
%getPixelChunk Get pixel chunk from image array
%
%   imChunk = getPixelChunk(imArray, S, L)
%
%   INPTUS:
%       S : smaller bounds  [x_small, y_small]
%       L : larger bounds  [x_large, y_large]

    xInd = S(1):L(1);
    yInd = S(2):L(2);
    
    chunkSize = [L(2)-S(2)+1, L(1)-S(1)+1];
    
    isValidX = xInd >= 1 & xInd <= size(imArray, 2);
    isValidY = yInd >= 1 & yInd <= size(imArray, 1);
    
    imChunk = zeros( [chunkSize, size(imArray,3)], 'like', imArray);
    imChunk(isValidY, isValidX, :) = imArray(yInd(isValidY), xInd(isValidX), :);
    
end