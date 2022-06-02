classdef RoiManager < applify.mixin.AppPlugin & roimanager.RoiGroupFileIoAppMixin
%imviewer.plugin.RoiManager Open the roimanager tool as a plugin in imviewer
    
    % Todo:
        % Organize submodules from this class.
        %   I.e pointerManagers should be created and customized here,
        %   and also notify about events that are relevant for other
        %   modules. 
        %   Specific: 
        %    1. should a polydraw finish operation happen here
        %       or in the polydraw tool?
        %    2. Should toggling of pointer tools go through here. Need to
        %       keep drack of polydraw vs editdraw etc...
        %
        % Implement settings.
    
    %   Signals are computed twice. Signal array and getRoiStats
    %   Signal extraction takes twice the amount time.
        
    properties (Constant, Hidden = true) % Inherited from applify.mixin.UserSettings via AppPlugin
        USE_DEFAULT_SETTINGS = false
        DEFAULT_SETTINGS = imviewer.plugin.RoiManager.getDefaultSettings()
        ICONS = uim.style.iconSet(imviewer.plugin.RoiManager.getIconPath)
    end
    
    properties (Constant) % Inherited from uim.applify.AppPlugin
        Name = 'Roimanager'
    end
    
    properties %(SetAccess = protected)
        CreateContextMenu = true  % Boolean flag : Should contextmenu be created.
    end
    
    properties
        PrimaryAppName = 'imviewer'
    end
    
    properties 
        RoiGroup
        roiFilePath             % RM
    end
    
    properties (Access = protected)

        roiDisplay
        
        secondaryGroups % Todo: merge this with roiGroup
        secondaryMaps % Todo: merge this with roiDisplay
        
        roiSignalArray          % RM
        ImageDataCache struct
        
        signalOptions           % ?
        deconvolutionOptions    % ?
        
        PointerManager
        
        StackViewer             % Dashboard?
        SignalViewer            % Dashboard?
        
    end
    
    properties (Access = protected)
        KeyPressListener = event.listener.empty
        MapUpdateListener = event.listener.empty
        hMenu
                
        ImageStackChangedListener
        ImageDataChangedListener

        SignalViewerDeletedListener % Dashboard, RM ?
    end

    
    methods % Structors
        
        function obj = RoiManager(varargin)
            
            [nvPairs, varargin] = utility.getnvpairs(varargin);
            
            % Note: hImviewer will be empty if varargin is empty.
            hImviewer = imviewer.plugin.RoiManager.validateApp(varargin{:});
            
            % Pass potential imviewer handle to superclass constructor.
            obj@applify.mixin.AppPlugin(hImviewer, [], nvPairs{:});

            % Plugin already existed, and obj was reassigned in superclass
            if obj.IsActivated
                if ~nargout; clear obj; end
                return
            end

            % if imviewer was empty, we return here
            if ~isempty(hImviewer)
                obj.activatePlugin(hImviewer)
            end

            if ~nargout; clear obj; end
        end
        
        function delete(obj)
            % todo: Clean up all handles belonging to this class
            % Do I need to delete roiDisplay or is it automatically
            % deleted?
            %
            % Check is roiGroup has unsaved changes, and save those
        end
        
    end
    
    methods (Access = {?applify.mixin.AppPlugin, ?applify.AppWithPlugin} ) % Callbacks
        
        function wasCaptured = keyPressHandler(obj, src, event)
            wasCaptured = true; %Guilty until proven innocent c-^_^-?
            
            switch event.Key
                case 'space'
                    obj.switchRoiOutlineVisibility()
                    
                case 'i'
                    obj.roiDisplay.improveRois();

                    
                otherwise
                    wasCaptured = false;
            end
        end
        
    end
    
    methods
        function activatePlugin(obj, h)

            hImviewer = imviewer.plugin.RoiManager.validateApp(h);
            activatePlugin@applify.mixin.AppPlugin(obj, hImviewer)

        end
    end
    
    methods (Access = protected)
        
        function onConstruction(obj)
            % Todo?
            % Initialize a roi map and store in the roiDisplay property
            obj.RoiGroup = roimanager.roiGroup();
        end
        
        function onPluginActivated(obj)
                                 
            obj.PrimaryApp.displayMessage('Activating roimanager...', [], 2)

            [obj.StackViewer, hImviewer] = deal( obj.PrimaryApp );

            hAxes = hImviewer.Axes;
            
            % Update menu, by adding some roimanager options:
            if obj.CreateContextMenu
                obj.createMenu()
            end
            
            obj.RoiGroup = roimanager.roiGroup();
            obj.RoiGroup.ParentApp = obj.PrimaryApp;
            
            obj.roiDisplay = roimanager.roiMap(hImviewer, hAxes, obj.RoiGroup);
            
            % Assign the Ancestor App of the roigroup to the app calling
            % for its creation.
            obj.roiDisplay.RoiGroup.ParentApp = hImviewer;
            obj.roiDisplay.hRoimanager = obj;
            
            obj.initializePointerTools()
            
            obj.addButtonsToToolbar % Do this after creating pointertools.
            obj.PrimaryApp.clearMessage()
            
            
            obj.ImageStackChangedListener = addlistener(obj.StackViewer, ...
                'ImageStack', 'PostSet', @obj.onImageStackChanged);
            
        end
        
        function onSettingsChanged(obj, name, value)
        %onSettingsChanged Callback for value change on a settings field.
        
        obj.settings.(name) = value;
        
            switch name
                case 'showTags'
                    % Todo: Change this to roi labels... Just for testing
                    obj.toggleShowRoiOutlines('', value)
                case 'colorRoiBy'
                    obj.roiDisplay.updateRoiColors(1:obj.RoiGroup.roiCount)
                    if strcmp(value, 'Activity Level')
                        obj.PrimaryApp.displayMessage('Not implemented yet')
                        pause(1.5)
                        obj.PrimaryApp.clearMessage()
                    end
            end
        end
        
        function changeCurrentRoiGroup(obj, newGroupName)
            
            newGroupNumberStr = strrep(newGroupName, 'Group ', ''); 
            newGroupNumber = round( str2double(newGroupNumberStr) );
            if newGroupNumber == 1
                newMap = obj.roiDisplay;
                newGroup = obj.RoiGroup;
            else
                newMap = obj.secondaryMaps(newGroupNumber-1);
                newGroup = obj.secondaryGroups(newGroupNumber-1);
            end
            
            obj.PointerManager.pointers.selectObject.RoiDisplay = newMap;
           
            obj.roiSignalArray.RoiGroup = newGroup;
            obj.SignalViewer.RoiGroup = newGroup;

        end
        
        function changeVisibleRoiGroups(obj, newValue)
            
            allMaps = [obj.roiDisplay, obj.secondaryMaps];
            numMaps = numel(allMaps);
            
            isVisible = false(1, numMaps);

            
            if strcmp(newValue, 'Show All')
                isVisible(:) = true;
            else
                numberStr = strrep(newValue, 'Show Group ', ''); 
                newNumber = round( str2double(numberStr) );
                isVisible(newNumber) = true;
            end
            
            for i = 1:numMaps
                if isVisible(i)
                    allMaps(i).Visible = 'on';
                else
                    allMaps(i).Visible = 'off';
                end
            end
            
            
        end
        
        
