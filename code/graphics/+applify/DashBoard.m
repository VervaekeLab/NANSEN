classdef DashBoard < applify.HasTheme & applify.mixin.HasDialogBox % & applify.mixin.UserSettings
    
    
    % Todo:
    %
    %   [ ] Make Appwindow class?
    %
    %   [ ] Coordinate with ModularApp class which classes are mainly
    %       responsible for resizing and draw operations. Make sure it is as
    %       efficient as possible. Make sure it is callback driven.
    %
    %   [ ] Optimize! 
    %       - Resizing
    %       - mouse over
    %       - window mouse and key callbacks... 
    %       - Implement mouseEnter and mouseLeave panel methods...
    %
    %   [ ] Block figure closing until dashboard is created
        
    properties (Constant, Hidden) % Inherits from applify.HasTheme
        DEFAULT_THEME = nansen.theme.getThemeColors('dark-gray')
    end
    
    properties (Abstract)
        ApplicationName
    end
    
    properties (Hidden) % Layout properties
        Margins = [10, 10, 10, 20] % Margins (left, bottom, right, top) in pixels
        Spacing = [30,10]  % Spacing (horizontal (x), vertical (y)) in pixels
    end
    
    properties
        AppModules %applify.ModularApp
    end
    
    properties (Access = protected)
        hFigure 
        hMainPanel matlab.ui.container.Panel
        hPanels matlab.ui.container.Panel
    end
    
    properties (Access = protected)
        IsConstructed = false;
    end
    
    
    methods (Abstract, Access = protected)
        
        createPanels(obj)
        resizePanels(obj)
        
    end
    
    methods % Structors
        
        function obj = DashBoard(varargin)

            obj.createFigure()
            obj.createPanels()
            obj.resizePanels()
            
            obj.setFigureInteractionCallbacks()
            
        end
        
        function onFigureCloseRequest(obj)
            
            obj.quit()
            % todo:
            % any reason to abort?
            % should anything be saved
            
            delete(obj)
            
        end
        
        function quit(obj)
        
        end
        
        function delete(obj)
            
            for i = 1:numel(obj.AppModules)
                delete(obj.AppModules(i))
            end
            
            if isvalid(obj.hFigure)
                delete(obj.hFigure)
            end
            
        end
        
    end
    
    methods % Set/Get
        function set.IsConstructed(obj, newValue)
           
            assert(islogical(newValue), 'IsConstructed must be logical')
            
            obj.IsConstructed = newValue;
            obj.onConstructed()
            
        end
    end
    
    methods (Access = protected) % Creation
        
        function createFigure(obj)
            
            obj.hFigure = figure('Visible', 'off');
            obj.hFigure.MenuBar = 'none';
            obj.hFigure.NumberTitle = 'off';
            obj.hFigure.Name = obj.ApplicationName;
            obj.hFigure.ResizeFcn = @(s,e) obj.resizeMainPanel;
            obj.hFigure.CloseRequestFcn = @(s,e) obj.onFigureCloseRequest();
            %obj.hFigure.Position(3:4) = obj.FigureSize;
            
            %set(obj.hFigure, 'DefaultAxesCreateFcn', @obj.onAxesCreated)
            
            obj.hMainPanel = uipanel(obj.hFigure);
            obj.hMainPanel.Title = '';
            obj.hMainPanel.BorderType = 'none';
            obj.hMainPanel.Units = 'pixels'; %'normalized'; %
            obj.hMainPanel.Tag = 'Dashboard Super Panel';
            %obj.hMainPanel.SizeChangedFcn = @(s,e) obj.resizeMainPanel;
        end
        
        function keepFigureOnScreen(obj)
           
            [sz, ~] = applify.ModularApp.getCurrentMonitorSize(obj.hFigure);
            
            % Figure is too wide for screen
            if obj.hFigure.Position(3) > sz(3)
                obj.hFigure.Position([1,3]) = sz([1,3]);
            end
            
            % Figure is too high for screen
            if obj.hFigure.Position(4) > sz(4)
                obj.hFigure.Position([2,4]) = sz([2,4]);
            end
            
            % Figure is placed too far to the right
            if sum(obj.hFigure.Position([1,3])) >  sz(3)
                obj.hFigure.Position(1) = sz(1) + (sz(3) - obj.hFigure.Position(3))/2;
            end
            
            % Figure is placed too high
            if sum(obj.hFigure.Position([2,4])) >  sz(4)
                obj.hFigure.Position(2) = sz(2) + (sz(4) - obj.hFigure.Position(4))/2;
            end

        end
        
        function resizeMainPanel(obj)
        %resizeMainPanel Resize main panel and subpanels.
        
        % Todo: Is there anything that can be optimized here???
        
        % Thanks to Jan @ https://www.mathworks.com/...
        % matlabcentral/answers/570829-slow-sizechangedfcn-or-resizefcn
        persistent blockCalls  % Reject calling this function again until it is finished
        if any(blockCalls), return, end
        blockCalls = true;

        % Todo: Generalize this...:
        set( cat(1, obj.hPanels([2:4]).Children ), 'Visible', 'off')
        %obj.hMainPanel.Visible = 'off';

        drawnow
        
        doResize = true;
        while doResize   % Repeat until the figure does not change its size anymore
            
            initialPosition = getpixelposition(obj.hFigure);

            panelPos = obj.computeMainPanelPosition();
            setpixelposition(obj.hMainPanel, panelPos)
            
            obj.resizePanels()
            pause(0.1)
            doResize = ~isequal(initialPosition, getpixelposition(obj.hFigure));

        end
        
        %obj.hMainPanel.Visible = 'on';
        set(cat(1,obj.hPanels([2:4]).Children), 'Visible', 'on')
        drawnow
        
        blockCalls = false;  % Allow further calls again
               
        end
        
        function panelPos = computeMainPanelPosition(obj)
        %computeMainPanelPosition Figure position minus margins.
            figPos = getpixelposition(obj.hFigure);
            panelPos(1:2) = obj.Margins(1:2);
            panelPos(3:4) = figPos(3:4) - sum(obj.Margins([1,2;3,4]));
        end
        
        function addPanelResizeButton(obj, hPanel)
            
            persistent icon
            if isempty(icon)
                iconSet = uim.style.iconSet(imviewer.App.getIconPath);
                icon = iconSet.maximize;
            end

            buttonArgs = {'Icon', icon, 'Padding', [4,4,4,4], ...
                'Size', [18,18], 'CornerRadius', 9, ...
                'Margin', [4,4,4,0], 'Location', 'northeast', ...
                'MechanicalAction', 'Latch when pressed', ...
                'Style', uim.style.buttonSymbol2};

            hButton = uim.control.Button_(hPanel, buttonArgs{:});
            hButton.Callback = @(s, e) obj.toggleMaximizePanel(hButton, hPanel);
            hButton.Location = 'northeast';
            
        end
        
        function toggleMaximizePanel(obj, btn, src)
            % Todo: 
            %   [x] Fix so that it works also if figure is resized while
            %       panel is open. Works since panel units are normalized
            %   [ ] Fix so that this works also if panel units are in pixels
            %   [ ] Add a SizeChangedFcn whil panel is maximized so that it
            %       will resize according to margins. 
            
            
            
            persistent iconSet
            if isempty(iconSet)
                iconSet = uim.style.iconSet(imviewer.App.getIconPath);
            end

            currentPos = round(getpixelposition(src)); %.Position;
            hFig = obj.hFigure;

            maxSize = obj.computeMainPanelPosition(); % Dont use this....Might be inaccurate since main panel is invisible when panel is maximized.
            maxSize = getpixelposition(obj.hMainPanel);

            tolerance = 25;
            if abs( sum(currentPos - maxSize) ) < tolerance % Restore
                
                src.Visible = 'off'; % Turn off visibility while restoring size
                drawnow % Make sure visibility is off before resizing panel
                
                % Restore visibility of main panel. Should also trigger 
                % resize if figure size changed while current panel was 
                % maximized. This could take time for complex dashboards.
                obj.hMainPanel.Visible = 'on';
                src.Parent = src.UserData.OriginalParent;
                
                src.Position = src.UserData.OriginalPosition; % This only works if panel units are normalized. Todo: Ensure that panel units are set to normalized before resizing
                src.BorderType = 'none';

                uistack(src, 'top')

                newIcon = iconSet.maximize;
                tooltip = 'Maximize Panel';
                src.Visible = 'on';
            else                                % Maximize

                % Turn of main panel visibility while the current panel is
                % maximized. Should improve performance.
                obj.hMainPanel.Visible = 'off';

                src.UserData.OriginalParent = src.Parent;
                src.UserData.OriginalUnits = src.Units;
                src.UserData.OriginalPosition = src.Position;

                src.Parent = hFig;
                src.BorderType = 'line';
                src.BorderWidth = 1;
                src.HighlightColor = [0.25,0.25,0.25]; % todo: get from theme...
                
                setpixelposition(src, maxSize)

                uistack(src, 'top')
                newIcon = iconSet.minimize;
                tooltip = 'Restore Panel';
            end

            drawnow
            btn.Icon = newIcon;
            btn.Tooltip = tooltip;
        end
        
        function setFigureInteractionCallbacks(obj)
            
            obj.hFigure.WindowKeyPressFcn = @obj.onKeyPressed;
            obj.hFigure.WindowKeyReleaseFcn = @obj.onKeyReleased;
            obj.hFigure.WindowScrollWheelFcn = @obj.onMouseScrolled;
            obj.hFigure.WindowButtonDownFcn = @obj.onMousePressed;
            obj.hFigure.WindowButtonMotionFcn = @obj.onMouseMotion;
            obj.hFigure.WindowButtonUpFcn = @obj.onMouseReleased;
            
        end
        
        function onConstructed(obj)
            
            if obj.IsConstructed
                obj.onThemeChanged()
                obj.hFigure.Visible = 'on';
            end
            
        end
        
        function onAxesCreated(obj, src, evt)
            % TODO: Does this actually make a difference...
            persistent removeAxToolbar
            if isempty(removeAxToolbar)
                matlabVersion = version();
                versionSplit = strsplit(matlabVersion, '.');
                versionVector = cellfun(@(c) str2double(c), versionSplit(1:3));
                removeAxToolbar = all( versionVector >= [9,5,0] );
            end

            if removeAxToolbar
                disableDefaultInteractivity(src)
                src.Toolbar = [];
            end
            
        end
    
    end
    
    methods (Access = protected)

        function [pos, siz] = computePanelPositions(obj, sizeSpecs, dim, availableLength)
            
            mainPanelPos = getpixelposition(obj.hMainPanel);
            
            % Determine some variable values based on the selected dimension
            switch dim
                case 'x'
                    SPACING = obj.Spacing(1);
                    mainPanelLength = mainPanelPos(3);
                case 'y'
                    SPACING = obj.Spacing(2);
                    mainPanelLength = mainPanelPos(4);
            end
            
            if nargin < 4
                availableLength = mainPanelLength;
            end
            
            % Count number of panels
            numPanels = numel(sizeSpecs);
            
            % Remove panel spacing from the available length
            availableLength = availableLength - SPACING*(numPanels-1);
            
            
            if isempty(sizeSpecs)
                lengthPix = ones(1, numPanels) .* availableLength ./ numPanels;
            else
                if iscolumn(sizeSpecs); sizeSpecs = sizeSpecs'; end
                % Convert to pixels...
                
                % Initialize vector for panel lengths in pixels
                lengthPix = zeros(1, numPanels);
                
                % Check if any size specs are in pixels
                isPixelSize = sizeSpecs > 1;
                lengthPix(isPixelSize) = sizeSpecs(isPixelSize);
                
                remainingLength = availableLength - sum(lengthPix);
                
                % Distribute remaining for panels specified in normalized
                % units
                lengthPix(~isPixelSize) = sizeSpecs(~isPixelSize) .* remainingLength;
            end

            
            % Get lengths for each panel and correct for rounding errors 
            % by adding 1 pixel to each panel starting at first panel 
            % and ending at the nth panel as needed to make sure panels 
            % correctly fill the available length.
            
            lengthPix = floor( lengthPix ); % Round down
            rem = floor( availableLength - sum(lengthPix) ); % Get remainders
            
            extra = zeros(1, numPanels); 
            extra(1:rem) = 1; % Distribute remainders

            siz = lengthPix + extra; % Add remainders to lengths
            
            % Calculate the location values for all panels
            pos = cumsum( [1, siz(1:end-1)] ) + (0:numPanels-1) .* SPACING;

        end
    
    end

    methods (Access = protected)

        function moduleHandle = getModuleHandle(obj, moduleName)
        %getModuleHandle Get module handle by name
            moduleIndex = strcmp( {obj.AppModules.AppName}, moduleName );
            if any(moduleIndex)
                moduleHandle = obj.AppModules(moduleIndex);
            else
                error('Module %s does not exist', moduleName)
            end
        end
               
        function setModuleHandle(obj, moduleName, moduleHandle)
        %setModuleHandle Set module handle by name
            moduleIndex = strcmp( {obj.AppModules.AppName}, moduleName );
            if any(moduleIndex)
                obj.AppModules(moduleIndex) = moduleHandle;
            else
                obj.AppModules(end+1) = moduleHandle;
            end
        end
    
    end
    
    methods (Access = protected) % Interactive callbacks
        %(Access = {?applify.ModularApp, ?applify.DashBoard} )
        
        function onKeyPressed(obj, src, evt, ~)
            currentApp = obj.getCurrentApp();
            %fprintf('keypress in %s\n', currentApp.AppName) % Debugging

            if ~isempty(currentApp)
                currentApp.onKeyPressed(src, evt)
            end
        end
        
        function onKeyReleased(obj, src, evt)
            currentApp = obj.getCurrentApp();
            %fprintf('keyrelease in %s\n', currentApp.AppName) % Debugging
            
            if ~isempty(currentApp)
                currentApp.onKeyReleased(src, evt)
            end
        end
        
        function onMouseScrolled(obj, src, evt)
            currentApp = obj.getCurrentApp();
            
            if ~isempty(currentApp)
                currentApp.onMouseScrolled(src, evt)
            end
        end
        
        function onMousePressed(obj, src, evt)
            currentApp = obj.getCurrentApp();
            
            if ~isempty(currentApp)
                currentApp.onMousePressed(src, evt)
            end
        end
        
        function onMouseMotion(obj, src, evt)
            currentApp = obj.getCurrentApp();
            
            if ~isempty(currentApp)
                currentApp.onMouseMotion(src, evt)
            end
        end
        
        function onMouseReleased(obj, src, evt)
            currentApp = obj.getCurrentApp();
            
            if ~isempty(currentApp)
                currentApp.onMouseReleased(src, evt)
            end
        end
            
        function currentApp = getCurrentApp(obj)
            
            % Todo: Improve performance by creating a pixelmap on every
            % resize so that we dont have to get positions constantly...
            currentApp = [];
            
            for i = 1:numel(obj.AppModules)
                if obj.AppModules(i).isMouseInApp()
                    currentApp = obj.AppModules(i);
                    break
                end
            end
            
        end
        
    end
    
    methods (Access = protected) % Property set callbacks
        
        function onThemeChanged(obj)
            
            S = obj.Theme;

            % Todo: Apply theme on figure and components
            obj.hFigure.Color = S.FigureBgColor;
            obj.hMainPanel.BackgroundColor = S.FigureBgColor;
            
            set(obj.hPanels, 'Background', S.FigureBgColor)
            
            % Set theme of submodules.
            for i = 1:numel(obj.AppModules)
                obj.AppModules(i).Theme = obj.Theme;
            end
            
            
        end
        
    end
    
    
end