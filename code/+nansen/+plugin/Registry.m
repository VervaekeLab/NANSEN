classdef Registry
%Registry Facade for per-type plugin registries.
%
%   Provides a single entry point when the plugin type is chosen at runtime.
%   Dispatches to the appropriate concrete registry using the PluginType enum.
%
%   Usage:
%     registry = nansen.plugin.Registry.getInstance( ...
%         nansen.plugin.enum.PluginType.FileAdapter)
%
%   Note: concrete registry instantiation is wired in as each plugin type
%   is implemented (Phases 2–5). Until then, unsupported types raise an error.

    methods (Static)

        function registry = getInstance(pluginType, projectFolder)
        %getInstance Return the registry for a given plugin type.
        %
        %   pluginType  — nansen.plugin.enum.PluginType value
        %   projectFolder — (optional) project root path; defaults to ""
        %
        %   Note: the persistent-per-process pattern used here is a placeholder.
        %   Per-project lifecycle (reset on project switch) is introduced when
        %   the project manager is wired in.
            arguments
                pluginType    (1,1) nansen.plugin.enum.PluginType
                projectFolder (1,1) string = ""
            end

            switch pluginType
                case nansen.plugin.enum.PluginType.FileAdapter
                    registry = nansen.plugin.fileadapter.Registry.getInstance( ...
                        projectFolder);

                case nansen.plugin.enum.PluginType.Action
                    registry = nansen.plugin.action.Registry.getInstance( ...
                        projectFolder);

                case nansen.plugin.enum.PluginType.TableVariable
                    registry = nansen.plugin.tablevariable.Registry.getInstance( ...
                        projectFolder);

                case nansen.plugin.enum.PluginType.ImviewerPlugin
                    registry = nansen.plugin.imviewer.Registry.getInstance( ...
                        projectFolder);

                otherwise
                    error('nansen:plugin:Registry:UnknownPluginType', ...
                        'No registry registered for plugin type "%s".', ...
                        char(pluginType))
            end
        end

        function specs = list(pluginType, varargin)
        %list Return specs for a plugin type.
            arguments
                pluginType (1,1) nansen.plugin.enum.PluginType
            end
            arguments (Repeating)
                varargin
            end
            registry = nansen.plugin.Registry.getInstance(pluginType);
            specs    = registry.list(varargin{:});
        end

        function issues = validate(pluginType)
        %validate Return discovery issues for a plugin type.
            arguments
                pluginType (1,1) nansen.plugin.enum.PluginType
            end
            registry = nansen.plugin.Registry.getInstance(pluginType);
            issues   = registry.validate();
        end
    end
end
