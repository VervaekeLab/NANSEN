classdef ImviewerPlugin < applify.mixin.AppPlugin
%imviewer.AppPlugin Superclass for plugins to the imviewer app

    % Abstract class providing properties and methods that gives plugin
    % functionality for imviewer.
    
    properties
        PrimaryAppName = 'imviewer'     % Name of primary app
    end
    
    properties (Dependent)
        ImviewerObj                     % Alias for PrimaryApp
    end
    
    properties (Access = protected)
        Axes                            % Axes for plotting into
    end
    
    
    methods
        function obj = ImviewerPlugin(h, varargin)
            
            % Make sure the given handle is an instance of imviewer.App 
            assert(isa(h, 'imviewer.App'), 'Input must be an imviewer App')
            
            obj@applify.mixin.AppPlugin(h, varargin{:})
            
            % Assign property values.
            obj.PrimaryApp = h;
            obj.Axes = h.Axes;
            
        end
        
    end
    
    methods 
        function imviewerObj = get.ImviewerObj(obj)
            imviewerObj = obj.PrimaryApp;
        end
    end
    
end