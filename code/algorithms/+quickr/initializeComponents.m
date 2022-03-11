function Results = initializeComponents(imageStack, params)

    % Todo: 
    %   [ ] Downsampling before binarization
    %   [ ] Load downsampled images if they already exist....

    % Use highjacked fprintf if available
    global fprintf; if isempty(fprintf); fprintf = str2func('fprintf'); end

    % Get chunking specifications
    numFramesPerPart = params.BatchSize;
    [IND, numParts] = imageStack.getChunkedFrameIndices(numFramesPerPart);

    % Todo: Implement temporal downsampling.
    %dt = params.TemporalDownsamplingFactor;
    dt = 1;
    
    for iPart = 1:dt:numParts
                
        iIndices = IND{iPart};
        Y = imageStack.getFrameSet(iIndices);

%         % Load image data
%         if dt == 1
%             iIndices = IND{iPart};
%             Y = imageStack.getFrameSet(iIndices);
%         else
%             %iIndices = [ IND{iPart:min(iPart+dt, numParts)} ];
%             iIndices = IND(iPart:min(iPart-1+dt, numParts));
%             Y = imageStack.getDownsampledFrameSet('mean', dt, iIndices);
%         end
        
        % Binarize stack
        fprintf(sprintf('Binarizing images...\n'))
        BW = roimanager.autosegment.binarizeStack(Y, [], 'soma');
        
        % Search for candidates based on activity in the binary stack
        S = roimanager.autosegment.getAllComponents(BW, params);
        
        % Append candidate results 
        if iPart == 1
            Results = S;
        else
            Results = cat(1, Results, S);
        end
        
    end
    
    
end

