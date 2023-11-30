function S = getDefaultSettings()

% NB: This will not be updated in a class until matlab is restarted or the
% class is cleared and reinitialized.

    S = struct();
    S.GridSize_ = {'3x5', '4x6', '5x8', '6x10', '7x12', '8x12', '9x14', '10x16'};
    S.GridSize = '8x12';
    S.ImageScaleFactor = '1';
    S.ImageScaleFactor_ = {'1/8', '1/4', '1/2', '1', '2', '4', '8'};
    S.TileAlpha_ = struct('type', 'slider', 'args', {{'Min', 0, 'Max', 1}}); 
    S.TileAlpha = 0.5;
    S.DeleteRejectedTilesOnRefresh = false;
    S.IgnoreClassifiedTileOnShiftClick = true;

end
