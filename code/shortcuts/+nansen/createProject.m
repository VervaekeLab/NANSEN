function createProject(flags)
    arguments (Repeating)
        flags (1,1) string {mustBeMember(flags, ["d", "dependencies", "v", "variables"])}
    end
    % Make sure we don't have a current project selection
    pm = nansen.ProjectManager();
    message = pm.changeProject(''); %#ok<NASGU> % Captures message. Todo: Make verbose option instead
    
    nansen.configureProject(flags{:}, "CreateNew", true)
end
