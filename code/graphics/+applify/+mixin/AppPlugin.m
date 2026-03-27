classdef AppPlugin < applify.mixin.UserSettings & matlab.mixin.Heterogeneous & uiw.mixin.AssignPVPairs
%AppPlugin Abstract superclass for an app plugin
%
%   Syntax:
%       hPlugin = AppPlugin(hApp) creates a plugin instance for the given
%       app reference
%
%       hPlugin = AppPlugin(hApp, options) additionally provides options to
%       use. Options can be a struct or an OptionsManager object.
%
%       hPlugin = AppPlugin(hApp, options, flags) specifies flags to set
%       mode of plugin.
%           Flags:
%               '-p' : create plugin using partial construction, i.e
%                      create, but do not open the control panel
%
%        hPlugin = AppPlugin(hApp, options, property, value, ...) specifies
%        property, value pairs to be set on construction
%

    % Plugins can:
    %   - implement mouse/keyboard callbacks invoked by the host app
    %   - add items to the app menu
    %   - hold user settings via UserSettings (persistent preferences)
    %   - hold method options via HasOptionsManager (algorithm parameters)
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
        OptionsManager      % Store optionsmanager handle if plugin is provided with an optionsmanager on construction
    end

    properties
        PrimaryApp          % App which is primary "owner" of the plugin.
        MenuItem struct     % Struct for storing menu handles
        Icon
    end

    properties (Access = protected)
        IsActivated = false;
    end

    methods % Constructor

        function obj = AppPlugin(hApp, varargin)

            [options, varargin] = applify.mixin.AppPlugin.optionsCheck(varargin);

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

            % Assign options from input if provided
            if nargin >= 2 && ~isempty(options)
                obj.assignOptions(options)
            else
                obj.assignDefaultOptions()
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

        function onPluginActivated(obj)
        %onPluginActivated Run subroutines when plugin is activated.
            obj.createSubMenu()
        end

        function parseVarargin(obj, varargin)
        %parseVarargin Parser for varargin that are passed on construction
            % Look for flag of whether to open plugin's options panel on construction
            if ischar(varargin{1}) && isequal(varargin{1}, '-p')
                obj.PartialConstruction = true;
                varargin(1) = [];
            end
            obj.assignPVPairs(varargin{:})
        end

        function assignOptions(obj, options)
        %assignOptions Assign non default options for plugin
        %
        %   options can be a struct or an OptionsManager object
            if isa(options, 'struct')
                obj.settings = options;
            elseif isa(options, 'nansen.manage.OptionsManager')
                obj.OptionsManager = options;
                obj.settings = obj.OptionsManager.Options;
            end
        end

        function assignDefaultOptions(obj) %#ok<MANU>
        %assignDefaultOptions Assign default options. Subclasses may override.
        end

        function createSubMenu(obj) %#ok<MANU>
            % Subclasses may override
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

    methods (Static)

        function [opts, cellOfArgs] = optionsCheck(cellOfArgs)
            opts = [];
            if numel(cellOfArgs) >= 1
                containsOpts = isa(cellOfArgs{1}, 'struct') || ...
                    isa(cellOfArgs{1}, 'nansen.manage.OptionsManager');
                if containsOpts
                    opts = cellOfArgs{1}; cellOfArgs(1) = [];
                end
            end
        end
    end
end
