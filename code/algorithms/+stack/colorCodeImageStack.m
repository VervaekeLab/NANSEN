function rgbImage = colorCodeImageStack(imArray, colorMap)
%colorCodeImageStack Color images of a stack based on colormap
%
%   Inputs:
%       imArray : (h x w x n) 3D image array
%       colorMap : an n x 3 colormap where n is equal to the number of
%           frames in the imArray
%
%   Output:
%       rgbImage : (h x w x 3) RGB image where each frame was given a
%           unique color

    numFrames = size(imArray, 3);

    if nargin == 1
        colorMap = hsv(numFrames);
    end
    
    % Image array must be single or double for this operation
    if ~isa(imArray, 'single') || ~isa(imArray, 'double')
        dataType = class(imArray);
        imArray = single(imArray);
    end

    % Make 3 duplicates ("rgb" frames) of the imArray along the 4th dim.
    imarrayRGB = repmat(imArray, 1,1,1,3);

    % Weight each new "rgb" frame with the rgb colorcode for that frame.
    for i = 1:numFrames
        iColor = reshape( colorMap(i, :), 1, 1, 1, 3);                      % Reshape so multiplication happens along the 3rd (rgb) dimension
        imarrayRGB(:,:,i,:) = imarrayRGB(:,:,i,:) .* iColor;
    end
    
    % Get the average of each color channel.
    rgbImage = squeeze(nanmean(imarrayRGB, 3)); %#ok<NANMEAN>
    
    % Recast to original datatype if relevant
    if exist('dataType', 'var')
        rgbImage = cast(rgbImage, dataType);
    end
end
