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
%       the projectmanager for use on the commandline or in scripts.
%
%   See also nansen.config.project.ProjectManager

    if ~nargout
        % Todo: consider giving projectManager instance as input to app: 
        nansen.config.project.ProjectManagerApp()
    else
        userSession = nansen.internal.user.NansenUserSession.instance();
        projectManager = userSession.getProjectManager();    
    end
end
