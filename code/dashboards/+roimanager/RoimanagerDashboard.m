classdef RoimanagerDashboard < applify.DashBoard & imviewer.plugin.RoiManager
    
    
    % Todo: 
    %   [ ] Why does the imviewer panel resize 3-4 times whenever
    %       showing/hiding the signal viewer panel
    %   [ ] Bug when creating rois and modifying them before the
    %       roisignalarray is initalized.
    %   [v] Register roitable as a modular app, so that keypresses are
    %       passed on...
    %   [ ] Create a reset method for reseting all roi-related data, i.e
    %       roimap, roitable etc. 


    %   [ ] Dashboard should not be a subclass of roimanager
    %       What dependencies exist?
    %           - settings...
    %           - methods for changing settings...

    
    properties
        ApplicationName = 'Roimanager'
    end
    
    properties(Constant, Hidden = true)
        %USE_DEFAULT_SETTINGS = false % Ignore settings file
        %DEFAULT_SETTINGS = roimanager.RoimanagerDashboard.getDefaultSettings() % Struct with default settings
    end
    
    properties (Hidden)
        FigureSize = [1280, 692]
    end
    
    properties (Constant, Hidden)
        PanelTitles = {'Controls', 'Image Display', 'Roi Manager', 'Signal Viewer', '', 'Roi Image'}
       %PanelModules = {'structeditor.App', 'imviewer.App', 'roimanager.RoiTable', 'roisignalviewer.App', []}
    end
    
    properties (Access = private)
       TabButtonGroup = struct() 
       ShowBottomPanel = true;
       
       ShowImagePanel = true;
       
       UiControls = []
       
       MainControlPanel % Store temorary control panel, i.e autosegmentation options
       TempControlPanelDestroyedListener % Listener for temporary control panel being deleted.
    end

    properties (Dependent, Access = protected) % App modules
        Imviewer
        RoiTable
        %SignalViewer
        RoiThumbnailViewer
        OptionsEditor
    end

    properties (Access = private)
        RowHeight =  [0.7, 0.3]
        ColumnWidthTop = [200, 0.7, 0.3]
    end
    
    
    methods % Structor
        
        function obj = RoimanagerDashboard(varargin)
        %RoimanagerDashboard Construct a roimanager dashboard application

            [jLabel, C] = roimanager.RoimanagerDashboard.showSplashScreen(); %#ok<ASGLU> 
            % C is a cleanup object, to ensure that the splash screen is
            % deleted on when constructor completes.

            % Explicit call to superclass constructors.
            obj@applify.DashBoard()
            obj@imviewer.plugin.RoiManager('CreateContextMenu', false)
           
            % Todo: Get figure position from properties.
            obj.hFigure.Position = [100, 50, obj.FigureSize];
            obj.keepFigureOnScreen()          
            
            obj.Theme = nansen.theme.getThemeColors('dark-purple');
            
            % Initialize and create the different ap modules
            %obj.UIModules = containers.Map;

            jLabel.setText('Initializing imviewer...')
            obj.initializeImviewer( varargin{:} )
            
            % Call method for activating the roimanager plugin on imviewer
            jLabel.setText('Initializing roi manager...')
            obj.activatePlugin(obj.Imviewer) % Activates the roimanager plugin
            % Todo: This dashboard should implement roimanager as a 
            % property, not a superclass...
            

            % Todo: Why do I need this. Should not roimanager take care of
            % this?
            if numel(obj.RoiGroup) > 1
                roiGroup = roimanager.CompositeRoiGroup(obj.RoiGroup);
            else
                roiGroup = obj.RoiGroup;
            end

            jLabel.setText('Initializing signal viewer...')
            obj.initializeSignalViewer(roiGroup)

            jLabel.setText('Initializing roi table...')
            obj.initializeRoiTable(roiGroup)

            obj.initializeRoiThumbnailDisplay(roiGroup)
            
            % Button bar on bottom switching between different panels.
            obj.createToolbar()

            obj.IsConstructed = true; % triggers onConstructed which will
            % make figure visible, apply theme etc.
            
            drawnow
            
            obj.TabButtonGroup.Group.Visible = 'on';
            
            % Load settings.... Needs to be done after figure is visible
            % due to the way controls are drawn.
            obj.initializeSettingsPanel()

            if ~nargout; clear obj; end
        end
        
        function quit(obj)
            obj.saveSettings()
        end
        
        function onFigureCloseRequest(obj)
                        
            wasAborted = obj.promptSaveRois();
            if wasAborted; return; end
            
            onFigureCloseRequest@applify.DashBoard(obj)
            
        end
    
        function saveSettings(obj)
        %saveSettings Save settings

            % Reset some settings before saving
            obj.settings.Autosegmentation.options = [];
