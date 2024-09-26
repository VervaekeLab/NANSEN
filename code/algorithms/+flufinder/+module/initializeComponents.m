function results = initializeComponents(imageStack, params)
%initializeComponents Detect bw components from a 3D imagestack.
%
%   results = initializeComponents(imageStack, params) return a struct of
%       stats containing 'Area', 'Centroid' & 'PixelIdxList' for all the
%       connected components that are found after thresholding the images.
%
%   This function combines the preprocessing, binarization and initial
%   component detection step for use on an ImageStack object.

    % Todo:
    %   [ ] Downsampling before binarization
    %   [ ] Load downsampled images if they already exist....

    % Use hijacked fprintf if available
    global fprintf; if isempty(fprintf); fprintf = str2func('fprintf'); end
    
    % Get chunking specifications
    numFramesPerPart = 2000;%params.BatchSize;
    [IND, numParts] = imageStack.getChunkedFrameIndices(numFramesPerPart);

    % Todo: Implement temporal downsampling.
    %dt = params.TemporalDownsamplingFactor;
    dt = 1;
    
    for iPart = 1:dt:numParts
                
        iIndices = IND{iPart};
        imArray = imageStack.getFrameSet(iIndices);
        
        imArray = flufinder.module.preprocessImages(imArray, params);
        bwArray = flufinder.module.binarizeImages(imArray);

        % Search for candidates based on activity in the binary stack
        S = flufinder.detect.getBwComponentStats(bwArray, params);

        % Append candidate results
        if iPart == 1
            results = S;
        else
            results = cat(1, Results, S);
        end
    end
end
