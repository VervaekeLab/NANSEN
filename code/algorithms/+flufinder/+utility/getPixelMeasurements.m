function stats = getPixelMeasurements(im, roiMask)
%getPixelMeasurements Get pixel measurements from image based on mask

    roiBrightness = nanmedian(nanmedian( im(roiMask) ));
    pilBrightness = nanmedian(nanmedian( im(~roiMask) ));
    
    stats.dff = (roiBrightness-pilBrightness+1) ./ (pilBrightness+1);
    stats.val = roiBrightness;
    
end