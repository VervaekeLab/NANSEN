%scalebar Create a scalebar showing magnitude with optional unit
%
%   hScalebar = scalebar() creates a scalebar in the current axes
%
%   hScalebar = scalebar(axis) creates a scalebar on the specified axis.
%   Axis can be 'x' or 'y'. Default is 'x'.
%
%   hScalebar = scalebar(axis, n) creates a scalebar with length given by n
%
%   hScalebar = scalebar(__, unit) adds a unit label for the scalebar. Unit
%   is a character vector
%
%   hScalebar = scalebar(hParent, __) creates the scalebar in the specified
%   parent. hParent must be a valid Axes.
%
%   hScalebar = scalebar(__, Name, Value, ...)  sets scalebar properties 
%   using one or more name-value pair arguments.
%
%
%   Options (Name-value pairs)
%       ConversionFactor : Conversion factor (if data units are different 
%           than scalebar units). For example: If scalebar units is in mm 
%           and 150 pixels of an image corresponds to 1 mm, 
%           ConversionFactor should be 150. (pix/mm)
%       Location      : northwest, southeast, southwestoutside etc 
%       Color         : Color of scalebar line and text
%       LineWidth     : Width of scalebar line
%       Margin        : Pixel units of offset from corner of axes.
%       + FontSize, FontWeight, FontName etc. 
%       
%       type open scalebar in matlabs command window to see all public
%       properties of the scalebar.
%
%
%   EXAMPLE:
%     f = figure();
%     hAx = axes(f);
% 
%     imshow('cell.tif', 'Parent', hAx);
% 
%     pixPerUm = 5;
%     scalebarLength = 10  % scalebar will be 10 micrometer long
%     label = sprintf('%sm', '\mu'); % micrometer
%     
%     hScalebar = scalebar(hAx, 'x', scalebarLength, label, 'Location', 'southeast', ...
%         'ConversionFactor', pixPerUm);
% 
%     % Change color of scalebar
%     hScalebar.Color = 'w';


% Todo:
%   [ ] Position + units property?
%   [ ] Autogenerate code

