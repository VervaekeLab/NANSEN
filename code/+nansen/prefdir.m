function preferenceDirectory = prefdir()
% preferenceDirectory - Get preference directory for NANSEN user session
    import nansen.internal.user.NansenUserSession
    
    userSession = NansenUserSession.instance('', 'nocreate');
    if isempty(userSession)
        preferenceDirectory = NansenUserSession.getPrefdir('anon_user');
        %throw(nansen.common.exception.NoUserSessionActive())
    else
        preferenceDirectory = userSession.getPrefdir(userSession.CurrentUserName);
    end
end
