function S = getDefaultSettings()

% NB: This will not be updated in a class until matlab is restarted or the
% class is cleared and reinitialized.


S = struct();



%S.showMovingAvg = false;        % Show moving average of images...
%S.binningSize   = 9;            % Binning size for moving average

%S.cLim          = [0,255];      % Color brightness limits of displayed images

% Options for image display
S.ImageDisplay.brightnessSliderLimits = [0, 1];  % Should be automatically adjusted based on loaded image data, but allow for manual override
S.ImageDisplay.imageBrightnessLimits = [0,255]; % Color brightness limits of displayed images

S.ImageDisplay.movingBinSize        = 9;

S.ImageDisplay.colorMap      = 'Gray'; % Colormap selection
S.ImageDisplay.colorMap_     = {'Viridis', 'Magma', 'Gray', 'Copper', 'Bone', ...
                                'Nissl', 'BuPu', 'GnBu', 'Greens', 'PuBuGn', 'YlOrRd', ...
                                'thermal', 'haline', 'solar', 'ice', 'deep', 'dense', ...
                                'algae','matter','turbid','speed', 'amp','tempo' }; % Colormap alternatives


% S.ImageStack.DataDimensionOrder = '';
% S.ImageStack.PixelSize = [1, 1];
% S.ImageStack.PixelUnits = ["um", "um"];
% S.ImageStack.SampleRate = 1;


% Options for loading virtual stacks..
S.VirtualData.useDynamicCache  = true;         % Number of frames to keep in memory when working with virtual stacks.
S.VirtualData.dynamicCacheSize = 1000;         % Number of frames to keep in memory when working with virtual stacks. Should be part of imageStack..
S.VirtualData.initialFrameToLoad = 1;
S.VirtualData.numFramesToLoad  = 1000;
S.VirtualData.target           = 'Add To Memory';
S.VirtualData.target_          = {'Add To Memory', 'Replace Stack', 'New Window'};
S.VirtualData.preprocessData   = true;


% Options for app mouse/keyboard interactions
S.Interaction.zoomFactor    = 0.25;         % Not currently used, should be part of pointerInterface/zoomingtools
S.Interaction.panFactor     = 0.25;         % Not currently used, should be part of pointerInterface/pantool
S.Interaction.scrollFactor  = 1;            % Scroll sensitivity for frame scrolling or zoom scrolling
S.Interaction.scrollFactor_ = struct('type', 'slider', 'args', {{'Min', 1, 'Max', 10}});
                     

% Options for app layout
S.AppLayout.showHeader              = true;
S.AppLayout.showFooter              = true;

% S.ImageToolbarOrientation = 'horizontal';
% S.ImageToolbarOrientation_ = {'horizontal', 'vertical'};

S.AppLayout.imageToolbarLocation    = 'northwest';
S.AppLayout.imageToolbarLocation_   = {'northwest', 'southwest', 'northeast', 'southeast'};


end