% % % % Context menu item callbacks (Roi map visibility states)
        
        function toggleShowRoiRelations(obj, src)
            
            % Get handle to menuItem
            if nargin < 2
                mItem = findobj(obj.hMenu, '-regexp', 'Text', 'Roi Relations');
            else
                mItem = src;
            end
            
            switch mItem.Text
                case 'Show Roi Relations'
                    obj.roiDisplay.showRoiRelations()
                case 'Hide Roi Relations'
                    obj.roiDisplay.hideRoiRelations()
            end
            
            % NB: Do this last
            utilities.toggleUicontrolLabel(mItem, 'Show', 'Hide');
            
        end
        
        function onShowRoiOutlinesMenuItemClicked(obj, src)
            switch src.Text
                case 'Show Roi Outlines'
                    obj.switchRoiOutlineVisibility(true)
                case 'Hide Roi Outlines'
                    obj.switchRoiOutlineVisibility(false)
            end
        end
        
        function onShowRoiLabelsMenuItemClicked(obj, src)
            switch src.Text
                case 'Show Roi Outlines'
                    obj.switchRoiLabelVisibility(true)
                case 'Hide Roi Outlines'
                    obj.switchRoiLabelVisibility(false)
            end
        end
        
        function onMaskRoiInteriorMenuItemClicked(obj, src)
            switch src.Text
                case 'Mask Roi Interior'
                    obj.switchMaskRoiInteriorState(true)
                case 'Show Roi Interior'
                    obj.switchMaskRoiInteriorState(false)
            end
        end
        
        
