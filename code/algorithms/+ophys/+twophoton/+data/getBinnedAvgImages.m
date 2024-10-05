function avgImages = getBinnedAvgImages(imageStack, N)
%getBinnedAvgImages Get N binned average images from an ImageStack

    chunkSize = floor( imageStack.NumTimepoints ./ N );
    [IND, ~] = imageStack.getChunkedFrameIndices(chunkSize);
    numParts = N;
        
    fprintf('Loading image data...');
    
    avgImages = zeros(imageStack.ImageHeight, imageStack.ImageWidth, N);
    for i = 1:numParts
        tmpImageData = imageStack.getFrameSet(IND{i});
        avgImages(:, :, i) = squeeze( mean(mean(tmpImageData, 3), 4) );
    end

    fprintf('done')
    fprintf(newline)
end
