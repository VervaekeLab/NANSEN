function hGridLines = plotGridLines(hImviewer, numRows, numCols)
%plotGrid Plot grid lines in the imviewer axes

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
    
    % Plot the lines
    hGridLines = line(hImviewer.Axes, [xDataV, xDataH], [yDataV, yDataH]);
    set(hGridLines, 'HitTest', 'off', 'PickableParts', 'none')
end
