classdef RoiManager < applify.mixin.AppPlugin
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
    
    properties 
        %RoiManager  % Handle to roimanager class
            
        PrimaryAppName = 'imviewer'
                
        roiTools
        roiGroup                % RM
        roiDisplay
        
        % Todo: Where should this be saved. need to rethink RoI
        % specifications...
        roiImages
        roiStats
        roiClassification
        
        secondaryGroups % Todo: merge this with roiGroup
        secondaryMaps % Todo: merge this with roiDisplay
        
        roiSignalArray          % RM
        
        roiFilePath             % RM
        
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
        
        hImageRoiStatic % Come up with better name
               
        ImageStackChangedListener
        ImageDataChangedListener

        SignalViewerDeletedListener % Dashboard, RM ?
    end

    
    methods % Structors
        
        function obj = RoiManager(varargin)
            
            % Note: hImviewer will be empty if varargin is empty.
            hImviewer = imviewer.plugin.RoiManager.validateApp(varargin{:});
            
            % Pass potential imviewer handle to superclass constructor.
            obj@applify.mixin.AppPlugin(hImviewer);

            % Plugin already existed, and obj was reassigned in superclass
            if obj.IsActivated
                if ~nargout; clear obj; end
                return
            end

            
            % Initialize a roi map and store in the roiDisplay property
            obj.roiGroup = roimanager.roiGroup();
            
            
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
        function wasCaptured = onKeyPress(obj, src, event)
            wasCaptured = true; %Guilty until proven innocent c-^_^-?
            
            switch event.Key
                case 'space'
                    obj.toggleShowRoiOutlines()
                    
                    
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
        
        function onPluginActivated(obj)
                                 
            obj.PrimaryApp.displayMessage('Activating roimanager...', [], 2)

            
            [obj.StackViewer, hImviewer] = deal( obj.PrimaryApp );

            hAxes = hImviewer.Axes;
            
            % Update menu, by adding some roimanager options:
            obj.createMenu()

            obj.roiGroup.ParentApp = obj.PrimaryApp;
            
            obj.roiDisplay = roimanager.roiMap(hImviewer, hAxes, obj.roiGroup);
            
            % Assign the Ancestor App of the roigroup to the app calling
            % for its creation.
            obj.roiDisplay.roiGroup.ParentApp = hImviewer;
            obj.roiDisplay.hRoimanager = obj;
            
            obj.initializePointerTools()
            
            obj.addButtonsToToolbar % Do this after creating pointertools.
            obj.PrimaryApp.clearMessage()
            
        end
        
        function onSettingsChanged(obj, name, value)
        %onSettingsChanged Callback for value change on a settings field.
        
        obj.settings.(name) = value;
        
            switch name
                case 'showTags'
                    % Todo: Change this to roi labels... Just for testing
                    obj.toggleShowRoiOutlines('', value)
                case 'colorRoiBy'
                    obj.roiDisplay.updateRoiColors(1:obj.roiGroup.roiCount)
                    if strcmp(value, 'Activity Level')
                        obj.PrimaryApp.displayMessage('Not implemented yet')
                        pause(1.5)
                        obj.PrimaryApp.clearMessage()
                    end
            end
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
            newRoiMap.roiGroup.ParentApp = obj.StackViewer;
            newRoiMap.hRoimanager = obj;
            
            colorMap=cbrewer('qual', 'Set1', 8, 'spline');
            newRoiMap.defaultColor = colorMap(numGroups+1, :);

            % Todo: What if this is not created yet....Need to add to
            % settings....?
            % Add group to settings controls...
            numGroups = numel(obj.secondaryGroups) + 1;
            % Todo. What if this panel was not opened yet?!?!?
            obj.AppModules(4).hControls.setCurrentRoiGroup.String{end+1} = sprintf('Group %d', numGroups);
            obj.AppModules(4).hControls.showRoiGroups.String{end+1} = sprintf('Show Group %d', numGroups);            
            
        end
        
        function changeCurrentRoiGroup(obj, newGroupName)
            
            newGroupNumberStr = strrep(newGroupName, 'Group ', ''); 
            newGroupNumber = round( str2double(newGroupNumberStr) );
            if newGroupNumber == 1
                newMap = obj.roiDisplay;
                newGroup = obj.roiGroup;
            else
                newMap = obj.secondaryMaps(newGroupNumber-1);
                newGroup = obj.secondaryGroups(newGroupNumber-1);
            end
            
            obj.PointerManager.pointers.selectObject.hObjectMap = newMap;
           
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
                obj.PointerManager.pointers.(pointerNames{i}).hObjectMap = hMap;
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
            mItem.Callback = @(s, e) obj.loadRois();
