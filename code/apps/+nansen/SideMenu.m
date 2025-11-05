classdef SideMenu < handle & applify.HasTheme
%SideMenu A side menu panel with action buttons for the Nansen application
%
%   This class creates a vertical menu with action buttons on the right
%   side of the Nansen application. Buttons can trigger various actions
%   such as refreshing data, opening settings, or accessing tools.

    properties (Constant)
        DEFAULT_THEME = nansen.theme.getThemeColors('dark-gray');
    end

    properties (Access = private)
        Parent              % Parent container (uipanel)
        Figure              % Parent figure
        AppRef              % Reference to main Nansen.App
        Buttons = struct()  % Struct containing button handles
        ButtonPanel         % Panel containing buttons
        TitleLabel          % Title label for the menu
    end
    
    properties (Access = private)
        ButtonConfigs = struct(...
            'RefreshTable', struct(...
                'Label', 'Refresh Table', ...
                'Icon', '', ...
                'Callback', @(app, ~, ~) app.refreshTable(), ...
                'Tooltip', 'Refresh the current table view'), ...
            'RefreshDataLocations', struct(...
                'Label', 'Refresh Data', ...
                'Icon', '', ...
                'Callback', @(app, src, ~) app.onDataLocationModelChanged(src, []), ...
                'Tooltip', 'Refresh data location information'), ...
            'OpenSettings', struct(...
                'Label', 'Preferences', ...
                'Icon', '', ...
                'Callback', @(app, ~, ~) app.editSettings(), ...
                'Tooltip', 'Open application preferences'), ...
            'SaveTable', struct(...
                'Label', 'Save Table', ...
                'Icon', '', ...
                'Callback', @(app, src, ~) app.saveMetaTable(src, [], true), ...
                'Tooltip', 'Save the current metatable'), ...
            'ClearCache', struct(...
                'Label', 'Clear Cache', ...
                'Icon', '', ...
                'Callback', @(app, ~, ~) app.menuCallback_ClearCachedMetaObjects(), ...
                'Tooltip', 'Clear the SessionObject cache'), ...
            'OpenProjectFolder', struct(...
                'Label', 'Project Folder', ...
                'Icon', '', ...
                'Callback', @(app, ~, ~) app.menuCallback_OpenProjectFolder(), ...
                'Tooltip', 'Open the current project folder') ...
        )
    end
    
    properties
        IsVisible (1,1) logical = false
        Width (1,1) double = 200  % Width of the side menu in pixels
    end
    
    methods
        function obj = SideMenu(parentPanel, figureHandle, appReference)
            %SideMenu Constructor for the side menu
            %
            %   Inputs:
            %       parentPanel - Parent uipanel where menu will be created
            %       figureHandle - Main figure handle
            %       appReference - Reference to main nansen.App instance
            
            if nargin < 3 || isempty(appReference)
                error('SideMenu:InvalidInput', 'App reference is required');
            end
            
            obj.Parent = parentPanel;
            obj.Figure = figureHandle;
            obj.AppRef = appReference;
            
            obj.create();
        end
        
        function delete(obj)
            %delete Clean up resources
            if isvalid(obj.ButtonPanel)
                delete(obj.ButtonPanel);
            end
        end
        
        function show(obj)
            %show Make the side menu visible
            obj.IsVisible = true;
            obj.Parent.Visible = 'on';
            obj.updatePosition();
        end
        
        function hide(obj)
            %hide Hide the side menu
            obj.IsVisible = false;
            obj.Parent.Visible = 'off';
        end
        
        function toggle(obj)
            %toggle Toggle visibility of the side menu
            if obj.IsVisible
                obj.hide();
            else
                obj.show();
            end
        end
        
        function updatePosition(obj)
            %updatePosition Update the position based on parent figure size
            if ~isvalid(obj.Parent)
                return;
            end
            
            figPos = getpixelposition(obj.Figure);
            h = figPos(4);
            
            if obj.IsVisible
                obj.Parent.Position = [figPos(3) - obj.Width, 25, obj.Width, h - 25];
            else
                obj.Parent.Position = [figPos(3), 25, obj.Width, h - 25];
            end
        end
    end
    
    methods (Access = private)
        function create(obj)
            %create Create the side menu UI components
            
            % Configure parent panel
            obj.Parent.BorderType = 'line';
            obj.Parent.Units = 'pixels';
            
            % Create title label
            obj.TitleLabel = uicontrol('Parent', obj.Parent, ...
                'Style', 'text', ...
                'String', 'Quick Actions', ...
                'FontSize', 14, ...
                'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', ...
                'Units', 'pixels');
            
            % Create button panel
            obj.ButtonPanel = uipanel('Parent', obj.Parent, ...
                'BorderType', 'none', ...
                'Units', 'pixels');
            
            % Create buttons
            obj.createButtons();
            
            % Apply theme
            obj.applyTheme();
            
            % Position components
            obj.positionComponents();
        end
        
        function createButtons(obj)
            %createButtons Create all action buttons
            
            buttonNames = fieldnames(obj.ButtonConfigs);
            numButtons = numel(buttonNames);
            
            buttonHeight = 40;
            buttonSpacing = 5;
            
            for i = 1:numButtons
                buttonName = buttonNames{i};
                config = obj.ButtonConfigs.(buttonName);
                
                % Calculate button position
                yPos = (numButtons - i) * (buttonHeight + buttonSpacing) + buttonSpacing;
                
                % Create button
                btn = uicontrol('Parent', obj.ButtonPanel, ...
                    'Style', 'pushbutton', ...
                    'String', config.Label, ...
                    'FontSize', 11, ...
                    'Units', 'pixels', ...
                    'Position', [10, yPos, obj.Width - 20, buttonHeight], ...
                    'Tooltip', config.Tooltip);
                
                % Set callback with app reference
                btn.Callback = @(src, evt) config.Callback(obj.AppRef, src, evt);
                
                % Store button handle
                obj.Buttons.(buttonName) = btn;
            end
        end
        
        function positionComponents(obj)
            %positionComponents Position all components within the panel
            
            if ~isvalid(obj.Parent)
                return;
            end
            
            panelPos = obj.Parent.Position;
            panelHeight = panelPos(4);
            
            % Position title label
            titleHeight = 40;
            obj.TitleLabel.Position = [0, panelHeight - titleHeight, obj.Width, titleHeight];
            
            % Position button panel
            obj.ButtonPanel.Position = [0, 0, obj.Width, panelHeight - titleHeight];
        end
    end
    
    methods (Access = protected)
        function onThemeChanged(obj)
            %onThemeChanged Apply theme colors to components
            obj.applyTheme();
        end
    end
    
    methods (Access = private)
        function applyTheme(obj)
            %applyTheme Apply theme styling to all components
            
            theme = obj.Theme;
            
            % Apply to parent panel
            if isfield(theme, 'HeaderBgColor')
                obj.Parent.BackgroundColor = theme.HeaderBgColor;
                obj.Parent.HighlightColor = theme.HeaderBgColor;
                obj.Parent.ShadowColor = theme.HeaderBgColor;
            end
            
            % Apply to title label
            if isfield(theme, 'HeaderFgColor')
                obj.TitleLabel.ForegroundColor = theme.HeaderFgColor;
            end
            if isfield(theme, 'HeaderBgColor')
                obj.TitleLabel.BackgroundColor = theme.HeaderBgColor;
            end
            
            % Apply to button panel
            if isfield(theme, 'HeaderBgColor')
                obj.ButtonPanel.BackgroundColor = theme.HeaderBgColor;
            end
            
            % Apply to buttons
            buttonNames = fieldnames(obj.Buttons);
            for i = 1:numel(buttonNames)
                btn = obj.Buttons.(buttonNames{i});
                if isvalid(btn)
                    if isfield(theme, 'FigureFgColor')
                        btn.ForegroundColor = theme.FigureFgColor;
                    end
                    if isfield(theme, 'FigureBgColor')
                        btn.BackgroundColor = theme.FigureBgColor;
                    end
                end
            end
        end
    end
end
