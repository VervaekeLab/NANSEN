function resolvedRequirements = resolveRequirements(options)
%resolveRequirements Aggregate, deduplicate and check dependencies.
%
%   resolvedRequirements = nansen.internal.dependencies.resolveRequirements()
%   returns the full resolved requirement set for core NANSEN.
%
%   resolvedRequirements = nansen.internal.dependencies.resolveRequirements(Name, Value)
%   accepts filtering options.
%
%   Name-Value Arguments:
%       IncludeCore (logical) - Include core dependencies. Default: true.
%       SelectedModules (string array) - Module package names to include.
%       SelectedWorkflows (string array) - Workflow ScopeIds to include.
%       DependencyTypes (string array) - Filter by DependencyType.
%           Empty means all types.
%       RequirementLevels (string array) - Filter by RequirementLevel.
%           Empty means all levels.
%       MissingOnly (logical) - Return only missing dependencies.
%           Default: false.
%       TrackedAddons (struct array) - Optional tracked addon records from
%           AddonManager. Used for richer install/path status checks.
%       ManifestPaths (string array) - Explicit manifest file paths.
%           When provided, skips automatic manifest discovery and uses
%           only the given paths. Useful for testing.
%
%   Output:
%       resolvedRequirements - struct array with all schema fields plus:
%           .IsInstalled (logical) - whether the dependency is tracked as
%               installed or otherwise known to be present
%           .IsOnPath (logical) - whether the dependency is currently
%               available on MATLAB's search path

    arguments
        options.IncludeCore (1,1) logical = true
        options.SelectedModules (1,:) string = string.empty
        options.SelectedWorkflows (1,:) string = string.empty
        options.DependencyTypes (1,:) string = string.empty
        options.RequirementLevels (1,:) string = string.empty
        options.MissingOnly (1,1) logical = false
        options.TrackedAddons (1,:) struct = struct.empty(1, 0)
        options.ManifestPaths (1,:) string = string.empty
    end

    if isempty(options.ManifestPaths)
        manifestPaths = collectManifestPaths(options.IncludeCore, options.SelectedModules);
    else
        manifestPaths = options.ManifestPaths;
    end
    allDependencies = readAllDependencies(manifestPaths);

    % Filter by scope inclusion
    allDependencies = filterByScope(allDependencies, ...
        options.IncludeCore, options.SelectedModules, options.SelectedWorkflows);

    % Deduplicate
    resolvedRequirements = deduplicateDependencies(allDependencies);

    % Check installation status
    resolvedRequirements = nansen.internal.dependencies.checkInstallationStatus( ...
        resolvedRequirements, options.TrackedAddons);

    % Apply filters
    resolvedRequirements = applyFilters(resolvedRequirements, ...
        options.DependencyTypes, options.RequirementLevels, options.MissingOnly);
end

function manifestPaths = collectManifestPaths(includeCore, selectedModules)
%collectManifestPaths Get manifest file paths from core and selected modules.
    manifestPaths = string.empty(1, 0);

    if includeCore
        coreManifestPath = fullfile(nansen.toolboxdir, 'dependencies.nansen.json');
        if isfile(coreManifestPath)
            manifestPaths(end+1) = string(coreManifestPath);
        end
    end

    % Module manifests
    if ~isempty(selectedModules)

        for i = 1:numel(selectedModules)
            
            currentModulePath = utility.path.packagename2pathstr(selectedModules(i));
            
            moduleInfo = what(currentModulePath);
            if isempty(moduleInfo)
                warning('NANSEN:Dependencies:ModuleNotFound', ...
                    'No module with name "%s" on MATLAB''s search path', selectedModules(i))
                continue
            elseif numel(moduleInfo) > 1
                warning('NANSEN:Dependencies:MultipleModulesFound', ...
                    'Multiple modules with name "%s" was found on MATLAB''s search path', selectedModules(i))
            end
            currentModuleManifestPath = fullfile(moduleInfo(1).path, 'dependencies.nansen.json');
            if isfile(currentModuleManifestPath)
                manifestPaths = [manifestPaths, currentModuleManifestPath]; %#ok<AGROW>
            end
        end
    end

    manifestPaths = unique(manifestPaths, "stable");
end

