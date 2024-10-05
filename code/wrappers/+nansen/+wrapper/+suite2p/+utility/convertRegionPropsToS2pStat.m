function stat = convertRegionPropsToS2pStat(S, imageSize)
%convertRegionPropsToS2pStat Convert region props to suite2p stat struct
%
%   stat = convertRegionPropsToS2pStat(S, imageSize)

    % Rebuild stats:
    stat = struct;
    for i = 1:numel(S)
        stat(i).ipix    = S(i).PixelIdxList;
        [y, x]          = ind2sub(imageSize, S(i).PixelIdxList);
        stat(i).xpix    = x;
        stat(i).ypix    = y;
        
        stat(i).lam     = S(i).PixelValues;
        stat(i).lambda  = S(i).PixelValues;
        
        % Make sure lam is normalized
        if sum(stat(i).lam) ~= 1
            stat(i).lam = stat(i).lam ./ sum(stat(i).lam);
        end

        stat(i).npix    = numel( stat(i).ipix );
        stat(i).med     = [median(stat(i).ypix) median(stat(i).xpix)];      % median center of cell
        stat(i).neuropilCoefficient = 0.7;                                  % hardcoded in sourcery/getFootprint
        stat(i).baseline = 0;                                               % hardcoded in sourcery/getFootprint
        %stat(i).footprint = [] % ? todo
    end
end
