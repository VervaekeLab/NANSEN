function project = getCurrentProject()
% getCurrentProject - Get the current project.

    userSession = nansen.internal.user.NansenUserSession.instance('', 'nocreate');

    if isempty(userSession)
        error('NANSEN:NoActiveUserSession', 'No user session is active')
    else
        pm = nansen.ProjectManager();
        project = pm.getCurrentProject();
    end
end
