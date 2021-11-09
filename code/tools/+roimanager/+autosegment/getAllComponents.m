function S = getAllComponents(BW, varargin)
%getAllComponents

%   parameters:
%       max area
%       min area

    
    bwSize = size(BW);
    
    % Find all connected components
    CC = cell(bwSize(3), 1);
    for i = 1:bwSize(3)-1
        CC{i} = bwconncomp(BW(:, :, i));
    end

    
    % Get area, center and pixel list of all components
    S = cellfun(@(c) regionprops(c, 'Area', 'Centroid', 'PixelIdxList'), CC, 'uni', 0);
    S = cat(1, S{:});


    % Filter out big components. Overlapping rois are just a mess anyway
    maxAreaToConsider = prctile([S.Area], 99); % pi*8^2
    ignoreInd = [S.Area] > maxAreaToConsider;
    S(ignoreInd) = [];
    
%     minAreaToConsider = prctile([S.Area], 1); % pi*8^2
%     ignoreInd = [S.Area] < minAreaToConsider;
%     S(ignoreInd) = [];
    

end