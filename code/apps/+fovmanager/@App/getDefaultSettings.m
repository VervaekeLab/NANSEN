function S = getDefaultSettings()

% NB: This will not be updated in a class until matlab is restarted or the
% class is cleared and reinitialized.

S = struct();
S.defaultFilePath = ''; ...
S.useDefaultPath = false;
S.opaqueBackground = false;
S.showGrayscaleImages = false;
S.showInjections = true;
S.hemisphereToLabel_ = {'right', 'left'}; % left|right
S.hemisphereToLabel = 'right'; % left|right
S.askBeforeDelete = true;
S.fovOrientation = struct('flipVertical', false, 'flipHorizontal', false, 'rotationAngle', -90);


end