%             mitem.Accelerator = 'l';

%             mitem = uimenu(m, 'Text', 'Load Rois...');
%             mitem.Callback = @(s, e, pstr) obj.loadRois('');
            
            mItem = uimenu(hMenu, 'Text', 'Save Rois');
            mItem.Callback = @(s, e) obj.saveRois();
%             mitem.Accelerator = 's';

            mItem = uimenu(hMenu, 'Text', 'Show...', 'Separator', 'on');
            
            mSubItem = uimenu(mItem, 'Text', 'Show Text Labels', 'Enable', 'off');
            mSubItem.Callback = [];
            
            mSubItem = uimenu(mItem, 'Text', 'Hide Roi Outlines');
            mSubItem.Callback = @(s, e) obj.toggleShowRoiOutlines(s);
            
            mSubItem = uimenu(mItem, 'Text', 'Hide Roi Relations');
            mSubItem.Callback = @(s, e) obj.toggleShowRoiRelations(s);
            
            mSubItem = uimenu(mItem, 'Text', 'Mask Roi Interior');
            mSubItem.Callback = @(s, e) obj.maskRoiInterior(s);
            
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
            mitem.Callback = @(s,e) imviewer.plugin.roiSignalVideo(obj.PrimaryApp); % Todo: update reference.
            
            obj.hMenu = hMenu;
            obj.Menu = hMenu;
            
        end
        
    end
    
    methods % User methods.

        function loadRois(obj, initPath)
            
            if nargin < 2; initPath = ''; end
            loadPath = obj.getRoiPath(initPath, 'load');
            if isempty(loadPath); return; end

            obj.PrimaryApp.displayMessage('Loading Rois...')
            C = onCleanup(@(s,e) obj.PrimaryApp.clearMessage);
            
             % Load roi array from selected file path.
            if exist(loadPath, 'file')
                S = load(loadPath);
                field = fieldnames(S);
                
                if contains('sessionData', fieldnames(S))
                    S = S.sessionData;
                    field = fieldnames(S);
                end
                
                fieldMatch = contains(field, {'roiArray', 'roi_arr'});
                if isempty(fieldMatch)
                    error('Did not find roi array in selected file')
                else
                    roi_arr = S.(field{fieldMatch});
                    if isa(roi_arr, 'struct')
                        roi_arr = roimanager.utilities.struct2roiarray(roi_arr);

                    end
                end
                
                if isa(roi_arr, 'RoI')
                    roi_arr_struct = roimanager.utilities.roiarray2struct(roi_arr);
                    roi_arr = roimanager.utilities.struct2roiarray(roi_arr_struct);
                end
                
                
                if contains( 'roiImages', field)
                    roi_arr = roi_arr.setappdata('roiImages', S.roiImages);
                end
                
                if contains( 'roiStats', field)
                    roi_arr = roi_arr.setappdata('roiStats', S.roiStats);
                end
                
                if contains( 'roiClassification', field)
                    roi_arr = roi_arr.setappdata('roiClassification', S.roiClassification);
                end
                
                obj.roiFilePath = loadPath;
            else
                error('File not found')
            end
            
            
            obj.roiDisplay.roiGroup.addRois(roi_arr, [], 'initialize')
            
        end
        
        function saveRois(obj, initPath)
           
            if nargin < 2; initPath = ''; end
            savePath = obj.getRoiPath(initPath, 'save');
            if isempty(savePath); return; end
            
            roiArray = obj.roiDisplay.roiGroup.roiArray;
            save(savePath, 'roiArray')
            saveMsg = sprintf('Rois Saved to %s', savePath);
            obj.PrimaryApp.displayMessage(saveMsg, 2)
                        
            obj.roiFilePath = savePath;
            
            

        end
        
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
        
        function filePath = getRoiPath(obj, initPath, mode)
            
            filePath = '';
            
            if nargin < 2 || isempty(initPath)
                if ~isempty(obj.roiFilePath)
                    initPath = obj.roiFilePath;
                else
                    initPath = obj.PrimaryApp.ImageStack.FileName;
                end
                
                if exist(initPath, 'file') == 2
                    [initPath, fileName, ext] = fileparts(initPath);
                end
                
            end
            
            fileSpec = {  '*.mat', 'Mat Files (*.mat)'; ...
                            '*', 'All Files (*.*)' };
            
            switch mode
                case 'load'
                    [filename, filePath, ~] = uigetfile(fileSpec, ...
                        'Load Roi File', initPath, 'MultiSelect', 'on');
                    
                case 'save'
                    if exist('fileName', 'var') && ~isempty(fileName)
                        if ~contains(fileName, '_rois')
                            initPath = fullfile(initPath, strcat(fileName, '_rois.mat'));
                        else
                            initPath = fullfile(initPath, [fileName, ext]);
                        end
                    end
                    [filename, filePath, ~] = uiputfile(fileSpec, ...
                        'Save Roi File', initPath);
            end
            
            if isequal(filename, 0) % User pressed cancel
                filePath = '';
            else
                filePath = fullfile(filePath, filename);
            end
            
            
        end
        
        
