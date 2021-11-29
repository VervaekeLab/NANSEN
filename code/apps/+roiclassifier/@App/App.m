classdef App < mclassifier.manualClassifier
    
    % todo, mouse tools are quite slow. should I use polygons instead of
    % patches?

    % roiMap should be a superclass of roiclassifier...?
    
    % classify roi methods, listeners
    % select roi methods/listeners
    % remove rois
    % reshape rois (keyboard/mousetools)
    
    % Why are superclass keyPress and onKeyPressed both activated on
    % keypress.....
    
    
    properties
        
        classificationColors = { [0.174, 0.697, 0.492], ...
                                 [0.920, 0.339, 0.378], ...
                                 [0.176, 0.374, 0.908] }

        classificationLabels = { 'Accepted', 'Rejected', 'Unclear' }


        guiColors = struct('Background', ones(1,3)*0.2, ...
                           'Foreground', ones(1,3)*0.7 )
    
    end
    
    properties
        dataFilePath            % Filepath to load/save data from
    end
    
    
    % Properties holding roi data Implementation of abstract properties.
    properties (Dependent)

        itemSpecs               % Struct array of different specifications per item
        itemImages              % Struct array of different images per item
        itemStats               % Struct array of different stats per item
        itemClassification      % Vector with classification status per item

    end
    
    properties (Access = public, SetObservable = true)
        currentFrameNo
    end
    
    properties (Access = private)
        hSignalViewer 
        roiGroup
        
        pointerManager
        
        roisChangedListener
        roiSelectionChangedListener
        roiClassificationChangedListener
        
        WindowMouseMotionListener
        WindowMouseReleaseListener
        
        roiPixelIndices
    end
    

    methods % Structors

        function obj = App(varargin)
        %roiClassifier Construct roi classifier app
            
            obj@mclassifier.manualClassifier(varargin{:})
                        
            obj.hFigure.Name = 'Roi Classifier';
%             obj.hFigure.KeyPressFcn = @obj.onKeyPressed;
            obj.hFigure.WindowKeyPressFcn = @obj.onKeyPressed;
            obj.initializePointerManager()
            obj.modifyControls()
            
            % Update tile callbacks because these are reset to default when
            % setting the tileUnits property of tiledImageAxes.
            obj.setTileCallbacks()
            
            obj.roiSelectionChangedListener = event.listener(obj.roiGroup, ...
                'roiSelectionChanged', @(s, e) onRoiSelectionChanged(obj, e));
            
            obj.roiClassificationChangedListener = event.listener(obj.roiGroup, ...
                'classificationChanged', @(s, e) onRoiClassificationChanged(obj, e));
            
            obj.roisChangedListener = event.listener(obj.roiGroup, ...
                'roisChanged', @(s, e) onRoiGroupChanged(obj, e));
            
            
            setappdata(obj.hFigure, 'ViewerObject', obj);

            
            if ~nargout
                clear obj
            end

        end
        
        function delete(obj)
            
        end
        
    end
    
    methods (Access = protected) % Creation
        
        function nvpairs = parseInputs(obj, varargin)
            
            if ischar(varargin{1})
                if exist(varargin{1}, 'file')
                    obj.uiopenFromFile(varargin{1});
                    varargin = varargin(2:end);
                end
            elseif isa(varargin{1}, 'roimanager.roiGroup')
                obj.roiGroup = varargin{1};
                varargin = varargin(2:end);
            end
            nvpairs = varargin;
                        
        end
        
        function preInitialization(obj)
            % Nothing needed here.
        end
        
        function initializePointerManager(obj)
            
            % todo: add roi map
            % todo: create a modified selection tool?
            
            hAxes = obj.hTiledImageAxes.Axes;
            obj.pointerManager = uim.interface.pointerManager(obj.hFigure, hAxes);

            % Todo: implement a sensible polydraw method... 
            % Start editing on click in tile. 
            % Restrict impoints within tile
            % Update roi on finish.
            