function allDependencies = readAllDependencies(manifestPaths)
%readAllDependencies Read and concatenate dependencies from all manifests.
    allDependencies = struct([]);
    for i = 1:numel(manifestPaths)
        if ~isfile(manifestPaths(i)); continue; end
        dependencies = nansen.internal.dependencies.readManifest(manifestPaths(i));
        for j = 1:numel(dependencies)
            if isempty(allDependencies)
                allDependencies = dependencies(j);
            else
                allDependencies(end+1) = dependencies(j); %#ok<AGROW>
            end
        end
    end
end

function dependencies = filterByScope(dependencies, includeCore, selectedModules, selectedWorkflows)
%filterByScope Keep only dependencies matching the requested scopes.
    if isempty(dependencies)
        return
    end
    keepMask = false(1, numel(dependencies));
    for i = 1:numel(dependencies)
        switch dependencies(i).Scope
            case "core"
                keepMask(i) = includeCore;
            case "module"
                keepMask(i) = ~isempty(selectedModules) && ...
                    any(dependencies(i).ScopeId == selectedModules);
            case "workflow"
                keepMask(i) = ~isempty(selectedWorkflows) && ...
                    any(dependencies(i).ScopeId == selectedWorkflows);
        end
    end
    dependencies = dependencies(keepMask);
end

function resolved = deduplicateDependencies(dependencies)
%deduplicateDependencies Merge duplicate entries across scopes.
%   Entries with the same Name + DependencyType are merged. When merging:
%   - "required" wins over "optional"
%   - Reason and WorkflowNotes are concatenated (unique values only)
    if isempty(dependencies)
        resolved = dependencies;
        return
    end

    numDependencies = numel(dependencies);
    keys = strings(1, numDependencies);
    for i = 1:numDependencies
        keys(i) = dependencies(i).Name + "|" + dependencies(i).DependencyType;
    end

    [~, ~, groupIndices] = unique(keys, 'stable');
    numUnique = max(groupIndices);
    resolved = repmat(dependencies(1), 1, numUnique);

    for i = 1:numUnique
        groupEntries = dependencies(groupIndices' == i);
        merged = groupEntries(1);
        for j = 2:numel(groupEntries)
            other = groupEntries(j);
            if other.RequirementLevel == "required"
                merged.RequirementLevel = "required";
            end
            merged.Reason = mergeStringField(merged.Reason, other.Reason);
            merged.WorkflowNotes = mergeStringField(merged.WorkflowNotes, other.WorkflowNotes);
            merged = preferNonEmpty(merged, other, "Source");
            merged = preferNonEmpty(merged, other, "DocsSource");
            merged = preferNonEmpty(merged, other, "Description");
            merged = preferNonEmpty(merged, other, "SetupHook");
            merged = preferNonEmpty(merged, other, "StartupHook");
            merged = preferNonEmpty(merged, other, "InstallCheck");
        end
        resolved(i) = merged;
    end
end

function result = mergeStringField(existing, incoming)
%mergeStringField Concatenate two string values, keeping only unique parts.
    if existing == "" && incoming == ""
        result = "";
    elseif existing == ""
        result = incoming;
    elseif incoming == "" || existing == incoming
        result = existing;
    else
        result = existing + "; " + incoming;
    end
end

function merged = preferNonEmpty(merged, other, fieldName)
%preferNonEmpty Use the other entry's value if the merged entry's is empty.
    if merged.(fieldName) == "" && other.(fieldName) ~= ""
        merged.(fieldName) = other.(fieldName);
    end
end

function dependencies = applyFilters(dependencies, dependencyTypes, requirementLevels, missingOnly)
%applyFilters Filter resolved dependencies by type, level, and install state.
    if isempty(dependencies)
        return
    end
    keepMask = true(1, numel(dependencies));
    if ~isempty(dependencyTypes)
        for i = 1:numel(dependencies)
            if ~any(dependencies(i).DependencyType == dependencyTypes)
                keepMask(i) = false;
            end
        end
    end
    if ~isempty(requirementLevels)
        for i = 1:numel(dependencies)
            if ~any(dependencies(i).RequirementLevel == requirementLevels)
                keepMask(i) = false;
            end
        end
    end
    if missingOnly
        for i = 1:numel(dependencies)
            if dependencies(i).IsInstalled
                keepMask(i) = false;
            end
        end
    end
    dependencies = dependencies(keepMask);
end
