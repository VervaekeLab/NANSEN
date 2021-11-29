classdef App < applify.ModularApp & uiw.mixin.AssignPVPairs
%structeditor.App An autoassembling viewer for editing a struct.
%
%   This class provides properties and methods for creating a viewer for
%   editing the values of fields in a struct. It can also have a callback
%   assigned, which will be invoked whenever a values is changed
%
%       h = structeditor(S) creates an app for editing struct S and assigns
%       the app object to h.
%   
%       Types of variables that are supported:
%           chars  -> text edit control
%           numbers -> numeric edit contol
%           logicals -> tickbox
%   
%       The control generated for a field can be customized using a field
%       that has the same name but with an underscore appended.
%       For example:
%           S.fruitChoices = 'apple'
%           S.fruitChoices_ = {'apple', 'mango', 'pear'}
%       ... will generate a dropdown menu where the value is apple, and the
%       choices are apple, mango and pear.
%
%       Other configurations:
%           rangeslider
%           button
%
%
%   PARAMETERS:    


%   Main things to change:
%
%       [x] Fix Scroller... Does it need its own panel???
%       [ ] Scrollerposition does not reset to top when changing tabs... 
%      *[ ] Implement dependable fields...
%       [ ] Implement transient fields
%           Q: 1) How are these updated? Is there any way of making that
%           simple, or not? True/false, enable/diable... 
%              2) Make data models?
%      *[x] Make a struct with the same fields as the input struct
%           containing the controls. Will be much easier to find things 
%           back and update things when needed.
%       [ ] Fix onMouseMotion bug (if closing a docked structeditor??)
%       [ ] Use toolbar_ for tabbuttons.
%       [ ] Add separators with section titles.
%       [ ] Improve disabling of pages! Or just find out how to best
%           disable controls...
%       [ ] Create own class for footer (preset selector)
%       [ ] Add a star (*) next to default options in the list of names for preset options... 
%       [ ] Create context menu for preset managing
%       [x] Create functionality for tabbuttons in header (added dropdown)
%       [ ] Replace eval with subsref and subsassign for nested structs.
%       [ ] Implement methods for creating controls, and for updating 
%           control values. I.e split up and generalize the newInputField
%           method.
%       [x] Add input parser.
%       [ ] Better use of space in modular versions.
%       [x] Resizing in modular version.
%       [ ] Fix focus issue when using undecorateFig.

%   Minor things to look into:
%       [ ] Resize figure width after creation if some text labels do not fit
%       [ ] Make sure long titles does not extend to save and cancel buttons.
%       [ ] Browse button is assymmetric
%       [ ] Tickbox update can be very slow when pressing it to tick it. Try it
%           in fovmanager for example. Think this was fixed at some point 
%       [ ] uicontrolSchemer might not be deleted. The objectBeingdestroyed
%           listener is not saved anywhere, so its deleted

    properties (Constant) % Inherited from applify.ModularApp
        AppName = 'Options Editor'
    end
    
    properties (Constant, Hidden = true) % Move to appwindow superclass
        DEFAULT_THEME = nansen.theme.getThemeColors('dark-purple');
        ICONS = uim.style.iconSet(structeditor.App.getIconPath)

    end
    
    properties % Configurations of appearance and layout of app
        
        Title = '' % Title description.
        showPresetInHeader = false;
        
        LabelPosition = 'Left' % 'Left' | 'Over'
        
        Name = ''           % Name of struct... (or names of all substructs)...
        
        TabMode = 'sidebar' % 'sidebar' | 'dropdown' | 'sidebar-popup'
        
        FontName = 'Avenir Next'
        FontSize = 14
        
        RowHeight = 30;
        RowSpacing = 10;
        ColSpacing = 10;
        Margins = [160, 45, 15, 45] % Layout. Space for header/footer + sidepanels

        
    end
    
    properties % Options manager / preset selection
        OptionsManager = []
        PresetSelection = ''
    end
    
    properties % Callback properties. Need to clean 
        Callback     
        TestFunc % Why is there a second one????
        
        ValidationFcn % todo
        ValueChangedFcn
    end

    properties % Data and flags
        dataOrig
        dataEdit
        
        hControls
        
        wasCanceled = false;
        currentPresetName = '' % Name of currently selected preset.
    end
    
    properties (Access = private) % Internal properties. Need to clean
        
        hJFrame
        hAxes
        
        hControlsPage
        
        numTabs
        isTabCreated = false
        currentPanel = 1
         
        TabButtonGroup      
        
        headerTitle
        PresetControls
        
        header
        sidebar
        main
        hScroller
        footer
        
        uiPanel
        subPanel % todo: move panels to same variable
        
        currentObjectInFocus = struct('handle', gobjects(1), 'props', {{}})
        tooltipHandle
        
        visibleHeight
        visibleWidth
        virtualHeight
        
        lastScrollValue = 0
        figureCallbackStore
        
        pleaseWaitTxt

        headerSubtitle
        sidePanelToggleButton
        presetDropdown
    end 
    
    properties (Access = protected, Dependent, Hidden = true )

        showFooter
        showSidePanel
        showSidePanenButton
    end
    
    properties (Access = private, Hidden = true)
        ConvertOutputToStruct = false % Convert output to struct. Struct of struct is converted to cell, need to convert back before outputting
        Debug = false
    end
    
    events
        AppDestroyed
    end
    
    methods % Structors
        
        function obj = App(varargin)
            
            % Split off parent handle from args (if given) and call 
            % superclass constructor for ModularApp
            [h, varargin] = applify.ModularApp.splitArgs(varargin{:});
            obj@applify.ModularApp(h);
            
            if nargin < 1
                return
            end
            
            obj.Panel.Units = 'normalized'; 
            % Todo: Fix this. Why does panel get pixel units from superclass

            % Validate first entry of remaining varargin. Should be a 
            % struct or a cell array of structs. 
            [S, varargin] = structeditor.validateStruct(varargin{:});
            % Above function fails if S is invalid. varargin has S removed
            
            obj.assignPVPairs(varargin{:});
            obj.parseStruct(S)
            
            % Use static method of AppWindow to turn off all java related
            % warnings. (Should be inherited at some point)
            applify.AppWindow.switchJavaWarnings('off')
            
            obj.customizeFigure()
            
            % Start GUI initialization
            obj.createPanels()
            
            obj.Panel.Visible = 'on';
            
            % Resize panels before creating components
            obj.resizePanel()
            
            % Create components for first panel..
            obj.addComponents(1)

            if exist('applify.uicontrolSchemer', 'class')==8
                obj.styleControls(1)
                
                if obj.showFooter
                    h = applify.uicontrolSchemer(obj.PresetControls);
                    el = addlistener(obj, 'ObjectBeingDestroyed', @(src,evt) delete(h));
                    drawnow
                end
                
            end

            % Find handles of all uicontrols.
            hUic = findobj(obj.header.hPanel, 'type','uicontrol'); 
            
            % Make them look good.
            if ~isempty(hUic)
                h = applify.uicontrolSchemer(hUic);
                el = addlistener(obj, 'ObjectBeingDestroyed', @(src,evt) delete(h));
            end
            
            
%             % Center position of figure on screen
%             screenSize = get(0, 'ScreenSize');
%             obj.Figure.Position(1:2) = screenSize(3:4)/2 - obj.Figure.Position(3:4)/2;
            

            % Make size fixed, and add close callback
            
            obj.createScrollBar();
            
            applify.AppWindow.switchJavaWarnings('on')
            
            obj.pleaseWaitTxt.Parent = obj.main.constructionCurtain;
            obj.pleaseWaitTxt.Position(3) = obj.pleaseWaitTxt.Extent(3); 
            obj.pleaseWaitTxt.Position(1) = 0.5 - obj.pleaseWaitTxt.Position(3)/2;

            delete(obj.main.tmpPanel)
            obj.main.constructionCurtain.Visible = 'off';
           

            obj.isConstructed = true;
            
            % Need to assign windowbuttonmotion function for rangebars to
            % work...
            if strcmp(obj.mode, 'standalone') || isempty(obj.Figure.WindowButtonMotionFcn)
                obj.Figure.WindowButtonMotionFcn = @obj.onMouseMotion;
            end
            
            if ~nargout
                clear obj
            end
            
        end
        
        function delete(obj)
            if strcmp( obj.mode, 'standalone' )
                if isvalid(obj.Figure)
                    delete(obj.Figure)
                end
            end
        end
        
    end
    
    methods % Set/get
        
        function set.Title(obj, newValue)
            assert( ischar(newValue), 'Title must be a character vector')
            
            obj.Title = newValue;
            obj.setFigureName()
        end
        
        function tf = get.showFooter(obj)
            tf = ~isempty(obj.OptionsManager);
        end
        
        function tf = get.showSidePanel(obj)
            tf = obj.numTabs > 1 && contains(obj.TabMode, 'sidebar');
        end
        
    end
    
    methods (Access = protected) % Window / panel configurations
         
        function createAppWindow(obj)

            createAppWindow@applify.ModularApp(obj)

            obj.Figure.Resize = 'off';
            obj.Figure.Position = obj.initializeFigurePosition();
        
            obj.Figure.CloseRequestFcn = @(s, e, action) obj.quit('Cancel');

        end
        
        function customizeFigure(obj)
            
            if strcmp(obj.mode, 'standalone')
                if obj.showSidePanel && ~contains(obj.TabMode, 'popup') % make space for panel with tab buttons.
                    obj.Figure.Position(3) = obj.Figure.Position(3) + 100;
                end
                
            end
            
            obj.setDefaultFigureCallbacks()
            
            obj.setFigureName()
            
            if ~obj.showFooter
                obj.Margins(2) = 0;
            end
            
            if ~obj.showSidePanel || contains(obj.TabMode, 'popup')
                obj.Margins(1) = 0;
            end
            
        end
        
        function pos = initializeFigurePosition(obj)
        % Use for when restoring figure size from maximized
            
            % Todo: get from settings/preferences
            width = 470;
            height = 470;
        
            screenSize = get(0, 'ScreenSize');
            figLocation = [100, screenSize(4) - 100 - height];
            figLocation = [130   190];
            pos = [figLocation, width, height];
        
        end
        
        function setFigureName(obj)
            isValidFigure = ~isempty(obj.Figure) && isvalid(obj.Figure);

            if isValidFigure && strcmp(obj.mode, 'standalone')
                if isempty(obj.Title)
                    obj.Figure.Name = obj.AppName;
                else
                    obj.Figure.Name = sprintf('%s (%s)', obj.AppName, obj.Title);
                end
                
            else
                % Todo: Where do we plot name???
            end
        end
        
        
