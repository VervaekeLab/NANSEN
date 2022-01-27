classdef manualClassifier < applify.mixin.UserSettings
    
    % Abstract class for manual classification of images or plot segments
    % or a combination of the two. 
    
    
    
properties (Constant, Hidden = true) % Inherited from UserSettings
    USE_DEFAULT_SETTINGS = false        % Ignore settings file
    DEFAULT_SETTINGS = mclassifier.getDefaultSettings
end


properties (Abstract) %(Access = private)

% % %     classificationColors = { [0.174, 0.697, 0.492], ...
% % %                              [0.920, 0.339, 0.378], ...
% % %                              [0.176, 0.374, 0.908] }
% % % 
% % %     classificationLabels = { 'Accepted', 'Rejected', 'Unclear' }
% % % 
% % % 
% % %     guiColors = struct('Background', ones(1,3)*0.2, ...
% % %                        'Foreground', ones(1,3)*0.7 )
             
                                      
    %settings
    classificationColors
    classificationLabels
    guiColors
    
end


% Graphical handles for gui
properties 
    hFigure
    hPanelSettings
    hPanelImage
    hPanelScroller
    hTiledImageAxes
    hMessageBox
end


% Graphical handles for gui that are private
properties (Access = private)
    hScrollbarAxes
    hScrollbar
    hUicontrols
end


% Properties holding ripple data (todo)
properties (Abstract)
    
    dataFilePath            % Filepath to load/save data from
    
    itemSpecs               % Struct array of different specifications per item
    itemImages              % Struct array of different images per item
    itemStats               % Struct array of different stats per item
    itemClassification      % Vector with classification status per item
    
end


% Properties related to selection of "items"
properties
    selectedItem
    displayedItems
    lastSelectedItem
end


properties (Access = public, SetObservable = true)
    mouseMode = ''
    scrollMode = ''
    cursorPosition
    lastMousePress
    lastKeyPress
    
    prevMousePointAx
end


methods
    
    function obj = manualClassifier(varargin)
        
        if ~nargin
            success = obj.uiopenFromFile();
            if ~success; clear obj; return; end
            nvpairs = {};
        else
            nvpairs = obj.parseInputs(varargin{:});
        end
        
        def = struct('numChan', 1, 'tileUnits', 'pixel');
        opt = utility.parsenvpairs(def, [], nvpairs);
        
        obj.loadSettings()
        obj.createFigure()
        
        %Initialization for subclass before gui is completed
        obj.preInitialization()
        
        obj.configurePanels()
        obj.addTiledImageAxes(opt)
        obj.createGuiControls()
        obj.createScrollbar()
        
        obj.hMessageBox = uim.widget.messageBox(obj.hTiledImageAxes.Axes);

        if isempty(obj.itemClassification)
            obj.itemClassification = zeros(size(obj.itemSpecs));
        end
        
        % Plot data
        obj.updateView([], [], 'Initialize')
        obj.setTileCallbacks()

        % Activate mouse moving callback when everything is up and running
        obj.hFigure.WindowButtonMotionFcn = @obj.onMouseMotion;

    end
    
    
    function delete(obj)
        % Todo: Check if there are unsaved changes and let user abort or
        % save changes before quitting.
        
        
        delete(obj.hFigure)
        delete(obj.hTiledImageAxes)
        delete(obj.hScrollbar)
    end

end
    
