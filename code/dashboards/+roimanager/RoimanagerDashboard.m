classdef RoimanagerDashboard < applify.DashBoard & imviewer.plugin.RoiManager
    
    
    % Todo: 
    %   [ ] Why does the imviewer panel resize 3-4 times whenever
    %       showing/hiding the signal viewer panel
    %   [ ] Bug when creating rois and modifying them before the
    %       roisignalarray is initalized.
    %   [ ] Register roitable as a modular app, so that keypresses are
    %       passed on...
    
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
       
       RoiThumbnailViewer = []
       
       TempControlPanel
       TempControlPanelDestroyedListener
    end
    
    
    methods % Structor
        
        function obj = RoimanagerDashboard(varargin)
            
            % Explicit call to superclass constructors.
            obj@applify.DashBoard()
            obj@imviewer.plugin.RoiManager()
           
            % Todo: Get figure position from properties.
            obj.hFigure.Position = [100, 50, obj.FigureSize];
            obj.keepFigureOnScreen()          
            
            obj.Theme = nansen.theme.getThemeColors('dark-purple');
            
            % Initialize modules
            
            % 1) Imviewer
            h = imviewer(obj.hPanels(2), varargin{:});
            h.resizePanelContents()
            obj.AppModules = h;
            obj.configurePanelResizeButton(obj.hPanels(2).Children(1), h)
            
            obj.DialogBox = h.uiwidgets.msgBox;
            
            % Call method for activating the roimanager plugin on imviewer
            obj.activatePlugin(h)
            
            
            
            % 2) Signal viewer
            if ~h.ImageStack.isDummyStack()
                obj.openSignalViewer(obj.hPanels(4))
                obj.addPanelResizeButton(obj.hPanels(4).Children(1))
                obj.AppModules(end+1) = obj.SignalViewer;
            end
            
            % 3) Roi table 
            h = roimanager.RoiTable(obj.hPanels(3), obj.roiGroup);
            h.KeyPressFcn = @(s, e) obj.onKeyPressed(s, e, 'roimanager');
            obj.addPanelResizeButton(obj.hPanels(3).Children(1))
            obj.AppModules(end+1) = h;

            % 4) Roi image display
            
            obj.RoiThumbnailViewer = roimanager.RoiThumbnailDisplay(obj.hPanels(6), obj.roiGroup);
            obj.RoiThumbnailViewer.ImageStack = obj.StackViewer.ImageStack;
            obj.RoiThumbnailViewer.Dashboard = obj;
            
            % Button bar on bottom switching between different panels.
            obj.createToolbar()

            
            obj.IsConstructed = true; % triggers onConstructed which will
            % make figure visible, apply theme etc.
            
            drawnow
            
            obj.TabButtonGroup.Group.Visible = 'on';
            
            
            % Load settings.... Needs to be done after figure is visible
            % due to the way controls are drawn.
            obj.initializeSettingsPanel()
            
        end
        
        function quit(obj)
            
            % Reset this
            obj.settings.Autosegmentation.options = [];
            obj.saveSettings()
            
            
        end
        
        function onFigureCloseRequest(obj)
                        
            wasAborted = obj.promptSaveRois();
            if wasAborted; return; end
            
            onFigureCloseRequest@applify.DashBoard(obj)
            
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
                panelHeights = [25, 0.3, 0.7];
                iA = 3;
                iB = 2;
            else
                panelHeights = [25, 1];
                iA = 2;
            end
            
            [yPos, H] = obj.computePanelPositions(panelHeights, 'y');
            
            
            % - - - Compute widths and xposition for each of the panel rows

            % New positions of panels on top row (controls, imviewer, roitable)
            [xPosA, Wa] = obj.computePanelPositions([200, 0.7, 0.3], 'x');
            
            
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
    
    methods (Access = protected) % Create/configure modules
        
        function initializeSettingsPanel(obj)
            
            P0 = struct();
            P0.ExperimentName = '';
            P0.SampleRate = 31;
            
            [P2, V] = nansen.twophoton.roisignals.getDeconvolutionParameters();
             
            P2.modelType_ = {'ar1', 'ar2', 'exp2', 'autoar'};
            P2.tauRise_ = struct('type', 'slider', 'args', {{'Min', 0, 'Max', 1000, 'nTicks', 100, 'TooltipPrecision', 0, 'TooltipUnits', 'ms'}});
            P2.tauDecay_ = struct('type', 'slider', 'args', {{'Min', 0, 'Max', 5000, 'nTicks', 500, 'TooltipPrecision', 0, 'TooltipUnits', 'ms'}});

            i = 0;
            [structs, names, callbacks] = deal( {} );
            
            i = i+1;
            structs{i} = P0;
            names{i} = 'Experiment Info';
            callbacks{i} = [];
                       
            i = i+1;
            structs{i} = obj.settings.RoiDisplayPreferences;
            names{i} = 'Roi Display';
            callbacks{i} = @obj.onRoiDisplayPreferencesChanged;
            obj.initializeRoiDisplaySettings()
            

            i = i+1;
            structs{i} = obj.settings.Autosegmentation();
            % Todo: Add field for preset selection.
            names{i} = 'Autosegmentation';
            callbacks{i} = @obj.onAutosegmentationOptionsChanged;
            
            i = i+1;
            structs{i} = obj.settings.RoiCuration();
            % Todo: Add field for preset selection.
            names{i} = 'Roi Curation';
            callbacks{i} = @obj.onRoiCurationOptionsChanged;
            
            i = i+1;
            structs{i} = obj.settings.SignalExtraction();
            names{i} = 'Signal Extraction';
            callbacks{i} = @obj.onSignalExtractionOptionsChanged;
            %valueChangedFcn{i} = @obj.onSignalExtractionOptionsChanged;
            
            hSignalViewer = obj.AppModules(2);

            
            i = i+1;
            structs{i} = obj.settings.DffOptions;
            names{i} = 'DFF Options';
            callbacks{i} = @hSignalViewer.onDffOptionsChanged;
            
            i = i+1;
            structs{i} = P2;
            names{i} = 'Deconvolution';
            callbacks{i} = @hSignalViewer.onDeconvolutionParamsChanged;
            
            
            h = structeditor.App(obj.hPanels(1), structs, 'FontSize', 10, ...
                'FontName', 'helvetica', 'LabelPosition', 'Over', ...
                'TabMode', 'dropdown', ...
                'Name', names, ...
                'Callback', callbacks );
            
            obj.AppModules(end+1) = h;
        end

        function initializeRoiDisplaySettings(obj)
            
            fields = {'showNeuropilMask', 'showLabels', 'showOutlines', ...
                'maskRoiInterior', 'showByClassification', 'roiColorScheme'};
            
            for i = 1:numel(fields)
                thisName = fields{i};
                thisValue = obj.settings.RoiDisplayPreferences.(fields{i});
                obj.onRoiDisplayPreferencesChanged(thisName, thisValue)
            end
            
            %defaults = roimanager.roiDisplayParameters; % Todo. Fix this (need to reset some values in this settings on startup..)

            
            % Reset some "transient" fields.
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

        function onRoiDisplayPreferencesChanged(obj, name, value)
                        
            % Todo: move to roiMap class...!
            switch name
                
                case 'showNeuropilMask'
                    obj.roiDisplay.neuropilMaskVisible = value;
                    
                case 'roiColorScheme'
                    obj.roiDisplay.RoiColorScheme = value;
                    
                case 'showByClassification'
                    obj.roiDisplay.showClassifiedCells(value)
                    
                case 'showLabels'
                    obj.roiDisplay.roiLabelVisible = value;
                    obj.toggleShowRoiTextLabels()

                case 'showOutlines'
                    obj.roiDisplay.roiOutlineVisible = value;
                    obj.toggleShowRoiOutlines()
                    
                case 'maskRoiInterior'
                    obj.maskRoiInterior()
                    
                case 'setCurrentRoiGroup'
                    obj.changeCurrentRoiGroup(value)
               
                case 'showRoiGroups'
                    obj.changeVisibleRoiGroups(value)
                    
            end
            
            % Why not set this first??
            obj.settings.RoiDisplayPreferences.(name) = value;

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
                            hPlugin = nansen.plugin.imviewer.EXTRACT(obj.AppModules(1));
                            callbackFcn = @hPlugin.changeSetting;
                            hPlugin.settings = S;
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
                    
                    % Make necessary updates
                    obj.onControlPanelOpened(h2, 'Autosegmentation.options', hPlugin)
                   
                case {'numFrames', 'downsamplingFactor'}
                    numFrames = obj.settings.Autosegmentation.numFrames;
                    dsFactor = obj.settings.Autosegmentation.downsamplingFactor;
                    
                    imSize = [obj.AppModules(1).imHeight, obj.AppModules(1).imWidth];
                    estimatedMemory = prod(imSize(1:2))*numFrames/dsFactor*8;
                    
                    if estimatedMemory > 1e9
                        msg = sprintf( 'Estimated system memory required using these settings: %.1f GB', round(estimatedMemory./1e9, 2) );
                    else
                        msg = sprintf( 'Estimated system memory required using these settings: %.1f MB', round(estimatedMemory./1e6, 2) );
                    end
                    
                    obj.AppModules(1).displayMessage(msg, [], 2)
                    
                case 'run'
                    obj.runAutoSegmentation()
                    
           end
            
        end
        
        function onRoiCurationOptionsChanged(obj, name, value)
                        
            % Update the value in settings.
            obj.settings.RoiCuration.(name) = value;
            
            % Make ui updates for some of the options
            switch name
               
                case 'selectVariable'
                    % Todo: 
                    % Get/set cutoffValues from cutoffValuesRef_
                    
                case 'cutoffValues'
                    % Change selection of classified rois...
                    
                case 'openCurationApp'
                    obj.openManualRoiClassifier()
            
            end
            
        end
        
        function S = getAutosegmentDefaultOptions(obj, methodName)
            
            switch lower(methodName)
                case 'quicky'
                    h = nansen.OptionsManager('quickr.getOptions');
                    S = quickr.getOptions();

                case 'extract'
                    S = nansen.wrapper.extract.Options.getDefaults();

                case 'suite2p'
                    S = nansen.twophoton.autosegmentation.suite2p.Options.getDefaultOptions;

               %case 'cnmf'

                otherwise
                   error('Not implemented')

            end
            
        end
        
        function opts = convertAutosegmentOptions(obj, options, methodName)
            
        end
        
        function onControlPanelOpened(obj, h, targetName, h2)
            obj.TempControlPanel = obj.AppModules(4);
            obj.AppModules(4) = h;
            obj.TempControlPanelDestroyedListener = addlistener(h, ...
                'AppDestroyed',  @(s,e,nm,hp) obj.onControlPanelClosed(targetName, h2) );
                        
        end
        
        function onControlPanelClosed(obj, targetName, h2)
            
            % Get changes
            if obj.AppModules(4).wasCanceled
                S = obj.AppModules(4).dataOrig;
                %obj.AppModules(1).displayMessage('Optio', [], 1.5)
            else
                S = obj.AppModules(4).dataEdit; 
                obj.AppModules(1).displayMessage('Options updated!', [], 1.5)
            end
            
            subs = struct('type', {'.'}, 'subs', strsplit(targetName, '.'));
            obj.settings = subsasgn(obj.settings, subs, S);
            
            delete(obj.AppModules(4))
            delete(h2) % delete plugin...
            obj.AppModules(4) = obj.TempControlPanel;
            obj.hPanels(1).Title = 'Controls';
            
            delete(obj.TempControlPanelDestroyedListener)
            obj.TempControlPanelDestroyedListener=[];
        end
        
    end
    
    methods (Access = protected)
        
        function onKeyPressed(obj, src, evt, module)
            
            if nargin < 4
                onKeyPressed@applify.DashBoard(obj, src, evt)
            else
                switch module
                    case 'roimanager'
                        obj.AppModules(1).onKeyPressed(src, evt, true)
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
    
            buttonNames = {'Signal Viewer', 'Signal Rastermap', 'Roi Info', 'Roi History Plot'};
            
            for i = 1:numel(buttonNames)
                hBtn(i) = hToolbar.addButton('Text', buttonNames{i}, buttonProps{:});
            end
            
            hBtn(1).Value = true;
            hBtn(3).Value = true;

            obj.TabButtonGroup.Group = hToolbar;
            obj.TabButtonGroup.Buttons = hBtn;
            
            
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
    
    
    methods
        function S = getDefaultSettings()
            
            
        end
    end
end