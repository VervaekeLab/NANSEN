classdef ImviewerPlugin < applify.mixin.AppPlugin
%imviewer.AppPlugin

    % Abstract class providing properties and methods that gives plugin
    % functionality for imviewer.
    
    properties
        PrimaryAppName = 'imviewer'     % Name of primary app
    end
    
    
    properties (Access = protected)
        Axes                            % Axes for plotting into
    end
    
    
    methods
        function obj = ImviewerPlugin(h)
            
            % Make sure the given handle is an instance of imviewer.App 
            assert(isa(h, 'imviewer.App'), 'Input must be an imviewer App')
            
            % Assign property values.
            obj.PrimaryApp = h;
            
            obj.Axes = h.Axes;
            
        end
        
    end
end