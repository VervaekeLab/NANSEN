function S = getDefaultSettings()

% NB: This will not be updated in a class until matlab is restarted or the
% class is cleared and reinitialized.

    S = struct();
    S.GridSize_ = {'Custom', '3x5', '4x6', '5x8', '6x10', '7x12', '8x12', '9x14', '10x16'};
    S.GridSize = '8x12';
    S.CustomGridSize = [3, 5];
    S.ImageSize_ = {'30x30', '50x50', '75x75', '100x100', '128x128', '256x256'};
    S.ImageSize = '100x100';
    S.TileAlpha_ = struct('type', 'slider', 'args', {{'Min', 0, 'Max', 1}}); 
    S.TileAlpha = 0.5;
    S.DeleteRejectedTilesOnRefresh = false;
    S.IgnoreClassifiedTileOnShiftClick = true;

end
