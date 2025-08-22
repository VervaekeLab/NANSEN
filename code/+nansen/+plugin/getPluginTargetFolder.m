function targetFolder = getPluginTargetFolder(pluginType, location)

    arguments
        pluginType (1,1) string
        location (1,1) string {mustBeMember(location, ["project", "user"])} = "project"
    end

    if location == "project"
        try
            currentProject = nansen.getCurrentProject();
        catch
            currentProject = [];
        end
    
        if isempty(currentProject)
            error('Need a project to save plugins to.')
            targetFolder = getUserPluginPath(pluginType);
            warning('No project found, saving plugin to user location: \n%s', targetFolder)
        else
            if strcmp(pluginType, 'fileadapter')
                targetFolder = currentProject.getFileAdapterFolder();
            else
                error('Not implemented yet')
            end
        end

    else % user
        error('Not implemented yet')
        targetFolder = getUserPluginPath(pluginType);
    end
end

function targetFolder = getUserPluginPath(pluginType)
    targetFolder = fullfile(userpath, 'NANSEN', 'plugins', pluginType);
end
