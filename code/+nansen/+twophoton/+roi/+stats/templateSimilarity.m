function similarity = templateSimilarity(roiImageArray, template)
%templateSimilarity Calculate xcorrelations between images and average
%
%   similarity = templateMatch(roiImageArray) computes the crosscorrelation
%       between a roi image and the average of all roi images of the
%       given array of roi images.
%
%
%   OUTPUT
%       similarity : column vector with a value for each roi
    
    if isa(roiImageArray, 'struct') % If roi images is a structarray
        fieldName = fieldnames(roiImageArray);
        roiImageArray = cat(3, roiImageArray.(fieldName) );
    end

    assert( ndims(roiImageArray) == 3, 'Roi images must be a 3D array')

    roiImageArray(isnan(roiImageArray)) = 0;
    
    if nargin < 2
        template = mean(roiImageArray, 3);
    end
    
    numRois = size(roiImageArray, 3);
    similarity = zeros(numRois, 1);

    for i = 1:numRois
        similarity(i) = corr2( template, roiImageArray(:,:,i) );

    end
end
