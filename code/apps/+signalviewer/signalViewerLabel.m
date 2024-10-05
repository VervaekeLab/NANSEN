classdef signalViewerLabel < handle
    
    properties
        Text = ''
        FontSize = 18
        FontColor = 'k'
        FontName = 'helvetica'
    end
    
    properties (SetAccess = immutable, GetAccess = private)
        Axes
    end

    properties (Access = private)
        TextObject
        AxesSizeListener
        AxesLimitsChangedListener
    end

    methods
        function obj = signalViewerLabel(hAxes, textStr)
            if ~nargin; return; end
            obj.Axes = hAxes;
            obj.Text = textStr;
            obj.plotLabel()
            obj.assignAxesSizeListener()
        end
    end

    methods
        function set.Text(obj, newValue)
            obj.Text = newValue;
            obj.onTextSet()
        end

        function set.FontColor(obj, newValue)
            obj.FontColor = newValue;
            obj.onFontColorSet()
        end
    end

    methods (Access = private)

        function plotLabel(obj)
            [x, y] = obj.getAxesCenterPosition();
            obj.TextObject = text(obj.Axes, x, y, obj.Text);
            obj.TextObject.FontUnits = 'pixels';
            obj.TextObject.FontSize = obj.FontSize;
            obj.TextObject.HorizontalAlignment = 'center';
            obj.TextObject.VerticalAlignment = 'middle';
            obj.TextObject.Color = obj.FontColor;
            obj.TextObject.Tag = 'Signalviewer Axes Label';
        end
        
        function [x, y] = getAxesCenterPosition(obj)
            x = obj.Axes.XLim(1) + (obj.Axes.XLim(2)-obj.Axes.XLim(1))/2;
            y = obj.Axes.YLim(1) + (obj.Axes.YLim(2)-obj.Axes.YLim(1))*0.75;
        end

        function assignAxesSizeListener(obj)
            obj.AxesSizeListener = listener(obj.Axes, 'SizeChanged', ...
                @(s, e) obj.onAxesSizeChanged);
            
            props = {'XLim', 'YLim'};
            obj.AxesLimitsChangedListener = listener(obj.Axes, props, ...
                'PostSet', @(s, e) obj.onAxesLimitsChanged);
        end
    end

    methods (Access = private)

        function onTextSet(obj)
            if ~isempty(obj.TextObject)
                obj.TextObject.String = obj.Text;
            end
        end

        function onFontColorSet(obj)
            if ~isempty(obj.TextObject)
                obj.TextObject.Color = obj.FontColor;
            end
        end

        function onAxesSizeChanged(obj)
            obj.updateTextPosition()
        end

        function onAxesLimitsChanged(obj)
            obj.updateTextPosition()
        end

        function updateTextPosition(obj)
            [x, y] = obj.getAxesCenterPosition();
            obj.TextObject.Position(1:2) = [x, y];
        end
    end
end