% % % % Methods for manipulating what is shown in the viewer.
        
        % TODO: Make sure settings value corresponds. Not needed now,
        % because only onsettingsChanged will call these methods...
        
        function switchRoiOutlineVisibility(obj, value)
            if nargin < 2; value = ~obj.roiDisplay.roiOutlineVisible; end
            obj.roiDisplay.roiOutlineVisible = value;
            obj.updateContextMenu('Roi Outlines')
        end
        
        function switchRoiLabelVisibility(obj, value)
            obj.roiDisplay.roiLabelVisible = value;
            obj.updateContextMenu('Text Labels')
        end
        
        function switchMaskRoiInteriorState(obj, value)
            obj.roiDisplay.MaskRoiInterior = value;
            obj.updateContextMenu('Roi Interior')
        end
        
        
    end
    
    methods (Access = protected) % RoiGroupFileIoAppMixin methods
                   
        function initPath = getRoiInitPath(obj)
        %getRoiInitPath Get path to start uigetfile or uiputfile
        
            if ~isempty(obj.roiFilePath)
                initPath = obj.roiFilePath;
            else
                initPath = obj.PrimaryApp.ImageStack.FileName;
                initPath = fileparts(initPath);
                [parentDir, name] = fileparts(initPath);
                if strcmp(name, 'reg_tif') % suite2p
                    initPath = parentDir;
                elseif isfolder(fullfile(parentDir, 'roi_data')) % nansen
                    initPath = fullfile(parentDir, 'roi_data');
                end
            end
        end

    end
    
    methods (Access = private) % Initialization
        
        function initializePointerTools(obj)
            % Todo: fetch from constructor...
            
            % Find the handle to the pointerManager
            
            pointerRoot = strjoin({'roimanager', 'pointerTool'}, '.');

            
            hViewer = obj.PrimaryApp;
            hAxes = obj.PrimaryApp.Axes;
            hMap = obj.roiDisplay;
            
            
            isMatch = contains({hViewer.plugins.pluginName}, 'pointerManager');
            obj.PointerManager = hViewer.plugins(isMatch).pluginHandle;
            
            
            pointerNames = {'selectObject', 'polyDraw', 'circleSelect', 'autoDetect', 'freehandDraw'};
            
            % Create function handles:
            pointerRefs = cellfun(@(name) str2func(strjoin({pointerRoot, name}, '.')), pointerNames, 'uni', 0);
            
            % Add roimanager pointer tools.
            for i = 1:numel(pointerNames)
                obj.PointerManager.initializePointers(hAxes, pointerRefs{i})
                obj.PointerManager.pointers.(pointerNames{i}).RoiDisplay = hMap;
            end

            % Set default tool.
            obj.PointerManager.defaultPointerTool = obj.PointerManager.pointers.selectObject;
            obj.PointerManager.currentPointerTool = obj.PointerManager.pointers.selectObject;
            
        end
        
        function addButtonsToToolbar(obj)
            
            hImviewer = obj.PrimaryApp;
            
            % Add toolbar buttons for the pointertools.
            hToolbar = hImviewer.uiwidgets.Toolbar;
            hToolbar.addSeparator()
            hToolbar.addButton('Icon', obj.ICONS.polydraw, 'Type', 'togglebutton', 'Tag', 'polyDraw', 'Tooltip', 'Polydraw (d)')
            hToolbar.addButton('Icon', obj.ICONS.freehand, 'Type', 'togglebutton', 'Tag', 'freehand', 'Tooltip', 'Draw freehand (t)')
            hToolbar.addButton('Icon', obj.ICONS.magicWand, 'Type', 'togglebutton', 'Tag', 'autoDetect', 'Tooltip', 'Autodetect (a)')
            hToolbar.addButton('Icon', obj.ICONS.circle, 'Type', 'togglebutton',  'Tag', 'circleSelect', 'Tooltip', 'Circular (o)')
            hToolbar.addButton('Icon', obj.ICONS.circleGrow2, 'Type', 'pushbutton', 'Tag', 'growCircle', 'Tooltip', 'Grow circle (g)')
            hToolbar.addButton('Icon', obj.ICONS.circleShrink2, 'Type', 'pushbutton', 'Tag', 'shrinkCircle', 'Tooltip', 'Shrink circle (h)')   
            hToolbar.Visible = 'off';
            
            % Add callbacks to button pushes and listener for tool toggle
            % events.
            hBtn = hImviewer.uiwidgets.Toolbar.getHandle('polyDraw');
            hBtn.Callback = @(s,e,h,str) togglePointerMode(obj.PointerManager, 'polyDraw');
            hBtn.addToggleListener(obj.PointerManager.pointers.polyDraw, 'ToggledPointerTool')
            
            hBtn = hImviewer.uiwidgets.Toolbar.getHandle('freehand');
            hBtn.Callback = @(s,e,h,str) togglePointerMode(obj.PointerManager, 'freehandDraw');
            hBtn.addToggleListener(obj.PointerManager.pointers.freehandDraw, 'ToggledPointerTool')
            
            hBtn = hImviewer.uiwidgets.Toolbar.getHandle('autoDetect');
            hBtn.Callback = @(s,e,h,str) togglePointerMode(obj.PointerManager, 'autoDetect');
            hBtn.addToggleListener(obj.PointerManager.pointers.autoDetect, 'ToggledPointerTool')
                        
            hBtn = hImviewer.uiwidgets.Toolbar.getHandle('circleSelect');
            hBtn.Callback = @(s,e,h,str) togglePointerMode(obj.PointerManager, 'circleSelect');
            hBtn.addToggleListener(obj.PointerManager.pointers.circleSelect, 'ToggledPointerTool')
            
            hBtn = hImviewer.uiwidgets.Toolbar.getHandle('growCircle');
            hBtn.Callback = @(s,e, h, r) obj.PointerManager.pointers.circleSelect.changeCircleRadius(1);
            
            hBtn = hImviewer.uiwidgets.Toolbar.getHandle('shrinkCircle');
            hBtn.Callback = @(s,e, h, r) obj.PointerManager.pointers.circleSelect.changeCircleRadius(-1);
            
            hToolbar.Visible = 'off';
            
            %hToolbar.onVisibleChanged()
            % Call this explicitly, 
            % incase toolbar visibility was already off. Todo, find
            % different solution. E.g., toolbar/widget could have dirty
            % property...
            
        end
        
        function createMenu(obj, hMenu)

            if nargin < 2
                hMenu = findobj(obj.PrimaryApp.Figure, 'Text', 'Open Roimanager');
            end
            
            hMenu.Text = 'Roimanager';
            hMenu.Callback = [];
            
            mItem = uimenu(hMenu, 'Text', 'Load Rois');
            mItem.Callback = @(s, e) obj.importRois();
%             mitem.Accelerator = 'l';

