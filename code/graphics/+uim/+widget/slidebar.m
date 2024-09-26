classdef slidebar < handle % & uiw.mixin.AssignPVPairs
    
    % Todo: adapt to uim.widgets.
    
    % Todo: Allow vertical orientation...
    
    properties
        
        Min = 0                 % Minimum slider value
        Max = 1                 % Maximum slider value
        Value = 0.5
        
        nTicks = 100
        Parent = []
        
        BarColor = ones(1,3)*0.75;
        KnobEdgeColorInactive = ones(1,3)*0.7;
        KnobEdgeColorActive = [0.1195    0.6095    0.5395]; % ones(1,3)*0.3; %;
        KnobFaceColorInactive = ones(1,3)*0.95;
        KnobFaceColorActive = ones(1,3)*0.8;
        TextColor = ones(1,3)*0.2;
        TextBackgroundColor = 'none';
        
        TickLength = 0;
        TickWidth = 1;
        TickMode = 'both' % 'over','under', 'both'
        
        ValueChangedFcn
        ValueChangingFcn
        Callback
        
        Position = [0, 0, 0.1, 0.3]
        Units = 'normalized'
        Padding = [0,9,3,9]; % padding in pixels...
        
        Visible = 'on'
        ShowLabel = true;
        TooltipPrecision = 2;
        TooltipUnits = '';
        TooltipExpression
        
        Style = 'slidebar'
        Tag = ''
        
    end
    
    
    properties (Dependent = true)
        Step
        FontSize
    end
    
    
    properties (Access = private)
        hAxes
        hasAxes = false;
        
        hBar
        hSlider
        hText
        hBackground
        hTicks = gobjects(0)
        
        WindowButtonUpListener
        WindowMouseMotionListener
        IsConstructed = false
    end
    
    
    methods % Structor
        
        function obj = slidebar(varargin)
            
            obj.parsevarargin(varargin)
            
            obj.createSlider()
            
            obj.IsConstructed = true;
        end
        
        function delete(obj)
            if obj.hasAxes
                delete(obj.hAxes)
            else
                delete(obj.hBar)
                delete(obj.hSlider)
                delete(obj.hText)
                delete(obj.hBackground)
                delete(obj.hTicks)
            end
        end
        
    end
    
    methods (Access = private) % Initialization
        function parsevarargin(obj, varargin)
            
            if isempty(varargin); return; end
            
            propNames = properties(obj);
            
            dependentProps = utility.class.findproperties(obj, 'Dependent');
            propNames = setdiff(propNames, dependentProps);
            
            defaultValues = cellfun(@(name) obj.(name), propNames, 'uni', 0);
            def = cell2struct(defaultValues, propNames, 1);
            
            props = utility.parsenvpairs(def, [], varargin{1});
            for i = 1:numel(propNames)
                obj.(propNames{i}) = props.(propNames{i});
            end
            
        end
        
        function createSlider(obj)
            
            if isempty(obj.Parent)
                obj.Parent = gcf;
            end
            
            if ~isa(obj.Parent, 'matlab.graphics.axis.Axes')
                obj.createAxes()
            else
                obj.hAxes = obj.Parent;
            end

            
            % Slider and especially the slider track is thin, and its easy
            % to miss when pressing it. Patch background so that
            % mousepresses are still captured by this widget on close miss.
            [xCoords, yCoords] = obj.getBackgroundCoordinates();
            obj.hBackground = patch(obj.hAxes, xCoords, yCoords, 'w');
            obj.hBackground.FaceAlpha = 0; % Makes it hittable
            obj.hBackground.EdgeColor = 'none';
            obj.hBackground.PickableParts = 'all';
            

            
            % Start plotting ticks, so that they are behind everything else
            if obj.TickLength ~= 0
                obj.plotTicks()
            end

            % Plot the bar as a line
            [xCoords, yCoords] = obj.getBarCoordinates();
