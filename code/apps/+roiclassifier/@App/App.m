classdef App < mclassifier.manualClassifier & roimanager.roiDisplay & roimanager.RoiGroupFileIoAppMixin
%roiClassifier.App App for classifying rois in a tiled montage view
%
%   roiClassifier.App(filename) initializes the app using rois from file
%   specified by filename. Filename is a character vector containing the
%   path to a file containing a roi group
%
%   roiClassifier.App(roiGroup) initializes the app with an existing roi
%   group.

    % Todo:
    % [ ] Save composite roi group in roi classifier...
    %
    % [ ] selectedItem is the same as roiDisplay's SelectedRois and
    %     displayedItems is the same as roiDisplay's VisibleRois
    %
    % [ ] roiFilePath = dataFilePath....
    %
    % [ ] old comment: mouse tools are quite slow. should I use polygons
    %     instead of patches? Is this still a problem
    %
    % [ ] old comment: Why are superclass keyPress and onKeyPressed both
    %     activated on keypress? - Is this still a problem
    % [ ] Fix imprecise coordinate representations of rois

    % This class requires a big upgrade.
    %   1) Should make a clear distinction between the app and the
    %      "classifier". The classifier widget consist of the tiled image
    %      axes and added functionality for classification of tiles, but
    %      the app contains more functionality, like roi load/save etc.
    %
    %   2) Roi editing tools should be moved/joined in a RoiEditor class.
    %   3) Roi display should be a property of the App class?

    %   Inherited properties: Note: Inherited from both roiDisplay and
    %   RoiGroupFileIoAppMixin. This needs to be fixed.
    %       RoiGroup            % RoiGroup object (roiDisplay)

    properties
        
% %         classificationColors = { [0.174, 0.697, 0.492], ...
% %                                  [0.920, 0.339, 0.378], ...
% %                                  [0.176, 0.374, 0.908] }
% %
% %         classificationLabels = { 'Accepted', 'Rejected', 'Unresolved' }

%         guiColors = struct('Background', ones(1,3)*0.1, ...
%                            'Foreground', ones(1,3)*0.7 )
         guiColors = struct('Background',  [0.1020 0.1137 0.1294], ...
                            'Foreground', [0.8196 0.8235 0.8275])
    
    end

    properties
        SaveFcn % Custom function for saving rois
    end
    
    properties (Dependent)
        dataFilePath            % Filepath to load/save data from
    end

    properties
        roiFilePath
        RoiSelectedCallbackFunction % Callback function that will run when a roi is selected.
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
    
    properties (SetAccess = protected)
        hSignalViewer
        pointerManager
    end
    
    properties (Access = private)
        WindowMouseMotionListener
        WindowMouseReleaseListener
        
        roiPixelIndices
    end

    methods % Structors

        function obj = App(varargin)
        %roiClassifier Construct roi classifier app
            
            % Todo: Should units always be scaled by default??
            varargin = [varargin, {'tileUnits', 'scaled'}];
            obj@mclassifier.manualClassifier(varargin{:})
                        
            obj.hFigure.Name = 'Roi Classifier';
            % obj.hFigure.KeyPressFcn = @obj.onKeyPressed;
            obj.hFigure.WindowKeyPressFcn = @obj.onKeyPressed;
            obj.initializePointerManager()
            obj.modifyControls()
            
            % Update tile callbacks because these are reset to default when
            % setting the tileUnits property of tiledImageAxes.
            obj.setTileCallbacks()
            
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
                obj.RoiGroup = varargin{1};
                varargin = varargin(2:end);
            elseif isa(varargin{1}, 'struct') && isfield(varargin{1}, 'roiArray')
                obj.RoiGroup = varargin{1};
                varargin = varargin(2:end);
            end
            
            % Todo: This requires a proper cleanup
            def = struct('RoiSelectedCallbackFunction', '');
            opt = utility.parsenvpairs(def, 1, varargin);
            
            if ~isempty(opt.RoiSelectedCallbackFunction)
                obj.RoiSelectedCallbackFunction = opt.RoiSelectedCallbackFunction;
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
            
            % Specify where pointer tools are defined:
     
            % Todo: Constant property or some roimanager constant class
            pointerRoot = strjoin({'roimanager', 'pointerTool'}, '.');
            
            hMap = obj;
            
            % Add roimanager pointer tools.
            for i = 1:numel(pointerNames)
                pointerRef = str2func(strjoin({pointerRoot, pointerNames{i}}, '.'));
                obj.pointerManager.initializePointers(hAxes, pointerRef)
                obj.pointerManager.pointers.(pointerNames{i}).RoiDisplay = hMap;
            end
            
            % Set default tool.
            obj.pointerManager.defaultPointerTool = obj.pointerManager.pointers.selectObject;
            obj.pointerManager.currentPointerTool = obj.pointerManager.pointers.selectObject;
            
            % Because the classifier app changes the extreme limits of the
            % axes when the image resolution or number of tiles is changed,
            % the autodetection tool must listen for axes limit changes.
            obj.pointerManager.pointers.autoDetect.addAxesLimitChangeListener()
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
            