% % % % Methods for manipulating what is shown in the viewer.

        function toggleShowRoiOutlines(obj, src, value)
            
            % Get handle to menuItem
            if nargin < 2 || isempty(src)
                mItem = findobj(obj.hMenu, '-regexp', 'Text', 'Roi Outlines');
            else
                mItem = src;
            end
            
            % Todo: Need to make a general toggle method...
            if nargin == 3
                if value
                    mItem.Text = 'Show Roi Outlines';
                else
                    mItem.Text = 'Hide Roi Outlines';
                end
            end
            
            drawnow
            
            switch mItem.Text
                case 'Show Roi Outlines'
                    obj.roiDisplay.showRoiOutlines()
                case 'Hide Roi Outlines'
                    obj.roiDisplay.hideRoiOutlines()
            end
            
            % NB: Do this last
            uim.utility.toggleUicontrolLabel(mItem, 'Show', 'Hide');
            
        end
        
        
        function toggleShowRoiTextLabels(obj, src, value)
            
            % Get handle to menuItem
            if nargin < 2 || isempty(src)
                mItem = findobj(obj.hMenu, '-regexp', 'Text', 'Text Labels');
            else
                mItem = src;
            end
            
            % Todo: Need to make a general toggle method...
            if nargin == 3
                if value
                    mItem.Text = 'Show Text Labels';
                else
                    mItem.Text = 'Hide Text Labels';
                end
            end
            
            drawnow
            
            switch mItem.Text
                case 'Show Text Labels'
                    obj.roiDisplay.showRoiTextLabels()
                case 'Hide Text Labels'
                    obj.roiDisplay.hideRoiTextLabels()
            end
            
            % NB: Do this last
            uim.utility.toggleUicontrolLabel(mItem, 'Show', 'Hide');
            
        end
        
        
        
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
        
        
        function maskRoiInterior(obj, src)
            
            % Todo: Only do this if hViewer is an imviewer instance?
            
            if nargin < 2
                % Todo: Does it match partially or do i need the regexp
                % flag?
                mItem = findobj(obj.hMenu, '-regexp', 'Text', 'Roi Interior');
            else
                mItem = src;
            end
            
            switch mItem.Text
                case 'Mask Roi Interior'
                    if isempty(obj.hImageRoiStatic)
                        obj.plotRoiStaticImage()
                    else
                        obj.hImageRoiStatic.Visible = 'on';
                        obj.updateRoiStaticImage()
                    end
                    
                case 'Show Roi Interior'
                    obj.hImageRoiStatic.Visible = 'off';
            end
            
            uim.utility.toggleUicontrolLabel(mItem, 'Show', 'Mask');
            
        end
        
        
        function plotRoiStaticImage(obj)
        %plotRoiStaticImage Overlay a static image on all rois.
        
            % Get mean image of stack
            avgIm = obj.PrimaryApp.imageStack.getProjection('average');

            obj.hImageRoiStatic = imagesc(avgIm, 'Parent', obj.PrimaryApp.Axes);
            
            % Make sure this layer does not capture mouseclicks.
            obj.hImageRoiStatic.HitTest = 'off';
            obj.hImageRoiStatic.PickableParts = 'none';
            
            % Place image just above the bottom level in the viewer axes.
            % The bottom should be the displayed image. NB, Not sure if
            % this will always be the case, so should add code to make sure
            % this is so. % Todo: This is shaky.
            uistack(obj.hImageRoiStatic, 'bottom')
            uistack(obj.hImageRoiStatic, 'up', 3)

            % Set alphadata of roi static image
            obj.updateRoiStaticImage()
            
            el = listener(obj.roiDisplay, 'mapUpdated', ...
                @(s,e) obj.updateRoiStaticImage);
            obj.MapUpdateListener = el;
        end
        
        
        function updateRoiStaticImage(obj)
        %updateRoiStaticImage Update the static image, i.e when rois change

            % Set alpha of all pixels not within a roi to 0 and within a
            % roi to 1.
