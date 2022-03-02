function projectManager = ProjectManager()
%nansen.ProjectManager Interface for managing projects
%
%   The purpose of this class is to simplify the process of listing
%   projects, adding new projects and changing the current project.

    if ~nargout
        nansen.config.project.ProjectManagerApp()
    else
        projectManager = nansen.config.project.ProjectManager();
    end

end