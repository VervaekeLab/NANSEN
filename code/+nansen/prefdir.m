function preferenceDirectory = prefdir()
% preferenceDirectory - Get preference directory for NANSEN user session
    import nansen.internal.user.NansenUserSession
    
    userSession = NansenUserSession.instance('', 'nocreate');
    if isempty(userSession)
        error('NANSEN:NoUserSessionActive', ...
            'No user session is active. Please start nansen and try again.')
    else
        preferenceDirectory = userSession.getPrefdir();
    end
end