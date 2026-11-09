function restart()
    currentUserProfile = nansen.internal.user.NansenUserSession.instance('', 'nocreate');
    profileName = currentUserProfile.CurrentUserName;

    % The app stays open when the user decides against quitting, for
    % example with tasks running, and it needs its session then.
    nansen.App.quit()
    if nansen.App.isOpen(); return; end

    nansen.quit();
    nansen(profileName)
end
