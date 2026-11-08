function folderPath = getProjectsSessionMethodsDirectory(itemType)
    arguments
        itemType (1,1) string = "Session"
    end
    pm = nansen.ProjectManager();
    project = pm.getCurrentProject();
    folderPath = project.getObjectMethodFolder(itemType, "IncludeModules", false);
    if iscell(folderPath)
        folderPath = folderPath{1};
    end
end