classdef scalebar < handle % & uiw.mixin.AssignPVPairs
%SCALEBAR Add scalebar to axes

    properties
        Axis = 'x'            % Axis to place scalebar ('x' or 'y')   
        ScalebarLength = nan  % Length of scalebar in "physical" units
        UnitLabel = ''        % Unit label, ie 'um'
        
        ConversionFactor = 1 % Unit conversion if axes limits are in different units
                       % than the units of the plot or image. E.g if 1mm in an
                       % image is 150 pixels, ConversionFactor should be 150.
                       % conversionFactor = data unit per scalebar unit
        
        AutoAdjustScalebarLength = false;
        AutoScalebarLength = 20; % In percentage of axes size...
        
        Location = 'southeastoutside'  % northwest, southeast, southwestoutside etc 
        Color = 'k'             % Color specification for line and text
        LineWidth = 1           % Width of scalebar
        
        TextSpacing = 2;        % Spacing (offset) between scalebar line and text in pixels
        FontName = 'Helvetica Neue';
        FontSize = 10;          % Fontsize of scalebar text
        FontWeight = 'normal'   % Fontweight of scalebar text
        
        Margin = [10, 10]       % Pixel units of offset from corner of image.
    end
    
    properties (Dependent)
        Parent
        Visible matlab.lang.OnOffSwitchState
    end
    
    properties (Access = private)
        hAxes               % Handle for the axes
        hScalebarLine       % Handle for the scalebar's line 
        hScalebarText       % Handle for the scalebar's text label
        ContextMenu         % Handle for scalebar's contextmenu
        
        IsConstructed = false
        
        MarginNorm          % Margins in normalized units   
        ScalebarLengthDu    % Length of scalebar in data units
        AxesSizePixels      % Size of axes in pixels
    end
    
    properties (Access = private)
        SizeChangedListener
        LimitsChangedListener
    end

    properties (Constant, Hidden)
        STYLE_PROPS = {'FontSize', 'FontWeight', 'LineWidth', ...
            'Color', 'Location', 'FontName'};
    end
    
    methods % Constructor/destructor
        
        function obj = scalebar(varargin)
        %SCALEBAR Construct an instance of this class
        %
        %   hScalebar = scalebar() creates a scalebar in the current axes
        %
        %   hScalebar = scalebar(axis) creates a scalebar on the specified 
        %   axis. Axis can be 'x' or 'y'. Default is 'x'.
            
            % Check for axes
            varargin = obj.checkArgs(varargin);            
            
            % Set default style properties from preferences
            nvPairs = prefs2props();
            obj.assignPVPairs(nvPairs{:})
            
            % Parse nv pairs
            [nvPairs, varargin] = getnvpairs(varargin{:});
            obj.assignPVPairs(nvPairs{:})
            
            % % Start creating scalebar
            isHoldOn = ishold(obj.hAxes);
            hold(obj.hAxes, 'on')

            if isnan(obj.ScalebarLength)
                obj.autoAdjustScalebarLength()
            end
            
            % Configure placement
            updateAxesSizePixel(obj)
            assignScalebarLength(obj)
            calculateMarginDataUnits(obj)    

            % Plot scalebar
            obj.plotScalebar()
            obj.plotTextLabel()
            
            % Create contextmenu 
            obj.createContextMenu()
            obj.createListeners()
            
            obj.IsConstructed = true;
            
            if ~isHoldOn
                hold(obj.hAxes, 'off')
            end
            
        end
        
        function delete(obj)
        %delete Delete components of scalebar

            obj.deleteListeners()
            delete(obj.ContextMenu)
            delete(obj.hScalebarLine)
            delete(obj.hScalebarText)
            
        end
    end
    
    methods % Set/get
        function set.Parent(obj, newValue)
            obj.validateAxes(newValue)
            obj.hAxes = newValue;
            
            obj.onParentChanged()
        end
        function hParent = get.Parent(obj)
            hParent = obj.hAxes;
        end
        
        function set.Visible(obj, newValue)
            if obj.IsConstructed
                obj.hScalebarLine.Visible = newValue;
                obj.hScalebarText.Visible = newValue;
            end
        end
        function visible = get.Visible(obj)
            if obj.IsConstructed
                visible = obj.hScalebarLine.Visible;
            else
                visible = 'off';
            end
        end
        
        function set.Color(obj, newColor)
            obj.onColorSet(newColor)
            % Only set prop value if above does not fail
            obj.Color = newColor;
        end
        
        function set.UnitLabel(obj, newValue)
            assert(ischar(newValue), 'Value must be a character vector')
            obj.UnitLabel = newValue;
            obj.updateTextLabel()
        end
        
        function set.ConversionFactor(obj, newValue)
            obj.ConversionFactor = newValue;
            obj.updateScalebar()
            %obj.updateTextLabel()
            obj.updateTextPosition()
        end
        
        function set.ScalebarLength(obj, newValue)
            obj.ScalebarLength = newValue;
            %obj.updateScalebar()
            obj.updateTextLabel()
            obj.updatePosition();
        end
        
        function set.LineWidth(obj, newValue)
            obj.onLinewidthChanged(newValue)
            % Only set prop value if above does not fail
            obj.LineWidth = newValue;
            obj.updateTextPosition()
            obj.updateContextMenu('Line Width')
        end
        
        function set.FontName(obj, newValue)
            obj.onFontNameChanged(newValue) 
            % Only set prop value if above does not fail
            obj.FontName = newValue;
        end
        
        function set.FontSize(obj, newValue)
            obj.onFontSizeChanged(newValue) 
            % Only set prop value if above does not fail
            obj.FontSize = newValue;
            obj.updateContextMenu('Font Size')
        end
        
        function set.FontWeight(obj, newValue)
             obj.onFontWeightChanged(newValue) 
            % Only set prop value if above does not fail
            obj.FontWeight = newValue;
        end
        
        function set.Location(obj, newValue)
            obj.Location = newValue;
            obj.updatePosition()
            obj.updateContextMenu('Location')
        end
        
        function set.Margin(obj, newValue)
            obj.Margin = newValue;
            obj.updatePosition()
        end
        
    end
    
    methods (Access = private) % Config & creation
        
        function assignScalebarLength(obj)
            
            n = obj.ScalebarLength;
            
            switch obj.Axis
                case 'x'
                    obj.ScalebarLengthDu = [n * obj.ConversionFactor, 0];
                case 'y'
                    obj.ScalebarLengthDu = [0, n * obj.ConversionFactor];
            end
            
        end
        
        function [xSign, ySign] = configurePositionDirection(obj)
            
            xSign = 1;
            ySign = 1;

            % Factor which moves coordinates outside of axes...
            if contains(obj.Location, 'outside')
                switch obj.Axis
                    case 'x'
                        ySign = -1;
                    case 'y'
                        xSign = -1;
                end
            end
            
        end
        
        function calculateMarginDataUnits(obj)
            % Convert pixel margin to x and y margin
            % NB: requires plotboxpos function from fileexchange and assumes axes
            % units are normalized and figure units are pixels....
            obj.updateAxesSizePixel()
            obj.MarginNorm = obj.Margin ./ obj.AxesSizePixels;
        end 
        
        function updateAxesSizePixel(obj)
            
            if exist('plotboxpos', 'file') == 2
                axUnits = obj.hAxes.Units;
                set(obj.hAxes, 'Units', 'normalized')
                axpos = plotboxpos(obj.hAxes);
                set(obj.hAxes, 'Units', axUnits)

                figH = ancestor(obj.hAxes, 'figure');
                figPos = getpixelposition(figH);
                axPixSize = figPos(3:4) .* axpos(3:4);
                
            else
                axPixPos = getpixelposition(obj.hAxes);
                axPixSize = axPixPos(3:4);
            end
            
            obj.AxesSizePixels = axPixSize;

        end
        
        function xData = calculateXData(obj)    % Calculate x coordinates of line
            
            [xSign, ~] = configurePositionDirection(obj);

            xLim = obj.hAxes.XLim;
            xLimRange = max(xLim) - min(xLim);
            
            offsetDu = xLimRange * obj.MarginNorm(1) * xSign;

            if contains(obj.Location, 'east')
                xData = xLim(2) - offsetDu - [obj.ScalebarLengthDu(1), 0];
            elseif contains(obj.Location, 'west')
                xData = xLim(1) + offsetDu + [0, obj.ScalebarLengthDu(1)];
            end
            
            xData = double(xData);
        end
        
        function yData = calculateYData(obj) 
            
            yLim = obj.hAxes.YLim;
            yLimRange = max(yLim) - min(yLim);

            [~, ySign] = configurePositionDirection(obj);

            offsetDu = yLimRange * obj.MarginNorm(2) * ySign;
                        
            % Calculate y coordinates of line
            if contains(obj.Location, 'north')
                yData = yLim(2) - offsetDu - [obj.ScalebarLengthDu(2), 0];
            elseif contains(obj.Location, 'south')
                yData = yLim(1) + offsetDu + [0, obj.ScalebarLengthDu(2)];
            end
            
            if strcmp(obj.hAxes.YDir, 'reverse')
                yData = yLim(1) - (yData - yLim(2));
            end
            
            yData = double(yData);

        end
            
        function txtPos = calculateTextPosition(obj)
            
            xData = calculateXData(obj) ;
            yData = calculateYData(obj) ;
            yLim = obj.hAxes.YLim;
            
            [xSign, ySign] = configurePositionDirection(obj);

            if strcmp(obj.hAxes.YDir, 'reverse')
                ySign = -ySign;
            end
            
            
            [~, vert] = getTextAlignment(obj);
            yOffset = obj.TextSpacing + obj.LineWidth/2;
            yOffset = (max(yLim)-min(yLim)) * (yOffset/obj.AxesSizePixels(2)) * ySign;

            if strcmp(vert, 'top')
                yOffset = -1 * yOffset;
            end
            
            if contains(obj.Location, 'outside')
                yOffset = -1 * yOffset;
            end
            
            
            % Calculate text coordinates and set alignment of text.
            switch obj.Axis
                case 'x'
                    txtPos = struct('x', xData(1)+diff(xData)/2, 'y', yData(1) + yOffset);
                case 'y'
                    txtPos = struct('x', xData(1), 'y', yData(1)+diff(yData)/2);
            end
            
            if strcmp(obj.hAxes.YDir, 'reverse')
                %txtPos.y = yLim(2) - (txtPos.y - yLim(1));
            end
            
            
            
        end
        
        function textLabel = getTextLabel(obj) % todo: dependent?
        %getTextLabel Get formatted text label
            
        % Add text
            n = obj.ScalebarLength;
            
            if strcmp(obj.UnitLabel, 'um') % Special case..
                unitLabel = sprintf('%sm', '\mu'); % micrometer
            else
                unitLabel = obj.UnitLabel;
            end
            
            % Todo....
            if isequal(n, round(n))
                textLabel = sprintf('%d %s', n, unitLabel);
            else
                textLabel = sprintf('%.3f %s', n, unitLabel);
            end

        end
        
        function [horz, vert] = getTextAlignment(obj)
            horz = 'center';
            vert = 'bottom';

            switch obj.Axis
                case 'x'
                    if any(strcmp(obj.Location, { 'northeast', 'northwest', ...
                            'southeastoutside', 'southwestoutside' }))
                        vert = 'top';
                    end
                case 'y'
                    if any(strcmp(obj.Location, { 'southeastoutside', 'southwest', ...
                            'northeastoutside', 'northwest' }))
                        vert = 'top';
                    end
            end 
            
            % Todo: X:  north: text under line. South: text over line
            % Todo: y:  west: text right of line. east: text left of line
            % Reverse when scalebar is outside of axes....
        end
        
        function plotScalebar(obj)
            
            xData = calculateXData(obj) ;
            yData = calculateYData(obj) ;
            
            % Plot scalebar
            obj.hScalebarLine = plot(obj.hAxes, xData, yData);
            %obj.hScalebarLine.HandleVisibility = 'off';
            obj.hScalebarLine.Tag = 'Scalebar Line';
            
            addlistener(obj.hScalebarLine, 'ObjectBeingDestroyed', ...
                @(s,e) obj.delete);
            
            % Make sure scalebar is not clipped.
            %if contains(obj.Location, 'outside')
                set(obj.hScalebarLine, 'Clipping', 'off')
                % set(obj.hAxes, 'Clipping', 'on')
            %end

            obj.hScalebarLine.Color = obj.Color;
            obj.hScalebarLine.LineWidth = obj.LineWidth;
        end

        function plotTextLabel(obj)
            
            % Add text

            txtPos = calculateTextPosition(obj);
            textLabel = getTextLabel(obj);
            [horz, vert] = getTextAlignment(obj);
            
            if isempty(obj.hScalebarText)
                obj.hScalebarText = text(obj.hAxes, txtPos.x, txtPos.y, ...
                    textLabel, 'Color', obj.Color, 'FontSize', ...
                    obj.FontSize, 'FontWeight', obj.FontWeight);
                %obj.hScalebarText.HandleVisibility = 'off';
                obj.hScalebarText.Tag = 'Scalebar Text';
            else
                obj.hScalebarText.Position(1:2) = [txtPos.x, txtPos.y];
            end

            obj.hScalebarText.VerticalAlignment = vert;
            obj.hScalebarText.HorizontalAlignment = horz;

            if strcmp(obj.Axis, 'y')
                obj.hScalebarText.Rotation = 90;
            end
            
        end
        
        function createContextMenu(obj)
        
            checked = {'off', 'on'};
            
            hFigure = ancestor(obj.hAxes, 'figure');
            hMenu = uicontextmenu(hFigure);
            
            mItem = uimenu(hMenu, 'Text', 'Configure Scalebar...');
            mItem.Callback = @(s,e) obj.uiEditScalebar;
                     
            mItem = uimenu(hMenu, 'Text', 'Autoadjust Scalebar');
            mItem.Checked = checked{ obj.AutoAdjustScalebarLength + 1 };
            mItem.Callback = @(s,e) obj.setAutoadjustScalebar(s);
            
            mItem = uimenu(hMenu, 'Text', 'Set Color...', 'Separator', 'on');
            mItem.Callback = @(s,e) obj.setColor;
            
            mItem = uimenu(hMenu, 'Text', 'Set Line Width');
            for i = 1:6
                mSubItem = uimenu(mItem, 'Text', num2str(i, '%d'));
                mSubItem.Checked = checked{ isequal(i, obj.LineWidth) + 1 };
                mSubItem.Callback = @(s,e) obj.setLineWidth(i);
            end
            
            mItem = uimenu(hMenu, 'Text', 'Set Font Size');
            for i = 0:6
                mSubItem = uimenu(mItem, 'Text', num2str(i+10, '%d'));
                mSubItem.Checked = checked{ isequal(i+10, obj.FontSize) + 1 };
                mSubItem.Callback = @(s,e) obj.setFontSize(i+10);
            end
            
            mItem = uimenu(hMenu, 'Text', 'Set Font...');
            mItem.Callback = @(s,e) obj.setFont;
            
            mItem = uimenu(hMenu, 'Text', 'Location');
            locations = {'southeast', 'southwest', 'northwest', 'northeast'};
            for i = 1:numel(locations)
                mSubItem = uimenu(mItem, 'Text', locations{i});
                mSubItem.Checked = checked{ strcmp(locations{i}, obj.Location) + 1 };
                mSubItem.Callback = @(s,e) obj.setLocation(locations{i});
            end
            
            mItem = uimenu(hMenu, 'Text', 'Save Current Style', 'Separator', 'on');
            mItem.Callback = @(s,e) props2prefs(obj);
                        
            mItem = uimenu(hMenu, 'Text', 'Delete Scalebar', 'Separator', 'on');
            mItem.Callback = @(s,e) obj.delete;
            
            obj.hScalebarText.ContextMenu = hMenu;
            obj.hScalebarLine.ContextMenu = hMenu;
            
            obj.ContextMenu = hMenu; % store in property
        end
        
        function updateContextMenu(obj, name, propName)
            
            if isempty(obj.ContextMenu); return; end
            
            if nargin < 3; propName = 'Checked'; end
            
            switch name
                case 'Line Width'
                    menuItem = findobj(obj.ContextMenu, 'Text', 'Set Line Width');
                    menuSubItem = menuItem.Children;
                    isMatched = strcmp({menuSubItem.Text}, num2str(obj.LineWidth, '%d'));
                    
                case 'Font Size'
                    menuItem = findobj(obj.ContextMenu, 'Text', 'Set Font Size');
                    menuSubItem = menuItem.Children;
                    isMatched = strcmp({menuSubItem.Text}, num2str(obj.FontSize, '%d'));
                    
                case 'Location'
                    menuItem = findobj(obj.ContextMenu, 'Text', 'Location');
                    menuSubItem = menuItem.Children;
                    isMatched = strcmp({menuSubItem.Text}, obj.Location);
                    
            end
            
            switch propName
                case 'Checked'
                    set(menuSubItem(~isMatched), 'Checked', 'off')
                    set(menuSubItem(isMatched), 'Checked', 'on')
                
            end
            
        end
        
        function createListeners(obj)
            
            obj.SizeChangedListener = listener(obj.hAxes, 'SizeChanged', ...
                @(s, e) obj.updatePosition);
            
            props = {'XLim', 'YLim'};
            obj.LimitsChangedListener = listener(obj.hAxes, props, ...
                'PostSet', @(s, e) obj.onAxesLimitsChanged);

        end
        
        function deleteListeners(obj)
            isdeletable = @(x) ~isempty(x) && isvalid(x);
            
            if isdeletable(obj.SizeChangedListener)
                delete(obj.SizeChangedListener)
            end
            
            if isdeletable(obj.LimitsChangedListener)
                delete(obj.LimitsChangedListener)
            end
        end
        
    end
    
    methods (Access = private) % Internal updating
        
        function validateAxes(obj, hAxes)
            assert(isa(hAxes, 'matlab.graphics.axis.Axes') && isvalid(hAxes), ...
                'First argument must be a valid axes object')
        end
        
        function args = checkArgs(obj, args)
            
            % Check if first argument is an axes object.
            if numel(args) >= 1 && isa(args{1}, 'matlab.graphics.axis.Axes')
                obj.hAxes = args{1};
                args(1) = [];
            end
            
            % If axes was not assigned, get the current axes.
            if isempty(obj.hAxes) 
                obj.hAxes = gca;
            end
            
            % Check if first argument is axis 
            if numel(args) >= 1 && ischar(args{1}) && ...
                    any( strcmp({'x', 'y'}, args{1}) )
                obj.Axis = args{1};
                args(1) = [];
            end
            
            % Check if second argument is length of scalebar
            if numel(args) >= 1 && isnumeric(args{1})
                obj.ScalebarLength = args{1};
                args(1) = [];
            end
            
            % Check if third argument is name of scalebar units
            if numel(args) >= 1 && ischar(args{1})
                if ~isprop(obj, args{1})
                    obj.UnitLabel = args{1};
                    args(1) = [];
                end
            end
            
        end
        
        function assignPVPairs(obj, varargin)
           
            names = varargin(1:2:end);
            for i = 1:numel(names)
                thisName = names{i};
                if isprop(obj, thisName)
                    obj.(thisName) = varargin{i*2};
                else
                    warning('Could not set the parameter "%s" for %s', thisName, class(obj))
                end
            end           
        end
        
        function onColorSet(obj, newValue)
            if obj.IsConstructed
                set(obj.hScalebarLine, 'Color', newValue)
                set(obj.hScalebarText, 'Color', newValue)
            end
        end
        
        function onLinewidthChanged(obj, newValue)
            if ~obj.IsConstructed; return; end
            set(obj.hScalebarLine, 'LineWidth', newValue)
        end
        
        function onFontNameChanged(obj, newValue)
            if ~obj.IsConstructed; return; end
            set(obj.hScalebarText, 'FontName', newValue)
        end
        
        function onFontSizeChanged(obj, newValue)
            if ~obj.IsConstructed; return; end
            set(obj.hScalebarText, 'FontSize', newValue)
        end
        
        function onFontWeightChanged(obj, newValue)
            if ~obj.IsConstructed; return; end
            set(obj.hScalebarText, 'FontWeight', newValue)
        end

        function onAxesLimitsChanged(obj)
            if obj.AutoAdjustScalebarLength
                obj.autoAdjustScalebarLength()
            end
            
            obj.updatePosition()
        end
        
        function onParentChanged(obj)
            if ~obj.IsConstructed; return; end
            
            wasHoldOn = ishold(obj.hAxes);
            hold(obj.hAxes, 'on')
            obj.hAxes.XLim = obj.hAxes.XLim;
            obj.hAxes.YLim = obj.hAxes.YLim;
            
            obj.hScalebarLine.Parent = obj.hAxes;
            obj.hScalebarText.Parent = obj.hAxes;
            obj.deleteListeners()
            obj.createListeners()
            
            obj.ContextMenu.Parent = ancestor(obj.hAxes, 'figure');
            
            obj.updatePosition()
            
            if ~wasHoldOn
                hold(obj.hAxes, 'off')
            end
        end
        
        function updateTextLabel(obj)
            if ~obj.IsConstructed; return; end
            textLabel = obj.getTextLabel();
            obj.hScalebarText.String = textLabel;
        end
        
        function updateScalebar(obj)
            if ~obj.IsConstructed; return; end
            
            obj.assignScalebarLength()
            obj.hScalebarLine.XData = obj.calculateXData();
            obj.hScalebarLine.YData = obj.calculateYData();
        end
        
        function updatePosition(obj)
            if ~obj.IsConstructed; return; end
                        
            % Make sure limit mode is manual, because resizing the scalebar
            % could change the axes limits.
            xLimModePreUpdate = obj.hAxes.XLimMode;
            yLimModePreUpdate = obj.hAxes.YLimMode;
            
            if ~strcmp(xLimModePreUpdate, 'manual')
                obj.hAxes.XLimMode = 'manual';
            end
            if ~strcmp(yLimModePreUpdate, 'manual')
                obj.hAxes.YLimMode = 'manual';
            end
                        
            assignScalebarLength(obj)
            calculateMarginDataUnits(obj)
            
            obj.updateScalebar()
            obj.plotTextLabel()
            
            % Reset xlim and ylim modes
            obj.hAxes.XLimMode = xLimModePreUpdate;
            obj.hAxes.YLimMode = yLimModePreUpdate;

        end
        
        function updateTextPosition(obj)
            if ~obj.IsConstructed; return; end
            
            txtPos = calculateTextPosition(obj);
            obj.hScalebarText.Position(1:2) = [txtPos.x, txtPos.y];
        end
        
        function autoAdjustScalebarLength(obj)
            
            switch obj.Axis
                case 'x'
                    axesLimits = obj.hAxes.XLim;
                case 'y'
                    axesLimits = obj.hAxes.YLim;
            end
            
            limRange = max(axesLimits) - min(axesLimits);
            
            scalebarLengthDu = limRange .* obj.AutoScalebarLength/100;
            
            % conversionFactor = data unit / scalebar unit;
            scalebarLengthRu = scalebarLengthDu / obj.ConversionFactor;
            
            % Round to nearest 5 on first significant digit
            x = floor( log10(scalebarLengthRu) );
            scalebarLengthRu_ = scalebarLengthRu .* 10^-x;
            scalebarLengthRu_ = round(scalebarLengthRu_);
            scalebarLengthRu_ = scalebarLengthRu_ .* 10^x;
            
