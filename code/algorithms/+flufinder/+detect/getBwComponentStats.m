function S = getBwComponentStats(BW, varargin)
%getBwComponentStats Get stats of components in a 3D logical (BW) array
%
%   S = getBwComponentStats(BW, varargin) returns a struct containing stats
%   for all connected components in a 3D logical (BW) array.
    
    assert(ndims(BW)==3, 'Array must be a 3D')
    assert(islogical(BW), 'Array must be logical')

    params = struct;
    params.MinDiameter = 6;
    params.MaxDiameter = 18;
    
    params = utility.parsenvpairs(params, [], varargin{:});
    
    getArea = @(d) pi * (d/2)^2;
    minArea = getArea(params.MinDiameter); % Todo
    maxArea = getArea(params.MaxDiameter); % Todo

    numFrames = size(BW, 3);
    
    % Find all connected components
    CC = cell(numFrames, 1);
    for i = 1:numFrames-1
        CC{i} = bwconncomp(BW(:, :, i));
    end

    % Get area, center and pixel list of all components
    props = {'Area', 'Centroid', 'PixelIdxList'};
    S = cellfun(@(c) regionprops(c, props), CC, 'uni', 0);
    S = cat(1, S{:});

    % Filter out big components. Overlapping rois are just a mess anyway
    maxAreaToConsider = prctile([S.Area], 99); % pi*8^2
    ignoreInd = [S.Area] > maxAreaToConsider;
    S(ignoreInd) = [];
    
%     minAreaToConsider = prctile([S.Area], 1); % pi*8^2
%     ignoreInd = [S.Area] < minAreaToConsider;
%     S(ignoreInd) = [];
    
end