classdef ImviewerPlugin < applify.mixin.AppPlugin
    
    % Abstract class providing properties and methods that gives plugin
    % functionality for imviewer.
    
    
    properties
        PrimaryAppName = 'imviewer'
    end
    
    
    properties (Access = protected)
        Axes
    end
    
    
    methods
        function obj = ImviewerPlugin(h)
            
            assert(isa(h, 'imviewer.App'), 'Input must be an imviewer App')
            
            obj.PrimaryApp = h;
            
            obj.Axes = h.Axes;
            
        end
        
    end
end