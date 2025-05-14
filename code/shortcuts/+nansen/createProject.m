function createProject(flags)
    arguments (Repeating)
        flags (1,1) string {mustBeMember(flags, ["d", "dependencies", "v", "variables"])}
    end
    % Make sure we don't have a current project selection
    pm = nansen.ProjectManager();
    pm.changeProject('', "Verbose", false);
    
    nansen.configureProject(flags{:}, "CreateNew", true)
end
