function score = calculateTemplateMatch(roiArray)
%calculateTemplateMatch Calculate xcorrelations between images and average
%
% score is the crosscorrelation between a roi image and the average of all
% roi images of the given roi array.

    roiImages = cat(3, roiArray.enhancedImage); 
    roiImages(isnan(roiImages))=0;
    
    template = mean(roiImages, 3);

    score = zeros(numel(roiArray), 1);

    for i = 1:numel(roiArray)
        score(i) = corr_err( template, roiImages(:,:,i) );
    end

end