% % %             if strcmp(obj.hImageRoiStatic.Visible, 'on')
% % %                 roiMasks = obj.roiDisplay.roiMaskAll;
% % %                 if isempty(roiMasks)
% % %                     obj.hImageRoiStatic.AlphaData = 0;
% % %                 else
% % %                     obj.hImageRoiStatic.AlphaData = sum(roiMasks, 3) >= 1;
% % %                 end
% % %             end
            
            
            if strcmp(obj.hImageRoiStatic.Visible, 'on')
                roiMask = obj.roiDisplay.roiMaskAll;
                if isempty(roiMask)
                    obj.hImageRoiStatic.AlphaData = 0;
                else
                    obj.hImageRoiStatic.AlphaData = roiMask;
                end
            end
            
            roiIndexMap
        end
        
        
% % % % 

    function Y = prepareImagedata(obj, opts)
   
            global fprintf
            fprintf = @(varargin) obj.PrimaryApp.updateMessage(varargin{:});
            
            % Get imageStack from viewer
            hImageStack = obj.PrimaryApp.ImageStack;
            
            % Determine which frames to use:
            firstFrame = opts.firstFrame;
            lastFrame = min([firstFrame + opts.numFrames - 1, hImageStack.NumFrames]);
            
            if hImageStack.IsVirtual
                fprintf('Loading image data\n')
                Y = hImageStack.getFrameSet(firstFrame:lastFrame);
            else
                Y = hImageStack.Data;
            end
            
            % Create moving average video.
            if opts.downsamplingFactor > 1 
                fprintf('Downsampling image data\n')
                dsFactor = opts.downsamplingFactor;
                Y = stack.process.framebin.mean(Y, dsFactor); % Adapt this to virtual stack
            end
            
        end


        function runAutoSegmentation(obj)
        % Calls autodetection package from Pnevmatikakis et al (Paninski)
        % and adds detected rois to gui

            import nansen.twophoton.autosegmentation.*
            import nansen.module.*
            global fprintf
            fprintf = @(varargin) obj.PrimaryApp.updateMessage(varargin{:});

            
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
                    
                    %foundRois = obj.runInternalAutosegmentation(Y, methodOptions);
                    [foundRois, im, stat] = roimanager.autosegment.autosegmentSoma(Y, mean(Y, 3));

                case 'suite2p'
                    opts = suite2p.Options.convert(methodOptions);
                    tic; foundRois = suite2p.run(Y, opts); toc

                case 'extract'
                    opts = nansen.module.extract.Options.convert(methodOptions);
                    tic; [foundRois, im, stat] = extract.run(Y, opts); toc
                    
                case 'cnmf'

                    
            end
            
            
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
                    obj.roiGroup.addRois(foundRois);

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
            imviewer.plugin.RoiClassifier(obj.StackViewer)
        end % /function openManualRoiClassifier
        
        function extractSignals(obj)
                    
            global fprintf
            fprintf = @(msg) obj.PrimaryApp.displayMessage(msg);
            
            
            % % Get image stack and rois. Cancel if there are no rois
            imageStack = obj.StackViewer.imageStack;
            roiArray = obj.roiGroup.roiArray;
            
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
            
            mItem = findobj(obj.Menu, '-regexp', 'Text', 'Signal Viewer');

            
            if isempty(obj.SignalViewer)
                
                if nargin < 2
                    obj.SignalViewer = roisignalviewer.App(obj.roiSignalArray);
                else
                    obj.SignalViewer = roisignalviewer.App(hPanel, obj.roiSignalArray);
                end
                
                %obj.SignalViewer.Theme = signalviewer.theme.Dark;
                
                % Add the roigroup reference to the signalviewer
                obj.SignalViewer.RoiGroup = obj.roiGroup;
                
                % Create listener for signalviewer being destroyed
                l = addlistener(obj.SignalViewer, 'ObjectBeingDestroyed', ...
                    @(s,e,m)obj.onSignalViewerDeleted(mItem));
                obj.SignalViewerDeletedListener = l;
                
                % Link current frame no property
                
                obj.StackViewer.linkprop(obj.SignalViewer)
                
                %obj.SignalViewer.synchWithApp(obj.StackViewer)
                
            else
                
                switch mItem.Text
                    case 'Open Signal Viewer'
                        obj.SignalViewer.show()
                    case 'Close Signal Viewer'
                        obj.SignalViewer.hide()
                end
            end
            
            uim.utility.toggleUicontrolLabel(mItem, 'Open', 'Close');

            
        end %?
        
        function onSignalViewerDeleted(obj, mItem)
            obj.SignalViewer = [];
            if isvalid(mItem)
                mItem.Text = 'Open Signal Viewer';
            end
        end
        
        function onImageStackChanged(obj, src, evt)
            
            obj.roiSignalArray.ImageStack = evt.AffectedObject.ImageStack;
            obj.SignalViewer.nSamples = obj.roiSignalArray.ImageStack.numFrames;
            obj.SignalViewer.resetTimeSeriesObjects()
            obj.SignalViewer.initializeTimeSeriesObjects()
            
            if obj.roiSignalArray.ImageStack.IsVirtual
                obj.SignalViewer.showVirtualDataDisclaimer()
            else
                obj.SignalViewer.hideVirtualDataDisclaimer()
            end
            
            obj.SignalViewer.setNewXLims()


        end
        
        function onImageDataChanged(obj, src, evt)
            
            imageStack = obj.StackViewer.ImageStack;
            imData = imageStack.Data.getStaticCache();
            
            obj.roiSignalArray.ImageStack = nansen.stack.ImageStack(imData);
            obj.SignalViewer.nSamples = obj.roiSignalArray.ImageStack.NumTimepoints;
            obj.SignalViewer.resetTimeSeriesObjects()
            obj.SignalViewer.initializeTimeSeriesObjects()
            obj.SignalViewer.hideVirtualDataDisclaimer()
            obj.SignalViewer.setNewXLims()
            obj.SignalViewer.refreshSignalPlot()
            
            
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
            
            obj.roiSignalArray = RoiSignalArray(imageStack, obj.roiGroup);
            
        end %RM?
    
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



 
 
 
 
