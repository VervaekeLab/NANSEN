function restart()
    currentUserProfile = nansen.internal.user.NansenUserSession.instance('', 'nocreate');
    profileName = currentUserProfile.CurrentUserName;
    nansen.quit();
    nansen(profileName)
end
