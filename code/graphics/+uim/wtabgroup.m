classdef wtabgroup < uim.abstract.virtualContainer & uim.mixin.assignProperties
%tabgroup Mimick Matlab's tabgroup container class.
%
%   This tabgroup container has more flexibility in design, but is slower
%   to update when being resized because the code is using axes and
%   graphical objects for the components.

    properties 
        TabLocation = 'top' % Not priority.
        SelectedTab = []
        SelectionChangedFcn = []
    end
    
    
    properties (Access = private, Hidden, Transient)
        % BackgroundDecoration
        TabToolBar
        
        TabButtonGroup uim.control.Button
        TabSeparators uim.control.toolbarSeparator
        TabPanels uim.panel
    end
    
    properties
        
    end
    
    events
        SelectionChanged
    end
    
    
    methods %structor
        
        function obj = wtabgroup(hParent, varargin)
            
            % Create listener for when parent size changes.
            el = listener(hParent, 'SizeChanged', ...
                @obj.onParentContainerSizeChanged);
            obj.ParentContainerSizeChangedListener = el;
            
            obj.Parent = hParent;
            
            obj.assignComponentCanvas()
            %obj@uim.abstract.WidgetContainer(hParent, varargin{:})

            obj.parseInputs(varargin{:})

            obj.createBackground()
            
            obj.IsConstructed = true;

            % Call adjustSize to trigger size update (call before location)
            obj.adjustSize('auto')
            
            % Call updateLocation to trigger location update
            obj.updateLocation('auto')
            
            obj.onStyleChanged()
            
            obj.createComponents()
            
            
        end
        
    end
    
    
    methods (Access = private) % Component creation
        
        function createComponents(obj)
            
            % Create background
            
            % Create toolbar / tabbar
            obj.createTabButtonBar()

            
        end
        
        function createTabButtonBar(obj)
        %createTabButtonBar Create bar with tab button group
        
            % Set toolbarheight and calculate margins based on tabgroup
            % container margins.
            toolbarHeight = 20;
            buttonGroupBackgroundColor = [71,73,75]./255;
            
            toolbarMargin = obj.Margin - [0,0,0,toolbarHeight/2];
            
            uicc = getappdata(obj.Parent, 'UIComponentCanvas');
            
            hToolbar = uim.widget.wtoolbar(obj.Parent, ...
                'CanvasMode', 'separate', ...
                'Size', [inf, toolbarHeight], ...
                'Margin', toolbarMargin, ...
                'Padding', [1, 1, 1, 1], ...
                'Spacing', 1, ...
                'ComponentAlignment', 'left', ...
                'BackgroundColor', buttonGroupBackgroundColor, ...
                'BackgroundAlpha', 0.5, ...
                'NewButtonSize', [100, 18]);

            hToolbar.Location = 'northeast';
            hToolbar.ComponentAlignment = 'center';
            hToolbar.CornerRadius = 4;
            
            uistack(hToolbar.Canvas, 'top')
            obj.TabToolBar = hToolbar;
            
        end
        
        function createTabButton(obj, hTab)
        %createTabButton Create new tab button for given tab
        
            buttonOptions = {'FontName', 'Lucida Grande', ...
                'Type', 'togglebutton', ...
                'Style', uim.style.tabButton, ...
                'Padding', [5, 0, 5, 0], ...
                'HorizontalTextAlignment', 'center', ...
                'AutoWrapText', true, ...
                'ButtonDownFcn', @obj.onTabButtonPressed }; 

            numButtons = numel(obj.Children);
            iButton = numButtons + 1; % number for this button
            
            if iButton > 1 % Add a separator between buttons
                separatorOptions = {'Color', ones(1,3)*0.9, ...
                    'LineWidth', 0.5, 'Height', 0.5};
                hSep = obj.TabToolBar.addSeparator(separatorOptions{:});
                obj.TabSeparators(iButton-1) = hSep;
                
                % Separators should be invisible when right next to a
                % selected tab button
                if iButton == 2 
                    hSep.Visible = 'off';
                end
            end
            
            % Add the button to the toolbar instance
            hBtn = obj.TabToolBar.addButton('String', hTab.Title, buttonOptions{:});
            
            % Add the button handle to tabButtonGroup property
            obj.TabButtonGroup(iButton) = hBtn;
            
            % Select button if it is the first button added.
            if iButton == 1
                obj.SelectedTab = 1;
                obj.TabButtonGroup(1).Value = true;
            end

        end
        
    end
    
    
    methods (Hidden)
        
        % Add tab
        function addTab(obj, hTab)

            % Adjust tab panel size to fit within the tabgroup container.
            toolbarHeight = obj.TabToolBar.Size(2);
            panelMargin = obj.Margin + [5,5,5,5 + toolbarHeight/2];
            
            hTab.Panel.Margin = panelMargin;
                        
            obj.createTabButton(hTab)
            
            if numel(obj.Children)>=1
                obj.Children(end+1) = hTab;
                hTab.Panel.Visible = 'off';
            else
                obj.Children = hTab;
            end
            
        end
        
        function updateTabTitle(obj, hTab)
            tabNum = find(ismember(obj.Children, hTab));
            
            hBtn = obj.TabButtonGroup(tabNum);
            hBtn.String = hTab.Title;

        end
        
        % Tab selected
        function onTabSelected(obj, src, evt)
            
        end
    end
    
    methods (Access = private)
        
        function changeTab(obj, panelNum)
            % need to be adapted. Taken from struct editor
            
            % Make sure all other tabs are not visible.
            set(obj.main.hPanel, 'Visible', 'off')
            obj.main.hPanel(panelNum).Visible = 'on';
            obj.currentPanel = panelNum;
            
            % Update header title
            obj.headerTitle.String = sprintf('Edit Preferences for %s', obj.Name{panelNum});
            
            % Create panel if it is opened for the first time.
            if ~obj.isTabCreated(panelNum)
            
                 % Create components
                obj.addComponents(panelNum)

                if exist('clib.uicontrolSchemer', 'class')==8
                    obj.styleControls(panelNum)
                end
                
                % Scroll to top, or align elements to top if all comps are
                % visible
                obj.visibleHeight(panelNum) = obj.main.hAxes(panelNum).Position(4); % Height of panel
                if obj.virtualHeight(panelNum) > obj.visibleHeight(panelNum)
                    obj.moveElementsToTop()
                end
                
                delete(obj.main.tmpPanel)
            end

        end
        
        function onTabButtonPressed(obj, src, evt)
        %onTabButtonPressed Callback handler for when a button is pressed
        
            % Determine which tab is selected
            nextTab = find(ismember(obj.TabButtonGroup, src));
            
            if isequal(nextTab, obj.SelectedTab)
                % Selected same tab
                evtData = uim.event.ToggleEvent(1);
            else
                % Selected new tab
                evtData = uim.event.ToggleEvent(0);
            end
            
            % Change button state.
            obj.TabButtonGroup(obj.SelectedTab).toggleState([], evtData)

            % Set panel visibility todo: make a separate method.
            if ~isequal(nextTab, obj.SelectedTab)
                obj.Children(nextTab).Panel.Visible = 'on'; 
                %obj.TabPanels(nextTab).Visible = 'on'; 
                obj.Children(obj.SelectedTab).Panel.Visible = 'off'; 
                %obj.TabPanels(obj.SelectedTab).Visible = 'off';
                
                % Update separator visibility
                for i = 1:numel(obj.TabSeparators)
                    if i == nextTab || i == nextTab-1
                        obj.TabSeparators(i).Visible = 'off';
                    else
                        obj.TabSeparators(i).Visible = 'on';
                    end
                end
                
                if ~isempty(obj.SelectionChangedFcn)
                    args = {obj.Children(obj.SelectedTab), obj.Children(nextTab)};
                    evtData = uim.event.TabSelectionChangedEvent(args{:});
                    obj.SelectionChangedFcn(obj, evtData)
                end
                
            end
            
            % Update currently selectedTab property
            obj.SelectedTab = nextTab;
            
        end
        
    end
    
    
    methods (Static, Access = protected)
            
        function S = getDefaultPropertyValues()
            
% %             S.PositionMode = 'auto';
% %             S.Location = 'northwest';
            
            S.IsFixedSize = [false, false];
% %             S.Size = [30, 30];

% %             S.HorizontalAlignment = 'left';
% %             S.VerticalAlignment = 'bottom';
% % 
% %             S.Padding = [10, 3, 10, 3];

            S.MinimumSize = [100, 100];
            S.MaximumSize = [inf, inf];

            S.Margin = [20,20,20,20];
            S.CornerRadius = 10;
            S.BackgroundColor = [0.3922    0.4000    0.4078];
            S.BackgroundAlpha = 1;
            
        end
    end
    
    
    
    
    
end