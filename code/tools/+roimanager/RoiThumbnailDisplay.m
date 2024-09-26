classdef RoiThumbnailDisplay < applify.ModularApp & roimanager.roiDisplay
%RoiThumbnailDisplay Widget for displaying a roi thumbnail image
%
%   This widget is created in a container (figure, panel, tab) and is
%   listening to changes on a RoiGroup. If a new roi is selected on the
%   RoiGroup, the display will update and show a thumbnail image of the
%   selected roi. Also, if the roi is modified, the image will update.
%
%   An imagestack can be added to The ImageStack property. If an image is
%   unavailable from a roi object, a new image will be created using the
%   imagestack.

    % Todo:
    %  [ ] get image: get from roi appdata or set to roi appdata.
    
    properties (Constant)
        AppName = 'Roi Thumbnail Display';
    end
    
    properties (Constant) % Inherited from applify.HasTheme via ModularApp
        DEFAULT_THEME = nansen.theme.getThemeColors('dark-gray');
    end
    
    properties
        Dashboard   % Handle for dashboard where thumbnail display is present
    end
    
    properties % Preference-like properties
        ColorMap        % Todo
        ContourColor    % Todo
        SpatialUpsampling = 4 % Factor for spatial upsampling of image.
        ThumbnailSize = [21, 21]
    end
    
    properties
        ActiveChannel = 1
        ImageStack  % Handle of an ImageStack object. Necessary for creating roi images.
        PointerManager
    end
    
    properties (Constant, Hidden)
        IMAGE_TYPES = {'Activity Weighted Mean', 'Diff Surround', ...
            'Top 99th Percentile', 'Local Correlation'};
    end
    
    properties (Access = private) % Handles to graphical objects
        hAxes           % Handle for axes to show image in
        hText           % Handle for text which displays message
        hRoiImage       % Handle for image
        hRoiOutline     % Handle for line to show roi outline
        hContextMenu    % Handle for image contextmenu
        hImageSelector  % Handle for image selector widget
        hCountourToggleButton % Button for toggling visibility of contour
        
        ContextMenuTree % Struct containing contextmenu items.
    end
    
    properties (Access = private) % Internal options
        CurrentImage % Holds image data of current image
        CurrentImageToShow = 'Activity Weighted Mean'
        ShowRoiImageUpdateErrorMessage = false; % Flag for popup dialog.
        WindowKeyPressListener event.listener
    end
    
    methods % Constructor
        
        function obj = RoiThumbnailDisplay(hParent, roiGroup)
        %RoiThumbnailDisplay Create a RoiThumbnailDisplay object.
        %
        %   displayObj = RoiThumbnailDisplay(hParent, roiGroup) creates a
        %   thumbnail display object in the container specified by hParent.
        %
            obj@applify.ModularApp(hParent);
            obj@roimanager.roiDisplay(roiGroup)
            
            obj.createImageDisplayAxes()
            
            obj.initializePointerManager
            
            %obj.createFigureInteractionListeners()
            
            obj.isConstructed = true;
        end
        
        function delete(obj)
            isdeletable = @(x) ~isempty(x) && isvalid(x);
            
            if isdeletable(obj.hContextMenu)
                delete(obj.hContextMenu)
            end
            if isdeletable(obj.WindowKeyPressListener)
                delete(obj.WindowKeyPressListener)
            end
        end
    end
    
    methods (Access = private)
        
        function createImageDisplayAxes(obj)
        %createImageDisplayAxes Create axes for image display
        
            if isa(obj.Panel, 'matlab.graphics.axis.Axes')
                obj.hAxes = obj.Panel;
                obj.Panel = obj.Panel.Parent;
            else
                % Create axes.
                obj.hAxes = axes('Parent', obj.Panel);
                obj.hAxes.Position = [0.05, 0.05, 0.9, 0.9];
            end
            
            obj.hAxes.XTick = [];
            obj.hAxes.YTick = [];
            obj.hAxes.Tag = 'Roi Thumbnail Display';
            obj.hAxes.Color = obj.Panel.BackgroundColor;
            obj.hAxes.Visible = 'off';
            obj.hAxes.PickableParts = 'all'; % In order to respond to pointer
            
        end
        
        function initializePointerManager(obj)
            
            hFigure = ancestor(obj.hAxes, 'figure');
            
            pointerRoot = strjoin({'roimanager', 'pointerTool'}, '.');
            pointerNames = {'selectObject', 'autoDetect'};
            
            getPointerFcn = @(name) str2func(strjoin({pointerRoot, name}, '.'));
            pointerFcn = cellfun(@(name) getPointerFcn(name), pointerNames, 'uni', 0);

            pif = uim.interface.pointerManager(hFigure, obj.hAxes, pointerFcn);
            obj.PointerManager = pif;
            
            % Create function handles:
            
