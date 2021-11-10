function [regionInd, regionName] = getRegionAtPoint(pointCoords)
%getRegionAtPoint 

    persistent S atlasChoice
    
    % Load file with region index map
    if isempty(S) || ~isequal(getpref('fovmanager', 'atlasChoice'), atlasChoice)
        atlasChoice = getpref('fovmanager', 'atlasChoice');
        S = fovmanager.fileio.loadRegionIndexMap(atlasChoice);
    end
    
    % Get some values from S
    m = S.magnificationFactor;
    regionLabels = S.regionLabels;
    [mapHeight, mapWidth] = size(S.indexMap);

    x = round( (pointCoords(1) - S.referencePoint(1)) .* m );
    y = round( (pointCoords(2) - S.referencePoint(2)) .* m );
            
    % Get the reigion indices for each coordinate in the fov.
    regionInd = S.indexMap(y, x);
   
    if regionInd == 0
        regionName = 'n/a';
    else
        regionName = regionLabels{regionInd};
    end
    
end