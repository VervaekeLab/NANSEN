function hIm = plotWeightedRois(hAxes, spatialWeights, varargin)
%imviewer.plot.plotWeightedRois Plot weighted roi images in imviewer
%
%   HIMAGE = imviewer.plot.plotWeightedRois(AX, DATASTRUCT, VARARGIN)
%
%   Parameters:
%       plotMode: 'single_layer' - plot all rois in the same image gobject
%                 'multi_layer' - plot each roiimage in a image gobject
%       colorMap: colormap to use for coloring each rois. colors are
%       imageUsFactor: upsample image (integer factor)
    
    import nansen.wrapper.extract.util.getRoiImageMatrix

    params = struct;
    params.plotMode = 'single_layer'; % single_layer or multi_layer
    params.colorMap = 'viridis';
    params.imageUsFactor = 2;
    
    params = utility.parsenvpairs(params, [], varargin);
    
    if isa(spatialWeights, 'struct')
        if isfield(dataStruct, 'spatial_weights') % extract format...
            roiImageArray = dataStruct.spatial_weights;
            % Todo: What if sparse...
        end
    end
    
    if ~exist('roiImageArray', 'var')
        error('Spatial weights are not provided or not in correct format')
    end
    
    [imageCData, imageAData] = getRoiImageMatrix(roiImageArray);
    
    imSize = size(roiImageArray);

    imageCData = imresize(imageCData, params.imageUsFactor);
    imageAData = imresize(imageAData, params.imageUsFactor);

    hIm = image(hAxes, imageCData);
    hIm.AlphaData = imageAData;
    hIm.XData = [1, imSize(2)];
    hIm.YData = [1, imSize(1)];
    
    
    set(hIm, 'PickableParts', 'none', 'HitTest', 'off')

    return
    
    % Something below is not working as expected....
    
    switch params.plotMode

        case 'single_layer'
         
            imSize = size(roiImageArray);
            imageCData = zeros([imSize(1:2), 3]);
            
            axesCMap = colormap(hAxes);
            colorMap = colormap(hAxes, params.colorMap);
            colormap(hAxes, axesCMap)
            
            for i = 1:size(roiImageArray, 3)
        
                thisRoiImage = roiImageArray(:, :, i);
                S = regionprops(thisRoiImage>0, 'BoundingBox');
                bbox = S.BoundingBox;

                xData = (bbox(1) - 0.5) + (1:(bbox(3)));
                yData = (bbox(2) - 0.5) + (1:(bbox(4)));

                imDataSmall = repmat(thisRoiImage(yData, xData), 1, 1, 3);

                cIdx = randi(255);
                color = colorMap(cIdx, :);
                color = reshape(color, 1, 1, 3);

                imDataSmall = imDataSmall .* color;
                imageCData(yData, xData, :) = imageCData(yData, xData, :) + imDataSmall;

            end

            imageCData = imresize(imageCData, params.imageUsFactor);
            imageAData = max(roiImageArray, [], 3);
            imageAData = imresize(imageAData, params.imageUsFactor);

            hIm = image(hAxes, imageCData);
            hIm.AlphaData = imageAData;
            hIm.XData = [1, imSize(2)];
            hIm.YData = [1, imSize(1)];
            
            
        case 'multi_layer'

            for i = 1:size(roiImageArray, 3)

                thisRoiImage = roiImageArray(:, :, i);
                
                S = regionprops(thisRoiImage>0, 'BoundingBox');
                bbox = S.BoundingBox;

                xData = (bbox(1) - 0.5) + (1:(bbox(3)));
                yData = (bbox(2) - 0.5) + (1:(bbox(4)));

                imData = repmat(thisRoiImage(yData, xData), 1, 1, 3);
                color = rand([1,3]).*0.5 + 0.5; 
                color = reshape(color, 1, 1, 3);

                imData = imData .* color;
                imageAData = thisRoiImage(yData, xData);

                imData = imresize(imData, 2);
                imageAData = imresize(imageAData, 2);

                hIm = image(hAxes, imData);
                hIm.AlphaData = imageAData;
                hIm.XData = xData;
                hIm.YData = yData;

            end
            
    end
    
    set(hIm, 'PickableParts', 'none', 'HitTest', 'off')
    

end