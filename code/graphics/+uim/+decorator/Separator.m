classdef Separator < uim.abstract.Control
%Separator A decorator for separating groups of controls in a widget.

    % Todo:
    %   [ ] Should there be a list of allowed parents?
    %   [ ] Generalize Height... I.e what if separator is horizontal. Also,
    %       should it be relative units?
    %   [ ] Subclass from Decorator instead of Control
    
    properties (Constant)
        Type = 'Separator'
    end
    
    properties
        Color = ones(1,3) * 0.5
        LineWidth = 1
        Height = 0.8 % Fraction of toolbar height (0,1)
    end
    
    properties (Access = protected, Transient)
        hSeparator
    end

    methods
        function obj = Separator(varargin)

            obj@uim.abstract.Control(varargin{:})
            
            %delete(obj.hBackground);
            obj.hBackground.Visible = 'off';
            obj.plotSeparator()
            
            %obj.Tag = 'Toolbar Separator';

            obj.IsConstructed = true;
            obj.onVisibleChanged()

        end
    end
    
    methods (Access = private)
        function plotSeparator(obj)
            
            [X, Y] = obj.getPlotData();
            
            h = plot(obj.CanvasAxes, X, Y);

            h.HitTest = 'off';
            h.PickableParts = 'none';
            
            h.Color = obj.Color;
            h.LineWidth = obj.LineWidth;

            obj.hSeparator = h;
        end
        
        function [X, Y] = getPlotData(obj)
            [x1, x2] = deal(obj.Position(1));
            
            yMean = obj.Position(2) + obj.Position(4)/2;
            
            y1 = yMean - (obj.Position(4)*obj.Height)/2;
            y2 = yMean + (obj.Position(4)*obj.Height)/2;
            
%             y1 = obj.Position(2);
%             y2 = sum(obj.Position([2,4]));
            
            X = [x1, x2];
            Y = [y1, y2];
        end
    end
    
    methods
        function relocate(obj, ~)
            if obj.IsConstructed
                [X, Y] = obj.getPlotData();
                set(obj.hSeparator, 'XData', X, 'YData', Y)
            end
        end
        
        function resize(obj)
            if obj.IsConstructed
                [X, Y] = obj.getPlotData();
                set(obj.hSeparator, 'XData', X, 'YData', Y)
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
                    obj.hSeparator.Visible = 'on';
                case 'off'
                    obj.hSeparator.Visible = 'off';
            end
        end
    end
end
