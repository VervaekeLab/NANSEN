tutorialUserName = "tutorial";

userSession = nansen.internal.user.NansenUserSession.instance('', 'nocreate');
if ~isempty(userSession)
    if strcmp(userSession.CurrentUserName, tutorialUserName)
        nansen.internal.user.NansenUserSession.reset()
    end
end

% Delete projects...
% projectManager = userSession.getProjectManager();
% for i = 1:numel(projectManager.NumProjects)
%     project = projectManager.getProject(i);
% 
% end

% Delete preference directory
userDir = nansen.internal.user.NansenUserSession.getPrefdir(tutorialUserName);
rmdir(userDir, "s")


% % % TEMP: 
% % pm = nansen.ProjectManager;
% % pm.changeProject("abo_ophys")
% % pm.removeProject('nansen_demo', true)