%             obj.settings.ExperimentInfo = ... % Necessary?
%                 rmfield(obj.settings.ExperimentInfo, 'ActiveChannel_');
            saveSettings@imviewer.plugin.RoiManager(obj)
        end
    end

    methods % Set/Get
        
        function handleObj = get.Imviewer(obj)
            handleObj = obj.getModuleHandle('imviewer');
        end
        function set.Imviewer(obj, handleObj)
            obj.setModuleHandle('imviewer', handleObj)
        end

        function handleObj = get.RoiTable(obj)
            handleObj = obj.getModuleHandle('Roi Info Table');
        end

        function handleObj = get.RoiThumbnailViewer(obj)
            handleObj = obj.getModuleHandle('Roi Thumbnail Display');
        end
        function set.RoiThumbnailViewer(obj, handleObj)
            obj.setModuleHandle('Roi Thumbnail Display', handleObj)
        end

% %         function h = get.SignalViewer(obj)
% %             h = obj.getModuleHandle('Roi Signal Viewer');
% %         end

        function h = get.OptionsEditor(obj)
            h = obj.getModuleHandle('Options Editor');
        end
        function set.OptionsEditor(obj, handleObj)
            obj.setModuleHandle('Options Editor', handleObj)
        end
        
    end
    
    methods (Access = protected) % Create/configure layout
        
        function createPanels(obj)
            
            % Todo: Incorporate colors into theme
            S = obj.Theme;
            
            bgColor2 = [0.15,0.15,0.15];
            hlColor = [0.3000 0.3000 0.3000];
            shColor = [0.3000 0.3000 0.3000];
            fgColor = [0.75,0.75,0.75];
            
            panelParameters = {'Parent', obj.hMainPanel, ...
                'BorderType', 'line', 'BorderWidth', 1, ...
                'Background', bgColor2, 'ShadowColor', shColor, ...
                'Foreground', fgColor, 'HighlightColor', hlColor };
            
            % Create each of the panels:
            for i = 1:numel(obj.PanelTitles)
                iTitle = obj.PanelTitles{i};
                obj.hPanels(i) = uipanel( panelParameters{:}, 'Title', iTitle);
            end
            
            set(obj.hPanels, 'Units', 'pixel')

            obj.addPanelResizeButton(obj.hPanels(1))
            %obj.addPanelResizeButton(obj.hPanels(3))
            
        end

        function resizePanels(obj)
        %resizePanels Resize panels of dashboard
        
            if ~obj.IsConstructed; return; end
            
            % Turn off border to prevent flickering
            set(obj.hPanels(1:3), 'BorderType', 'none');
            set(obj.hPanels(3), 'Visible', 'off');
            
            % Store visibility state of main panel before turning
            % visibility off.
            mainPanelVisibility = obj.hMainPanel.Visible;
            %drawnow limitrate
            
            obj.hMainPanel.Visible = 'off';
            %obj.hFigure.Visible = 'off';
            
            
            % - - - Compute heights and yposition for each of the panel rows
            if obj.ShowBottomPanel
                panelHeights = [25, obj.RowHeight(2), obj.RowHeight(1)];
                iA = 3;
                iB = 2;
            else
                panelHeights = [25, 1];
                iA = 2;
            end
            
            [yPos, H] = obj.computePanelPositions(panelHeights, 'y');
            
            
            % - - - Compute widths and xposition for each of the panel rows

            % New positions of panels on top row (controls, imviewer, roitable)
            [xPosA, Wa] = obj.computePanelPositions(obj.ColumnWidthTop, 'x');
            
            
            % New positions of panels on middle row (signal viewer, roi image)
            if obj.ShowImagePanel && obj.ShowBottomPanel
                imPanelWidth = H(iB);
                [xPosB, Wb] = obj.computePanelPositions([1,imPanelWidth], 'x');
            elseif obj.ShowImagePanel && ~obj.ShowBottomPanel
                obj.hideModule('Roi Info')
            else
                [xPosB, Wb] = obj.computePanelPositions(1, 'x');
            end
            
            % New positions of panels on bottom row (toolbar)
            [xPosC, Wc] = obj.computePanelPositions(1, 'x');

            % - - - Resize the panels:
            
            panelNumsA = [1, 2, 3];
            numPanelsA = numel(panelNumsA);
            
            newPos = cell(numPanelsA, 1);
            
            for i = [1,3,2] % Resize imviewer latest...
                newPos{i} = [xPosA(i), yPos(iA), Wa(i), H(iA)];
                setpixelposition(obj.hPanels(panelNumsA(i)), newPos{i})
            end
            
            if obj.ShowBottomPanel
                setpixelposition(obj.hPanels(4), [xPosB(1), yPos(iB), Wb(1), H(iB)])
            end
            if obj.ShowImagePanel
                setpixelposition(obj.hPanels(6), [xPosB(2), yPos(iB), Wb(2), H(iB)])
            end
            
            setpixelposition(obj.hPanels(5), [xPosC, yPos(1), Wc, H(1)])

            %set( obj.hPanels, {'Position'},  newPos );
                      
            % Restore border to prevent flickering
            set(obj.hPanels(1:3), 'BorderType', 'line');
            
            set(obj.hPanels(3), 'Visible', 'on');
            
            obj.hMainPanel.Visible = mainPanelVisibility;
            
            %obj.hFigure.Visible = 'on';
            
            %drawnow

        end
        
    end
    
    methods (Access = private) % Initialize modules
        
        function initializeImviewer(obj, varargin)
        %initializeImviewer Initialize the imviewer module

            h = imviewer(obj.hPanels(2), varargin{:});
            h.resizePanelContents()
            obj.AppModules = h;
            obj.configurePanelResizeButton(obj.hPanels(2).Children(1), h)
            
            obj.DialogBox = h.uiwidgets.msgBox;
        end

        function initializeSignalViewer(obj, roiGroup)
        %initializeSignalViewer Initialize the signalviewer module
            if ~obj.Imviewer.ImageStack.isDummyStack()
                obj.openSignalViewer(obj.hPanels(4), roiGroup)
                obj.addPanelResizeButton(obj.hPanels(4).Children(1))
                obj.AppModules(end+1) = obj.SignalViewer;
            end
        end

        function initializeRoiTable(obj, roiGroup)
        %initializeRoiTable Initialize the roi table module
            h = roimanager.RoiTable(obj.hPanels(3), roiGroup);
            % Note: table catches all key events by default. Setting the 
            % following callbacks will pass uncaught key events to the
            % roimanager/imviewer.
            h.KeyPressFcn = @(s, e) obj.onKeyPressed(s, e, 'roimanager');
            h.KeyReleaseFcn = @(s, e) obj.onKeyReleased(s, e, 'roimanager');

            obj.addPanelResizeButton(obj.hPanels(3).Children(1))
            obj.AppModules(end+1) = h;
        end

        function initializeRoiThumbnailDisplay(obj, roiGroup)  
            obj.RoiThumbnailViewer = roimanager.RoiThumbnailDisplay(obj.hPanels(6), roiGroup);
            obj.RoiThumbnailViewer.ImageStack = obj.ImviewerObj.ImageStack;
            obj.RoiThumbnailViewer.Dashboard = obj;
            obj.RoiThumbnailViewer.ThumbnailSize = obj.settings.RoiDisplayPreferences.roiThumbnailSize;
                    
            %obj.AppModules(end+1) = obj.RoiThumbnailViewer;
        end

    end

    methods (Access = protected) % Create/configure modules
        
        function initializeSettingsPanel(obj)
            