% %             Down for maintenance...
% %             % Add a final option to show selected rois
% %             label = sprintf('(%d) Current Frame', numOptions+1);
% %             hControl.String{end+1} = label;
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
                    obj.RoiGroup.redo()
                elseif contains('command', event.Modifier) || contains('control', event.Modifier)
                    obj.RoiGroup.undo()
                end
                
                case ''
                    
                case 'o'
                    if contains('command', event.Modifier) || contains('control', event.Modifier)
                        obj.importRois()
                    end
            end
        end
        
        function mousePressed(obj, src, event, tileNum)
            
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
                        % Important: start move should be called before
                        % changeSelectedItem to avoid race conditions.
                        obj.startMove(src, event, tileNum)
                        obj.changeSelectedItem('tile', tileNum)

                    case 'open'
                        % Edit roi
                end

            else
                obj.pointerManager.onButtonDown(obj.hFigure, event)
            end
        end
        
        function onMousePressedInRoi(obj)
        end
        
        function moveRoi(obj, shift)
            if isempty(obj.selectedItem)
                return
            end
        end
        
        function growRois(obj)
            
            % Get selected rois
            originalRois = obj.RoiGroup.roiArray(obj.selectedItem);
            
            newRois = originalRois;
            for i = 1:numel(originalRois)
                newRois(i) = originalRois(i).grow(1); % Grow rois
            end
            
            obj.RoiGroup.modifyRois(newRois, obj.selectedItem)
            
        end
        
        function shrinkRois(obj)
                        
            % Get selected rois
            originalRois = obj.RoiGroup.roiArray(obj.selectedItem);
            
            newRois = originalRois;
            for i = 1:numel(originalRois)
                newRois(i) = originalRois(i).shrink(1); % Shrink rois
            end
            
            obj.RoiGroup.modifyRois(newRois, obj.selectedItem)
            
        end
        
        % % % Handling of user input for moving a roi within a tile.
        function startMove(obj, object, event, tileNum)
            
            el2 = listener(obj.hFigure, 'WindowMouseRelease', @(s, e) obj.endMove(object, tileNum));
            el1 = listener(obj.hFigure, 'WindowMouseMotion', @(s, e) obj.onMouseDragRoi(object));
            
            obj.WindowMouseMotionListener = el1;
            obj.WindowMouseReleaseListener = el2;
            
            x = event.IntersectionPoint(1);
            y = event.IntersectionPoint(2);
            obj.prevMousePointAx = [x, y];

            object.UserData.Shift = [0,0];

        end

        function improveRois(obj)
            fprintf('Not implemented yet\n')
        end
        
        function onMouseDragRoi(obj, h, ~)

            newMousePointAx = get(obj.hTiledImageAxes.Axes, 'CurrentPoint');
            newMousePointAx = newMousePointAx(1, 1:2);

            % Is it more responsive if we get current pointer from 0?
    %             pl = get(0, 'PointerLocation');
    %             newMousePointAx2 = pl-obj.hFigure.Position(1:2);
    %             newMousePointAx2 = (newMousePointAx2 ./ obj.hFigure.Position(3:4) - 0.02) .* [obj.pixelWidth, obj.pixelHeight];
    %             newMousePointAx2(2) = obj.pixelHeight - newMousePointAx2(2);
    %             newMousePointAx = newMousePointAx2;
            
            %TODO: Fix
            
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
            originalRoi = obj.RoiGroup.roiArray(roiInd);
            
            % Get new rois that are moved versions of original ones.
            newRoi = originalRoi.move(shift, 'shiftImage');
            obj.RoiGroup.modifyRois(newRoi, roiInd)

            obj.updateTile(roiInd, tileNum)

        end
    end
    
    methods
        
        function removeRois(obj, roiInd)
            if nargin < 2; roiInd = obj.SelectedRois; end
            
            obj.removeItems(roiInd)
        end
        
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
            tileCenter = obj.hTiledImageAxes.getTileCenterAxesCoords(tileNum);

            roiInd = obj.displayedItems(tileNum);
            IM = obj.getRoiImage(roiInd);
            imSize = size(IM);
            
            % Find the distance between the mouse pointer position and the
            % center of the current image tile. Correct by 0.5 to go from
            % axes coordinates to image pixel coordinates.
          
            %Calculate the center offset of the mouse pointer in the
            % current image.
            
            centerOffset = [x, y] - tileCenter + 0.5;
            
            %centerOffset = round(centerOffset);
            %IM = circshift(IM, -fliplr(centerOffset));
            IM = imtranslate(IM, -centerOffset);
            
