classdef ContainerCanvas < uim.handle
    
    
    properties (SetAccess = private, Transient)
        Parent = []                 % Parent handle (figure/uifigure)
        Axes = []                   % Handle to the axes which components are plotted in
        Position (1,4) double = [0,0,1,1] % Position within the parent. 
        Units = 'pixels'            % Units for position property
        Children = []               % List of uicomponents
        Tag = 'Widget Canvas'       % A tag which is also applied to the axes.
    end
    
    methods 
        function obj = ContainerCanvas()
            
        end
    end
    
    
    methods %Set/Get
        function set.Position(obj, newPosition)

        end
    end
    
    methods
        function onPositionChanged(obj)
            obj.Axes.Position = obj.Position;
            obj.Axes.YLim = [1, obj.Position(4)];
            obj.Axes.XLim = [1, obj.Position(3)]; 
        end
    end
    
    
    
end