% %             P0 = struct();
% %             P0.ExperimentName = '';
% %             P0.SampleRate = 31;
            
            P0 = obj.settings.ExperimentInfo;
            P0.ActiveChannel_ = obj.getActiveChannelAlternatives();

            i = 0;
            [structs, names, callbacks, valueChangedFcn] = deal( {} );
            
            i = i+1;
            structs{i} = P0;
            names{i} = 'Experiment Info';
            callbacks{i} = @obj.onExperimentOptionsChanged;
                       
            i = i+1;
            structs{i} = obj.settings.RoiDisplayPreferences;
            names{i} = 'Roi Display';
            callbacks{i} = @obj.onRoiDisplayPreferencesChanged;
            %valueChangedFcn{i} = @obj.onRoiDisplayPreferencesChanged;
            obj.initializeRoiDisplaySettings()
            
% %             i = i+1; % Not urgent, might also not provide any benefit..
% %             structs{i} = obj.settings.RoiSelectionPreferences;
% %             names{i} = 'Roi Selection';
% %             callbacks{i} = @obj.onRoiSelectionPreferencesChanged;
            
            i = i+1;
            structs{i} = obj.settings.Autosegmentation();
            % Todo: Add field for preset selection.
            names{i} = 'Autosegmentation';
            callbacks{i} = @obj.onAutosegmentationOptionsChanged;
            
            i = i+1;
            structs{i} = obj.settings.RoiCuration();
            % Todo: Add field for preset selection.
            names{i} = 'Roi Curation';
            callbacks{i} = @obj.onRoiClassifierOptionsChanged;
            
            i = i+1;
            structs{i} = obj.settings.SignalExtraction();
            obj.signalOptions = obj.settings.SignalExtraction;
            % Add save signal button
            structs{i}.SaveSignals = false;
            structs{i}.SaveSignals_ = struct('type', 'button', 'args', {{'String', 'Save Signals...', 'FontWeight', 'bold', 'ForegroundColor', [0.1840    0.7037    0.4863]}});
            names{i} = 'Signal Extraction';
            callbacks{i} = @obj.onSignalExtractionOptionsChanged; % todo
            %valueChangedFcn{i} = @obj.onSignalExtractionOptionsChanged;
            %valueChangedFcn{i} = [];
            
            
            i = i+1;
            obj.dffOptions = obj.settings.DffOptions;
            structs{i} = obj.settings.DffOptions;
            names{i} = 'DFF Options';
            callbacks{i} = @obj.onDffOptionsChanged;
            
            i = i+1;

            [P2, V] = nansen.twophoton.roisignals.getDeconvolutionParameters();
             
            P2.modelType_ = {'ar1', 'ar2', 'exp2', 'autoar'};
            P2.tauRise_ = struct('type', 'slider', 'args', {{'Min', 0, 'Max', 1000, 'nTicks', 100, 'TooltipPrecision', 0, 'TooltipUnits', 'ms'}});
            P2.tauDecay_ = struct('type', 'slider', 'args', {{'Min', 0, 'Max', 5000, 'nTicks', 500, 'TooltipPrecision', 0, 'TooltipUnits', 'ms'}});

            structs{i} = P2;
            names{i} = 'Deconvolution';
            callbacks{i} = @obj.onDeconvolutionParamsChanged;
            
            i=i+1;
            structs{i} = struct('RowHeight', {{'2.3x', '1x'}}, 'ColumnWidth', {{'200', '2.3x', '1x'}});
            names{i} = 'App Layout';
            callbacks{i} = @obj.onLayoutParamsChanged;


            h = structeditor.App(obj.hPanels(1), structs, 'FontSize', 10, ...
                'FontName', 'helvetica', 'LabelPosition', 'Over', ...
                'TabMode', 'dropdown', ...
                'Name', names, ...
                'Callback', callbacks);%, ...
                %'ValueChangedFcn', valueChangedFcn);

            
            
            obj.AppModules(end+1) = h;
            obj.UiControls = h;
        end

        function initializeRoiDisplaySettings(obj)
            
            fields = {'showNeuropilMask', 'showLabels', 'showOutlines', ...
                'maskRoiInterior', 'roiColorScheme'};
            
            for i = 1:numel(fields)
                thisName = fields{i};
                thisValue = obj.settings.RoiDisplayPreferences.(fields{i});
                obj.onRoiDisplayPreferencesChanged(thisName, thisValue)
            end
            
            %defaults = roimanager.roiDisplayParameters; % Todo. Fix this (need to reset some values in this settings on startup..)

            
            % Reset some "transient" fields.
            
            obj.settings.RoiDisplayPreferences.showByClassification = ...
                obj.settings.RoiDisplayPreferences.showByClassification_{1};
            obj.settings.RoiDisplayPreferences.setCurrentRoiGroup = ...
                obj.settings.RoiDisplayPreferences.setCurrentRoiGroup_{1};
            obj.settings.RoiDisplayPreferences.showRoiGroups = ...
                obj.settings.RoiDisplayPreferences.showRoiGroups_{1};
        end
        
        function configurePanelResizeButton(obj, hPanel, hImviewer)
            
            hAppbar = hImviewer.uiwidgets.Appbar;

            hButton = hAppbar.Children(3);
            hButton.ButtonDownFcn = @(s, e) obj.toggleMaximizePanel(hButton, hPanel);
        end
        
    end
    
    methods % Settings changed callbacks

        function onExperimentOptionsChanged(obj, name, value)
            
            switch name
                case 'OpenStack'
                    obj.openImageStack()
                case 'LoadRois'
                    obj.importRois()
                case 'SaveRois'
                    obj.saveRois()
                case 'SampleRate'

                case 'ActiveChannel'
                    obj.changeActiveChannel(value)
            end
            
        end
        
        function onRoiDisplayPreferencesChanged(obj, name, value)
            
            % todo: roimanager