% %             persistent f ax hIm
% %             if isempty(f) || ~isvalid(f)
% %                 f = figure('Position', [300,300,300,300], 'MenuBar', 'none');
% %                 ax = axes(f, 'Position',[0,0,1,1]);
% %             else
% %                 cla(ax)
% %             end
% %
% %             hIm = imagesc(ax, IM); hold on
% %             plot(ax, size(IM,2)/2+0.5, size(IM,1)/2+0.5, 'xw')
            
            switch autodetectionMode
                case 1
                    roiMask_ = flufinder.binarize.findSomaMaskByEdgeDetection(IM);

                case {2, 3, 4}
                    roiMask_ = flufinder.binarize.findSomaMaskByThresholding(IM, 'InnerDiameter', 0, 'OuterDiameter', r(1)*2);
            end
            
            roiMask_ = imtranslate(roiMask_, round(centerOffset)); % + correction);
            %roiMask_ = circshift(roiMask_, centerOffset);
            
            if ~nargout
                
                roiObject = obj.RoiGroup.roiArray(roiInd);
                
                % Place detected roimask in fov-sized mask
                [I, J] = roiObject.getThumbnailCoords(imSize);
                mask = false(roiObject.imagesize);
                mask(J, I) = roiMask_;
                
                % Using the reshape method to retain appdata. Note: reshape
                % will circshift the existing images, not make new ones.
                newRoi = roiObject.reshape('Mask', mask, 'shiftImage');
                obj.RoiGroup.modifyRois(newRoi, roiInd)
                
                clear newRoi
                
            else
                % Need to make the mask the same size as the tiled image
                % axes.
                
                % persistent hImage
                
                roiMask = false(round(fliplr(obj.hTiledImageAxes.axesRange)));
                xInd = round( (1:imSize(2)) - imSize(2)/2 + tileCenter(1)-0.5); % Todo: Why subtract 0.5
                yInd = round( (1:imSize(1)) - imSize(1)/2 + tileCenter(2)-0.5);
                roiMask(yInd, xInd) = roiMask_;
                %roiMask = imtranslate(roiMask, [-1,0]);
                
