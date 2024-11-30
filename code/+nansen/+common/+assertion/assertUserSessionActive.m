function assertUserSessionActive()
    userSession = nansen.internal.user.NansenUserSession.instance('', 'nocreate');
    exception = nansen.common.exception.NoUserSessionActive();
    assert(~isempty(userSession), exception.identifier, exception.message)
end