% %             if scalebarLengthRu_ == 0
% %                 x = x + sign(x);
% %                 scalebarLengthRu_ = round(scalebarLengthRu/5, -x) * 5;
% %             end
            
            % Set autoadjusted scalebar length
            obj.ScalebarLength = scalebarLengthRu_;
            
        end
        
    end
    
    methods
        
        function uiEditScalebar(obj)
            definput = {num2str(obj.ScalebarLength), obj.UnitLabel, num2str(obj.ConversionFactor)};
            answer = inputdlg({'Enter scalebar length', 'Enter scalebar unit', ...
                'Enter conversion ratio'}, 'Enter scalebar info', 1, definput);
            if isempty(answer); return; end
            
            scalebarLength = str2double(answer{1});
            unitLabel = answer{2};
            conversionFactor = str2double(answer{3});
            
            obj.ScalebarLength = scalebarLength;
            obj.UnitLabel = unitLabel;
            obj.ConversionFactor = conversionFactor;
            
        end
        
        function setAutoadjustScalebar(obj, src)
           
            if src.Checked
                obj.AutoAdjustScalebarLength = false;
                src.Checked = 'off';
            else
                obj.AutoAdjustScalebarLength = true;
                src.Checked = 'on';
                obj.autoAdjustScalebarLength()
            end
            
        end
        
        function setLineWidth(obj, lineWidth)
            obj.LineWidth = lineWidth;
        end
        
        function setFontSize(obj, fontSize)
            obj.FontSize = fontSize;
        end
        
        function setColor(obj)
            c = uisetcolor('Select scalebar color');
            if isequal( c, 0)
                return % User canceled
            else 
                obj.Color = c;
            end
        end
        
        function setFont(obj)
            
            opts = uisetfont(obj.hScalebarText);
            if isequal( opts, 0)
                return % User canceled
            else 
                obj.FontWeight = opts.FontWeight;
                obj.FontSize = opts.FontSize;
                obj.FontName = opts.FontName;
            end
            
        end
        
        function setLocation(obj, newLocation)
            obj.Location = newLocation;
        end
        
    end
    
    methods (Static)
        function demo()
            scalebarDemo()
        end
        
        function test()
            testScalebar()
        end
    end