methods (Access = private, Hidden) % Gui Creation/construction


    % % % Gui creation
    function createFigure(obj)
    %createFigure Create and configure gui figure
    
        % Open figure in full screen size
        screenSize = get(0, 'ScreenSize');
        obj.hFigure = figure('Position', screenSize);
        obj.hFigure.MenuBar = 'none';
        obj.hFigure.Color = obj.guiColors.Background;
        obj.hFigure.NumberTitle = 'off';
        obj.hFigure.Name = 'Manual Classifier';
        obj.hFigure.KeyPressFcn = @obj.keyPress;
        obj.hFigure.WindowButtonDownFcn = @obj.mousePressed;
        obj.hFigure.WindowScrollWheelFcn = @obj.scrollHandler;
        obj.hFigure.CloseRequestFcn = @(s, e) obj.delete;
    end


    function configurePanels(obj)
    %configurePanels Configure gui panels and add axes/controls
    

        % Create panel on top for adding uicontrols
        obj.hPanelSettings = uipanel('Parent', obj.hFigure);

        % Set height of panel and padding
        panelHeight = 50; % pixels
        padxy = [30, 30]; % pixels
        
        padxy = padxy ./ obj.hFigure.Position(3:4);
        panelHeight = panelHeight ./ obj.hFigure.Position(4);

        obj.hPanelSettings.Position = [padxy(1), ...
            1-panelHeight-padxy(2)*0.5, 1-2*padxy(1), panelHeight];
        obj.hPanelSettings.BorderType = 'none';
        obj.hPanelSettings.BackgroundColor = obj.guiColors.Background;

        annotation( obj.hFigure, 'line', [padxy(1) 1-padxy(1)], ...
            ones(1,2)*obj.hPanelSettings.Position(2)-0.005, ...
            'Color', ones(1,3)*0.5)


        % Create Image Panel for the tiled image montage
        obj.hPanelImage = uipanel('Parent', obj.hFigure);
        obj.hPanelImage.Position = [padxy(1),  padxy(2), ...
            1-2*padxy(1), obj.hPanelSettings.Position(2) - 2*padxy(2)];
        
        
        obj.hPanelImage.BorderType = 'none';
        obj.hPanelImage.BackgroundColor = obj.guiColors.Background;
    
        
        % Create a panel for a scrollbar on the right side. (Interestingly
        % parenting the scrollbar axes to this panel instead of parenting
        % it to the figure makes the scroller itself much more responsive
        % to the mouse down and mousemove callbacks
        imPanelPos = obj.hPanelImage.Position;
        obj.hPanelScroller = uipanel('Parent', obj.hFigure);
        obj.hPanelScroller.Position = [sum(imPanelPos([1,3]))+0.005, imPanelPos(2), 0.0075, imPanelPos(4)];
        obj.hPanelScroller.BorderType = 'none';
        obj.hPanelScroller.BackgroundColor = obj.guiColors.Background;
        uistack(obj.hPanelScroller, 'top')
    end

      
    % Adapted to non-square images
    function addTiledImageAxes(obj, varargin)
    %addTiledImageAxes Add a tiledImageAxes object. This is the "plotter"
        
        def = struct('numChan', 1, 'tileUnits', 'pixel');
        opt = utility.parsenvpairs(def, [], varargin);
    
        % Get aspect ratio of the panel that will hold the tiledImageAxes
        panelPixelPosition = getpixelposition(obj.hPanelImage);
        panelAspectRatio = panelPixelPosition(3) / panelPixelPosition(4);
        
        
        imSize = strsplit(obj.settings.ImageSize, 'x');
        imSize = str2double(imSize);
        
        imageAspectRatio = imSize(2) ./ imSize(1);
        
        % Determine possible grid sizes based on panel aspect ratio
        nRows = 2:15;
        nCols = round( nRows .* panelAspectRatio ./ imageAspectRatio);

        opts = arrayfun(@(i) sprintf('%dx%d', nRows(i), nCols(i)), 1:numel(nRows), 'uni', 0);
        obj.settings_.GridSize_ = opts;

        
        % Get grid size for initialization based on settings
        oldGridSize = strsplit(obj.settings.GridSize, 'x');
        oldGridSize = str2double(oldGridSize);
        [~, closestMatch] = min(abs(nRows - oldGridSize(1))); 
        obj.settings_.GridSize = obj.settings.GridSize_{closestMatch};
        newGridSize = [nRows(closestMatch), nCols(closestMatch)];

        imageSize = strsplit(obj.settings.ImageSize, 'x');
        imageSize = str2double(imageSize);
        
        % Create a Tiled Image Axes Object in the image panel.
        tmpH = uim.graphics.tiledImageAxes(obj.hPanelImage, 'gridSize', newGridSize, ...
            'imageSize', imageSize, 'numChan', opt.numChan, 'tileUnits', opt.tileUnits);
        obj.hTiledImageAxes = tmpH;
        
        obj.setTileCallbacks()

        tmpHAX = obj.hTiledImageAxes.Axes;
        tmpHAX.Position = [0.01,0.01,0.98,0.98];

    end
    
    
    function createGuiControls(obj)  
    %createGuiControls Create Gui Controls on the top panel
    
        % Add settings controls to the top panel
        textbox = gobjects(0,1);
        inputbox = gobjects(0,1);
        buttons = gobjects(0,1);

        
        % Some sizes in normalized units.
        xPos = linspace(0.005, 0.9, 10);
        uicSize = [0.08, 0.4];
        btnSize = [0.08, 0.56];
        yPosTxt = 0.7;
        yPosPop = 0.2;
        yPosBtn = 0.11;

        i=0;

        % Create a textbox to label classification dropdown menu
        i = i+1;
        textbox(end+1) = uicontrol(obj.hPanelSettings, 'style', 'text');
        textbox(end).String = 'Classification:';
        textbox(end).Units = 'normalized';
        textbox(end).Position = [xPos(i)+0.003, yPosTxt, uicSize];
        textbox(end).Tag = '';

        % Create classification dropdown menu
        numbers = 1:numel(obj.classificationLabels);
        popupLabels = arrayfun(@(j) sprintf('(%d) %s', j, obj.classificationLabels{j}), numbers, 'uni', 0);
        popupLabels = cat(2, '(0) Cycle', popupLabels);

        inputbox(end+1) = uicontrol(obj.hPanelSettings, 'style', 'popupmenu');
        inputbox(end).String = popupLabels;
        inputbox(end).Value = 1;
        inputbox(end).Units = 'normalized';
        inputbox(end).Position = [xPos(i), yPosPop, uicSize];
        inputbox(end).HorizontalAlignment = 'left';
        inputbox(end).Tag = 'SelectionMode';
        inputbox(end).TooltipString = 'Press number to switch selection';
        inputbox(end).Callback = @(src, event) obj.removeFocusFromControl(src);
        
        
        % Create a textbox to label show selection dropdown menu
        i = i+1;
        textbox(end+1) = uicontrol(obj.hPanelSettings, 'style', 'text');
        textbox(end).String = 'Show:';
        textbox(end).Units = 'normalized';
        textbox(end).Position = [xPos(i)+0.003, yPosTxt, uicSize];
        textbox(end).Tag = '';
        
        
        % Create show selection dropdown menu
        N = numel(obj.classificationLabels);
        popupLabels = arrayfun(@(j) sprintf('(%d) %s', j, obj.classificationLabels{j}), 1:N, 'uni', 0);
        popupLabels = cat(2, '(0) Unclassified', popupLabels, sprintf('(%d) All', N+1) );

        inputbox(end+1) = uicontrol(obj.hPanelSettings, 'style', 'popupmenu');
        inputbox(end).String = popupLabels;
        inputbox(end).Value = N+2;
        inputbox(end).Units = 'normalized';
        inputbox(end).Position = [xPos(i), yPosPop, uicSize];
        inputbox(end).HorizontalAlignment = 'left';
        inputbox(end).Tag = 'SelectionShow';
        inputbox(end).Callback = {@obj.updateView, 'change selection'};
        inputbox(end).TooltipString = 'Press shift+number to switch selection';
        
        if ~isempty(obj.itemImages)
        % Create a textbox to label image selection dropdown menu
        i = i+1;
        textbox(end+1) = uicontrol(obj.hPanelSettings, 'style', 'text');
        textbox(end).String = 'Image Selection:';
        textbox(end).Units = 'normalized';
        textbox(end).Position = [xPos(i)+0.003, yPosTxt, uicSize];
        textbox(end).Tag = '';
        
        
        % Create image selection dropdown menu
        
        imageNames = fieldnames(obj.itemImages);
        numbers = 1:numel(imageNames);
        popupLabels = arrayfun(@(j) sprintf('(%d) %s', j, imageNames{j}), numbers, 'uni', 0);

        inputbox(end+1) = uicontrol(obj.hPanelSettings, 'style', 'popupmenu');
        inputbox(end).String = popupLabels;
        inputbox(end).Value = 1;
        inputbox(end).Units = 'normalized';
        inputbox(end).Position = [xPos(i), yPosPop, uicSize];
        inputbox(end).HorizontalAlignment = 'left';
        inputbox(end).Tag = 'SelectionImage';
        inputbox(end).Callback = @(src, event) obj.changeImageType;
        inputbox(end).TooltipString = 'Press cmd+number to switch selection';
        end
        
        
        if ~isempty(obj.itemStats)
        % Create a textbox to label variable sorting selection dropdown menu
        i = i+1;
        textbox(end+1) = uicontrol(obj.hPanelSettings, 'style', 'text');
        textbox(end).String = 'Sort By Variable:';
        textbox(end).Units = 'normalized';
        textbox(end).Position = [xPos(i)+0.003, yPosTxt, uicSize];
        textbox(end).Tag = '';
        
        
        % Create variable sorting selection dropdown menu
        
        varNames = fieldnames(obj.itemStats);
%         numbers = 1:numel(imageNames);
        popupLabels = varNames; %arrayfun(@(j) sprintf('(%d) %s', j, imageNames{j}), numbers, 'uni', 0);
        popupLabels = cat(1, '<none>', popupLabels);

        inputbox(end+1) = uicontrol(obj.hPanelSettings, 'style', 'popupmenu');
        inputbox(end).String = popupLabels;
        inputbox(end).Value = 1;
        inputbox(end).Units = 'normalized';
        inputbox(end).Position = [xPos(i), yPosPop, uicSize];
        inputbox(end).HorizontalAlignment = 'left';
        inputbox(end).Tag = 'VariableSelector';
        inputbox(end).Callback = {@obj.updateView, 'change sort order'};
%         inputbox(end).TooltipString = '';
        end
        
        
        i = i+1;
        % Create a textbox to label grid size selection dropdown menu
        textbox(end+1) = uicontrol(obj.hPanelSettings, 'style', 'text');
        textbox(end).String = 'Select grid-size:';
        textbox(end).Units = 'normalized';
        textbox(end).Position = [xPos(i)+0.003, yPosTxt, uicSize];
        textbox(end).HorizontalAlignment = 'left';
        textbox(end).Tag = 'GridSize';

        % Create grid size selection dropdown menu
        inputbox(end+1) = uicontrol(obj.hPanelSettings, 'style', 'popupmenu');
        inputbox(end).String = obj.settings.GridSize_;
        inputbox(end).Value = find(contains(obj.settings.GridSize_, obj.settings.GridSize));
        inputbox(end).Units = 'normalized';
        inputbox(end).Position = [xPos(i), yPosPop, uicSize];
        inputbox(end).HorizontalAlignment = 'left';
        inputbox(end).Tag = 'Set GridSize';
        inputbox(end).Callback = {@obj.settingsValueChange 'GridSize'};

        i = i+1;
        % Create a textbox to label image size selection dropdown menu
        textbox(end+1) = uicontrol(obj.hPanelSettings, 'style', 'text');
        textbox(end).String = 'Select image-size:';
        textbox(end).Units = 'normalized';
        textbox(end).Position = [xPos(i)+0.003, yPosTxt, uicSize];
        textbox(end).HorizontalAlignment = 'left';
        textbox(end).Tag = 'ImageSize';

        % Create image size selection dropdown menu
        inputbox(end+1) = uicontrol(obj.hPanelSettings, 'style', 'popupmenu');
        inputbox(end).String = obj.settings.ImageSize_;
        inputbox(end).Value = find(contains(obj.settings.ImageSize_, obj.settings.ImageSize));
        inputbox(end).Units = 'normalized';
        inputbox(end).Position = [xPos(i), yPosPop, uicSize];
        inputbox(end).HorizontalAlignment = 'left';
        inputbox(end).Tag = 'Set ImageSize';
        inputbox(end).Callback = {@obj.settingsValueChange, 'ImageSize'};

        set(textbox, 'BackgroundColor', obj.guiColors.Background)
        set(textbox, 'ForegroundColor', obj.guiColors.Foreground)
        set(textbox, 'HorizontalAlignment', 'left')
        
        
        i = i+1;
        buttons(end+1) = uicontrol(obj.hPanelSettings, 'style', 'togglebutton');
        buttons(end).String = 'Show/Hide Lines';
        buttons(end).Units = 'normalized';
        buttons(end).Position = [xPos(i), yPosBtn, btnSize];
        buttons(end).Callback = @obj.toggleShowOutlines;
        buttons(end).Tag = 'Show Outline Button';
        buttons(end).TooltipString = 'Press shift+s to switch visibility mode';


        i = i+1;
        buttons(end+1) = uicontrol(obj.hPanelSettings, 'style', 'pushbutton');
        buttons(end).String = 'Settings';
        buttons(end).Units = 'normalized';
        buttons(end).Position = [xPos(i), yPosBtn, btnSize];
        buttons(end).Callback = @(src, event) obj.editSettings;

        i = i+1;
        buttons(end+1) = uicontrol(obj.hPanelSettings, 'style', 'pushbutton');
        buttons(end).String = 'Save Classification';
        buttons(end).Units = 'normalized';
        buttons(end).Position = [xPos(i), yPosBtn, btnSize];
        buttons(end).Callback = @obj.saveClassification;
        buttons(end).TooltipString = 'Press control+s to save classification';

        i = i+1;
        buttons(end+1) = uicontrol(obj.hPanelSettings, 'style', 'pushbutton');
        buttons(end).String = 'Help';
        buttons(end).Units = 'normalized';
        buttons(end).Position = [xPos(i), yPosBtn, btnSize];
        
    end


    function createScrollbar(obj)
    %createScrollbar Create scrollbar and add callback
    
        opts = {'Orientation', 'Vertical', ...
                'Maximum', 100, ...
                'VisibleAmount', 50};
        
        obj.hScrollbar = uim.widget.scrollerBar(obj.hPanelScroller, opts{:});
%         obj.hScrollbar.Callback = @obj.scrollValueChange;
        obj.hScrollbar.StopMoveCallback = @obj.stopScrollbarMove;
        obj.hScrollbar.showTrack()
        
    end
    
    
    function stopScrollbarMove(obj, src, deltaY)
    %stopScrollbarMove Update the view when scroller stops moving
        obj.updateView(struct('deltaY', deltaY), [], 'scrollbar');
        
    end
    
    
    function updateScrollbar(obj, candidates)
    %updateScrollbar Update scrollbar position if view was changed
    
        % Todo: checkout timerseriesPlot for positioning of bar calculating
        % new value
        
        if nargin < 2
            candidates = getCandidatesForUpdatedView(obj);

            roiOrder = obj.getItemOrder();
            candidates = intersect(roiOrder, candidates, 'stable');
        end
        
        nTiles = obj.hTiledImageAxes.nTiles;
        barLength = nTiles ./ numel(candidates) * 100;
        barLength = min( [barLength, 100] );
        
        VisibleAmount = barLength;
        obj.hScrollbar.VisibleAmount = VisibleAmount;
        
        
        if ~isempty(obj.displayedItems)
            barInit = find( candidates ==  obj.displayedItems(1), 1, 'first'); 
            barInit = (barInit-1) ./ numel(candidates);
        else
            barInit = 0;
        end

        obj.hScrollbar.Value = barInit * 100;


% %         yData = barInit + [0,1,1,0] * barLength;
% % 
% %         set(obj.hScrollbar(2), 'YData', yData)
% %         
% %         % Move the tooltip on the scroller if it is present
% %         if ~isa(obj.hScrollbar(2).UserData, 'struct')
% %             obj.hScrollbar(2).UserData.Position(2) = 1-mean(yData);
% %         end

    end
    
    
    % % % Keyboard and mouse callbacks
    function keyPress(obj, src, event)

        switch event.Key
            case 'uparrow'
                obj.updateView([], [], 'previous')
            case 'downarrow'
                obj.updateView([], [], 'next')
            case 'leftarrow'
                obj.changeSelectedItem('prev')
            case 'rightarrow'
                obj.changeSelectedItem('next')
                
            % Numeric keypress should change the selected value in one of 3
            % popupmenus and make necessary updates. If a roi is selected
            % during numeric keypress, that roi will be classified.
            case {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9'}
                
                val = str2double(event.Key) + 1;

                if contains(event.Modifier, 'shift')
                    hPopup = findobj(obj.hPanelSettings, 'Tag', 'SelectionShow');
                elseif any(contains({'command',  'control'}, event.Modifier))
                    hPopup = findobj(obj.hPanelSettings, 'Tag', 'SelectionImage');
                    
                    val = val-1;
                    if val == 0 || isempty(hPopup); return; end
                else % If roi is selected, classify it, otherwise, change mouse click classification behavior
                    obj.setMouseMode(src, event, 'Select') % Exit roiTools if numbers are used
                    
%                     if ~isempty(obj.selectedItem)
%                         obj.classifyRoi(obj.selectedItem, str2double(event.Key))
%                         obj.changeSelectedItem('next')
%                         return
%                     end
                    
                    hPopup = findobj(obj.hPanelSettings, 'Tag', 'SelectionMode');
                end
                
                % Change selected item in the popup by changing the Value.
                if val <= numel(hPopup.String) 
                    hPopup.Value = val;
                end
                
                % Invoke the new selection from the popup menu.
                if contains(event.Modifier, 'shift')                 
                    obj.updateView([], [], 'change selection');
                elseif any(contains({'command',  'control'}, event.Modifier))
                    obj.changeImageType()
                end

                return % Dont want to pass this on to roiTools/roimanager
                
%             case 'c'
%                 hPopup = findobj(obj.hPanelSettings, 'Tag', 'ClickMode');
%                 hPopup.Value = 1;
%             case 'e'
%                 hPopup = findobj(obj.hPanelSettings, 'Tag', 'ClickMode');
%                 hPopup.Value = 2;
            case 's'
                if contains(event.Modifier, 'shift') 
                    btnH = findobj(obj.hFigure, 'Tag', 'Show Outline Button');
                    btnH.Value = ~btnH.Value;
                    obj.toggleShowOutlines(btnH, [])
                elseif contains(event.Modifier, {'command', 'control'})
                    obj.saveClassification()
                else
                    obj.setMouseMode(src, event, 'Select')
                end
                
            case 'space'
                btnH = findobj(obj.hFigure, 'Tag', 'Show Outline Button');
                btnH.Value = ~btnH.Value;
                obj.toggleShowOutlines(btnH, [])
                
                
%             case 'o'
%                 hPopup = findobj(obj.hPanelSettings, 'Tag', 'ClickMode');
%                 hPopup.Value = 3;


            case 'p'
                if contains(event.Modifier, 'command')
                   im = frame2im(getframe(obj.hTiledImageAxes.Axes));
                   filename = strcat( datestr(now, 'yyyy_mm_dd_HHMMSS'), '_printscreen.tif');
                   imwrite(im, fullfile(getDesktop, filename), 'TIFF')
                end

            otherwise
                % Do nothing.

        end
        

        
        
        
    end
    
    
    function scrollHandler(obj, src, event)
    %scrollHandler Take care of scrolling input to figure.
    
        if isempty(obj.selectedItem)
            obj.hScrollbar.moveScrollbar(src, event)
            obj.updateView(src, event, 'scroll')
        else
% %             if ~isempty(obj.hRoimanager) && isvalid(obj.hRoimanager)
% %                 obj.hRoimanager.changeFrame(src, event, 'mousescroll')
% %             end
        end
        
    end
    
    
    function onMouseMotion(obj, src, event)

        newMousePointAx = obj.hTiledImageAxes.Axes.CurrentPoint(1, 1:2);
        obj.cursorPosition = newMousePointAx;
       
        hTmp = hittest(obj.hFigure);
       %obj.hScrollbar.hittest(hTmp)
        
    end
    
    
    function mousePressed(obj, src, event, tileNum)
        
        % Assign nan to variable if it is not given in function call
        if nargin < 4; tileNum = nan; end
        
        % Get Mouse Point in the axes coordinates.
        newMousePointAx = get(obj.hTiledImageAxes.Axes, 'CurrentPoint');
        newMousePointAx = newMousePointAx(1, 1:2);
%         obj.lastMousePress = newMousePointAx;
        
        
%         if ~isempty(obj.roiTools) && obj.roiTools.captureClicks && ~isnan(tileNum)
% 
%             switch obj.roiTools.mouseMode
%                 case {'magicwand', 'circle', 'Autodetect', 'CircleSelect', 'CrosshairSelect'}
%                     
%                     currentRoiInd = obj.displayedItems(tileNum);
%                     roiData = obj.prepareRoiData(currentRoiInd, tileNum);
%                     
%                     modifiedRoi = obj.roiTools.requestRoi(src, event, roiData);
%                     
%                     if ~isempty(modifiedRoi)
%                         obj.updateRois(modifiedRoi, currentRoiInd, 'reshape')
%                     end
%                     
%                 case {'polydraw'}
%                     
%                     
%             end
% 
%         end
%         
%         if isnan(tileNum) && ~isempty(obj.selectedItem) 
%             obj.changeSelectedItem('unselect')
%         end

        
    end
    
    
    function setMouseMode(obj, ~, event, newMouseMode)
        
        if ~exist('newMouseMode', 'var') || isempty(newMouseMode) % External change
            obj.mouseMode = event.AffectedObject.mouseMode;
        else
            obj.mouseMode = newMouseMode;
        end
    end
    
    
end


methods (Abstract, Access = protected)
    
    preInitialization(obj)
    
    nvpairs = parseInputs(obj, varargin)
    
    updateTile(obj)
    
    onSelectedItemChanged(obj)
    
end


methods (Access = protected)
        
    function setTileCallbacks(obj)
        for i = 1:obj.hTiledImageAxes.nTiles
            obj.hTiledImageAxes.tileCallbackFcn({@obj.mouseClickInTile, i}, i)
            obj.hTiledImageAxes.tilePlotButtonDownFcn({@obj.mouseClickInRoi, i}, i)
        end
    end
    
    function candidates = getCandidatesForUpdatedView(obj)
    %getCandidatesForUpdatedView Get indices for candidates that pass filter
    %
    %   Get all candidates that are passing the current selection in the
    %   show dropdown menu. 
    %
    %   Dropdown selection has n+2 modes where 1->n is the available
    %   classifications, 0 is unclassified and n+1 is to show all.
    
        % Get show mode
        hPopup = findobj(obj.hPanelSettings, 'Tag', 'SelectionShow');
        class = hPopup.Value - 1;
        
        % Get candidates based on the selection in the show classification
        N = numel(obj.classificationLabels);
        if class > N % (One extra selection; "All")
            candidates = 1:numel(obj.itemClassification);
        else
            candidates = find(obj.itemClassification == class);
        end
        
    end
    
end

methods


    % % % Callbacks for gui controls
    
    function numberSize = stringSizeToNumbers(~, stringSize)
    %stringSizeToNumbers Convert a string formatted size to numbers    
    % 
    %   Example: '100x100' -> [100, 100]
    
        stringSizeSplit = strsplit(stringSize, 'x');
        numberSize = str2double(stringSizeSplit);
        
    end
    
    function stringSize = numbersToStringSize(~, numberSize)
    %numbersToStringSize Convert numbers to a string formatted size
    %
    %   Example: [100, 100] -> '100x100'
    
        stringSize = sprintf('%dx%d', numberSize(1), numberSize(2));
    end


    function settingsValueChange(obj, src, ~, settingsName)
    %settingsValueChange Apply changes made to settings

        switch settingsName

            case 'GridSize'
                % Get new gridsize from popup selector
                newGridSize = src.String{src.Value};
                
                % Note: Changing the settings property will invoke the
                % onSettingsChanged callback.
                obj.settings.GridSize = newGridSize;
                
                if ~isa(src, 'struct')
                    obj.removeFocusFromControl(src)
                end
                
            case 'ImageSize'
                
                newImageSize = src.String{src.Value};
                newImageSize = obj.stringSizeToNumbers(newImageSize);

                obj.settings.ImageSize = src.String{src.Value};
                
                obj.removeFocusFromControl(src)

        end

    end

    
    % % % Method to take care of changes to gridsize
    
    function changeGridSize(obj, newGridSize)
    %changeGridSize Set new grid size and apply all required changes
    
        obj.hTiledImageAxes.gridSize = newGridSize;
        obj.updateView([], [], 'change gridsize')
        
        % This needs to be set after updating the view.
        obj.setTileCallbacks()
        
    end
    
    
    % % % Methods for updating tile(s) with data
    
    function updateView(obj, src, event, mode)

        
        % Reset selection of roi if any rois are selected.
% %         if ~isempty(obj.selectedItem)
% %             obj.changeSelectedItem('unselect', [])
% %         end
        
        nTiles = min( [obj.hTiledImageAxes.nTiles, numel(obj.itemClassification)] );

        
%         % Remove rejected rois.
%         if obj.settings.DeleteRejectedRoisOnRefresh
%             % Do for following modes:
%             if contains(mode, {'next', 'previous', 'change selection', 'change sort order', 'scroll'})
%                 indToRemove = find(obj.itemClassification == 2);
%                 obj.updateRois([], indToRemove, 'remove') %#ok<FNDSB>
%             end
%         end
        
        % Find the first and last roi number in the current view.
        if isempty(obj.displayedItems)
            firstIndex = 1;
            lastIndex = 1;
        else
            firstIndex = obj.displayedItems(1);
            lastIndex = obj.displayedItems(end);
        end
    
        
        % Get indices of all candidate items. 
        candidates = getCandidatesForUpdatedView(obj);
        
        
        % Get order of rois. Update candidates according to current sorting.
        roiOrder = obj.getItemOrder();
        candidates = intersect(roiOrder, candidates, 'stable');

        
        if isempty(candidates)
            mode = 'skip';
        end
        
        
        switch lower(mode)
            case 'initialize'
                newIndices = candidates( 1:nTiles );
                
            case {'change gridsize', 'refresh'}
                firstCandidate = find( candidates == firstIndex );
                candidatesLeft = candidates(firstCandidate:end);
                
                nCandidates = min([nTiles,  numel(candidatesLeft)]);
                newIndices = candidatesLeft(1:nCandidates);
                            
            case 'next'
                if lastIndex==candidates(end); return; end

                currentCandidate = find( candidates == lastIndex );
                if isempty(currentCandidate); currentCandidate = 0; end

                candidatesLeft = candidates(currentCandidate+1:end);
                
                nCandidates = min([nTiles,  numel(candidatesLeft)]);
                newIndices = candidatesLeft(1:nCandidates);
                                
            case 'previous'
                if firstIndex==candidates(1); return; end
                    
                currentCandidate = find( candidates == firstIndex );
                
                % Subtract number of tile from currentCancidate to get new
                % firstCandidate.
                firstCandidate = max( [1, currentCandidate - nTiles] );
                candidatesLeft = candidates(firstCandidate:end);

                nCandidates = min([nTiles,  numel(candidatesLeft)]);
                newIndices = candidatesLeft(1:nCandidates);

            case 'change selection'
                
                if numel(candidates) < nTiles
                    newIndices = candidates;
                else
                    newIndices = candidates(1:nTiles);
                end
                
            case 'change sort order'
                newIndices = candidates( 1:nTiles );
                
            case 'skip'
                newIndices = [];
                
            case 'scrollbar'
                deltaY = src.deltaY;

                % DeltaY is a fractional change of the scrollbar position.
                % It follows the the change of tiles is the fractional
                % change of all the tiles...
                n = numel(candidates) * deltaY;
                
                % Adjust n so that tiles are not shifted along rows
                n = round(n / obj.hTiledImageAxes.nCols) .* obj.hTiledImageAxes.nCols;
                
                % Find new indices to show. Make sure they are within range
                % of possible candidates.
                firstCandidate = find( candidates == firstIndex ) + n;
                firstCandidate = max( [1, firstCandidate] );
                
                candidatesLeft = candidates(firstCandidate:end);

                nCandidates = min([nTiles,  numel(candidatesLeft)]);
                newIndices = candidatesLeft(1:nCandidates);
                
            case 'scroll'
                
                % Determine how many tiles to move across
                if ismac % Mac touchpad is too sensitive...
                    i = ceil(event.VerticalScrollCount/5);
                else
                    i = ceil(event.VerticalScrollCount);
                end
                n = obj.hTiledImageAxes.nCols * i;
                
                % If already at the beginning or end of the list, and asked
                % to move further, abort and skip the update.
                if i < 0 && firstIndex == 1; return; end
                if i > 0 && lastIndex==candidates(end); return; end
              
                % Among the current candidate selection, which index is
                % being displayed as first in the image tiles?
                currentCandidate = find( candidates == firstIndex );
                
                % Count how many candidates are left in the list after this
                % one.
                candidatesLeft = candidates(currentCandidate:end);

                % Make sure to stop at either beginning or end of candidate
                % list.
                if currentCandidate+n < 1
                    candidatesLeft = candidates(1:end);
                elseif currentCandidate+n >= numel(candidatesLeft) + obj.hTiledImageAxes.nCols
                    candidatesLeft = candidates(end-nTiles:end);
                else
                    candidatesLeft = candidates(currentCandidate+n:end);
                end
                
                % Assign the list of new candidates to display
                nCandidates = min([nTiles,  numel(candidatesLeft)]);
                newIndices = candidatesLeft(1:nCandidates);
                
        end

        if ~isempty(newIndices) && newIndices(1) < 1
            newIndices = 1:nTiles;
        end

        if ~isempty(newIndices) && newIndices(end) > numel(obj.itemSpecs)
            newIndices = (1:nTiles) - nTiles + numel(obj.itemSpecs);
        end

        
        obj.displayedItems = newIndices;
        
        imageSelection = getCurrentImageSelection(obj);
        
        
        obj.hTiledImageAxes.resetAxes()
        
        
        numTilesToUpdate = numel(obj.displayedItems);
        obj.updateTile(obj.displayedItems, 1:numTilesToUpdate)
        
        
        if numTilesToUpdate < nTiles
            obj.hTiledImageAxes.resetTile(numTilesToUpdate+1:nTiles)
        end


        updateScrollbar(obj, candidates)
        
        if isa(src, 'matlab.ui.control.UIControl')
            obj.removeFocusFromControl(src)
        end
        

    end
    
    
    function changeImageType(obj)
    %changeImageType Update the image type in each tiled based on popup
    
        nTiles = min( [obj.hTiledImageAxes.nTiles, numel(obj.itemClassification)] );

        %imageSelection = getCurrentImageSelection(obj);
        
        numTilesToUpdate = numel(obj.displayedItems);
        obj.updateTile(obj.displayedItems, 1:numTilesToUpdate)
        
        if numTilesToUpdate < nTiles
            obj.hTiledImageAxes.resetTile(numTilesToUpdate+1:nTiles)
        end
        
    end
    
    
    function updateTileColor(obj, tileNum)

        colors = obj.classificationColors;
        
        tileClsf = obj.itemClassification(obj.displayedItems);

        for i = tileNum
            cInd = tileClsf(i);

            if cInd == 0
                obj.hTiledImageAxes.setTileOutlineColor(i)
            else
                obj.hTiledImageAxes.setTileOutlineColor(i, colors{cInd})
            end
            
        end

        tileNum = find(tileClsf~=0);
        obj.hTiledImageAxes.setTileTransparency(tileNum, obj.settings.TileAlpha) %#ok<FNDSB>

    end

    
    function toggleShowOutlines(obj, src, ~)
        
       if src.Value
            obj.hTiledImageAxes.setPlotVisibility('on')
       else
            obj.hTiledImageAxes.setPlotVisibility('off')
       end
       
    end
    
    
    % % % Get current selections/indices based on states of popup menus.

    function roiOrder = getItemOrder(obj)
        
        
        if ~isempty(obj.itemStats)
            hPopup = findobj(obj.hPanelSettings, 'Tag', 'VariableSelector');
            sortVariable = hPopup.String{hPopup.Value};
        else
            sortVariable = '<none>';
        end
        
        
        switch sortVariable
            case '<none>'
                roiOrder = 1:numel(obj.itemSpecs);
            otherwise
                val = [obj.itemStats.(sortVariable)];
                [~, roiOrder] = sort(val, 'descend', 'MissingPlacement', 'last');
        end
        
        
        
    end
    

    function imageSelection = getCurrentImageSelection(obj)
    %getCurrentImageSelection Get image type selection from popup menu 
        
        if isempty(obj.itemImages)
            imageSelection = 'default'; 
        else
            imageAlternatives = fieldnames(obj.itemImages);
            hSelectionPopup = findobj(obj.hFigure, 'Tag', 'SelectionImage');
            if hSelectionPopup.Value <= numel(imageAlternatives)
                imageSelection = imageAlternatives{hSelectionPopup.Value};
            else
                imageSelection = 'Current Frame';
            end
        end
        
    end
    
    
    % Todo: Make protected
    function roiImage = getRoiImage(obj, roiInd, varargin)
    % getRoiImage Get images for all specified rois based on image selection
        
        def = struct('Resize', false);
        opt = utility.parsenvpairs(def, [], varargin{:});
    
        imageSelection = getCurrentImageSelection(obj);
        imageSize = obj.hTiledImageAxes.imageSize;
        
        try
            if strcmp(imageSelection, 'default')
                roiImage = cat(3, obj.roiArray(roiInd).enhancedImage);
            else
                roiImage = cat(3, obj.itemImages(roiInd).(imageSelection));
            end
            
        catch ME % Todo: Might be other errors than images not being same sizes.
            
            if strcmp(imageSelection, 'default')
                roiImage = arrayfun(@(i) obj.roiArray(i).enhancedImage, roiInd, 'uni', 0);
            else
                roiImage = arrayfun(@(i) obj.itemImages(i).(imageSelection), roiInd, 'uni', 0);
            end
            
        end

        if opt.Resize
            if isa(roiImage, 'numeric')
                roiImage = imresize(roiImage, imageSize);
            elseif isa(roiImage, 'cell')
                roiImage = cellfun(@(im) imresize(im, imageSize), roiImage, 'uni', 0);
                roiImage = cat(3, roiImage{:});
            end
        end
        
    end


    
    % % % Methods for making changes...
    
    function classifyRoi(obj, roiInd, classNum)
        
        obj.itemClassification(roiInd) = classNum;
        
        for i = 1:numel(roiInd)
            tileNum = find(obj.displayedItems==roiInd(i));
            if ~isempty(tileNum)
                obj.updateTileColor(tileNum)
            end
        end
        
        
        % Todo: move to updateRoi Property...
        % NB: This is currently only one way! Changes in RM does not update
        % in the classifier.
        

    end
    
    
    function removeRois(obj, indToRemove)
        
        if isempty(indToRemove); return; end
        
        obj.itemClassification(indToRemove) = [];
        
        if ~isempty(obj.itemImages)
            obj.itemImages(indToRemove) = [];
        end
        
        if ~isempty(obj.itemStats)
            obj.itemStats(indToRemove) = [];
        end
        
        if ~isempty(obj.selectedItem)
            if any(indToRemove == obj.selectedItem)
                obj.changeSelectedItem('unselect')
            end
        end
        
        if ~isempty(obj.lastSelectedItem)
            if any(indToRemove == obj.lastSelectedItem)
                obj.lastSelectedItem = []; % Just to be sure.
            end
        end
        
        
        % Remove numbers from displayedItems list...Remove from list and
        % decrease number according to elements that have disappeared.
        tmpMask = zeros(1, numel(obj.roiArray));
        tmpMask(indToRemove) = 1;
        tmpMaskCumSum = cumsum(tmpMask);
        
        obj.displayedItems = setdiff(obj.displayedItems, indToRemove, 'stable');
        
        for i = 1:numel(obj.displayedItems)
            oldInd = obj.displayedItems(i);
            obj.displayedItems(i) = oldInd - tmpMaskCumSum(oldInd);
        end
        
        obj.roiArray(indToRemove) = [];

    end
    

    % % % Roi callbacks
    
    % Todo: Generalize
    function changeSelectedItem(obj, mode, tileNum)
    % changeSelectedItem Handle flipping through rois
    
        % Unselect current roi
        if ~isempty(obj.selectedItem)
            currentTileNum = find(obj.displayedItems == obj.selectedItem);
            obj.hTiledImageAxes.updateTilePlotLinewidth(currentTileNum, 1)
            obj.selectedItem = [];
        else
            currentTileNum = [];
        end
        
        
        % Determine which roi to select next depending on the 'mode' input
        switch mode
            case 'prev'
                nextTileNum = max([1, currentTileNum-1]); 
            case 'next'
                nextTileNum = min([currentTileNum+1, obj.hTiledImageAxes.nTiles]);
            case 'unselect'
                return
            case 'tile'
                nextTileNum = tileNum;
        end
            
        
        % Add roi index to selectedItem property and highlight plot 
        if exist('nextTileNum', 'var')
            obj.selectedItem = obj.displayedItems(nextTileNum);
            obj.hTiledImageAxes.updateTilePlotLinewidth(nextTileNum, 2)
        end
        
        obj.onSelectedItemChanged(obj.selectedItem)

    end
    
   
    % Mouse click callbacks
    function mouseClickInTile(obj, src, event, tileNum)
    %mouseClickInTile Callback for user input (mouseclicks) on a tile
    
        % If mousemode is not select, pass this to the mousePressed method 
        if ~isempty(obj.mouseMode) && ~strcmp(obj.mouseMode, 'Select')
            obj.mousePressed(src, event, tileNum)
            return
        end
        
        if ~isempty(obj.selectedItem)
            obj.changeSelectedItem('unselect', [])
            
%             currentTileNum = find(obj.displayedItems == obj.selectedItem);
%             obj.hTiledImageAxes.updateTilePlotLinewidth(currentTileNum, 1)
%             obj.selectedItem = [];
        end
        
        % Abort if tile is empty
        if tileNum > numel(obj.displayedItems); return; end

        
        % Roi number currently inhabitating given tile
        roiInd = obj.displayedItems(tileNum);
        
        doClassify = false;
        

        switch obj.hFigure.SelectionType
            
            case 'alt'  % Right click
                
                mp = get(obj.hFigure, 'CurrentPoint');
                
                tmpIm = findobj(obj.hTiledImageAxes.Axes, 'Type', 'image');
                tmpIm.UIContextMenu.Position(1:2) = mp;
                tmpIm.UIContextMenu.Visible = 'on';
                
                
            case {'normal'}
                doClassify = true;
                
            case 'open' % (doubleclick)
                % Do nothing 


            case 'extend' % Shift-click
                
                % Skip this step if there were no previously selected roi.
                if isempty(obj.lastSelectedItem); return; end

                doClassify = true;

                % Find all roi indices between last selection and current
                % selection
                itemOrder = obj.getItemOrder();
                currentInd = find(itemOrder == roiInd);
                previousInd = find(itemOrder == obj.lastSelectedItem);

                % Select either forward or backward
                if currentInd < previousInd
                    extInd = itemOrder(currentInd:previousInd);
                else
                    extInd = itemOrder(previousInd:currentInd);
                end
                
                % Only pick the rois that are unclassified.
                if obj.settings.IgnoreClassifiedTileOnShiftClick
                    extInd = extInd(obj.itemClassification(extInd)==0);
                end
                
        end
        
        
        if doClassify
            
            numClsf = numel(obj.classificationLabels);

            % Get classification of the roi in the selected tile.
            currentClsf = obj.itemClassification(roiInd);

            % Get the current classification mode
            hPopup = findobj(obj.hPanelSettings, 'Tag', 'SelectionMode');
            classificationMode = hPopup.Value-1;
            
            if classificationMode == 0 % Cycle through classifications
                newClsf = currentClsf+1;
            else % Flip between current classification selection and unclassified
                if currentClsf == classificationMode
                    newClsf = 0;
                else
                    newClsf = classificationMode;
                end
            end
            
            % If above selection yielded a number higher than the number of
            % available classifications, cycle back to unclassified
            if newClsf > numClsf; newClsf = 0; end

            
            % If multiple rois were chosen through shift-click, update
            % roiInd
            if exist('extInd', 'var')
                roiInd = extInd;
            end
            
            % Call the classification.
            obj.classifyRoi(roiInd, newClsf)
            
        end
        
        % Update the proprty containing the roi number of the last selected
        % roi
        obj.lastSelectedItem = roiInd(end);
        
    end
    
    
    % Todo: Generalize
    function mouseClickInRoi(obj, src, event, tileNum)
    %mouseClickInRoi Callback for user input (mouseclicks) on a roi
    
        if isempty(obj.mouseMode) || strcmp(obj.mouseMode, 'Select')
            switch obj.hFigure.SelectionType
                case 'open'
                    
                    obj.changeSelectedItem('tile', tileNum)

%                     % Quick adhoc, just for testing:
%                     event = struct;
%                     event.EventName = 'KeyPress';
%                     event.Key = 'i';
%                     
%                     currentRoiInd = obj.selectedItem;
%                     roiData = obj.prepareRoiData(currentRoiInd);
% 
%                     modifiedRoi = obj.roiTools.requestRoi([], event, roiData);
% 
%                     if ~isempty(modifiedRoi)
%                         obj.updateRois(modifiedRoi, currentRoiInd, 'reshape')
%                     end

                    
                otherwise
%                     obj.startMove(src, event, tileNum)
                    obj.changeSelectedItem('tile', tileNum)
            end

        else
            obj.mousePressed(src, event, tileNum)
        end
        
    end
    
    
    % % % Handling of user input for moving a roi within a tile.

    
    % Methods for saving results.
    function saveClassification(obj, ~, ~, varargin)
        
        
        % Get path for saving data to file.
        if isempty(varargin)
            savePath = obj.getSavePath();
        else
            error('Not implemented yet')
        end
        
        if isempty(savePath); return; end
        
        % Save these variables:
        varNames = {'itemSpecs', 'itemImages', 'itemStats', 'itemClassification'};
        
        S = struct;
        for i = 1:numel(varNames)
            S.(varNames{i}) = obj.(varNames{i});
        end
        S.classificationLabels = obj.classificationLabels;
        
        if exist(savePath, 'file')
            save(savePath, '-struct', 'S', '-append')
        else
            save(savePath, '-struct', 'S')
        end
        
        
        % Save clean version:
        keep = obj.itemClassification ~= 2;
        for i = 1:numel(varNames)
            S.(varNames{i}) = S.(varNames{i})(keep);
        end
        
        savePath = strrep(savePath, '.mat', '_clean.mat');
        save(savePath, '-struct', 'S')
        
        fprintf('Saved classification results to %s\n', savePath)
        
    end
    
    
    function savePath = getSavePath(obj)
    %getSavePath Interactive user dialog to let user choose where to save
    
        savePath = '';
        
        % Determine where to save classification
        if ~isempty(obj.dataFilePath)
            answer = questdlg('Save classification to file that was loaded? (Existing variables will be replaced)', 'Choose How to Save Classification', 'Yes', 'Pick Another File', 'Append _classified', 'Yes');
            
            switch lower(answer)
                case 'yes'
                    pickFile = false;
                    savePath = obj.dataFilePath;

                case 'pick another file'
                    pickFile = true;
                    
                case 'append _classified'
                    pickFile = false;
                    savePath = strrep(obj.dataFilePath, '.mat', '_classified.mat');
                    
                otherwise
                    return
            end
            
            initPath = obj.dataFilePath;
        else
            pickFile = true;
            initPath = '';
        end
        
        % Pick filepath interactively or get from obj.
        if pickFile
            
            fileSpec = {'*.mat', 'Mat Files (*.mat)'; '*', 'All Files (*.*)'};
            titleStr = 'Save Classification File';
            
            [filename, folderPath] = uiputfile(fileSpec, titleStr, initPath);
                                    
            savePath = fullfile(folderPath, filename);
            
        end

    end


end


methods (Access = protected)
    
        function onSettingsChanged(obj, name, val)
       
        % Todo: Unite with previous...
        switch name
            case 'TileAlpha'
                tileClsf = obj.itemClassification(obj.displayedItems);
                tileNum = find(tileClsf~=0);
                if val == 0
                    obj.settings.TileAlpha = 0.01;
                    val = 0.01; 
                end % Patch becomes unpickable if it is completely transparent.
                obj.hTiledImageAxes.setTileTransparency(tileNum, val) %#ok<FNDSB>
            
            case 'GridSize'
                obj.settings.(name) = val;
                newGridSize = obj.stringSizeToNumbers(val);

                % Apply!
                if ~obj.hMessageBox.isMessageDisplaying()
                    obj.hMessageBox.displayMessage('Updating Grid Size')
                end
                
                obj.changeGridSize(newGridSize)
                obj.hMessageBox.clearMessage()

                % Change the value of the popup control.
                hPopup = findobj(obj.hFigure, 'Tag', 'Set GridSize');
                hPopup.Value = find(contains(hPopup.String, val));

            case 'ImageSize'
                obj.settings.(name) = val;
                
                newImageSize = obj.stringSizeToNumbers(val);

                % Apply changes:
                obj.hMessageBox.displayMessage('Updating Image Resolution')

                obj.hTiledImageAxes.imageSize = newImageSize;

                % Change gridSize if aspect ratio changes.
                imageAr = newImageSize(2) ./ newImageSize(1);
                             
                % Get aspect ratio of the panel that holds the tiledImageAxes
                panelPixelPosition = getpixelposition(obj.hPanelImage);
                panelAspectRatio = panelPixelPosition(3) / panelPixelPosition(4);
                
                % Determine possible grid sizes based on panel aspect ratio
                nRows = 2:15;
                nCols = round( nRows .* panelAspectRatio ./ imageAr);
                opts = arrayfun(@(i) sprintf('%dx%d', nRows(i), nCols(i)), 1:numel(nRows), 'uni', 0);
                
                obj.settings.GridSize_ = opts;

                % Get grid size for initialization based on settings
                oldGridSize = obj.stringSizeToNumbers(obj.settings.GridSize);
                
                [~, closestMatch] = min(abs(nRows - oldGridSize(1))); 
                obj.settings.GridSize = obj.settings.GridSize_{closestMatch};
                newGridSize = [nRows(closestMatch), nCols(closestMatch)];
                obj.changeGridSize(newGridSize)

                obj.hMessageBox.clearMessage()
                
                % Change the value of the grid-size popup control.
                hPopup = findobj(obj.hFigure, 'Tag', 'Set GridSize');
                hPopup.String = obj.settings.GridSize_;
                hPopup.Value = closestMatch;
                
                % Change the value of the image-resolution popup control.
                hPopup = findobj(obj.hFigure, 'Tag', 'Set ImageSize');
                hPopup.Value = find(contains(hPopup.String, val));
                
        end
        
    end

end


methods (Static)
    
    
    function S = getSettings()
        S = getSettings@clib.hasSettings('manualClassifier');
    end

    function removeFocusFromControl(h)
        
        set(h, 'Enable', 'off');
        drawnow;
        set(h, 'Enable', 'on');
        
    end
    
end
    
end