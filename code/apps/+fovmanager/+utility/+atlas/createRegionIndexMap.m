function createRegionIndexMap()
%createRegionIndexMap Create an index map for map regions.
%
%   createRegionIndexMap() will create an indexed map of cortical regions 
%   from the polygon patches that are part of the paxinos dorsal surface map

    % Open the figure containing the paxinos map (each subregion is a
    % patched object / polygon object)

    tmpFig = brainmap.paxinos.open('Invisible');
    h = findobj(tmpFig, 'Type', 'Polygon');
    h(31) = []; % Ignore (This is the map borders, and should not be included)
    
    
    ax = findobj(tmpFig, 'type', 'Axes');
    
    % Get the map limits and range
    xMin = ax.XLim(1);
    yMin = ax.YLim(1);
    xRange = range(ax.XLim);
    yRange = range(ax.YLim);
    
    m = 100;    % magnification factor...

    % Initialize the indexMap
    indexMap = zeros(yRange*m, xRange*m, 'uint8');

    % Go through every polygonobject, and add its index number to the map.
    for i = 1:numel(h)
        
        % Get x & y coordinates of region boundaries.
        edge = h(i).Shape.Vertices;
        x = (edge(:,1) - xMin) * m;
        y = (edge(:,2) - yMin) * m;

        x(isnan(x))=[];
        y(isnan(y))=[];

        % Create a binary mask for all points that lie within the boundary.
        BW = poly2mask(x, y, yRange*m, xRange*m);
        BW = imfill(BW,'holes');
        BW = imdilate(BW, ones(5,5)); % This expansion fills most of the gaps between regions at 100x magnification.
        
        % Update the index map.
        indexMap(BW) = i;
    end

    % Get area labels form the tag of the patch objects.
    regionLabels = { h.Tag };

    
    % Create filepath for saving file.
    rootPath = fileparts( mfilename('fullpath') );
    fileName = 'regionIndexMap.mat'; 
    savePath = fullfile(rootPath, fileName);
    
    
    S = struct;
    S.indexMap = indexMap;
    S.regionLabels = regionLabels;
    S.magnificationFactor = m;
    S.referencePoint = [xMin, yMin];
    
    save(savePath, '-struct', 'S')

end