% %             % Add roimanager pointer tools.
% %             for i = 1:numel(pointerNames)
% %                 obj.PointerManager.initializePointers(hAxes, pointerRefs{i})
% %                 obj.PointerManager.pointers.(pointerNames{i}).RoiDisplay = hMap;
% %             end

            % Set default tool.
            obj.PointerManager.defaultPointerTool = obj.PointerManager.pointers.selectObject;
            obj.PointerManager.currentPointerTool = obj.PointerManager.pointers.selectObject;
            
            %obj.PointerManager.pointers.autoDetect.RoiDisplay = obj;
            obj.PointerManager.currentPointerTool.activate();
            
            obj.PointerManager.pointers.autoDetect.UpdateRoiFcn = @obj.updateRoiEstimate;
            obj.PointerManager.pointers.autoDetect.ButtonDownFcn = @obj.updateRoiEstimate;
            obj.PointerManager.pointers.autoDetect.RoiDisplay = obj;

        end
        
        function createFigureInteractionListeners(obj)
            
            hFigure = ancestor(obj.hAxes, 'figure');
            obj.WindowKeyPressListener = listener(hFigure, 'KeyPress', ...
                @obj.onKeyPressed);
            
        end
        
        function createImageMenu(obj)
        %createImageMenu Create image context menu
        
            h = uicontextmenu(ancestor(obj.hAxes, 'figure'));
            obj.ContextMenuTree = struct;
            
            % Todo...
            
% % %             mItem = uimenu(h, 'Text', 'Set Colormap', 'Enable', 'off');
% % %
% % %             mItem = uimenu(h, 'Text', 'Set Image');
% % %             obj.ContextMenuTree.SetImage = mItem;
% % %
% % %             for i = 1:numel(obj.IMAGE_TYPES)
% % %                 hMenuSubItem = uimenu(mItem, 'Text', obj.IMAGE_TYPES{i});
% % %                 hMenuSubItem.Callback = @obj.onSetImageMenuItemClicked;
% % %             end
                
            obj.hContextMenu = h;
            obj.hRoiImage.UIContextMenu = h;
            
            obj.setCurrentImageToShow('Enhanced Average')
        end
        
        function createImageSelector(obj)
        %createImageSelector Create widget for selecting image to view
        
            % Create page indicator
            options = {'Size', [inf, 60], 'Margin', [20, 13, 20, 20], ...
                'Location', 'southwest', 'IndicatorSize', 12, ...
                'SizeMode', 'manual', 'IndicatorColor', ones(1,3)*0.6, ...
                'FontColor', ones(1,3)*0.9, 'BarColor', ones(1,3)*0.9, ...
                'FontSize', 11, 'HorizontalTextAlignment', 'left', ...
                'BarVisibility', 'off', 'TextVisibility', 'hit' };

            uicc = getappdata(obj.Panel, 'UIComponentCanvas');
            if isempty(uicc)
                uicc = uim.UIComponentCanvas(obj.Panel);
            end
            
            pageNames = obj.IMAGE_TYPES;
            obj.hImageSelector = uim.widget.PageIndicator(uicc, pageNames, options{:});
            obj.hImageSelector.ChangePageFcn = @obj.onSetImageTabButtonClicked;
            
            obj.setCurrentImageToShow(obj.IMAGE_TYPES{1})
        end
        
        function recreateImageSelector(obj) % debugging
            delete(obj.hImageSelector)
            obj.createImageSelector()
        end
        
        function createCountourToggleButton(obj)
