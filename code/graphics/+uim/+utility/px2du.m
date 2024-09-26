function varargout = px2du(ax, pixelCoords, recursive)
%px2du Convert pixel coordinates to data unit coordinates
%
%   dataUnits = px2du(ax, pixelCoords)

    % Note: Only supports axes with xlim and ylim [0,1]
    % Todo: Normalize by xRange and yRange
    
    if nargin < 3
        recursive = false; % See getpixelposition doc
    end
    
    % Get Axes position in pixels.
    axPos = getpixelposition(ax, recursive);
    
    xLim = ax.XLim;
    yLim = ax.YLim;
    
    axLim = [xLim', yLim'];
    
    %axLim = reshape(axis(ax), 2, 2);
    axRange = diff(axLim);
    
    if recursive
        dataUnits = (pixelCoords-axPos(1:2)) ./ axPos(3:4) .* axRange + axLim(1, 1:2);
    else
        dataUnits = pixelCoords ./ axPos(3:4) .* axRange + axLim(1, 1:2);
    end
    
    if nargout == 1
        varargout = {dataUnits};
    else
        varargout = {dataUnits(:,1), dataUnits(:,2)};
    end
end