% %             if isa(value, 'structeditor.eventdata.ValueChanged')
% %                 name = value.Name; %
% %             end
            
            % Todo: move to roiMap class...!
            switch name
                
                case 'showNeuropilMask'
                    obj.roiDisplay.neuropilMaskVisible = value;
                    
                case 'roiColorScheme'
                    obj.roiDisplay.RoiColorScheme = value;
                    
                case 'showByClassification'
                    obj.RoiTable.resetTableFilters()
                    obj.roiDisplay.showClassifiedCells(value)
                    
                case 'showLabels'
                    obj.switchRoiLabelVisibility(value)

                case 'showOutlines'
                    obj.switchRoiOutlineVisibility(value)
                    
                case 'maskRoiInterior'
                    obj.switchMaskRoiInteriorState(value)
                    
                case 'setCurrentRoiGroup'
                    obj.changeCurrentRoiGroup(value)
               
                case 'showRoiGroups'
                    obj.changeVisibleRoiGroups(value)

                case 'roiThumbnailSize'
                    obj.RoiThumbnailViewer.ThumbnailSize = value;
                    
            end
            
            % Why not set this first??
            obj.settings.RoiDisplayPreferences.(name) = value;

        end
        
        function onRoiSelectionPreferencesChanged(obj, name, value)
        
            % todo: roimanager
 
            obj.settings.RoiSelectionPreferences.(name) = value;
            
            switch name
                
                case 'SelectNextRoiOnClassify'
                    %obj.RoiGroup.NextRoiSelectionMode = value;
                    
                case 'NextRoiSelectionMode'
                    obj.RoiGroup.NextRoiSelectionMode = value;
            end
            
        end
        
        function onAutosegmentationOptionsChanged(obj, name, value)
            
            % Update the value in settings.
            obj.settings.Autosegmentation.(name) = value;

            % Make ui updates for some of the options
            switch name
               
                case 'autosegmentationMethod'
                    % Todo: Edit preset control and fill out with preset
                    % for selected method... 
                    
                    % Reset the method options struct
                    obj.settings.Autosegmentation.options = [];
                   
                case 'editOptions'
                                       
                    methodName = obj.settings.Autosegmentation.autosegmentationMethod;

                    if ~isempty( obj.settings.Autosegmentation.options )
                        S = obj.settings.Autosegmentation.options;
                    else
                        S = obj.getAutosegmentDefaultOptions(methodName);
                    end
                    
                    titleStr = sprintf('%s Options', methodName);

                    switch lower(methodName)
                        case 'extract'
                            hPlugin = nansen.plugin.imviewer.EXTRACT(obj.Imviewer, S, '-p');
                            callbackFcn = @hPlugin.changeSetting;
                        case {'flufinder', 'quicky'}
                            hPlugin = nansen.plugin.imviewer.FluFinder(obj.Imviewer, S, '-p');
                            callbackFcn = @hPlugin.changeSetting;
                        otherwise
                            hPlugin = [];
                            callbackFcn = [];
                    end
                    
                    %  Open structeditor.
                    h2 = structeditor.App(obj.hPanels(1), S, 'FontSize', 10, ...
                    'FontName', 'helvetica', 'LabelPosition', 'Over', ...
                    'Title', titleStr, 'TabMode', 'sidebar-popup', ...
                    'showPresetInHeader', true, 'Callback', callbackFcn);
                    
                    % Change panel title
                    obj.hPanels(1).Title = titleStr;
                    
                    % Open new control panel with autosegmentation options
                    obj.onControlPanelOpened(h2, 'Autosegmentation.options', hPlugin)
                   
                case {'numFrames', 'downsamplingFactor'}
                    numFrames = obj.settings.Autosegmentation.numFrames;
                    dsFactor = obj.settings.Autosegmentation.downsamplingFactor;
                    
                    imSize = [obj.Imviewer.imHeight, obj.Imviewer.imWidth];
                    estimatedMemory = prod(imSize(1:2))*numFrames/dsFactor*8;
                    
                    if estimatedMemory > 1e9
                        msg = sprintf( 'Estimated system memory required using these settings: %.1f GB', round(estimatedMemory./1e9, 2) );
                    else
                        msg = sprintf( 'Estimated system memory required using these settings: %.1f MB', round(estimatedMemory./1e6, 2) );
                    end
                    
                    obj.Imviewer.displayMessage(msg, [], 2)
                    
                case 'run'
                    obj.runAutoSegmentation()
                    
           end
        end
        
        function onRoiClassifierOptionsChanged(obj, name, value)
                        
            % Update the value in settings.
            obj.settings.RoiCuration.(name) = value;
            
            % Make ui updates for some of the options
            switch name
               
                case 'selectVariable'
                    % Todo: 
                    % Get/set cutoffValues from cutoffValuesRef_
                    
                case 'cutoffValues'
                    % Change selection of classified rois...
                    
                case 'openClassifierApp'
                    obj.openManualRoiClassifier()
            end
        end

        function onSignalExtractionOptionsChanged(obj, name, value)

            switch name
                case 'SaveSignals'
                    obj.extractSignals()
                otherwise
                    obj.signalOptions.(name) = value;
            end
        end

        function onDffOptionsChanged(obj, name, value)
            obj.SignalViewer.onDffOptionsChanged(name, value)
            obj.dffOptions.(name) = value;
        end

        function onDeconvolutionParamsChanged(obj, name, value)
            obj.SignalViewer.onDeconvolutionParamsChanged(name, value)
            obj.deconvolutionOptions.(name) = value;
        end

        function onLayoutParamsChanged(obj, name, value)
            
            value = strsplit(value{1}, ',');

            % Convert values;
            numberValues = zeros(size(value));

            isNormalized = cellfun(@(c) contains(c, 'x'), value);
            numberValues(~isNormalized) = cellfun(@(c) str2double(c), value(~isNormalized));
            
            normalizedValues = cellfun(@(c) str2double(strrep(c, 'x', '')), value(isNormalized));
            normalizedValues = normalizedValues ./ sum(normalizedValues);
            numberValues(isNormalized) = normalizedValues;

            switch name
                case 'RowHeight'
                    obj.RowHeight = numberValues;
                case 'ColumnWidth'
                    obj.ColumnWidthTop = numberValues;
            end
            obj.resizePanels()
        end

        function opts = convertAutosegmentOptions(obj, options, methodName)
            
        end
        
        function onControlPanelOpened(obj, hOptsEditor, targetName, hPlugin)
        %onControlPanelOpened Opens a new control panel
        %
        %   INPUTS:
        %       hOptsEditor Handle to an options editor for temp control panel
        %       targetName Name of options for temporary control panel
        %       hPlugin Plugin handle (if a plugin is activated)

        % This method handles cases when a new control panel is opened from
        % the main control panel (e.g autosegmentation options).
        %
        % The main control panel is stored in the MainControlPanel
        % property, and a listener is added on the temp control panel. When
        % the temp control panel is destroyed, the main control panel is
        % restored.

            obj.MainControlPanel = obj.OptionsEditor;
            obj.OptionsEditor = hOptsEditor;
            obj.TempControlPanelDestroyedListener = addlistener(hOptsEditor, ...
                'AppDestroyed',  @(s,e,nm,hp) obj.onControlPanelClosed(targetName, hPlugin) );
        end
        
        function onControlPanelClosed(obj, targetName, hPlugin)
            
            % Get changes
            if obj.OptionsEditor.wasCanceled
                S = obj.OptionsEditor.dataOrig;
                %obj.AppModules(1).displayMessage('Optio', [], 1.5)
            else
                S = obj.OptionsEditor.dataEdit; 
                obj.Imviewer.displayMessage('Options updated!', [], 1.5)
            end
            
            subs = struct('type', {'.'}, 'subs', strsplit(targetName, '.'));
            obj.settings = subsasgn(obj.settings, subs, S);
            
            % Replace the OptionsEditor appmodule with the original main
            % control panel.
            closingOptionsEditor = obj.OptionsEditor;
            obj.OptionsEditor = obj.MainControlPanel; % Need to reassign, because appmodule is updated behind the scenes
            obj.hPanels(1).Title = 'Controls';

            delete(closingOptionsEditor)
            delete(hPlugin)

            delete(obj.TempControlPanelDestroyedListener)
            obj.TempControlPanelDestroyedListener=[];
        end
        
    end

    methods (Access = protected) % Internal callbacks

        function onCurrentChannelChanged(obj, ~, ~)
            onCurrentChannelChanged@imviewer.plugin.RoiManager(obj)

            if obj.IsConstructed
                obj.RoiTable.RoiGroup = obj.ActiveRoiGroup;
                obj.SignalViewer.RoiGroup = obj.ActiveRoiGroup;
                obj.RoiThumbnailViewer.RoiGroup = obj.ActiveRoiGroup;
            end
        end

        function onCurrentPlaneChanged(obj, ~, ~)
            onCurrentPlaneChanged@imviewer.plugin.RoiManager(obj)

            if obj.IsConstructed
                obj.RoiTable.RoiGroup = obj.ActiveRoiGroup;
                obj.RoiThumbnailViewer.RoiGroup = obj.ActiveRoiGroup;
            end
        end

        function onActiveChannelSet(obj)
            onActiveChannelSet@imviewer.plugin.RoiManager(obj)
            
            % Todo:
            % Change active channel in signal viewer and in thumbnail
            % display
            if obj.IsConstructed
                obj.RoiTable.RoiGroup = obj.ActiveRoiGroup;
                obj.SignalViewer.RoiGroup = obj.ActiveRoiGroup;
                obj.RoiThumbnailViewer.RoiGroup = obj.ActiveRoiGroup;
                obj.RoiThumbnailViewer.ActiveChannel = obj.ActiveChannel;
            end
        end
    end

    methods (Access = protected) % Internal callbacks (Mouse, keyboard)
        
        function onKeyPressed(obj, src, evt, module)
            
            % Handle key events that should be taken care of by the main
            % application:
            
            switch evt.Key
                case 's'
                    if isequal(evt.Modifier, {'command'}) || isequal(evt.Modifier, {'control'})
                        obj.saveRois(obj.roiFilePath)
                        return
                    end
            end

            % If key event was not handled so far, defer to submodules.
            if nargin < 4
                onKeyPressed@applify.DashBoard(obj, src, evt)
            else
                switch module
                    case 'roimanager'
                        obj.Imviewer.onKeyPressed(src, evt, true)
                        
                        % Special case (temporary)
                        switch evt.Character
                            case {'<', '>'}
                                if ~isempty(obj.RoiThumbnailViewer)
                                    obj.RoiThumbnailViewer.onKeyPressed(src, evt)
                                end
                        end
                end
            end
        end

        function onKeyReleased(obj, src, evt, module)
            % If key event was not handled so far, pass on to submodules.
            
            if nargin < 4
                onKeyReleased@applify.DashBoard(obj, src, evt)
            else
                switch module
                    case 'roimanager'
                        obj.Imviewer.onKeyReleased(src, evt)
                end
            end
        end
    end
    
    methods 
        
        function createToolbar(obj)
            
            buttonSize = [100, 22];
    
            obj.hPanels(5).BorderType = 'none';

           % Create toolbar
            hToolbar = uim.widget.toolbar_(obj.hPanels(5), 'Margin', [10,0,0,0], ...
                'ComponentAlignment', 'left', 'BackgroundAlpha', 0, ...
                'Spacing', 20, 'Padding', [0,1,0,1], 'NewButtonSize', buttonSize, ...
                'Visible', 'off');
            hToolbar.Location = 'southwest';
            
            buttonProps = { 'Mode', 'togglebutton', 'CornerRadius', 4, ...
                'Padding', [0,0,0,0], 'Style', uim.style.buttonDarkMode3, ...
                'Callback', @obj.onTabButtonPressed, 'HorizontalTextAlignment', 'center' };

            hBtn = uim.control.Button_.empty;
    
            %buttonNames = {'Signal Viewer', 'Signal Rastermap', 'Roi Info', 'Roi History Plot'};
            %buttonStates = [true, false, true, false];
            buttonNames = {'Signal Viewer', 'Roi Info'};
            buttonStates = [true, true];

            for i = 1:numel(buttonNames)
                hBtn(i) = hToolbar.addButton('Text', buttonNames{i}, buttonProps{:});
                hBtn(i).Value = buttonStates(i);
            end

            obj.TabButtonGroup.Group = hToolbar;
            obj.TabButtonGroup.Buttons = hBtn;
        end
        
        function openImageStack(obj)
            
            fileAdapter = nansen.dataio.fileadapter.imagestack.ImageStack();
            initPath = fileparts(obj.Imviewer.ImageStack.FileName);
            
            fileAdapter.uiopen(initPath);
            if isempty(fileAdapter.Filename); return; end
            
            imageStack = fileAdapter.load();
                
            obj.Imviewer.replaceStack(imageStack, true)
            obj.RoiThumbnailViewer.ImageStack = imageStack;
            
            obj.settings.ExperimentInfo.SampleRate = imageStack.getSampleRate();
        end
            
        function onTabButtonPressed(obj, src, evt)
            
            if strcmp(src.Text, 'Roi Info')
                if src.Value
                    obj.showModule('Roi Info')
                else
                    obj.hideModule('Roi Info')
                end
                return
            end
            
            for iBtn = 1:numel(obj.TabButtonGroup.Buttons)
                
                buttonName = obj.TabButtonGroup.Buttons(iBtn).Text;
                
                if ~isequal(src, obj.TabButtonGroup.Buttons(iBtn))
                    obj.TabButtonGroup.Buttons(iBtn).Value = 0;
                    obj.hideModule(buttonName)
                else
                    obj.TabButtonGroup.Buttons(iBtn).Value = src.Value;
                    
                    if obj.TabButtonGroup.Buttons(iBtn).Value
                        obj.showModule(buttonName)
                    else
                        obj.hideModule(buttonName)
                    end
                end
            end
        end
        
        function showModule(obj, moduleName)
            % Todo: Move to dashboard?
            switch moduleName
                case 'Signal Viewer'
                    
                    if ~strcmp( obj.hPanels(4).Visible, 'on' )
                        set([obj.hPanels(4).Children], 'Visible', 'on');
                        obj.hPanels(4).Visible = 'on';
                        obj.ShowBottomPanel = true;
                        obj.resizePanels()
                        obj.hPanels(4).BorderType = 'line';
                    end
                    
                case 'Roi Info'
                    
                    if ~strcmp( obj.hPanels(6).Visible, 'on' )
                        set([obj.hPanels(6).Children], 'Visible', 'on');
                        obj.hPanels(6).Visible = 'on';
                        obj.ShowImagePanel = true;
                        obj.resizePanels()
                        obj.hPanels(6).BorderType = 'line';
                    end
            end
        end
        
        function hideModule(obj, moduleName)
            % Todo: Move to dashboard?
            % Add mapping from panel to module name
            switch moduleName
                case 'Signal Viewer'
                    if ~strcmp( obj.hPanels(4).Visible, 'off' )
                        set([obj.hPanels(4).Children], 'Visible', 'off');
                        obj.hPanels(4).Visible = 'off';
                        obj.hPanels(4).BorderType = 'none';
                        obj.ShowBottomPanel = false;
                        obj.resizePanels()
                    end
                    
                case 'Roi Info'
                    if ~strcmp( obj.hPanels(6).Visible, 'off' )
                        set([obj.hPanels(6).Children], 'Visible', 'off');
                        obj.hPanels(6).Visible = 'off';
                        obj.hPanels(6).BorderType = 'none';
                        obj.ShowImagePanel = false;
                        obj.resizePanels()
                    end
            end
            
            
            % if allPanelsHidden
