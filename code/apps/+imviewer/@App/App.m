classdef App < applify.ModularApp & applify.mixin.UserSettings & applify.AppWithPlugin
    
% Interactive figure inspired by imageJ for displaying images and stacks
%
%   imviewer without any inputs opens a browser for locating tiff file or 
%   avi files. Loads files in virtual mode, reading those frames that are 
%   requested. 
%   
%   imviewer(filepath) opens file specified by path.   
%
%   imviewer(varName) opens imviewer with a variable from the workspace,
%   i.e an an array containing image data.
%
%   imviewer([]) opens an empty imviewer instance where images from another
%   imviewer or files can be dropped.
%   
%   Useful keyboard shortcuts
%       p : play video
%       > : play 2x faster
%       < : play 2x slower
%       b : show brightness enhanced average image of all images
%       n : show average image of all images
%       m : show maximum image of all images
%       arrows (left and right) : previous or next image
%       arrows (up and down) : make window bigger or smaller

% Features of this app that can be generalized...?
%   
%   App with user settings
%   App with light/dark theme?
%   App with (user selected) theme?


% Can I create multiple menu items in one go?
    
% Note: minimized figures retains their unminimized position. Can be
% confusing if trying to drop an image into an imviewer instance if there
% is a minimized version in the same place.

% TODO:
%   [x] setSliderLimits : should use imagestack for getting limits
%   [ ] Make brightness slider for each channel...
%   [ ] need a method for resizing panel without invoking its sizechanged function
%   [ ] Find a way to turn preprocessing on and off when opening sciscan raw
%       stack..
%   [ ] Fix bug: when opening new stack in same viewer, need to reset
%       thumbnailviewer
%   [ ] Zoom is not working if image/axes aspect ratio is different from 1???
%   [ ] Only resize thumbnail selector if it is visible!
%   [ ] Methods for resizing on visible on/off if position changed.
%   [ ] Linking currentFrameNo with another viewer (i.e) signalviewer
%       significantly slows down playback
%
%   [x] keep virtual stack reference if loading images into memory, and add
%       button for toggling between virtual stack and in memory...
%
%   [x] enable/disable toggle virtual stack button if a memory stack is
%       added...
%
%   [x] Add waitbar when loading
%
%   [x] Super visible indicator for if stack is virtual or not. (scrollbar??)
%
%   [ ] Save/load image settings...
%
%   [ ] Create annotation axes, for plotting things... But hide image
%       axes from properties

properties (Constant, Hidden = true) % Move to appwindow superclass
    DEFAULT_THEME = nansen.theme.getThemeColors('dark-gray');
end

properties (Constant, Hidden = true) % Inherited from UserSettings
    USE_DEFAULT_SETTINGS = false
    DEFAULT_SETTINGS = imviewer.App.getDefaultSettings()
    ICONS = uim.style.iconSet(imviewer.App.getIconPath)
end

properties (Constant) % Inherited from ModularApp
    AppName = 'imviewer';
end

properties (Transient = true, Dependent = true)
    %Figure
    Axes 
end

properties (SetAccess = private, SetObservable) % Image data properties
    ImageStack (1,1) nansen.stack.ImageStack
end

properties (SetAccess = private) % Image data properties
    CurrentImage                            % Current image on display (original image data)
    DisplayedImage                          % Actual image on display (this image can be spatially resampled and have a applied color model...)
    
    image                                   % Current image | Todo: Rename to DisplayedImage
                                    
    ImageResolution %Dep? Which is the best name
    FrameResolution %Dep?
    nSamples % Number of samples in imagestack.. (dependent??)
end

properties (Access = public, SetObservable) % Current frame selection
    currentFrameNo (1,1) double = 1 % Current frame number
    currentChannel (1,:) double = 1 % List of channels that are displayed.
    currentPlane   (1,:) double = 1 % List of planes that are displayed.
end

properties (Dependent)
    ChannelColors
end

properties (Access = public) % Components
    LinkedApps % Todo: Make superclass for timeseries viewer. Property: currentSampleNum & Methods for synching samplenumber...

    uiwidgets = struct() % Todo: Inherit from modular app?
    plugins = struct('pluginName', {}, 'pluginHandle', {}); % Todo: migrate to AppWithPlugin superclass
end

properties (Access = private) % Private components (todo: clean up)
    
    uiaxes = struct()
    
    positionInfo = struct('Margin', [1, 20]); % Todo: remove /move to super...
    
    % Graphical handles
    imObj % Rename to hImage
    infoField
    
    zoomOutline
    tmpHandles
    
    % Widgets / interfaces / 
    brightnessSlider

    dndObj
    hDropbox
    hDropbox2
    hThumbnail 


    textStrings = struct('CurrentFrame', '', 'Resolution', '', 'CursorPoint', '', 'Status', '');
        
end

properties (Access = public, Hidden)
    ImageProcessingFcn = [] 
end

properties (Access = public, Hidden) % Todo: clean up: These should be dependent and correspond with imagestack properties

    % Properties that should go into imageStack class
    stackname = ''
    
    isRgb = false
    
    % All these should be very easily accessible from imageStack
    imHeight
    imWidth
    nFrames                 % (nChannels x nPlanes x nSamples)
    
end

properties (Hidden = true)
    imageDisplayMode = struct('projection', 'none', 'binning', 'none', 'filter', 'none');
    ImageDragAndDropEnabled = true;
    
    isPlaying = false; % Make part of playbackcontrol
    playbackspeed = 1; % Make part of playbackcontrol
    imTheta = 0;
end

properties (Access = public, Dependent = true) % Superclass? (modular app)
    Visible
end

properties (Access = private, Dependent = true) % Aspect ratios
    axesAspectRatio
    imageAspectRatio
end

properties (Access = private, Hidden = true) % Internal states/settings
    
    showHeader = true;
    showFooter = true;
    
    % Under construction... % make struct? 
    % modifier = struct('shift', false, 'alt', false, 'control', false)
    DeleteImageStackOnQuit
    DownsampleDisplayedImage = true
    
    prevMousePoint
    scrollHistory = zeros(5,1)
    mouseDown = false
    isDrag = false
    
    isAltDown = false;
    isShiftDown = false;
    isControlDown = false;
    isImageToolbarPinned = false;
    isThumbnailSelectorPinned = false; % Todo: move to class...
    autoAdjustLimits = false;

    limitsListener
    FigureLocationChangedListener
end



methods % Structors
         
    function obj = App(varargin) % Constructor
        
        [h, varargin] = applify.ModularApp.splitArgs(varargin{:});
        obj@applify.ModularApp(h);
        
        if isempty(varargin)
            dataref = '';
        else
            dataref = varargin{1};
            varargin = varargin(2:end);
        end
        
        % todo: method....
        stackOpts = struct();
        stackOpts.PreprocessOnLoad = obj.settings.VirtualData.preprocessData;
        stackOpts.UseDynamicCache = obj.settings.VirtualData.useDynamicCache;
        stackOpts.DynamicCacheSize = obj.settings.VirtualData.dynamicCacheSize;

        nvPairs = utility.struct2nvpairs(stackOpts);
        nvPairs = [nvPairs, varargin{:}];
        
        % Check if data ref is an imageStack object, initialize if not.
        if ~isa(dataref, 'nansen.stack.ImageStack') % && ~isa(dataref, 'imviewer.ImageStack')
            %obj.ImageStack = imviewer.stack.initialize(dataref, nvPairs);
            obj.ImageStack = nansen.stack.ImageStack(dataref, nvPairs{:});
            obj.DeleteImageStackOnQuit = true;
            %if isempty(obj.ImageStack); 
                %fprintf('Aborted...\n'); clear obj; return; 
            %end
        else
            obj.ImageStack = dataref;
            obj.DeleteImageStackOnQuit = false;
        end
        
        
        obj.matlabVersionCheck() % Todo: This is not a method of imviewer...

        % Run this after imageArray is parsed. Basically, varargins can 
        % overwrite values set in parseimage array. Todo: Change this later.
        % parseImageArray should be part of imageStack class, so that
        % function will change dramatically later...
        % obj.parseVarargin(varargin{:})
        
        warning('off', 'MATLAB:ui:javaframe:PropertyToBeRemoved')
        obj.initializeViewer()
        warning('on', 'MATLAB:ui:javaframe:PropertyToBeRemoved')
        
        setappdata(obj.Figure, 'ViewerObject', obj)
        
        % Add app instance to a global variable. Used in certain cases
        % where an app needs to know about other apps that are open.
        obj.registerApp()
        
        obj.resizePanel(obj.Panel)
        
        obj.isConstructed = true; %obj.onThemeChanged()
        
        if ~all(isnan(obj.DisplayedImage(:)))
            set(obj.hDropbox, 'Visible', 'off')
        end
        
        if nargout == 0
            clear obj
        end
        
    end
    
    function delete(obj) % Destructor
        obj.unregisterApp()
        
        if ~isempty(obj.dndObj)
            delete(obj.dndObj)
        end
        
        if ~isempty(obj.ImageStack)
            if obj.DeleteImageStackOnQuit
                delete(obj.ImageStack)
            end
        end
        
        clear obj
        
    end
    
    function quit(obj)
        obj.quitImviewer()
    end
    
    function quitImviewer(obj, ~, ~)
        
        if ~isvalid(obj); return; end
        
        if obj.DeleteImageStackOnQuit
            delete(obj.ImageStack)
        end
        
        obj.unregisterApp()
        obj.saveSettings()
        delete(obj.Figure)
        delete(obj.dndObj)
        delete(obj)
        clear('obj')
        
        % Todo: Test: Do i need to delete plugins here?
    end
   
end

methods (Access = protected)

    function createAppWindow(obj)
        
        createAppWindow@applify.ModularApp(obj)
        
        obj.setFigureName()
        obj.Figure.Resize = 'off';
        
        obj.Figure.CloseRequestFcn = @obj.quitImviewer;
    end

%     function setDefaultFigureCallbacks(obj, hFig)
%         
%         if nargin < 2 || isempty(hFig)
%             hFig = obj.Figure;
%         end
%         
%         if strcmp(obj.mode, 'standalone')
%             % Need to set these instead of listeners to prevent each
%             % keypress to go back to the matlab command line
%             
%             hFig.WindowKeyPressFcn = @obj.keyPress;
%             hFig.WindowKeyReleaseFcn = @obj.keyRelease;
%             
%         elseif strcmp(obj.mode, 'docked')
%             % Use listeners so that this module does not occupy the
%             % WindowKeyPressFcn & WindowKeyReleaseFcn properties.
%             
%             obj.FigureInteractionListeners.WindowButtonDown = addlistener(...
%                 hFig, 'KeyPress', @obj.keyPress);
% 
%             obj.FigureInteractionListeners.WindowButtonDown = addlistener(...
%                 hFig, 'KeyRelease', @obj.keyRelease);
%         end
%         
% %         hFig.WindowScrollWheelFcn = @obj.mouseScrollCallbackHandler;
% %         hFig.WindowButtonDownFcn = @obj.mousePressed;
% %         hFig.WindowButtonMotionFcn = @obj.mouseOver;
% %         hFig.WindowButtonUpFcn = @obj.mouseRelease;
% 
%         obj.FigureInteractionListeners.WindowScrollWheel = addlistener(...
%             hFig, 'WindowScrollWheel', @obj.mouseScrollCallbackHandler);
%                     
%         obj.FigureInteractionListeners.WindowButtonDown = addlistener(...
%             hFig, 'WindowMousePress', @obj.mousePressed);
%             
%         obj.FigureInteractionListeners.WindowMouseMotion = addlistener(...
%             hFig, 'WindowMouseMotion', @obj.mouseOver);
%         
%         obj.FigureInteractionListeners.WindowButtonReleased = addlistener(...
%             hFig, 'WindowMouseRelease', @obj.mouseRelease);
%         
%     end

end % Overrides ModularApp methods

methods % App initialization & creation
    
    function registerApp(obj)
        global imviewerInstances
        if isempty(imviewerInstances)
            imviewerInstances = struct('Handles', imviewer.App.empty, ...
                'PreviousInstance', [], 'IsMouseDown', false);
        end

        imviewerInstances.Handles(end+1) = obj;
        imviewerInstances.PreviousInstance = obj;
        
    end
    
    function unregisterApp(obj)
        global imviewerInstances
        if isempty(imviewerInstances); return; end
        if isempty(imviewerInstances.Handles); return; end
        
        IND = ismember(imviewerInstances.Handles, obj);
        imviewerInstances.Handles(IND) = [];
        imviewerInstances.PreviousInstance = [];
    end
    
    function parseVarargin(obj, varargin)
        
        default = struct();
        default.imageBrightnessLimits = [];
        
        options = utility.parsenvpairs(default, 1, varargin);
        
        if ~isempty(options.imageBrightnessLimits)
            obj.settings.ImageDisplay.imageBrightnessLimits = options.imageBrightnessLimits;
        end
        
    end
 
% % Functions for creating the gui
    
    function initializeViewer(obj)
        
        [figurePosition, axesSize] = obj.initializeFigurePosition();
        %obj.createFigure(figurePosition)
        
        if strcmp( obj.mode, 'standalone' )
            obj.Figure.Position = figurePosition;
            obj.Panel.Position(3:4) = figurePosition(3:4); %Todo: Set this automatically through callbacks
        end
        
        obj.createUiAxes(axesSize)
        
        obj.updateImage()
        obj.updateImageDisplay()
        obj.updateInfoText();

        obj.changeColormap()
        obj.plotZoomRegion()
        
%         if obj.nFrames > 1
            obj.createPlaybackWidget()
%         end

        obj.onThemeChanged() % Apply theme colors...
        
        % Need to turn on figure visibility here because otherwise some
        % features of initialization does not work. Is it only DND? find
        % out and clean up
        if strcmp(obj.mode, 'standalone')
            obj.resizePanelContents(obj.Panel, 1, 'width') % Call this to make sure all content are size appropriately before figure is made visible. Todo: Should improve this, i.e should be taken care of by callback functions!
            obj.Figure.Visible = 'on';
        end
        
        % obj.setDefaultFigureCallbacks() Should be done onConstruction in superclass.

        obj.uiwidgets.msgBox = uim.widget.messageBox(obj.uiaxes.imdisplay);
        %obj.displayMessage('Initializing...')
        
        global fprintf
        fprintf = @(msg, nSec) obj.uiwidgets.msgBox.displayMessage(msg, 1);
        
        
        % Initialize the pointer interface.
        pif = uim.interface.pointerManager(obj.Figure, obj.uiaxes.imdisplay, {'zoomIn', 'zoomOut', 'pan'});
        pif.pointers.pan.buttonMotionCallback = @obj.moveImage;
        obj.plugins(end+1).pluginName = 'pointerManager';
        obj.plugins(end).pluginHandle = pif;        
        
        % A bit random to do this here, but for now it only influences the
        % pointerManager zoom tools
        obj.configureSpatialDownsampling()

        
        % Create UIComponentCanvas for drawing uicontrols and widgets on
        uicc = uim.UIComponentCanvas(obj.Panel);
        setappdata(obj.Figure, 'UIComponentCanvas', uicc);
        
        
        obj.createBrightnessSlider()

        
        % Create toolbars
        obj.addImageToolbar()
        obj.addAppToolbar()
        
        % obj.addTaskbar()
% %         obj.openThumbnailSelector()

        
        % Manually set moving avg to false when opening stack
        obj.settings.showMovingAvg = false;
    
% % %          t = timer('ExecutionMode', 'singleShot', 'StartDelay', 1);
% % %          t.TimerFcn = @(myTimerObj, thisEvent) obj.postStartup(t);
% % %          start(t)
                 
        obj.clearMessage()
        obj.addLandingPage()
        
        % This should happen after all components are created...
        uicc.bringTooltipToFront()
        
        obj.Panel.SizeChangedFcn = @obj.resizePanel;
        
        
        drawnow
        obj.setFigureWindowBackgroundColor() %BG of java window. Set
        
        if strcmp(obj.mode, 'standalone')
            obj.addDragAndDropFunctionality()
        end
        
% because otherwise figure background appears white on resizing
        
    end
    
    
    function postStartup(obj, hTimer)
        disp('a')
        obj.openThumbnailSelector()
        obj.addTaskbar()
        
        if nargin >=2 && ~isempty(hTimer) && isvalid(hTimer)
            stop(hTimer)
            delete(hTimer)
        end
        
    end
    
    
    function axesSize = initializeAxesSize(obj)
        
        % Get screensize to set up axes position
        screenSize = get(0, 'Screensize');
        screenAspectRatio = screenSize(3)/screenSize(4);
        
        % Initialize the axes size to half the size of the screen.
        axesSize = screenSize(3:4) .* 0.5;
        
        % Adjust to maintain aspect ratio of image
        if obj.imageAspectRatio > screenAspectRatio
            axesSize(2) = axesSize(1) ./ obj.imageAspectRatio;
        else
            axesSize(1) = axesSize(2) .* obj.imageAspectRatio;
        end
        
        axesSize = round(axesSize);
    end
    
   
% % Methods for resizing..

    function newAxesSize = updateAxesSize(obj, resizeMode, preserveAr)     
    %updateAxesSize Calculate axes size for given resize mode
    
        if nargin < 2 || isempty(preserveAr)
            preserveAr = true;
        end
        
        STEPSIZE = 100;
        
        if strcmp(resizeMode, 'shrink')
            STEPSIZE = -1*STEPSIZE;
        end
        
        currentAxesPos = getpixelposition(obj.uiaxes.imdisplay);
                
        % Step 100 in the longest direction.
        if preserveAr
            if obj.imageAspectRatio <= 1
                newAxesSize(2) = currentAxesPos(4) + STEPSIZE;
                newAxesSize(1) = newAxesSize(2) .* obj.imageAspectRatio;
            elseif obj.imageAspectRatio > 1
                newAxesSize(1) = currentAxesPos(3) + STEPSIZE;
                newAxesSize(2) = newAxesSize(1) ./ obj.imageAspectRatio;
            end
        
        else
            deltaSize = STEPSIZE ./ [1, obj.imageAspectRatio];
            newAxesSize = currentAxesPos(3:4) + deltaSize;
        end
        
        % Determine the maximum axes size based on available screen space
        screenSize = obj.getCurrentMonitorSize(obj.Figure);
        maxAxesSize = screenSize(3:4);

        if obj.showFooter 
            maxAxesSize(2) = maxAxesSize(2) - obj.positionInfo.Margin(2);
        end
        
        if obj.showHeader
            maxAxesSize(2) = maxAxesSize(2) - obj.positionInfo.Margin(2);
        end
        
        
        % Make sure axes size is not too large to fit on screen
        if any(newAxesSize > maxAxesSize)
            newAxesSize = min([newAxesSize; maxAxesSize]);
        end
        
        % Specify minimum figure size
        minAxesSize = [100, 100];

        
        % Make sure axes size is not smaller than the minimum size
        if any(newAxesSize > maxAxesSize)
            newAxesSize = max([minAxesSize; newAxesSize]);
        end
        
        newAxesSize = round(newAxesSize);
        
        % Todo: Potential nightmare of keeping aspect ratio....
    end
    
    function newAxSize = getAxesSize(obj, panelSize, preserveAspectRatio, mode)
    %getAxesSize Get axes size within panel 
        
        if nargin < 4
            mode = 'auto';
        end
    
        axesMargins = obj.positionInfo.Margin;
        
        yMargin = sum([obj.showHeader, obj.showFooter]) .* axesMargins(2);
        
        newAxSize = panelSize - [axesMargins(1)*2, yMargin];
       
        if preserveAspectRatio
            axesAr = obj.getAspectRatio(newAxSize);
            imageAr = obj.imageAspectRatio;
            
            switch mode
                case 'auto'
                    if axesAr > imageAr
                        newAxSize(1) = newAxSize(2) .* imageAr;
                    elseif axesAr < imageAr
                        newAxSize(2) = newAxSize(1) ./ imageAr;
                    end
                case 'width'
                    newAxSize(2) = newAxSize(1) ./ imageAr;
                case 'height'
                    newAxSize(1) = newAxSize(2) .* imageAr;

            end
        end
        
        newAxSize = round(newAxSize);

    end
    
    function figureSize = getFigureSize(obj, axesSize)
    %getFigureSize Get figure size given axes size
    
        margins = [obj.positionInfo.Margin(1)*2, 0];
        
        if obj.showHeader
            margins(2) = margins(2) + obj.positionInfo.Margin(2);
        end
        
        if obj.showFooter
            margins(2) = margins(2) + obj.positionInfo.Margin(2);
        end
        
        figureSize = axesSize + margins;
        
    end
    
    function maxFigureSize = getMaximumFigureSize(obj)
    %getFigureSize Get maximum figure size
    
        screenSize = obj.getCurrentMonitorSize(obj.Figure);
        maxFigureSize = screenSize(3:4);
        
    end
    
    