%             uicc = getappdata(obj.Panel, 'UIComponentCanvas');
%             if isempty(uicc)
%                 uicc = uim.UIComponentCanvas(obj.Panel);
%             end
            
            ICONS = uim.style.iconSet(imviewer.plugin.RoiManager.getIconPath);

            hButton = uim.control.Button_(obj.Panel, 'Icon', ICONS.circle, ...
                'IconSize', [15, 15], ...
                'Mode', 'togglebutton', ...
                'Size', [20, 20], 'SizeMode', 'auto', ...
                'Margin', [20,13,20,30], ...
                'Style', uim.style.buttonSymbol, ...
                'Location', 'northwest', 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', ...
                'HorizontalAlignment', 'left' );
            hButton.Callback = @(s,e)obj.toggleRoiOutline(s);
            obj.hCountourToggleButton = hButton;
            obj.hCountourToggleButton.Value = true;
            obj.hCountourToggleButton.Tooltip = 'Hide Contour';
            obj.hCountourToggleButton.TooltipYOffset = 10;
        end
        
        function createImageTextbox(obj)
        %createImageTextbox Create a textbox in the image display axes
            obj.hText = text(obj.hAxes, 'Units', 'normalized');
            obj.hText.Position(1:2) = [0.5, 0.5];
            obj.hText.String = '';
            obj.hText.Color = ones(1,3)*0.4;
            obj.hText.HorizontalAlignment = 'center';
            obj.hText.FontSize = 12;
            
            if ~isempty(obj.hRoiImage)
                uistack(obj.hText, 'bottom')
            end
        end
        
        function updateImageText(obj, str)
        %updateImageText Update text in image text box
            if isempty(obj.hText) || ~isvalid(obj.hText)
                obj.createImageTextbox()
            end
            obj.hText.String = str;
        end
        
        function createImageDisplay(obj, imageData)
        %createImageDisplay Create the image display
            
            if isempty(obj.hText)
                % Create first for it to be below image in the uistack
                obj.createImageTextbox()
            end
            
            obj.hRoiImage = imshow(imageData, [0, 255], ...
                'Parent', obj.hAxes, 'InitialMagnification', 'fit');
            obj.hRoiImage.HitTest = 'off';
            obj.hRoiImage.PickableParts = 'none';
            
            uistack(obj.hRoiImage, 'bottom')
            
            % set(obj.hRoiImage, 'ButtonDownFcn', @obj.mousePress)
            
            if ~ishold(obj.hAxes)
                hold(obj.hAxes, 'on')
            end

            % obj.createImageMenu() % Todo?
            obj.createImageSelector()
            obj.createCountourToggleButton()
        end
        
        function updateImageDisplay(obj, roiObj)
        %updateImageDisplay Update the displayed image
            
            roiThumbnailImage = obj.getImage(roiObj);
            if isempty(roiThumbnailImage); return; end
            
            obj.CurrentImage = roiThumbnailImage;
            
            if isempty(obj.hRoiImage) % First time. Create image object
                obj.createImageDisplay(roiThumbnailImage)
            else % Update image display:
                set(obj.hRoiImage, 'cdata', roiThumbnailImage);
            end

            % Update x- and y- limits of the axes based on size of image
            imSize = size(roiThumbnailImage);
            set(obj.hAxes, 'XLim', [0,imSize(2)]+0.5, ...
                           'YLim', [0,imSize(1)]+0.5 )
           
            if ~isempty(obj.PointerManager)
                hPointer = obj.PointerManager.pointers.autoDetect;
                hPointer.xLimOrig = obj.hAxes.XLim;
                hPointer.yLimOrig = obj.hAxes.YLim;
            end
                       
            % Update color limits to get the optimal brightness range
            clims = [min(roiThumbnailImage(:)), max(roiThumbnailImage(:))];

            % Make sure upper clim is larger than lower
            if clims(2) <= clims(1)
                clims(2) = clims(1) + 1;
            end
            set(obj.hAxes, 'CLim', clims );
            
            obj.updateRoiContour(roiObj)
            obj.updateImageText('')
        end
        
        function resetImageDisplay(obj)
            set(obj.hRoiOutline, 'XData', nan, 'YData', nan)
            set(obj.hRoiImage, 'cdata', [])
            obj.CurrentImage = [];
        end
        
        function updateRoiContour(obj, roiObj)
        %updateRoiContour Update the contour of a roi in the image display
            
            usFactor = obj.SpatialUpsampling;
            imageSize = size(obj.CurrentImage) ./ usFactor;
            
            ul = roiObj.getUpperLeftCorner([], imageSize);
            roiBoundary = fliplr(roiObj.boundary{1}); % yx -> xy
            %roiBoundary = (roiBoundary - ul + [1,1]) * usFactor;
            roiBoundary = (roiBoundary - ul + [1,1]) * usFactor - [0.5, 0.5];
            % Todo: What's the correct pixel offset? Does it depend on
            % magnification factor?
            
            if isempty(obj.hRoiOutline)
                obj.hRoiOutline = plot(obj.hAxes, roiBoundary(:,1), roiBoundary(:,2), ...
                    'LineStyle', '-', 'Marker', 'None', 'LineWidth', 2 );
                % set(obj.hRoiOutline,  'Color', ones(1,3)*0.9 )
            else
                set(obj.hRoiOutline, 'XData', roiBoundary(:,1), 'YData', roiBoundary(:,2))
            end
        end
        
        function toggleRoiOutline(obj, src)
            
            if src.Value
                obj.hRoiOutline.Visible = 'on';
                obj.hCountourToggleButton.Tooltip = 'Hide Contour';
            else
                obj.hRoiOutline.Visible = 'off';
                obj.hCountourToggleButton.Tooltip = 'Show Contour';
            end
        end
        
        function im = getImage(obj, roiObj)
        %getImage Get roi thumbnail image based on current settings
                        
            imageVarName = strrep(obj.CurrentImageToShow, ' ', '');
            roiImageData = getappdata(roiObj, 'roiImages');
           
            if isfield(roiImageData, imageVarName)
                im = roiImageData.(imageVarName);
                if all(im(:) == 0 )
                    im = obj.createRoiImage(roiObj);
                end
                if ~isempty(im)
                    roiImageData.(imageVarName) = im;
                end
            else
                im = obj.createRoiImage(roiObj);
            end

            if isempty(im)
                obj.updateImageText('Image not available')
                return;
            end
            
            % Perform spatial resampling of image
            im = imresize(im, obj.SpatialUpsampling);
            
        end
        
        function im = createRoiImage(obj, roiObj)
        %createRoiImage Create a roi image from an ImageStack
            
            import nansen.twophoton.roi.compute.computeRoiImages
            import nansen.twophoton.roisignals.extractF
            import nansen.twophoton.roisignals.computeDff
            
            im = [];
            if isempty(obj.ImageStack); return; end
                
            imArray = obj.ImageStack.getFrameSet('cache', [], 'C', obj.ActiveChannel);
            imArray = squeeze(imArray);

            if ndims(imArray) > 3
                % Todo, throw error or display message...
                return
            end

            if size(imArray, 3) < 100
                if obj.ShowRoiImageUpdateErrorMessage
                    obj.createImageTextbox()
                    obj.updateImageText('Roi image not available')
                    obj.Dashboard.displayMessage('Can not update roi image because there are not enough image frames in memory')
                    obj.ShowRoiImageUpdateErrorMessage = false;
                end
                im = [];
                return
            end
            
            roiSignals = extractF(imArray, roiObj);
            
            im = computeRoiImages(imArray, roiObj, roiSignals, ...
                'ImageType', obj.CurrentImageToShow, ...
                'dffFcn', 'dffRoiMinusDffNpil', ...
                'BoxSize', obj.ThumbnailSize);
        end
        
        function setCurrentImageToShow(obj, name)
            
            if strcmp(obj.CurrentImageToShow, name); return; end
            
            obj.CurrentImageToShow = name;
            
            if ~isempty(obj.ContextMenuTree)
                if isfield( obj.ContextMenuTree, 'SetImage' )
                    hMenuItems = obj.ContextMenuTree.SetImage.Children;
                    set(hMenuItems, 'Checked', 'off')
                    isMatch = strcmp({hMenuItems.Text}, name);
                    set(hMenuItems(isMatch), 'Checked', 'on')
                end
            end
            
            if ~isempty(obj.VisibleRois)
                roiObj = obj.RoiGroup.roiArray(obj.VisibleRois);
                obj.updateImageDisplay(roiObj)
                obj.updateEstimatedRoi()
            end
        end
        
        function [imageName, imageIdx] = getImageName(obj, token)
            
            idx = find( strcmp(obj.IMAGE_TYPES, obj.CurrentImageToShow) );
            numImages = numel(obj.IMAGE_TYPES);
            
            switch token
                case 'next'
                    newIdx = mod(idx, numImages) + 1; % Next with reset.
                case 'previous'
                    newIdx = numImages - mod(-idx+1, numImages); % Previous with reset.
            end
            
            imageName = obj.IMAGE_TYPES{newIdx};
            
            if nargout == 2
                imageIdx = newIdx;
            end
        end
    end
    
    methods (Access = protected) % Inherited from applify.ModularApp

        % use for when restoring figure size from maximized
        function pos = initializeFigurePosition(obj)
            initPos = initializeFigurePosition@applify.ModularApp(obj);
            pos = obj.getPreference('Position', initPos);
        end

        function resizePanel(obj, src, evt)
            
            posAxes = getpixelposition(obj.hAxes);
            posPanel = getpixelposition(obj.Panel);
            obj.hImageSelector.Margin(1:2) = posAxes(1:2)+[10,5];
            obj.hCountourToggleButton.Margin(1) = posAxes(1)+10;
            obj.hCountourToggleButton.Margin(4) = posPanel(4) - sum(posAxes([2,4])) + 5;

        end
        
        function onThemeChanged(obj)
            onThemeChanged@applify.ModularApp(obj)
            if isa(obj.Parent, 'matlab.ui.container.Panel')
                obj.Panel.BackgroundColor = obj.Parent.BackgroundColor;
            end
        end
    end
    
    methods (Access = private)
        
        function updateEstimatedRoi(obj)
            if ~isempty(obj.PointerManager)
                if isa( obj.PointerManager.currentPointerTool, ...
                        'roimanager.pointerTool.autoDetect' )
                    obj.PointerManager.currentPointerTool.updateRoi()
                end
            end
        end
        
        % Todo implement modes (combine with roiMap method):
        function newRoi = updateRoiEstimate(obj, x, y, r, autodetectionMode, doReplace)
                      IM = obj.CurrentImage;
            if isempty(IM); newRoi = RoI.empty; return; end
            
            imSize = size(IM);
            
            centerOffset = imSize/2 - [y,x]; %./obj.SpatialUpsampling;
            IM = circshift( IM, round(centerOffset) );
            %IM = imtranslate(IM, fliplr( round(centerOffset) ));

            roiMask = flufinder.binarize.findSomaMaskByEdgeDetection(IM, ...
            'us', 1);
            roiMask = circshift( roiMask, -round(centerOffset) );
 
            newRoi = RoI('Mask', roiMask, imSize);%roiMask;

            if ~nargout
                i = obj.VisibleRois;
                currentRoi = obj.RoiGroup.roiArray(i);
                fovMask = false(currentRoi.imagesize);
                roiMask = imresize(roiMask, 1/obj.SpatialUpsampling);
                roiMask = flufinder.utility.placeLocalRoiMaskInFovMask(roiMask, currentRoi.center, fovMask);
                newRoi = RoI('Mask', roiMask);
                
                obj.RoiGroup.modifyRois(newRoi, i)
                clear newRoi
            end
        end
    end
    
    methods (Access = protected) % Inherited from roimanager.roiDisplay
        
        function onRoiGroupChanged(obj, evtData)
        %onRoiGroupChanged Callback for RoiGroupChanged event.
        %
        %   If a roi is modified, the image should be updated.
                    
            % Take action for this EventType
            switch lower(evtData.eventType)

                case {'modify', 'reshape'}
                    
                    if isempty(evtData.roiIndices)
                        return
                    end
                    
                    roiIdx = evtData.roiIndices(end);
                    % Update image if the displayed roi was modified
                    if isequal(roiIdx, obj.VisibleRois)
                        roi = obj.RoiGroup.roiArray(roiIdx);
                        obj.updateImageDisplay(roi)
                        obj.updateEstimatedRoi()
                    end
                    
                otherwise
                    % Do nothing...
            end
        end
        
        function onRoiSelectionChanged(obj, evtData)
        %onRoiSelectionChanged Callback for RoiSelectionChanged event
        %
        %   Update the image display with an image of the selected roi
        
            if isempty(evtData.NewIndices)
                obj.resetImageDisplay()
                obj.updateImageText('No roi selected')
                obj.VisibleRois = [];
            else
                roiIdx = evtData.NewIndices(end);
                roi = obj.RoiGroup.roiArray(roiIdx);
                obj.updateImageDisplay(roi)
                obj.VisibleRois = roiIdx;
                obj.updateEstimatedRoi()
            end
        end
        
        function onRoiClassificationChanged(obj, evtData)
            % Do nothing
        end
    end
    
    methods (Access = private)
        
        function onSetImageMenuItemClicked(obj, src, evt)
            obj.setCurrentImageToShow(src.Text);
        end
        
        function onSetImageTabButtonClicked(obj, src, evt)
            imageName = src.PageNames{evt.NewPageNumber};
            obj.setCurrentImageToShow(imageName);
        end
    end
    
    methods % Implement abstract methods from
        function addRois(~)
            % This class can not add rois
        end
        
        function removeRois(obj)
            % This class can not remove rois
        end
    end
    
    methods
        
        function tf = hittest(obj, src, evt)
            tf = ~isempty(obj.VisibleRois);
        end
    end
    
    methods (Access = {?applify.ModularApp, ?applify.DashBoard} )
        
        function onKeyPressed(obj, src, evt)
                
            if obj.isMouseInApp
                if ~isempty(obj.PointerManager)
                    wasCaptured = obj.PointerManager.onKeyPress(src, evt);
                    if wasCaptured; return; end
                end
            end
            
            switch evt.Character
                case '>'
                    [imageName, imageIdx] = obj.getImageName('next');
                    obj.setCurrentImageToShow(imageName);
                    obj.hImageSelector.changePage(imageIdx)

                case '<'
                    [imageName, imageIdx] = obj.getImageName('previous');
                    obj.setCurrentImageToShow(imageName);
                    obj.hImageSelector.changePage(imageIdx)
            end
        end
    end
end
