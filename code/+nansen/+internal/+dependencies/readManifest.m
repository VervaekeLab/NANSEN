function dependencies = readManifest(manifestFilePath)
%readManifest Parse a dependencies.nansen.json manifest file.
%
%   dependencies = nansen.internal.dependencies.readManifest(manifestFilePath)
%   reads the manifest at the given path and returns a struct array of
%   dependency entries, validated against the schema.
%
%   Input:
%       manifestFilePath (1,1) string - Absolute path to a
%           dependencies.nansen.json file.
%
%   Output:
%       dependencies - struct array where each element has all schema
%           fields. Missing optional fields are filled with defaults.
%
%   Errors:
%       Throws if the file does not exist, is not valid JSON, or if
%       required fields (name, dependencyType, requirementLevel) are
%       missing from any entry.

    arguments
        manifestFilePath (1,1) string {mustBeFile} = fullfile(nansen.toolboxdir, 'dependencies.nansen.json')
    end

    jsonText = fileread(manifestFilePath);
    manifestData = jsondecode(jsonText);

    validateManifestStructure(manifestData);

    manifestScope = string(manifestData.scope);
    manifestScopeId = string(manifestData.scopeId);

    rawDependencies = manifestData.dependencies;
    if isstruct(rawDependencies)
        numDependencies = numel(rawDependencies);
    else
        numDependencies = length(rawDependencies);
    end

    dependencies = repmat(getDefaultEntry(), numDependencies, 1);

    for i = 1:numDependencies
        if iscell(rawDependencies)
            entry = rawDependencies{i};
        else
            entry = rawDependencies(i);
        end
        dependencies(i) = populateEntry(entry, manifestScope, manifestScopeId);
    end
end

function validateManifestStructure(manifestData)
%validateManifestStructure Verify top-level manifest fields exist.
    manifestFields = string(fieldnames(manifestData));
    % jsondecode mangles leading underscores, so _schema_version becomes
    % x_schema_version in the resulting struct.
    requiredPayloadFields = ["scope", "scopeId", "dependencies"];
    hasPayloadFields = all(ismember(requiredPayloadFields, manifestFields));
    hasVersionField = ismember("x_schema_version", manifestFields);
    if ~hasPayloadFields || ~hasVersionField
        error("NANSEN:Dependencies:InvalidManifest", ...
            "Manifest is missing required top-level fields.");
    end
end

function entry = populateEntry(rawEntry, manifestScope, manifestScopeId)
%populateEntry Convert a raw JSON entry to a normalized dependency struct.
    entry = getDefaultEntry();

    % Required fields
    requiredFields = ["name", "dependencyType", "requirementLevel"];
    entryFields = string(fieldnames(rawEntry));
    missingFields = setdiff(requiredFields, entryFields);
    if ~isempty(missingFields)
        entryName = "(unknown)";
        if ismember("name", entryFields)
            entryName = rawEntry.name;
        end
        error("NANSEN:Dependencies:InvalidEntry", ...
            "Dependency entry '%s' is missing required fields: %s", ...
            entryName, strjoin(missingFields, ", "));
    end

    % Map all camelCase JSON fields to PascalCase struct fields
    defaultFieldNames = string(fieldnames(entry));
    for j = 1:numel(entryFields)
        pascalName = camelToPascal(entryFields(j));
        if ismember(pascalName, defaultFieldNames) && isfield(rawEntry, entryFields(j))
            entry.(pascalName) = string(rawEntry.(entryFields(j)));
        end
    end

    % Scope: inherit from manifest if not overridden at entry level
    if ~ismember("scope", entryFields)
        entry.Scope = manifestScope;
    end
    if ~ismember("scopeId", entryFields)
        entry.ScopeId = manifestScopeId;
    end
end

function pascalName = camelToPascal(camelName)
%camelToPascal Convert camelCase to PascalCase by uppercasing the first letter.
    camelName = char(camelName);
    pascalName = string([upper(camelName(1)), camelName(2:end)]);
end

function entry = getDefaultEntry()
%getDefaultEntry Return a dependency struct with all fields set to defaults.
    entry = struct( ...
        'Name', "", ...
        'DependencyType', "", ...
        'Scope', "", ...
        'ScopeId', "", ...
        'RequirementLevel', "", ...
        'Source', "", ...
        'DocsSource', "", ...
        'Description', "", ...
        'Reason', "", ...
        'WorkflowNotes', "", ...
        'SetupHook', "", ...
        'StartupHook', "", ...
        'InstallCheck', "", ...
        'VersionConstraint', "" ...
    );
end
