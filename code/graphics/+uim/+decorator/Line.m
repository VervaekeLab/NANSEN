classdef Line < uim.abstract.Control
%Separator A decorator for separating groups of controls in a widget.

    % Todo:
    %   [ ] Should there be a list of allowed parents?
    %   [ ] Generalize Height... I.e what if separator is horizontal. Also,
    %       should it be relative units?
    %   [ ] Subclass from Decorator instead of Control
    
    properties (Constant)
        Type = 'Line'
    end
    
    properties
        XData
        YData
    end
    
    properties
        Color = ones(1,3) * 0.5
        LineWidth = 0.5
    end
    
    properties (Access = protected, Transient)
        hLine
    end

    methods
        function obj = Line(varargin)

            obj@uim.abstract.Control(varargin{:})
            
            %delete(obj.hBackground);
            obj.hBackground.Visible = 'off';
            obj.plotLine()
            
            %obj.Tag = 'Toolbar Separator';

            obj.IsConstructed = true;
            obj.onVisibleChanged()

        end
    end
    
    methods (Access = private)
        function plotLine(obj)
            
            [X, Y] = obj.getPlotData();
            
            h = plot(obj.CanvasAxes, X, Y);

            h.HitTest = 'off';
            h.PickableParts = 'none';
            h.Clipping = 'off';
            
            h.Color = obj.Color;
            h.LineWidth = obj.LineWidth;

            obj.hLine = h;
        end
        
        function [X, Y] = getPlotData(obj)
            if isempty(obj.XData)
                X = [obj.Position(1), obj.Position(3)];
            else
                X = obj.XData;
            end

            if isempty(obj.YData)
                Y = [obj.Position(2), obj.Position(4)];
            else
                Y = obj.YData;
            end
        end
    end
    
    methods
        function relocate(obj, ~)
            if obj.IsConstructed
                [X, Y] = obj.getPlotData();
                set(obj.hLine, 'XData', X, 'YData', Y)
            end
        end
        
        function resize(obj)
            if obj.IsConstructed
                [X, Y] = obj.getPlotData();
                set(obj.hLine, 'XData', X, 'YData', Y)
            end
        end
    end
    
    methods
        function updateLocation(obj, ~)
            if obj.IsConstructed
                
            end
        end
    end
    
    methods (Hidden, Access = protected)
        function onVisibleChanged(obj, ~)
            switch obj.Visible
                case 'on'
                    obj.hLine.Visible = 'on';
                case 'off'
                    obj.hLine.Visible = 'off';
            end
        end
    end
end
