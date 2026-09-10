function localDataDirectory = localdatadir(userDataDirectory)
% localdatadir - Get the machine specific data directory for this user
%
%   localDataDirectory = nansen.localdatadir() returns the directory
%   holding configurations that belong to this machine only, such as task
%   lists, watched folders and local data root paths.
%
%   localDataDirectory = nansen.localdatadir(userDataDirectory) returns
%   the machine specific directory within the given user data directory,
%   for callers that hold one and must not depend on the active session.
%
%   The user data directory can be a shared or synchronized folder, so
%   these configurations are kept in a subfolder keyed by a machine
%   identifier. Two machines sharing a user data directory would otherwise
%   overwrite each other's configurations.
%
%   See also nansen.userdatadir,
%   nansen.internal.system.getMachineIdentifier

    arguments
        userDataDirectory (1,1) string = ""
    end

    if strlength(userDataDirectory) == 0
        userDataDirectory = nansen.userdatadir();
    end

    localDataDirectory = char( fullfile(userDataDirectory, 'local', ...
        nansen.internal.system.getMachineIdentifier()) );
end
