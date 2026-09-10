function userDataDirectory = userdatadir()
% userdatadir - Get the user data directory for the NANSEN user session
%
%   userDataDirectory = nansen.userdatadir() returns the directory that
%   holds the project catalog and the configurations belonging to the
%   current user.
%
%   Unlike nansen.prefdir, this location does not belong to a MATLAB
%   release. It is the UserDataDirectory preference when one is set, and a
%   default location under MATLAB's userpath otherwise.
%
%   See also nansen.prefdir,
%   nansen.internal.user.NansenUserSession/getUserDataDirectory

    import nansen.internal.user.NansenUserSession

    userSession = NansenUserSession.instance('', 'nocreate');
    if isempty(userSession)
        userDataDirectory = NansenUserSession.getUserDataDirectory('anon_user');
    else
        userDataDirectory = NansenUserSession.getUserDataDirectory(userSession.CurrentUserName);
    end
end
