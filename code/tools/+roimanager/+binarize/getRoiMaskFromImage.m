function BW = getRoiMaskFromImage(im, roiClass)


    switch roiClass
        
        case 'soma'

            L = prctile(im(:), 50);
            U = prctile(im(:), 95);

            T = L + (U-L)/2;
            
        case 'axon'
            % Pixel need to be active atleast 33% of the time.
            T = max(im(:)) / 3;
            
    end
    
%     im(im==0) = nan;
%     im = uint8(fillmissing(im, 'linear'));

    BW = imbinarize(im, T);
    
    
    switch roiClass
        
        case 'soma'

            BW = bwareaopen(BW, 10);
            BW = imfill(BW,'holes');
            BW = roimanager.autosegment.pickLargestComponent(BW);
            
        case 'axon'
            
            BW = imdilate(BW, ones(3,3));
    end
end