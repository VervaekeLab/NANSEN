function assertInstalled(dependencyId)
%assertInstalled - Throw an error if a dependency is not on the search path
%   assertInstalled(dependencyId) checks that the community toolbox with
%   the id dependencyId is on the MATLAB search path, using the
%   installCheck of its manifest entry. If the toolbox is not on the path,
%   assertInstalled throws an error that tells the user to run
%   nansen_install with the id. Call it before code that needs the
%   toolbox, so that a missing toolbox fails early with that instruction.
%
%   Example: Check for Flow Registration before motion correction
%       nansen.internal.dependencies.assertInstalled("flowreg")
%
%   See also resolveDependencyIds, checkInstallationStatus, nansen_install

    arguments
        dependencyId (1,1) string {mustBeNonzeroLengthText}
    end

    dependency = nansen.internal.dependencies.resolveDependencyIds(dependencyId);

    % Without an installCheck NANSEN cannot see the toolbox on the path,
    % and the error below would ask for an installation that cannot fix it
    if dependency.InstallCheck == ""
        error("NANSEN:Dependencies:MissingInstallCheck", ...
            "The manifest entry for %s has no installCheck, so NANSEN " + ...
            "cannot check whether it is installed. Add an installCheck " + ...
            "to the entry with the id ""%s"".", dependency.Name, dependency.Id)
    end

    dependencyStatus = nansen.internal.dependencies.checkInstallationStatus(dependency);
    if ~dependencyStatus.IsOnPath
        error("NANSEN:Dependencies:NotInstalled", ...
            "%s is required for this operation, but it was not found on " + ...
            "the MATLAB search path. Install it and add it to the path " + ...
            "by running:" + newline + newline + "    nansen_install(""%s"")", ...
            dependency.Name, dependency.Id)
    end
end
