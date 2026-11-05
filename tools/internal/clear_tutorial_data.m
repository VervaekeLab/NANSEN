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

% The tutorial profile keeps its preferences in the preference directory of
% this MATLAB release, and its catalog and configurations in its user data
% directory under the userpath. Without a userpath the two are the same.
preferenceDirectory = nansen.internal.user.NansenUserSession.getPrefdir(tutorialUserName);
userDataDirectory = nansen.internal.user.NansenUserSession.getDefaultUserDataDirectory(tutorialUserName);

if isfolder(userDataDirectory) && ~nansen.util.path.isSamePath(userDataDirectory, preferenceDirectory)
    rmdir(userDataDirectory, "s")
end

if isfolder(preferenceDirectory)
    rmdir(preferenceDirectory, "s")
end


% % % TEMP: 
% % pm = nansen.ProjectManager;
% % pm.changeProject("abo_ophys")
% % pm.removeProject('nansen_demo', true)