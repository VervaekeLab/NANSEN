function roiArray = convert2rois(extractOutput, varargin)

    params = struct;
    params.enforceSingleSegment = false;
    params.bwThreshold = 0.2;
    
    params = utility.parsenvpairs(params, [], varargin{:});
    
    
    spatialImages = extractOutput.spatial_weights;
    imSize = size(spatialImages);
    
    roiArray = RoI.empty;
    
    for i = 1:size(spatialImages, 3)
        BW = spatialImages(:, :, i) > params.bwThreshold;   
        
        if params.enforceSingleSegment
            CC = bwconncomp(BW);
            numPixels = cellfun(@numel, CC.PixelIdxList);
            [~,idx] = max(numPixels);
            pixelIdxList = CC.PixelIdxList{idx};
            [Y,X] = ind2sub(imSize(1:2), pixelIdxList);
            coords = [X,Y];
            
            roiArray(i) = RoI('Mask', coords, imSize(1:2));
        else
            roiArray(i) = RoI('Mask', BW, imSize(1:2));
        end
        
    end

end
