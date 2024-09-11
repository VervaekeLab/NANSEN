function project = createProject(projectName, projectDescription, projectFolder)
    
    arguments
        projectName (1,1) string
        projectDescription (1,1) string
        projectFolder (1,1) string
    end
    
    project = nansen.config.project.Project.new(projectName, projectDescription, projectFolder);
end