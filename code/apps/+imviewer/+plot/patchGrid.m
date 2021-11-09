function hPatches = patchGrid(hImviewer, numRows, numCols, gridWidth, gridHeight)
%patchGrid Patch grid lines in the imviewer axes

    xLim = [1, hImviewer.imWidth];
    yLim = [1, hImviewer.imHeight];

    % Create a set of points, evenly spaced out between the axes limits
    xPoints = linspace(xLim(1),xLim(2), numCols+1);
    yPoints = linspace(yLim(1),yLim(2), numRows+1);

    % Remove the endpoints
    xPoints = xPoints(2:end-1);
    yPoints = yPoints(2:end-1);

    % Create the coordinates for vertical (V) and horizontal (H) lines
    xDataV = cat(1, xPoints, xPoints);
    yDataV = [repmat(yLim(1), 1, numCols-1); repmat(yLim(2), 1, numCols-1)];
    xDataH = [repmat(xLim(1), 1, numRows-1); repmat(xLim(2), 1, numRows-1)];
    yDataH = cat(1, yPoints, yPoints);

    % Create rectangular coordinates for each of the gridlines (vertical)
    xDataV = cat(1, xDataV, xDataV);
    xDataV(1:2, :) = xDataV(1:2, :) - gridWidth/2;
    xDataV(3:4, :) = xDataV(3:4, :) + gridWidth/2;
    yDataV = cat(1, yDataV, flipud(yDataV));

    % Create rectangular coordinates for each of the gridlines (hrizontal)
    xDataH = cat(1, xDataH, flipud(xDataH));
    yDataH = cat(1, yDataH, yDataH);
    yDataH(1:2, :) = yDataH(1:2, :) - gridHeight/2;
    yDataH(3:4, :) = yDataH(3:4, :) + gridHeight/2;
           
    % Patch vertical grid lines
    hV = patch(obj.imviewerRef.Axes, xDataV, yDataV, 'w');
    
    % Patch horizontal grid lines
    hH = patch(obj.imviewerRef.Axes, xDataH, yDataH, 'w');
    
    hPatches = [hV, hH];
    set(hPatches, 'HitTest', 'off', 'PickableParts', 'none')

end