% % %             pointerNames = {'selectObject', 'polyDraw', ...
% % %                             'circleSelect', 'autoDetect'};
            
            pointerNames = {'selectObject', 'circleSelect', 'autoDetect'};
            % Specify where pointer tools are defind:
            
            pointerRoot = strjoin({'roimanager', 'pointerTool'}, '.');
            
            hMap = obj;
            
            % Add roimanager pointer tools.
            for i = 1:numel(pointerNames)
                pointerRef = str2func(strjoin({pointerRoot, pointerNames{i}}, '.'));
                obj.pointerManager.initializePointers(hAxes, pointerRef)
                obj.pointerManager.pointers.(pointerNames{i}).hObjectMap = hMap;
            end
            
            % Set default tool.
            obj.pointerManager.defaultPointerTool = obj.pointerManager.pointers.selectObject;
            obj.pointerManager.currentPointerTool = obj.pointerManager.pointers.selectObject;
            

        end
        
        function modifyControls(obj)
            
            % Add a selection on the show menu to show only selected items.
            
            hControl = findobj(obj.hFigure, 'Tag', 'SelectionShow');
            numOptions = numel(hControl.String);
            
            % Add a final option to show selected rois
            label = sprintf('(%d) Selected', numOptions);
            hControl.String{end+1} = label;
            
            
            hControl = findobj(obj.hFigure, 'Tag', 'SelectionImage');
            numOptions = numel(hControl.String);
            
            % Add a final option to show selected rois
            label = sprintf('(%d) Current Frame', numOptions+1);
            hControl.String{end+1} = label;
            
        end
        
    end
    
    methods % Touch callback handling
        
        function onKeyPressed(obj, src, event)
            wasCaptured = obj.pointerManager.onKeyPress([], event);
        
            switch event.Key
                
                
                case {'z', 'Z'}
                % Todo: Figure out what todo if another app is keeper of
                % the undomanager.
                if contains('command', event.Modifier) && contains('shift', event.Modifier) ...
                        || contains('control', event.Modifier) && contains('shift', event.Modifier)
                    obj.roiGroup.redo()
                elseif contains('command', event.Modifier) || contains('control', event.Modifier) 
                    obj.roiGroup.undo()
                end
            end
            
            
        end
        
        
        function onMousePressed(obj)
        end
        
        function mouseClickInTile(obj, src, event, tileNum)
        %mouseClickInTile Overrides superclass method
        
            % Only invoke superclss method when pointerTool is selectObject
            if isequal(obj.pointerManager.currentPointerTool, ...
                obj.pointerManager.pointers.selectObject) || ...
                    isempty(obj.pointerManager.currentPointerTool)
                mouseClickInTile@mclassifier.manualClassifier(obj, src, event, tileNum)
            else
                obj.pointerManager.onButtonDown(obj.hFigure, event)
                
                
            end
            
            
            
        end
        
        
        function mouseClickInRoi(obj, src, event, tileNum)
        %mouseClickInRoi Callback for user input (mouseclicks) on a roi
        % Todo: rename to onMousePressedInRoi
        
            if isequal(obj.pointerManager.currentPointerTool, ...
                    obj.pointerManager.pointers.selectObject)
                
                switch obj.hFigure.SelectionType
                    case {'normal'}
                        obj.changeSelectedItem('tile', tileNum)
                        obj.startMove(src, event, tileNum)

                    case 'open'
                        % Edit roi
                end

            else
                obj.pointerManager.onButtonDown(obj.hFigure, event)
            end

        end

        
        function onMousePressedInRoi(obj)
        end
        
    
        function growRois(obj)
            
            % Get selected rois
            originalRois = obj.roiGroup.roiArray(obj.selectedItem);
            
            newRois = originalRois;
            for i = 1:numel(originalRois)
                newRois(i) = originalRois(i).grow(1); % Grow rois
            end
            
            obj.roiGroup.modifyRois(newRois, obj.selectedItem)
            
        end
        
        
        function shrinkRois(obj)
                        
            % Get selected rois
            originalRois = obj.roiGroup.roiArray(obj.selectedItem);
            
            newRois = originalRois;
            for i = 1:numel(originalRois)
                newRois(i) = originalRois(i).shrink(1); % Shrink rois
            end
            
            obj.roiGroup.modifyRois(newRois, obj.selectedItem)
            
        end
        
        
        % % % Handling of user input for moving a roi within a tile.
        function startMove(obj, object, event, tileNum)

            el1 = listener(obj.hFigure, 'WindowMouseMotion', @(s, e) obj.moveRoi(object));
            el2 = listener(obj.hFigure, 'WindowMouseRelease', @(s, e) obj.endMove(object, tileNum));
            obj.WindowMouseMotionListener = el1;
            obj.WindowMouseReleaseListener = el2;
            
            x = event.IntersectionPoint(1);
            y = event.IntersectionPoint(2);
            obj.prevMousePointAx = [x, y];

            object.UserData.Shift = [0,0];

        end


        function moveRoi(obj, h, ~)

            
            newMousePointAx = get(obj.hTiledImageAxes.Axes, 'CurrentPoint');
            newMousePointAx = newMousePointAx(1, 1:2);

            % Is it more responsive if we get current pointer from 0?
    %             pl = get(0, 'PointerLocation');
    %             newMousePointAx2 = pl-obj.hFigure.Position(1:2);
    %             newMousePointAx2 = (newMousePointAx2 ./ obj.hFigure.Position(3:4) - 0.02) .* [obj.pixelWidth, obj.pixelHeight];  
    %             newMousePointAx2(2) = obj.pixelHeight - newMousePointAx2(2);
    %             newMousePointAx = newMousePointAx2;


            % Check if pointer is outside of tile and return if so.
            tf = newMousePointAx(1) < h.UserData.XLim(1) || ...
                    newMousePointAx(1) > h.UserData.XLim(2) || ...
                        newMousePointAx(2) < h.UserData.YLim(1) || ...
                            newMousePointAx(2) > h.UserData.YLim(2);

            if tf; obj.prevMousePointAx = newMousePointAx; return; end

            shift = newMousePointAx - obj.prevMousePointAx;

            % Limit movement within tile.
            shift(1) = max( [shift(1), -min(h.XData - h.UserData.XLim(1))] );
            shift(1) = min( [shift(1), min(h.UserData.XLim(2) - h.XData)] );
            shift(2) = max( [shift(2), -min(h.YData - h.UserData.YLim(1))] );
            shift(2) = min( [shift(2), min(h.UserData.YLim(2) - h.YData)] );

            % Move roi outline
            h.XData = h.XData + shift(1);
            h.YData = h.YData + shift(2);

            h.UserData.Shift = h.UserData.Shift + shift;

            obj.prevMousePointAx = newMousePointAx;
    %             drawnow limitrate
        end

        function endMove(obj, object, tileNum)
            
            
            delete(obj.WindowMouseMotionListener);
            delete(obj.WindowMouseReleaseListener);
            drawnow


            % Shift roi in roiarray
            if abs(sum(object.UserData.Shift)) > 0.1
                obj.repositionRoi(tileNum, object.UserData.Shift)
            end

        end
        
        function repositionRoi(obj, tileNum, shift)
        
            roiInd = obj.displayedItems(tileNum);
            
            
            % Get selected rois
            originalRoi = obj.roiGroup.roiArray(roiInd);
            
            % Get new rois that are moved versions of original ones.
            newRoi = originalRoi.move(shift, 'shiftImage');
            obj.roiGroup.modifyRois(newRoi, roiInd)

            obj.updateTile(roiInd, tileNum)

        end
        
    end
    
    methods
        
        function tf = isPointValid(obj, x, y)
            
            tf = false;
            
            if nargin < 3
                currentPoint = obj.hTiledImageAxes.Axes.CurrentPoint(1,1:2);
                x = round(currentPoint(1));
                y = round(currentPoint(2));
            end
            

            tileNum = obj.hTiledImageAxes.hittest(x, y);
            tf = ~isnan(tileNum);
            
        end
        
        function roiInd = hittest(obj, src, event)
            
            roiInd = [];
            
            x = round(event.IntersectionPoint(1));
            y = round(event.IntersectionPoint(2));
            
            tileNum = obj.hTiledImageAxes.hittest(x, y);
            if isnan(tileNum); return; end
            if tileNum > numel(obj.displayedItems); return; end
                        
            roiInd = obj.displayedItems(tileNum);
            
        end
            
        function newRoi = autodetectRoi(obj, x, y, r, autodetectionMode, doReplace)

            if nargin < 5; autodetectionMode = 1; end            
            newRoi = [];
            
            %tileSize = obj.hTiledImageAxes.imageSize;

            tileNum = obj.hTiledImageAxes.hittest(x, y);
            if isnan(tileNum); return; end
            if tileNum > numel(obj.displayedItems); return; end
            
            tileCenter = obj.hTiledImageAxes.getTileCenter(tileNum);
            
            roiInd = obj.displayedItems(tileNum);
            IM = obj.getRoiImage(roiInd);
            imSize = size(IM);
            
            
            centerOffset = [x, y] - tileCenter;
            centerOffset = round(centerOffset);
                        
            IM = circshift(IM, -fliplr(centerOffset));
            
            switch autodetectionMode
                case 1
                    %Todo: specify local center... This function should use local
                    %center, not assume to start in center of small image.
                    [roiMask_, ~] = applib.roimanager.binarize.findRoiMaskFromImage(IM, imSize./2, imSize);

                case {2, 3, 4}
                    roiMask_ = applib.roimanager.roidetection.binarizeSomaImage(IM, 'InnerDiameter', 0, 'OuterDiameter', r(1)*2);
            
            end
            
            roiMask_ = imtranslate(roiMask_, centerOffset);
                        
            if ~nargout                
                roiObject = obj.roiGroup.roiArray(roiInd);
                [I, J] = roiObject.getThumbnailCoords(imSize);
                mask = false(roiObject.imagesize);
                mask(J, I) = roiMask_;
                % mask = imtranslate(mask, [0,0]);
                
                % Using the reshape method to retain appdata. Note: reshape
                % will circshift the existing images, not make new ones.
                newRoi = roiObject.reshape('Mask', mask, 'shiftImage');

                obj.roiGroup.modifyRois(newRoi, roiInd)
                
                clear newRoi
                
            else
                % Need to make the mask the same size as the tiled image
                % axes.
                
                roiMask = false(round(obj.hTiledImageAxes.axesRange));
                xInd = round( (1:imSize(2)) - imSize(2)/2 + tileCenter(1));
                yInd = round( (1:imSize(1)) - imSize(1)/2 + tileCenter(2));
                roiMask(yInd, xInd) = roiMask_;
                
                newRoi = roiMask;
            end

            
        end
        
        % todo: move to roimanager
        function createCircularRoi(obj, x, y, r)
            
            
            tileNum = obj.hTiledImageAxes.hittest(x, y);
            roiInd = obj.displayedItems(tileNum);

            oldRoi = obj.roiGroup.roiArray(roiInd);
            
            % Calculate x,y coordinates in original image
            tileCenter = obj.hTiledImageAxes.getTileCenter(tileNum);
            centerOffset = [x, y] - tileCenter;

            newCenter = oldRoi.center + centerOffset;
            x_ = newCenter(1); y_ = newCenter(2);
            
            newRoi = oldRoi.reshape('Circle', [x_, y_, r], 'shiftImage');
            
            obj.roiGroup.modifyRois(newRoi, roiInd)

         end
        
        
        
        function changeSelectedItem(obj, mode, tileNum) % Override super
        %changeSelectedItem Method for changing selection of roi in a tile
        %
        %   Override superclass method, because roiGroup needs to notify
        %   if rois have been unselected. Also, external guis/classes may
        %   allow multi selection, and the superclass method assumes there
        %   is only one selection. Therefore the unselection is processed
        %   first, then the superclass method is called.
            
            roiInd = obj.displayedItems(tileNum);
            
            if isequal(obj.selectedItem, roiInd)
                obj.roiGroup.changeRoiSelection(obj.selectedItem, 'unselect')
                return
            elseif ~isempty(obj.selectedItem)
                obj.roiGroup.changeRoiSelection(obj.selectedItem, 'unselect')
                obj.selectedItem = [];
            end
            
            changeSelectedItem@mclassifier.manualClassifier(obj, mode, tileNum);

        end
        
        % Todo: Make protected
        function roiImage = getRoiImage(obj, roiInd, varargin)
            
            hPopup = findobj(obj.hPanelSettings, 'Tag', 'SelectionImage');
            selection = hPopup.String{hPopup.Value};
            
            if contains(selection, 'Current Frame') % Show selection
                roiImage = cat(3, obj.roiGroup.roiArray(roiInd).enhancedImage);
            else
                roiImage = getRoiImage@mclassifier.manualClassifier(obj, roiInd, varargin);
            end
            
        end
        
        function updateView(obj, src, event, mode)
            updateView@mclassifier.manualClassifier(obj, src, event, mode)
            obj.setRoiPixelIndices()
        end
        
        
        function changeFrame(obj, currentImage)
            % Todo: update tile images when imviewer frame is changed.
            
            hPopup = findobj(obj.hPanelSettings, 'Tag', 'SelectionImage');
            selection = hPopup.String{hPopup.Value};
            
            if contains(selection, 'Current Frame')
                
                imData = obj.getRoiImage(obj.displayedItems);
                for i = 1:numel(obj.displayedItems)
                    
                    I = obj.roiPixelIndices(:,1,i);
                    J = obj.roiPixelIndices(:,2,i);
                    
                    imData(:, :, i) = currentImage(J, I);
                end
                
            else
                return
            end
            
            
            obj.hTiledImageAxes.updateTileImage(imData, 1:numel(obj.displayedItems))
            
            
        end
        
        
        
        
    end
        
    methods (Access = protected) % Other event and callback handlers

        
        function onSelectedItemChanged(obj, roiIndices)
        %onSelectedItemChanged Callback for selection in the classifier
        
            % Call the changeRoiSelection of roiGroup, which will trigger
            % the roiSelectionChanged event
            obj.roiGroup.changeRoiSelection(roiIndices, 'select', true)
            
        end
        
        function onRoiSelectionChanged(obj, evtData)
        %onRoiSelectionChanged Callback for event listener on roi selection
        %
        %   This event is triggered from the roiGroup and can therefore be
        %   caused by selection change from external apps/classes. This
        %   separates it from the onSelectedItemChanged which is a callback
        %   from the manualClassifier.
        %
        %   Takes care of selection of roi. Show roi as white in image 
        %   on selection. Reset color on deselection.
        
            roiIndices = evtData.roiIndices;
            tileNum = ismember(obj.displayedItems, roiIndices);
            
            switch evtData.eventType
                case 'unselect'
                    obj.hTiledImageAxes.updateTilePlotLinewidth(tileNum, 1)
                    obj.selectedItem = setdiff(obj.selectedItem, roiIndices);
                case 'select'
                    obj.hTiledImageAxes.updateTilePlotLinewidth(tileNum, 2)
                    obj.selectedItem = cat(2, obj.selectedItem, roiIndices);
            end
            
            % Make sure the list is unique and well behaving....
            if ~isempty(obj.selectedItem)
                obj.selectedItem = unique(obj.selectedItem, 'stable'); % The lazy way
            else
                obj.selectedItem = []; % setdiff creates an empty row vector, creates problems later...
            end
            
            if ~isempty(obj.selectedItem)
                candidates = getCandidatesForUpdatedView(obj);
                if isequal(candidates, obj.selectedItem)
                    obj.updateView([], [], 'change selection')
                end
            end
        end
        
        function onRoiClassificationChanged(obj, evtData)
            
            tileNum = ismember(obj.displayedItems, evtData.roiIndices);
            obj.updateTileColor(find(tileNum))
            
        end
        
        function onRoiGroupChanged(obj, evt)
            % Triggered on existing roiGroup events
            
            % Todo: also update text label. 
            % (Maybe text label is not implemented)
            
            
            % Take action for this EventType
            switch lower(evt.eventType)
                
                case {'initialize', 'append', 'insert'}
                    
                    % Todo: work on this. Ie. if mode is sort then roi
                    % might need to be inserted even if is it not within
                    % the range of displayed rois...
                    tileInd = find( ismember(obj.displayedItems, evt.roiIndices) );
                    
                    if ~isempty(tileInd) || numel(obj.displayedItems) < obj.hTiledImageAxes.nTiles
                        obj.updateView([], [], 'refresh')
                    end
                                        
                    