% %         function setDefaultFigureCallbacks(obj, hFig)
% %             if nargin < 2 || isempty(hFig)
% %                 hFig = obj.Figure;
% %             end
% %             
% %             hFig.WindowKeyPressFcn = @obj.onKeyPressed;
% %             hFig.WindowKeyReleaseFcn = @obj.onKeyReleased;
% %         end
        
        function updateHeaderTitle(obj, pageNum)
            
            if nargin < 2   
                pageNum = obj.currentPanel;
            end
            
            % Update header title
            if ~strcmp(obj.TabMode, 'dropdown')
                if obj.showPresetInHeader
                    obj.headerTitle.String = sprintf('Current Preset:\n%s', 'Default');
                else
                    obj.headerTitle.String = sprintf('Edit %s', obj.Title);
                end
            end
            
            if obj.showSidePanel && contains(obj.TabMode, 'popup')
                obj.headerSubtitle.String = obj.Name{pageNum};
%                 if obj.headerSubtitle.Extent(1) < 1 ??
%                     obj.headerSubtitle.Position(1) = 1;
%                 else
%                     
%                 end
            end
            
        end
        
        function resizePanel(obj, src, evt)
        %resizePanel Callback for resizing panels.
        %
        %   Header/footer and sidebar panels should have fixed sizes in
        %   pixels vertically and horizontally respectively. 
        %
        %   Note: All calculations are done in pixels..   
        
            % Get size of the main panel.
            panelPixelSize = getpixelposition(obj.Panel);
            panelWidth = panelPixelSize(3);
            panelHeight = panelPixelSize(4);            
            
            % Note: The control panel is configured as a scrollpanel, so just
            % need to update the visibleHeight property, and should not
            % update y-positions
            obj.visibleHeight = panelHeight - sum( obj.Margins([2,4]) );
            obj.visibleWidth = panelWidth - sum( obj.Margins([1,3]) );
            
            % Calculate positions for each subpanel
            headerPos = [0, panelHeight-obj.Margins(4), panelWidth, obj.Margins(4)+2];            
            footerPos = [0, 0, panelWidth, obj.Margins(2)];
            scrollPanelPos = [panelWidth-obj.Margins(3), obj.Margins(2)+1, obj.Margins(3), obj.visibleHeight-1];
            mainPos = [obj.Margins(1), obj.Margins(2), obj.visibleWidth, obj.visibleHeight];
            sidebarPos = [0, obj.Margins(2), obj.Margins(1), obj.visibleHeight];
            
            % Set positions using pixel units.
            setpixelposition(obj.header.hPanel, headerPos);
            setpixelposition(obj.sidebar.hPanel, scrollPanelPos); % TODO: Rename
            setpixelposition(obj.main.constructionCurtain, [obj.Margins(1:2), obj.visibleWidth, obj.visibleHeight]);
            %setpixelposition(obj.main.tmpPanel, mainPos)
            
            obj.resizeControlPanel(obj.currentPanel, mainPos)
            
            if ~isempty(obj.hScroller)
                obj.updateScrollbar(obj.currentPanel)
            end

            if obj.showSidePanel
                if contains(obj.TabMode, 'popup')
                    sidebarPos(3) = 150;
                end
                setpixelposition(obj.uiPanel.Tab, sidebarPos);
                obj.uiPanel.Tab.UserData.Separator.Position([1,3]) = sidebarPos(3) .* [1,1];
            end
            
            if obj.showFooter
                setpixelposition(obj.footer.hPanel, footerPos);
            end
            
            drawnow limitrate
            
        end
        
        function resizeControlPanel(obj, pageNum, newPosition)
        %resizeControlPanel Resize control panel for given page.
        
            % Panel/page is not create yet...
            if isempty(obj.visibleWidth); return; end
            
            if nargin < 3
                newPosition = [obj.Margins(1:2), obj.visibleWidth, obj.visibleHeight];
            end
            
            % Panel height should be same as virtual height.
            if ~isnan(obj.virtualHeight(pageNum))
                newPosition(4) = obj.virtualHeight(pageNum);

                if newPosition(4) < obj.visibleHeight
                    newPosition(2) = newPosition(4) - obj.visibleHeight;
                end
            else
                newPosition(4) = obj.visibleHeight;
            end

            setpixelposition(obj.main.hPanel(pageNum), newPosition);

            if isfield(obj.main, 'hAxes')  
                obj.main.hAxes(pageNum).Position(3) = newPosition(3);
                obj.main.hAxes(pageNum).Position(4) = newPosition(4);
                set(obj.main.hAxes(pageNum), 'XLim', [0,newPosition(3)], 'YLim', [0, newPosition(4)]);
                obj.moveElementsToTop()
            end
            
        end
        
        function onConstructed(obj)
        % Overrides superclass method because turning figure visibility on 
        % also requires to delete a panel...
        
            obj.setDefaultFigureCallbacks()
            obj.onThemeChanged()
            
            if strcmp(obj.mode, 'standalone')
                obj.showFigure();
            end
            
        end
        
        function onThemeChanged(obj)

            % Todo: Apply changes to toolbars and widgets as well!

            S = obj.Theme;
            onThemeChanged@applify.ModularApp(obj)
                    
            obj.setFigureWindowBackgroundColor( S.FigureBgColor )

            allPanels = [obj.header.hPanel, obj.sidebar.hPanel, obj.main.hPanel];
            set(allPanels, 'BackgroundColor', obj.Theme.FigureBgColor)
            
            if obj.showSidePanel
                bgColor = min( [1,1,1 ; obj.Theme.FigureBgColor+0.01] );
                set(obj.uiPanel.Tab, 'BackgroundColor', bgColor)
            end
            
        end
        
    end
    
    methods (Access = private) % Gui initialization
        
        function setFigureWindowBackgroundColor(obj, newColor)
        % Todo: Should be a superclass method i.e appwindow.
            if nargin < 2
                newColor = [13,13,13] ./ 255;
            end

            rgb = num2cell(newColor);

            warning('off', 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
            warning('off', 'MATLAB:ui:javaframe:PropertyToBeRemoved')

            % Its disappearing any day now!
            jFrame = get(handle(obj.Figure), 'JavaFrame');
            jWindow = jFrame.getFigurePanelContainer.getTopLevelAncestor;
            javaColor = javax.swing.plaf.ColorUIResource(rgb{:});
            set(jWindow, 'Background', javaColor)

            warning('on', 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
            warning('on', 'MATLAB:ui:javaframe:PropertyToBeRemoved')

        end 

        function createPanels(obj)
        %createPanels Create the gui panels
            
            
            % Create a panel for controls for each of structs to be edited.
            for i = 1:obj.numTabs
                obj.main.hPanel(i) = uipanel(obj.Panel, 'Visible', 'off');
                obj.main.hPanel(i).SizeChangedFcn = @(s,e) obj.resizeControlPanel(i);
            end
        
            % Create a temporary panel to cover up uicontrols while they
            % are rendered and the style is updated. This should be above
            % the uicontrols, but below the other panels
            obj.main.constructionCurtain = uipanel(obj.Panel, 'Units', 'pixel');
            obj.main.constructionCurtain.BackgroundColor = obj.Theme.FigureBgColor;
            obj.main.constructionCurtain.BorderType = 'none';
            
            if obj.Debug
                obj.main.constructionCurtain.Visible='off';
            end
            
            % Create sidebar panel for scroller
            obj.sidebar.hPanel = uipanel(obj.Panel);
            
            % Create panel for tab buttons if struct is multipaged:
            if obj.showSidePanel
                obj.uiPanel.Tab = uipanel(obj.Panel);
            end
            

            % Create header (and footer) panel last to keep them on top!
            obj.header.hPanel = uipanel(obj.Panel);

            
            if obj.showFooter
                obj.footer.hPanel = uipanel(obj.Panel);
            end
            
            % Todo: Remove this shit!
            obj.main.disablePanel = uipanel(obj.Panel, 'Visible', 'off');
            
            set( obj.main.hPanel(1), 'Visible', 'on' )
            
            
            % Create a temporary panel to cover up uicontrols while they
            % are rendered and the style is updated.
            obj.main.tmpPanel = uipanel(obj.Panel);
            obj.main.tmpPanel.BackgroundColor = obj.Theme.FigureBgColor;
            obj.main.tmpPanel.BorderType = 'none';
            
            if obj.Debug
                obj.main.tmpPanel.Visible='off';
            end
            
            
            obj.pleaseWaitTxt = uicontrol(obj.main.tmpPanel, 'style', 'text');
            obj.pleaseWaitTxt.String = 'Please Wait...';
            obj.pleaseWaitTxt.HorizontalAlignment = 'center';
            obj.pleaseWaitTxt.ForegroundColor = obj.Theme.FigureFgColor;
            obj.pleaseWaitTxt.BackgroundColor = obj.Theme.FigureBgColor;
            obj.pleaseWaitTxt.FontSize = 10;
            obj.pleaseWaitTxt.Position = obj.pleaseWaitTxt.Extent;
            obj.pleaseWaitTxt.Units = 'normalized';
            obj.pleaseWaitTxt.Position(2) = 0.5;
            obj.pleaseWaitTxt.Position(1) = 0.5 - obj.pleaseWaitTxt.Position(3)/2;
            
            
            obj.resizePanel()

            % Add all panels to array for customization
            allPanels = [obj.header.hPanel, obj.sidebar.hPanel, obj.main.hPanel, obj.main.disablePanel];
            if obj.showSidePanel;  allPanels = [allPanels, obj.uiPanel.Tab];   end
            if obj.showFooter;     allPanels = [allPanels, obj.footer.hPanel]; end
                
            % Customize panel appearance
            set(allPanels, 'BackgroundColor', obj.Theme.FigureBgColor)
            set(allPanels, 'BorderType',  'none')
            

            obj.main.disablePanel.BackgroundColor = 'w';
            
% % %             %[output, jPanel, ~, ~, ~] = evalc( findjobj(obj.main.disablePanel) );
% % %             jPanel = findjobj(obj.main.disablePanel);
% % %             
% % %             jColor = java.awt.Color(1,1,1,0.3);
% % %             jPanel.setBackground(jColor)
% % %             h1 = jPanel.getComponent(0);
% % %             set(h1, 'Opaque', false);
% % %             h2 = h1.getComponent(0);
% % %             set(h2, 'Opaque', false);
% % %             
% % %             h0 = jPanel.getParent();
% % %             set(h0, 'Opaque', false);
            

            obj.main.disablePanel.Visible = 'off';
            %get(jPanel, 'Opaque')
            
            
            % Set up/configure individual panels.
            obj.createHeaderComponents()
            
            if obj.showSidePanel
                obj.createTabPanel()
            end
            
            obj.createControlPanelAxes()
            
            if obj.showFooter
                obj.createFooterComponents()
            end
        end
        
        function createDisablePanel(obj)
            
        end
        
        function createHeaderComponents(obj)
        %createHeaderComponents Configure and add components to header.
                      
            % Create axes to display text and "buttons"
            obj.header.hAxes = axes('Parent', obj.header.hPanel, 'Position', [0,0,1,1]);
            obj.header.hAxes.Visible = 'off';
            set(obj.header.hAxes, 'XLim', [0,1], 'YLim', [0,1])
            hold(obj.header.hAxes, 'on')
            
            % Patch the entire axes with an invisible but pickable object.
            % Can be used for moving the figure if undercoratedFigure is
            % active.
            hhp = patch(obj.header.hAxes, [0,0,1,1], [0,1,1,0], 'c');
            hhp.FaceAlpha = 0;
            hhp.PickableParts = 'all';
            hhp.ButtonDownFcn = @obj.startMoveWindow;
                     
            % Plot line separating header from rest of figure
            plot(obj.header.hAxes, [0,1], [0,0], 'Color', obj.Theme.FigureFgColor*0.5)
            
            % Create header title
            if strcmp(obj.mode, 'standalone')
                hTxt = text(obj.header.hAxes, 0.1, 0.5, '');
                hTxt.Color = obj.Theme.FigureFgColor;
                hTxt.FontSize = 14;
                hTxt.FontName = obj.FontName;
                hTxt.FontWeight = 'normal';
                obj.headerTitle = hTxt;
            else
                obj.headerTitle = uicontrol(obj.header.hPanel, 'style', 'text');
                obj.headerTitle.String = '';
                obj.headerTitle.HorizontalAlignment = 'center';
                obj.headerTitle.ForegroundColor = obj.Theme.FigureFgColor;
                obj.headerTitle.BackgroundColor = min([1,1,1;obj.Theme.FigureBgColor+0.05]);
                obj.headerTitle.HitTest = 'off';
                obj.headerTitle.FontSize = 10;
                obj.headerTitle.Position = [50,5,100,35];
            end
            
            obj.headerSubtitle = uicontrol(obj.header.hPanel, 'style', 'text');
            obj.headerSubtitle.String = '';
            obj.headerSubtitle.HorizontalAlignment = 'center';
            obj.headerSubtitle.ForegroundColor = obj.Theme.FigureFgColor;
            obj.headerSubtitle.FontSize = 10;
            obj.headerSubtitle.Position = [2,3,48,15];

            obj.updateHeaderTitle()
            
            % Create a dropdown for changing panels
            if obj.numTabs > 1 && strcmp(obj.TabMode, 'dropdown')
                obj.createTabDropdownSelector()
            end
            
            
            % Create a button for showing/hiding tabpanel
            if obj.showSidePanel && contains(obj.TabMode, 'popup')
                
                btnProps = {'Icon', obj.ICONS.tab1, 'Location', 'northwest', ...
                    'Size', [22,22], ...
                    'Margin', [13,8,0,8], 'Mode', 'togglebutton', ...
                    'Value', 0, 'Style', uim.style.buttonSymbol, ...
                    'Callback', @obj.onToggleSidePanelVisibilityButtonPressed};
                hButton = uim.control.Button_(obj.header.hPanel, btnProps{:});
                obj.sidePanelToggleButton=hButton;
            end
            
            %if strcmp( obj.mode, 'docked' ); return; end
            if strcmp( obj.TabMode, 'dropdown' ); return; end
            
            createFinishButtons(obj)
            
        end

        function createFooterComponents(obj)
            
            fgColor = obj.Theme.FigureFgColor;
            
            % Create axes to display components
            obj.footer.hAxes = axes('Parent', obj.footer.hPanel, 'Position', [0,0,1,1]);
            obj.footer.hAxes.Visible = 'off';
            set(obj.footer.hAxes, 'XLim', [0,1], 'YLim', [0,1])
            hold(obj.footer.hAxes, 'on')
            
            % Plot line separating header from rest of figure
            plot(obj.footer.hAxes, [0,1], [1,1], 'Color', obj.Theme.FigureFgColor*0.5)
            
            % Create a textbox with the property name
            textbox = text(obj.footer.hAxes, 0.03, 0.5, '');
            textbox.VerticalAlignment = 'middle';
            textbox.String = 'Presets:';
            textbox.Color = obj.Theme.FigureFgColor*0.8;
            textbox.FontName = obj.FontName;
            textbox.FontSize = obj.FontSize;
            
            if obj.numTabs > 1
                X = [80, 300, 420];
                W = [180, 100, 100];
            else
                X = [80, 220, 340];
                W = [120, 100, 100];
            end
            
            % Todo: Save to property...
            hDropdown = uicontrol(obj.footer.hPanel, 'style', 'popupmenu');
            hDropdown.String = {'Custom'};
            hDropdown.Value = 1;
            hDropdown.Position = [X(1), 12, W(1), 22];
            hDropdown.ForegroundColor = obj.Theme.FigureFgColor*0.8;
            hDropdown.FontName = obj.FontName;
            hDropdown.FontSize = obj.FontSize;
            hDropdown.Callback = @obj.onPresetChanged;
            
            obj.refreshPresetDropdown(hDropdown)
            obj.presetDropdown = hDropdown;
            
            if ~isempty(obj.PresetSelection)
                obj.setPresetSelection(obj.PresetSelection)
            end
            
            obj.currentPresetName = obj.getCurrentPresetSelection(hDropdown);
            
            hButton1 = uicontrol(obj.footer.hPanel, 'style', 'pushbutton');
            hButton1.String = 'Save Preset';
            hButton1.Position = [X(2), 12, W(2), 22];
            hButton1.ForegroundColor = obj.Theme.FigureFgColor*0.8;
            hButton1.FontName = obj.FontName;
            hButton1.FontSize = obj.FontSize;
            hButton1.Callback = @(s,e,h) obj.savePreset(hDropdown);
            
            hButton2 = uicontrol(obj.footer.hPanel, 'style', 'pushbutton');
            hButton2.String = 'Make Default';
            hButton2.Position = [X(3), 12, W(3), 22];
            hButton2.ForegroundColor = obj.Theme.FigureFgColor*0.8;
            hButton2.FontName = obj.FontName;
            hButton2.FontSize = obj.FontSize;
            hButton2.Callback = @(s,e,h) obj.makePresetDefault(hDropdown);

            obj.PresetControls = [hDropdown, hButton1, hButton2];
            
            
        end
        
        function createTabDropdownSelector(obj)
            
            parentSize = getpixelposition(obj.header.hPanel);
            
            dropdownSize = [150, 25];
            dropdownPadding = ( parentSize(3:4) - dropdownSize ) ./ 2;
            dropdownPadding(2) = dropdownPadding(2)+1;
            
            h = uicontrol(obj.header.hPanel, 'style', 'popupmenu');
            h.Position = [dropdownPadding, dropdownSize];
            h.String = obj.Name;
            h.Value = 1;
            h.ForegroundColor = obj.Theme.FigureFgColor*0.8;
            h.HorizontalAlignment = 'left';
            h.FontName = obj.FontName;
            h.FontSize = obj.FontSize+2;
            h.Callback = @obj.onDropdownSelected;
            
        end
        
        function createFinishButtons(obj)
        %createFinishButtons Create save and cancel buttons
        
                
% % %             hToolbar = uim.widget.toolbar_(obj.header.hPanel, ...
% % %                 'Location', 'east', 'VerticalAlignment', 'middle', ...
% % %                 'Margin', [0,0,10,20],'ComponentAlignment', 'left', ...
% % %                 'BackgroundAlpha', 0, 'IsFixedSize', [false, true], ...
% % %                 'Size', [inf, 24], ...
% % %                 'NewButtonSize', [16,16], 'Padding', [0,0,0,0], ...
% % %                 'Spacing', 0);
% % %             
% % %             buttonConfig = {'FontSize', 15, 'FontName', obj.FontName, ...
% % %                 'Padding', [2,2,2,2], 'CornerRadius', 2, ...
% % %                 'Mode', 'pushbutton', 'Style', uim.style.buttonSymbol, ...
% % %                 'IconSize', [16,16], 'IconTextSpacing', 7};
% % %             
% % %             btnIcon = {obj.ICONS.save2, obj.ICONS.cancel2};
% % %             btnName={'Save', 'Cancel'};
% % %             for i = 1:2
% % %                 hToolbar.addButton('Icon', btnIcon{i}, 'Tooltip', btnName{i}, ...
% % %                     'Callback', @(s, e, action) obj.quit(btnName{i}), buttonConfig{:})
% % %             end
% % %             
% % %             % Update location after buttons are created..
% % %             hToolbar.Location = 'east';
% % % 
% % %             return
        
        
            xPos = [0.84, 0.94];
            yPos = 0.5;
            margin = [8, 8];
            offset = [0.5, 0];
            
            btnName = {'Save', 'Cancel'};
            
            hV = plot(obj.header.hAxes, xPos(1), yPos, 'o', 'MarkerSize', 12, 'LineWidth', 2);
            hV.Color =[0.1840    0.7037    0.4863]; % obj.Theme.FigureFgColor;
            hV.LineWidth = 1.5;

            hX = plot(obj.header.hAxes, xPos(2), yPos, 'x', 'MarkerSize', 14);
            hX.Color = obj.Theme.FigureFgColor;
            hX.LineWidth = 1.5;
            
            hBtn = gobjects(2,1);
            
            for i = 1:2
                % Get coordinates for patching a box under the X.
                bgSize = hX.MarkerSize + margin(i);
                
                [edgeX, edgeY] = uim.shape.rectangle([bgSize, bgSize], 4);
                %edgeX = edgeX + offset(i);
                
                % Convert edge coordinates to data units (Transpose because
                % input to px2du is nPoints x 2 and output from createBox is 
                % row-vectors.
                edgeCoords = uim.utility.px2du(obj.header.hAxes, [edgeX', edgeY']);
                edgeCoords = edgeCoords - min(edgeCoords);

                % Shift coordinates to be centered on xPos and yPos.
                edgeCoords = [xPos(i), yPos] + edgeCoords - range(edgeCoords)/2;

                hBtn(i) = patch(edgeCoords(:,1), edgeCoords(:,2), 'w');
                hBtn(i).Parent = obj.header.hAxes;
                
                % Configure patch which will be visible when hovering over X
                hBtn(i).FaceColor = obj.Theme.FigureFgColor;
                hBtn(i).EdgeColor = 'none';
                hBtn(i).FaceAlpha = 0;
                hBtn(i).PickableParts = 'all';
                hBtn(i).Tag = sprintf('%s Button', btnName{i});
                hBtn(i).ButtonDownFcn = @(s, e, action) obj.quit(btnName{i});

            end
            
            % Create a tooltip...
            obj.tooltipHandle = text(obj.header.hAxes, 1,1, '');
            obj.tooltipHandle.BackgroundColor = obj.Theme.FigureBgColor*0.8;
            obj.tooltipHandle.Color = obj.Theme.FigureFgColor;
            obj.tooltipHandle.EdgeColor = 'none';
            obj.tooltipHandle.FontName = obj.FontName;
            obj.tooltipHandle.FontSize = obj.FontSize;
            obj.tooltipHandle.HorizontalAlignment = 'right';
            obj.tooltipHandle.Visible = 'off';
            obj.tooltipHandle.HitTest = 'off';
            obj.tooltipHandle.PickableParts = 'none';
            
        end
                
        function createTabPanel(obj)
        %createTabPanel Configure and add tab buttons to tabpanel
        
            if contains(obj.TabMode, 'popup')
                xPad = 10;
                w = obj.Margins(1);
            else
                xPad = 10;
                w = obj.Margins(1);
            end
            
            % Mis-use header text for testing size of button text...
            fontSize = obj.headerTitle.FontSize;
            units = obj.headerTitle.Units;
            obj.headerTitle.Units = 'pixels';
            obj.headerTitle.FontSize = 15;
            width = 0;
            for i = 1:numel(obj.Name)
                obj.headerTitle.String = utility.string.varname2label(obj.Name{i});
                width = max([width, obj.headerTitle.Extent(3)]);
            end
            obj.headerTitle.FontSize = fontSize;
            obj.headerTitle.Units = units;
            obj.headerTitle.String = '';
            
            width = width + 12 + xPad*2 + 7; % 12=iconsize, 7 = icontextspacing..
            %width = max([width, obj.Margins(1)]);
            
            hToolbar = uim.widget.toolbar_(obj.uiPanel.Tab, 'Location', 'northwest', ...
                'Margin', [0,0,0,10],'ComponentAlignment', 'top', ...
                'BackgroundAlpha', 0, 'IsFixedSize', [true, false], ...
                'NewButtonSize', [width, 25], 'Padding', [0,10,0,10], ...
                'Spacing', 0);

            buttonConfig = {'FontSize', 15, 'FontName', obj.FontName, ...
                'Padding', [xPad,2,xPad,2], 'CornerRadius', 0, ...
                'Mode', 'togglebutton', 'Style', uim.style.tabButton2, ...
                'IconSize', [12,12], 'IconTextSpacing', 7};
            
            % Bug with toolbar so buttons are created from the bottom up
            counter = 0;
            for i = numel(obj.Name):-1:1
                counter = counter+1;
                
                if any(strcmpi(obj.ICONS.iconNames, obj.Name{i}) )
                    icon = obj.ICONS.(lower(obj.Name{i}));
                else
                    icon = obj.ICONS.default;
                end

                obj.TabButtonGroup.Buttons(counter) = hToolbar.addButton(...
                    'Text', utility.string.varname2label(obj.Name{i}), 'Icon', icon, ...
                    'Callback', @(s,e,n) obj.onTabButtonPressed(s,e,i), ...
                    buttonConfig{:} );
                if i == 1
                    obj.TabButtonGroup.Buttons(counter).Value = true;
                end
            end
            
            obj.TabButtonGroup.Group = hToolbar;
            
            
            % Adjust margins/sidebar to fit with tabbuttons
            if strcmp(obj.TabMode, 'sidebar') && strcmp(obj.mode, 'standalone')
                deltaWidth = width - obj.Margins(1);
                obj.Margins(1) = width;
                obj.Figure.Position(3) = obj.Figure.Position(3) + deltaWidth;
            end
            
            panelPos = getpixelposition(obj.uiPanel.Tab);
            linePos([1,3]) = floor([panelPos(3), panelPos(3)]);
            linePos([2,4]) = [1, panelPos(4)];
            
            h = uim.decorator.Line(obj.uiPanel.Tab, ...
                'Position', linePos, ...
                'ForegroundColor', obj.Theme.FigureFgColor*0.5);
            obj.uiPanel.Tab.UserData.Separator = h;
            
            if obj.showSidePanel && contains(obj.TabMode, 'popup')
                obj.uiPanel.Tab.Visible = 'off';
                hToolbar.Location = 'northwest';
            end
            
        end
        
        function createControlPanelAxes(obj)
        %createControlPanelAxes Create plotting axes in the main panel/panels
        
            % Todo: consider to use the UiComponentCanvas class instead.
            
            % Create axes for texting and plotting
            for i = 1:obj.numTabs
                obj.main.hAxes(i) = axes('Parent', obj.main.hPanel(i), 'Position', [0,0,1,1]);
            end
            
            set(obj.main.hAxes, 'Visible', 'off')
            set(obj.main.hAxes, 'HandleVisibility', 'on')
            set(obj.main.hAxes, 'Tag', 'UicStylerAxes');
            
            set(obj.main.hAxes, 'Units', 'pixel');
            
            axSize = obj.main.hAxes(1).Position(3:4);
            set(obj.main.hAxes, 'XLim', [0,axSize(1)], 'YLim', [0,axSize(2)])
            
            arrayfun( @(ax) hold(ax, 'on'), obj.main.hAxes)

        end
        
        function createScrollBar(obj)
        % Create a scrollbar on the panel if all the fields do not fit in the panel
        
            % Todo: Create widget? Or panel with scrollbar class...
        
            % Scrollbar is always created when panel 1 is visible
            panelNum = 1;

            visibleRatio = obj.visibleHeight/obj.virtualHeight(panelNum);

            barColor = min([1,1,1;obj.Theme.FigureBgColor+0.3]);
            
            % Add a homemade scrollbar
            hScrollerTmp = uim.widget.scrollerBar(obj.sidebar.hPanel, ...
                'Orientation', 'vertical', ...
                'Maximum', 1/visibleRatio*100, ...
                'VisibleAmount', 100, ...
                'BarColor', barColor);

            hScrollerTmp.Callback = @obj.scrollValueChange;
            obj.hScroller = hScrollerTmp;
            
            if visibleRatio > 1
                obj.hScroller.Visible = 'off';
            else
                obj.hScroller.show()
            end
                
            % Scroll to top, or align elements to top if all comps are
            % visible
            if obj.virtualHeight(panelNum) > obj.visibleHeight
                %obj.scrollToTop()
            else
                obj.moveElementsToTop()
            end

        end
        
        function updateScrollbar(obj, panelNum)
            
            visibleRatio = obj.visibleHeight/obj.virtualHeight(panelNum);
            obj.hScroller.Maximum = 1/visibleRatio*100;
            
            if obj.virtualHeight(panelNum) > obj.visibleHeight
                obj.hScroller.Visible = 'on';
                obj.lastScrollValue = 0;
                obj.moveElementsToTop()
            else
                obj.moveElementsToTop()
                obj.hScroller.Visible = 'off';
            end
            
            
        end
        
        function parseStruct(obj, S)
            
            if isstruct(S)
                subfields = fieldnames(S);
                isSubstruct = cellfun(@(name) isstruct(S.(name)), subfields);

                if all(isSubstruct)
                    obj.ConvertOutputToStruct = true;
                    names = fieldnames(S);
                    
                    S = struct2cell(S);
                    obj.Name = names;
                end
            end
            
            obj.dataOrig = S;
            obj.dataEdit = S;
            
            % Count number of structs in input.
            if isa(S, 'cell') && numel(S) > 1
                obj.numTabs = numel(S);
                obj.isTabCreated = false(1, obj.numTabs);
                % assert(~isempty(obj.Name), 'Name required for each struct')
                
                if numel(obj.Callback)==1
                    obj.Callback = arrayfun(@(i) obj.Callback, 1:obj.numTabs, 'uni', 0);
                end
                
                if numel(obj.ValueChangedFcn)==1
                    obj.ValueChangedFcn = arrayfun(@(i) obj.ValueChangedFcn, 1:obj.numTabs, 'uni', 0);
                end
                
            else % What a mess this turned into...
                obj.numTabs = 1;
                obj.dataOrig = {S};
                obj.dataEdit = {S};
                if ~isempty(obj.Name)
                    obj.Name = {obj.Name};
                end
                
                % Todo: Fix this: Should have to put them into cell here.
                if ~isempty(obj.Callback)
                    obj.Callback = {obj.Callback};
                end
                if ~isempty(obj.TestFunc)
                    obj.TestFunc = {obj.TestFunc};
                end
                if ~isempty(obj.ValueChangedFcn)
                    obj.ValueChangedFcn = {obj.ValueChangedFcn};
                end
            end
            
            if isempty(obj.Name)
                obj.Name = arrayfun(@(i) sprintf('Struct %d', i), 1:obj.numTabs, 'uni', 0);
            end
            
            obj.virtualHeight = nan(1, obj.numTabs);
            
        end
        
    end
    
    methods (Access = {?applify.ModularApp, ?applify.DashBoard} ) % Mouse/keyboard callbacks
           
        function onKeyPressed(obj, src, event)
            
            currentObject = gco;

            if isa(currentObject, 'matlab.ui.control.UIControl')
                if isequal(currentObject.Style, 'edit')
                    return
                end
            end

            if obj.isStandalone
                switch event.Key
                    case {'x', 'escape'}
                        obj.quit('Cancel')
                    case 's'
                        obj.quit('Save')
                end
            end
            
        end
        
        function onMouseMotion(obj, src, event)
        % Need for buttons in header... Highlight button & show tooltip
            
            h = hittest();

            if ~isequal(h, obj.currentObjectInFocus.handle)

                % Reset previous object
                if ~isa(obj.currentObjectInFocus.handle, 'matlab.graphics.GraphicsPlaceholder')
                    set(obj.currentObjectInFocus.handle, obj.currentObjectInFocus.props{:})
                    obj.currentObjectInFocus = struct('handle', gobjects(1), 'props', {{}});
                    obj.tooltipHandle.String = '';
                    obj.tooltipHandle.Visible = 'off';
                end
                
                if isa(h, 'matlab.graphics.primitive.Patch') && contains(h.Tag, 'Button')
                    h.FaceAlpha = 0.15;
                	obj.currentObjectInFocus = struct('handle', h, 'props', {{'FaceAlpha', 0}});
                    text = strrep(h.Tag, ' Button', '');
                    pos = get(obj.header.hAxes, 'CurrentPoint');
                    
                    pos = [mean(h.XData), mean(h.YData)];
                    
                    obj.tooltipHandle.Position(1:2) = pos - [0.05, 0.25];
                    obj.tooltipHandle.String = text;
                    obj.tooltipHandle.Visible = 'on';
                end
                
            end
            
        end
        
        function onMouseScrolled(obj, src, event)
            
            if obj.isMouseInApp()
                if strcmp(obj.hScroller.Visible, 'on')
                    obj.hScroller.moveScrollbar(src, event)
                end
            end
            
        end
        
    end
    
    methods (Access = protected)
        
        function onToggleSidePanelVisibilityButtonPressed(obj, src, evt)
            
            if src.Value
                obj.uiPanel.Tab.Visible = 'on';
            else
                obj.uiPanel.Tab.Visible = 'off';
            end
            
        end
        
    end
    
    methods % Gui update
    % % % % Methods for adding components on the main panel.
        
        function addComponents(obj, panelNum)

            obj.main.constructionCurtain.Visible = 'on';

            if obj.Debug
                obj.main.constructionCurtain.Visible = 'off';
            end
            
            X_POSITION = 20;
            
            if strcmp(obj.LabelPosition, 'Over')
                rowSpacing = obj.RowSpacing + obj.FontSize;
            elseif strcmp(obj.LabelPosition, 'Left')
                rowSpacing = obj.RowSpacing;
            end
            
            
            supportedClasses = {'logical', 'cell', 'double', 'char', ...
                'struct', 'uint16', 'single', 'uint8'};
            
            % Set some size preferences:
            contentPanel = obj.main.hAxes(panelNum);

            totHeight = contentPanel.Position(4); 
            
            % Initialize the yPosition for adding new components.
            y = obj.RowSpacing + 10;
            
            S = obj.dataOrig{panelNum};
            fieldNames = fieldnames(S);
            
            % Go through each property and make an inputfield for it. Each
            % editfield has a Tag which is the same as the propertyname. 
            % This is how to refer to them in other functions of the gui.
            for p = numel(fieldNames):-1:1
            
                currentProperty = fieldNames{p};
                
                % Check if current field is a configuration field
                if obj.isConfigField(currentProperty, fieldNames)
                    continue; 
                end
                
                % Check if current field has a configuration field
                configInd = obj.hasConfigField(currentProperty, fieldNames);
                if isempty(configInd)
                    config = [];
                else
                    config = S.(fieldNames{configInd});
                end
                
                if ischar(config) % skip "internal" properties
                    if any(strcmp(config, {'ignore', 'internal'}))
                        continue
                    end
                end
                
                propertyClass = class(S.(currentProperty));
            
                if ~contains(propertyClass, supportedClasses)
                    continue
                end
                
                switch propertyClass
                    
                    case 'struct'   % Make input for each field of struct property
                        % todo: clean this up...
                        propertyFields = fields(S.(currentProperty));

                        % Make a control for every subfield.
                        y = y + obj.RowSpacing;
                        yInit = y - obj.RowSpacing;

                        for i = 1:numel(propertyFields)
                            currentField = propertyFields{i};
                            name = strcat(currentProperty, '.', currentField);
                            val = eval(strcat('S', '.', name));
                            obj.newInputField(contentPanel, y, name, val, config)
                            y = y + obj.RowHeight + rowSpacing;
                        end

                        % Make a title text and a border around
                        % subfields.

                        textbox = text(contentPanel, X_POSITION, y, name);
                        textbox.String = utility.string.varname2label(currentProperty);
                        textbox.Tag = name;
                        textbox.Color = obj.Theme.FigureFgColor;
                        textbox.FontName = obj.FontName;
                        textbox.FontSize = obj.FontSize;
                        textbox.VerticalAlignment = 'middle';

                        edgeCoords = uim.shape.rectangle(round( [contentPanel.XLim(2)-20, y-yInit]), 5 );
                        edgeCoords = edgeCoords + [10, yInit];

                        extent = textbox.Extent + [-3,-3, 6, 6];

                        % Remove line under text.
                        rmv = edgeCoords(:,1) > extent(1) & ...
                            edgeCoords(:,1) < sum(extent([1,3])) & ...
                            edgeCoords(:,2) > extent(2) & ...
                            edgeCoords(:,2) < sum(extent([2,4]));

                        edgeCoords(rmv, :) = nan;

                        hRect = patch(contentPanel, edgeCoords(:,1),edgeCoords(:,2), ones(1,3)*0.2);
                        hRect.FaceAlpha = 0;
                        hRect.EdgeColor = obj.Theme.FigureFgColor*0.5;
                        y = y + obj.RowHeight;


                    otherwise
                        val = eval(strcat('S', '.', currentProperty));
                        obj.newInputField(contentPanel, y, currentProperty, val, config)
                        y = y + obj.RowHeight + rowSpacing;
                end
            end

            % Todo: Fix this so that objects in the axes also gets
            % flipped...
            %obj.flipUpsideDown(y, panelNum)
            
            % Adjust size of main panel so that it is large enough for all
            % controls.
            obj.virtualHeight(panelNum) = y;
            obj.resizeControlPanel(panelNum)
            
            obj.moveElementsToTop()

            obj.isTabCreated(panelNum) = true;
            
        end
        
        function tf = isConfigField(~, currentField, allFields)
        %isConfigField Check if field is a config field with a matching
        %non-config field...
        
            hasConfigFlag = strcmp(currentField(end), '_');
            hasNameMatch = contains(currentField(1:end-1), allFields);

            if hasConfigFlag && hasNameMatch
                tf = true;
            else
                tf = false;
            end
        end
        
        function ind = hasConfigField(~, currentField, allFields)
        %hasConfigField Check if field is a config field and return field ind
        
            ind = []; % Assign default value
        
            if contains(currentField, allFields)
                matchInd = find(contains(allFields, currentField));
                if iscolumn(matchInd); matchInd = matchInd'; end

                for i = matchInd
                    if strcmp(allFields{i}(end), '_') && ...
                            strcmp(currentField, allFields{i}(1:end-1))
                        ind = i;
                        break
                    end
                end
            end
        end
        
        % Note inputbox belongs to guiPanel
        function newInputField(obj, guiAxes, y, name, val, config)
        % Add input field for editing of property value
        %       y       : y position in panel
        %       name    : name of property. Used for text field and Tag
        %       val     : value f property. Assigned to input field.

            guiPanel = guiAxes.Parent;
            
            
            if strcmp(obj.LabelPosition, 'Over')
                xMargin = [18, 25]; % Old: 65
                x = xMargin(1);
                xSpacing = 7;
                yTxt = y + obj.RowHeight-5;
                textAlignment = 'left';
            
            elseif strcmp(obj.LabelPosition, 'Left')
                xMargin = [20, 50]; % Old: 65
                x = guiAxes.Position(3)/2-10;
                %x = guiAxes.Position(3) - 60;
                xSpacing = 15;
                yTxt = y;
                textAlignment = 'right';
            end
            
            height = round(obj.FontSize .* 1.8 + 1);
            ycorr = 0;
            xcorr = 0;
            hcorr = 0;
            
            % Create a textbox with the property name
            textbox = text(guiAxes, x, yTxt, name);
            textbox.String = [utility.string.varname2label(name), ':'];
            textbox.HorizontalAlignment = textAlignment;
            textbox.Tag = name;
            textbox.Color = obj.Theme.FigureFgColor;
            textbox.FontName = obj.FontName;
            textbox.FontSize = obj.FontSize;
            textbox.VerticalAlignment = 'bottom';
            
            buttonTypes = {'button', 'pushbutton', 'togglebutton'};
            if isa(config, 'struct') && any( strcmp(config.type, buttonTypes) )
                delete(textbox)
            end
            
            % Create input field for editing of propertyvalues

            if isempty(config) || isa(config, 'char') % Create control based on class of value
                
                switch class(val)
                    case 'logical'
                        inputbox = uicontrol(guiPanel, 'style', 'checkbox');
                        inputbox.Value = val;
                        ycorr = 3;
                        
                    case 'cell'
                        if all(ischar([ val{:} ]))
                            inputbox = uicontrol(guiPanel, 'style', 'edit');
                            inputbox.String = strjoin(val, ', ');
                        end

                    case 'char'
                        inputbox = uicontrol(guiPanel, 'style', 'edit');
                        inputbox.String = val;

                    case 'struct'
                        % Not implemented
                        % skip for now

                    case {'double', 'single', 'uint16', 'uint8'}
                        inputbox = uicontrol(guiPanel, 'style', 'edit');
                        
                        if numel(val) == 2 || numel(val) == 3
                            for i = 2:numel(val)
                                inputbox(i) = uicontrol(guiPanel, 'style', 'edit');
                            end
                            
                            for iValue = 1:numel(val)
                                inputbox(iValue).String = num2str(val(iValue));
                            end
                            
                        else
                            
                           strArray = num2str(val);

                            if size(strArray, 1) > 1
                                strArray = arrayfun(@(i) strArray(i,:), 1:size(strArray, 1), 'uni', 0);
                                strArray = strjoin(strArray, ';       ');
                            end
                            
                            inputbox.String = strArray;

                        end
                        

                    otherwise
                        % skip for now
                end
                
            else % Create control based on configuration of value
                if isa(config, 'cell')
                    inputbox = uicontrol(guiPanel, 'style', 'popupmenu');
                    inputbox.String = config;
                    if ischar(val)
                        inputbox.Value = find(strcmp(config, val));
                    elseif isnumeric(val)
                        inputbox.Value = find(ismember(cell2mat(config), val));
                    end
                    
                elseif isa(config, 'struct')
                    switch config.type
                        case 'slider'
                            inputbox = uim.widget.slidebar('Parent', guiAxes, ...
                                'Units', 'pixel', config.args{:}, 'Value', val, ...
                                'TextColor', obj.Theme.FigureFgColor, 'Padding', [0,9,3,9]);
                            ycorr = -3;
                            % padding is 3pix assymmetric... i think
                            % because of the way other uicontrols are positioned.
% %                             
% %                         case 'rangeslider'
% %                             inputbox = uim.widget.rangeslider(guiAxes, ...
% %                                 'Units', 'pixel', config.args{:}, 'Low', val(1), 'High', val(2), ...
% %                                 'TextColor', obj.Theme.FigureFgColor, 'Padding', [0,9,3,9]);
% %                             ycorr = -3;
                            
                        case 'button'
                            inputbox = uicontrol(guiPanel, 'style', 'pushbutton', ...
                                config.args{:} );
                            
% % %                             inputbox = uim.control.Button_(guiPanel, ...
% % %                                 'mode', 'pushbutton', config.args{:}, ...
% % %                                 'HorizontalTextAlignment', 'center');
                            if strcmp(obj.LabelPosition, 'Over')
                                ycorr = obj.RowSpacing;
                            end
                            xcorr = -3;
                            
                        case 'togglebutton'
                            inputbox = uicontrol(guiPanel, 'style', 'togglebutton', ...
                                config.args{:} );
                            ycorr = obj.RowSpacing;
                            xcorr = -3;
                             
                    end
                end
            end
            
            
            % Configure properties/appearance of uicontrol
            pos = [x+xSpacing+xcorr, y+ycorr, guiAxes.XLim(2) - x - xMargin(2) - xSpacing, height+hcorr];
            
            if numel(inputbox) == 1
                inputbox.Position = pos;
            else
                pos = obj.subdividePosition(pos, numel(inputbox));
                pos = mat2cell(pos, ones(1, numel(inputbox)));
                set(inputbox, {'Position'}, pos)
            end
            
            if isa(inputbox, 'matlab.ui.control.UIControl')
                
                if numel(inputbox) > 1
                    set(inputbox, ...
                    'ForegroundColor', obj.Theme.FigureFgColor*0.8, ...
                    'HorizontalAlignment', 'left', ...
                    'FontName', obj.FontName, ...
                    'FontSize', obj.FontSize, ...
                    'Tag', name, ...
                    'Callback', @obj.editCallback_propertyValueChange, ...
                    {'UserData'}, transpose( arrayfun(@(i) struct('ControlIdx', i), 1:numel(inputbox), 'uni', 0) ) )

                else
                    inputbox.ForegroundColor = obj.Theme.FigureFgColor*0.8;
                    inputbox.HorizontalAlignment = 'left';
                    inputbox.FontName = obj.FontName;
                    inputbox.FontSize = obj.FontSize;
                    %inputbox.HitTest = 'off';
                    %inputbox.HandleVisibility = 'off';
                    inputbox.Tag = name;
                    inputbox.Callback = @obj.editCallback_propertyValueChange;
                end
                
            else
            	inputbox.FontSize = obj.FontSize-2;
                inputbox.Tag = name;
                inputbox.Callback = @obj.editCallback_propertyValueChange;

            end
            
            
            % Add control to a struct of controls using same fieldnames as
            % for the data structs: % Todo: Add name for multipages...
            structSubs = obj.getSubfieldSubs(name);
            obj.hControls = subsasgn(obj.hControls, structSubs, inputbox);
            
            
            % If config is a char, then we should create a button next to
            % the input field.
            if ~isempty(config) && isa(config, 'char')
                
                inputbox.Position(3) = inputbox.Position(3);
                xPos = sum(inputbox.Position([1,3]) + 6 );
                
                hButton = uicontrol(guiPanel, 'style', 'pushbutton');
                hButton.String = '...';
                hButton.Units = 'pixel';
                hButton.ForegroundColor = inputbox.ForegroundColor;
                
                if strcmp(obj.mode, 'standalone')
                    hButton.Position = [xPos, y+1, 22,  22]; %Slightly smaller..
                elseif strcmp(obj.mode, 'docked')
                    sz = inputbox.Position(4);
                    xPos = sum(inputbox.Position([1,3]))+2;
                    hButton.Position = [xPos, y, sz, sz]; %Slightly smaller..
                end
                hButton.Callback = {@obj.onButtonPressed, config};
                hButton.ButtonDownFcn = {@obj.onButtonPressed, config};

                hButton.Tag = name;
                inputbox.TooltipString = inputbox.String;

            elseif contains(lower(name), {'path', 'drive', 'dir'})  && isa(val, 'char') % Todo: remove this and use the uigetdir or uigetfile flags instead!!
                
                if ~isempty(config); return; end %NB: This is a quickfix related to the todo above
                
                inputbox.Position(3) = inputbox.Position(3);
                xPos = sum(inputbox.Position([1,3]) + 6 );
                
                hButton = uicontrol(guiPanel, 'style', 'pushbutton');
                hButton.String = '...';
                hButton.Units = 'pixel';
                hButton.ForegroundColor = inputbox.ForegroundColor;
                hButton.Position = [xPos, y+1, 22,  22]; %Slightly smaller..
                hButton.Callback = @obj.buttonCallback_openBrowser;
                hButton.Tag = name;
                hButton.ButtonDownFcn = @obj.buttonCallback_openBrowser;
                inputbox.TooltipString = inputbox.String;
            end
            
        end
        
        function pos = subdividePosition(obj, pos, numSubdivision)
            
            sizeSpecs = ones(1, numSubdivision) ./ numSubdivision;
            spacing = obj.ColSpacing;
            
            x0 = pos(1);
            l0 = pos(3);
            [x, l] = uim.utility.layout.subdividePosition(x0, l0, sizeSpecs, spacing);
            
            pos = repmat(pos, numSubdivision, 1);
            pos(:,1) = x;
            pos(:,3) = l;
            
        end

        
        function setControlValue(obj, hControl, value)
            
            if isa(hControl, 'matlab.ui.control.UIControl')

                switch class(value)
                    case 'logical'
                        hControl.Value = value;
                        drawnow
                        
                    case 'cell'
                        if all(ischar([ value{:} ]))
                            hControl.String = strjoin(value, ', ');
                        end

                    case 'char'
                        if strcmp(hControl.Style, 'popupmenu')
                            value = find(contains(hControl.String, value));
                            hControl.Value = value;
                        else
                            hControl.String = value;
                        end
                        
                    case 'struct'
                        % Not implemented
                        % skip for now

                    case {'double', 'single', 'uint16', 'uint8'}
                        
                        % Special case where value is a vector and each
                        % value has its own inputbox
                        if numel(hControl) > 1
                            for i = 1:numel(value)
                                hControl(i).String = num2str(value(i));
                            end
                        else
                            strArray = num2str(value);

                            if size(strArray, 1) > 1
                                strArray = arrayfun(@(i) strArray(i,:), 1:size(strArray, 1), 'uni', 0);
                                strArray = strjoin(strArray, ';       ');
                            end

                            hControl.String = strArray;
                        end
                        
                    otherwise
                        % skip for now
                end
            
                
            elseif isa(hControl, 'uim.widget.slidebar') % todo.
                hControl.Value = value;
            end
            
        end

        function styleControls(obj, panelNum)
        %styleControls Style ui controls
        
            if obj.isStandalone
                set(obj.Figure, 'Visible', 'on')
            end
            
            if isa(panelNum, 'matlab.graphics.container.Panel')
                hPanel = panelNum;
            else
                hPanel = obj.main.hPanel(panelNum);
            end
            
% %             % Find handles of all uicontrols.
% %             fieldNamesPage = fieldnames(obj.dataOrig{panelNum});
% %             fieldNamesControls = fieldnames(obj.hControls);
% %             
% %             keep = ismember(fieldNamesControls, fieldNamesPage);
            
            hUic = findobj(hPanel, 'type','uicontrol'); 
            
% %             hUic = struct2cell( obj.hControls );
% %             hUic = hUic(keep);
% %             
% %             isUic = cellfun(@(c) isa(c, 'matlab.ui.control.UIControl'), hUic);
% %             hUic = [hUic{isUic}];
            
            % Make them look good.
            if ~isempty(hUic)
                h = applify.uicontrolSchemer(hUic);
                el = addlistener(obj, 'ObjectBeingDestroyed', @(src,evt) delete(h));
                
            end
            %drawnow
            
        end
        
        function showFigure(obj)
            
            if isfield(obj.main, 'tmpPanel')
                delete(obj.main.tmpPanel)
            end
            
            obj.Figure.Visible = 'on';
            
        end
        
        function scrollToTop(obj)
        %scrollToTop Scroll panel to the top. 
            
            % (Mis)Use the scroll callback to move the elements so that the first is on
            % the top of the panel. This is a fix for starting the positioning
            % of elements from the bottom, potentially leaving the first 
            % (topmost) elements outside of the panel.
            
            i = obj.currentPanel;
            
            obj.lastScrollValue = 0;
            newScrollValue = 100-obj.virtualHeight(i)/obj.visibleHeight*100;
            
            obj.scrollValueChange(struct('Value', newScrollValue), [])
            obj.lastScrollValue = 0;
            
        end
        
        function moveElementsToTop(obj)
        %moveElementsToTop Move elements of a panel to the top.   
            i = obj.currentPanel;
            
            if isnan(obj.virtualHeight(i)); return; end
            
            difference = obj.visibleHeight - obj.virtualHeight(i);
            
            pixelPos = getpixelposition( obj.main.hPanel(i) );
            
            if obj.showFooter
                y0 = 45;
            else
                y0 = 0;
            end
            
            pixelPos(2) = y0 + difference;
            setpixelposition( obj.main.hPanel(i), pixelPos);
            
            obj.lastScrollValue = 0;
            %obj.hScroller.Value = 0;
            
            return
            
            %TODO: Remove this..
            % Move elements to top:
            difference = obj.main.hAxes(i).YLim(2) - obj.virtualHeight(i);
            obj.main.hAxes(i).YLim = obj.main.hAxes(i).YLim - difference;

            uic = findobj(obj.main.hPanel(i), 'Type', 'UIControl');
            for i = 1:numel(uic)
                uic(i).Position(2) = uic(i).Position(2) + difference;
            end
            
        end
        
        function flipUpsideDown(obj, y, panelNum)
            
            uic = findobj(obj.main.hPanel(panelNum), 'Type', 'UIControl');
            for i = 1:numel(uic)
                uic(i).Position(2) = abs( uic(i).Position(2) - y + obj.RowHeight );
            end
        end
        
        function editCallback_propertyValueChange(obj, src, ~, isInternal)
        % Callback for value change in inputfields. Update session property
        %
        %   Updates the value of the property corresponding to inputfield.
            
            % todo: split into several functions so the below is not
            % necessary (isInternal).
        
            if nargin < 4
                % Flag used if changing preset selection
                isInternal = false;
            end
        
            name = src.Tag;

            switch src(1).Style
                case 'edit'
                    val = src.String;
                case 'checkbox'
                    val = src.Value;
                case 'popupmenu'
                    val = src.String{src.Value};
                case 'slidebar'
                    val = src.Value;
                case 'pushbutton'
                    val = ~obj.dataEdit{obj.currentPanel}.(name); % Need to trigger button every time...
                    isInternal = true; % Quick fix...Dont change to custom if button is pushed!
                case 'togglebutton'
                    val = src.Value;
                    isInternal = true; % Quick fix...Dont change to custom if button is pushed!
                    
            end
            

            
            % Convert value to a string for the eval function later.
            switch class(eval(['obj.dataEdit{obj.currentPanel}.', name]))
                case {'double', 'single', 'uint16', 'uint8'}
                    if isempty(val)
                        val = '[]';
                    else
                        val = strcat('[', num2str(val), ']');
                    end

                case 'logical'
                    if val
                        val = 'true';
                    else
                        val = 'false';
                    end

                case 'cell'
                    val = strcat('{', '''', val, '''', '}');

                case 'char'
                    val = ['''' val ''''];

                case 'struct'
                 	%Not implemented
            end

            % Check if new value is different than old, and update if so
            % Using eval function here because input from controls are in
            % char/string format.
            
            newVal = eval(val);
            oldVal = eval(['obj.dataEdit{obj.currentPanel}.', name]);
            
            
            % Adaptation to special case where edit control is split into
            % multiple controls (info about this was added to userdata)
            if isprop(src, 'UserData') && ~isempty(src.UserData)
                idx = src.UserData.ControlIdx;
                
                tmpVal = oldVal;
                tmpVal(idx) = newVal;
                newVal = tmpVal;
            end
            

            if isequal(newVal, oldVal) % Todo: Rounding errors....
                return
            else
                
                % Need eval function to assign fields in properties that are
                % structs. Do I need this anymore? % Todo: replace with
                % subsasgn
                ind = obj.currentPanel;
                subs = obj.getSubfieldSubs(name);
                
                % Add the new value to the data struct
                obj.dataEdit{ind} = subsasgn(obj.dataEdit{ind}, subs, newVal);


                %eval(['obj.dataEdit{obj.currentPanel}.', name, ' = ', val , ';'])
                
                if ~isempty(obj.Callback) && ~isempty( obj.Callback{obj.currentPanel} )
                    obj.Callback{obj.currentPanel}(name, newVal)
                end
                
                if ~isempty(obj.TestFunc)
                    obj.TestFunc{obj.currentPanel}(obj.dataEdit{obj.currentPanel})
                end
                
                if ~isempty(obj.ValueChangedFcn) && ~isempty(obj.ValueChangedFcn{obj.currentPanel})
                    evd = structeditor.eventdata.ValueChanged(name, oldVal, newVal, obj.hControls);
                    obj.ValueChangedFcn{obj.currentPanel}(obj, evd)
                end
                
                if ~isInternal && ~isempty(obj.OptionsManager)
                    obj.changePresetToModified()
                end
            end

        end
        
        function onButtonPressed(obj, src, ~, action)
        % Button callback for browse button. Used to change path

            guiFig = obj.Figure;
            propertyName = src.Tag;
            
            iPanel = obj.currentPanel;
            
            switch action
                
                case {'uigetdir', 'uigetfile', 'uiputfile'}
                    
                    oldPathString = obj.dataOrig{iPanel}.(propertyName);

                    % Todo: Does this work on windows???
                    if isempty(oldPathString)
                        initPath = '/';
                    else
                        [initPath, ~, ~] = fileparts(oldPathString);
                    end

                    if strcmp(action, 'uigetfile')
                        [fileName, folderPath, ~] = uigetfile({'*', 'All Files (*.*)'}, '', initPath);
                        pathString = fullfile(folderPath, fileName);
                    elseif strcmp(action, 'uiputfile')
                        [fileName, folderPath, ~] = uiputfile({'*', 'All Files (*.*)'}, '', initPath);
                        pathString = fullfile(folderPath, fileName);
                    elseif strcmp(action, 'uigetdir')
                        pathString = uigetdir(initPath);
                    end

                    if isequal(fileName, 0) || isequal(pathString, 0)
                        return
                    else
                        if isequal(oldPathString, pathString)
                            return
                        else
                            
                            inputfield = findobj(guiFig, 'Tag', propertyName, 'Style', 'edit');
                            inputfield.String = pathString;
                            inputfield.TooltipString = inputfield.String;
                            
                            obj.editCallback_propertyValueChange(inputfield)
                            
                            %obj.dataEdit{iPanel}.(propertyName) = pathString;

                        end
                    end
                    
                case 'uisetcolor' % Use uisetcolor dialog to pick a color.
                    origRGB = obj.dataEdit{iPanel}.(propertyName);                    
                    newRGB = uisetcolor(origRGB);
                                        
                    if isequal(newRGB, 0)
                        return
                    end
                    
                    if isequal(origRGB, newRGB)
                        return
                    else
                        obj.dataEdit{iPanel}.(propertyName) = newRGB;
                        inputfield = findobj(guiFig, 'Tag', propertyName, 'Style', 'edit');
                        inputfield.String = num2str(newRGB, '%.2f  %.2f  %.2f');
                        inputfield.TooltipString = inputfield.String;
                    end
                    
            end

        end
        
        function buttonCallback_openBrowser(obj, src, ~)
        % Button callback for browse button. Used to change path

            guiFig = obj.Figure;
            
            propertyName = src.Tag;
            
            oldPathString = obj.dataOrig{obj.currentPanel}.(propertyName);

            if isempty(oldPathString)
                initPath = '/';
            else
                [initPath, ~, ~] = fileparts(oldPathString);
            end

            if contains(lower(src.Tag), {'file'})
                [fileName, folderPath, ~] = uigetfile({'*', 'All Files (*.*)'}, '', initPath);
                pathString = fullfile(folderPath, fileName);
            elseif contains(lower(src.Tag), {'path', 'drive', 'dir'})
                pathString = uigetdir(initPath);
            end

            if ~pathString
                return
            else
                if isequal(oldPathString, pathString)
                    return
                else
                    
                    %obj.dataEdit{obj.currentPanel}.(propertyName) = pathString;
                    inputfield = findobj(guiFig, 'Tag', propertyName, 'Style', 'edit');
                    inputfield.String = pathString;
                    inputfield.TooltipString = inputfield.String;
                    obj.editCallback_propertyValueChange(inputfield)
                end
            end

        end
        
        
% % % % Methods for presets (Todo: make into separate class)
        
        function setPresetDropdownValueToName(obj, newName)
            
            hDropDown = obj.presetDropdown;
            
            if any( strcmp(newName, hDropDown.String) )
                hDropDown.Value = find( strcmp(newName, hDropDown.String) );
            else
                hDropDown.String = cat(1, hDropDown.String, {newName} );
                hDropDown.Value = numel(hDropDown.String);
            end
            
            obj.currentPresetName = newName;
            
        end

        function onPresetChanged(obj, src, evt)
            
            % Todo: Skip if current name is chosen...
            
            oldName = obj.currentPresetName;
            newName = obj.getCurrentPresetSelection(src);
            
            if strcmp(oldName, newName); return; end
            
            if contains(oldName, 'Modified')
                
                % Todo: turn this into a method.
                if numel(obj.dataEdit) > 1
                    opts = cell2struct(obj.dataEdit, obj.Name);
                else
                    opts = obj.dataEdit{1};
                end
                
                obj.OptionsManager.storeModifiedOptions(opts, oldName)
            end
            
            
            newOpts = obj.OptionsManager.getOptions(newName);
            
% % %             % Todo: turn this into a method.
% % %             if numel(obj.dataEdit) > 1
% % %                 newOpts = struct2cell(newOpts);
% % %             else
% % %                 newOpts = {newOpts};
% % %             end
            
            obj.updateFromPreset(newOpts)
            %obj.refreshPresetDropdown(src)
            
            obj.currentPresetName = newName;
        end
        
        function updateFromPreset(obj, newOpts)
                 
            % If original data was a struct of structs, need to convert 
            % input to cell before continuing
            if obj.ConvertOutputToStruct
                newOpts = struct2cell(newOpts);
            end
            
            numPages = numel(obj.dataEdit);
            
            getOldValue = @(fieldname) strjoin({'obj.dataEdit{i}', fieldname}, '.');  
            getNewValue = @(fieldname) strjoin({'newOpts{i}', fieldname}, '.');
            
            % Todo: Find better way?
            currentPanelOrig = obj.currentPanel;
            
            for i = 1:numPages
                
                sTmp = obj.dataEdit{i};
                % names = fieldnamesr(sTmp);
                
                % Get fieldnames recursively and find intersection
                fieldsOptions = fieldnamesr(sTmp);
                fieldsControls = fieldnamesr(obj.hControls);
            
                names = intersect(fieldsOptions, fieldsControls);
                
% %                 if isempty(newOpts{i})
% %                     obj.disablePage(i)
% %                     continue
% %                 else
% %                     if obj.isPageDisabled(i)
% %                         obj.enablePage(i)
% %                     end
% %                 end
                
                obj.currentPanel = i;
                
                
                for j = 1:numel(names)
                    %hControl = findobj(guiFig, 'Tag', names{j}, 'Type', 'uicontrol');
                    
                    s = struct('type', {'.'}, 'subs', strsplit(names{j}, '.'));
                    hControl = subsref(obj.hControls, s);
                    
                    
                    % TODO: Use old value if new value is not present. Ie
                    % if original options have been updated at some point
                    
                    oldVal = eval( getOldValue(names{j}) );
                    newVal = eval( getNewValue(names{j}) );
                    if ~isequal(oldVal, newVal)
                        obj.setControlValue(hControl, newVal);
                        if numel(hControl)>1
                            hControl = hControl( ~ismember(oldVal, newVal) );
                        end

                        obj.editCallback_propertyValueChange(hControl, [], true)
                    end
                        
                
                end
                
            end
            
            % Reset current panel prop
            obj.currentPanel = currentPanelOrig;
            
        end
        
        function setPresetSelection(obj, newName)
            
            hDropdown = obj.presetDropdown;
            
            % Todo: Need to test this properly???
            
            optionNames = obj.OptionsManager.listAllOptionNames();
            
            isMatch = strcmp( optionNames, newName );
            
            matchedInd = find(isMatch);
            
            %matchedName = hDropdown.String{matchedInd(1)};
            
            hDropdown.Value = matchedInd;
            
        end
        
        function name = getCurrentPresetSelection(obj, hDropdown)
            
            if nargin < 2
                hDropdown = obj.presetDropdown;
            end
            
            name = hDropdown.String{hDropdown.Value};
            
            name = strrep(name, '[', '');
            name = strrep(name, ']', '');
        end
        
        function savePreset(obj, hDropdown)
            
            % Get current options
            opts = obj.dataEdit;
            
            % Todo: make method:
            if isa(opts, 'cell') && numel(opts) > 1
                opts = cell2struct(opts, obj.Name);
            else
                opts = opts{1};
            end

            currentName = obj.getCurrentPresetSelection;
            
            % Todo: get info about whether preset was saved and which name
            givenName = obj.OptionsManager.saveCustomOptions(opts);
            
            % Update list of presets.
            if ~isempty(givenName)
                
                % If current preset is modified, update name
                if contains(currentName, 'Modified')
                    currentInd = obj.presetDropdown.Value;
                    
                    %names = obj.presetDropdown.String;
                    %names{currentInd} = givenName;
                    %obj.presetDropdown.String = names;
                    
                    obj.presetDropdown.String{currentInd} = givenName;
                    %obj.presetDropdown.Value = currentInd;
                    obj.OptionsManager.removeModifiedOptions(currentName)
                    
                % Else, make a new entry in the list
                else
                    %names = cat(1, obj.presetDropdown.String, {givenName} ];
                    obj.presetDropdown.String{end+1} = givenName;
                    obj.presetDropdown.Value = numel(obj.presetDropdown.String);
                end
            end

            
            %obj.refreshPresetDropdown(hDropdown)

        end
        
        function makePresetDefault(obj, hDropdown)
        %makePresetDefault Make current preset the default  
            name = obj.getCurrentPresetSelection(hDropdown);
            obj.OptionsManager.setDefault(name);
        end
        
        function refreshPresetDropdown(obj, hDropdown)
        %makePresetDefault Make current preset the default  
            
            presetNames = obj.OptionsManager.PresetOptionNames;
            presetNames = cellfun(@(name) sprintf('[%s]',name), presetNames, 'uni', 0);
            customNames = obj.OptionsManager.CustomOptionNames;
            
            names = [presetNames, customNames];
            
            if isempty(names)
                names = {'Original'}; %?
            end
            
            hDropdown.String = names;
            
            % Todo: Make sure value stays the same (points to same item)
            
        end
        
        function changePresetToModified(obj)
            
            % Question: Is there anything else here that must be done?
            hDropDown = obj.presetDropdown;
            name = obj.getCurrentPresetSelection(hDropDown);
            
            if contains(name, 'Modified')
                return
            else
                newName = sprintf('%s (Modified)', name);
                obj.setPresetDropdownValueToName(newName)
            end
            
            %todo: add hDropDown as property. 
            obj.currentPresetName = newName;
        end
        

        
% % % % User interaction callbacks


        function onDropdownSelected(obj, src, evt)
            obj.changeTab(src.Value)
        end
    
        function onTabButtonPressed(obj, src, evt, pageNum)
            
            % Make sure all other buttons than current is off
            for iBtn = 1:numel(obj.TabButtonGroup.Buttons)
                      
                if ~isequal(src, obj.TabButtonGroup.Buttons(iBtn))
                    obj.TabButtonGroup.Buttons(iBtn).Value = 0;
                end
                   
            end

            % Make sure current button is on (and change page if it was turned on)
            if src.Value
                % If click turns button on, change page!
                obj.changeTab(pageNum)
            else
                % If click turns button off, turn it back on!
                src.Value = true;
            end 
            
            if obj.showSidePanel && contains(obj.TabMode, 'popup')
                obj.sidePanelToggleButton.Value = 0;
                %set this to current object before turning off panel
                %visibility, to control who is next current object
                uicontrol(obj.headerSubtitle)

                obj.onToggleSidePanelVisibilityButtonPressed(obj.sidePanelToggleButton)

            end


        end
        
        function changeTab(obj, panelNum)

            % Make sure all other tabs are not visible.
            set(obj.main.hPanel, 'Visible', 'off')
            obj.main.hPanel(panelNum).Visible = 'on';
            obj.currentPanel = panelNum;
            
% %             if obj.isPageDisabled(panelNum)
% %                 obj.main.disablePanel.Visible = 'on';
% %             else
% %                 obj.main.disablePanel.Visible = 'off';
% %             end
                

            
            obj.updateHeaderTitle()
            
            if obj.showSidePanel && contains(obj.TabMode, 'popup')
                obj.headerSubtitle.String = obj.Name{panelNum};
            end
            
            % Create panel if it is opened for the first time.
            if ~obj.isTabCreated(panelNum)
                applify.AppWindow.switchJavaWarnings('off')

                 % Create components
                obj.addComponents(panelNum)

                if exist('applify.uicontrolSchemer', 'class')==8
                    obj.styleControls(panelNum)
                end
                
                % Scroll to top, or align elements to top if all comps are
                % visible
                if obj.virtualHeight(panelNum) > obj.visibleHeight
                    obj.moveElementsToTop()
                end
                
                obj.main.constructionCurtain.Visible = 'off';
                
                applify.AppWindow.switchJavaWarnings('on')
            end
            

            % Update scrollbar.
            obj.updateScrollbar(panelNum)

        end
        

        function disablePage(obj, panelNum)
            obj.main.hPanel(panelNum).Enable = 'off';
            if obj.currentPanel == panelNum
                obj.main.disablePanel.Visible = 'on';
            end
        end
        
        function enablePage(obj, panelNum)
            obj.main.hPanel(panelNum).Enable = 'on';
            if obj.currentPanel == panelNum
                obj.main.disablePanel.Visible = 'off';
            end
        end
        
        function tf = isPageDisabled(obj, panelNum)
            tf = strcmp( obj.main.hPanel(panelNum).Enable, 'off' );
        end

        
% % % % Functions for moving window (if figure is undecorated)

        function startMoveWindow(obj, ~, ~)
            startMovePos = get(obj.Figure, 'CurrentPoint');
            
            if isempty(obj.hJFrame)
                initFigPos = obj.Figure.Position(1:2);
            else
                initFigPos = obj.hJFrame.getLocation;
                initFigPos = [initFigPos.x, initFigPos.y];
            end
            
            obj.figureCallbackStore.WindowButtonMotionFcn = obj.Figure.WindowButtonMotionFcn;
            obj.figureCallbackStore.WindowButtonUpFcn = obj.Figure.WindowButtonUpFcn;

            obj.Figure.WindowButtonMotionFcn = {@obj.moveWindow, startMovePos, initFigPos};
            obj.Figure.WindowButtonUpFcn = @obj.stopMoveWindow;
        end
        
        function moveWindow(obj, ~, ~, startMovePos, initFigPos)
            
            mousePoint = get(obj.Figure, 'CurrentPoint');
            shift = mousePoint - startMovePos;
            
            if isempty(obj.hJFrame)
%                 obj.Figure.Position(1:2) = initFigPos + shift;
%                   bug here...
            else
                newPos = initFigPos + shift.*[1,-1];
                obj.hJFrame.setLocation(java.awt.Point(newPos(1), newPos(2)));
            end
            
        end
        
        function stopMoveWindow(obj, ~, ~)
            obj.Figure.WindowButtonMotionFcn = obj.figureCallbackStore.WindowButtonMotionFcn;
            obj.Figure.WindowButtonUpFcn = obj.figureCallbackStore.WindowButtonUpFcn;
        end
        
        
% % % % Other callbacks

        function scrollValueChange(obj, scroller, ~)        
        % Callback for value change on scroller belonging to panel. Scrolls up or down.

            panelNum = obj.currentPanel;
        
            % Get the fraction which the scrollbar has moved
            fractionMoved = (scroller.Value - obj.lastScrollValue) / 100;
            obj.lastScrollValue = scroller.Value;

            % Get textsfields of panel
            hUicTmp = findobj(obj.main.hPanel(panelNum), 'Type', 'UIControl');

            % Calculate the shift of components in pixels
            pixelShiftY = fractionMoved * obj.visibleHeight;
            
            pixelpos = getpixelposition( obj.main.hPanel(panelNum) );
            pixelpos(2) = pixelpos(2) + pixelShiftY;
            setpixelposition( obj.main.hPanel(panelNum), pixelpos );
            
            return
            
            % Move all fields up or down in panel.
            for i = 1:length(hUicTmp)
                fieldPos = get(hUicTmp(i), 'Position');
                fieldPos(2) = fieldPos(2) + pixelShiftY;
                set(hUicTmp(i), 'Position', fieldPos)
            end
            
            obj.main.hAxes(panelNum).YLim = obj.main.hAxes(panelNum).YLim - pixelShiftY;

        end
        
        function waitfor(obj)                               
            uiwait(obj.Figure)
        end
        
        function quit(obj, action)
    
            switch action

                case 'Cancel'
                    obj.wasCanceled = true;
                case 'Save'
                    obj.wasCanceled = false;
            end
            
            % make sure output is not a cell if only 1 panel...
            if obj.numTabs == 1
                obj.dataOrig = obj.dataOrig{1};
                obj.dataEdit = obj.dataEdit{1};
            end
            
            if obj.ConvertOutputToStruct
                obj.dataOrig = cell2struct(obj.dataOrig, obj.Name);
                obj.dataEdit = cell2struct(obj.dataEdit, obj.Name);
            end
            
            uiresume(obj.Figure)
           
            if strcmp(obj.mode, 'standalone')
                delete(obj.Figure)  % Close figure
            else
                delete(obj.Panel)
            end
            drawnow
            
            obj.notify('AppDestroyed', event.EventData)

        end
        
    end

    methods (Static)
        
        
        function subs = getSubfieldSubs(subfieldName)
            subfields = strsplit(subfieldName, '.');
            subs = struct('type', {'.'}, 'subs', subfields);
        end
        
        function pathStr = getIconPath()
            % Set system dependent absolute path for icons.

            rootDir = utility.path.getAncestorDir(mfilename('fullpath'), 0);
            pathStr = fullfile(rootDir, 'resources', 'icons');

        end
        
        
    end

    
end




% % % % OLDER CODE:
% % 
% % function parseNvPairs(obj, varargin)
% %     if any(contains(varargin(1:2:end), 'Callback'))
% %         ind = find(contains(varargin(1:2:end), 'Callback'));
% %         obj.Callback = varargin{ind*2};
% %     end
% % 
% %     if any(contains(varargin(1:2:end), 'Testfunc'))
% %         ind = find(contains(varargin(1:2:end), 'Testfunc'));
% %         obj.TestFunc = varargin{ind*2};
% %     end
% % 
% %     if any(contains(varargin(1:2:end), 'Name'))
% %         ind = find(contains(varargin(1:2:end), 'Name'));
% %         obj.Name = varargin{ind*2};
% %     end
% % 
% %     if any(contains(varargin(1:2:end), 'OptionsManager'))
% %         ind = find(contains(varargin(1:2:end), 'OptionsManager'));
% %         obj.OptionsManager = varargin{ind*2};
% %         obj.showFooter = true;
% %     end
% % 
% %     if any(contains(varargin(1:2:end), 'PresetSelection'))
% %         ind = find(contains(varargin(1:2:end), 'PresetSelection'));
% %         obj.PresetSelection = varargin{ind*2};
% %     end
% % end 