%             mitem = uimenu(m, 'Text', 'Load Rois...');
%             mitem.Callback = @(s, e, pstr) obj.importRois('');
            
            mItem = uimenu(hMenu, 'Text', 'Save Rois');
            mItem.Callback = @(s, e) obj.saveRois();
%             mitem.Accelerator = 's';

            mItem = uimenu(hMenu, 'Text', 'Show...', 'Separator', 'on');
            
            mSubItem = uimenu(mItem, 'Text', 'Show Text Labels', 'Enable', 'off');
            mSubItem.Callback = @(s,e) obj.onShowRoiLabelsMenuItemClicked(s);
            
            mSubItem = uimenu(mItem, 'Text', 'Hide Roi Outlines');
            mSubItem.Callback = @(s,e) obj.onShowRoiOutlinesMenuItemClicked(s);
            
            mSubItem = uimenu(mItem, 'Text', 'Hide Roi Relations');
            mSubItem.Callback = @(s,e) obj.toggleShowRoiRelations(s);
            
            mSubItem = uimenu(mItem, 'Text', 'Mask Roi Interior');
            mSubItem.Callback = @(s,e) obj.onMaskRoiInteriorMenuItemClicked(s);
            
            mItem = uimenu(hMenu, 'Text', 'Run Autosegmentation', 'Separator', 'on');
            mItem.Callback = @(s, e) obj.runAutoSegmentation();
            
            mItem = uimenu(hMenu, 'Text', 'Classify Rois');
            mItem.Callback = @(s, e) obj.openRoiClassifier();
            
            mItem = uimenu(hMenu, 'Text', 'Open Signal Viewer', 'Separator', 'on');
            mItem.Callback = @(s, e) obj.openSignalViewer();
            
            mItem = uimenu(hMenu, 'Text', 'Extract Signals...');
            mItem.Callback = @(s, e) obj.extractSignals();
            
            mItem = uimenu(hMenu, 'Text', 'Signal Extraction Settings');
            %mItem.Callback = @(s, e) obj.editSignalExtractionSettings;
            
            mItem = uimenu(hMenu, 'Text', 'Deconvolution Settings');
            mItem.Callback = @(s, e) obj.editDeconvolutionSettings;
            
            mItem = uimenu(hMenu, 'Text', 'Edit Settings', 'Enable', 'off', 'Separator', 'on');
            mItem.Callback = [];
            
            mitem = uimenu(hMenu, 'Text', 'Export Video');
            mitem.Callback = @(s,e) imviewer.plugin.RoiSignalVideo(obj.PrimaryApp); % Todo: update reference.
            
            obj.hMenu = hMenu;
            
        end
        
        function updateContextMenu(obj, name, propName)
            
            %if isempty(obj.ContextMenu); return; end
            if isempty(obj.hMenu); return; end
            
            if nargin < 3; propName = 'Checked'; end
            
            mItem = findobj(obj.hMenu, '-regexp', 'Text', name);
            if isempty(mItem); return; end
            
            switch name
                    
                case 'Roi Outlines'
                    if obj.roiDisplay.roiOutlineVisible
                        newMenuTextLabel = 'Hide Roi Outlines';
                    else
                        newMenuTextLabel = 'Show Roi Outlines';
                    end
                    
                case 'Text Labels'
                    if obj.roiDisplay.roiLabelVisible
                        newMenuTextLabel = 'Hide Text Labels';
                    else
                        newMenuTextLabel = 'Show Text Labels';
                    end
                    
                case {'Show Roi Interior', 'Mask Roi Interior', 'Roi Interior'}
                    if obj.roiDisplay.MaskRoiInterior
                        newMenuTextLabel = 'Show Roi Interior';
                    else
                        newMenuTextLabel = 'Mask Roi Interior';
                    end
                    
            end
            
            set(mItem, 'Text', newMenuTextLabel)
                    
        end
    end
    
    methods % User methods.
        
        function [initPath, fileName] = getInitPath(obj)
            
            if ~isempty(obj.roiFilePath)
                initPath = obj.roiFilePath;
            else
                initPath = obj.PrimaryApp.filePath;
            end

            if exist(initPath, 'file') == 2
                [initPath, fileName, ~] = fileparts(initPath);
            end
            
            if ~exist('fileName', 'var')
                fileName = 'unnamed';
            end
        
        end
              
        function rois = loadRois(obj, loadPath)
        %loadRois Load rois and add them to app
        
            obj.PrimaryApp.displayMessage('Loading Rois...')
            C = onCleanup(@(s,e) obj.PrimaryApp.clearMessage);
           
            try
                rois = loadRois@roimanager.RoiGroupFileIoAppMixin(obj, loadPath);
            catch ME
                clear C % Reset message display
                obj.PrimaryApp.displayMessage(['Error: ', ME.message], [], 2)
                if nargout; rois = []; end
                return
            end
            
             %msg = lastwarn;
            %if ~isempty(msg); obj.PrimaryApp.displayWarning(); end  %Todo
            
            % Todo: Current group / Current channel / Current plane...
            currentRoiGroup = obj.RoiGroup;
            loadedRoiGroup = rois;
            if ~nargout; clear rois; end
            
            % If rois already exist, determine how to add new ones
            if ~isempty(currentRoiGroup.roiArray)
                % If the loaded rois are identical, abort here
                if isequal(currentRoiGroup.roiArray, loadedRoiGroup.roiArray)
                    return
                else
                    addMode = obj.uiGetModeForAddingRois();
                end
            else
                addMode = 'initialize';
            end
            
            % Todo: Check that the imagesize of rois match the imagesize of
            % the loaded images, and take appropriate action if not!
