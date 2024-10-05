function preferenceDirectory = prefdir()
% preferenceDirectory - Get preference directory for NANSEN user session
    import nansen.internal.user.NansenUserSession
    
    userSession = NansenUserSession.instance('', 'nocreate');
    if isempty(userSession)
        throw(nansen.common.exception.NoUserSessionActive())
    else
        preferenceDirectory = userSession.getPrefdir(userSession.CurrentUserName);
    end
end
