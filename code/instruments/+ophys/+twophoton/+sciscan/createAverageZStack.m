function imageArrayAvgZ = createAverageZStack(imageStack, varargin)

% not a sciscan function...

    assert(isa(imageStack, 'nansen.stack.ImageStack'), ...
        'Input must be an ImageStack object')
    
    defaults = struct;
    defaults.MergeChannels = false;
    defaults.ReferenceChannel = 2;
    defaults.AdjustBrightness = false;
    defaults.doDestretch = false;
    defaults.doRegister = false;
    defaults.doNonrigid = false;
    %defaults.doParallell = false;
    
    params = utility.parsenvpairs(defaults, [], varargin{:});
    
    if params.doDestretch
        imageStack.enablePreprocessing()
        imageStack.Data.PreprocessingOptions.CorrectBidirectionalOffset = true;
        imageStack.Data.PreprocessingOptions.StretchCorrectionMethod = 'imwarp';
    end
    
    nChannelsOut = imageStack.NumChannels;
    if params.MergeChannels 
        nChannelsOut = 1;
    end
    
    ncOpts = getNormcorreOptions(params, imageStack);
    channelInd = getChannelOrder(params, imageStack);
    
    % Preallocate output:
    newArraySize = [imageStack.ImageHeight, imageStack.ImageWidth, ...
        nChannelsOut, imageStack.NumPlanes];
    imageArrayAvgZ = zeros(newArraySize, 'single');
    
    dimC = imageStack.getDimensionNumber('C');
    dimZ = imageStack.getDimensionNumber('Z');
    
    for iPlane = 1:imageStack.NumPlanes
        
        imageStack.CurrentPlane = iPlane;
        imArray = imageStack.getFrameSet('all');
        imArray = single(squeeze(imArray));
        
        if imageStack.NumChannels > 1 && params.MergeChannels
            imArray = squeeze(mean(imArray, dimC));
        end
        
        imArray = correctLineByLineBrightnessDifference(imArray);
        
        if params.doRegister
            
            for iChannel = channelInd
                if nChannelsOut == 1
                    Y = imArray;
                else
                    Y = squeeze( imArray(:, :, iChannel, :) );
                end
                
                if iChannel == params.ReferenceChannel || params.MergeChannels
                    [M, ncShifts, ~] = normcorre_batch(Y, ncOpts);
                else
                    M = apply_shifts(Y, ncShifts, ncOpts);
                end
                
                % Insert corrected images in the output array
                if nChannelsOut == 1
                    imageArrayAvgZ(:, :, iPlane) = mean(M, 3);
                else
                    imageArrayAvgZ(:, :, iChannel, iPlane) = mean(M, 3);
                end
            end
            
        else
            % Insert corrected images in the output array
            if nChannelsOut == 1
                imageArrayAvgZ(:, :, iPlane) = mean(imArray, 3);
            else
                imageArrayAvgZ(:, :, :, iPlane) = mean(imArray, dimZ);
            end
        end
        
        
        if exist('str', 'var')
            fprintf( char(8*ones(1,length(str))));
        end

        str = sprintf('Processed plane %d/%d...', iPlane, imageStack.NumPlanes);
        fprintf(str)
        
    end
    
    fprintf(newline)
    
    
    % Todo: implement different normalizations....
% %     minVal = prctile(imageArrayAvgZ(:), 0.05);
% %     maxVal = prctile(imageArrayAvgZ(:), 99.95);
% %     normalizearray = @(A) uint8((A - minVal) ./ (maxVal-minVal) .* 255);
% %     imageArrayAvgZ = normalizearray(imageArrayAvgZ);
    
    
    if params.AdjustBrightness
        imageArrayAvgZ = normalizeArray(imageArrayAvgZ);
    end
    
    imageArrayAvgZ = squeeze(imageArrayAvgZ);
    
end

function ncOpts = getNormcorreOptions(params, imageStack)

    h = imageStack.ImageHeight;
    w = imageStack.ImageWidth;

    if params.doNonrigid
        ncOpts = NoRMCorreSetParms('d1', h, 'd2', w, ...
            'grid_size', [128,  w], 'max_shift', 50, ...
            'max_dev', 20, 'us_fac', 50, 'correct_bidir', 0, ...
            'boundary', 'copy', 'print_msg', 0, ...
            'bin_width',  imageStack.NumPlanes );
        
    else
        ncOpts = NoRMCorreSetParms('d1', h, 'd2', w, 'print_msg', 0, ...
            'max_shift', 15, 'bin_width', imageStack.NumPlanes, ...
            'correct_bidir', 0, 'boundary', 'copy');

    end
end

function channelInd = getChannelOrder(params, imageStack)

    if params.MergeChannels
        channelInd = 1;
    else
        channelInd = 1:imageStack.NumChannels;
        channelInd = [params.ReferenceChannel, ...
                      setdiff(channelInd, params.ReferenceChannel)];
    end
end

function IM = normalizeArray(IM)
%normalizeArray Adjust brightness of image array
%
%   Use an individual minimum value per channel. Find a "depth adjusted"
%   maximum value per plane, also individual values per channel.
    
    if ndims(IM) == 3
        [h, w, numPlanes] = size(IM);
        IM = reshape(IM, h, w, 1, numPlanes);
    end
    [h, w, numChannels, numPlanes] = size(IM);
    
    tmpPixelValues = reshape(IM, [], numChannels, numPlanes);
    
    % Find max values per plane
    maxValue = prctile(tmpPixelValues, 99.95, 1);
    maxValue = single( transpose( squeeze(maxValue) ) );
    
    % Find minimum values per channel
    minValue = prctile(tmpPixelValues, 0.05, 1);
    minValue = single( min( transpose( squeeze(minValue) ) ) );

    % Use 2nd order polyfit to avoid jitter when adjusting planes
    % individually.
    X = 1:size(maxValue,1);
    p = arrayfun(@(i) polyfit(X, maxValue(:,i), 2), 1:size(maxValue,2), 'uni', 0);
    
    normalizeframe = @(A, minVal, maxVal) (A - minVal) ./ (maxVal-minVal) .* 255;

    % Loop through all planes and channels and adjust brightness of each
    % frame individually.
    for iChannel = 1:numChannels
        
        maxValue = polyval(p{iChannel}, X);

        for iPlane = 1:numPlanes
            IM(:, :, iChannel, iPlane) = normalizeframe(...
                IM(:, :, iChannel, iPlane), minValue(iChannel), maxValue(iPlane));
        end
    end
    
    IM = uint8(IM);
end