% %                 if isempty(hImage)
% %                     f=figure; ax=axes(f); hImage = image(roiMask, 'Parent', ax);
% %                     hImage.CDataMapping = 'scaled';
% %                 else
% %                     hImage.CData = roiMask;
% %                 end
                
                newRoi = RoI('Mask', roiMask, size(roiMask));%roiMask;

                %newRoi = roiMask;
            end
        end
        
        function newRoi = autodetectRoi2(obj, x, y, r, autodetectionMode, doReplace)
            if nargin < 5; autodetectionMode = 1; end
            
            if ~nargout
                obj.autodetectRoi(x, y, r, autodetectionMode, doReplace);
            else
                newRoi = obj.autodetectRoi(x, y, r, autodetectionMode, doReplace);
            end
        end
        % todo: move to roimanager
        function createCircularRoi(obj, x, y, r)
            
            tileNum = obj.hTiledImageAxes.hittest(x, y);
            roiInd = obj.displayedItems(tileNum);

            oldRoi = obj.RoiGroup.roiArray(roiInd);
            
            % Calculate x,y coordinates in original image
            tileCenter = obj.hTiledImageAxes.getTileCenter(tileNum);
            centerOffset = [x, y] - tileCenter;

            newCenter = oldRoi.center + centerOffset;
            x_ = newCenter(1); y_ = newCenter(2);
            
            newRoi = oldRoi.reshape('Circle', [x_, y_, r], 'shiftImage');
            
            obj.RoiGroup.modifyRois(newRoi, roiInd)

         end
        
        function changeSelectedItem(obj, mode, tileNum) % Override super
        %changeSelectedItem Method for changing selection of roi in a tile
        %
        %   Override superclass method, because roiGroup needs to notify
        %   if rois have been unselected. Also, external guis/classes may
        %   allow multi selection, and the superclass method assumes there
        %   is only one selection. Therefore the unselection is processed
        %   first, then the superclass method is called.
            
            if nargin == 2
                changeSelectedItem@mclassifier.manualClassifier(obj, mode);
                return
            end
        
            roiInd = obj.displayedItems(tileNum);
            
            if isequal(obj.selectedItem, roiInd) % Toggle off.
                obj.RoiGroup.changeRoiSelection(obj.selectedItem, [])
                return
                
