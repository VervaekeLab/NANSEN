function [BW,s] = getRoiMaskFromImage2(im)

    im(im==0)=nan;
%     im = uint8(fillmissing(im, 'linear'));
    if (isa(im, 'single') || isa(im, 'double'))  && max(im(:))>1
        im = uint8(im);
    end
    BW = imbinarize(im);

    
    BW = bwareaopen(BW, 10);
    BW = imfill(BW,'holes');
    BW = pickLargestComponent(BW);
    
    nhood = strel('disk', 1);
    BW = imopen(BW, nhood);

    nhood = strel('disk', 2);
    BW = imclose(BW, nhood);

    
    roiBrightness = nanmedian(nanmedian( im(BW) ));
    pilBrightness = nanmedian(nanmedian( im(~BW) ));
    s.dff = (roiBrightness-pilBrightness+1) ./ (pilBrightness+1);
    s.val = roiBrightness;
    
    if nargout == 1
        clear s
    end
     
    
end

