function folderPath = getProjectsSessionMethodsDirectory()
    pm = nansen.ProjectManager();
    project = pm.getCurrentProject();
    folderPath = project.getProjectPackagePath('Session Methods');
end