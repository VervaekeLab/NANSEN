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
    
    
    methods % Constructor
        
        function obj = ImviewerPlugin(h, varargin)
            
            % Make sure the given handle is an instance of imviewer.App 
            assert(isa(h, 'imviewer.App'), 'Input must be an imviewer App')
            
            isSecondArgOptions = isa(varargin{1}, 'struct') || ...
                isa(varargin{1}, 'nansen.manage.OptionsManager');

            if nargin > 2 && isSecondArgOptions
                opts = varargin{1}; varargin(1) = []; 
            else
                opts = [];
            end

            obj@applify.mixin.AppPlugin(h, opts, varargin{:})
            
            % Assign property values.
            obj.PrimaryApp = h;
            obj.Axes = h.Axes;
            
            obj.assignDataIoModel() % todo: superclass?
            
        end
        
    end
    
    methods 
        
        function assignDataIoModel(obj)
            return % Under construction
            if isempty(obj.DataIoModel)
                folderPath = fileparts( obj.ImviewerObj.ImageStack.FileName );
                obj.DataIoModel = nansen.dataio.DataIoModel(folderPath);
            end            
        end
        
        function imviewerObj = get.ImviewerObj(obj)
            imviewerObj = obj.PrimaryApp;
        end
        
    end
    
    methods (Access = protected)
        
        function showImageInImviewer(obj, image, imageName)
            obj.PrimaryApp.showExternalImage(image, imageName)
        end
        
        function setImviewerUpdateFunction(obj, fcnHandle)
            obj.PrimaryApp.ImageProcessingFcn = fcnHandle;
        end
        
        function updateImviewerDisplay(obj)
            obj.PrimaryApp.updateImage()
            obj.PrimaryApp.updateImageDisplay()
        end
    end
    
end