%                     obj.updateRoiMaskAll(evt.roiIndices, evt.eventType)
%                     obj.updateRoiIndexMap()
                    
                case {'modify', 'reshape'}
                    
                    tileInd = find( ismember(obj.displayedItems, evt.roiIndices) );
                    obj.updateTile(evt.roiIndices, tileInd)

% %                     obj.updateRoiMaskAll(evt.roiIndices, evt.eventType)
% %                     obj.updateRoiIndexMap()
                    
                case 'remove'
                    
                    tileInd = find( ismember(obj.displayedItems, evt.roiIndices) );
                    
                    if ~isempty(tileInd)
                        obj.updateView([], [], 'refresh')
                    end
                    
                    
                case {'connect', 'relink'}
                    obj.updateLinkPlot(evt.roiIndices, evt.eventType)

                otherwise
                    
                    % Throw a warning, then redraw just to be safe
                    warning('onRoiGroupChanged:UnhandledEvent',...
                        'Unhandled event type: %s',evt.EventType);
                    
            end %switch
            
            %obj.notify('mapUpdated')
            
        end %function
        
        function onSettingsChanged(obj, name, value)
            onSettingsChanged@mclassifier.manualClassifier(obj, name, value)
        end
        
    end
    
    methods (Access = protected) % Gui update
    
        function candidates = getCandidatesForUpdatedView(obj)
            
            hPopup = findobj(obj.hPanelSettings, 'Tag', 'SelectionShow');
            selection = hPopup.String{hPopup.Value};
            
            if contains(selection, 'Selected') % Show selection
                candidates = obj.selectedItem;
            else
                candidates = getCandidatesForUpdatedView@mclassifier.manualClassifier(obj);
            end
            
        end
        
        function updateTile(obj, roiInd, tileNum)

            % Accepts vector of roi indices and tile numbers

            if nargin < 3 || isempty(tileNum)
                tileNum = find(ismember(obj.displayedItems, roiInd));
            end

            if isempty(tileNum); return; end

            imageSelection = getCurrentImageSelection(obj);
            imageSize = obj.hTiledImageAxes.imageSize;

            try
                if strcmp(imageSelection, 'default')
                    roiImage = cat(3, obj.itemSpecs(roiInd).enhancedImage);
                elseif strcmp(imageSelection, 'Current Frame')
                    roiImage = cat(3, obj.itemSpecs(roiInd).enhancedImage);
                else
                    roiImage = cat(3, obj.itemImages(roiInd).(imageSelection));
                end
            catch
                error('Not implemented for images of different size')
            end

            %roiImageSize = size(roiImage);
            %obj.scaleFactor = imageSize ./ roiImageSize(1:2);
            %roiImage = imresize(roiImage, imageSize);
            upsampling = [1,1];

            obj.hTiledImageAxes.updateTileImage(roiImage, tileNum)

            % Update outline color according to classification
            obj.updateTileColor(tileNum)


            cellOfStr = arrayfun(@(i) num2str(i), roiInd, 'uni', 0);
            obj.hTiledImageAxes.updateTileText(cellOfStr, tileNum)

    %         for i = 1:numel(roiInd)
    %             obj.hTiledImageAxes.updateTileText(num2str(roiInd(i)), tileNum(i))
    %         end

            % Get boundary coordinates for all rois. Shift boundary to origo
            % and resize according to upsampling factor.
            boundaryX = arrayfun(@(i) (obj.itemSpecs(i).boundary{1}(:,2) - ...
                obj.itemSpecs(i).center(1)).* upsampling, roiInd, 'uni', 0) ;
            boundaryY = arrayfun(@(i) (obj.itemSpecs(i).boundary{1}(:,1) - ...
                obj.itemSpecs(i).center(2)).* upsampling, roiInd, 'uni', 0) ;

            % Send to plotter method in TiledImageAxes Object
            obj.hTiledImageAxes.updateTilePlot(boundaryX, boundaryY, tileNum)
            
            
            % Reset linewidth of objects in all tiles
            obj.hTiledImageAxes.updateTilePlotLinewidth(tileNum, 1)

            % Update linewidths of tiles with selected items.
            tileNum = ismember(obj.displayedItems, obj.selectedItem);
            obj.hTiledImageAxes.updateTilePlotLinewidth(tileNum, 2)
            
        end
        
        
        function setRoiPixelIndices(obj)
        %setRoiPixelIndices Create 3D array with pixel ind for roi thumbs 
        %
        %   This is used for retrieving new images if the current frame of
        %   imviewer is changed
            numRois = numel(obj.displayedItems);
            if numRois == 0; return; end
            
            roiImageSize = size( obj.getRoiImage(obj.displayedItems(1)) );
            
            obj.roiPixelIndices = zeros([roiImageSize(1), 2, numRois]);
            
            for i = 1:numRois
                roiObject = obj.roiGroup.roiArray(obj.displayedItems(i));
                [I, J] = roiObject.getThumbnailCoords(roiImageSize);
                obj.roiPixelIndices(:,1,i) = I;
                obj.roiPixelIndices(:,2,i) = J;
                
            end
            
        end
        
        
        % % % Methods for modifying roi objects.
    
        function shiftRoiImages(obj, roiInd, shift)
        % shiftRoiImages Shift roi images in the roiImage property
        %
        %   If rois are modified in this gui the images need to be shifted
        %   accordingly, since the roi is always centered on the image...

            if ~isempty(obj.itemImages)
                imageNames = fieldnames(obj.itemImages);
                for i = 1:numel(imageNames)
                    obj.itemImages(roiInd).(imageNames{i}) = ...
                        circshift(obj.itemImages(roiInd).(imageNames{i}), -fliplr(round(shift)) );
                end
            end

        end
        
        % Todo reposition / move rois. Old way, capture figure callbacks
        % and implement drag and release methods to calculate shift.  Limit
        % move within tile. Not sure if this will work with the selection
        % tool, since it also has the drag to select many method. Maybe I
        % can disable that..., startMove, moveRoi, endMove, repositionRoi
        
        
    end
    
    
    methods % Data methods
        
        function openFromFile(obj)
            
            
        end
        
        
        
        function tf = uiopenFromFile(obj, filePath)
    
            tf = false;

            if nargin < 2
                [S, obj.dataFilePath] = applib.roimanager.fileio.uigetrois();
                if isempty(S); return; end

            else
                S = load(filePath);
                obj.dataFilePath = filePath;
            end


            obj.roiGroup = applib.roimanager.roiGroup(S);
            
            
% %             allowedFields = {'roiArray', 'roiImages', 'roiStats', 'roiClassification'};
% % 
% %             for i = 1:numel(allowedFields)
% %                 if isfield(S, allowedFields{i})
% %                     obj.(allowedFields{i}) = S.(allowedFields{i});
% %                 end
% %             end

            tf = true;

        end

        
        
        function saveClassification(obj)
        end
        
    end
    
    
    methods %Set/get
        function specs = get.itemSpecs(obj)
            specs = obj.roiGroup.roiArray;
        end
        
        function imData = get.itemImages(obj)
            imData = obj.roiGroup.roiImages;
        end
        
        function set.itemClassification(obj, newClass)
            
            oldClass = obj.roiGroup.roiClassification;
            roiInd = find(oldClass ~= newClass);
            
            obj.roiGroup.setRoiClassification(roiInd, newClass(roiInd))
        end
        
        function stats = get.itemStats(obj)
            stats = obj.roiGroup.roiStats;
        end
        
        function classification = get.itemClassification(obj)
            classification = obj.roiGroup.roiClassification;
        end
    end
    
    
    methods (Static)
        
        function S = getSettings()
            S = getSettings@clib.hasSettings('roiClassifier');
        end
        
    end

end

