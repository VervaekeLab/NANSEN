classdef Registry
%Registry Facade for type-specific plugin registries.
%
%   The type-specific registries own discovery and compatibility behavior.
%   This facade gives callers one stable entry point when the plugin type is
%   decided at runtime.

    methods (Static)

        function registry = getInstance(pluginType, forceRefresh)
        %getInstance Return registry instance for a plugin type.
            if nargin < 2
                forceRefresh = false;
            end

            switch lower(pluginType)
                case {'fileadapter', 'file-adapter', 'file_adapter'}
                    registry = nansen.plugin.fileadapter.Registry.getInstance(forceRefresh);

                case {'action', 'entitymethod', 'entity-method', ...
                        'sessionmethod', 'session-method'}
                    registry = nansen.plugin.action.Registry.getInstance(forceRefresh);

                case {'tablevariable', 'table-variable', 'table_variable'}
                    registry = nansen.plugin.tablevariable.Registry.getInstance(forceRefresh);

                case {'module', 'pluginmodule', 'plugin-module'}
                    registry = nansen.plugin.module.Registry.getInstance(forceRefresh);

                otherwise
                    error('Nansen:PluginRegistry:UnknownPluginType', ...
                        'Unknown plugin type "%s".', pluginType)
            end
        end

        function specs = list(pluginType, varargin)
        %list Return specs for a plugin type.
            registry = nansen.plugin.Registry.getInstance(pluginType);
            specs = registry.list(varargin{:});
        end

        function report = validate(pluginType)
        %validate Return discovery issues for a plugin type.
            registry = nansen.plugin.Registry.getInstance(pluginType);
            report = registry.validate();
        end

    end

end