%             elseif ~isempty(obj.selectedItem)
%                 obj.RoiGroup.changeRoiSelection(obj.selectedItem, [])
%                 %obj.selectedItem = [];
            
            elseif ~isempty(roiInd)
                obj.RoiGroup.changeRoiSelection(obj.selectedItem, roiInd)
            end
            
            %changeSelectedItem@mclassifier.manualClassifier(obj, mode, tileNum);

        end
        
        function classifyRois(obj, classification)
            
            roiInd = obj.selectedItem;
            if isempty(roiInd); return; end
            newClass = repmat(classification, size(roiInd));
            obj.RoiGroup.setRoiClassification(...
                roiInd, newClass)
                        
        end
        
        % Todo: Make protected
        function roiImage = getRoiImage(obj, roiInd, varargin)
            
            hPopup = findobj(obj.hPanelSettings, 'Tag', 'SelectionImage');
            selection = hPopup.String{hPopup.Value};
            
            if contains(selection, 'Current Frame') % Show selection
                roiImage = cat(3, obj.RoiGroup.roiArray(roiInd).enhancedImage);
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
        
        function onSelectedItemChanged(obj, roiIndices) %Roidisplay
        %onSelectedItemChanged Callback for selection in the classifier
        
            % Call the changeRoiSelection of roiGroup, which will trigger
            % the roiSelectionChanged event
            obj.RoiGroup.changeRoiSelection(obj.selectedItem, roiIndices, obj)
        end
        
        function onRoiSelectionChanged(obj, evtData) %Roidisplay
        %onRoiSelectionChanged Callback for event listener on roi selection
        %
        %   This event is triggered from the roiGroup and can therefore be
        %   caused by selection change from external apps/classes. This
        %   separates it from the onSelectedItemChanged which is a callback
        %   from the manualClassifier.
        %
        %   Takes care of selection of roi. Show roi as white in image
        %   on selection. Reset color on deselection.
        
            selectedRoiIdx = setdiff(evtData.NewIndices, obj.selectedItem);
            deselectedRoiIdx = setdiff(obj.selectedItem, evtData.NewIndices);
            
            if ~isempty(selectedRoiIdx) % Update appearance of selected roi
                tileNum = ismember(obj.displayedItems, selectedRoiIdx);
                obj.hTiledImageAxes.updateTilePlotLinewidth(tileNum, 2)
                obj.selectedItem = cat(2, obj.selectedItem, selectedRoiIdx);
            end
            
            if ~isempty(deselectedRoiIdx) % Update appearance of deselected roi
                tileNum = ismember(obj.displayedItems, deselectedRoiIdx);
                obj.hTiledImageAxes.updateTilePlotLinewidth(tileNum, 1)
                obj.selectedItem = setdiff(obj.selectedItem, deselectedRoiIdx);
            end
            
            % Make sure the list is unique and well behaving....
            if ~isempty(obj.selectedItem)
                obj.selectedItem = unique(obj.selectedItem, 'stable'); % The lazy way
            else
                obj.selectedItem = []; % setdiff creates an empty row vector, creates problems later...
            end
            
            obj.SelectedRois = obj.selectedItem;
            
            if ~isempty(obj.RoiSelectedCallbackFunction) && ~isempty(obj.selectedItem)
                obj.RoiSelectedCallbackFunction(selectedRoiIdx, obj.itemSpecs(selectedRoiIdx))
            end

            if ~isempty(obj.selectedItem)
                candidates = getCandidatesForUpdatedView(obj);
                if isequal(candidates, obj.selectedItem)
                    obj.updateView([], [], 'change selection')
                end
            end
        end
        
        function onRoiClassificationChanged(obj, evtData) %Roidisplay
            
            tileNum = ismember(obj.displayedItems, evtData.roiIndices);
            
            obj.updateTileColor(find(tileNum))
            
        end
        
        function onRoiGroupChanged(obj, evt) %Roidisplay
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
            
        end
        
        function onSettingsChanged(obj, name, value)
            onSettingsChanged@mclassifier.manualClassifier(obj, name, value)
        end

        function onFigureCloseRequest(obj)

            wasAborted = obj.promptSaveRois();
            if wasAborted; return; end
            
            delete(obj)
            
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
                    roiImages = {obj.itemImages(roiInd).(imageSelection)};
                    isEmpty = cellfun(@(c) isempty(c), roiImages);
                    ind = find(~isEmpty, 1, 'first');
                    [roiImages{isEmpty}] = deal(zeros(size(roiImages{ind}, [1,2]), 'like', roiImages{ind}));
                    roiImage = cat(3, roiImages{:});
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

            %cellOfStr = arrayfun(@(i) num2str(i), roiInd, 'uni', 0);
            roiLabels = obj.getItemText(roiInd);
            obj.hTiledImageAxes.updateTileText(roiLabels, tileNum)

    %         for i = 1:numel(roiInd)
    %             obj.hTiledImageAxes.updateTileText(num2str(roiInd(i)), tileNum(i))
    %         end

            % Get boundary coordinates for all rois. Shift boundary to origo
            % and resize according to upsampling factor.
            boundaryX = arrayfun(@(i) (obj.itemSpecs(i).boundary{1}(:,2) - ...
                round(obj.itemSpecs(i).center(1))).* upsampling(1), roiInd, 'uni', 0) ;
            boundaryY = arrayfun(@(i) (obj.itemSpecs(i).boundary{1}(:,1) - ...
                round(obj.itemSpecs(i).center(2))).* upsampling(2), roiInd, 'uni', 0) ;

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
                roiObject = obj.RoiGroup.roiArray(obj.displayedItems(i));
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
    
    methods (Access = public)
        
        function addCustomGridSize(obj, customGridSize)

            if isnumeric(customGridSize)
                assert(numel(customGridSize)==2, 'Grid size must be numerix height x width')
                customGridSize = sprintf('%dx%d', customGridSize(1), customGridSize(2));
            end

            obj.settings_.GridSize_{end+1} = customGridSize;

            % Add to dropdown control
            h = findobj(obj.hPanelSettings, 'Tag', 'Set GridSize');
            h.String{end+1} = customGridSize;
        end

        % Methods for saving results.
        function saveClassification(obj, ~, ~, varargin)
        % saveClassification

            if ~isempty(obj.SaveFcn)
                obj.SaveFcn(obj.RoiGroup)
                return
            end

            % Get path for saving data to file.
            if isempty(varargin)
                savePath = obj.getSavePath();
            else
                error('Not implemented yet')
            end

            if isempty(savePath); return; end
            
            obj.saveRois(savePath)
            
            % Save clean version of rois....
            % Todo: Show have setting for this, and default should be to
            % not save...

            if isa(obj.RoiGroup, 'roimanager.CompositeRoiGroup')
                tempRoiGroup = obj.RoiGroup.getAllRoiGroups();
            else
                tempRoiGroup = obj.RoiGroup;
            end

            roiGroupStruct = struct;

            for i = 1:numel(tempRoiGroup)

                keep = tempRoiGroup(i).roiClassification ~= 2;
                
                roiGroupStruct(i).roiArray = tempRoiGroup(i).roiArray(keep);
                roiGroupStruct(i).roiImages = tempRoiGroup(i).roiImages(keep);
                roiGroupStruct(i).roiStats = tempRoiGroup(i).roiStats(keep);
                roiGroupStruct(i).roiClassification = tempRoiGroup(i).roiClassification(keep);
            end

            savePath = strrep(savePath, '.mat', '_clean.mat');

            % Save roigroup using roigroup fileadapter
            fileObj = nansen.dataio.fileadapter.roi.RoiGroup(savePath, '-w');
            fileObj.save(roiGroupStruct);
            fprintf('Saved clean classification results to %s\n', savePath)
            
        end
    end
    
    methods (Access = public) % Load/save rois
        
        function rois = loadRois(obj, loadPath)
        %loadRois Load rois and add them to app
        
            obj.hMessageBox.displayMessage('Loading Rois...')
            C = onCleanup(@(s,e) obj.hMessageBox.clearMessage);
           
            try
                rois = loadRois@roimanager.RoiGroupFileIoAppMixin(obj, loadPath);
            catch ME
                clear C % Reset message display
                obj.hMessageBox.displayMessage(['Error: ', ME.message], [], 2)
                if nargout; rois = []; end
                return
            end
            doInitialization = ~isempty(obj.RoiGroup);
            obj.RoiGroup = rois;
            obj.RoiGroup.markClean()
            
            if doInitialization
                obj.updateView([], [], 'Initialize')
            end
        end
        
        function saveRois(obj, initPath)
        %saveRois Save rois with confirmation message in app.
            if nargin < 2; initPath = ''; end
            
            if ~isempty(obj.SaveFcn)
                obj.SaveFcn(obj.RoiGroup)
            else
                saveRois@roimanager.RoiGroupFileIoAppMixin(obj, initPath)
                saveMsg = sprintf('Rois Saved to %s\n', obj.roiFilePath);
                obj.hMessageBox.displayMessage(saveMsg, [], 2)
            end
        end
    end

    methods (Access = protected) % RoiGroupFileIoAppMixin methods

        % Todo: Same as import rois??
        function tf = uiopenFromFile(obj, filePath)
    
            tf = false;

            if nargin < 2
                fileObj = nansen.dataio.fileadapter.roi.RoiGroup();
                fileObj.uiopen()
                if isempty(fileObj.Filename); return; end
            else
                fileObj = nansen.dataio.fileadapter.roi.RoiGroup(filePath);
            end
            
            doInitialization = ~isempty(obj.RoiGroup);
            obj.RoiGroup = fileObj.load();
            
            if doInitialization
                obj.updateView([], [], 'Initialize')
            end

            tf = true;

        end
    
        function initPath = getRoiInitPath(obj)
        %getRoiInitPath Get path to start uigetfile or uiputfile
        
            if ~isempty(obj.roiFilePath)
                initPath = obj.roiFilePath;
            elseif isempty(obj.dataFilePath)
                initPath = obj.dataFilePath;
            else
                initPath = '';
            end
        end
    end
    
    methods %Set/get

        function set.dataFilePath(obj, value)
            obj.roiFilePath = value;
        end
        function filePath = get.dataFilePath(obj)
            filePath = obj.roiFilePath;
        end

        function specs = get.itemSpecs(obj)
            specs = obj.RoiGroup.roiArray;
        end
        
        function imData = get.itemImages(obj)
            imData = obj.RoiGroup.roiImages;
        end
        
        function set.itemClassification(obj, newClass)
            
            oldClass = obj.RoiGroup.roiClassification;
            roiInd = find(oldClass ~= newClass);
            
            obj.RoiGroup.setRoiClassification(roiInd, newClass(roiInd))
        end
        
        function stats = get.itemStats(obj)
            stats = obj.RoiGroup.roiStats;
        end
        
        function classification = get.itemClassification(obj)
            classification = obj.RoiGroup.roiClassification;
        end
    end
    
    methods (Static)
        
        function S = getSettings()
            S = getSettings@applify.mixin.UserSettings('roiclassifier.App');
        end
    end
end
