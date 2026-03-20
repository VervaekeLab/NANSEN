function statusResults = checkInstallationStatus(resolvedRequirements)
%checkInstallationStatus Check install state of resolved requirements.
%
%   statusResults = nansen.internal.dependencies.checkInstallationStatus(resolvedRequirements)
%   takes the output of resolveRequirements and populates the IsInstalled
%   field for each entry.
%
%   Input:
%       resolvedRequirements - struct array from readManifest or
%           resolveRequirements.
%
%   Output:
%       statusResults - same struct array with IsInstalled populated:
%           - MathWorks products: checked via ver()
%           - Community toolboxes: checked via InstallCheck field
%             (a function/class name tested with exist())

    arguments
        resolvedRequirements (1,:) struct
    end

    statusResults = resolvedRequirements;

    if isempty(statusResults)
        return
    end

    % Cache installed MathWorks products (call ver() once)
    versionInfo = ver();
    installedProductNames = string({versionInfo.Name});

    for i = 1:numel(statusResults)
        entry = statusResults(i);
        if entry.DependencyType == "mathworks-product"
            statusResults(i).IsInstalled = any(entry.Name == installedProductNames);
        elseif isfield(entry, 'InstallCheck') && strlength(entry.InstallCheck) > 0
            statusResults(i).IsInstalled = ~isempty( which(entry.InstallCheck) );
        else
            statusResults(i).IsInstalled = false;
        end
    end
end
