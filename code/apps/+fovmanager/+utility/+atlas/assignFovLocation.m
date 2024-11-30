function fovLocs = assignFovLocation(fovArray, varargin)
%assignFovLocation Assign a fovlocation to a FoV or an array of FoVs.
%
%   fovLocs = assignFovLocation(fovArray) returns a cell array fovLocs of
%   region names based on an input of FoVs (fovArray). The region name is
%   determined based on which region of the cortical map the fov overlaps
%   most with.
%
%   fovLocs = assignFovLocation(fovArray, Name1, Value1, ...) sets
%   additional options.
%
%   Name, Value pairs:
%       mergeRegions    : true | false

    % S is a struct containing a region index map and some other necessary
    % parameters. S is loaded from a file. Use persistent variable, because
    % this function might be called many times. Also, the file will have a
    % small footprint in memory.
    persistent S
    
    opt = struct('mergeRegions', true);
    opt = utility.parsenvpairs(opt, [], varargin);
    
    % Load file with region index map
    if isempty(S)
        S = fovmanager.utility.atlas.loadRegionIndexMap();
    end
    
    % Get some values from S
    m = S.magnificationFactor;
    regionLabels = S.regionLabels;
    [mapHeight, mapWidth] = size(S.indexMap);
    
    % Merge regions / region labels if requested
    if opt.mergeRegions
        regionLabels = fovmanager.utility.atlas.mergeRegions(regionLabels);
    end
    uniqueRegions = unique(regionLabels);
    
    numFovs = numel(fovArray);
    fovLocs = cell(numFovs, 1);
    
    for iFov = 1:numFovs
    
        thisFov = fovArray(iFov);
        
        % Make binary mask of the fov with same size and coordinates as the
        % region index map.
        fovX = (thisFov.edge(:,1) - S.referencePoint(1)) .* m;
        fovY = (thisFov.edge(:,2) - S.referencePoint(2)) .* m;
        fovMask = poly2mask(fovX, fovY, mapHeight, mapWidth);
        
        % Get the reigion indices for each coordinate in the fov.
        regionIndices = S.indexMap(fovMask);

        % Count the different regionLabels
        C = categorical(regionIndices, 1:numel(S.regionLabels), regionLabels);  % Use categorical in case some regions are merged and should be considered the same
        N = histcounts(C, uniqueRegions);

        % Select the regionLabels with most counts.
        [~, bestRegionInd] = max(N);

        fovLocs(iFov) = uniqueRegions(bestRegionInd);
        
    end
end