% %             imSize = [obj.imHeight, obj.imWidth] %<- Todo...
% %             if ~assertImageSize(loadedRoiGroup.roiArray, imSize)
% %                 for i = 1:numel(loadedRoiGroup.roiArray)
% %                     loadedRoiGroup.roiArray(i).imagesize = imSize;
% %                 end
% %             end
            
            
            % If rois should be replaced, remove current rois. Also remove
            % overlapping rois if that is requested.
            switch addMode
                case 'replace'
                    roiInd = 1:currentRoiGroup.roiCount;
                    currentRoiGroup.removeRois(roiInd);
                
                case 'append non-overlapping'
                    addMode = 'append';
                    
                    [iA, ~] = roimanager.utilities.findOverlappingRois(...
                    	loadedRoiGroup.roiArray, currentRoiGroup.roiArray);
                    
                    loadedRoiGroup.removeRois(iA)
            end
                        
            obj.RoiGroup.addRois(loadedRoiGroup, [], addMode)
            
            if strcmp(addMode, 'replace') || strcmp(addMode, 'initialize')
                obj.RoiGroup.markClean()
            end
        end
        
        function saveRois(obj, initPath)
        %saveRois Save rois with confirmation message in app.    
            if nargin < 2; initPath = ''; end
            saveRois@roimanager.RoiGroupFileIoAppMixin(obj, initPath)
            
            saveMsg = sprintf('Rois Saved to %s\n', obj.roiFilePath);            
            obj.PrimaryApp.displayMessage(saveMsg, 2)
        end

        function addRois(obj, roiArray)
            obj.RoiGroup.addRois(roiArray, [], 'append')
        end
        
        function newGroup = createNewRoiGroup(obj)
            
            newGroup = roimanager.roiGroup();
            newRoiMap = roimanager.roiMap(obj.StackViewer, obj.StackViewer.Axes, newGroup);

            numGroups =  numel(obj.secondaryGroups);
            
            if numGroups == 0
                obj.secondaryGroups = newGroup;
                obj.secondaryMaps = newRoiMap;
            else
                obj.secondaryGroups(end+1) = newGroup;
                obj.secondaryMaps(end+1) = newRoiMap;

            end

            
            % Assign the Ancestor App of the roigroup to the app calling
            % for its creation.
            newRoiMap.RoiGroup.ParentApp = obj.StackViewer;
            newRoiMap.hRoimanager = obj;
            
            colorMap=cbrewer('qual', 'Set1', 8, 'spline');
            newRoiMap.defaultColor = colorMap(numGroups+1, :);

            % Todo: What if this is not created yet....Need to add to
            % settings....?
            % Add group to settings controls...
            numGroups = numel(obj.secondaryGroups) + 1;
            
            
            % Todo. What if this panel was not opened yet?!?!?
            if ~isprop(obj, 'AppModules') || isempty( obj.AppModules(4) )
                return
            end
            
            % Todo: Simplify?
            if isfield(obj.AppModules(4).hControls, 'setCurrentRoiGroup')
                obj.AppModules(4).hControls.setCurrentRoiGroup.String{end+1} = sprintf('Group %d', numGroups);
                obj.AppModules(4).hControls.showRoiGroups.String{end+1} = sprintf('Show Group %d', numGroups);            
            end
        end
                
        function mode = uiGetModeForAddingRois(obj)
        %uiGetModeForAddingRois Ask user for how to add rois    
        
            message = 'Should new rois replace current rois?';
            title = 'Options for Loading New Rois';
            alternatives = {'Replace', 'Append', 'Append non-overlapping'};
            defaultChoice = 'Append';
            
            mode = questdlg(message, title, alternatives{:}, defaultChoice);
            mode = lower(mode);
            
        end
        
        % Todo: Should belong to roimap:
        function improveRois(obj)
            obj.roiDisplay.improveRois()
        end
        
% % % % 

        function Y = prepareImagedata(obj, opts)
        
            if nargin < 2
                opts = obj.settings.Autosegmentation;
            end
        
            global fprintf
            fprintf = @(varargin) obj.PrimaryApp.updateMessage(varargin{:});
            
            % Get imageStack from viewer
            hImageStack = obj.PrimaryApp.ImageStack;
            
            % Determine which frames to use:
            firstFrame = opts.firstFrame;
            lastFrame = min([firstFrame + opts.numFrames - 1, hImageStack.NumFrames]);
            
            frameInd = firstFrame:lastFrame;
            
            if ~isempty( obj.ImageDataCache )
                if isequal(obj.ImageDataCache.FrameInd, frameInd) && ...
                    isequal(obj.ImageDataCache.DownSamplingFactor, opts.downsamplingFactor)
                    Y = obj.ImageDataCache.Data; return
                end
            end

            loadOpts = struct('target', 'Add To Memory');
            Y = obj.PrimaryApp.loadImageFrames(frameInd, loadOpts);
            
            % Create moving average video.
            if opts.downsamplingFactor > 1 
                fprintf('Downsampling image data\n')
                dsFactor = opts.downsamplingFactor;
                Y = stack.process.framebin.mean(Y, dsFactor); % Adapt this to virtual stack
                obj.PrimaryApp.clearMessage()
            end
            
            
