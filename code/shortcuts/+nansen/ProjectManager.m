function projectManager = ProjectManager()
%nansen.ProjectManager Interface for managing projects
%
%   This is a function for accessing NANSEN's project manager, where
%   projects can be listed, added and removed.
%
%   USAGE:
%       nansen.ProjectManager() will open an app for managing projects
%
%       PM = nansen.ProjectManager() will return an instance (singleton) of
%       the projectmanager for working with on the commandline or in
%       scripts
%
%   See also nansen.config.project.ProjectManager

    if ~nargout
        nansen.config.project.ProjectManagerApp()
    else
        projectManager = nansen.config.project.ProjectManager.instance();
    end

end