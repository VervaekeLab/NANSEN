function statusResults = checkInstallationStatus(resolvedRequirements, trackedAddons)
%checkInstallationStatus Check install and path state of resolved requirements.
%
%   statusResults = nansen.internal.dependencies.checkInstallationStatus(resolvedRequirements)
%   populates the IsInstalled and IsOnPath fields for each dependency.
%
%   statusResults = nansen.internal.dependencies.checkInstallationStatus( ...
%       resolvedRequirements, trackedAddons)
%   uses tracked addon records from AddonManager for richer status checks.
%
%   Input:
%       resolvedRequirements - struct array from readManifest or
%           resolveRequirements.
%       trackedAddons - optional AddonManager addon records.
%
%   Output:
%       statusResults - same struct array with fields populated:
%           - IsInstalled: dependency is installed/tracked
%           - IsOnPath: dependency is available on MATLAB's search path

    arguments
        resolvedRequirements (1,:) struct
        trackedAddons (1,:) struct = struct.empty(1, 0)
    end

    statusResults = resolvedRequirements;

    if isempty(statusResults)
        return
    end

    versionInfo = ver();
    installedProductNames = string({versionInfo.Name});
    installedAddonTable = getInstalledAddonsTable();

    for i = 1:numel(statusResults)
        entry = statusResults(i);
        trackedEntry = getTrackedAddonEntry(entry, trackedAddons);

        if entry.DependencyType == "mathworks-product"
            isInstalled = any(entry.Name == installedProductNames);
            isOnPath = isInstalled;
        else
            isOnPath = isDependencyOnPath(entry);
            if isTrackedAddonSetupIncomplete(entry, trackedEntry)
                isInstalled = false;
            else
                isInstalled = isOnPath || ...
                    isTrackedAddonInstalled(trackedEntry, installedAddonTable);
            end
        end

        statusResults(i).IsInstalled = isInstalled;
        statusResults(i).IsOnPath = isOnPath;
    end
end

function tf = isDependencyOnPath(entry)
%isDependencyOnPath Check if a dependency is available in the current session.
    tf = false;
    if isfield(entry, 'InstallCheck') && strlength(string(entry.InstallCheck)) > 0
        checkName = char(entry.InstallCheck);
        try
            answer = which(checkName);
        catch ME
            warning('NANSEN:Dependencies:InstallCheckFailed', ...
                'Failed to evaluate InstallCheck "%s": %s', checkName, ME.message)
            return
        end

        if isempty(answer) || strcmp(answer, 'Not on MATLAB path')
            tf = false;
        elseif isfile(answer)
            tf = true;
        else
            % Our install check should be pointing to a file
            tf = false;
            warning('NANSEN:Dependencies:InstallCheckUnexpectedWhichOutput', ...
                'InstallCheck "%s" resolved to unexpected output: %s', ...
                checkName, answer)
        end
    end
end

function trackedEntry = getTrackedAddonEntry(entry, trackedAddons)
%getTrackedAddonEntry Find a matching tracked addon entry by dependency name.
    trackedEntry = struct.empty(1, 0);

    if isempty(trackedAddons) || ~isfield(entry, 'Name') || ~isfield(trackedAddons, 'Name')
        return
    end

    trackedNames = string({trackedAddons.Name});
    matchIndex = find(trackedNames == string(entry.Name), 1, 'first');
    if ~isempty(matchIndex)
        trackedEntry = trackedAddons(matchIndex);
    end
end

function tf = isTrackedAddonSetupIncomplete(entry, trackedEntry)
%isTrackedAddonSetupIncomplete Check whether setup must be retried.
    tf = false;
    if isempty(trackedEntry) || ~isfield(entry, 'SetupHook') || ...
            strlength(string(entry.SetupHook)) == 0
        return
    end

    setupStatus = string(getStructFieldOrDefault( ...
        trackedEntry, 'SetupStatus', ""));
    tf = any(setupStatus == ["", "pending", "failed"]);
end

function tf = isTrackedAddonInstalled(trackedEntry, installedAddonTable)
%isTrackedAddonInstalled Determine whether a tracked addon is installed.
    tf = false;
    if isempty(trackedEntry)
        return
    end

    installationType = string(getStructFieldOrDefault(trackedEntry, 'InstallationType', ""));
    filePath = string(getStructFieldOrDefault(trackedEntry, 'FilePath', ""));
    addonName = string(getStructFieldOrDefault(trackedEntry, 'Name', ""));
    toolboxIdentifier = string(getStructFieldOrDefault(trackedEntry, 'ToolboxIdentifier', ""));

    switch installationType
        case "folder"
            tf = strlength(filePath) > 0 && isfolder(filePath);
        case "mltbx"
            tf = isInstalledToolboxAddon(addonName, toolboxIdentifier, installedAddonTable);
        otherwise
            if strlength(filePath) > 0
                tf = isfolder(filePath);
            elseif strlength(toolboxIdentifier) > 0 || strlength(addonName) > 0
                tf = isInstalledToolboxAddon(addonName, toolboxIdentifier, installedAddonTable);
            elseif isfield(trackedEntry, 'IsInstalled')
                tf = logical(trackedEntry.IsInstalled);
            end
    end
end

function tf = isInstalledToolboxAddon(addonName, toolboxIdentifier, installedAddonTable)
%isInstalledToolboxAddon Check if an addon is installed through MATLAB's addon system.
    tf = false;
    if isempty(installedAddonTable)
        return
    end

    variableNames = string(installedAddonTable.Properties.VariableNames);
    if strlength(toolboxIdentifier) > 0 && ismember("Identifier", variableNames)
        tf = any(string(installedAddonTable.Identifier) == toolboxIdentifier);
    elseif strlength(addonName) > 0 && ismember("Name", variableNames)
        tf = any(string(installedAddonTable.Name) == addonName);
    end
end

function addonsTable = getInstalledAddonsTable()
%getInstalledAddonsTable Return installed MATLAB addons or an empty table.
    try
        addonsTable = matlab.addons.installedAddons();
    catch
        addonsTable = table();
    end
end

function value = getStructFieldOrDefault(S, fieldName, defaultValue)
%getStructFieldOrDefault Read struct field if present, otherwise return default.
    if isfield(S, fieldName)
        value = S.(fieldName);
    else
        value = defaultValue;
    end
end
