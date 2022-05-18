function [S, CC] = getBwComponentStats(BW, varargin)
%getBwComponentStats Get stats of components in a 3D logical (BW) array
%
%   S = getBwComponentStats(BW, varargin) returns a struct containing stats
%   for all connected components in a 3D logical (BW) array.
    
%   Todo. Count number of segments that are ignored and return in summary?


    assert(ndims(BW)==3, 'Array must be a 3D')
    assert(islogical(BW), 'Array must be logical')

    params = struct;
    params.MinimumDiameter = 6;
    params.MaximumDiameter = 18;
    
    params = utility.parsenvpairs(params, [], varargin{:});
    
    getArea = @(d) pi * (d/2)^2;
    minArea = getArea(params.MinimumDiameter); % Todo
    maxArea = getArea(params.MaximumDiameter); % Todo

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
    maxAreaToConsider = prctile([S.Area], 99); % pi*maxR^2
    ignoreInd = [S.Area] > maxAreaToConsider;
    S(ignoreInd) = [];
    
%     minAreaToConsider = prctile([S.Area], 1); % pi*minR^2
%     ignoreInd = [S.Area] < minAreaToConsider;
%     S(ignoreInd) = [];

    if nargout == 1
        clear CC
    else
        CCArray = cat(1, CC{:});
        CC = CC{1};
        CC.NumObjects = sum([CCArray.NumObjects]);
        CC.PixelIdxList = cat(2, CCArray.PixelIdxList);
    end
end