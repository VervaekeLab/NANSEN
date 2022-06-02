function rgbImage = colorCodeImageStack(imArray, colorMap)

    if nargin == 1
        colorMap = hsv(size(imArray, 3));
    end

    % make 3 duplicates of the imArray along the 4th dimension
    imarrayRGB = repmat(imArray, 1,1,1,3);

    % Weight each duplicate with the rgb colorcode for each bin.
    for m = 1:size(imArray, 3)
        tmpColor = colorMap(m, :);
        imarrayRGB(:,:,m,:) = imarrayRGB(:,:,m,:) .* reshape(tmpColor, 1, 1, 1, 3);
    end

    % Get the average of each color channel.
    rgbImage = squeeze(nanmean(imarrayRGB, 3));
    rgbImage = stack.makeuint8(rgbImage);
    
end

