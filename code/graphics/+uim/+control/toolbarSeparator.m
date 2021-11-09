classdef toolbarSeparator < uim.abstract.virtualContainer & uim.mixin.assignProperties

    % todo: is this a virtualContainer....???
    
    
    properties
        Color = ones(1,3) * 0.5
        LineWidth = 1
        Height = 0.8 % Fraction of toolbar height (0,1)
    end
    
    
    properties (Access = protected, Transient)
        hSeparator
    end
    

    methods
        function obj = toolbarSeparator(varargin)
            if isa(varargin{1}, 'uim.widget.toolbar') || isa(varargin{1}, 'uim.widget.wtoolbar')
                obj.Parent = varargin{1};
                obj.Canvas = obj.Parent.Canvas;
                varargin = varargin(2:end);
            else
                error('UIM:Invalid parent for toolbar separator')
            end
            
            obj.parseInputs(varargin{:})
            obj.plotSeparator()
            obj.Tag = 'Toolbar Separator';
            obj.Visible = obj.Parent.Visible;

            obj.IsConstructed = true;
        end
    end
    
    methods (Access = private)
        function plotSeparator(obj)
            
            [X, Y] = obj.getPlotData();
            
            if isa(obj.Canvas, 'matlab.graphics.axis.Axes')
                h = plot(obj.Canvas, X, Y);
            else
                h = plot(obj.Canvas.Axes, X, Y);
            end
            h.Color = obj.Color;
            h.LineWidth = obj.LineWidth;
            h.HitTest = 'off';
            h.PickableParts = 'none';
        
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