% % Methods for creating / configuring figure..

    function createFigure(obj, figurePosition)

        %hFig = figure('Visible', 'off');
        %obj.Figure = hFig;
        obj.Figure.Position = figurePosition;
               
        obj.Figure.Color = [0.05,0.05,0.05];
        %obj.Figure.MenuBar = 'none';
        %obj.Figure.NumberTitle = 'off';
        %obj.Figure.Name = sprintf('StackViewer (%d): %s', obj.Figure.Number, obj.stackname);
        
        %obj.Figure.Resize = 'off';
        obj.Figure.CloseRequestFcn = @obj.quitImviewer;
       
        
        obj.Panel = uipanel(hFig);
        obj.Panel.BackgroundColor = obj.Figure.Color;
        obj.Panel.BorderType = 'none';
        obj.Panel.Position = [0,0,1,1];
        obj.Panel.Units = 'pixel';
        
        % obj.setFigureWindowBackgroundColor() %BG of java window. Set because 
        % resizing is glitcy, and even if figure background is dark, the
        % glitches rshow a white background.

        % Todo:
        %obj.Figure.SizeChangedFcn = {@obj.resizeWindow, []};

    end
    
    function setFigureName(obj)
        
        isValidFigure = ~isempty(obj.Figure) && isvalid(obj.Figure);
        
        if isValidFigure && strcmp(obj.mode, 'standalone')
                        
            if isempty(obj.stackname)
                figureName = sprintf('%s (%d)', obj.AppName, ...
                        obj.Figure.Number );
            else
                figureName = sprintf('%s (%d): %s', obj.AppName, ...
                        obj.Figure.Number, obj.stackname );
            end
            
            obj.Figure.Name = figureName;
        end
    end
    
    function setFigureWindowBackgroundColor(obj, newColor)
        
        if nargin < 2
            newColor = [13,13,13] ./ 255;
        end
        
        rgb = num2cell(newColor);
        
        warning('off', 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
        warning('off', 'MATLAB:ui:javaframe:PropertyToBeRemoved')
        
        % Its disappearing any day now!
        jFrame = get(handle(obj.Figure), 'JavaFrame'); %#ok<JAVFM>
        jWindow = jFrame.getFigurePanelContainer.getTopLevelAncestor;
        javaColor = javax.swing.plaf.ColorUIResource(rgb{:});
        set(jWindow, 'Background', javaColor)
        
        warning('on', 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
        warning('on', 'MATLAB:ui:javaframe:PropertyToBeRemoved')
        
    end

    function createUiAxes(obj, axesSize)
        
        pixelMargins = obj.positionInfo.Margin;
        
        % Create axes for displaying images
        if obj.isMatlabPre2018b
            axArgs = {'Parent', obj.Panel};
        else
            axArgs = {'Parent', obj.Panel, 'Toolbar', []};
        end
        
        
        % Create axes for displaying images
        obj.uiaxes.imdisplay = axes(axArgs{:});
        
        obj.uiaxes.imdisplay.Units = 'pixel';

        obj.uiaxes.imdisplay.Position = [pixelMargins+1, axesSize];
        obj.uiaxes.imdisplay.XTick = [];
        obj.uiaxes.imdisplay.YTick = [];
        obj.uiaxes.imdisplay.Box = 'on';
        obj.uiaxes.imdisplay.Tag = 'Image Display';
        hold(obj.uiaxes.imdisplay, 'on')
        obj.uiaxes.imdisplay.XAxis.Visible = 'off';
        obj.uiaxes.imdisplay.YAxis.Visible = 'off';

        axis(obj.uiaxes.imdisplay, 'equal')
        
        obj.uiaxes.imdisplay.XLim = [0, obj.imWidth] + 0.5;
        obj.uiaxes.imdisplay.YLim = [0, obj.imHeight] + 0.5;
        
        obj.uiaxes.imdisplay.HitTest = 'on';
        obj.uiaxes.imdisplay.PickableParts = 'all';

        obj.uiaxes.imdisplay.UIContextMenu = uicontextmenu(obj.Figure);
        obj.createImageMenu(obj.uiaxes.imdisplay.UIContextMenu);
        
        
        figSize = getpixelposition(obj.Figure);
        figSize = figSize(3:4);

        % Create Axes for displaying text
        obj.uiaxes.textdisplay = axes(axArgs{:});
        
        obj.uiaxes.textdisplay.Units = 'pixel';
        obj.uiaxes.textdisplay.Position = [0, figSize(2) - pixelMargins(2), ...
                                  figSize(1), pixelMargins(2)-pixelMargins(1)+4]; 
        obj.uiaxes.textdisplay.YAxis.Visible = 'off'; 
        obj.uiaxes.textdisplay.XTick = []; 
        obj.uiaxes.textdisplay.YTick = [];
        obj.uiaxes.textdisplay.HandleVisibility = 'off';
        obj.uiaxes.textdisplay.Tag = 'Text Display';
        %obj.uiaxes.textdisplay.Visible = 'off';

        
        obj.infoField = text(0.01, 0.45, '', 'Parent', obj.uiaxes.textdisplay);%, 'FontName', 'Thonburi'
        obj.infoField.FontSize = 13;
        obj.infoField.HorizontalAlignment = 'left';
        obj.infoField.VerticalAlignment = 'middle';
        % obj.infoField.BackgroundColor = [0.2,0.2,0.2];
%         obj.infoField.BackgroundColor = [1,1,1];
        
        obj.uiaxes.textdisplay.XLim = [0,1];
        obj.uiaxes.textdisplay.YLim = [0,1];
        hold(obj.uiaxes.textdisplay, 'on')
        
        obj.turnOffModernAxesToolbar(obj.uiaxes.textdisplay)
        obj.turnOffModernAxesToolbar(obj.uiaxes.imdisplay)

    end
    
    function createPlaybackWidget(obj)
    %createPlaybackWidget Create widget with playback controls
        
        pixelMargins = obj.positionInfo.Margin;
        
        figSize = getpixelposition(obj.Panel);
        figSize = figSize(3:4);

        scrollerSize = [figSize(1), pixelMargins(2)];
        scrollerPosition = [0, 0, scrollerSize];
        
        obj.uiwidgets.playback = uim.widget.PlaybackControl(obj, ...
            obj.Panel, 'Position', scrollerPosition, 'Minimum', 1, ...
            'Value', obj.currentFrameNo, 'Maximum', obj.nFrames, ...
            'RangeSelectorEnabled', 'off', 'NumChannels', obj.ImageStack.NumChannels, ...
            'ChannelColors', obj.ChannelColors);
        
        obj.uiwidgets.playback.ActiveRangeChangedFcn = ...
            @obj.onFrameIntervalSelectionChanged;
        
        obj.uiwidgets.playback.Visible = 'on';
        
        obj.uiwidgets.playback.NumChannels = obj.ImageStack.NumChannels;
        obj.uiwidgets.playback.CurrentChannels = obj.currentChannel;
    end
    
    function addLandingPage(obj)
        
% %         pathstr = '/Users/eivinhen/PhD/Programmering/MATLAB/ExternalLabs/LettenCenter/imviewer/landing.png';
% %         [im, ~, ALPHA] = imread(pathstr);
% %         im = mean(im, 3);
% %         im = (im-min(im(:))) ./ range(im(:));
% %         im = stack.reshape.imexpand(im, [1500,1500]);
% %         im = imcomplement(im);
% %         ALPHA = stack.reshape.imexpand(ALPHA, [1500,1500]);
% %         himageInit = image(im, 'XData', [1,512], 'YData', [1,512], 'Parent', obj.uiaxes.imdisplay);
% %         %himageInit.AlphaData = ALPHA;
    
        % todo: Add a browse button..


        uicc = getappdata(obj.Figure, 'UIComponentCanvas');
% % 
% %         axesXLim = uicc.Axes.XLim;
% %         axesYLim = uicc.Axes.YLim;
        
        axesXLim = [1,512];
        axesYLim = [1,512];
        
        
% %         hBox = uim.decorator.box(uicc, 'Size', [250, 60], 'SizeMode', 'manual', ...
% %             'Location', 'center', 'HorizontalAlignment', 'center', ...
% %             'VerticalAlignment', 'middle');
% %         hBox.BorderWidth = 1;
% %         hBox.BorderColor = 'w';
% %         hBox.CornerRadius = 10;
        
        
        rectSize = [250, 60]; cornerRadius = 10;
        [X, Y] = uim.shape.rectangle( rectSize, cornerRadius );
        
        X = X + axesXLim(1) + (range(axesXLim) - range(X))/2;
        Y = Y + axesYLim(1) + (range(axesYLim) - range(Y))/2;
        
        h = plot(obj.uiaxes.imdisplay, X, Y, '--', 'Color', obj.Theme.FigureFgColor, 'LineWidth', 1);
        h2 = text(obj.uiaxes.imdisplay, mean(X), mean(Y), 'Drag & Drop Here');
        h2.HorizontalAlignment = 'center';
        h2.VerticalAlignment = 'middle';
        h2.Color = obj.Theme.FigureFgColor;
        hBox.BorderColor = obj.Theme.FigureFgColor;
        h2.FontSize = 20;
        
        % Important...lol
        set([h,h2], 'HitTest', 'off', 'PickableParts', 'none')
        
        uistack(h, 'bottom')
        uistack(h2, 'bottom')
        
        obj.hDropbox = [h, h2];
        
        
% %         hButton = uim.control.Button_(obj.Panel, 'Text', 'Load Images...', ...
% %             'Size', [100, 25], 'SizeMode', 'manual', ...
% %             'Location', 'center', 'HorizontalAlignment', 'center', ...
% %             'VerticalAlignment', 'middle', 'Margin', [0,-75,0,0], ...
% %             'HorizontalTextAlignment', 'center');
% %         
% %         obj.hDropbox2 = hButton;
    end

    function addDragAndDropFunctionality(obj)
        
        drawnow;
        
        warning('off', 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
        warning('off', 'MATLAB:ui:javaframe:PropertyToBeRemoved')
        
        jFrame = get(obj.Figure, 'JavaFrame'); %#ok<JAVFM>
        jWindow = jFrame.getFigurePanelContainer.getTopLevelAncestor;
            
        warning('on', 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
        warning('on', 'MATLAB:ui:javaframe:PropertyToBeRemoved')

        dndcontrol.initJava();
        
        % Create dndcontrol for the JTextArea object
        obj.dndObj = dndcontrol(jWindow);

        % Set Drop callback functions
        obj.dndObj.DropFileFcn = @obj.fileDropFcn;
        
    end
    
    function fileDropFcn(obj, ~, evt)

        switch evt.DropType
            case 'file'
                
                [~, ~, ext] = fileparts(evt.Data{1});
                
                switch ext
                    case '.mat'
                        S = whos('-file', evt.Data{1});
                        if ~isempty(S) && contains(S.name, 'roiArray')
                            S = load(evt.Data{1});
                            numColors = size(obj.Axes.ColorOrder, 1);
                            color = obj.Axes.ColorOrder(randi(numColors), :);
                            h = imviewer.plot.plotRoiArray(obj.Axes, S.roiArray);
                            set(h, 'Color', color);
                        elseif ~isempty(S) && contains(S.name, 'roi_arr')
                            S = load(evt.Data{1});
                            numColors = size(obj.Axes.ColorOrder, 1);
                            color = obj.Axes.ColorOrder(randi(numColors), :);
                            h = imviewer.plot.plotRoiArray(obj.Axes, S.roi_arr);
                            set(h, 'Color', color);
                        end
                            
                    otherwise % assume image file...
                        
                        obj.resetImageDisplay()
                        
                        obj.displayMessage('Loading File')
                        for n = 1%:numel(evt.Data)
                            obj.ImageStack = nansen.stack.ImageStack(evt.Data{1});
                        end
                end      
                
            case 'string'
                
            case 'image'
                
        end
        
        % Need to reset slider limits first, so that when low and high
        % value are set, the slider has the  correct range for it
        
        % Todo: I think I changed this...
        % Need a method for this, if there is not...
        obj.setSliderLimits( obj.ImageStack.DataIntensityLimits )
        
        
        obj.setTempProperties()
        obj.setFigureName()

        
        [figurePosition, ~] = initializeFigurePosition(obj);
        deltaPos = figurePosition(3:4) - obj.Figure.Position(3:4);
        obj.resizeWindow([], [], 'manual', deltaPos)
        obj.updateImage()
        obj.updateImageDisplay()
        
        
        obj.clearMessage()
        
    end
    
    function createImageMenu(obj, m)
        
        % todo: get this from an external function.
        
        mitem = uimenu(m, 'Label', 'Set Colormap');
        colormapNames = obj.settings.ImageDisplay.colorMap_;
        
        for i = 1:numel(colormapNames)
            tmpItem = uimenu(mitem, 'Label', colormapNames{i});
            tmpItem.Callback = @obj.changeColormap;
        end
        
        mitem = uimenu(m, 'Label', 'Calculate Projection', 'Separator', 'on');
        projectionPackage = {'stack','zproject'};
        
        result = what(fullfile(projectionPackage{:}));
        for i = 1:numel(result(1).m)
            funcName = strrep(result(1).m{i}, '.m', '');
            textLabel = utility.string.varname2label(funcName);
            tmpItem = uimenu(mitem, 'Label', textLabel, 'Enable', 'on');
            tmpItem.Callback = @(s,e,f) obj.calculateProjection(funcName);
        end
        
        mitem = uimenu(m, 'Label', 'Filter Images');
        filterPackage = {'stack', 'process', 'filter2'};
        
        result = what(fullfile(filterPackage{:}));
        for i = 1:numel(result(1).m)
            funcName = strrep(result(1).m{i}, '.m', '');
            textLabel = utility.string.varname2label(funcName);
            tmpItem = uimenu(mitem, 'Label', textLabel, 'Enable', 'off');
            funcHandle = str2func(strjoin([filterPackage, {funcName}], '.'));
            tmpItem.Callback = @(s,e,f) obj.filterImages(funcHandle);
        end
        
        mitem = uimenu(m, 'Label', 'Downsample Stack');
        mitem.Callback = @(s, e) obj.createDownsampledStack();

        
        
        mitem = uimenu(m, 'Label', 'Align Images', 'Separator', 'on');            
            tmpItem = uimenu(mitem, 'Label', 'NoRMCorre', 'Enable', 'on');
            tmpItem.Callback = @(s,e) imviewer.plugin.NoRMCorre(obj);
    
            tmpItem = uimenu(mitem, 'Label', 'FlowReg', 'Enable', 'on');
            tmpItem.Callback = @(s,e) imviewer.plugin.FlowRegistration(obj);

% %         tmpItem = uimenu(m, 'Label', 'Align Images');
% %         
% %         tmpItemA = uimenu(tmpItem, 'Label', 'Rigid');
% %         tmpItemA.Callback = @(s, e) obj.alignImagesRigid;
% %         tmpItemB = uimenu(tmpItem, 'Label', 'Nonrigid');
% %         tmpItemB.Callback = @(s, e) obj.alignImagesNonRigid;

        mitem = uimenu(m, 'Label', 'Open Roimanager');   
        mitem.Callback = @(s, e, h) imviewer.plugin.RoiManager(obj);

        mitem = uimenu(m, 'Label', 'Link to Another Viewer...', 'Separator', 'on');
        mitem.Callback = @(s, e) obj.manualLinkProp;
        
        mitem = uimenu(m, 'Label', 'Load Images...');
        mitem.Callback = @(s, e, bool) obj.onLoadImageDataPressed(true);

        mitem = uimenu(m, 'Text', 'Save');
        mSubItem = uimenu(mitem, 'Text', 'Save Stack', 'Enable', 'off');
        mSubItem.Callback = @obj.saveStack; % Todo: make this one
        mSubItem = uimenu(mitem, 'Text', 'Save Image', 'Enable', 'on');
        mSubItem.Callback = @(s,e) obj.saveImage; % Todo: make this one
        mSubItem = uimenu(mitem, 'Text', 'Export Image As...', 'Enable', 'off');
        mSubItem.Callback = @obj.exportImage; % Todo: make this one
        
    end
    
    
% % Create widgets

    function createBrightnessSlider(obj)
        
        uicc = getappdata(obj.Figure, 'UIComponentCanvas');
        
        % Create brightness slider
        obj.brightnessSlider = uim.widget.rangeslider(uicc, ...
            'Location', 'northeast', 'Margin', [0,0,60,30], ...
            'Size', [120, 25], 'Visible', 'off', 'Padding', [10, 5, 10, 5]);

        obj.uiwidgets.BrightnessSlider = obj.brightnessSlider;
        
        obj.setSliderExtremeLimits()
        obj.setSliderLimits()

        % Do this after setting limits and low/high.
        obj.brightnessSlider.Callback = @obj.onSliderChanged;

        
        % Create toolbar
        hToolbar = uim.widget.toolbar(uicc, 'Location', 'northeast', ...
            'Margin', [0,0,10,30], 'ComponentAlignment', 'left', ...
            'BackgroundAlpha', 0, 'Size', [50, 25], 'NewButtonSize', [21,21],...
            'Spacing', 5, 'Padding', [5,2,5,2], 'Visible', 'off');
        hToolbar.Size = [50,25];
        hToolbar.Location = 'northeast';
        hToolbar.SizeMode = 'manual';
        % Add buttons
        hToolbar.addButton('Icon', obj.ICONS.auto, 'Type', 'togglebutton', 'Tag', 'auto', 'Tooltip', 'Auto', 'ButtonDownFcn', @obj.onAutoAdjustLimitsPressed)
        hToolbar.addButton('Icon', obj.ICONS.hist, 'Type', 'pushbutton', 'Tag', 'hist', 'Tooltip', 'Show Histogram', 'ButtonDownFcn', @(s,e) obj.openBrightnessHistogram)        
        obj.uiwidgets.BrightnessToolbar = hToolbar;

        obj.changeBrightness([obj.brightnessSlider.Low, obj.brightnessSlider.High])
        
        return

    end
    
    function openThumbnailSelector(obj, showMessage)
        
        % todo: update these as more frames are added (for virtual stacks)
        
        % todo: make code for getting images to uint8 more robust
        
        % todo: error handling in case the imviewer gui is closed while the
        % thumbnails are being created.
        
        % todo: move code to widget class
        
        if nargin < 2; showMessage = false; end
        
        if obj.imHeight==0 || obj.imWidth == 0; return; end
        if obj.nFrames == 1; return; end
        return
        
        % Only proceed if this widget is not initialized/present.
        if ~isfield(obj.uiwidgets, 'thumbnailSelector') || ...
                ~isvalid(obj.uiwidgets.thumbnailSelector.Figure) 
            %try
                
            obj.uiwidgets.thumbnailSelector = struct.empty;
            
            if showMessage
                obj.displayMessage('Creating thumbnails')
            end

            
            % Default projections
            labels = {'None', 'Average', 'Maximum'};
            numProjections = numel(labels);
            
            [images, callbacks] = deal(cell(numProjections,1));
            
            for i = 1:numProjections
                if i == 1
                    images{i} = obj.image;
                else
                    images{i} = obj.ImageStack.getFullProjection(labels{i});
                end
%                 images{i} = cast(images{i}, obj.ImageStack.dataType);
%                 images{i} = imadjustn(images{i});
                
                callbacks{i} = @(type, name) obj.changeImageDisplayMode('projection', labels{i});
                labels{i} = strrep(labels{i}, '_', ' ');
            end
            
            imdata = cat(3, images{:});
            imdata = stack.makeuint8(imdata);
            %imdata = im2uint8(imdata);

            avgProjection = images{2};
            
            
            widgetFunc = @imviewer.widget.ThumbnailSelector;
            %obj.uiwidgets.thumbnailSelector = widgetFunc( obj.Figure, imdata, labels, callbacks);
            obj.uiwidgets.thumbnailSelector = widgetFunc( obj.Panel, imdata, labels, callbacks);
            
            %! Do the same for moving avg...
            % Default projections
            projectionNames = {'None', 'Average', 'Maximum'};
            numProjections = numel(labels);
            
            [images, labels, callbacks] = deal(cell(numProjections,1));
            
            for i = 1:numProjections
                if i == 1
                    images{i} = obj.image;
                else
                    images{i} = obj.ImageStack.getProjection(projectionNames{i}, 1:obj.settings.ImageDisplay.movingBinSize);
                end
                
                %images{i} = imadjustn(images{i});

                callbacks{i} = @(type, name) obj.changeImageDisplayMode('binning', projectionNames{i});
                labels{i} = strrep(projectionNames{i}, '_', ' ');
            end
            
            imdata = cat(3, images{:});
            %imdata = stack.makeuint8(imdata);
            imdata = im2uint8(imdata);

            obj.uiwidgets.thumbnailSelector.addThumbnailGroup('Binning', imdata, labels, callbacks)
            
            defaultFilters = {'none', 'gauss2dtest', 'clahe'};
            [images, labels, callbacks] = deal(cell(numProjections,1));
            
            for i = 1:numProjections
                filterName = defaultFilters{i};
                if i == 1
                    images{i} = uint8(avgProjection);
                    
                else
                    images{i} = stack.process.filter2.(filterName)(avgProjection);
                end
                
                %images{i} = imadjustn(images{i});

                callbacks{i} = @(type, name) obj.changeImageDisplayMode('filter', filterName);
                filterName(1) = upper(filterName(1));
                labels{i} = filterName;
            end
            
            imdata = cat(3, images{:});
            %imdata = stack.makeuint8(imdata);
            imdata = im2uint8(imdata);

            obj.uiwidgets.thumbnailSelector.addThumbnailGroup('Filter', imdata, labels, callbacks)
            
            
            % Apply colormap
            obj.changeColormap()
            
            
            % Make changes to the axes of the thumbnail viewer
            tmpAx = obj.uiwidgets.thumbnailSelector.Axes;
            tmpAx.Visible = 'off';
            tmpAx.Units = 'pixel';
            tmpAx.Color = ones(1,3)*0.2;
            
            imAxPos = obj.uiaxes.imdisplay.Position;
            
            % Set size of thumbnail selector to be smaller than displayed
            % image....
            
            scale = imAxPos(4) / tmpAx.Position(4) * 0.8;
            tmpAx.Position(3:4) = tmpAx.Position(3:4) .* scale;
            
            % Position thumbnail viewer to the left in the imviewer
            % tmpAx.Position(1) = -tmpAx.Position(3);
            
            % Center vertically:
            tmpAx.Position(2) = imAxPos(2) + (imAxPos(4)-tmpAx.Position(4))/2;
            
            obj.uiwidgets.thumbnailSelector.createScrollBar()
            
            
            toolbarPosition = [tmpAx.Position(1)-5, tmpAx.Position(2)-32, ...
                           tmpAx.Position(3), 30 ];
                       
            obj.createThumbnailSelectorToolbar(toolbarPosition)
            
            if showMessage
                obj.clearMessage()
            end
            
%             catch
%                 try
%                     delete(obj.uiwidgets.thumbnailSelector)
%                 end
%                 obj.uiwidgets = rmfield(obj.uiwidgets, 'thumbnailSelector');
%                 obj.clearMessage()
%             end
            
        else
            switch obj.uiwidgets.thumbnailSelector.Visible
                case 'on'
                    obj.uiwidgets.thumbnailSelector.Visible = 'off';
                case 'off'
                    obj.uiwidgets.thumbnailSelector.Visible = 'on';
            end
        end
        

    end

    function createThumbnailSelectorToolbar(obj, toolbarPosition)

        %uicc = getappdata(obj.Figure, 'UIComponentCanvas');
        uicc = getappdata(obj.Panel, 'UIComponentCanvas');

        % Create toolbar for changing thumbnail selector mode
        % i.e projection, binning or filtering.
        
        toolbarConfig = {'Margin', [0,0,0,0], 'Padding', [3,3,3,3], ...
            'ComponentAlignment', 'left', 'BackgroundAlpha', 0.5, ...
            'Position', toolbarPosition, 'Spacing', 3};
        
        hToolbar = uim.widget.toolbar_(obj.Panel, toolbarConfig{:});
        %hToolbar = uim.widget.toolbar(uicc, 'Position', toolbarPosition, 'Margin', [0,0,0,0],'ComponentAlignment', 'center', 'BackgroundAlpha', 0.5);
        hToolbar.Position = toolbarPosition;
        hToolbar.BackgroundMode = 'wrap';      
        hToolbar.SizeMode = 'manual';

        hBtn(1) = hToolbar.addButton('Icon', obj.ICONS.pin3, 'Padding', [5,5,5,5], 'Mode', 'togglebutton', 'Tag', 'pinThumbnails', 'Tooltip', 'Pin Thumbnail', 'MechanicalAction', 'Switch when pressed', 'Callback', @obj.togglePinThumbnailSelector, 'IconAlignment', 'center');

        hBtn(2) = hToolbar.addButton('Icon', obj.ICONS.proj2, 'Mode', 'togglebutton', 'Tag', 'Projection', 'Tooltip', 'Projection (shift-p)');
        hBtn(3) = hToolbar.addButton('Icon', obj.ICONS.binning, 'Mode', 'togglebutton', 'Tag', 'Binning', 'Tooltip', 'Binning (shift-b)');
        hBtn(4) = hToolbar.addButton('Icon', obj.ICONS.filter2, 'Mode', 'togglebutton', 'Tag', 'Filter', 'Tooltip', 'Filter (shift-f)');

        obj.uiwidgets.thumbnailSelector.toggleButtons = hBtn;

        for i = 2:numel(hBtn)
            %hBtn(i).ButtonDownFcn = @(s,e,h) obj.uiwidgets.thumbnailSelector.changeThumbnailClass(hBtn(i).Tag);
            hBtn(i).Callback = @(s,e,h) obj.uiwidgets.thumbnailSelector.changeThumbnailClass(hBtn(i).Tag);
        end

        hToolbar.Visible = 'off';
        obj.uiwidgets.thumbNailToggler = hToolbar;



    end
    
    function addImageToolbar(obj)
    %ADDIMAGETOOLBAR Add toolbar with image tools to the image display
    
        % Calculate the position of the toolbar.
        toolbarHeight = 30;
        imAxPosition = obj.uiaxes.imdisplay.Position;
        
        initPosition(1) = imAxPosition(1);
        initPosition(2) = sum(imAxPosition([2,4])) - toolbarHeight - 5;
        initPosition(3) = imAxPosition(3);
        initPosition(4) = toolbarHeight;
        
        %uicc = getappdata(obj.Figure, 'UIComponentCanvas');
        
        % Create toolbar
        hToolbar = uim.widget.toolbar_(obj.Panel, 'Position', ...
            initPosition, 'Margin', [10,25,10,25], ...
            'ComponentAlignment', 'left', 'BackgroundAlpha', 0, ...
            'Spacing', 0, 'Padding', [0,0,0,0], 'NewButtonSize', 25);
        
        hToolbar.Location = 'northwest';
        buttonProps = {'CornerRadius', 0, 'Style', uim.style.buttonDarkMode};
        
        % Add buttons
        hToolbar.addButton('Icon', obj.ICONS.pin3, 'Padding', [5,5,5,5], 'Mode', 'togglebutton', 'Tag', 'pinToolbar', 'Tooltip', 'Pin Toolbar', 'MechanicalAction', 'Switch when pressed', 'Callback', @obj.toggleImageToolbarPin, 'IconAlignment', 'center', buttonProps{:})
        
        % Todo: Make this a toggle button.
        hToolbar.addButton(buttonProps{:}, ...
            'Type', 'togglebutton', ...
            'Icon', obj.ICONS.brightness,  ...
            'Padding', [4,4,4,4], ...
            'Callback', @(s,e) obj.showBrightnessSlider, ...
            'Tooltip', 'Set Brightness (c)');
        
        hToolbar.addButton('Icon', obj.ICONS.zoomIn, 'Mode', 'togglebutton', 'Tag', 'zoomIn', 'Tooltip', 'Zoom In (q)', 'MechanicalAction', 'Switch when pressed', buttonProps{:})
        hToolbar.addButton('Icon', obj.ICONS.zoomOut, 'Mode', 'togglebutton', 'Tag', 'zoomOut', 'Tooltip', 'Zoom Out (w)', buttonProps{:})
        hToolbar.addButton('Icon', obj.ICONS.hand4, 'Mode', 'togglebutton', 'Tag', 'pan', 'Tooltip', 'Pan (y)', buttonProps{:})

        % Get handle for pointerManager interface
        isMatch = contains({obj.plugins.pluginName}, 'pointerManager');
        pifHandle = obj.plugins(isMatch).pluginHandle;
            
        % Add listeners for toggling of modes from the pointertools to the
        % buttons. Also connect to buttonDown to toggling of the pointer
        % tools.
        pointerModes = {'zoomIn', 'zoomOut', 'pan'};
        
        for i = 1:numel(pointerModes)
            hBtn = hToolbar.getHandle(pointerModes{i});
            hBtn.Callback = @(s,e,h,str) togglePointerMode(pifHandle, pointerModes{i});
            hBtn.addToggleListener(pifHandle.pointers.(pointerModes{i}), 'ToggledPointerTool')
        end
        
        % Add toolbar to the widgets property.
        % Todo: rename to image toolbar
        obj.uiwidgets.Toolbar = hToolbar;
        obj.uiwidgets.Toolbar.Visible = 'off';

    end
    
    function addTaskbar(obj, showMessage)
        
        obj.uiwidgets.Taskbar = struct.empty;
        
        if nargin < 2; showMessage = false; end
        if showMessage
            obj.displayMessage('Initializing Task Bar')
        end
        
        
        uicc = getappdata(obj.Figure, 'UIComponentCanvas');
        
        % Create the taskbar
        hTaskbar = uim.widget.toolbar(uicc, 'Location', 'east', ...
            'Margin', [20,20,10,20],'ComponentAlignment', 'middle', ...
            'BackgroundAlpha', 0.5, 'IsFixedSize', [true, false], ...
            'Size', [64,64], 'NewButtonSize', 58, 'Padding', [3,10,3,10]);
       
        obj.uiwidgets.Taskbar = hTaskbar;
        obj.uiwidgets.Taskbar.Visible = 'off';
        
        
        % Add button for the RoiClassifier plugin.
        hBtn = hTaskbar.addButton('Type', 'pushbutton', ...
            'Tag', 'manualclassifier', 'Tooltip', 'Manual Classifier', ...
            'Icon', obj.ICONS.manualClassifier, 'UseDefaultIcon', false);
        hBtn.ButtonDownFcn = @(s, e, h) imviewer.plugin.RoiClassifier(obj);
        
        % Add button for the RoiManager plugin
        hBtn = hTaskbar.addButton('Type', 'pushbutton', ...
            'Tag', 'roimanager', 'Tooltip', 'Roi Manager', ...
            'Icon', obj.ICONS.roimanager);
        
        % Should clean this up somehow..
        hUicMenu = hBtn.getContextMenuHandle();
        hBtn.ButtonDownFcn = @(s, e, h, hMenu) imviewer.plugin.RoiManager(obj, hUicMenu);
        
        
        % What is this again???
        uicc.arrangeTooltipHandle()
        
        if showMessage
            obj.clearMessage()
        end
        
    end
    
    function addAppToolbar(obj)
    %ADDAPPTOOLBAR Add toolbar for app related buttons/tools
        
        uicc = getappdata(obj.Figure, 'UIComponentCanvas');
                
        pixelMargins = obj.positionInfo.Margin;
        newButtonSize = pixelMargins(2) - 9;
        
        % Create a toolbar for app-related buttons in upper right corner.
        hAppbar = uim.widget.toolbar(uicc, 'Location', 'northeast', ...
            'Margin', [0,0,0,0],'ComponentAlignment', 'right', ...
            'BackgroundColor', obj.Theme.HeaderBgColor, ...
            'BackgroundAlpha', 1, 'Size', [inf, pixelMargins(2)], ...
            'NewButtonSize', newButtonSize, 'Padding', [5,3,7,5], 'Spacing', 3);
        
        
        buttonArgs = {'Padding', [0,0,0,0], 'Style', uim.style.buttonSymbol}; %#ok<NASGU>
        
% %         hAppbar.addButton('Icon', obj.ICONS.bulb, ...
% %             'Padding', [0,0,1,0], 'Style', uim.style.buttonSymbol, ...
% %             'ButtonDownFcn', @obj.toggleHelp, 'Tooltip', 'Show Tips', ...
% %             'Type', 'togglebutton');
        
        hAppbar.addButton('Icon', obj.ICONS.import, ...
            'Padding', [0,0,1,0], 'Style', uim.style.buttonSymbol, ...
            'Type', 'pushbutton', 'Tooltip', 'Load Frames', ...
            'ButtonDownFcn', @(s,e,bool)obj.onLoadImageDataPressed(false) );
        
            
        hAppbar.addButton('Icon', obj.ICONS.plugins, ...
            'Padding', [0,0,1,0], 'Style', uim.style.buttonSymbol, ...
            'ButtonDownFcn', @(s,e,m) obj.displayMessage('Not implemented yet'), 'Tooltip', 'Show Plugin Menu', ...
            'Type', 'pushbutton');

        % Todo: Make this a toggle button.
        hAppbar.addButton('Icon', obj.ICONS.maximize, 'Type', 'pushbutton', ...
            'Padding', [0,0,0,0], 'Style', uim.style.buttonSymbol, ...
            'ButtonDownFcn', @obj.toggleResize, ... %maximizeWindow
            'Tooltip', 'Maximize Window');
        
        hAppbar.addButton('Icon', obj.ICONS.pin, 'Type', 'togglebutton', ...
            'Padding', [0,0,0,0], 'Style', uim.style.buttonSymbol, ...
            'ButtonDownFcn', @obj.pinWindow, 'Tooltip', 'Always on Top');

        hAppbar.addButton('Icon', obj.ICONS.preferences, ...
            'Padding', [0,0,0,0], 'Style', uim.style.buttonSymbol, ...
            'ButtonDownFcn', @obj.editSettings, 'Tooltip', 'Settings');

        hAppbar.addButton('Icon', obj.ICONS.question, 'FontWeight', 'bold', ...
            'FontSize', 15, 'Padding', [0,1,0,0], 'Tooltip', 'Help', ...
            'Style', uim.style.buttonSymbol, 'ButtonDownFcn', @obj.showHelp);
        
        
        obj.uiwidgets.Appbar = hAppbar;

    end
    
    function setImagePointerBehavior(obj)
        %NB: >Setting this on the figure object. Should be on the image
        %object, but due to the pointerManager' way of handling mouse
        %events, image ans axes' hittest is off, so this would have noe
        %effect
        pointerBehavior.enterFcn    = @obj.onMouseEnteredImage;
        pointerBehavior.exitFcn     = @obj.onMouseExitedImage;
        pointerBehavior.traverseFcn = [];%@obj.moving;

        iptPointerManager(obj.Figure);
        iptSetPointerBehavior(obj.Figure, pointerBehavior);
    end
    
end

methods % Set/Get
% % Get figure, axes and image object from imviewer object handle

    function set.ImageStack(obj, newValue)
        
        obj.ImageStack = newValue;
        obj.onImageStackSet()
    end

    function set.stackname(obj, newName)
        obj.stackname = newName;
        obj.setFigureName()
    end
    
    function hAxes = get.Axes(obj)
       hAxes = obj.uiaxes.imdisplay;
    end
    
    function set.Visible(obj, value)
        switch value
            case 'on'
                obj.Figure.Resize = 'off';
                pos = obj.Figure.Position;
                
                if ~isempty(obj.uiwidgets.playback)
                    obj.uiwidgets.playback.changeFramePos(obj.currentFrameNo, obj.nFrames)
                end
                updateInfoText(obj)
                updateImageDisplay(obj);
                
            case 'off'
                obj.Figure.Resize = 'on';
            otherwise
                error('Visible can be ''on'' or ''off'' ')
                
        end
        
        obj.Figure.Visible = value;
        
        % Why do I need to do this????
        if strcmp(value, 'on')
            drawnow
            obj.Figure.Position = pos;
        end
        
    end
    
    function value = get.Visible(obj)
        value = obj.Figure.Visible;
    end
    
    function set.ImageProcessingFcn(obj, newValue)
        
        assert(isempty(newValue) || isa(newValue, 'function_handle'), 'Value must be a function handle')
        obj.ImageProcessingFcn = newValue;
        
    end
    
    function set.showHeader(obj, newValue)
        
        assert(islogical(newValue), 'Value must be logical')
        obj.showHeader = newValue;
        obj.switchHeaderVisibility();
        
    end
    
    function set.showFooter(obj, newValue)
        
        assert(islogical(newValue), 'Value must be logical')
        obj.showFooter = newValue;
        obj.switchFooterVisibility();
        
    end
    
    function imAr = get.imageAspectRatio(obj)
        imAr = obj.imWidth / obj.imHeight;
    end
    
    function axAr = get.axesAspectRatio(obj)
        axesPosition = getpixelposition(obj.uiaxes.imdisplay);
        axAr = axesPosition(3) / axesPosition(4);
    end
    
    function set.DownsampleDisplayedImage(obj, newValue)
        obj.DownsampleDisplayedImage = newValue;
        obj.onDownsamplingToggled()
    end
    
    function set.ChannelColors(obj, newValue)
        
    end
    
    function channelColors = get.ChannelColors(obj)
                
        switch obj.ImageStack.ColorModel
            case 'RGB'
                channelColors = {'r', 'g', 'b'};
            case 'Custom'
                channelColors = obj.ImageStack.CustomColorModel;
                
                if ~isa(channelColors, 'cell')
                    numCh = size(channelColors, 1);
                    channelColors = mat2cell(channelColors, ones(1,numCh), 3);
                end
                
            otherwise
                channelColors = [];
                
        end
        
    end
        
    
end

methods % App update
        
    function reparent(obj, newParent, mode)
        
        if nargin < 3; mode = 'standalone'; end
        
        reparent@applify.ModularApp(obj, newParent, mode)
        
        switch obj.mode
            case 'docked'
                obj.ImageDragAndDropEnabled = false;
        end
        
        obj.Panel.Parent = newParent;
        obj.Panel.Units = 'normalized';
        obj.Panel.Position = [0,0,1,1];
         
        hFig = ancestor(obj.Panel.Parent, 'figure');
        setDefaultFigureCallbacks(obj, hFig)
        
        obj.Axes.UIContextMenu.Parent = hFig;
        
        
        % TEMP SHIT!
        % Get handle for pointerManager interface
        isMatch = contains({obj.plugins.pluginName}, 'pointerManager');
        pifHandle = obj.plugins(isMatch).pluginHandle;
        delete(pifHandle)
        
        obj.Figure.CloseRequestFcn = [];
        delete(obj.Figure)
        
        obj.Figure = hFig;
        
        obj.uiaxes.imdisplay.UIContextMenu = uicontextmenu(obj.Figure);
        obj.createImageMenu(obj.uiaxes.imdisplay.UIContextMenu);

        
        obj.uiaxes.imdisplay.ButtonDownFcn = [];
        pifHandle = uim.interface.pointerManager(obj.Figure, obj.uiaxes.imdisplay, {'zoomIn', 'zoomOut', 'pan'});
        pifHandle.pointers.pan.buttonMotionCallback = @obj.moveImage;
        obj.plugins(isMatch).pluginHandle = pifHandle;
        % Add listeners for toggling of modes from the pointertools to the
        % buttons. Also connect to buttonDown to toggling of the pointer
        % tools.
        
        hToolbar = obj.uiwidgets.Toolbar;
        pointerModes = {'zoomIn', 'zoomOut', 'pan'};
        
        for i = 1:numel(pointerModes)
            hBtn = hToolbar.getHandle(pointerModes{i});
            hBtn.Callback = @(s,e,h,str) togglePointerMode(pifHandle, pointerModes{i});
            hBtn.addToggleListener(pifHandle.pointers.(pointerModes{i}), 'ToggledPointerTool')
        end
        
        % From updateImageDisplay
        obj.setImagePointerBehavior
        
        delete(obj.uiwidgets.playback)
        createPlaybackWidget(obj)
    end
    
% % Update display

    function updateInfoText(obj)
        
        % Todo: use struct2cell and use strjoin on nonempty cells
        
        if isempty(obj.textStrings.Status)
            infoStr = sprintf(  '%s | %s | %s', ...
                                obj.textStrings.CurrentFrame, ...
                                obj.textStrings.Resolution, ...
                                obj.textStrings.CursorPoint);
        else
            infoStr = sprintf(  '%s | %s | %s | %s', ...
                                obj.textStrings.CurrentFrame, ...
                                obj.textStrings.Resolution, ...
                                obj.textStrings.Status, ...
                                obj.textStrings.CursorPoint);
        end
        
        obj.infoField.String = infoStr;
    end
    
    function updateImage(obj)
    %UPDATEIMAGE get updated image for display    
    %
    %   this functions prepares a new image for the display when the image
    %   should be updated. This could either be because of changing frames
    %   or changing the displayMode
    
    % Rename? : UpdateDisplayedImageFrame
    
        %TODO: Implement rgb colors and multiple channels.
        
        
        if isa(obj.ImageStack, 'nansen.stack.HighResolutionImage')
            obj.updateImageSpatialDownsample()
            return
        end
        
        showProjection = ~strcmpi(obj.imageDisplayMode.projection, 'none');
        showBinning = ~strcmpi(obj.imageDisplayMode.binning, 'none');

        if showProjection
            global fprintf %#ok<TLEV>
            fprintf = @(msg)obj.uiwidgets.msgBox.displayMessage(msg);
            C = onCleanup(@obj.resetFprintfToBuiltin);
            
            projectionName = obj.imageDisplayMode.projection;
            obj.image = obj.ImageStack.getFullProjection(projectionName);
            
        elseif showBinning
            frameNo = obj.currentFrameNo;
            binningSize = obj.settings.ImageDisplay.movingBinSize;
            frameInd = obj.ImageStack.getMovingWindowFrameIndices(frameNo, binningSize);
            
            binningName = obj.imageDisplayMode.binning;
            obj.image = obj.ImageStack.getProjection(binningName, frameInd);

        else
            frameNo = obj.currentFrameNo;
            
            % Todo: use getFrame function from imageStack?
            obj.image = obj.ImageStack.getFrameSet(frameNo);
            
            
% %             if ndims(obj.ImageStack.imageData) == 4
% %                 obj.image = obj.ImageStack.imageData(:, :, :, frameNo);
% %             elseif obj.isRgb && size(obj.ImageStack.imageData, 3) == 3          % Todo: Generalize and make this more robust...
% %                 obj.image = obj.ImageStack.imageData(:, :, :);
% %             else
% %                 obj.image = obj.ImageStack.imageData(:, :, frameNo);
% %             end

        end
        
        % Todo: Apply filter.
        if ~strcmpi(obj.imageDisplayMode.filter, 'none')
            filterName = obj.imageDisplayMode.filter;
            filterFcn = obj.getFilterFcn(filterName);
            if ~isempty(obj.imageDisplayMode.filterParam)
                param = obj.imageDisplayMode.filterParam;
                obj.image = filterFcn(obj.image, param);
            else
                obj.image = filterFcn(obj.image);
            end
        end
        
        
        if ~isempty(obj.ImageProcessingFcn)
            obj.image = obj.ImageProcessingFcn(obj.image);
        end
            
        obj.CurrentImage = obj.image;
        obj.DisplayedImage = obj.image;
        
        % Todo: merge multiple channels if channel displaymode is multi....
        %obj.setChColors(obj.image)
        
    end
    
    function updateImageSpatialDownsample(obj)
        
        if isempty(obj.CurrentImage)
            obj.CurrentImage = obj.ImageStack.getFullImage();
        end
        
        xLim = round(obj.uiaxes.imdisplay.XLim) - [0,1];
        yLim = round(obj.uiaxes.imdisplay.YLim) - [0,1];

        obj.ImageStack.DataXLim = xLim;
        obj.ImageStack.DataYLim = yLim;

        n = range(yLim) / obj.Axes.Position(4);

        im = obj.ImageStack.getFrameSet(obj.currentFrameNo, n);

        obj.DisplayedImage = im;
        
    end
    
    function hFcn = getFilterFcn(~, filterName)
        % todo not an imviewer not a class method
        switch filterName
            case 'gauss3d'
                hFcn = str2func('stack.process.filter3.gauss3d');
            otherwise
                hFcn = str2func(sprintf('stack.process.filter2.%s', filterName));
        end
    end
    
    
    function imageOut = setChColors(obj, image)
    % Creates an rgb frame based on channel color settings

        % Preallocate new frame
        imSize = size(image);
        imageOut = zeros(imSize(1), imSize(2), 3, 'single');

        if strcmp(obj.ImageStack.ColorModel, 'RGB')
            %channelColors = {'red', 'green', 'blue'};
            channelColors = {[1,0,0], [0,1,0], [0,0,1]};
        
        elseif strcmp(obj.ImageStack.ColorModel, 'Custom')
            channelColors = obj.ImageStack.CustomColorModel;
            if ~isa(channelColors, 'cell')
                numCh = size(channelColors, 1);
                channelColors = mat2cell(channelColors, ones(1,numCh), 3);
            end
        end
        
        colorArray = cat(1, channelColors{:});
        
        % Restrict colors to range between 0 and 1
        if any(colorArray > 1) % If rgb in range (1,255)
            colorArray = colorArray / 255;
        end
        
% % %         colorArraySum = sum(colorArray, 1);
% % %                
% % %         % Weight colors, so as not to saturate them...
% % %         if any(colorArraySum(:) > 1)
% % %             colorArray = colorArray ./ max(colorArraySum(:));
% % %         end
         
        numCh = size(colorArray, 1);
        channelColors = mat2cell(colorArray, ones(1,numCh), 3);
        
        % Go through image for each loaded channel and put in right
        % color channel of newFrame
        for i = 1:numel(obj.ImageStack.CurrentChannel)
            
            chNum = obj.ImageStack.CurrentChannel(i);
            color = channelColors{chNum};
            
            imageOut = imageOut + single( repmat(image(:, :, i), 1, 1, 3)) .* reshape(color, 1, 1, 3);
            
        end
        
        imageOut = cast(imageOut, 'like', image);

    end
        
    function im = adjustMultichannelImage(obj, im)
        switch obj.ImageStack.DataType
            case 'uint8'
                lowhigh_in = obj.settings.ImageDisplay.imageBrightnessLimits /2^8;
            case 'uint16'
                lowhigh_in = obj.settings.ImageDisplay.imageBrightnessLimits /2^16;
            case 'int16'
                lowhigh_in = (obj.settings.ImageDisplay.imageBrightnessLimits+2^15) /2^16;
            case {'single', 'double'}
                cLim = obj.settings.ImageDisplay.imageBrightnessLimits;
                lowhigh_in = (cLim - min(cLim)) ./ range(obj.settings.ImageDisplay.brightnessSliderLimits);
        end

        %im = imadjust(im, lowhigh_in);
        im = imadjustn(im, lowhigh_in);
    end
    
    function updateImageDisplay(obj)
        
        % Get current image...
        im = obj.DisplayedImage;

        % Rotate image
        if obj.imTheta ~= 0
            im = imrotate(im, obj.imTheta, 'bicubic', 'crop');
        end
        
        % Adjust the image color and brightness if image is truecolor
        if (size(im, 3) > 1 || obj.ImageStack.NumChannels > 1) && strcmp(obj.ImageStack.ColorModel, 'Grayscale')
            im = mean(im, 3);
        elseif size(im, 3) > 1 && obj.ImageStack.NumChannels > 1
            im = obj.setChColors(im);
            im = adjustMultichannelImage(obj, im);
        end
        
         
        % Create or update the image object
        if isempty(obj.imObj) 
            hold(obj.uiaxes.imdisplay, 'on')

            obj.uiaxes.imdisplay.YDir = 'reverse';
            
            if obj.ImageStack.NumChannels > 1
                obj.imObj = image(obj.uiaxes.imdisplay, 'CData', im);
            else
                obj.imObj = image(obj.uiaxes.imdisplay, 'CData', im, 'CDataMapping', 'scaled');
                obj.uiaxes.imdisplay.CLim = obj.settings.ImageDisplay.imageBrightnessLimits;
            end
            
            obj.imObj.HitTest = 'off';
            obj.imObj.PickableParts = 'none';
            obj.imObj.XData = [1, obj.imWidth];
            obj.imObj.YData = [1, obj.imHeight];
            obj.setImagePointerBehavior()

            % Update image display x- & y-limits to keep axes tight..
            obj.uiaxes.imdisplay.XLim = [0, obj.imWidth] + 0.5;
            obj.uiaxes.imdisplay.YLim = [0, obj.imHeight] + 0.5;
            
        else
            % if reso is very high, replace subpart of image and set image
            % limits...
            
            obj.imObj.CData = im;
        end
        
        if isa(obj.ImageStack, 'nansen.stack.HighResolutionImage')
            xLim = round(obj.uiaxes.imdisplay.XLim) - [0,1];
            yLim = round(obj.uiaxes.imdisplay.YLim) - [0,1];
            
            obj.imObj.XData = xLim;
            obj.imObj.YData = yLim;
        end
        
        
        % Set transparency if image contains nans
        if all(isnan(obj.imObj.CData(:)))
            obj.imObj.AlphaData = 0;
        else
            obj.imObj.AlphaData = 1;
        end
        
        
        % Update brightness range if autoadjust is on
        if obj.autoAdjustLimits
            if all(isnan(obj.image(:))); return; end
            P = prctile(double(obj.image(:)), [0.05, 99.95]);
            obj.brightnessSlider.Low = P(1);
            obj.brightnessSlider.High = P(2);
        end
        
        
        % Update viewer
        if strcmp(obj.Figure.Visible, 'on')
            drawnow limitrate
        end
        
    end
    
    function refreshImageDisplay(obj)
        obj.updateImage()
        if strcmp(obj.Visible, 'on')
            updateInfoText(obj)
            updateImageDisplay(obj);
        end
    end
    
    function resetImageDisplay(obj)
        delete(obj.imObj)
        obj.imObj = [];
        obj.currentFrameNo = 1;
    end
    
    function activateGlobalMessageDisplay(obj, mode)
        
        if nargin < 2
            mode = 'update';
        end
        
        global fprintf
        
        switch mode
            case 'display'
                fprintf = @(msg)obj.uiwidgets.msgBox.displayMessage(msg);
            case 'update'
                fprintf = @(varargin)obj.uiwidgets.msgBox.displayMessage(varargin{:});
        end
        
    end
    
    function updateMessage(obj, message, varargin)
        
        if ~isempty(varargin)
            message = sprintf(message, varargin{:});
        end
        if isempty(message) || isequal(message, newline)
            obj.uiwidgets.msgBox.clearMessage()
        else
            obj.uiwidgets.msgBox.displayMessage(message)
        end

    end
    
    function displayMessage(obj, message, target, msgDuration)
        
        if nargin < 3 || isempty(target); target = 'messageBox'; end
        if nargin < 4; msgDuration = []; end
        
        if isempty(obj.uiwidgets) || ~isfield(obj.uiwidgets, 'msgBox')
            target = 'statusLine';
        end
        
        switch target
            case 'messageBox'
                obj.uiwidgets.msgBox.displayMessage(message, msgDuration)
            case 'statusLine'
                obj.textStrings.Status = message;
                updateInfoText(obj)
        end
        
    end
    
    function clearMessage(obj)
        if isvalid(obj)
            obj.uiwidgets.msgBox.clearMessage()
            obj.textStrings.Status = '';
            updateInfoText(obj)
        end
        
    end
    
    function hPlugin = openPlugin(obj, pluginName, pluginOptions)
        
        if nargin < 3 || isempty(pluginOptions)
            pluginOptions = struct.empty;
        end
        
        pluginFcnName = strjoin({'imviewer', 'plugin', pluginName}, '.');
        pluginFcn = str2func(pluginFcnName);
        
        hPlugin = pluginFcn(obj, pluginOptions);

        if ~nargout
            clear(hPlugin)
        end
    end
    
end

methods % Event/widget callbacks
   % % Callback from widget interaction
    
    % Methods for updating brightness slider

    function setSliderExtremeLimits(obj, newLimits)
        
        if nargin < 2
            newLimits = obj.ImageStack.DataTypeIntensityLimits;
            obj.settings_.ImageDisplay.brightnessSliderLimits = newLimits;
        end
        
        assert(newLimits(1) < newLimits(2), 'L(1) must be smaller than L(2)')
        
        obj.brightnessSlider.Min = newLimits(1);
        obj.brightnessSlider.Max = newLimits(2);
        
        if newLimits(2) <= 1
            obj.brightnessSlider.NumTicks = max( [100, diff(newLimits)] );
        else
            obj.brightnessSlider.NumTicks = max( [255, diff(newLimits)] );
        end
    end
   
    function setSliderLimits(obj, newLimits)
        
        % Todo: Should get slider limits from imagestack method, which is
        % based on the datatype of the image data..
        
        if nargin < 2
            %newLimits = obj.settings.ImageDisplay.imageBrightnessLimits;
            newLimits = obj.ImageStack.DataIntensityLimits;
            if isempty(obj.ImageStack.DataIntensityLimits)
                newLimits = obj.ImageStack.DataTypeIntensityLimits;
            end
            obj.settings_.ImageDisplay.imageBrightnessLimits = newLimits;
        else
            %Use internal property to avoid triggering on settings changed callback
            obj.settings_.ImageDisplay.imageBrightnessLimits = newLimits;
        end
        
        % Todo: Do i need to round?
        newLimits = double(newLimits);
        
        % The high value must be set first in some cases:
        if newLimits(1) > obj.brightnessSlider.High
            obj.brightnessSlider.High = min([newLimits(2), obj.brightnessSlider.Max]);
            obj.brightnessSlider.Low = max([newLimits(1), obj.brightnessSlider.Min]);
        else
            obj.brightnessSlider.Low = max([newLimits(1), obj.brightnessSlider.Min]);
            obj.brightnessSlider.High = min([newLimits(2), obj.brightnessSlider.Max]);
        end
        
        
%         % If a "blank" stack is opened, need to readjust limits.
%         if all(obj.settings.ImageDisplay.imageBrightnessLimits == 0)
%             obj.settings.ImageDisplay.imageBrightnessLimits = [0,1];
%         end
%         
%         if obj.settings.ImageDisplay.imageBrightnessLimits(1) == 1
%             obj.settings.ImageDisplay.imageBrightnessLimits(1) = 0;
%         end
        
        
        
    end
    
    
    function goToFrame(obj, frameNumber) % todo: remove but fix roisignal video which use this
        src = struct('String', num2str(frameNumber));
        obj.changeFrame(src, [], 'jumptoframe')
    end
    
    
    % Methods for changing the current frame selection. Todo: make internal (protected)...
    
    function changeFrame(obj, source, event, action)
        % Callback from different sources to change the current frame.
        % Internal..
        
        persistent counter
        if isempty(counter); counter = 1; end
        
        % Todo: This should be a protected method. Therefore, if this
        % method is called, the changeFrame request is internal, and should
        % also update the frame of linked apps. Make a superclass for
        % linked apps (imviewer and signalviewer)
        
        switch action
            case 'mousescroll'
                i = event.VerticalScrollCount;
                if obj.nFrames / obj.settings.Interaction.scrollFactor < 100% obj.settings.Interaction.scrollFactor
                    scrollFactor = 1;
                else
                    scrollFactor = obj.settings.Interaction.scrollFactor;
                end
                
                i = i * scrollFactor;
            case {'slider', 'buttonclick'}
                newValue = source.Value;
                i = newValue -  obj.currentFrameNo;
                i = round(i);
            case 'keypress'
                i = source.Value;
            case {'jumptoframe'}                
                newFrame = source.String;
                if isa(newFrame, 'char'); newFrame = str2double(newFrame); end
                i = newFrame -  obj.currentFrameNo;
                i = round(i);
            case 'playvideo'
                i = source.Value;
            case 'next'
                i = 1;
            case 'prev'
                i = -1;
            otherwise
                i = 0;   
        end

        
        if ~strcmpi(obj.imageDisplayMode.projection, 'none')
            obj.imageDisplayMode.projection = 'none';
        end
        

        % Check that new value is within range and update current frame/slider info
        if (obj.currentFrameNo + i) >= 1  && (obj.currentFrameNo + i) <= obj.nFrames
            obj.currentFrameNo = round(obj.currentFrameNo + i);
        else
            return
        end

        counter = counter + 1; % todo: remove this...
        
        updateLinkedApps = true;

        % Cant update the currentFrame of other viewers too frequently,
        % because updating gets very sluggish. Super weird. How to improve?
        if strcmp(action, 'mousescroll') || obj.isPlaying
            if ~(mod(counter, 1)==0)
                updateLinkedApps = false;
            end
        end
            
        % Update linked apps!
        if updateLinkedApps && ~isempty(obj.LinkedApps)
            for i = 1:numel(obj.LinkedApps)
                % Todo: Make sure the property is available....
                obj.LinkedApps(i).currentFrameNo = obj.currentFrameNo;
            end
        end
        
        
    end %rename to sample/time
    
    function set.currentFrameNo(obj, newValue)

        obj.currentFrameNo = newValue;
        obj.onFrameChanged()

    end
    
    function onFrameChanged(obj)
        
        obj.textStrings.CurrentFrame = sprintf('%d/%d', obj.currentFrameNo, obj.nFrames);

        if ~strcmpi(obj.imageDisplayMode.projection, 'none')
            obj.imageDisplayMode.projection = 'none';
        end
        
        
        if ~isempty(obj.imObj)% && i~=0
            
            obj.updateImage()

            if strcmp(obj.Visible, 'on')
                
                updateInfoText(obj)
                updateImageDisplay(obj);

            end
        end

    end
    
    function onNumFramesChanged(obj)
        obj.uiwidgets.playback.Maximum = obj.nFrames;
    end
    
    function changeChannel(obj, channelNum, mode)
        
        if nargin < 3 || isempty(mode)
            mode = 'select';
        end
        
        numChannels = obj.ImageStack.NumChannels;
        
        % If channelnum is 'all', convert to numbers
        if ischar(channelNum) && strcmp(channelNum, 'all')
            channelNum = 1:obj.ImageStack.NumChannels;
        end
        
        % Dont select channel which is not present
        if any(channelNum > numChannels)
            msg = sprintf('Channels are not available: %s', num2str(channelNum(channelNum > numChannels)));
            obj.displayMessage(msg, [], 2)
            channelNum(channelNum > numChannels) = [];
            if isempty(channelNum)
                return
            end
        end
        
        if isempty(channelNum)
            obj.currentChannel = obj.currentChannel;
            obj.displayMessage('At least one channel must be displayed', [], 2)
            return
        end
        
        % Set new selection
        switch mode
            case 'toggle'
                if ismember(channelNum, obj.currentChannel)
                    obj.currentChannel = setdiff(obj.currentChannel, channelNum);
                else
                    obj.currentChannel = union(obj.currentChannel, channelNum);
                end
            case 'select'
                obj.currentChannel = channelNum;
        end
        
    end
    
    function set.currentChannel(obj, newValue)
        obj.currentChannel = newValue;
        obj.onChannelChanged()
    end
    
    function onChannelChanged(obj)
        if ~obj.isConstructed; return; end
        
        obj.uiwidgets.playback.CurrentChannels = obj.currentChannel;

        obj.ImageStack.CurrentChannel = obj.currentChannel;
            
        if ~isempty(obj.imObj)
            obj.updateImage()
            obj.updateImageDisplay()
        end
        
    end
    
    function changePlane(obj, planeNum, mode) %#ok<INUSD>
    end
    
    function set.currentPlane(obj, newValue)
        obj.currentPlane = newValue;
        obj.onPlaneChanged()
    end
    
    function onPlaneChanged(obj) %#ok<MANU>
    end
    
    function set.nFrames(obj, newValue)
        obj.nFrames = newValue;
        obj.onNumFramesChanged()
    end
        
    
    
    function onDisplayLimitsChanged(obj)
        
        % This is used as an explicit callback instead of have a listener
        % and callback on properties XLim and YLim on axes object. That
        % does not work well because the callback is triggered once for
        % xlim and once for ylims.
        
        if isa(obj.ImageStack, 'nansen.stack.HighResolutionImage')
            obj.updateImage()
            obj.updateImageDisplay()
        end
        
    end
    
    
   % Methods for interactive update of displayed image based on display mode...
   
    function changeImageDisplayMode(obj, type, name, persisting)
        
        if nargin < 4; persisting = true; end
        currentDisplayMode = obj.imageDisplayMode;
        
        switch type
            case 'projection'
                obj.imageDisplayMode.projection = name;
                obj.imageDisplayMode.binning = 'none';
                obj.textStrings.CurrentFrame = strrep(name, '_', ' ');
                updateInfoText(obj)
            case 'binning'
                obj.imageDisplayMode.binning = name;
                obj.imageDisplayMode.projection = 'none';
            case 'filter'
                obj.imageDisplayMode.filter = name;
                obj.imageDisplayMode.filterParam = [];
        end
        
        
        % If shift click, should open parameters for function.
        if strcmp(obj.Figure.SelectionType, 'extend') && strcmp(type, 'filter')
            
            if ~strcmp(obj.imageDisplayMode.filter, 'none')
                obj.Figure.SelectionType = 'normal'; % Reset selection type...
                obj.previewImage(name);
                return
            end
            
        end
        
        obj.updateImage()
        obj.updateImageDisplay()
        
        if ~persisting
            obj.imageDisplayMode = currentDisplayMode;
        end
        
        % Todo: update textdisplay.
                
    end

    function previewImage(obj, filterName)
        %Todo: rename and work more on this
        filterFunc = str2func(strcat('stack.process.filter2.',filterName));
        param = filterFunc();
        
        titleStr = sprintf('Set Parameters for %s', filterName);
        param = tools.editStruct(param, '', titleStr, 'TestFunc', @(param) obj.updatePreview(param));
        
        obj.imageDisplayMode.filter = filterName;
        obj.imageDisplayMode.filterParam = param;
    end
    
    function updatePreview(obj, param)
        %Todo: rename and work more on this

        obj.imageDisplayMode.filterParam = param;
        obj.updateImage();        
        obj.updateImageDisplay();
        
    end
    
    function changeBrightness(obj, newCLim)
        % Callback function for value change of brightness slider
%         min_brightness = slider.Low;
%         max_brightness = slider.High;

%         switch obj.channelDisplayMode
%             case {'single', 'correlation'}
%                 set(obj.uiaxes.imagedisplay, 'CLim', [min_brightness, max_brightness])
%             case 'multi'
%                 obj.updateImageDisplay();
%         end
        
%         if obj.settings.ImageDisplay.imageBrightnessLimits(2) <= 1
%             newCLim = newCLim/100;
%         end
        
        
        
        % Prevent setting upper limit lower than lower limit.
        if newCLim(2) <= newCLim(1)
            if obj.settings.ImageDisplay.imageBrightnessLimits(2) <= 1
                newCLim(2) = newCLim(1)+0.01;
            else
                newCLim(2) = newCLim(1)+1;
            end
        end
        
        % Update settings, but use protected property, dont need to trigger
        % settings changed, because update is invoked below.
        obj.settings_.ImageDisplay.imageBrightnessLimits = newCLim;

        if obj.ImageStack.NumChannels > 1
            if ~isempty(obj.imObj)
                imdata = obj.DisplayedImage;
                imdata = obj.setChColors(imdata);
                obj.imObj.CData = obj.adjustMultichannelImage(imdata);
            end
        else
            obj.uiaxes.imdisplay.CLim = newCLim;
        end
        
        if ~isempty( obj.hSettingsEditor )
             obj.hSettingsEditor.replaceEditedStruct(obj.settings)
        end
        
        %drawnow;
    end
     
    function changeColormap(obj, src, ~)
    %changeColormap Change the colormap of the image display
    
        if nargin >= 2 && isa(src, 'matlab.ui.container.Menu')
            obj.settings.ImageDisplay.colorMap = src.Label;
            % This will trigger onSettingsChanged which will trigger this
            % function again. Return now to prevent getting caught in 
            % an infinite loop.
            return
        end
        
        numColors = 256; 

        selectedColorMap = obj.settings.ImageDisplay.colorMap;
        
        % Get right colormap based on the colormap selection
        switch selectedColorMap
            
            % Matlab default colormaps
            case {'Gray', 'Summer', 'Copper', 'Bone', 'Pink'}
                cmapFunc = str2func( lower(selectedColorMap) );
                cmap = cmapFunc(numColors);
            
            % Matplotlib colormaps    
            case {'Viridis', 'Inferno', 'Magma', 'Plasma'}
                cmapFunc = str2func( lower(selectedColorMap) );
                cmap = cmapFunc(numColors);

            case 'Nissl'
                cmap = fliplr(cbrewer('seq', 'BuPu', numColors, 'spline'));

            case 'PuBuGn'
                cmap = flipud(cbrewer('seq', selectedColorMap, numColors, 'spline'));
            case {'GnBu', 'Greens', 'YlOrRd', 'BuPu'}
                cmap = cbrewer('seq', selectedColorMap, numColors, 'spline');
            case 'PuOr' 
                cmap = flipud(cbrewer('div', selectedColorMap, numColors, 'spline'));
                
            % cmocean colormaps
            case {'thermal', 'haline', 'solar', 'ice', 'gray', 'oxy', 'deep', 'dense', ...
            'algae','matter','turbid','speed', 'amp','tempo'}
                cmap = cmocean(selectedColorMap);
                
            otherwise
                error('Invalid colormap name, "%s"', selectedColorMap)
        end
        
        % Make sure colors are within range (0,1). Cmap interpolation can
        % create outliers.
        cmap(cmap<0) = 0; cmap(cmap>1) = 1;

%             cmap(1, :) = [0.7,0.7,0.7];%obj.Figure.Color;

        colormap(obj.uiaxes.imdisplay, cmap)
        
        
        if obj.ImageStack.NumChannels > 1
            msg = 'Color maps does not have any effect on multi channel images';
            obj.displayMessage(msg, [], 2)
        end
        
        
        if isfield(obj.uiwidgets, 'thumbnailSelector')
            colormap(obj.uiwidgets.thumbnailSelector.Axes, cmap)
        end
        
        if ~isempty( obj.hSettingsEditor )
             obj.hSettingsEditor.replaceEditedStruct(obj.settings)
        end
                
    end

end

methods % Handle user actions
    function calculateProjection(obj, funcName)
        global fprintf
        fprintf = @(msg)obj.uiwidgets.msgBox.displayMessage(msg);
        C = onCleanup(@obj.resetFprintfToBuiltin);
        
        % todo: Should messagebox.displayMessage accept varargin that will
        % be formatted as in fprintf or sprintf?
        
        im = obj.ImageStack.getFullProjection(funcName);
        obj.DisplayedImage = im;
        
        obj.updateImageDisplay()
        
        callbackFcn = @(type, name) obj.changeImageDisplayMode('projection', funcName);
        args = {'Projection', stack.makeuint8(im), funcName, callbackFcn};
        %args = {'Projection', im2uint8(im), funcName, callbackFcn};

        if isfield(obj.uiwidgets, 'thumbnailSelector')
            obj.uiwidgets.thumbnailSelector.addThumbnailToGroup(args{:})
        end
        
    end
    
    function createDownsampledStack(obj)
        
        % Todo: Get this from the imviewer method.
        params = struct();
        
        % parameters for imviewer
        params.OpenOutputInNewWindow = true;
        
        % parameters for the image stack method
        params.DownSamplingFactor = 10;
        params.BinningMethod = 'mean';
        params.BinningMethod_ = {'mean', 'max'};
        
        params.CreateVirtualOutput = false;
        params.UseTransientVirtualStack = true;
        params.FilePath = '';
        params.OutputDataType = 'same';
        
        params = tools.editStruct(params);
        
        if ~params.OpenOutputInNewWindow        
            obj.displayMessage('Not implemented yet')
            return
        end
        
        obj.displayMessage('Downsampling stack...', [], 1.5)


        
        n = params.DownSamplingFactor;
        binMethod = params.BinningMethod;
        imageStackDs = obj.ImageStack.downsampleT(n, binMethod, params);
        
        if params.OpenOutputInNewWindow
            imviewer(imageStackDs)
        else
            obj.displayMessage('Not implemented yet', [], 1.5)
        end
        
        obj.clearMessage()
        
    end
    
    function addImage(obj, newImage)
        
        if all(isnan(obj.image(:))) % No image present...

            delete(obj.ImageStack)
            obj.resetImageDisplay()

            obj.ImageStack = nansen.stack.ImageStack(newImage, 'isVirtual', false);
            
            
            [figurePosition, ~] = initializeFigurePosition(obj);
            deltaPos = figurePosition(3:4) - obj.Figure.Position(3:4);
            obj.resizeWindow([], [], 'manual', deltaPos)
            
            %obj.setSliderLimits( obj.ImageStack.DataIntensityLimits ) % Todo
            
        else
            obj.ImageStack.insertImage(newImage, obj.currentFrameNo)
            obj.setTempProperties()
            obj.updateImage()
            obj.updateImageDisplay()
            obj.updateInfoText()
        end
        
       

    end
    
    function resetFprintfToBuiltin(obj)
        %global fprintf
        obj.uiwidgets.msgBox.clearMessage()
        %fprintf = str2func('fprintf');
    end
    
    function createDraggableThumbnail(obj)
    %createDraggableThumbnail Create a draggable thumbnail of the current image
    %
    %   Create a small draggable thumbnail image on the current mouse
    %   point. The image will follow the mousepointer as long as a drag
    %   operation is ongoing. The image will be deleted on mouse release.
    %
    %   If the thumbnail is released over another imviewer instance, the
    %   current image will be copied to that instance. See mousePressed and
    %   mouseRelease
    
        mp = get(0, 'PointerLocation');
        obj.hThumbnail = imviewer.widget.DraggableThumbnail(obj.Figure, obj.imObj.CData, mp, obj.settings.ImageDisplay.colorMap);

        el1 = listener(obj.Figure, 'WindowMouseMotion', @(s,e)obj.hThumbnail.moveWindow);
        el2 = listener(obj.Figure, 'WindowMouseRelease', @(s,e)obj.hThumbnail.stopMoveWindow);

        setappdata( obj.hThumbnail.hFigure, 'el1', el1)
        setappdata( obj.hThumbnail.hFigure, 'el2', el2)
    
    end
    
    function pinWindow(obj, src, ~)
        
        warning('off', 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
        warning('off', 'MATLAB:ui:javaframe:PropertyToBeRemoved')
        
        jFrame = get(obj.Figure, 'JavaFrame'); %#ok<JAVFM>
        jClient = jFrame.fHG2Client;
        jWindow = jClient.getWindow;
        
        newState = src.Value;
        
        jWindow.setAlwaysOnTop(newState)
        
        warning('on', 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
        warning('on', 'MATLAB:ui:javaframe:PropertyToBeRemoved')
        
    end
    
end

methods % Misc, most can be outsourced

    
    function playVideoFrames(obj, ~, ~)
        % Callback for play button. Plays calcium images as video
        
        obj.isPlaying = true;
        
        while obj.isPlaying

            if obj.currentFrameNo >= obj.nFrames - (obj.playbackspeed+1)
                obj.currentFrameNo = 0;
            end

            t1 = tic;
            
            if obj.playbackspeed >= 1
                src.Value = obj.playbackspeed;
            else
                src.Value = 1;
            end
            
            obj.changeFrame(src, [], 'playvideo');
            
            t2 = toc(t1);
            if obj.playbackspeed < 1
                pause(0.033/obj.playbackspeed - t2)
                
            else
                pause(0.033 - t2)
            end
            
        end

    end
    
    function playVideo(obj, ~, ~)
    % Callback for play button. Plays calcium images as video
        
    %   Todo: If playback speed ischanging, should adjust current position.
    %   % As it is now, theres a big jump...
    
        obj.isPlaying = true;
        
        dt = 1/31;
        
        initialFrame = obj.currentFrameNo;
        tBegin = tic;
        
        while obj.isPlaying

            if obj.currentFrameNo >= obj.nFrames - (obj.playbackspeed+1)
                obj.currentFrameNo = 1;
                initialFrame = 1;
                tBegin = tic;
            end
            
            t1 = tic;

            elapsedTime = toc(tBegin);
            elapsedFrames = round( elapsedTime ./ dt .* obj.playbackspeed );

            
            if obj.playbackspeed >= 1
                src.Value = obj.playbackspeed;
            else
                src.Value = 1;
            end
            
            newFrame = initialFrame + elapsedFrames;
            obj.changeFrame(struct('String', num2str(newFrame)), [], 'jumptoframe')
            drawnow
            
            t2 = toc(t1);
            if obj.playbackspeed < 1
                pause(0.033/obj.playbackspeed - t2)
            else
                pause(0.033 - t2)
            end
            
            
                        
        end  
        
    end
    
    function manualLinkProp(obj)
        
        % Todo: Modify this:
        viewerNames = {'StackViewer', 'imviewer', 'Signal Viewer', 'Roi Classifier'};
        
        hApp = obj.uiSelectViewer(viewerNames, obj.Figure);
        obj.linkprop(hApp, 'currentFrameNo')
        
    end
    
    function linkprop(obj, externalGuiHandle, prop)
    %linkprop Link properties with external guis, so that update to
    %property is applied in all linked guis.
    
    % Work in progress. Currently supported property: currentFrameNo
    % Todo: How to do cleanup?
    
    % TODO: Expand so that listeners are deleted in a targeted way. I.e if
    % there are many externalGuiHandles.. Or maybe just accept on external
    % handle at a time...
    
    if nargin < 3 || isempty(prop)
        prop = 'currentFrameNo';
    end
        
    if isempty(obj.LinkedApps)
        obj.LinkedApps = externalGuiHandle;
    else
        obj.LinkedApps(end+1) = externalGuiHandle;
    end
    
    if isempty(externalGuiHandle.LinkedApps)
        externalGuiHandle.LinkedApps = obj;
    else
        externalGuiHandle.LinkedApps(end+1) = obj;
    end
    
    assert(strcmp(prop, 'currentFrameNo'), 'Currently only supports linking currentFrameNo property')
    
% %         assert(numel(externalGuiHandle) == 1, 'Currently only supports one handle at a time.')
% %         
% %         if ~isa(externalGuiHandle, 'cell') && numel(externalGuiHandle) == 1
% %             externalGuiHandle = {externalGuiHandle};
% %         end
% %         
% %         %Todo: Make sure a cell array of guis is a row vector...
% %     
% %         guiList = cat(2, {obj}, externalGuiHandle);
% %         
% %         eL = event.listener.empty;
% %         
% %         for i = 1:numel(guiList)
% %             eL(i) = addlistener(guiList{i}, prop, 'PostSet', @(s,e,h) obj.linkedPropertyChange(e, guiList));
% %         end
% %         
% %         addlistener(externalGuiHandle{1}, 'ObjectBeingDestroyed', @(src,evt) delete(eL));
        
    end
    
    function unlinkprop(obj, externalGuiHandle, prop) %#ok<INUSD>
        %todo
    end
    
    function linkedPropertyChange(obj, event, guiList)
        
        % Find which gui is the trigger:
        isAffected = cellfun(@(h) isequal(event.AffectedObject, h), guiList);
        
        newPropValue = guiList{isAffected}.(event.Source.Name);
        
        for i = find(~isAffected)
            
            if ~isvalid(guiList{i})
                continue
            end
            
            if isa(guiList{i}, 'imviewer.App')
                guiList{i}.changeFrame(struct('String', newPropValue), [], 'jumptoframe');
            elseif isa(guiList{i}, 'signalviewer.App')
                guiList{i}.interactiveFrameChangeRequest(struct('String', newPropValue), [], 'jumptoframe');
            elseif isa(guiList{i}, 'roiClassifier')
                guiList{i}.changeFrame(obj.image)
            else
                warning('Gui of type (%s) is not supported', class(guiList{i}))
            end
        end
        
    end
        
    function slideUiWidget(obj, action, uiwidgetName, dim, side)
        
        % UIWidgets 'thumbnailSelector', 'Toolbar'
        
        
        assert(isa(uiwidgetName, 'char'))
        
        
        if ~isfield(obj.uiwidgets, uiwidgetName)
            return
        end
        
        tmpAx = obj.uiwidgets.(uiwidgetName).Axes;

        switch action
            
            case 'show'
                nIter = 15;
                switch dim
                    case 'x'
                        deltaMov = tmpAx.Position(3) / (nIter);
                        tmpAx.Position(1) = -tmpAx.Position(3);
                        dim = 1;
                    case 'y'
                        deltaMov = tmpAx.Position(4) / (nIter);
                        switch side
                            case 'top'
                                imAxPos = obj.uiaxes.imdisplay.Position;
                                tmpAx.Position(2) = imAxPos(4)-imAxPos(2)+tmpAx.Position(4);
                                deltaMov = -deltaMov;
                            case 'bottom'
                                tmpAx.Position(2) = -tmpAx.Position(4);
                        end
                        dim = 2;
                end
% %                 deltaX = tmpAx.Position(3) / (nIter);
% %                 tmpAx.Position(1) = -tmpAx.Position(3);
            case 'hide'
                nIter = 10;
                switch dim
                    case 'x'
                        deltaMov = -1 * tmpAx.Position(3) / (nIter);
                        dim = 1;
                    case 'y'
                        deltaMov = -1 * tmpAx.Position(4) / (nIter);
                        if strcmp(side, 'top')
                            deltaMov = -deltaMov;
                        end
                        dim = 2;
                end
                
                %deltaX = -1 * tmpAx.Position(3) / (nIter);
        end

        for i = 1:nIter+1
            tmpAx.Position(dim) = tmpAx.Position(dim) + deltaMov;
            drawnow limitrate
        end
        
    end
    
    function onAutoAdjustLimitsPressed(obj, src, ~)
        
        if src.Value
            obj.autoAdjustLimits = true;
            P = prctile(double(obj.image(:)), [0.05, 99.95]);
            if all(isnan(P)); return; end
            obj.brightnessSlider.Low = P(1);
            obj.brightnessSlider.High = P(2);
            %obj.changeBrightness(P)
        else
            obj.autoAdjustLimits = false;
        end

%         obj.updateImage()
%         obj.updateImageDisplay()

    end
    
    function openBrightnessHistogram(obj)
        obj.displayMessage('Not quite finished yet...')
        %f = figure();
        pause(2)
        obj.clearMessage()
    end
    
    function showBrightnessSlider(obj)
        % Todo: rename to toggleVisibility....
        
        isVisible = strcmp(obj.brightnessSlider.Visible, 'on');
        
        if isVisible
            obj.uiwidgets.BrightnessToolbar.Visible = 'off';
            obj.brightnessSlider.Visible = 'off';
        else
            obj.uiwidgets.BrightnessToolbar.Visible = 'on';
            obj.brightnessSlider.Visible = 'on';            
        end
        
    end
    
    function showThumbnailViewer(obj, action)
        
        tmpAx = obj.uiwidgets.thumbnailSelector.Axes;
        tmpTb = obj.uiwidgets.thumbNailToggler;
        
        switch action
            
            case 'show'
                nIter = 15;
                deltaX = tmpAx.Position(3) / (nIter);
                tmpAx.Position(1) = -tmpAx.Position(3);
                tmpTb.Position(1) = -tmpAx.Position(3);
            case 'hide'
                nIter = 10;
                deltaX = -1 * tmpAx.Position(3) / (nIter);
        end
        
        
%         % Slide into view
%         h = obj.uiwidgets.thumbnailSelector;
%         
%         for i = 1:nIter+1
%             %tmpAx.Position(1) = tmpAx.Position(1) + deltaX;
%             h.Position(1) = h.Position(1) + deltaX;
%             %pause(0.01)
%             drawnow limitrate
%         end

        tmpAx.Position(1) = tmpAx.Position(1) + deltaX.*(nIter+1);
        tmpTb.Position(1) = tmpTb.Position(1) + deltaX.*(nIter+1);

        
    end
  
    function toggleImageToolbarPin(obj, ~, ~)
        
        obj.isImageToolbarPinned = ~obj.isImageToolbarPinned;
        
    end
    
    function togglePinThumbnailSelector(obj, ~, ~)
        obj.isThumbnailSelectorPinned = ~obj.isThumbnailSelectorPinned;
    end
    
    function switchHeaderVisibility(obj)
        
        if obj.showHeader
            obj.uiaxes.textdisplay.Visible = 'on';
            obj.infoField.Visible = 'on';
        else
            obj.uiaxes.textdisplay.Visible = 'off';
            obj.infoField.Visible = 'off';
        end
        
        switch obj.mode
            case 'standalone'
                obj.resizePanelContents(obj.Panel, true, 'width')
            case 'docked'
                obj.resizePanelContents(obj.Panel, false)
        end
        
    end
    
    function switchFooterVisibility(obj)
        
        if obj.showFooter
            obj.uiwidgets.playback.Visible = 'on';
        else
            obj.uiwidgets.playback.Visible = 'off';
        end
        
        switch obj.mode
            case 'standalone'
                obj.resizePanelContents(obj.Panel, true, 'width')
            case 'docked'
                obj.resizePanelContents(obj.Panel, false)
        end
        
    end
    
    
    function hideToolbars(obj)
        
        if isfield(obj.uiwidgets, 'Toolbar') && strcmp(obj.uiwidgets.Toolbar.Visible, 'on')
            %toolbarVisibleState = obj.uiwidgets.Toolbar.Visible;
            obj.uiwidgets.Toolbar.Visible = 'off';
            drawnow
        end
        
        if isfield(obj.uiwidgets, 'BrightnessSlider') && strcmp(obj.uiwidgets.BrightnessSlider.Visible, 'on')
            %toolbarVisibleState = obj.uiwidgets.Toolbar.Visible;
            obj.showBrightnessSlider()
            drawnow
        end
        
% %         if isfield(obj.uiwidgets, 'Appbar') && strcmp(obj.uiwidgets.Appbar.Visible, 'on')
% %             %toolbarVisibleState = obj.uiwidgets.Toolbar.Visible;
% %             obj.uiwidgets.Appbar.Visible = 'off';
% %             drawnow
% %         end
        
    end

% % Zooming functions (Todo: Outsource this to zooming and panning tools...)

    function imageZoom(obj, direction, speed)
        % Zoom in image    
        
        % TODO: Not working if image/axes aspect ratio is different from 1???
        
        if nargin < 3; speed = 1; end
            
        switch direction
            case 'in'
                zoomF = -obj.settings.Interaction.zoomFactor .* speed;
            case 'out'
                zoomF = obj.settings.Interaction.zoomFactor*2 .* speed;
        end

        xLim = get(obj.uiaxes.imdisplay, 'XLim');
        yLim = get(obj.uiaxes.imdisplay, 'YLim');

        currentFig = gcf;
        mp_f = get(currentFig, 'CurrentPoint');
        
        
        mp_a = get(obj.uiaxes.imdisplay, 'CurrentPoint');
        mp_a = mp_a(1, 1:2);

        % todo: clean up:
        
        % Find ax position and limits in figure units.
%         figsize = get(currentFig, 'Position');
        if isequal(currentFig, obj.Figure)
%             set(obj.uiaxes.imdisplay, 'units', 'normalized')
%             axPos = get(obj.uiaxes.imdisplay, 'Position') .* [figsize(3:4), figsize(3:4)]; % pixel units
%             set(obj.uiaxes.imdisplay, 'units', 'pixel')
            
            axPos = getpixelposition(obj.uiaxes.imdisplay, true);
            
        else
            return
        end
        
                
        axLim = axPos + [0, 0, axPos(1), axPos(2)]; % in pixels...

        % Check if mousepoint is within axes limits.
        insideImageAx = ~any(any(diff([axLim(1:2); mp_f; axLim(3:4)]) < 0));

        xLimNew = xLim + [-1, 1] * zoomF * diff(xLim);
        yLimNew = yLim + [-1, 1] * zoomF * diff(yLim);

        if insideImageAx
            mp_f = mp_f - [axPos(1), axPos(2)];

            % Correction of 0.25 was found to give precise zooming in and
            % out of a point... Is it the 0.5 offset in image coordinates
            % divided by 2?
            
            
            shiftX = (axPos(3)-mp_f(1)+0.25) / axPos(3)               * diff(xLimNew) - (xLim(1) + diff(xLim)/2 + diff(xLimNew)/2 - mp_a(1)) ;
            shiftY = (axPos(4)-abs(axPos(4)-mp_f(2)-0.25)) / axPos(4) * diff(yLimNew) - (yLim(1) + diff(yLim)/2 + diff(yLimNew)/2 - mp_a(2)) ;
            
            xLimNew = xLimNew + shiftX;
            yLimNew = yLimNew + shiftY;
        end

        setNewImageLimits(obj, xLimNew, yLimNew)

        
        
    end
    
    
    function setNewImageLimits(obj, xLimNew, yLimNew)

        % Todo: Have tests here to prevent setting limits outside of
        % image limits.


%          set(obj.uiaxes.imdisplay, 'units', 'pixel')
        pos = get(obj.uiaxes.imdisplay, 'Position');
%         set(obj.uiaxes.imdisplay, 'units', 'normalized')

        axAR = pos(3)/pos(4); % Axes aspect ratio.

        xRange = diff(xLimNew); yRange = diff(yLimNew);

        % Adjust limits so that the zoomed image fills up the display
        if xRange/yRange > axAR
            yLimNew = yLimNew + [-1, 1] * (xRange/axAR - yRange)/2 ;
        elseif xRange/yRange < axAR
            xLimNew = xLimNew + [-1, 1] * (yRange*axAR-xRange)/2;
        end

        if diff(xLimNew) > obj.imWidth
            xLimNew = [0, obj.imWidth] + 0.5;
        elseif xLimNew(1) <= 0.5
            xLimNew = xLimNew - xLimNew(1) + 0.5;
        elseif xLimNew(2) > obj.imWidth  + 0.5
            xLimNew = xLimNew - (xLimNew(2) - obj.imWidth)  + 0.5;
        end

        if diff(yLimNew) > obj.imHeight
            yLimNew = [0, obj.imHeight] + 0.5;
        elseif yLimNew(1) <= 0.5
            yLimNew = yLimNew - yLimNew(1) + 0.5;
        elseif yLimNew(2) > obj.imHeight  + 0.5
            yLimNew = yLimNew - (yLimNew(2) - obj.imHeight) + 0.5;
        end
        
        
        if diff(xLimNew) < 1 || diff(yLimNew) < 1; return; end
        
        
        set(obj.uiaxes.imdisplay, 'XLim', xLimNew, 'YLim', yLimNew)
        
        plotZoomRegion(obj, xLimNew, yLimNew) % move into onDisplayLimitsChanged?
        
        obj.onDisplayLimitsChanged()
        
        
    end
    
    
    function moveImage(obj, shift)
    % Move image in ax according to shift
        persistent shiftSum
        if isempty(shiftSum); shiftSum = [0,0]; end
        % Get current axes limits
        xlim = get(obj.uiaxes.imdisplay, 'XLim');
        ylim = get(obj.uiaxes.imdisplay, 'YLim');

        xRange = range(xlim);
        yRange = range(ylim);
        
        axpos = getpixelposition(obj.uiaxes.imdisplay);
                  
        pixel2du = [xRange, yRange] ./ axpos(3:4);
        shiftSum = shiftSum + shift;
        %s = dbstack
        
        % Convert mouse shift to image shift
        imshift = shift .* pixel2du;
        xLimNew = xlim - imshift(1);
        yLimNew = ylim + imshift(2);
        
        setNewImageLimits(obj, xLimNew, yLimNew)
        
    end
    
    function plotZoomRegion(obj, xLimNew, yLimNew)
        
        % Todo: 
        %   [ ] Work more on placement (offset) of rectangles. Right now,
        %       for very high resolution images with high AR they are close
        %       to edge...
        %   [ ] Add comments...
        %   [ ] Plot it with a maximum pixelsize. I.e, max 100 pixels along
        %       smallest dimension
        %   [ ] Todo: Take care if axes ar is different from image ar....
        %   [ ] Should this be part of zooming tools
            
        if nargin < 2
            xLimNew = obj.uiaxes.imdisplay.XLim;
            yLimNew = obj.uiaxes.imdisplay.YLim;
        end
        
        xRange = range(xLimNew);
        yRange = range(yLimNew);
        
        axpos = getpixelposition(obj.uiaxes.imdisplay);
        
        if xRange/yRange > axpos(3)/axpos(4)
            % use y for normalization
            pixel2du = yRange / axpos(4);
        else
            pixel2du = xRange / axpos(3);
        end
        
        % Set pixel limits for size and offset of zoom outlines.
        minSize = 20; minOffset = 5;
        maxSize = 100; maxOffset = 15;
        
        % Determine size and offset of zoom outlines based on size of axes
        rectSizeInPixels = min(axpos(3:4) .* 0.15);
        offsetInPixels = min(axpos(3:4) .* 0.025);
        
        % Make sure size and offset stays within limits.
        rectSizeInPixels = max([minSize, rectSizeInPixels]);
        rectSizeInPixels = min([maxSize, rectSizeInPixels]);

        offsetInPixels = max([minOffset, offsetInPixels]);
        offsetInPixels = min([maxOffset, offsetInPixels]);
        
        
        % Calculate resize factor to scale rectangular coordinates into
        % data units.
        resizeFactorFactor = min([obj.imWidth, obj.imHeight]) ./ ...
            min([rectSizeInPixels, axpos(3:4)]) ./ pixel2du;
        rect1 = [1,1,obj.imWidth, obj.imHeight] ./ resizeFactorFactor;
        rect2 = [xLimNew(1), yLimNew(1), xRange, yRange]  ./ resizeFactorFactor;
        
        % Add offset, to make sure rectangle stays in the corner
        offsetDu = [xLimNew(1), yLimNew(1)] + (offsetInPixels .* pixel2du);
        
        rect1(1:2) = rect1(1:2) + offsetDu;
        rect2(1:2) = rect2(1:2) + offsetDu;
        
        % Convert rectangle coord to plot data
        xData1 = [rect1(1), rect1(1)+rect1(3), rect1(1)+rect1(3), rect1(1)];
        xData2 = [rect2(1), rect2(1)+rect2(3), rect2(1)+rect2(3), rect2(1)];
        yData1 = [rect1(2), rect1(2), rect1(2)+rect1(4), rect1(2)+rect1(4)];
        yData2 = [rect2(2), rect2(2), rect2(2)+rect2(4), rect2(2)+rect2(4)];
        
        xData1(end+1) = xData1(1); xData2(end+1) = xData2(1);
        yData1(end+1) = yData1(1); yData2(end+1) = yData2(1);

        % Initialize or plot rectangles.
        if isempty(obj.zoomOutline) % Todo: Initialize this with axes....
            hold(obj.uiaxes.imdisplay, 'on')
            obj.zoomOutline = gobjects(2, 1);
            obj.zoomOutline(1) = plot(obj.uiaxes.imdisplay, xData1, yData1);
            obj.zoomOutline(2) = plot(obj.uiaxes.imdisplay, xData2, yData2);
            
            set(obj.zoomOutline, 'Color', ones(1,3)*0.5, 'LineWidth', 1)
            
            % Add listener for updating the plot rectangle whenever xlim or
            % ylim changes.
            addlistener(obj.uiaxes.imdisplay, {'XLim', 'YLim', 'Position'}, 'PostSet', ...
                @(s, e)obj.plotZoomRegion);
            
        else
            set(obj.zoomOutline(1), 'XData', xData1, 'YData', yData1)
            set(obj.zoomOutline(2), 'XData', xData2, 'YData', yData2)
        end
        
        
        % Hide box when image is zoomed out (with small wiggleroom)
        isZoomedOut =  sum( abs(xLimNew - ([0, obj.imWidth]+0.5)) ) < 1 && ...
                         sum( abs(yLimNew - ([0, obj.imHeight]+0.5)) ) < 1;
        if isZoomedOut
            set(obj.zoomOutline, 'Visible', 'off')
        else
            set(obj.zoomOutline, 'Visible', 'on')
        end
        
    end
    
    function resizeWindow(obj, ~, ~, resizeMode, incr )
        %TODO: Fix resize behavior for non-square figures
        % Todo: Fix bug when this function is called many times in a short
        % time.
        
        % Todo: Adjust increment if figsize is approacing screen size.
        % Todo: Fix so that window does not jump to screen 1 when resized.
        % Todo: Make this quicker. Reduce number of axes?
        
        % Todo: Is there anything that can be optimized here???
        % D do we need source or eventdata for anything?
        
        
        % Thanks to Jan @ https://www.mathworks.com/...
        % matlabcentral/answers/570829-slow-sizechangedfcn-or-resizefcn
%         persistent blockCalls  % Reject calling this function again until it is finished
%         if any(blockCalls), return, end
%         blockCalls = true;
        
        
        % Hackety hack because toolbar icons are very slow to update when
        % they are visible...
        obj.hideToolbars()
        
        % Make resizable and turn off resizeability when finished.
        obj.Figure.Resize = 'on';
% %         obj.Figure.Interruptible = 'off'; % Not sure if this has any function. But idea is to prevent another resize if one is ongoing...
% %         obj.Figure.BusyAction = 'cancel';
        
% %         C = onCleanup(@(s,e) set(obj.Figure, 'Resize', 'off'));
                
        screenSize = obj.getCurrentMonitorSize(obj.Figure);
        
        if nargin < 3 || isempty(resizeMode)
            resizeMode = 'custom';
        end
        
        oldFigurePosition = obj.Figure.Position;

        keepAspectRatio = true;
                
        % Determine change in figure size
        switch resizeMode
            case {'grow', 'shrink'}
                newAxesSize = obj.updateAxesSize(resizeMode, false);
                newFigureSize = obj.getFigureSize(newAxesSize);
                
                deltaSize = newFigureSize - oldFigurePosition(3:4);
                newFigureLocation = oldFigurePosition(1:2) - deltaSize(1:2)./2;
                newFigurePosition =  [newFigureLocation, newFigureSize];
                
            case 'maximize'
                newFigureSize = getMaximumFigureSize(obj);
                newFigurePosition = [screenSize(1:2), newFigureSize];
                keepAspectRatio = false;
            case 'restore'
                [newFigurePosition, ~] = obj.initializeFigurePosition();
                
            case 'manual'
                newFigureSize = oldFigurePosition(3:4) +  incr;
                
                deltaSize = newFigureSize - oldFigurePosition(3:4);
                newFigureLocation = oldFigurePosition(1:2) - deltaSize(1:2)./2;
                newFigurePosition =  [newFigureLocation, newFigureSize];
            otherwise
                % Do nothing
        end
        
        % Abort if resulting figure is less than 100 x 100 pixels.
        if all(newFigurePosition(3:4) < [100, 100])
            return
        end
        
        % Todo: Should I test any or all here. I had used any before, but
        % changed it because that did not work for when draggin an image
        % stack of different size into the window. (if new stack only had different size in 1 dim)
        if all(abs(newFigurePosition(3:4) - oldFigurePosition(3:4)) < 2)
            return
        end
        
        newFigurePosition = obj.assertWindowOnScreen(newFigurePosition, screenSize); % superclass static method
        
        % Turn off panel size changed function
        panelSizeChangedFcn = obj.Panel.SizeChangedFcn;
        obj.Panel.SizeChangedFcn = [];
        %obj.Panel.Units = 'pixel';

        % Resize figure and panel
        obj.Figure.Position = newFigurePosition;
        obj.Panel.Position = [1,1,obj.Figure.InnerPosition(3:4)];
        obj.resizePanelContents(obj.Panel, keepAspectRatio)
        
        % Turn on panel size changed function
        %obj.Panel.Units = 'normalized';
        obj.Panel.SizeChangedFcn = panelSizeChangedFcn;
                     

        % % blockCalls = false;

        obj.Figure.Resize = 'off';

    end
    
    
    function resizePanelContents(obj, hPanel, preserveAspectRatio, mode)
        
        if nargin < 2 
            hPanel = obj.Panel;
        end
        
        if nargin < 3 || isempty(preserveAspectRatio)
            preserveAspectRatio = false;
        end
        
        if nargin < 4
            mode = 'auto';
        end
        
        newPosition = getpixelposition(hPanel);
        axesMargins = obj.positionInfo.Margin;
        [headerSize, footerSize] = deal( axesMargins(2) );
        
        axesSize = obj.getAxesSize(newPosition(3:4), preserveAspectRatio, mode);
           
        % Resize image display
        newAxLocation = [axesMargins(1) + 1, obj.showFooter*footerSize + 1];
        obj.uiaxes.imdisplay.Position = [newAxLocation, axesSize];

        if obj.showHeader
            % Resize header  (text display)
            obj.uiaxes.textdisplay.Position(2) = newPosition(4) - headerSize;
            obj.uiaxes.textdisplay.Position(3) = newPosition(3) + 1;
            obj.uiwidgets.Toolbar.Margin(4) = 25;
        else
            obj.uiwidgets.Toolbar.Margin(4) = 25 - obj.positionInfo.Margin(2);
        end
        
        if obj.showFooter
            obj.uiwidgets.playback.Position(3) = newPosition(3);
            %obj.uiaxes.scrollerax.Position(3) = newPosition(3) - 80;
            obj.uiwidgets.Toolbar.Margin(2) = 25;
        else
            obj.uiwidgets.Toolbar.Margin(2) = 25 - obj.positionInfo.Margin(2);
        end
        
        % Readjust figure position if it is not correct
        if preserveAspectRatio
            optimalFigureSize = obj.getFigureSize(axesSize);
            if any( abs(obj.Figure.Position(3:4) - optimalFigureSize) >= 1 )
                %disp('Adjusted figure size')
                deltaSize = optimalFigureSize - obj.Figure.Position(3:4);
                newLocation = round( obj.Figure.Position(1:2) - deltaSize/2 );
                obj.Figure.Position = [newLocation, optimalFigureSize];            
                %obj.Panel.Position(3:4) = optimalFigureSize;
                setpixelposition(obj.Panel, [1,1,optimalFigureSize])
                obj.resizePanelContents(obj.Panel, false)
            end
        end

        
        % Center thumbnail selector
        if isfield(obj.uiwidgets, 'thumbnailSelector')
            
            % TODO: Only resize if this is visible!
            
            obj.uiwidgets.thumbnailSelector.Visible = 'off';
            obj.uiwidgets.thumbNailToggler.Visible = 'off';
%             obj.showThumbnailViewer('hide')
            
            imAxPos = obj.uiaxes.imdisplay.Position;
            tmpAx = obj.uiwidgets.thumbnailSelector;

            aR = tmpAx.Position(3) / tmpAx.Position(4);
            h = imAxPos(4) * 0.8;
            w = h * aR;
            
            if w > 150; w = 150; h = w ./ aR; end
                         
            tmpAx.Position(3:4) = [w, h];
            tmpAx.Position(2) = imAxPos(2) + (imAxPos(4)-tmpAx.Position(4))/2;
            
            obj.uiwidgets.thumbNailToggler.Position = [tmpAx.Position(1), tmpAx.Position(2)-32, ...
                           tmpAx.Position(3), 30 ];
            
            if obj.isThumbnailSelectorPinned
                obj.uiwidgets.thumbnailSelector.Visible = 'on';
                obj.uiwidgets.thumbNailToggler.Visible = 'on';
            end
                       
        end
        
        if isfield(obj.uiwidgets, 'msgBox')
            d = (newPosition(3:4) - obj.uiwidgets.msgBox.Axes.Position(3:4))/2;
            obj.uiwidgets.msgBox.Axes.Position(1:2) = d;
        end
        
        % % % Debugging
        %disp('resizing')
        %dbstack
        
        
        if strcmp(obj.mode, 'standalone')
            drawnow
        end
             
        % % % obj.Figure.Position = [figPos, figSize];

    end

    function replaceStack(obj, newStack, deleteFlag)
        % Todo: merge with filedrop?
        
        if nargin < 3
            deleteFlag = true;
        end
        
        if deleteFlag
            delete(obj.ImageStack)
        end
        
        obj.ImageStack = newStack;
        
    end
   
    function onLoadImageDataPressed(obj, useDialog)
        
        if nargin < 2; useDialog = false; end
        
        if ~obj.ImageStack.IsVirtual  
            obj.displayMessage('Image data is already in memory', [], 1.5)
            return
        end
        
        % Proceeding with virtual stack (get load preferences)
        if useDialog
            S = obj.settings.VirtualData;
            S = rmfield(S, 'useDynamicCache');
            S = rmfield(S, 'dynamicCacheSize');
            
            [S, wasAborted] = tools.editStruct(S, '', 'Load Selection');
            if wasAborted; return; end
        else
            S = obj.settings.VirtualData;
        end
        
        % Determine frames to load.
        firstFrame = S.initialFrameToLoad;
        lastFrame = min([firstFrame-1+S.numFramesToLoad, obj.nFrames]);
        frameInd = firstFrame:lastFrame;
        
        obj.loadImageFrames(frameInd, S)
        
    end
    
    function onFrameIntervalSelectionChanged(obj, ~, evt)
        frameInd = evt.NewRange(1):evt.NewRange(2);
        obj.loadImageFrames(frameInd)
    end
    
    
    function loadImageFrames(obj, frameInd, opts)
        
        if nargin < 3
            opts = obj.settings.VirtualData;
        end
        
        % Activate waitbar...
        obj.uiwidgets.msgBox.activateGlobalWaitbar()
        
        obj.displayMessage('Updating image data')
        
        %imData = obj.ImageStack.imageData(:, :, frameInd); %Todo!
        imData = obj.ImageStack.getFrameSet(frameInd); %Todo!

        obj.uiwidgets.msgBox.deactivateGlobalWaitbar()
        obj.clearMessage()

        % todo... Find a way to turn preprocessing on and off
        
        switch opts.target
            case 'Add To Memory'
                if ~obj.ImageStack.HasStaticCache
                    obj.uiwidgets.playback.RangeSelectorEnabled = 'on';
                end
                obj.ImageStack.addToStaticCache(imData, frameInd);
                obj.uiwidgets.playback.ActiveRange = [frameInd(1), frameInd(end)];

            case 'New Window'
                newStack = nansen.stack.ImageStack(imData); % Todo
                newStack.FileName = obj.ImageStack.FileName; 
                imviewer(newStack)

            case 'Replace Stack'
                filePath = obj.ImageStack.FileName; 
                obj.replaceStack(imviewer.ImageStack(imData), false)
                obj.ImageStack.FileName = filePath; 

        end

    end
    
    
    function saveImage(obj, savePath)
        
        
        if nargin < 2 || isempty(savePath)
            savePath = obj.getImageFilePath();
        end
        
        if isempty(savePath); return; end

        im = obj.imObj.CData;
        
        switch class(im)
            case 'uint16'
                imwrite(uint16(im), savePath, 'TIFF')
            case 'int16'
                im = im - min(im(:));
                imwrite(uint16(im), savePath, 'TIFF')
                
                % Todo, use Tiff... imwrite(int16(im), savePath, 'TIFF')
            case 'uint8'
                imwrite(uint8(im), savePath, 'TIFF')
            otherwise % This will need to be fixed at some point
                imwrite(uint8(im), savePath, 'TIFF')
        end

    end
    
    
    function saveImageToDesktop(obj)
        filename = strcat('imviewer_', datestr(now, 'yyyy_mm_dd-HH.MM.SS'), '.tif');
        savePath = fullfile(getDesktop, filename);

        obj.saveImage(savePath)
    end
    
    
    function savePath = getImageFilePath(obj)
        
        % todo: not imviewer method...
          
        savePath = '';
        
        initPath = obj.ImageStack.FileName;
        
%         Todo. implement different filetypes:
%         filePattern = { '*.tif;*.tiff;*.png;*.jpg;*.jpeg;*.JPG', ...
%                         'Image Files (*.tif, *.tiff, *.png, *.jpg, *.jpeg, *.JPG)'; ...
%                        '*', 'All Files (*.*)'} ;

        filePattern = { '*.tif;*.tiff', 'Tiff Files (*.tif, *.tiff)' };
        [fileName, folderPath] = uiputfile(filePattern, '', initPath);
        
        if isempty(fileName) || isequal(fileName, 0)
            return
        end
        
        savePath = fullfile(folderPath, fileName);

    end
    
    function showHelp(obj, ~, ~)
        
        % Create a figure for showing help text
        helpfig = figure('Position', [100,200,500,500], 'Visible', 'off');
        helpfig.Resize = 'off';
        helpfig.Color = obj.Theme.FigureBgColor;
        helpfig.MenuBar = 'none';
        helpfig.NumberTitle = 'off';
        helpfig.Name = 'Help for imviewer';
        
        

        % Create an axes to plot text in
        ax = axes('Parent', helpfig, 'Position', [0,0,1,1]);
        ax.Visible = 'off';
        hold on
        
        
        messages = {...
            '\bGet Started', ...
            ['To quickly open a file, copy the path string to the clipboard (On mac, select \n', ...
             'a file and press cmd+alt+c. On windows, press shift and right click the file, \n', ...
             'then select copy as path). Then run imviewer from the matlab command line.'], ...
            '', ...
            '\bKey Shortcuts' ...
            'arrows up/down : Make window larger/smaller', ...
            'c : Toggle slider for changing min and max brightness limits\n (slider appears in top right corner)', ...
            '+/- : Zoom in/out', ...
            'alt+arrows : Pan image when zoomed in', ...
            'q : Activate zoom in', ...
            'w : Activate zoom out', ...
            'p : Toggle play/pause video', ...
            'n : Show average projection image', ...
            'alt+n : Show a moving average', ...
            'm : Show maximum projection', ...
            'r : Rotate image (Use shift to change direction and\n ctrl for small steps)', ...
            ...
            '\n\bMouse Behavior' ...
            'scroll : Scroll through images if a stack is loaded', ...
            'shift+scroll : Zoom in and out'} ;
        
        % Plot messages from bottom top. split messages by colon and
        % put in different xpositions.
        numMessage = numel(messages);
        hTxt = gobjects(numMessage*2, 1);
        
        y = 0.1;
        x1 = 0.05;
        x2 = 0.3;
        
        count = 0;

        for i = numel(messages):-1:1
            nLines = numel(strfind(messages{i}, '\n'));
            y = y + nLines*0.03;

            makeBold = contains(messages{i}, '\b');
            messages{i} = strrep(messages{i}, '\b', ''); 

            if contains(messages{i}, ':')
                msgSplit = strsplit(messages{i}, ':');
                count = count + 1;
                hTxt(count) = text(x1, y, sprintf(msgSplit{1}));
                count = count + 1;
                hTxt(count) = text(x2, y, sprintf([': ', msgSplit{2}]));
            else
                count = count + 1;
                hTxt(count) = text(0.05, y, sprintf(messages{i}));
            end

            if makeBold; hTxt(count).FontWeight = 'bold'; end

            y = y + 0.05;
        end
        
        hTxt = hTxt(1:count);
        
        color = obj.Theme.FigureFgColor;
        set(hTxt, 'FontSize', 14, 'Color', color, 'VerticalAlignment', 'top')

        hTxt(end).ButtonDownFcn = @(s,e) fovmanager.openWiki;

        % Adjust size of figure to wrap around text.
        % txtUnits = get(hTxt(1), 'Units');
        set(hTxt, 'Units', 'pixel')
        extent = cell2mat(get(hTxt, 'Extent'));
        % set(hTxt, 'Units', txtUnits)

        maxWidth = max(sum(extent(:, [1,3]),2));
        helpfig.Position(3) = maxWidth./0.9; %helpfig.Position(3)*0.1 + maxWidth;
        helpfig.Position(4) = helpfig.Position(4) - (1-y)*helpfig.Position(4);
        helpfig.Visible = 'on';
        
        warning('off', 'MATLAB:ui:javaframe:PropertyToBeRemoved')
        
        % Close help window if it loses focus
        jframe = getjframe(helpfig); 
        set(jframe, 'WindowDeactivatedCallback', @(s, e) delete(helpfig))
        
        warning('on', 'MATLAB:ui:javaframe:PropertyToBeRemoved')

    end
    
   
% % Todo: Remove/resolve this
    
    function editSettings(obj, ~, ~)
        obj.editSettings@applify.mixin.UserSettings()

        % Why? Is this if the cancel button is hit?
        obj.uiaxes.imdisplay.CLim = obj.settings.ImageDisplay.imageBrightnessLimits;
    end

    
% % Plot tools % Move to a toolbox?

    function plotCircle(obj, center, radius)

        if ~isfield(obj.tmpHandles, 'hCircle') || isempty(obj.tmpHandles.hCircle)
            obj.tmpHandles.hCircle = viscircles(obj.uiaxes.imdisplay, center, radius, 'LineWidth', 1, 'EdgeColor', 'none');
            obj.tmpHandles.hCircle(end+1) = plot(obj.uiaxes.imdisplay, center(1), center(2), '+', 'Color', ones(1,3)*0.2);
        else
            l1 = obj.tmpHandles.hCircle(1).Children(1);
            l2 = obj.tmpHandles.hCircle(1).Children(2);
            p = obj.tmpHandles.hCircle(2);
        
            if ~isnan(radius)
                th = deg2rad(0:360);
                xData = radius * cos(th) + center(1);
                yData = radius * sin(th) + center(2);
                
%                 l1.XData = xData; l1.YData = yData; 
%                 l2.XData = xData; l2.YData = yData;

                set([l1, l2], 'XData', xData, 'YData', yData)
                set(p, 'XData', center(1), 'YData', center(2))
            else
                l1.XData = nan; l1.YData = nan; 
                l2.XData = nan; l2.YData = nan;
                set(p, 'XData', nan, 'YData', nan)
            end
        end
    end
    
    
    function deleteCircle(obj)
        if isfield(obj.tmpHandles, 'hCircle')
            delete(obj.tmpHandles.hCircle)
            obj.tmpHandles.hCircle = [];
        end
        
    end
    
    
    function plotOverlay(obj, key)
    
        switch key
            case '1' % Plot a circle with on center of image with diameter equal to the shortest side 
                h = findobj(obj.uiaxes.imdisplay, 'Tag', 'CenterCross');
                if isempty(h)
                    xdata = [1, obj.imHeight, nan, obj.imHeight/2, obj.imHeight/2];
                    ydata = [obj.imWidth/2, obj.imWidth/2, nan, 1, obj.imHeight];
                    plot(ydata, xdata, 'Tag', 'CenterCross')
                else
                    delete(h)
                    clear('h')
                end
                
            case '2' % Plot a cross on center.
                h = findobj(obj.uiaxes.imdisplay, 'Tag', 'CenterCircle');
                if isempty(h)
                    center = [obj.imWidth, obj.imHeight] / 2;
                    rad = min(center);
                    xdata = rad .* cos(deg2rad(0:360)) + center(1) ;
                    ydata = rad .* sin(deg2rad(0:360)) + center(2) ;
                    plot(obj.uiaxes.imdisplay, xdata, ydata, 'Tag', 'CenterCircle', 'LineWidth', 1)
                else
                    delete(h)
                    clear('h')
                end
            case '3'
                if isfield(obj.tmpHandles, 'grid')
                    delete(obj.tmpHandles.grid)
                    obj.tmpHandles = rmfield(obj.tmpHandles, 'grid');
                else
                    n = obj.settings.gridSize;
                    obj.tmpHandles.grid = imviewer.tools.plotgrid(obj.uiaxes.imdisplay, n);
                end
        end
        
    end
    
    
% % Interactive Selection Tools

    function rcc = selectRectangularRoi(obj, rccInit)

        plotColor = [128, 128, 128]./255;

        imSizeXY = [obj.imWidth, obj.imHeight] - 40;
        
        if nargin < 2 || isempty(rccInit)
            rccInit = [21,21, imSizeXY-[1,1]];
        end
        
        % Move to non-class function
        if obj.isMatlabPre2018b
            hrect = imrect(obj.uiaxes.imdisplay, rccInit); %#ok<IMRECT>
            hrect.setColor(plotColor)
            restrainCropSelection = makeConstrainToRectFcn('imrect', [1, obj.imWidth], [1, obj.imHeight]);
            hrect.setPositionConstraintFcn( restrainCropSelection );
            uiwait(obj.Figure)
            rcc = round(hrect.getPosition);
        else
            hrect = drawrectangle(obj.uiaxes.imdisplay, 'Position', rccInit);
            hrect.Color = plotColor;
            hrect.DrawingArea = [1, 1, obj.imWidth, obj.imHeight];
            uiwait(obj.Figure)
            rcc = round(hrect.Position);
        end
        
        delete(hrect);

    end
    
    function coords = polySelect(obj)
        
        plotColor = [128, 128, 128]./255;

        hPoly = impoly(obj.uiaxes.imdisplay); %#ok<IMPOLY>
        hPoly.setColor(plotColor)

        uiwait(obj.Figure)

        coords = hPoly.getPosition;
        delete(hPoly);
        
        x = coords(:,1); y = coords(:,2);
        
        x = interp(x, 10);
        x = utility.circularsmooth(x, 10);
        y = interp(y, 10);

        y = utility.circularsmooth(y, 10);
        
        plot(obj.uiaxes.imdisplay, x, y)


    end
    
    function [pos, h] = selectTwoPoints(obj)
        
        % this is a measurement tool
        
        %Todo: Create non-class function.

        plotColor = [128, 128, 128]./255;

        impoints = cell(2, 1);
        hline = plot(obj.uiaxes.imdisplay, nan, nan,  '--');
        hline.Color = plotColor;
        hline.LineWidth = 1;
        hline.HitTest = 'off';
        
        for i = 1:2
            impoints{i} = impoint(obj.uiaxes.imdisplay); %#ok<IMPNT>
            impoints{i}.setColor(plotColor);
            impoints{i}.addNewPositionCallback(@(pos)updateLineBetweenPoints(obj, pos, hline, i));
        end

        impointPosition = cellfun(@(imp) imp.getPosition, impoints, 'uni', false);
        impointPosition = cell2mat(impointPosition);

        hline.XData = impointPosition(:, 1)';
        hline.YData = impointPosition(:, 2)';

        uiwait(obj.Figure)

        pos = cellfun(@(imp) imp.getPosition, impoints, 'uni', false);
        pos = cell2mat(pos);
        cellfun(@(imp) delete(imp), impoints, 'uni', false);
        
        
        obj.tmpHandles.twoPointLine = hline;
        
        if nargout == 2
            h = hline;
        end
        
    end
    
    function updateLineBetweenPoints(~, pos, hLine, i)
        x = pos(1);
        y = pos(2);

        hLine.XData(i) = x;
        hLine.YData(i) = y;
    end
    
    function deleteTwoPointLine(obj)
        if isfield(obj.tmpHandles, 'twoPointLine') && ~isempty(obj.tmpHandles.twoPointLine)
            if isvalid(obj.tmpHandles.twoPointLine)
                delete(obj.tmpHandles.twoPointLine)
            end
            obj.tmpHandles = rmfield(obj.tmpHandles, 'twoPointLine');
        end
    end
    
    function [pos] = freeHandLine(obj)
        obj.tmpHandles.freehandLine = [];
        
        obj.Figure.WindowButtonDownFcn = @obj.startDraw;
        
        uiwait(obj.Figure)
        
        obj.Figure.WindowButtonDownFcn = [];
        
        x = obj.tmpHandles.freehandLine.XData;
        y = obj.tmpHandles.freehandLine.YData;
        
        delete(obj.tmpHandles.freehandLine)
        obj.tmpHandles.freehandLine = [];
        
        pos = [x',y'];
        
    end
    
    function startDraw(obj, ~, event)
        % Todo. Make into pointer tools

        % NB: Call this before assigning moveObject callback. Update
        % coordinates callback is activated in the moveObject
        % function..
        
        x = event.IntersectionPoint(1);
        y = event.IntersectionPoint(2);
        obj.prevMousePoint = [x, y];

        obj.Figure.WindowButtonMotionFcn = @(src, event) obj.drawLine();
        obj.Figure.WindowButtonUpFcn = @(src, event) obj.stopDraw;

    end

    function drawLine(obj)
        % Todo. Make into pointer tools
        point = obj.uiaxes.imdisplay.CurrentPoint;

        xNew = point(1,1);
        yNew = point(1,2);

        
        if isempty(obj.tmpHandles.freehandLine) 
            xData = xNew;
            yData = yNew;
        else 
            xData = horzcat(obj.tmpHandles.freehandLine.XData, xNew);
            yData = horzcat(obj.tmpHandles.freehandLine.YData, yNew);
        end

        win = max([1,numel(xData)-4]):numel(xData);

        if ~any(isnan(xData(win)))
            xData(win) = smoothdata(xData(win));
            yData(win) = smoothdata(yData(win));
        end

        if isempty(obj.tmpHandles.freehandLine) 
            obj.tmpHandles.freehandLine = plot(obj.uiaxes.imdisplay, xData, yData, '-');
            obj.tmpHandles.freehandLine.LineWidth = 2;
            obj.tmpHandles.freehandLine.Color = 'c';
            obj.tmpHandles.freehandLine.HitTest = 'off';
            obj.tmpHandles.freehandLine.PickableParts = 'None';
        else 
            set(obj.tmpHandles.freehandLine, 'XData', xData)
            set(obj.tmpHandles.freehandLine, 'YData', yData)
        end

    end

    function stopDraw(obj)

%         xData = horzcat(obj.tmpHandles.freehandLine.XData, nan);
%         yData = horzcat(obj.tmpHandles.freehandLine.YData, nan);
%         set(obj.tmpHandles.freehandLine, 'XData', xData)
%         set(obj.tmpHandles.freehandLine, 'YData', yData)
%         
        obj.Figure.WindowButtonMotionFcn = @obj.mouseOver;
        obj.Figure.WindowButtonUpFcn = @obj.mouseRelease;
        
    end

end

methods (Access = private) % Housekeeping
    
    function turnOffModernAxesToolbar(obj, hAxes)
        
        % Disable newer matlab axes interactivity...
        if ~obj.isMatlabPre2018b
            % addToolbarExplorationButtons(obj.Figure)
            % hAxes.Toolbar.Visible = 'off';
            disableDefaultInteractivity(hAxes)
        end 
        
    end
end

methods (Access = protected) % Event callbacks
    
    function onSettingsChanged(obj, name, value)
        
        % Update the value in the the settings... Only necessary if the
        % function is called from external source....
        
        superFields = fieldnames(obj.settings);
        
        for i = 1:numel(superFields)
            thisField = superFields{i};
            if isfield(obj.settings.(thisField), name)
                obj.settings.(thisField).(name) = value;
                break
            end
        end
        
        
        switch name
            
            case 'brightnessSliderLimits'
                obj.setSliderExtremeLimits(value)

            case 'imageBrightnessLimits' % Todo: find better solution...
                
                if isfield(obj.uiaxes, 'imdisplay')
                    S = dbstack();
                    if ~strcmp(S(3).name, 'imviewer.changeBrightness') && ~strcmp(S(3).name, 'App.changeBrightness')
                        %obj.changeBrightness(value)
                        obj.setSliderLimits(value)
                    end
                end

            case 'useDynamicCache'
                if obj.ImageStack.IsVirtual 
                    obj.ImageStack.Data.UseDynamicCache = value;
                end

            case 'dynamicCacheSize'
                if obj.ImageStack.IsVirtual  %Update cache size of virtual stack.
                    if isempty(value); value = 0; end
                    
                    obj.displayMessage('Updating cache size...')
                    obj.ImageStack.Data.updateCacheSize(value); % Todo: test
                    bytes = obj.ImageStack.imageData.getCacheByteSize(); % Todo
                    
                    if bytes > 1e9
                        msg = sprintf('Cache uses ~%.1f GB of memory', round(bytes/1e9, 1));
                    elseif bytes > 1e6
                        msg = sprintf('Cache uses ~%d MB of memory', round(bytes/1e6));
                    else
                        msg = sprintf('Cache uses ~%d kB of memory', round(bytes/1e3));
                    end
                    
                    obj.displayMessage(msg, [], 2)
                    
                end
                
            case 'binningSize'
                obj.updateImage()
                obj.updateImageDisplay()
                
                
            case 'showMovingAvg' % Todo: remove...
                obj.settings.showMovingAvg = value;
                if obj.settings.showMovingAvg
                    obj.changeImageDisplayMode('binning', 'average')
                else
                    obj.changeImageDisplayMode('binning', 'none')
                end
            
            case 'colorMap'
                obj.changeColormap();
                
            case 'showHeader'
                obj.showHeader = value;
                
            case 'showFooter'
                obj.showFooter = value;
                
            case 'imageToolbarLocation'
                obj.uiwidgets.Toolbar.Location = value;
                
                
        end
    end

    
    function onThemeChanged(obj)

        % Todo: Apply changes to toolbars and widgets as well!
        
        S = obj.Theme;
        onThemeChanged@applify.ModularApp(obj)
% %         obj.setFigureWindowBackgroundColor(S.FigureBgColor)
% %         
% %         obj.Figure.Color = S.FigureBgColor;
% %         obj.Panel.BackgroundColor = S.FigureBgColor;
        
        obj.uiaxes.imdisplay.Color = S.FigureBgColor;
        
        obj.infoField.Color = S.HeaderFgColor;
        obj.uiaxes.textdisplay.Color = S.HeaderBgColor;
        obj.uiwidgets.Appbar.BackgroundColor = S.HeaderBgColor;
        
        
        obj.uiwidgets.playback.BackgroundColor = S.HeaderBgColor;
        
    end
    
    function onSliderChanged(obj, ~, evtData)
        
        if evtData.High <= evtData.Low
            evtData.High = evtData.Low;
        end

        newCLim = [evtData.Low, evtData.High];
        obj.changeBrightness(newCLim)
        
    end
    
    function onMouseEnteredImage(obj, ~, ~)
        isMatch = contains({obj.plugins.pluginName}, 'pointerManager');
        if any(isMatch)
            pifHandle = obj.plugins(isMatch).pluginHandle;
            pifHandle.updatePointerSymbol()
        end
    end

    function onMouseExitedImage(obj, ~, ~)
        if ispc
            obj.Figure.Pointer = 'arrow';
        else
            obj.Figure.Pointer = 'fleur';
        end
    end
    
    
% % Mouse and Keyboard callbacks
    function tf = isMouseOnWidget(obj, widgetName)
    %isMouseOnWidget Check if mouse pointer is on top of a widget
    %
    %   tf = isMouseOnWidget(obj, widgetName) checks if the mouse pointer
    %   is on top of a widget. widgetname can be the name of a single
    %   widget or a cell array of widgetNames. If more than one widget is
    %   given, tf is a row vector.
    

        xy = obj.Figure.CurrentPoint;

        if ~isa(widgetName, 'cell')
            widgetName = {widgetName};
        end
        numWidgets = numel(widgetName);
        
        tf = false(1, numWidgets);

        for i = 1:numWidgets
            if ~isfield(obj.uiwidgets, widgetName{i}); continue; end
            if isempty(obj.uiwidgets.(widgetName{i})); continue; end
            if strcmp(obj.uiwidgets.(widgetName{i}).Visible, 'off'); continue; end
        
            widgetPosition = obj.uiwidgets.(widgetName{i}).Position;
            widgetLim = uim.utility.pos2lim(widgetPosition);

            % Check if mousepoint is within axes limits.
            tf(i) = ~any(any(diff([widgetLim(1:2); xy; widgetLim(3:4)]) < 0));
        end
        
    end
    
end

methods (Access = {?applify.ModularApp, ?applify.DashBoard} )

    function onMousePressed(obj, ~, ~)
        
        if strcmp(obj.Figure.SelectionType, 'normal')
            obj.mouseDown = true;
        end
                
        global imviewerInstances
        
        isValid = arrayfun(@(h) isvalid(h.Figure), imviewerInstances.Handles);
        imviewerInstances.Handles(~isValid) = [];
        
        imviewerInstances.IsMouseDown = true;
        imviewerInstances.PreviousInstance = obj;

    end
    
    function onMouseReleased(obj, ~, ~)
        obj.mouseDown = false;
        obj.isDrag = false;
        
        if ~isempty(obj.hThumbnail) && isvalid(obj.hThumbnail)
            delete(obj.hThumbnail)
            obj.hThumbnail = [];
        end
        
        global imviewerInstances
        
        pointerLocation = get(0, 'PointerLocation');
        
        figurePositions = arrayfun(@(h) h.Figure.Position, imviewerInstances.Handles, 'uni', 0);
        figurePositions = cat(1, figurePositions{:});
        
        figLimits = uim.utility.pos2lim(figurePositions);
        isPointerOver = all(pointerLocation > figLimits(:, 1:2), 2) & ...
                            all(pointerLocation < figLimits(:, 3:4), 2);
        
        currentInstance = imviewerInstances.Handles(isPointerOver);
        
        if any(ismember(currentInstance, imviewerInstances.PreviousInstance))
            return
        end
        
        if numel(currentInstance) > 1
            currentInstance = currentInstance(1);
        end
        
        if ~isequal(imviewerInstances.PreviousInstance, currentInstance) && ...
            ~isempty(currentInstance) && imviewerInstances.IsMouseDown
            
            tmpImage = imviewerInstances.PreviousInstance.image;
            currentInstance.addImage(tmpImage)
            imviewerInstances.PreviousInstance = currentInstance;
        end
        
        imviewerInstances.IsMouseDown = false;

    end
    
    function onMouseMotion(obj, ~, ~)
        
        if ~obj.isMouseInApp; return; end
        
        % % Update current pixel information
        mousePoint = round( obj.uiaxes.imdisplay.CurrentPoint(1,1:2) );
        x = mousePoint(1);
        y = mousePoint(2);
        
        
        if x > 1 && x < obj.imWidth && y > 1 && y < obj.imHeight
            % Get pixelvalue for text display
            pixelValueStr = obj.getPixelValueAtCoordsAsString([x, y]);
            obj.textStrings.CursorPoint = pixelValueStr;
        else
            obj.textStrings.CursorPoint = '';
        end
        
        obj.updateInfoText();
        
        if obj.isDrag; return; end
        
        if obj.mouseDown && obj.ImageDragAndDropEnabled% Create a draggable thumbnail of current image
            obj.isDrag = true;
            
            % Abort if mousemode is set
            if ~isempty(obj.plugins(1).pluginHandle.currentPointerTool)
                return
            end
            
            widgets = {'thumbnailSelector', 'Toolbar', 'Taskbar', ...
                'thumbNailToggler', 'playback', 'Appbar', 'BrightnessSlider',...
                'BrightnessToolbar'};
            
            % Abort if mouse is over any of the widgets.
            if any( obj.isMouseOnWidget(widgets) )
                return
            end
            
            if x > 1 && x < obj.imWidth && y > 1 && y < obj.imHeight
                obj.createDraggableThumbnail()
            else
                return
            end
            
            % Delete if mouse was released during creation
            if ~obj.mouseDown; delete(obj.hThumbnail); end
            
            return;
        end
        
        if obj.mouseDown; return; end
    
        % Get mouse point in figure coordinates and figure size
        mousePoint = obj.Figure.CurrentPoint;
        x = mousePoint(1); y = mousePoint(2);
        
        %figSize = obj.Figure.Position(3:4); 
        %figLoc = [1,1];
        
        panelPos = getpixelposition(obj.Panel, true);
        figSize = panelPos(3:4); % use anel instead of figure!
        figLoc = panelPos(1:2);
        
        % Determine if mouse is over any of the "sensitive" fields
        isOutside = y > figLoc(2)+figSize(2)+10 || ...
                        x > figLoc(1)+figSize(1)+10 || ...
                            y < figLoc(2) || x < figLoc(1);
        
        isTop = y > figLoc(2)+figSize(2) - [30, 65] & y < figLoc(2)+figSize(2);
        isBottom = y > figLoc(2) && y < figLoc(2)+20;

        isRight = x > figLoc(1)+figSize(1) - [20, 80] & x < figLoc(1)+figSize(1);
        isLeft = x > figLoc(1) + [1, 1] & x < figLoc(1) + [20, 130];
        
        isRight = isRight & ~any(isBottom) & ~any(isTop) & ~isOutside;
        isLeft = isLeft & ~any(isBottom) & ~any(isTop) & ~isOutside;
        
        if isfield(obj.uiwidgets, 'Toolbar')
            
            if contains(obj.uiwidgets.Toolbar.Location, 'north')
                isTouch = isTop(1) & ~isOutside;
                isUntouch = ~any(isTop);
            elseif contains(obj.uiwidgets.Toolbar.Location, 'south')
                isTouch = isBottom(1) & ~isOutside;   
                isUntouch = ~any(isBottom);
            else
                isTouch = false;
                isUntouch = false;
            end
            
            if isTouch && strcmp(obj.uiwidgets.Toolbar.Visible, 'off')
                obj.uiwidgets.Toolbar.Visible = 'on';
            elseif isUntouch && strcmp(obj.uiwidgets.Toolbar.Visible, 'on')
                if ~obj.isImageToolbarPinned
                    obj.uiwidgets.Toolbar.Visible = 'off';
                end
            end
        end
        
        if isfield(obj.uiwidgets, 'Taskbar') && ~isempty(obj.uiwidgets.Taskbar)
            isVisible = strcmp(obj.uiwidgets.Taskbar.Visible, 'on');
            if isRight(1) && ~isVisible
                obj.uiwidgets.Taskbar.Visible = 'on';
            elseif ~any(isRight) && isVisible
                obj.uiwidgets.Taskbar.Visible = 'off';
            end
        elseif ~isfield(obj.uiwidgets, 'Taskbar') % Create widget on demand
%             % NB: Commented out when i played around with reparenting
%             if isRight(1)
%                 obj.addTaskbar(true)
%                 obj.uiwidgets.Taskbar.Visible = 'on';
%             end
        end
        
        if isfield(obj.uiwidgets, 'thumbnailSelector') && ~isempty(obj.uiwidgets.thumbnailSelector)
            isVisible = strcmp(obj.uiwidgets.thumbnailSelector.Visible, 'on');
            
            isTouch = isLeft(1);
            isUntouch = ~any(isLeft);
            
            if isTouch && ~isVisible
                obj.uiwidgets.thumbnailSelector.Visible = 'on';
                obj.uiwidgets.thumbNailToggler.Visible = 'on';
            elseif isUntouch && isVisible
                if x > obj.uiwidgets.thumbnailSelector.Position(3) + 35 || ...
                    y < obj.uiwidgets.thumbnailSelector.Position(1)
                    
                    if ~obj.isThumbnailSelectorPinned
                        obj.uiwidgets.thumbnailSelector.Visible = 'off';
                        obj.uiwidgets.thumbNailToggler.Visible = 'off';
                    end
                end
            end
        elseif ~isfield(obj.uiwidgets, 'thumbnailSelector') % Create widget on demand
            if isLeft(1)
                if isa(obj.ImageStack.Data, 'stack.io.fileadapter.Video')
                    return
                end
                
                try
                    obj.openThumbnailSelector(true)
                catch ME
                    if isvalid(obj) 
                        rethrow(ME)
                    else
                        return % obj was deleted during creation
                    end
                end
                
                if isfield(obj.uiwidgets, 'thumbnailSelector')
                    obj.uiwidgets.thumbnailSelector.Visible = 'on';
                    obj.uiwidgets.thumbNailToggler.Visible = 'on';
                end
            end
        end
        
    end
    
    function onMouseScrolled(obj, src, evt)
        obj.mouseScrollCallbackHandler(src, evt)
    end
    
    function onKeyPressed(obj, ~, event)
        
        if ~obj.isMouseInApp; return; end

        if ~isempty(obj.plugins)
            for i = 1:numel(obj.plugins)
                try
                    wasCaptured = obj.plugins(i).pluginHandle.onKeyPress([], event);
                    if wasCaptured; return; end
                catch ME
                    fprintf( [ME.message, '\n'] )
                    % something went wrong, but thats fine?
                end
            end
        end
        
        
        if contains('shift', event.Modifier)
            switch event.Key
                
                case 'f'
                    obj.uiwidgets.thumbnailSelector.changeThumbnailClass('Filter')
                case 'p'
                    obj.uiwidgets.thumbnailSelector.changeThumbnailClass('Projection')
                case 'b'
                    obj.uiwidgets.thumbnailSelector.changeThumbnailClass('Binning')
            end
        end
        
        switch event.Key
            
            case 'alt'
                obj.isAltDown = true;
            
            case 'shift'
                obj.Figure.SelectionType = 'extend';
%                 obj.Figure.Interruptible = 'off';
            
            case {'0', '1', '2', '3', '4'}
                
                if isempty(event.Modifier)
                    switch event.Key
                        case '0'
                            obj.changeChannel('all', 'select')
                        case {'1', '2', '3', '4'}
                            obj.changeChannel(str2double(event.Key), 'select')
                    end
                    
                elseif contains('alt', event.Modifier)
                    switch event.Key
                        case '0'
                            obj.changeChannel('all', 'select')
                        case {'1', '2', '3', '4'}
                            obj.changeChannel(str2double(event.Key), 'toggle')
                    end
                    
                elseif contains('shift', event.Modifier)
                    if isequal(event.Key, '1')
                        obj.setNewImageLimits([1, round(obj.imWidth/2)+10], [1, round(obj.imHeight/2)+10]);
                    elseif isequal(event.Key, '2')
                        obj.setNewImageLimits([round(obj.imWidth/2)-10, obj.imWidth], [1, round(obj.imHeight/2)+10]);
                    elseif isequal(event.Key, '3')
                        obj.setNewImageLimits([1, round(obj.imWidth/2)+10], [round(obj.imHeight/2)-10, obj.imHeight]);
                    elseif isequal(event.Key, '4')
                        obj.setNewImageLimits([round(obj.imWidth/2)-10, obj.imWidth], [round(obj.imHeight/2)-10, obj.imHeight]);
                    elseif isequal(event.Key, '0')
                        obj.setNewImageLimits([0, obj.imWidth], [0, obj.imHeight])
                        set(obj.zoomOutline, 'Visible', 'off')
                    end

% %                 elseif contains('alt', event.Modifier)
% %                     obj.plotOverlay(event.Key)
                end
                
            case '6'
                if all( contains({'shift', 'command'}, event.Modifier))
                    try
                        obj.saveImageToDesktop()
                    catch
                        obj.saveImage()
                    end
                end
                
            case 'u'
                obj.updateImageDisplay()
                
                
%             case {'leftarrow', 'rightarrow'}
            case 'return'
                obj.Figure.UserData.lastKey = 'return';
                uiresume(obj.Figure)
            case 'escape'
                obj.Figure.UserData.lastKey = 'escape';
                uiresume(obj.Figure)
                
            case 'leftarrow'
                if contains( event.Modifier, {'alt', 'ctrl','control'})
                    xLim = get(obj.uiaxes.imdisplay, 'XLim');
                    obj.moveImage([obj.settings.panFactor * diff(xLim), 0])
                elseif contains(event.Modifier, {'shift'})
                    obj.changeFrame(struct('Value', -5), [], 'keypress');
                else
                    obj.changeFrame(struct('Value', -1), [], 'keypress');
                end
            case 'rightarrow'
                if contains( event.Modifier, {'alt', 'ctrl', 'control'})
                    xLim = get(obj.uiaxes.imdisplay, 'XLim');
                    obj.moveImage([-obj.settings.panFactor * diff(xLim), 0])
                elseif contains(event.Modifier, {'shift'})
                    obj.changeFrame(struct('Value', 5), [], 'keypress');
                else
                    obj.changeFrame(struct('Value', 1), [], 'keypress');
                end
            case 'uparrow'
                if contains( event.Modifier, {'alt', 'ctrl', 'control'})
                    yLim = get(obj.uiaxes.imdisplay, 'YLim');
                    obj.moveImage([0, -obj.settings.panFactor * diff(yLim)])
                elseif contains( event.Modifier, 'shift')
                    if strcmp(obj.Figure.Resize, 'off')
                        obj.resizeWindow([], [],'maximize')
                    end
                else
                    if strcmp(obj.Figure.Resize, 'off')
                        obj.resizeWindow([], [], 'grow')
                    end
                end
            case 'downarrow'
                if contains( event.Modifier, {'alt', 'ctrl', 'control'})
                    yLim = get(obj.uiaxes.imdisplay, 'YLim');
                    obj.moveImage([0, obj.settings.panFactor * diff(yLim)])
                else
                    if strcmp(obj.Figure.Resize, 'off')
                        obj.resizeWindow([], [], 'shrink')
                    end
                end
                
                
            case {'z', 'Z'}
                % Todo: Figure out what todo if another app is keeper of
                % the undomanager.
                if contains('command', event.Modifier) && contains('shift', event.Modifier) ...
                        || contains('control', event.Modifier) && contains('shift', event.Modifier)
                    uiundo(obj.Figure, 'execRedo')
                elseif contains('command', event.Modifier) || contains('control', event.Modifier) 
                    uiundo(obj.Figure, 'execUndo')
                end

            case 'n'
                if contains( event.Modifier, 'shift' )
                    if ~isempty(obj.imageDisplayMode.binning) && ...
                        strcmp(obj.imageDisplayMode.binning, 'average')
                        obj.changeImageDisplayMode('binning', 'none')
                    else
                        obj.changeImageDisplayMode('binning', 'average')
                    end

                else
                    obj.changeImageDisplayMode('projection', 'average')
                end
                
            case 'm'
                if contains( event.Modifier, 'shift' )
                    obj.changeImageDisplayMode('projection', 'minimum')
                else
                    obj.changeImageDisplayMode('projection', 'maximum')
                end
                
            case 'b'
                if ~contains('shift', event.Modifier)
                    obj.changeImageDisplayMode('projection', 'average')
                    obj.changeImageDisplayMode('filter', 'clahe', false)
                end
                
            case 'c'
                obj.showBrightnessSlider()

                
            case 'p'
                if ~contains('shift', event.Modifier)
                    if obj.isPlaying
                        obj.isPlaying = false;
                        obj.uiwidgets.playback.switchPlayPauseIcon('play')
                    else
                        obj.uiwidgets.playback.switchPlayPauseIcon('pause')
                        obj.playVideo([],[]);
                    end
                end
                
            case 'backquote'
                if ~isempty(event.Modifier) && isequal(event.Modifier{1}, 'shift')
                    obj.playbackspeed = obj.playbackspeed * 2;
                else
                    obj.playbackspeed = obj.playbackspeed / 2;
                end
            case 'v'
                if contains( event.Modifier, {'command', 'ctrl', 'control'})
                    str = clipboard('paste');
                    strCellArray = strsplit(str, '\n');
                    isFiles = cellfun(@(str) exist(str, 'file'), strCellArray, 'uni', 1);
                    if all(isFiles)
                        obj.openFile(strCellArray)
                    end
                    
                else
                    %obj.imObj.CData = flipud(obj.imObj.CData);
                end
                
            case 'h'
                %obj.imObj.CData = fliplr(obj.imObj.CData);
                
            case 's'

            case 'w' % Assign images to workspace
                % Todo; only assign sub, e.g. by first making a rectangular
                % crop.
                % Todo: Assign selection from imageStack.imageData...
                % assignin('base', 'imviewerData')
                
            case {'+', 'slash', '0'}
                if ispc && strcmp(event.Key, '0')
                    obj.imageZoom('in');
                elseif ~ispc && strcmp(event.Key, '0')
                    % Skip
                else
                    obj.imageZoom('out');
                end
                    
            case {'-', 'hyphen'}
                if ispc
                    obj.imageZoom('out');
                else
                    obj.imageZoom('in');
                end
            case 'q'
%                 set(obj.uiaxes.imdisplay, 'XLim', [1, obj.imWidth], 'YLim', [1, obj.imHeight])
%                 plotZoomRegion(obj, [1, obj.imWidth], [1, obj.imHeight])
                
                % Todo: debug and fix setNewImageLimits. It did not always
                % work, hence the shortcut above.
%                 setNewImageLimits(obj, [1, obj.imWidth], [1, obj.imHeight])
 

            case 'r'

                theta = -90; % CW rotation
                 
                if contains({'control'}, event.Modifier)
                    theta = theta/90;
                end
                
                if contains({'shift'}, event.Modifier)
                    theta = -1*theta;
                end
                    
                obj.imTheta = obj.imTheta + theta;    
                obj.updateImageDisplay();
                
            case 'g'
                
% %                 if isfield(obj.tmpHandles, 'grid')
% %                     delete(obj.tmpHandles.grid)
% %                     obj.tmpHandles = rmfield(obj.tmpHandles, 'grid');
% %                 else
% %                     n = obj.settings.gridSize;
% %                     obj.tmpHandles.grid = tools.plotgrid(obj.uiaxes.imdisplay, n);
% %                 end
                
                
        end

    end
    
    function onKeyReleased(obj, ~, event)
        switch event.Key
            
            case 'shift'
                obj.Figure.SelectionType = 'normal';
%                 obj.Figure.Interruptible = 'on';
            case 'alt'   
                obj.isAltDown = false;
                
        end
        
    end
    
end

methods (Access = protected)
    
    function mouseScrollCallbackHandler(obj, src, event)
        
        if ~obj.isMouseInApp; return; end

        
        % Use the scrollHistory to avoid "glitchy" scrolling. For small
        % movements on a mousepad, scroll values can come in as 0, 1, 1,
        % -1, 1, 1 even if fingers are moving in on direction.
        
        obj.scrollHistory = cat(1, obj.scrollHistory(2:5), event.VerticalScrollCount);
        
        if obj.isAltDown; return; end
        
        if obj.isMouseOnWidget('thumbnailSelector')
            obj.uiwidgets.thumbnailSelector.scroll(src, event)
            %obj.uiwidgets.thumbnailSelector.updateView([], event, 'scroll')
            return
        end
        
        
        switch obj.Figure.SelectionType
            case 'normal'
                obj.changeFrame(src, event, 'mousescroll');
                   
            case 'extend'
                
                scrollFactor = abs(event.VerticalScrollCount )/10.*obj.settings.Interaction.scrollFactor;
                
                if event.VerticalScrollCount > 0 && sum(obj.scrollHistory) > 0 
                    imageZoom(obj, 'in', scrollFactor);
                elseif event.VerticalScrollCount < 0  && sum(obj.scrollHistory) < 0
                    imageZoom(obj, 'out', scrollFactor);
                end
        end
        
    end
    
    function pixelValueStr = getPixelValueAtCoordsAsString(obj, coords)
    %getPixelValueAtCoordsAsString Return pixelvalue at point as string
    %
    %   pixelValueStr = getPixelValueAtCoordsAsString(obj, coords) returns
    %   pixelValueStr, a formatted string with the pixel value at the point
    %   of the given coordinates. 
    
    %   todo: Show value for each color channel..

        pixelValueStr = '';
        
        if isempty(obj.imObj.CData); return; end
            
        x = coords(1); y = coords(2);
        
        val = obj.CurrentImage(y, x, :);
        
        
        if numel(val) > 1; val = mean(val); end

        
        locationStr = sprintf('x=%1d, y=%1d', x, y);
        
        switch obj.ImageStack.DataType
            case {'single', 'double'}
                % Todo: Change precision if data is not between 0 and 1
                pixelValueStr = sprintf('value=%.2f', val);
            otherwise
                pixelValueStr = sprintf('value=%1d', round(val));
        end
        
        pixelValueStr = strjoin({locationStr, pixelValueStr}, ', ');
        
    end
     
    function keyPressFigResume(~, src, event)

        switch event.Key
            case 'return'
                src.UserData.lastKey = 'return';
                uiresume(src)
            case 'esc'
                src.UserData.lastKey = 'esc';
                uiresume(src)
        end
    end
    
% % Window actions / layout updating

    function [figurePosition, axesSize] = initializeFigurePosition(obj)

        screenSize = obj.getCurrentMonitorSize();
        axesSize = obj.initializeAxesSize();
        
        % Figure size is axes size + margins
        pixelMargins = obj.positionInfo.Margin;
        figSize = axesSize + pixelMargins .* 2;
        
        % Determine figure position so that figure is centered on screen
        figLoc = floor( (screenSize(3:4) - figSize) / 2 );
        
        figLoc = figLoc + screenSize(1:2);
        
        figurePosition = [figLoc, figSize];
        
        if nargout == 1
            clear axesSize
        end
        
    end

    function resizePanel(obj, hPanel, ~, mode)
        
        if nargin == 4
            switch mode
                case 'maximize'
                    obj.Panel.UserData.OriginalParent = obj.Panel.Parent;
                    obj.Panel.UserData.OriginalPosition = obj.Panel.Position;
                    obj.Panel.BorderType = 'line';
                    obj.Panel.BorderWidth = 1;
                    obj.Panel.HighlightColor = [0.25,0.25,0.25];
                    
                    hFig = ancestor(obj.Panel, 'figure');
                    
                    if strcmp( obj.mode, 'docked' )
                        newSize = getpixelposition(obj.Panel.Parent.Parent);
                    else
                        newSize = [8,8,hFig.Position(3:4)-14];
                    end
                    
                    panelSizeChangedFcn = obj.Panel.SizeChangedFcn;
                    obj.Panel.SizeChangedFcn = [];
                                       
                    obj.Panel.Parent = hFig;
                    setpixelposition(obj.Panel, newSize)
                    
                    obj.resizePanelContents(obj.Panel, false)

                    % Turn on panel size changed function
                    obj.Panel.SizeChangedFcn = panelSizeChangedFcn;
                    
                    %obj.Panel.Position = [0.025, 0.025, 0.95, 0.95];
                case 'restore'
                    panelSizeChangedFcn = obj.Panel.SizeChangedFcn;
                    obj.Panel.SizeChangedFcn = [];
                    
                    obj.Panel.BorderType = 'none';
                    obj.Panel.Parent = obj.Panel.UserData.OriginalParent;
                    obj.Panel.Position = obj.Panel.UserData.OriginalPosition;
                    
                    obj.resizePanelContents(obj.Panel, false)

                    % Turn on panel size changed function
                    obj.Panel.SizeChangedFcn = panelSizeChangedFcn;
            end
        else
            obj.resizePanelContents(hPanel, false)
        end
        
        
    end
    
    function maximizeWindow(obj, ~, ~)
        
        MP = get(0, 'MonitorPosition');
        xPos = obj.Figure.Position(1);
        yPos = obj.Figure.Position(2);
        
        % Get screenSize for monitor where figure is located.
        for i = 1:size(MP, 1)
            if xPos > MP(i, 1) && xPos < sum(MP(i, [1,3]))
                if yPos > MP(i, 2) && yPos < sum(MP(i, [2,4]))
                    screenSize = MP(i,:);
                    break
                end
            end
        end
        
        set(obj.Figure, 'Resize', 'on')
        
%         jFrame = get(obj.Figure, 'JavaFrame');
%         jWindow = jFrame.getFigurePanelContainer.getTopLevelAncestor;
%         jWindow.setFullScreen(false)
        
        newFigurePos = screenSize;
        obj.Panel.SizeChangedFcn = [];
        
        obj.Panel.Units = 'pixel';
        obj.Figure.Position = newFigurePos;
        
        newPanelPos = obj.Figure.InnerPosition + [10, 10, -20, -20];

        
        obj.Panel.Position = newPanelPos;
        obj.Panel.Units = 'normalized';
        obj.Panel.BorderType = 'etchedin';
        obj.Panel.HighlightColor = [0.1569    0.1569    0.1569]; 
        
        obj.uiaxes.imdisplay.Position = [1,1,newPanelPos(3:4)-2];
        
        obj.uiaxes.textdisplay.Visible = 'off';
    end
    
    function toggleResize(obj, src, ~)
        
        switch src.Tooltip

            case 'Maximize Window'
                
                switch obj.mode
                    case 'standalone'
                        obj.resizeWindow(src, [], 'maximize')
                        
                    case 'docked'
                        obj.resizePanel(obj.Panel, false, 'maximize')
                end

                src.Icon = obj.ICONS.minimize;
                src.Tooltip = 'Restore Window';
                %obj.Figure.Resize = 'on';
            case 'Restore Window'

                switch obj.mode
                    case 'standalone'
                        obj.resizeWindow(src, [], 'restore')
                        obj.resizePanelContents(obj.Panel, 1, 'width') % Call this to make sure all content are size appropriately before figure is made visible. Todo: Should improve this, i.e should be taken care of by callback functions!

                    case 'docked'
                        obj.resizePanel(obj.Panel, false, 'restore')
                        
                end

                src.Icon = obj.ICONS.maximize;
                src.Tooltip = 'Maximize Window';
                %obj.Figure.Resize = 'off';
        end

    end

end

methods (Access = private) % Methods that runs when properties are set
    
    
    function onImageStackSet(obj)
                
        obj.setTempProperties()
        obj.setImageStackSettings()

        if  obj.isConstructed
            obj.setSliderExtremeLimits()
            obj.setSliderLimits()
            obj.updateImage();
            obj.updateImageDisplay();

            if ~all(isnan(obj.DisplayedImage(:)))
                set(obj.hDropbox, 'Visible', 'off')
            end
            
            obj.configureSpatialDownsampling()
        end
        
    end
    
    
    function configureSpatialDownsampling(obj)
        
        if isa(obj.ImageStack, 'nansen.stack.HighResolutionImage')
            
            ind = find(contains( {obj.plugins.pluginName}, 'pointerManager'));
            pif = obj.plugins(ind).pluginHandle;
            
            pif.pointers.zoomIn.zoomFinishedCallback = @(s,e) obj.onDisplayLimitsChanged;
            pif.pointers.zoomOut.zoomFinishedCallback = @(s,e) obj.onDisplayLimitsChanged;

        else
            ind = find(contains( {obj.plugins.pluginName}, 'pointerManager'));
            pif = obj.plugins(ind).pluginHandle;
            pif.pointers.zoomIn.zoomFinishedCallback = [];
            pif.pointers.zoomOut.zoomFinishedCallback = [];
        end
        
    end
    
    function setTempProperties(obj)
        
        obj.imHeight = obj.ImageStack.ImageHeight;
        obj.imWidth = obj.ImageStack.ImageWidth;
        obj.nFrames = obj.ImageStack.NumTimepoints;
        
        obj.currentFrameNo = 1;
        obj.currentChannel = obj.ImageStack.CurrentChannel;


        % Initialize text for textdisplay
        obj.textStrings.Resolution = sprintf('%dx%d pixels', obj.imHeight, obj.imWidth);
        
        obj.stackname = obj.ImageStack.Name;

        
        % Set brightness limits. Will trigger callback to set slider Low
        % and High value.
        %obj.settings.ImageDisplay.imageBrightnessLimits = obj.ImageStack.DataIntensityLimits;
        
        
% %         % If a "blank" stack is opened, need to readjust limits.
% %         if all(obj.settings.ImageDisplay.imageBrightnessLimits == 0)
% %             obj.settings.ImageDisplay.imageBrightnessLimits = [0,1];
% %         end
% %         
% %         if obj.settings.ImageDisplay.imageBrightnessLimits(1) == 1
% %             obj.settings.ImageDisplay.imageBrightnessLimits(1) = 0;
% %         end

        if obj.ImageStack.IsVirtual  
            obj.currentChannel = obj.ImageStack.CurrentChannel;
        end
        
    end
    
    function setImageStackSettings(obj)
        
        S.ImageStack.DataDimensionOrder = '';
        S.ImageStack.PixelSize = [1, 1];
        S.ImageStack.PixelUnits = ["um", "um"];
        S.ImageStack.SampleRate = 1;
        
        obj.settings.ImageStack = S.ImageStack;
    end
    
end

methods (Static)
    
    S = getDefaultSettings()
    
    function [screenSize, screenNum] = getCurrentMonitorSize(hFigure)
    % Todo: Method of nansen.app superclass
        
        persistent titleBarHeight
        if isempty(titleBarHeight)
            if nargin < 1
                f = figure('Menubar', 'none', 'Visible', 'off');
                titleBarHeight = f.OuterPosition(4) - f.Position(4);
                close(f)
            else
                titleBarHeight = hFigure.OuterPosition(4) - hFigure.Position(4);
            end
        end
        
        if nargin < 1
            screenSize = get(0, 'ScreenSize');
            
        else

            figurePosition = hFigure.Position;

            MP = get(0, 'MonitorPosition');
            xPos = figurePosition(1);
            yPos = figurePosition(2) + figurePosition(4);

            % Get screenSize for monitor where figure is located.
            for i = 1:size(MP, 1)
                if xPos >= MP(i, 1) && xPos <= sum(MP(i, [1,3]))
                    if yPos >= MP(i, 2) && yPos <= sum(MP(i, [2,4]))
                        screenSize = MP(i,:);
                        break
                    end
                end
            end
        end
        
        if ismac
            screenSize(4) = screenSize(4) - imviewer.App.MAC_MENUBAR_HEIGHT;
        end
        
        screenSize(4) = screenSize(4) - titleBarHeight;
        
        if nargout == 2
            screenNum = i;
        end
        
    end
    
    function ar = getPanelAspectRatio(h)
    %getPanelAspectRatio Return aspect ratio for a graphical panel/object
    %
    %   ar = getPanelAspectRatio(h)

        oldUnits = h.Units;
        h.Units = 'pixel';
        pixelPosition = h.Position;
        h.Units = oldUnits;

        ar = pixelPosition(3) / pixelPosition(4);

    end 
    
    function ar = getAspectRatio(size)
        ar = size(1) / size(2);
    end
    
    function S = getSettings()
        S = getSettings@clib.hasSettings('imviewer');
    end
    
    function pathStr = getIconPath()
        % Set system dependent absolute path for icons.
        
        %rootDir = fileparts(fileparts(mfilename('fullpath')));
        rootDir = utility.path.getAncestorDir(mfilename('fullpath'), 1);
        pathStr = fullfile(rootDir, 'resources', 'icons');

        %iconPath = @(iconName) fullfile(iconDir, [iconName, '.mat']);
        
    end
    
    function hApp = uiSelectViewer(viewerNames, hFigure)
        
        % Todo: make this method of superclass??
        % INPUTS:
        %   viewerNames : list (cell array) of app names to look for
        %   hFigure : figure handle of figure to ignore (optional)
        %   
        %   
        % Supported names: {'StackViewer', 'Signal Viewer', 'Roi Classifier'}
        
        if nargin < 1
            viewerNames = {'StackViewer', 'imviewer'};
        end
        if nargin < 2
            hFigure = [];
        end
        
        % Find all open figures that has a viewer object.
        openFigures = findall(0, 'Type', 'Figure');
        
        isMatch = contains({openFigures.Name}, viewerNames);
        
        % Dont include self.
        isMatch = isMatch & ~ismember(openFigures, hFigure)';

        if any(isMatch)
            tf = true;
        else
            tf = false;
        end
      
        if ~tf
            msgbox('There are no open viewers to connect to', 'Aborting'); 
            return
        end
    
        
        figInd = find(isMatch);

        % Select figure window from selection dialog
        if sum(isMatch) > 1

            figNames = {openFigures(figInd).Name};
%             figNumbers = [openFigures(figInd).Number];
%             figNumbers = arrayfun(@(n) sprintf('%d:', n), figNumbers, 'uni', 0); 
%             figNames = strcat(figNumbers ,figNames);

            % Open a listbox selection to figure
            [selectedInd, tf] = listdlg(...
                'PromptString', 'Select figure:', ...
                'SelectionMode', 'single', ...
                'ListString', figNames );

            if ~tf; return; end

            figInd = figInd(selectedInd);

        end
        
        hApp = getappdata(openFigures(figInd), 'ViewerObject');
    
    end
    
end

end

