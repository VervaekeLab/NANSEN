function localDataDirectory = localdatadir()
% localdatadir - Get the machine specific data directory for this user
%
%   localDataDirectory = nansen.localdatadir() returns the directory
%   holding configurations that belong to this machine only, such as task
%   lists, watched folders and local data root paths.
%
%   The user data directory can be a shared or synchronized folder, so
%   these configurations are kept in a subfolder keyed by a machine
%   identifier. Two machines sharing a user data directory would otherwise
%   overwrite each other's configurations.
%
%   See also nansen.userdatadir,
%   nansen.internal.system.getMachineIdentifier

    localDataDirectory = char( fullfile(nansen.userdatadir(), 'local', ...
        nansen.internal.system.getMachineIdentifier()) );
end