%             obj.ShowBottomPanel = true;
%             obj.resizePanels()
            % end
            
        end

    end
    
    methods (Access = private)
        
        function changeActiveChannel(obj, value)
        %changeActiveChannel Change active channel based on option selection
            switch value
                case 'All Channels'
                    channelInd = 1:obj.NumChannels;
                otherwise
                    channelInd = str2double( strrep(value, 'Channel ', '') );
            end
            
            obj.ActiveChannel = channelInd;
        end

        function alternativesList = getActiveChannelAlternatives(obj)
        %getActiveChannelAlternatives Create list of alternatives for options    
            alternativesList = arrayfun(@(i) sprintf('Channel %d', i), ...
                1:obj.NumChannels, 'UniformOutput', false);

            if numel(alternativesList) > 1
                alternativesList = [{'All Channels'}, alternativesList];
            end
        end

    end

    methods
        function S = getDefaultSettings()

        end
    end

    methods (Static)

        function [jLabel, C] = showSplashScreen()
            
% %             jLabel = simpleLogger;
% %             C = []; return

            filepath = fullfile(nansen.toolboxdir, 'resources', ...
                'images', 'nansen_roiman.png');
            [~, jLabel, C] = nansen.ui.showSplashScreen(filepath, ...
                'RoiManager', 'Initializing imviewer...');
        end

    end
end