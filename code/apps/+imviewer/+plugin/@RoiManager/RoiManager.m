classdef RoiManager < imviewer.ImviewerPlugin & roimanager.RoiGroupFileIoAppMixin
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
        %
        %   [ ] Consider whether to add the RoiGroupFileIoAppMixin to a
        %   property instead. Startegy pattern might be better than
        %   inheritance here, because if a session object is added to
        %   roimanager, we want to save to "data variables" instead of
        %   files (and this functionality could have it's own class).
        %
        %   [ ] ActiveChannel property
        %       [ ] Add option for selecting active channel.


%     % Multichannel rois todos:
%         [ ] Load rois (all channels/planes)
%         [ ] Save rois (all channels/planes)
%         [ ] Add autosegmented rois (all channels/planes)
%         [ ] Add individual/manual rois (current channel/plane)
%         [ ] 

%       addRois method could be modified to loop through channels and
%       planes?


    
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
    
    properties %(SetAccess = protected) %hidden, options?
        CreateContextMenu = true  % Boolean flag : Should contextmenu be created.
    end
    
    properties
        roiFilePath             % RM 
        DataSet % DataSet?
        %Todo: Should be dependent based on filepath set in file io mixin
    end

    properties % Outline/ thinking around roi groups...
        % Todo: How to keep track of active roi group and "secondaries"?

        % There is always one primary/active roigroup! A RoiGroup in
        % roimanager is a RoiGroup array of size (numPlanes x numChannels)

        % Furthermore: there is also one primary plane and channel, so when
        % interacting with the active RoiGroup we interact with the
        % RoiGroup from the active channel and plane

        % All secondary roigroups are stored in a struct array? (to be able
        % to name them and keep track of names? Or should roigroups have a
        % name property?

        % Visible roigroups: When a roigroup is set to visible, the rois
        % are added to the roimap.... The RoiMap (roiDisplay) will reflect 
        % whatever rois are added to it. However, if multiple roigroups
        % (i.e different named roigroups) are added, there should be one
        % display per group?
        ActiveRoiGroup  % Handle to an active roi group
        RoiGroup
    end
    
    properties (Dependent)
        CurrentRoiGroup % RoiGroup object of current channel+plane from current selection in list 
    end

    properties (SetAccess = protected)
        % Active channel. The value of this property determines which rois 
        % are displayed in the viewer. Also, if multiple channels are set, 
        % adding and removing rois is not possible
        ActiveChannel = 1

        CurrentRoiGroupIndex % Placeholder
        RoiGroupList % Placeholder
    end

    properties (Access = protected)

        %roiDisplay (1,:) roimanager.RoiDisplay % Todo
        %RoiEditor (1,1) roimanager.RoiEditor % Todo
        roiDisplay
        secondaryGroups  cell % struct array containing roigroups. Todo: merge this with roiGroup
        secondaryMaps cell % Todo: merge this with roiDisplay or remove?
    end

    properties (Access = protected) % Properties which should go elsewhere
        roiSignalArray          % RM
        ImageDataCache struct   % Todo: This does not belong on roimanager!
        
        signalOptions           % ? Should not be part of roimanager!
        dffOptions
        deconvolutionOptions    % ? Should not be part of roimanager!
        
        PointerManager  % make dependent property on imviewerplugin class
        
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
            
            obj@imviewer.ImviewerPlugin(varargin{:})

% %             [nvPairs, varargin] = utility.getnvpairs(varargin);
% %             
% %             % Note: hImviewer will be empty if varargin is empty.
% %             hImviewer = imviewer.plugin.RoiManager.validateApp(varargin{:});
% %             
% %             % Pass potential imviewer handle to superclass constructor.
% %             obj@applify.mixin.AppPlugin(hImviewer, [], nvPairs{:});
% % 
% %             % Plugin already existed, and obj was reassigned in superclass
% %             if obj.IsActivated
% %                 if ~nargout; clear obj; end
% %                 return
% %             end
% % 
% %             % if imviewer was empty, we return here
% %             if ~isempty(hImviewer)
% %                 obj.activatePlugin(hImviewer)
% %             end

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
    
    methods % Set/get
        
        function roiGroup = get.CurrentRoiGroup(obj)
            roiGroup = obj.getCurrentRoiGroup();
        end
        
        function set.ActiveChannel(obj, newValue)
            obj.assertValidChannelIndex(newValue)
            obj.ActiveChannel = newValue;
            obj.onActiveChannelSet()
        end

        function set.ActiveRoiGroup(obj, newValue)
            if isa(obj.ActiveRoiGroup, 'roimanager.CompositeRoiGroup')
                delete(obj.ActiveRoiGroup) % Delete old before setting new 
            end
            obj.ActiveRoiGroup = newValue;
            obj.updateRoiDisplay()
        end
    end

    methods
        function activatePlugin(obj, h)

            hImviewer = imviewer.plugin.RoiManager.validateApp(h);
            activatePlugin@imviewer.ImviewerPlugin(obj, hImviewer)
        end
    end
    
    methods % User methods.
        
        function changeSession(obj, imageStack, roiArray)
        
            % Delete composite rois before removing rois! Todo: Make this
            % more intuitive. Should not have to do this explicitly!
            if isa(obj.ActiveRoiGroup, 'roimanager.CompositeRoiGroup')
                delete(obj.ActiveRoiGroup)
                obj.roiDisplay.RoiGroup = roimanager.roiGroup.empty;
            end

            for i = 1:numel(obj.RoiGroup)
                obj.RoiGroup(i).removeRois()
            end

            obj.ImviewerObj.replaceStack(imageStack, false)
            
            % Delete composite rois before adding rois! Todo: See above
            if isa(obj.ActiveRoiGroup, 'roimanager.CompositeRoiGroup')
                delete(obj.ActiveRoiGroup)
                obj.roiDisplay.RoiGroup = roimanager.roiGroup.empty;
            end

            for i = 1%;%2:numel(obj.RoiGroup)
                % use obj.addRois!
                obj.ImviewerObj.displayMessage('Updating rois...')
                obj.RoiGroup(i).addRois(roiArray, [], 'initialize')
                obj.ImviewerObj.clearMessage()
            end
            obj.onCurrentChannelChanged()
        end

        function [initPath, fileName] = getInitPath(obj)
            
            if ~isempty(obj.roiFilePath)
                initPath = obj.roiFilePath;
            else
                initPath = obj.PrimaryApp.ImageStack.FileName;
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
           
%             variableName = obj.DataSet.uiSelectVariableName('RoiGroup');
%             if isempty(variableName); return; end
%             if isa(variableName, 'cell'); variableName = variableName{1}; end
            
            try
                %rois = obj.DataSet.loadData(variableName);
                rois = loadRois@roimanager.RoiGroupFileIoAppMixin(obj, loadPath);
            catch ME
                clear C % Reset message display
                obj.PrimaryApp.displayMessage(['Error: ', ME.message], [], 2)
                if nargout; rois = []; end
                return
            end
            
             %msg = lastwarn;
            %if ~isempty(msg); obj.PrimaryApp.displayWarning(); end  %Todo
            
            % Todo: Loop through channels and planes.
            % Todo: Assert that loaded rois have same dimensions (channels,
            % planes) as current. 
            
            % Todo: Current group / Current channel / Current plane...
            currentRoiGroup = obj.RoiGroup;
            loadedRoiGroup = rois;
            if ~nargout; clear rois; end
            
            % Make sure size of loaded and size of current roi groups is
            % the same.
            %assert( isequal( size(currentRoiGroup), size(loadedRoiGroup) ), ...
            %    'Loaded roi group does not match the dimensions of the image stack')

            % Todo: Load through all roi groups:
            for i = 1:numel(loadedRoiGroup)
                iC = loadedRoiGroup(i).ChannelNumber;
                iZ = loadedRoiGroup(i).PlaneNumber;
                % If rois already exist, determine how to add new ones
                if ~isempty(currentRoiGroup(iZ, iC).roiArray)
                    % If the loaded rois are identical, abort here
                    if isequal(currentRoiGroup(iZ, iC).roiArray, ...
                                loadedRoiGroup(iZ, iC).roiArray)
                        continue
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
                        roiInd = 1:currentRoiGroup(iZ, iC).roiCount;
                        currentRoiGroup(iZ, iC).removeRois(roiInd);
                    
                    case 'append non-overlapping'
                        addMode = 'append';
                        
                        [iA, ~] = roimanager.utilities.findOverlappingRois(...
                    	    loadedRoiGroup(i).roiArray, currentRoiGroup(iZ, iC).roiArray);
                        
                        loadedRoiGroup(i).removeRois(iA)
                end
                
                if loadedRoiGroup(i).roiCount > 0
                    obj.RoiGroup(iZ, iC).addRois(loadedRoiGroup(i), [], addMode)
                end
            end

            if strcmp(addMode, 'replace') || strcmp(addMode, 'initialize')
                obj.RoiGroup.markClean()
            end

            if i > 1
                obj.onCurrentChannelChanged()
            end
        end
        
        function saveRois(obj, initPath)
        %saveRois Save rois with confirmation message in app.    
            if nargin < 2; initPath = ''; end

% %             obj.DataSet.saveType('RoiGroup', obj.RoiGroup, 'Subfolder', ...
% %                 'roidata', 'FileAdapter', 'RoiGroup', 'IsCustom', true )
% %             return
            wasSaved = saveRois@roimanager.RoiGroupFileIoAppMixin(obj, initPath);
            
            if wasSaved
                saveMsg = sprintf('Rois Saved to %s\n', obj.roiFilePath);            
                obj.PrimaryApp.displayMessage(saveMsg, [], 2)
            else
                saveMsg = sprintf('Could not save rois');
                obj.PrimaryApp.displayMessage(saveMsg, [], 2)
            end
        end
        
        function addRois(obj, roiArray)
            if isa(obj.ActiveRoiGroup, 'roimanager.CompositeRoiGroup')
                delete(obj.ActiveRoiGroup)
                obj.roiDisplay.RoiGroup = roimanager.roiGroup.empty;
            end

            currentRoiGroup = obj.getCurrentRoiGroup();
            currentRoiGroup.addRois(roiArray, [], 'append')
            %obj.updateActiveRoiGroup()
            obj.onActiveChannelSet()
        end
        
        function newGroup = createNewRoiGroup(obj)
            
            newGroup = roimanager.roiGroup();
            newRoiMap = roimanager.roiMap(obj.ImviewerObj, obj.ImviewerObj.Axes, newGroup);

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
            newRoiMap.RoiGroup.ParentApp = obj.ImviewerObj;
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
        
        function S = getAutosegmentDefaultOptions(obj, methodName)
            
            switch lower(methodName)
                case 'quicky'
                    %h = nansen.OptionsManager('flufinder.getDefaultOptions');
                    S = flufinder.getDefaultOptions();
                    
                case 'extract'
                    S = nansen.wrapper.extract.Options.getDefaults();

                case 'suite2p'
                    S = nansen.twophoton.autosegmentation.suite2p.Options.getDefaultOptions;

               %case 'cnmf'

                otherwise
                   error('Not implemented')

            end
            
        end

        function foundRois = runInternalAutosegmentation(obj, Y, options)
                        
            % Get imageStack from viewer
            hImageStack = obj.PrimaryApp.ImageStack;
            
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
            hClassifier = imviewer.plugin.RoiClassifier(obj.ImviewerObj);
            hClassifier.setFilePath(obj.roiFilePath);
            
        end % /function openManualRoiClassifier
        
        function extractSignals(obj) % Todo: Use imageStackProcessors and external methods!
            
            C = obj.ImviewerObj.activateGlobalMessageDisplay(); %#ok<NASGU>
            
            % % Get image stack and rois. Cancel if there are no rois
            imageStack = obj.ImviewerObj.ImageStack;
            roiArray = obj.RoiGroup.roiArray;
            
            if isempty(roiArray)
                msg = 'Need some rois to extract signals from...';
                obj.ImviewerObj.displayMessage(msg, [], 2)
                return
            end
            
            
            % % Import functions for extracting/processing signals
            import nansen.twophoton.roisignals.extractF
            import nansen.twophoton.roisignals.computeDff
            import nansen.twophoton.roisignals.deconvolveDff
            
            if isempty(obj.dffOptions)
                obj.dffOptions = nansen.twophoton.roisignals.computeDff();
            end
            
            % % Define options for what to save
            options = struct;
            options.saveNeuropilSignals = true;
            options.computeDff = true;
            options.dffMethod = obj.dffOptions.dffFcn;
            options.dffMethod_ = {'dffClassic', 'dffChenEtAl2013', 'dffRoiMinusDffNpil'};
            
            options.deconvolveSignals = true;
            options.deconvolutionMethod = 'CaImAn';
            options.deconvolutionMethod_ = {'CaImAn'};
            
            options.savePath = fullfile('..', 'roisignals');

            [options, wasAborted] = tools.editStruct(options);
            if wasAborted; return; end
            
            obj.dffOptions.dffFcn = options.dffMethod;

            % % Get signal extraction options
            if isempty(obj.signalOptions)
                obj.signalOptions = nansen.twophoton.roisignals.extract.getDefaultParameters();
            end
            
            obj.ImviewerObj.displayMessage('Extracting signals...')
            
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
                obj.ImviewerObj.displayMessage('Computing DFF...')
                dff = computeDff(signalArray, obj.dffOptions);
                save(savePath, 'dff', '-append')
            end
            
            if options.deconvolveSignals
                if isempty(obj.deconvolutionOptions)
                    obj.deconvolutionOptions = nansen.twophoton.roisignals.getDeconvolutionParameters();
                end
                obj.ImviewerObj.displayMessage('Deconvolving DFF...')
                
                [deconvolved, denoised, opts] = deconvolveDff(dff, 'deconvolutionMethod', 'caiman', obj.deconvolutionOptions);
                save(savePath, 'deconvolved', '-append')
                save(savePath, 'denoised', '-append')
                % Todo: save options
                
            end
            
            obj.ImviewerObj.clearMessage()

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
        
        function openSignalViewer(obj, hPanel, roiGroup)
            
%             if obj.ImviewerObj.ImageStack.isVirtual
%                 obj.PrimaryApp.displayMessage('Can not show signals with virtual stack, aborting...', [], 2);
%                 return
%             end
            
            if nargin < 3
                roiGroup = obj.RoiGroup;
            end

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
                obj.SignalViewer.RoiGroup = roiGroup;
                
                % Create listener for signalviewer being destroyed
                l = addlistener(obj.SignalViewer, 'ObjectBeingDestroyed', ...
                    @(s,e,m)obj.onSignalViewerDeleted(mItem));
                obj.SignalViewerDeletedListener = l;
                
                % Link current frame no property
                
                obj.ImviewerObj.linkprop(obj.SignalViewer, [], false, false)
                
                %obj.SignalViewer.synchWithApp(obj.ImviewerObj)
                
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
                
                if obj.roiSignalArray.ImageStack.IsVirtual && ...
                        obj.roiSignalArray.ImageStack.HasStaticCache
                    obj.SignalViewer.hideVirtualDataDisclaimer()

                elseif obj.roiSignalArray.ImageStack.IsVirtual
                    obj.SignalViewer.showVirtualDataDisclaimer()
                else
                    obj.SignalViewer.hideVirtualDataDisclaimer()
                end
                
            end
            
            % Reset the static image of the fov...
            obj.roiDisplay.resetStaticFovImage()
        end
        
        function onImageDataChanged(obj, src, evt)
            
            imageStack = obj.ImviewerObj.ImageStack;
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
            
            imageStack = obj.ImviewerObj.ImageStack;

            if imageStack.IsVirtual
                obj.ImageDataChangedListener = listener(imageStack.Data, ...
                    'StaticCacheChanged', @obj.onImageDataChanged);
            end
            
            obj.ImageStackChangedListener = addlistener(obj.ImviewerObj, ...
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
            
            obj.ImageStackChangedListener = addlistener(obj.ImviewerObj, ...
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

    methods (Access = protected)
        
        function onConstruction(obj)
            % This method is not used for anything, but is a placeholder in
            % in case this subclass needs to to something during
            % construction and before the plugin is activated.

            % Initialize a roi map and store in the roiDisplay property
            obj.RoiGroup = roimanager.roiGroup();
        end
        
        function onPluginActivated(obj)
                                 
            obj.PrimaryApp.displayMessage('Activating roimanager...', [], 2)

            onPluginActivated@imviewer.ImviewerPlugin(obj)

            % Update menu, by adding some roimanager options:
            if obj.CreateContextMenu
                obj.createMenu()
            end
            
            obj.initializeRoiGroup()
            obj.initializeRoiDisplay()            
            obj.initializePointerTools()
            obj.addButtonsToToolbar % Do this after creating pointertools.
            
            % Todo: move to imviewer plugin?
            obj.ImageStackChangedListener = addlistener(obj.ImviewerObj, ...
                'ImageStack', 'PostSet', @obj.onImageStackChanged);
            
            obj.ActiveChannel = 1;

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
                    obj.roiDisplay.updateRoiColors('all')
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
            
            % Todo! Should change roimap for all roi pointertools 
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
        
        function onActiveChannelSet(obj)

            obj.updateActiveRoiGroup()
            
            % Todo:
            % Tell roiMap (roiEdior) about the active channel 
            obj.roiDisplay.ActiveChannel = obj.ActiveChannel;
            if ~isempty(obj.roiSignalArray)
                obj.roiSignalArray.ActiveChannel = obj.ActiveChannel;
            end
            if ~isempty(obj.SignalViewer)
                obj.SignalViewer.ActiveChannel = obj.ActiveChannel;
            end
        end

% % % % Imviewer callback methods

        function onCurrentChannelChanged(obj, src, evt)
            obj.updateActiveRoiGroup()
            
            if ~isempty(obj.roiSignalArray)
                if ~isempty(obj.roiSignalArray.ImageStack)
                    obj.roiSignalArray.ImageStack.CurrentChannel = obj.ImviewerObj.currentChannel;
                end
            end
        end

        function onCurrentPlaneChanged(obj, src, evt)
            obj.updateActiveRoiGroup()

            if ~isempty(obj.roiSignalArray)
                if ~isempty(obj.roiSignalArray.ImageStack)
                    obj.roiSignalArray.ImageStack.CurrentPlane = obj.ImviewerObj.currentPlane;
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
        
        function initializeRoiGroup(obj)
            
            % Todo: Remove when type of roiGroup is properly defined in
            % property block of superclass
            if isempty(obj.RoiGroup)
                obj.RoiGroup = roimanager.roiGroup.empty;
            end

            % Create one roigroup object for each channel and each plane
            for i = 1:obj.ImviewerObj.NumPlanes
                for j = 1:obj.ImviewerObj.NumChannels
                    obj.RoiGroup(i,j) = roimanager.roiGroup();
                    obj.RoiGroup(i,j).ParentApp = obj.PrimaryApp;
                    obj.RoiGroup(i,j).ChannelNumber = j;
                    obj.RoiGroup(i,j).PlaneNumber = i;
                end
            end
        end
        
        function initializeRoiDisplay(obj)
        %initializeRoiDisplay Initialize a roidisplay for the current roi group

            hImviewer = obj.ImviewerObj;
            hAxes = obj.ImviewerObj.Axes;

            currentChannel = 1;
            currentPlane = 1;

            roiGroup = obj.RoiGroup(currentPlane, currentChannel);
            
            obj.roiDisplay = roimanager.roiMap(hImviewer, hAxes, roiGroup);
        end
        
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

    methods (Access = private)

        function roiGroup = getCurrentRoiGroup(obj)
%             currentChannel = obj.ImviewerObj.CurrentChannel(1);
%             currentPlane = obj.ImviewerObj.CurrentPlane;
            currentChannel = 1;
            currentPlane = 1;
            roiGroup = obj.RoiGroup(currentPlane, currentChannel);
        end

        function updateActiveRoiGroup(obj)
        %updateActiveRoiGroup Update active roi group based on current channel and plane selection    
            
            if ~isempty( obj.ActiveRoiGroup )
                obj.ActiveRoiGroup.changeRoiSelection(nan, []) 
            end

            currentPlane = obj.ImviewerObj.currentPlane;
            currentChannel = obj.ImviewerObj.currentChannel;
            
            currentChannel = intersect(currentChannel, obj.ActiveChannel);

            numChannels = numel(currentChannel);
            numPlanes = numel(currentPlane);

            if numChannels * numPlanes > 1

                roiGroup = roimanager.CompositeRoiGroup(...
                    obj.RoiGroup(currentPlane, currentChannel) );

            elseif numChannels * numPlanes == 1

                roiGroup = obj.RoiGroup(currentPlane, currentChannel);

            elseif numChannels * numPlanes == 0
                % Todo: Should make this a static roi group, i.e should not
                % be allowed to add or remove rois from it.
                roiGroup = roimanager.roiGroup.empty;
            end

            obj.ActiveRoiGroup = roiGroup;
            %obj.roiDisplay.RoiGroup = roiGroup;
            %obj.PointerManager.pointers.selectObject.RoiDisplay = obj.roiDisplay;
            return

            % Deprecated, but keep for reference;
            % Creating multiple roi displays:
            for i = 1:numel(currentChannel)
                roiGroup = obj.RoiGroup(currentPlane, currentChannel(i));
                if i > numel(obj.roiDisplay)
                    obj.roiDisplay(i) = roimanager.roiMap(obj.ImviewerObj, obj.ImviewerObj.Axes, roiGroup);
                end
                obj.roiDisplay(i).RoiGroup = roiGroup;
                obj.ActiveRoiGroup = roiGroup;
            end
            
            if i < numel(obj.roiDisplay)
                delete(obj.roiDisplay(i+1:end))
                obj.roiDisplay(i+1:end) = [];
            end

            obj.PointerManager.pointers.selectObject.RoiDisplay = obj.roiDisplay;

            % Deactivate the rois that are currently active

            % Activate rois for the newly selected slice (and primary channel)
        end
    
        function updateRoiDisplay(obj)
            obj.roiDisplay.RoiGroup = obj.ActiveRoiGroup;
            obj.PointerManager.pointers.selectObject.RoiDisplay = obj.roiDisplay;
        end

        function assertValidChannelIndex(obj, value, message)
        %assertValidChannelIndex Check that channel indices are in valid range
            if nargin < 3 || isempty(message)
                msg = sprintf('Channel numbers must be in range [1, %d]', ...
                    obj.NumChannels);
            end

            assert( all( ismember( value, 1:obj.NumChannels) ), msg )
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

