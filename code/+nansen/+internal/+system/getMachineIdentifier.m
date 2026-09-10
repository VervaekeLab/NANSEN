function machineIdentifier = getMachineIdentifier()
%getMachineIdentifier Get an identifier for the current machine
%
%   machineIdentifier = getMachineIdentifier() returns a stable, filename
%   safe identifier for the machine NANSEN is running on. It is used to
%   keep machine specific configurations apart when a user data directory
%   is shared between machines.
%
%   This is the identifier the data location model uses as its SourceID,
%   so a project shared between machines resolves its local configurations
%   and its local data root paths by one key.
%
%   The identifier is cached, because resolving it queries the operating
%   system and it is needed on every local path lookup.
%
%   See also nansen.localdatadir, utility.system.getComputerName

    persistent cachedIdentifier

    if isempty(cachedIdentifier)
        cachedIdentifier = string( utility.system.getComputerName(true) );
    end

    machineIdentifier = cachedIdentifier;
end
