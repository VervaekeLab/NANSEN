classdef AppPlugin < matlab.mixin.Heterogeneous & uiw.mixin.AssignPVPairs
%AppPlugin Abstract superclass for an app plugin
%
%   Syntax:
%       hPlugin = AppPlugin(hApp) creates a plugin instance for the given
%       app reference
%
%       hPlugin = AppPlugin(hApp, flags) specifies flags to set
%       mode of plugin.
%           Flags:
%               '-p' : create plugin using partial construction, i.e
%                      create, but do not open the control panel
%
%        hPlugin = AppPlugin(hApp, property, value, ...) specifies property,
%        value pairs to be set on construction
%

    % Plugins can:
    %   - implement mouse/keyboard callbacks invoked by the host app
    %   - add items to the app menu
    %   - opt into method options through a dedicated options mixin
    %
    % matlab.mixin.Heterogeneous allows AppWithPlugin.Plugins to hold an
    % array of mixed AppPlugin subclass instances.

    properties (Abstract, Constant)
        Name
    end

    properties (SetAccess = protected)
        PartialConstruction = false % Do a partial construction, i.e skip the opening of options editor on construction
    end

    properties
        DataIoModel         % Store a data i/o model object if it is provided.
    end

    properties
        PrimaryApp          % App which is primary "owner" of the plugin. Should be typed
        MenuItem struct     % Struct for storing menu handles
    end

    properties (Access = protected)
        IsActivated = false;
    end

    methods % Constructor

        function obj = AppPlugin(hApp, varargin)

            if nargin > 2
                obj.parseVarargin(varargin{1:end})
            end

            if ~nargin || isempty(hApp); return; end

            obj.validateAppHandle(hApp)

            % If this plugin is already active, return the existing instance
            % rather than creating a duplicate.
            if hApp.isPluginActive(obj)
                warning('applify:AppPlugin:alreadyActive', ...
                    'Plugin "%s" is already active. Returning existing instance.', obj.Name)
                obj = hApp.getPluginHandle(obj.Name);
                return
            end

            obj.activatePlugin(hApp);

            if ~nargout; clear obj; end

        end

        function delete(obj)
            % Delete menu items
            if ~isempty(obj.MenuItem)
                structfun(@delete, obj.MenuItem)
            end
        end
    end

    methods (Access = public)

        function run(obj) %#ok<MANU>
            % Subclasses may override
        end
    end

    % Methods for mouse and keyboard interactive callbacks
    methods (Access = {?applify.mixin.AppPlugin, ?applify.AppWithPlugin})

        function tf = keyPressHandler(obj, src, evt) %#ok<INUSD> Subclass can override
            tf = false;
        end

        function tf = keyReleasedHandler(obj, src, evt) %#ok<INUSD> Subclass can override
            tf = false;
        end

    end

    methods

        function activatePlugin(obj, appHandle)
            obj.PrimaryApp = appHandle;
            obj.PrimaryApp.addPlugin(obj)
            obj.onPluginActivated()
            obj.IsActivated = true;
        end

    end

    methods (Access = protected)

        function setFigureTitle(obj)
            if isprop(obj.PrimaryApp, 'Figure')
                obj.PrimaryApp.Figure.Name = obj.Name;
            else
                warning('Could not set figure title')
            end
        end

        function onPluginActivated(obj)
        %onPluginActivated Run subroutines when plugin is activated.
            obj.createSubMenu()
        end

        function parseVarargin(obj, varargin)
        %parseVarargin Parser for varargin that are passed on construction
            if isempty(varargin); return; end

            % Look for flag of whether to open plugin's options panel on construction
            if ischar(varargin{1}) && isequal(varargin{1}, '-p')
                obj.PartialConstruction = true;
                varargin(1) = [];
            end
            if isempty(varargin); return; end

            obj.assignPVPairs(varargin{:})
        end

        function createSubMenu(obj) %#ok<MANU>
            % Subclasses may override
        end

        function menuHandle = findAppContextMenu(obj)
            if isprop(obj.PrimaryApp, 'hContextMenu')
                menuHandle = obj.PrimaryApp.hContextMenu;
            else
                menuHandle = findobj(obj.PrimaryApp.Figure, 'Tag', 'App Context Menu');
            end
        end
    end

    methods (Access = private)

        function validateAppHandle(obj, hApp)
        %validateAppHandle Check validity of app handle
            if ~isa(hApp, 'applify.AppWithPlugin')
                error('Can not add plugin "%s" to app of type %s', ...
                    obj.Name, class(hApp))
            end
        end
    end
end