%             obj.hBar = plot(obj.hAxes, xCoords, yCoords);
%             obj.hBar.LineWidth = 3;
%             obj.hBar.Color = obj.BarColor;

            obj.hBar = patch(obj.hAxes, xCoords, yCoords, obj.BarColor);

            obj.hBar.HitTest = 'on';
            obj.hBar.PickableParts = 'visible';
            obj.hBar.FaceColor = obj.BarColor;
            obj.hBar.EdgeColor = 'none';

            obj.hBackground.ButtonDownFcn = @(src, event) obj.moveSlider;
            obj.hBar.ButtonDownFcn = @(src, event) obj.moveSlider;
            
            % Patch the slider knob using aspect ratio adjusted coords.
            [xCoords, yCoords] = obj.getKnobCoordinates();
            obj.hSlider = patch(obj.hAxes, xCoords, yCoords, ones(1,3)*0.5);
            obj.hSlider.LineWidth = 1;
            obj.hSlider.FaceColor = obj.KnobFaceColorInactive;
            obj.hSlider.EdgeColor = obj.KnobEdgeColorInactive;
            obj.hSlider.ButtonDownFcn = @(src, event) obj.activateSlider;
            obj.hSlider.Clipping = 'off';
            
            % Create a text object for displaying the current value when
            % the slider is active.
            [xCoords, yCoords] = obj.getTextCoordinates();
            obj.hText = text(obj.hAxes, xCoords, yCoords, '');
            obj.hText.VerticalAlignment = 'Bottom';
            obj.hText.HorizontalAlignment = 'Left';
            obj.hText.Color = obj.TextColor;
            obj.hText.FontSize = obj.FontSize;
            obj.updateValuetipString()
            
            
            % Set visibility of subcomponents.
            obj.hBar.Visible = obj.Visible;
            obj.hSlider.Visible = obj.Visible;
            obj.hBackground.Visible = obj.Visible;
            obj.hText.Visible = 'off';
            
            %Add listener on axes resize
            if obj.hasAxes
                addlistener(obj.hAxes, 'Position', 'PostSet', ...
                    @(s,e) obj.onPositionChanged);
            end
            
        end
        
        function createAxes(obj)
            
            % Create an axes which will be the container for this widget.
            obj.hAxes = axes('Parent', obj.Parent);
            hold(obj.hAxes, 'on');
            obj.hAxes.Visible = 'off';
            obj.hAxes.Units = obj.Units;
            obj.hAxes.Position = obj.Position;
            obj.hAxes.HandleVisibility = 'off';
            obj.hAxes.Tag = 'SlideBar Container';

            obj.hAxes.YLim = [0,1];
            obj.hAxes.XLim = [obj.Min, obj.Max];
            obj.hasAxes = true;
        end
        
        function plotTicks(obj)
            if obj.hasAxes; return; end % Todo....
            
            [x, y] = getTickCoordinates(obj);
            obj.hTicks = plot(obj.hAxes, x, y, '-', 'Color',  obj.BarColor, 'LineWidth', obj.TickWidth);
            
            if obj.IsConstructed
                uistack(obj.hTicks, 'bottom')
            end
        end
        
        function redrawTicks(obj)
            if isempty(obj.hTicks); return; end
            [xCoords, yCoords] = getTickCoordinates(obj);
            numTicks = size(xCoords, 2);
            xCoords = mat2cell(xCoords', ones(numTicks, 1));
            yCoords = mat2cell(yCoords', ones(numTicks, 1));
            set(obj.hTicks, {'XData'}, xCoords, {'YData'}, yCoords)
        end
        
    end
    
    
    methods (Access = private) % Internal updating
        
        function [xCoords, yCoords] = getTextCoordinates(obj)
            if obj.hasAxes
                xCoords = obj.Value;
                yCoords = obj.hAxes.YLim(2) .* 1.4; % Ad hoc offset.
            else
                xCoords = obj.Position(1) + obj.Padding(1) + ...
                    obj.Position(3) .* (obj.Value - obj.Min) ./ (obj.Max - obj.Min);
                yCoords = obj.Position(2) + obj.Position(4) .* 0.9;
            end
        end
        
        function [xCoords, yCoords] = getKnobCoordinates(obj)

            sliderSize = 15;
            theta = linspace(0, 2*pi, 200);

            if obj.hasAxes

                % Get axes size in pixels
                axPosition = getpixelposition(obj.hAxes);

                xrangepx = axPosition(3);
                yrangepx = axPosition(4);            

                % Get axes size in data units.
                xrangedu = range(obj.hAxes.XLim);
                yrangedu = range(obj.hAxes.YLim);

                % Expand axes limits to account for slider moving to the
                % limits..
                obj.hAxes.XLim = [obj.Min, obj.Max] + ...
                            [-1,1] .* xrangedu .* (sliderSize / xrangepx);
% %                 obj.hAxes.YLim = [0, 1] + ...
% %                             [-1, 1] .* yrangedu .* (sliderSize / yrangepx);

                % Get new x-dim axes size in data units.
                xrangedu = range(obj.hAxes.XLim);
                yrangedu = range(obj.hAxes.YLim);
                
                rho = ones(size(theta)).*0.5;
                
                % Calculate radius in x and y of slider handle
                [xCoords, yCoords] = pol2cart(theta, rho);
                xCoords = xCoords .* xrangedu .* (sliderSize / xrangepx);
                yCoords = yCoords .* yrangedu .* (sliderSize / yrangepx);
            
                xCoords = xCoords + obj.Value;
                yCoords = yCoords + 0.5;
                
            else
            	rho = ones(size(theta)) .* 0.5 .* sliderSize;
                [xCoords, yCoords] = pol2cart(theta, rho);
                
                xCoords = xCoords + obj.Position(1) + obj.Padding(1) + ...
                    (obj.Position(3)-sum(obj.Padding([1,3]))) .* (obj.Value - obj.Min) ./ (obj.Max - obj.Min);
                yCoords = yCoords + obj.Position(2) + obj.Position(4)/2;
                
            end




            
            
        end
        
        function [xCoords, yCoords] = getBarCoordinates(obj)
            if obj.hasAxes
                xCoords = [obj.Min; obj.Max];
                yCoords = [0.5; 0.5];
                
                barWidth = 3;
                
                [edgeX, edgeY] = uim.shape.rectangle([obj.Position(3), barWidth], barWidth/2);
                %edgeX = edgeX + obj.Position(1);
                edgeY = edgeY + obj.Position(4)/2 - barWidth/2;
                coords = uim.utility.px2du(obj.hAxes, [edgeX', edgeY']);
                xCoords = coords(:,1)';
                yCoords = coords(:,2)';
                
                
                
            else
                xCoords = [obj.Position(1)+obj.Padding(1); sum(obj.Position([1,3]))-obj.Padding(3)];
                yCoords = ones(2,1) .* obj.Position(2) + obj.Position(4) / 2;
                
                length = obj.Position(3)-sum(obj.Padding([1,3]));
                
                [xCoords, yCoords] = uim.shape.rectangle([length, 3], 1.5);
                xCoords = xCoords + obj.Position(1)+obj.Padding(1);
                yCoords = yCoords + obj.Position(2) + obj.Position(4) / 2 - 1;
            end
        end
        
        function [xCoords, yCoords] = getTickCoordinates(obj)
                
            x1 = obj.Position(1)+obj.Padding(1);
            x2 = sum(obj.Position([1,3]))-obj.Padding(3);
            
            % Correct for linewidth
            x1 = x1+2;
            x2 = x2-2;
            
            y1 = obj.Position(2) + obj.Position(4) / 2;
            y2 = y1 - obj.TickLength;
            
            if strcmp(obj.TickMode, 'both')
               y1 = y1+obj.TickLength/2;
               y2 = y2+obj.TickLength/2;
            elseif strcmp(obj.TickMode, 'over')
                y1 = y1+obj.TickLength;
                y2 = y2+obj.TickLength;
            elseif strcmp(obj.TickMode, 'underx2')
                y1 = y1-obj.TickLength;
                y2 = y2-obj.TickLength;
            end
            
            numTicks = 9;
            xCoords = linspace(x1,x2,numTicks);
            xCoords = repmat(xCoords, 3, 1);
            xCoords(3,:) = nan;
           
            yCoords = repmat([y1;y2;nan], 1, numTicks);
            
            if obj.hasAxes
                coords = uim.utility.px2du(obj.hAxes, [xCoords', yCoords']);
                % Todo:
            end
        end
        
        function [xCoords, yCoords] = getBackgroundCoordinates(obj)
            if obj.hasAxes
                xCoords = obj.hAxes.XLim([1,1,2,2,1]);
                yCoords = obj.hAxes.YLim([2,1,1,2,2]);
            else
                w = obj.Position(3); h = obj.Position(4);
                xCoords = obj.Position(1) + [0, 0, w, w, 0];
                yCoords = obj.Position(2) + [h, 0, 0, h, h];
            end
        end
        
        function updateValuetipString(obj)
            [xCoords, ~] = obj.getTextCoordinates();
            obj.hText.Position(1) = xCoords;
            
            if isempty(obj.TooltipExpression)
                formatStr = sprintf('%%.%df', obj.TooltipPrecision);
                tooltipStr = num2str(obj.Value, formatStr);
                if ~isempty(obj.TooltipUnits)
                    tooltipStr = sprintf('%s %s', tooltipStr, obj.TooltipUnits);
                end
            else
                tooltipStr = sprintf(obj.TooltipExpression, obj.Value);
            end
            
            obj.hText.String = tooltipStr;
            
        end
        
        function onPositionChanged(obj)
            
            if ~obj.IsConstructed; return; end
            
            [xCoords, yCoords] = obj.getTextCoordinates();
            obj.hText.Position(1:2) = [xCoords, yCoords];
            
            [xCoords, yCoords] = getKnobCoordinates(obj);
            set(obj.hSlider, 'XData', xCoords, 'YData', yCoords)
            
            [xCoords, yCoords] = getBarCoordinates(obj);
            set(obj.hBar, 'XData', xCoords, 'YData', yCoords)
            
            [xCoords, yCoords] = getBackgroundCoordinates(obj);
            set(obj.hBackground, 'XData', xCoords, 'YData', yCoords)
           
            if ~isempty(obj.hTicks)
                obj.redrawTicks()
            end
        end
        
        function onVisibleChanged(obj)
            
            obj.hSlider.Visible = obj.Visible;
            obj.hBar.Visible = obj.Visible;
            obj.hBackground.Visible = obj.Visible;
            
            switch obj.Visible
                case 'on'
                    obj.hBackground.PickableParts = 'all';
                case 'off'
                    obj.hBackground.PickableParts = 'none';
            end
        end
        
        function onStyleChanged(obj)
            
            if obj.IsConstructed
                obj.hText.Color = obj.TextColor;
            end
        end
        
        function onTickLengthSet(obj)
            if ~obj.IsConstructed; return; end
                
            if obj.TickLength ~= 0 && isempty(obj.hTicks)
                obj.plotTicks()
            elseif obj.TickLength ~= 0
                obj.redrawTicks()
            end
        end
        
        function onBarColorSet(obj)
            if ~isempty(obj.hBar)
                obj.hBar.FaceColor = newColor;
            end
        end
        
    end
    
    
    methods % Set/Get
    
        function set.Position(obj, newPos)
            obj.Position = newPos;
            
            if ~isempty(obj.hAxes) && obj.hasAxes
                obj.hAxes.Position = newPos;
            end
            
            obj.onPositionChanged();
            
        end

        
        function set.Value(obj, newValue)
            
            if all(obj.isValueInRange(newValue)) && all(newValue ~= obj.Value)
                
                obj.Value = newValue;
                
                if ~isempty(obj.hSlider)                                        %#ok<MCSUP>
                    [xCoords, ~] = obj.getKnobCoordinates();
                    obj.hSlider.XData = xCoords;        %#ok<MCSUP>
                    obj.updateValuetipString()
                    %newValue
                end
            
            end
        end
        
        
        function tf = isValueInRange(obj, newValue)
            
            tf = newValue >= obj.Min & newValue <= obj.Max;
            
        end
        
        
%         function set.Range(obj, newRange)
%             assert(newRange(1) < newRange(2), 'Slider lower limit must be smaller than slider upper limit')
%             obj.Min = newRange(1);
%             obj.Max = newRange(2);
%         end
%         
%         function range = get.Range(obj)
%             range = [obj.Min, obj.Max];
%         end
%         
        
        function set.Min(obj, newMin)
            assert(newMin < obj.Max, 'Slider lower limit must be smaller than slider upper limit')
            obj.Min = newMin;
            
            if ~isempty(obj.hAxes) && obj.hasAxes
                obj.onPositionChanged();
            end
            
        end
        

        function set.Max(obj, newMax)
            assert(newMax > obj.Min, 'Slider upper limit must be larger than slider lower limit')
            obj.Max = newMax;
            
            if ~isempty(obj.hAxes) && obj.hasAxes
                obj.onPositionChanged();
            end
            
        end
        
        
%         function set.Step(obj, newValue)
%             obj.Step = newValue;
%         end
        

        function stepSize = get.Step(obj)
            stepSize = (obj.Max-obj.Min) / obj.nTicks;
        end
        
        function set.TextColor(obj, newValue)
        
            assert(isa(newValue, 'numeric') || isa(newValue, 'char'))
            obj.TextColor = newValue;
            obj.onStyleChanged()

        end
        
        function set.Visible(obj, newValue)
            newValue = validatestring(newValue, {'on', 'off'});
            obj.Visible = newValue;
            obj.onVisibleChanged()
        end
        
        function set.FontSize(obj, newValue)
            if ~isempty(obj.hText)
                obj.hText.FontSize = newValue;
            end
        end
        
        function fontSize = get.FontSize(obj)
            if ~isempty(obj.hText)
                fontSize = obj.hText.FontSize;
            else
                fontSize = nan;
            end
        end
% %         function visible = get.Visible(obj)
% %             if isempty(obj.hBar)
% %                 visible = 'off';
% %             else
% %                 visible = obj.hBar.Visible;
% %             end
% %         end
        

        function set.KnobEdgeColorInactive(obj, newColor)
            if ~isempty(obj.hSlider)
                obj.hSlider.EdgeColor = newColor;
            end
        end
        
        
        function set.KnobFaceColorInactive(obj, newColor)
            if ~isempty(obj.hSlider)
                obj.hSlider.FaceColor = newColor;
            end
        end
        
        function set.BarColor(obj, newColor)
            obj.BarColor = newColor;
            obj.onBarColorSet()
        end
        
        function set.TickLength(obj, newValue)
            assert(isnumeric(newValue), 'TickLength must be a number')
            obj.TickLength = newValue;
            obj.onTickLengthSet()
        end
        
    end
    
    methods % Slider Interaction Callbacks
        
        function activateSlider(obj)
            
            hFigure = ancestor(obj.Parent, 'figure');
            el1 = listener(hFigure, 'WindowMouseRelease', @(s,e) obj.deactivateSlider);
            el2 = listener(hFigure, 'WindowMouseMotion', @obj.moveSlider);
           
            obj.WindowButtonUpListener = el1;
            obj.WindowMouseMotionListener = el2;

            obj.hSlider.FaceColor = obj.KnobFaceColorActive;
            obj.hSlider.EdgeColor = obj.KnobEdgeColorActive;

            if obj.ShowLabel
                obj.hText.Visible = 'on';
            end
            
        end
        
        
        function moveSlider(obj, ~, ~)
            
            % NOTE: The CurrentPoint property only updates on mouse
            % motion if the figure has a value assigned to its 
            % WindowButtonMotionFcn property. This is super weird! And
            % pontially really fucking confusing if the sliderbar is
            % created in a figure without a WindowButtonMotionFcn

            mousePoint = get(obj.hAxes, 'CurrentPoint');

            if obj.hasAxes
                newValue = mousePoint(1);
            else
                newValue = (mousePoint(1) - obj.Position(1) - obj.Padding(1)) / (obj.Position(3)-sum(obj.Padding([1,3]))) .* (obj.Max-obj.Min) + obj.Min;
            end

            % Round to nearest point...
            newValue = round(newValue/obj.Step) * obj.Step;
            
            if ~isequal(newValue, obj.Value)
                obj.valueChangedCallback(newValue)
            end
            
        end
        
        
        function deactivateSlider(obj)

            delete(obj.WindowButtonUpListener)
            delete(obj.WindowMouseMotionListener)
            obj.WindowButtonUpListener = [];
            obj.WindowMouseMotionListener = [];
            
            obj.hSlider.FaceColor = obj.KnobFaceColorInactive;
            obj.hSlider.EdgeColor = obj.KnobEdgeColorInactive;
            
            if obj.ShowLabel
                obj.hText.Visible = 'off';
            end
            
        end
           
        
        function valueChangedCallback(obj, newValue)
            
            if newValue <= obj.Min; newValue = obj.Min; end
            if newValue >= obj.Max; newValue = obj.Max; end
            
            if newValue ~= obj.Value

                obj.Value = newValue;
                
                if ~isempty(obj.Callback)
                    obj.Callback(obj, newValue)
                end
            end
            
        end
        
        function onValueChanging(obj, newValue)
            if newValue <= obj.Min; newValue = obj.Min; end
            if newValue >= obj.Max; newValue = obj.Max; end
            
            if newValue ~= obj.Value
                obj.Value = newValue;

                if ~isempty(obj.Callback)
                    obj.Callback(obj, newValue)
                end
            end
            
        end
        
    end

end