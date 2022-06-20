function [rgbMatrix, alphaMatrix] = getRoiImageMatrix(roiData, varargin)
%getRoiImageMatrix Get image and alpha matrix for a set of spatial weigths
%
%   [rgbMatrix, alphaMatrix] = getRoiImageMatrix(roiData)
%
%   Combine all roi spatial weights into a colorcoded image where each roi
%   is given a unique color representation.


    % Default parameters
    params = struct();
    params.colorMap = 'viridis';
    params.imageUsFactor = 1;
    
    % Get parameter selection from varargins.
    params = utility.parsenvpairs(params, [], varargin{:});

    % Get spatial weights from the first input.
    if isstruct(roiData) && isfield(roiData, 'spatial_weights')
        spatialWeightArray = roiData.spatial_weights;
    elseif isa(roiData, 'single') && ndims(roiData)==3
        spatialWeightArray = roiData;
    end
        
    % Create the rgb and alpha matrices.
    imSize = size(spatialWeightArray);
    
    rgbArray = reshape(spatialWeightArray, [imSize(1:2), 1, imSize(3)]);
    rgbArray = repmat(rgbArray, 1,1,3,1);

    % Create a colormap scaled across all rois.
    cmapFcn = str2func(params.colorMap);
    colorArray = cmapFcn(imSize(3));
    colorArray = transpose(colorArray);
    colorArray = reshape(colorArray, 1, 1, 3, imSize(3));
    
    % Colorcode each roi
    rgbArray = rgbArray .* colorArray;
    rgbMatrix = sum(rgbArray, 4);
    alphaMatrix = max(spatialWeightArray, [], 3);
    
    % Upsample images if requested
    rgbMatrix = imresize(rgbMatrix, params.imageUsFactor);
    alphaMatrix = imresize(alphaMatrix, params.imageUsFactor);
    
    if nargout == 1
        clear alphaMatrix
    end

end