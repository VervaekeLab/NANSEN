function saveRegionsAsPolyshapes()

tmpFig = fovmanager.view.openAtlas("paxinos", "Visibility", "invisible");

hAx = findobj(tmpFig, 'type', 'axes');
hPoly = findall(hAx, 'type', 'polygon');

polyShape = {hPoly.Shape};
colors = {hPoly.FaceColor};
tags = {hPoly.Tag};

% Go through polyshapes and set simplify to false to avoid calling
% check and simplify on loading and plotting of polyshapes
for i = 1:numel(polyShape)
    p1 = polyShape{i};
    p2 = polyshape(p1.Vertices, 'Simplify', false);
    polyShape{i} = p2;
end

mapRegions = struct('Shape', polyShape, 'FaceColor', colors, 'Tag', tags);
mapBoundary = struct('Shape', polyShape(31), 'FaceColor', colors(31), 'Tag', tags(31));

rootDir = fileparts( fileparts(mfilename('fullpath')) );
saveDir = fullfile(rootDir, '+brainmap', '+paxinos');
savePath = fullfile(saveDir, 'dorsal_map_polyshapes.mat');

save(savePath, 'mapRegions', 'mapBoundary')
return

% Create patchdata (This is just for the record)
numShapes = numel(polyShape);
[xData, yData] = deal( cell(numShapes, 1) );

for i = 1:numel(polyShape)
    vCoords = polyShape{i}.Vertices;
    
    if i == 31; continue; end
    
    if any(isnan(vCoords(:,1)))
        ind = find(isnan(vCoords(:,1)));
        vCoordsPre = vCoords(1:ind-1, :);
        vCoordsPost = vCoords(ind+1:end, :);
        vCoordsPre(end+1, :) =  vCoordsPre(1, :);
        vCoordsPost(end+1, :) =  vCoordsPost(1, :);
        vCoords = cat(1, vCoordsPre, vCoordsPost);
    end
    
    xData{i} = vCoords(:,1);
    yData{i} = vCoords(:,2);
    
end

xData(31) = [];
yData(31) = [];
colors(31) = [];
tags(31) = [];

mapRegions = struct('XData', xData, 'YData', yData, 'FaceColor', colors', 'Tag', tags');
savePath = strrep(savePath, 'polyshapes.mat', 'patchdata.mat');

% Save regions as patches and boundary as polygon...

save(savePath, 'mapRegions', 'mapBoundary')

end
