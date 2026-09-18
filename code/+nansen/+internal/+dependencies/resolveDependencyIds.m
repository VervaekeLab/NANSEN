function [dependencies, modulePackageNames] = resolveDependencyIds(dependencyIds)
%resolveDependencyIds - Find community toolbox dependencies by id
%   DEPENDENCIES = resolveDependencyIds(dependencyIds) returns the
%   manifest entry of the community toolbox with each id in
%   dependencyIds, in the same order. It searches the core manifest of
%   NANSEN and the dependencies.nansen.json file of every module on the
%   MATLAB search path, and matches ids without regard to letter case.
%   DEPENDENCIES is a struct array with the fields that readManifest
%   returns.
%
%   [DEPENDENCIES,modulePackageNames] = resolveDependencyIds(...) also
%   returns the package name of the module whose manifest declares each
%   dependency, or "" for a dependency in the core manifest.
%
%   resolveDependencyIds throws an error that lists the available ids if
%   an id is not in any manifest, or if two manifests use the id for
%   different dependencies.
%
%   See also readManifest, listModules, assertInstalled

    arguments
        dependencyIds (1,:) string {mustBeNonzeroLengthText}
    end

    % Ids are lowercase by the manifest schema
    dependencyIds = lower(dependencyIds);

    modules = nansen.internal.dependencies.listModules();
    [availableDependencies, declaringModules] = ...
        collectIdentifiedDependencies(modules);
    if isempty(availableDependencies)
        availableIds = strings(1, 0);
    else
        availableIds = [availableDependencies.Id];
    end

    isKnown = ismember(dependencyIds, availableIds);
    if ~all(isKnown)
        error("NANSEN:Dependencies:UnknownDependency", "%s", ...
            createUnknownIdMessage(dependencyIds(~isKnown), ...
            availableDependencies, declaringModules, modules))
    end

    for i = 1:numel(dependencyIds)
        assertIdIsUnique(dependencyIds(i), availableDependencies, declaringModules)
    end

    % The core manifest is read first, so a dependency that the core and a
    % module both declare resolves to the core entry
    [~, matchIndices] = ismember(dependencyIds, availableIds);
    dependencies = availableDependencies(matchIndices);
    modulePackageNames = declaringModules(matchIndices);
end

function [dependencies, declaringModules] = collectIdentifiedDependencies(modules)
%collectIdentifiedDependencies - Read community toolboxes that have an id
    manifestPaths = string(fullfile(nansen.toolboxdir, "dependencies.nansen.json"));
    manifestOwners = "";
    if ~isempty(modules)
        hasManifest = [modules.ManifestPath] ~= "";
        manifestPaths = [manifestPaths, modules(hasManifest).ManifestPath];
        manifestOwners = [manifestOwners, modules(hasManifest).PackageName];
    end

    dependencyLists = cell(1, numel(manifestPaths));
    ownerLists = cell(1, numel(manifestPaths));
    for i = 1:numel(manifestPaths)
        manifestDependencies = nansen.internal.dependencies.readManifest( ...
            manifestPaths(i));
        % readManifest returns a column; ids are only meaningful for
        % community toolboxes, which are the ones NANSEN can install
        manifestDependencies = reshape(manifestDependencies, 1, []);
        if isempty(manifestDependencies)
            continue
        end
        isIdentified = [manifestDependencies.DependencyType] == "community-toolbox" ...
            & [manifestDependencies.Id] ~= "";
        dependencyLists{i} = manifestDependencies(isIdentified);
        ownerLists{i} = repmat(manifestOwners(i), 1, nnz(isIdentified));
    end

    dependencies = [dependencyLists{:}];
    declaringModules = [ownerLists{:}];
end

function assertIdIsUnique(dependencyId, dependencies, declaringModules)
%assertIdIsUnique - Error if manifests use an id for different dependencies
    isMatch = [dependencies.Id] == dependencyId;
    [dependencyNames, firstIndices] = unique([dependencies(isMatch).Name], "stable");
    if numel(dependencyNames) > 1
        owners = declaringModules(isMatch);
        owners = owners(firstIndices);
        owners(owners == "") = "core";
        error("NANSEN:Dependencies:DuplicateDependencyId", ...
            "The id ""%s"" is used for more than one dependency: %s. " + ...
            "Give each dependency a unique id in its manifest.", ...
            dependencyId, strjoin(dependencyNames + " (" + owners + ")", ", "))
    end
end

function message = createUnknownIdMessage(unknownIds, dependencies, declaringModules, modules)
%createUnknownIdMessage - Describe unknown ids and list the available ones
    quotedIds = strjoin("""" + unknownIds + """", ", ");
    if isscalar(unknownIds)
        message = sprintf("No dependency with the id %s was found.", quotedIds);
    else
        message = sprintf("No dependencies with the ids %s were found.", quotedIds);
    end

    % Passing a module name in place of a dependency id is an easy mistake
    % to make with nansen_install
    for unknownId = unknownIds
        if isModuleName(unknownId, modules)
            message = message + newline + newline + sprintf( ...
                """%s"" is a module. Install the dependencies of a module " + ...
                "with nansen_install(Modules=""%s"").", unknownId, unknownId);
        end
    end

    if isempty(dependencies)
        message = message + newline + newline + ...
            "No dependency ids were found in the manifests on the " + ...
            "MATLAB search path.";
    else
        [availableIds, firstIndices] = unique([dependencies.Id]);
        dependencyNames = [dependencies(firstIndices).Name];
        owners = declaringModules(firstIndices);
        owners(owners == "") = "core";

        idColumn = pad(availableIds);
        message = message + newline + newline + "Available dependency ids:";
        for owner = unique(owners)
            isOwned = owners == owner;
            message = message + newline + "    " + owner + ":" + newline + ...
                strjoin("        " + idColumn(isOwned) + "   " + ...
                dependencyNames(isOwned), newline);
        end
    end

    message = message + newline + newline + ...
        "NANSEN reads dependency ids from its own dependencies.nansen.json " + ...
        "file and from the dependencies.nansen.json file of each module " + ...
        "on the MATLAB search path. If the dependency belongs to a module " + ...
        "that is not on the path, add the module's repository folder with " + ...
        "addpath(genpath(<repository folder>)) and try again.";
end

function tf = isModuleName(name, modules)
%isModuleName - True if a name matches a module on the path
    tf = false;
    if isempty(modules)
        return
    end
    tf = any(strcmpi([modules.PackageName], name) ...
        | strcmpi([modules.Name], name) ...
        | strcmpi([modules.ShortName], name));
end
