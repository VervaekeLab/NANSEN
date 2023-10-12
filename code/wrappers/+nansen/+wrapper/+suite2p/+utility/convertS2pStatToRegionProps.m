function S = convertS2pStatToRegionProps(stat, imageSize)
%convertS2pStatToRegionProps Convert suite2p stat to regionprop struct
%
%   S = convertS2pStatToRegionProps(stat, imageSize)
    
    % Build a struct that has the required fields for a conncomp struct
    CC = struct;
    CC.Connectivity = 8;
    CC.ImageSize = imageSize;
    CC.PixelIdxList = arrayfun(@(s) s.ipix, stat, 'UniformOutput', false);
    CC.NumObjects = numel( CC.PixelIdxList );
    
    % Get the regionprops struct array
    S = regionprops(CC, 'Centroid', 'PixelIdxList', 'EquivDiameter');

    % Add the PixelValues field from the lam field in stat.

    for i = 1:numel(S)
        S(i).PixelValues = stat(i).lam;
    end
end

