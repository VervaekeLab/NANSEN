function createPlugin(pluginType, varargin)
%createPlugin Create a new NANSEN plugin from a template.
%
%   Syntax:
%     nansen.plugin.createPlugin(pluginType)
%     nansen.plugin.createPlugin(pluginType, Name=Value, ...)
%
%   Input Arguments:
%     pluginType - Plugin type: 'fileadapter', 'action', 'tablevariable',
%                  or 'imviewerplugin'. Type: string
%
%   Name-Value Arguments (forwarded to the type-specific creator):
%     Name      - Plugin/class name. Prompted interactively if omitted.
%     Category  - (action only) Subfolder: 'data','process','analyze','plot'.
%     TableType - (tablevariable only) 'session' or 'subject'.
%
%   Examples:
%     nansen.plugin.createPlugin('action', Name='MyPreprocessing')
%     nansen.plugin.createPlugin('tablevariable', Name='MyVar', TableType='session')
%     nansen.plugin.createPlugin('imviewerplugin', Name='MyPlugin')
%
%   See also: nansen.plugin.createAction, nansen.plugin.createTableVariable,
%             nansen.plugin.createImviewerPlugin, nansen.plugin.createFileAdapter

    arguments
        pluginType (1,1) string
    end
    arguments (Repeating)
        varargin
    end

    switch lower(char(pluginType))
        case {'fileadapter', 'file_adapter'}
            nansen.plugin.createFileAdapter(varargin{:})

        case {'action', 'sessionmethod'}
            nansen.plugin.createAction(varargin{:})

        case {'tablevariable', 'table_variable'}
            nansen.plugin.createTableVariable(varargin{:})

        case {'imviewerplugin', 'imviewer', 'imviewer_plugin'}
            nansen.plugin.createImviewerPlugin(varargin{:})

        otherwise
            error('nansen:plugin:createPlugin:UnknownType', ...
                ['Unknown plugin type "%s". ', ...
                'Valid types: fileadapter, action, tablevariable, imviewerplugin.'], ...
                pluginType)
    end
end
