function [foundRois, im, stat] = run(M, config)

% TODO: add stats from extract outputs. Create more images???
%   Create images and stats in an external function and use for different
%   segmentation methods.

    config = get_defaults(config);

    [S, T, ~] = run_extract(M, config);
    % S = height x width x num_rois
    % T = num_rois x num_timpoints
    
    imSize = size(M);
    numRois = size(S,2);

    
    S = reshape(S, [imSize(1:2), numRois]);
    
    roiArray = RoI.empty;
    
    
    for i = 1:numRois
        CC = bwconncomp(S(:, :, i)>0.1);
        [~, ind] = max( cellfun(@numel, CC.PixelIdxList));
        
        [yy,xx] = ind2sub(imSize(1:2), CC.PixelIdxList{ind});
        
        roiArray(i) = RoI('Mask', [xx,yy], imSize(1:2));
    end
    
    foundRois = roiArray;
        
    roiImSmall = zeros(25,25,numRois);
    stat = struct.empty;
    
    for i = 1:numRois
        stats = regionprops(S(:, :, i)>0, 'Centroid', 'Area', 'Circularity');
        [~, ind] = max([stats.Area]);
        stats = stats(ind);
        stat(i).Area = stats.Area;
        stat(i).Circularity = stats.Circularity;
        stat(i).PeakF = max(T(i,:));
        
        [xx0, yy0] = deal(-12:12);
        xx = xx0 + round(stats.Centroid(1)); 
        yy = yy0 + round(stats.Centroid(2));
        
        keepX = xx > 0 & xx < imSize(2);
        keepY = yy > 0 & yy < imSize(1);
        
        roiImSmall(yy0(keepY)+13, xx0(keepX)+13, i) = S(yy(keepY), xx(keepX), i);
        
    end
    
    roiImSmall = uint8(roiImSmall./max(roiImSmall(:)).*255);
    roiIm = arrayfun(@(i) roiImSmall(:, :, i), 1:numRois, 'uni', 0);
    
    im = struct('extractSpatialWeight', roiIm);
    
    
end