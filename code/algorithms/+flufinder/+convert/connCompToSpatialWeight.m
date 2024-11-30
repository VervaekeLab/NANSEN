function weights = connCompToSpatialWeight(S, imageSize)
%connCompToSpatialWeight Convert connected components to spatial weights
%
%   weights = connCompToSpatialWeight(S, imageSize) converts a struct array
%   of connected components to a 3D array of spatial weights, where each
%   plane is the weights for one component.

    assert( all(isfield(S, {'PixelIdxList', 'PixelValues'})))
    
    weights = zeros([imageSize, numel(S)]);
    
    for i = 1:numel(S)
        thisWeight = weights(:,:,i);
        thisWeight(S(i).PixelIdxList) = S(i).PixelValues;
        weights(:, :, i) = thisWeight;
    end
end
