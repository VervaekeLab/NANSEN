function pixelCoordinates = du2px(ax, dataUnits, recursive)
%Convert data unit coordinates to pixel coordinates
%
%   pixelCoords = du2px(ax, dataUnits)

% Todo: Does it need to change if axis are reversed... Probably
    
    if nargin < 3
        recursive = false; % See getpixelposition doc
    end
    
    axPos = getpixelposition(ax, recursive);
    axLim = reshape(axis(ax), 2, 2);
    axRange = diff(axLim);
    
% %     ax.YDir
% %     ax.XDir
    
    pixelCoordinates = axPos(1:2) + ...
        (dataUnits - axLim(1, 1:2)) .* axPos(3:4) ./ axRange;

end