% % %             Todo: implement image mask from avg image. Ie, if image has
% % %             black regions.
% % %             mask = hImageStack.getProjection('mean') ~= 0;
% % %             mask = imdilate(mask, strel('disk', 5));
% % %             Y = cast(mask, 'like', Y) .* Y; % Adapt this to virtual stack

            
            % Add data to cache.
            obj.ImageDataCache = struct();
            obj.ImageDataCache.FrameInd = frameInd;
            obj.ImageDataCache.DownSamplingFactor = opts.downsamplingFactor;
            obj.ImageDataCache.Data = Y;
        end

        function runAutoSegmentation(obj)
        % Calls autodetection package from Pnevmatikakis et al (Paninski)
        % and adds detected rois to gui

            import nansen.twophoton.autosegmentation.*
            import nansen.wrapper.*
            global fprintf
            fprintf = @(varargin) obj.PrimaryApp.updateMessage(varargin{:});

            obj.PrimaryApp.uiwidgets.msgBox.activateGlobalWaitbar()

            
            % Prepare data
            Y = obj.prepareImagedata(obj.settings.Autosegmentation);
            if ~isa(Y,'single'); Y = single(Y);  end    % convert to single

            
            % Call autosegmentation method with options...
           
            methodName = obj.settings.Autosegmentation.autosegmentationMethod;
            methodOptions = obj.settings.Autosegmentation.options;

            fprintf('Initializing roi autosegmentation using %s', methodName)

            
            if isempty(methodOptions)
                methodOptions = obj.getAutosegmentDefaultOptions(methodName);
            end
            
            [im, stat] = deal([]);
            
            switch lower(methodName)
                
                case 'quicky'
                    opts = nansen.wrapper.quicky.Options.convert(methodOptions);
                    foundRois = flufinder.runAutoSegmentation(Y, opts);

                case 'suite2p'
                    opts = suite2p.Options.convert(methodOptions);
                    tic; foundRois = suite2p.run(Y, opts); toc

                case 'extract'
                    opts = nansen.wrapper.extract.Options.convert(methodOptions);
                    tic; [foundRois, im, stat] = extract.run(Y, opts); toc
                    
                case 'cnmf'

                    
            end
            
            obj.PrimaryApp.uiwidgets.msgBox.deactivateGlobalWaitbar()

            
            
            mask = mean(Y,3) == 0;
            mask = imdilate(mask, strel('disk', 5));

            % Check and remove rois that are close to the edge of the image.
            isBoundaryRoi = arrayfun(@(roi) roi.isOnBoundary, foundRois);
            isOutside = foundRois.isOverlap(mask);
            keep = ~isBoundaryRoi & ~isOutside';

            foundRois = foundRois(keep);
            foundRois.setappdata('roiClassification', zeros(numel(foundRois), 1));
            
            if ~isempty(im)
                im = im(keep);
                foundRois = foundRois.setappdata('roiImages', im);
            end
            if ~isempty(stat)
                stat = stat(keep);
                foundRois = foundRois.setappdata('roiStats', stat);
            end
            
            foundRois = foundRois.setappdata('roiClassification', zeros(1, numel(foundRois)));

            switch obj.settings.Autosegmentation.finalization
                
                case 'Add rois to current Roi Group'
                    obj.RoiGroup.addRois(foundRois);

                case 'Add rois to new Roi Group'
                    newGroup = obj.createNewRoiGroup();
                    newGroup.addRois(foundRois)
                    
                    
                case 'Add rois to new window'

            end
            
            

            
            % Todo: Add the roi classifier.
            % obj.manuallyClassifyRois()

            obj.PrimaryApp.clearMessage()
            fprintf = str2func('fprintf');

            
        end %RM
        
        function foundRois = runInternalAutosegmentation(obj, Y, options)
                        
            % Get imageStack from viewer
            hImageStack = obj.PrimaryApp.imageStack;
            
            % Todo: implement image mask form avg image. Ie, if image has
            % black regions.
            mask = hImageStack.getProjection('mean') ~= 0;
            mask = imdilate(mask, strel('disk', 5));
            
            Y = cast(mask, 'like', Y) .* Y; % Adapt this to virtual stack

            [im, stat] = deal([]);

            [foundRois, im, stat] = roimanager.autosegment.autosegmentSoma(Y, mean(Y, 3));

            mask = hImageStack.getProjection('mean') == 0;
            mask = imdilate(mask, strel('disk', 5));

            % Check and remove rois that are close to the edge of the image.
            isBoundaryRoi = arrayfun(@(roi) roi.isOnBoundary, foundRois);
            isOutside = foundRois.isOverlap(mask);
            keep = ~isBoundaryRoi & ~isOutside';

            foundRois = foundRois(keep);

            if ~isempty(im)
                im = im(keep);
                foundRois = foundRois.setappdata('roiImages', im);
            end
            if ~isempty(stat)
                stat = stat(keep);
                foundRois = foundRois.setappdata('roiStats', stat);
            end
            
            % Todo: Check if rois overlap with rois already in the gui.
            
        end
        
        function openManualRoiClassifier(obj)
            % todo....
            hClassifier = imviewer.plugin.RoiClassifier(obj.StackViewer);
            hClassifier.setFilePath(obj.roiFilePath);
            
        end % /function openManualRoiClassifier
        
        function extractSignals(obj)
                    
            global fprintf
            fprintf = @(msg) obj.PrimaryApp.displayMessage(msg);
            
            
            % % Get image stack and rois. Cancel if there are no rois
            imageStack = obj.StackViewer.imageStack;
            roiArray = obj.RoiGroup.roiArray;
            
            if isempty(roiArray)
                msg = 'Need some rois to extract signals from...';
                obj.StackViewer.displayMessage(msg, [], 2)
                return
            end
            
            
            % % Import functions for extracting/processing signals
            import nansen.twophoton.roisignals.extractF
            import nansen.twophoton.roisignals.computeDff
            import nansen.twophoton.roisignals.deconvolveDff
            
            
            % % Define options for what to save
            options = struct;
            options.saveNeuropilSignals = true;
            options.computeDff = true;
            options.dffMethod = 'dffClassic';
            options.dffMethod_ = {'dffClassic', 'dffChenEtAl2013', 'dffRoiMinusDffNpil'};
            
            options.deconvolveSignals = true;
            options.deconvolutionMethod = 'CaImAn';
            options.deconvolutionMethod_ = {'CaImAn'};
            
            options.savePath = fullfile('..', 'roisignals');

            options = tools.editStruct(options);
            
            
            % % Get signal extraction options
            if isempty(obj.signalOptions)
                obj.signalOptions = nansen.twophoton.roisignals.extract.getDefaultParameters();
            end
            
            obj.StackViewer.displayMessage('Extracting signals...')
            
            
            % % Extract signals
            signalArray = extractF(imageStack, roiArray, obj.signalOptions);

            
            % % Create save path
            [initPath, fileName] = obj.getInitPath();
            savePath = utility.path.validatePathString(options.savePath, initPath);
            if ~exist(savePath, 'dir'); mkdir(savePath); end 
            
            if contains(fileName, 'rois')
                fileName = strrep(fileName, 'rois', 'roisignals');
            else
                fileName = sprintf('%s_roisignals.mat', fileName);
            end
            savePath = fullfile(savePath, fileName);
            
            
            % % Save signals
            roiMeanF = squeeze(signalArray(:,1,:));
            save(savePath, 'roiMeanF')
            % Todo: save options

            
            if options.saveNeuropilSignals
                neurpilMeanF = squeeze(signalArray(:,2:end,:));
                save(savePath, 'neurpilMeanF', '-append')
            end
            
            if options.computeDff || options.deconvolveSignals
                obj.StackViewer.displayMessage('Computing DFF...')
                dff = computeDff(signalArray, 'dffFcn', options.dffMethod);
                save(savePath, 'dff', '-append')
            end
            
            if options.deconvolveSignals
                if isempty(obj.deconvolutionOptions)
                    obj.deconvolutionOptions = nansen.twophoton.roisignals.getDeconvolutionParameters();
                end
                obj.StackViewer.displayMessage('Deconvolving DFF...')
                
                [deconvolved, denoised, opts] = deconvolveDff(dff, 'deconvolutionMethod', 'caiman', obj.deconvolutionOptions);
                save(savePath, 'deconvolved', '-append')
                save(savePath, 'denoised', '-append')
                % Todo: save options
                
            end
            
            obj.StackViewer.clearMessage()
            fprintf = str2func('fprintf');

        end %RM
        
        function editSignalExtractionSettings(obj)
            
            if isempty(obj.signalOptions)
                obj.signalOptions = nansen.twophoton.roisignals.extract.getDefaultParameters();
            end
            
            obj.signalOptions = tools.editStruct(obj.signalOptions);
        
        end %? 
        
        function editDeconvolutionSettings(obj)
            if isempty(obj.deconvolutionOptions)
                obj.deconvolutionOptions = nansen.twophoton.roisignals.getDeconvolutionParameters();
            end
            obj.deconvolutionOptions = tools.editStruct(obj.deconvolutionOptions);
        end %? 
        
        function openSignalViewer(obj, hPanel)
            
