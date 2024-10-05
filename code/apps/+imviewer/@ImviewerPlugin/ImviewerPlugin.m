classdef ImviewerPlugin < applify.mixin.AppPlugin
%imviewer.AppPlugin Superclass for plugins to the imviewer app

    % Abstract class providing properties and methods that gives plugin
    % functionality for imviewer.

    properties
        PrimaryAppName = 'imviewer'     % Name of primary app
    end
    
    properties (Dependent)
        ImviewerObj                     % Alias for PrimaryApp % Rename to ImviewerApp
    end
    
    properties (GetAccess = protected, SetAccess = private)
        Axes                            % Axes for plotting into
        %PointerManager
    end

    properties (Dependent, SetAccess = private)
        NumFrames
        NumChannels
        NumPlanes
    end

    properties (Access = private)
        CurrentFrameChangedListener event.listener
        CurrentChannelChangedListener event.listener
        CurrentPlaneChangedListener event.listener
    end

    methods % Constructor
        
        function obj = ImviewerPlugin(varargin)
            
            % Make sure the given handle is an instance of imviewer.App
            [h, varargin] = imviewer.ImviewerPlugin.checkForImviewerInArgList(varargin);
            obj@applify.mixin.AppPlugin(h, varargin{:})
            
            if isempty(h); return; end

            % Assign property values.
            obj.PrimaryApp = h;
            obj.Axes = h.Axes;

            obj.onImviewerSet()

            obj.assignDataIoModel() % todo: superclass? Should belong to a
            % data method class, not a plugin.
            % So a plugin that runs a method should inherit the imviewer
            % plugin and the datamethod...
        end
    end

    methods %Set/get methods
        
        function numChannels = get.NumChannels(obj)
            numChannels = obj.ImviewerObj.ImageStack.NumChannels;
        end
      
        function numPlanes = get.NumPlanes(obj)
            numPlanes = obj.ImviewerObj.ImageStack.NumPlanes;
        end
    end
    
    methods
        
        function assignDataIoModel(obj)
            return % Under construction. Todo: Move to another class
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

    methods (Access = protected) % Consider private
        
        function onPluginActivated(obj)
        %onPluginActivated Run subroutines when plugin is activated.
            onPluginActivated@applify.mixin.AppPlugin(obj)

            assert(isa(obj.PrimaryApp, 'imviewer.App'), ...
                ['Can not activate plugin because the parent app has to be' ...
                'an instance of imviewer.App'])
            
            obj.Axes = obj.PrimaryApp.Axes;
            obj.onImviewerSet()
        end

        function onImviewerSet(obj)
            obj.resetImviewerListeners()
            obj.createImviewerListeners()
        end
    end

    methods (Access = protected) % Listener callbacks

        function onCurrentChannelChanged(obj)
            % Subclasses can implement
        end

        function onCurrentPlaneChanged(obj)
            % Subclasses can implement
        end
    
        function onCurrentFrameChanged(obj)
            % Subclasses can implement
        end
    end

    methods (Access = private)

        function createImviewerListeners(obj)
        %createImviewerListeners Create listeners for events in imviewer

            obj.CurrentFrameChangedListener = listener( ...
                obj.ImviewerObj, 'currentFrameNo', 'PostSet', ...
                @(s, e) obj.onCurrentFrameChanged );

            obj.CurrentChannelChangedListener = listener( ...
                obj.ImviewerObj, 'currentChannel', 'PostSet', ...
                @(s, e) obj.onCurrentChannelChanged );

            obj.CurrentPlaneChangedListener = listener( ...
                obj.ImviewerObj, 'currentPlane', 'PostSet', ...
                @(s, e) obj.onCurrentPlaneChanged );
        end
        
        function resetImviewerListeners(obj)
        %resetImviewerListeners Reset listeners if they are active

            obj.resetListener( obj.CurrentFrameChangedListener )
            obj.CurrentFrameChangedListener = event.listener.empty;
            
            obj.resetListener( obj.CurrentChannelChangedListener )
            obj.CurrentChannelChangedListener = event.listener.empty;
            
            obj.resetListener( obj.CurrentPlaneChangedListener )
            obj.CurrentPlaneChangedListener = event.listener.empty;
        end

        function resetListener(~, listenerHandle)
            isdeletable = @(x) ~isempty(x) & isvalid(x);
            
            if isdeletable( listenerHandle )
                delete( listenerHandle )
            end
        end
    end

    methods (Static)

        function [h, arglist] = checkForImviewerInArgList(arglist)

            if isa(arglist{1}, 'imviewer.App')
                h = arglist{1};
                arglist(1) = [];
            else
                h = [];
            end
        end
    end
end
