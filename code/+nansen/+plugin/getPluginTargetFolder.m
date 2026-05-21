function targetFolder = getPluginTargetFolder(pluginType, location)
%getPluginTargetFolder Return the target folder for saving a new plugin.
%
%   Syntax:
%     targetFolder = nansen.plugin.getPluginTargetFolder(pluginType)
%     targetFolder = nansen.plugin.getPluginTargetFolder(pluginType, location)
%
%   Input Arguments:
%     pluginType - One of: 'fileadapter', 'action', 'tablevariable'. Type: string
%     location   - 'project' (default) or 'user'. Type: string
%
%   Output Arguments:
%     targetFolder - Absolute path to the folder where the plugin should be saved.
%
%   See also: nansen.plugin.createPlugin

    arguments
        pluginType (1,1) string
        location   (1,1) string {mustBeMember(location, ["project", "user"])} = "project"
    end

    if location == "project"
        try
            currentProject = nansen.getCurrentProject();
        catch
            currentProject = [];
        end

        if isempty(currentProject)
            error('nansen:plugin:getPluginTargetFolder:NoProject', ...
                'No active project found. Open a project before creating a plugin.')
        end

        switch lower(char(pluginType))
            case 'fileadapter'
                targetFolder = currentProject.getFileAdapterFolder();

            case {'action', 'sessionmethod'}
                % Return the project's own session method folder (first path).
                folderPaths = currentProject.getObjectMethodFolder( ...
                    'Session', 'IncludeModules', false);
                targetFolder = folderPaths{1};

            case {'tablevariable', 'table_variable'}
                targetFolder = currentProject.getTableVariableFolder();

            otherwise
                error('nansen:plugin:getPluginTargetFolder:UnsupportedType', ...
                    ['Plugin type "%s" is not supported. ', ...
                    'Supported types: fileadapter, action, tablevariable.'], pluginType)
        end

    else % user
        targetFolder = getUserPluginPath_(pluginType);
    end
end

function targetFolder = getUserPluginPath_(pluginType)
    targetFolder = fullfile(userpath, 'NANSEN', 'plugins', char(pluginType));
end
