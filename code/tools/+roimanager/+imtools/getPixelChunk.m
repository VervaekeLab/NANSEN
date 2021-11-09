function imChunk = getPixelChunk(imArray, S, L)

    imChunk = imArray(S(2):L(2), S(1):L(1), :);

end