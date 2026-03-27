classdef AppBridgePlugin < applify.mixin.AppPlugin
%AppBridgePlugin Base for plugins that bridge to another app/controller
%
%   Bridge plugins coordinate another app or controller, but do not own a
%   method-options workflow and do not need persistent plugin settings by
%   default. This class supplies the inert UserSettings contract required
%   by AppPlugin so bridge plugins do not need to implement settings
%   boilerplate unless they truly have plugin-specific preferences.

    properties (Constant, Hidden = true)
        USE_DEFAULT_SETTINGS = true
        DEFAULT_SETTINGS = struct.empty
    end

    methods (Access = protected)

        function onSettingsChanged(obj, name, value) %#ok<INUSD,MANU>
        % Bridge plugins do not react to settings by default.
        end

    end
end
