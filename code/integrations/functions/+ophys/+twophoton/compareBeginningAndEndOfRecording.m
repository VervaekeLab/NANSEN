function rgbImage = compareBeginningAndEndOfRecording(imageStack, doRegister, nImages)

    import nansen.wrapper.normcorre.utility.rigid
    
    if nargin < 2; doRegister = false; end
    if nargin < 3; nImages = 200; end

    frameInd = 1:imageStack.NumTimepoints;

    frameIndBeginning = frameInd(1:nImages);
    frameIndEnd = frameInd(end-nImages:end);
    
    rgbImage = cell(1, imageStack.NumChannels);
    
    currentPlanes = imageStack.CurrentPlane;

    if imageStack.NumPlanes > 1
        warning('Method  %s is not implemented for multi-plane recordings. Method will run on the first plane only')
        imageStack.CurrentPlane = 1;
    end
    
    for iChannel = 1:imageStack.NumChannels
        
        imageStack.CurrentChannel = iChannel;
        
        IM1 = squeeze( imageStack.getFrameSet(frameIndBeginning) );
        IM2 = squeeze( imageStack.getFrameSet(frameIndEnd) );


        if doRegister
            IM1 = rigid(IM1);
            IM2 = rigid(IM2);
        end


        firstImage = mean(IM1, 3);
        lastImage = mean(IM2, 3);
        
        % Align last image to first image
        lastImage = rigid(lastImage, firstImage);
        
        rgbImage{iChannel} = cat(3, firstImage, lastImage);
        rgbImage{iChannel}(:, :, 3) = 0;
        
        rgbImage{iChannel} = cast(rgbImage{iChannel}, imageStack.DataType);
    end

    % Reset the currentplanes property of imagestacks.
    imageStack.CurrentPlane = currentPlanes;
    
end
