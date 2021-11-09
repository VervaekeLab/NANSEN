classdef Container < uim.abstract.Component
%Container A container for placing other components within.    
%
%   This container is virtual...
%
%   Todo: implement so that it can live in its own canvas.


    properties (Abstract, SetAccess = protected, Transient)
        Children uim.abstract.Component
    end
    
    
    methods
        function obj = Container(varargin)
        	obj@uim.abstract.Component(varargin{:})
        end
    end
    
    
    methods (Access = protected)
        
        function assignComponentCanvas(obj)
            switch obj.CanvasMode
                case 'shared'
                    assignComponentCanvas@uim.abstract.Component(obj)
                case 'private'
                    obj.createPrivateCanvas()
            end
            
        end
        
        function createPrivateCanvas(obj)
            
            % Create an axes which will be the container for this widget.
            obj.hAxes = axes('Parent', obj.Parent);
            hold(obj.hAxes, 'on');
            obj.hAxes.Visible = 'off';
            obj.hAxes.Units = 'pixel';         
            obj.hAxes.HandleVisibility = 'off';
            obj.hAxes.Tag = sprintf('%s Widget Canvas', obj.Type);
            
            axis(obj.hAxes, 'equal')

            if ~any(isnan(obj.Position))
                obj.hAxes.Position = obj.Position;
                obj.hAxes.YLim = [1, obj.Position(4)];
                obj.hAxes.XLim = [1, obj.Position(3)];
            end
            
            obj.Canvas = obj.hAxes;

        end
        
        function onChildAdded(obj, newChild)
            
        end
        
        
        function onChildRemoved(obj, removedChild)
            
        end
        
        function moveChildren(obj)
            
        end
        
        function resizeChildren(obj)
            
        end
        
    end
    
end