end

function [nvPairs, varargin] = getnvpairs(varargin)
%getnvpairs Get name value pairs from a list of input arguments
%
%   [nvPairs, varargin] = getnvpairs(varargin)

    
    if numel(varargin)==1 && iscell(varargin{1}) 
        % Assume varargin is passed on directly and need to be unpacked
        varargin = varargin{1};
    end

    nvPairs = {};
    
    for i = numel(varargin) : -2 : 1
        
        if i == 1; break; end
        
        if ischar( varargin{i-1} )
            nvPairs = [nvPairs, varargin(i-1:i)]; %#ok<AGROW>
            varargin(i-1:i) = [];
        else
            break
        end
        
    end
        
end

function props2prefs(obj)
    
    [~, groupName, ~] = fileparts(mfilename('fullpath'));
    propNames = uim.illustration.scalebar.STYLE_PROPS;
    
    for i = 1:numel(propNames)
        setpref(groupName, propNames{i}, obj.(propNames{i}))
    end
    
end

function nvPairs = prefs2props()
    
    [~, groupName, ~] = fileparts(mfilename('fullpath'));
    propNames = uim.illustration.scalebar.STYLE_PROPS;
    % todo: get from mc...
    defaultValues = {12, 'normal', 1, 'k', 'southeast', 'Helvetica Neue'};
    prefValues = cell(1, numel(propNames));
    
    for i = 1:numel(propNames)
        prefValues{i} = getpref(groupName, propNames{i}, defaultValues{i});
    end
    
    nvPairs = cat(1, propNames, prefValues);
    nvPairs = transpose( nvPairs(:) );
    
end

function hScalebar = scalebarDemo()

    f = figure();
    hAx = axes(f);

    imshow('cell.tif', 'Parent', hAx);

    pixPerUm = 5;
    scalebarLength = 10;  % scalebar will be 10 micrometer long
    label = sprintf('%sm', '\mu'); % micrometer
    
    hScalebar = uim.illustration.scalebar(hAx, 'x', scalebarLength, label, 'Location', 'southeast', ...
        'ConversionFactor', pixPerUm, 'Margin', [10,10]);
    
    if ~nargout; clear hScalebar; end

end

function testScalebar()
    
    figure;
    ax = axes;
    imshow(imread('cameraman.tif'))
    
    axis = {'x', 'y'};
    locs = {'northeast', 'northwest', 'southeast', 'southwest'};
    
    for i = 1:2
        for j = 1:4
            for k = 1:2
                loc = locs{j};
                c = 'w';
                if k == 2
                    loc = strcat(loc, 'outside');
                    c = 'r';
                end
                uim.illustration.scalebar(ax, axis{i}, 50, 'pixels', 'ConversionFactor', 1, 'Location', loc, 'Color', c, 'LineWidth', 2)
            end
        end
    end

end