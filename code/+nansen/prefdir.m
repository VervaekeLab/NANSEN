function preferenceDirectory = prefdir()
    %userSession = nansen.internal.user.NansenUserSession.instance();
    %preferenceDirectory = userSession.getPrefdir();
    %todo: remove this:
    preferenceDirectory = fullfile(nansen.rootpath, '_userdata');
end