%             if obj.StackViewer.imageStack.isVirtual
%                 obj.PrimaryApp.displayMessage('Can not show signals with virtual stack, aborting...', [], 2);
%                 return
%             end
            
            if isempty(obj.roiSignalArray)
                obj.initializeSignalArray()
            end
            
            mItem = findobj(obj.hMenu, '-regexp', 'Text', 'Signal Viewer');

            
            if isempty(obj.SignalViewer)
                
                if nargin < 2
                    obj.SignalViewer = roisignalviewer.App(obj.roiSignalArray);
                else
                    obj.SignalViewer = roisignalviewer.App(hPanel, obj.roiSignalArray);
                end
                obj.SignalViewer.ShowRoiSignalOptionsOnMenu = true;
                
                %obj.SignalViewer.Theme = signalviewer.theme.Dark;
                
                % Add the roigroup reference to the signalviewer
                obj.SignalViewer.RoiGroup = obj.RoiGroup;
                
                % Create listener for signalviewer being destroyed
                l = addlistener(obj.SignalViewer, 'ObjectBeingDestroyed', ...
                    @(s,e,m)obj.onSignalViewerDeleted(mItem));
                obj.SignalViewerDeletedListener = l;
                
                % Link current frame no property
                
                obj.StackViewer.linkprop(obj.SignalViewer, [], false, false)
                
                %obj.SignalViewer.synchWithApp(obj.StackViewer)
                
            else
                if ~isempty(mItem)
                    switch mItem.Text
                        case 'Open Signal Viewer'
                            obj.SignalViewer.show()
                        case 'Close Signal Viewer'
                            obj.SignalViewer.hide()
                    end
                end
            end
            
            uim.utility.toggleUicontrolLabel(mItem, 'Open', 'Close');

            
        end %?
        
        function onSignalViewerDeleted(obj, mItem)
            if ~isvalid(obj); return; end
            obj.SignalViewer = [];
            if isvalid(mItem)
                mItem.Text = 'Open Signal Viewer';
            end
        end
        
        function onImageStackChanged(obj, src, evt)
            
            imageStack = evt.AffectedObject.ImageStack;
            
            if ~isempty(obj.roiSignalArray)
                obj.roiSignalArray.ImageStack = imageStack;
            end
            
            if imageStack.IsVirtual
                obj.ImageDataChangedListener = listener(imageStack.Data, ...
                    'StaticCacheChanged', @obj.onImageDataChanged);
            end
            
            if ~isempty(obj.SignalViewer)

                obj.SignalViewer.nSamples = obj.roiSignalArray.ImageStack.NumTimepoints;
                obj.SignalViewer.resetTimeSeriesObjects()
                obj.SignalViewer.initializeTimeSeriesObjects()
            
                obj.SignalViewer.setNewXLims()

                if obj.roiSignalArray.ImageStack.IsVirtual
                    obj.SignalViewer.showVirtualDataDisclaimer()
                else
                    obj.SignalViewer.hideVirtualDataDisclaimer()
                end
                
            end
            
            % Reset the static image of the fov...
            obj.roiDisplay.resetStaticFovImage()
        end
        
        function onImageDataChanged(obj, src, evt)
            
            imageStack = obj.StackViewer.ImageStack;
            imData = imageStack.Data.getStaticCache();
            
            if ~isempty(obj.roiSignalArray)
                obj.roiSignalArray.ImageStack = nansen.stack.ImageStack(imData);
            end
            
            if ~isempty(obj.SignalViewer)
                obj.SignalViewer.nSamples = obj.roiSignalArray.ImageStack.NumTimepoints;
                obj.SignalViewer.resetTimeSeriesObjects()
                obj.SignalViewer.initializeTimeSeriesObjects()
                obj.SignalViewer.hideVirtualDataDisclaimer()
                obj.SignalViewer.setNewXLims()
                obj.SignalViewer.refreshSignalPlot()
            end
            
        end
        
        function initializeSignalArray(obj)
            
            import nansen.roisignals.RoiSignalArray
            
            imageStack = obj.StackViewer.ImageStack;

            if imageStack.IsVirtual
                obj.ImageDataChangedListener = listener(imageStack.Data, ...
                    'StaticCacheChanged', @obj.onImageDataChanged);
            end
            
            obj.ImageStackChangedListener = addlistener(obj.StackViewer, ...
                'ImageStack', 'PostSet', @obj.onImageStackChanged);
            
            % Get data from static cache and add to roi signal array if possible...
            if imageStack.IsVirtual
                if imageStack.HasStaticCache
                    imData = imageStack.Data.getStaticCache();
                    imageStack = nansen.stack.ImageStack(imData);
                end
            end
            
            obj.roiSignalArray = RoiSignalArray(imageStack, obj.RoiGroup);
            
        end %RM?
    
        function createImageStackListeners(obj, imageStack)
            % Not finished
            if imageStack.IsVirtual
                obj.ImageDataChangedListener = listener(imageStack.Data, ...
                    'StaticCacheChanged', @obj.onImageDataChanged);
            end
            
            obj.ImageStackChangedListener = addlistener(obj.StackViewer, ...
                'ImageStack', 'PostSet', @obj.onImageStackChanged);
            
        end
        
        function resetImageStackListeners(obj)
            % Not finished
            if ~isempty(obj.ImageDataChangedListener)
                delete(obj.ImageDataChangedListener)
            end
            
            if ~isempty(obj.ImageStackChangedListener)
                delete(obj.ImageStackChangedListener)
            end
            
        end
        
    end
    
    methods (Static)
        
        function hApp = validateApp(varargin)
            
            hApp = [];
                  
            if ~isempty(varargin)
                msg = 'Plugin is only valid for imviewer apps';
                assert(isa(varargin{1}, 'imviewer.App'), msg)

                hApp = varargin{1};
            end
        
        end
        
        S = getDefaultSettings()
        
        function icon = getPluginIcon()
            
        end
        
        function pathStr = getIconPath()
            % Get system dependent absolute path for icons.
            pathStr = roimanager.localpath('toolbar_icons');
        end                
    end
    
end



 
 
 
 
