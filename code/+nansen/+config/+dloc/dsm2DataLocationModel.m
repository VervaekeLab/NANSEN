function [dataLocations, variables, report] = dsm2DataLocationModel(dsmConfig, options)
%dsm2DataLocationModel Convert a Dataset Structure Model to NANSEN data locations and variables
%
%   Syntax:
%       [dataLocations, variables, report] = ...
%           nansen.config.dloc.dsm2DataLocationModel(dsmConfig)
%
%       [...] = nansen.config.dloc.dsm2DataLocationModel(dsmConfig, ...
%           SessionEntity=name, SubjectEntity=name)
%
%   Converts what a NANSEN project can represent and reports the rest. A
%   Dataset Structure Model describes any number of entity types with any
%   metadata. NANSEN has sessions and subjects, and four metadata
%   variables: Subject ID, Session ID, Experiment Date and Experiment Time.
%
%   Which entity becomes a NANSEN session:
%       an entity type named session with a layout level, otherwise the
%       entity type of the deepest layout level. A NANSEN session has to be
%       found on disk, so it must be an entity with a folder or files.
%   Which entity becomes a NANSEN subject:
%       an entity type named subject, otherwise the source of a
%       relationship whose target is the session entity.
%
%   Input arguments:
%       dsmConfig - Path to a Dataset Structure Model json file, or its
%                   decoded struct. Validate it first (dsm validate).
%       options.SessionEntity - Entity type to use as the NANSEN session.
%       options.SubjectEntity - Entity type to use as the NANSEN subject.
%
%   Output arguments:
%       dataLocations - Struct array of data location model items.
%       variables     - Struct array of variable model items.
%       report        - Table of the model elements that were not mapped,
%                       or were mapped approximately, with the reason.
%
%   See also nansen.config.dloc.DataLocationModel,
%   nansen.config.varmodel.VariableModel

    arguments
        dsmConfig
        options.SessionEntity (1,1) string = missing
        options.SubjectEntity (1,1) string = missing
    end

    import nansen.config.dloc.dsmconversion.*

    if ischar(dsmConfig) || isstring(dsmConfig)
        dsmConfig = jsondecode(fileread(dsmConfig));
    end

    report = Report();

    entityTypes = asList(dsmConfig, 'entityTypes');
    definitions = getOr(dsmConfig, 'metadataDefinitions', struct());
    locations = asList(dsmConfig, 'dataLocations');

    sessionEntity = options.SessionEntity;
    if ismissing(sessionEntity)
        sessionEntity = chooseSessionEntity(entityTypes, locations);
    end
    subjectEntity = options.SubjectEntity;
    if ismissing(subjectEntity)
        subjectEntity = chooseSubjectEntity(entityTypes, asList(dsmConfig, 'entityRelationships'), sessionEntity);
    end

    sessionKeys = identityKeys(entityTypes, sessionEntity);
    subjectKeys = identityKeys(entityTypes, subjectEntity);
    usedFields = string.empty(1, 0);

    report.add("entityRelationships", "NANSEN has no relationships between entity types beyond subject and session.", ...
        ~isempty(asList(dsmConfig, 'entityRelationships')))
    for i = 1:numel(entityTypes)
        name = string(entityTypes{i}.name);
        if ~ismember(name, [sessionEntity, subjectEntity])
            report.add("entityTypes[" + name + "]", "Only the session and subject entity types have a NANSEN counterpart.")
        end
    end
    report.add("preferences", "Preferences belong to the data location model, not to its items; set DefaultDataLocation after importing.", ...
        isfield(dsmConfig, 'preferences'))

    dataLocations = struct.empty;
    variables = struct.empty;

    for i = 1:numel(locations)
        location = locations{i};
        where = "dataLocations[" + string(location.identifier) + "]";

        if string(getOr(location, 'sourceType', 'filesystem')) ~= "filesystem"
            report.add(where, "Only filesystem data locations can be converted.")
            continue
        end

        [item, sessionLevel, usedHere, levelsBelowSession] = convertLocation(location, where, definitions, ...
            sessionEntity, subjectEntity, sessionKeys, subjectKeys, report);
        if isempty(item)
            continue
        end
        usedFields = [usedFields, usedHere]; %#ok<AGROW>

        dataLocations = appendItems(dataLocations, item);
        variables = appendItems(variables, convertFilePatterns(sessionLevel, item, where, ...
            [sessionKeys, subjectKeys], report));
        variables = appendItems(variables, convertFilePatternsBelowSession(levelsBelowSession, ...
            item, where, [sessionKeys, subjectKeys], report));
    end
    variables = qualifyRepeatedVariableNames(variables, report);

    for fieldName = string(fieldnames(definitions))'
        if ~ismember(fieldName, usedFields)
            report.add("metadataDefinitions[" + fieldName + "]", ...
                "NANSEN extracts only Subject ID, Session ID, Experiment Date and Experiment Time.")
        end
    end

    report = report.toTable();
end

% -------------------------------------------------------------------------

function [item, sessionLevel, usedFields, levelsBelowSession] = convertLocation(location, where, definitions, ...
        sessionEntity, subjectEntity, sessionKeys, subjectKeys, report)
%convertLocation Convert one filesystem data location
%
%   levelsBelowSession are the layout levels under the session level. NANSEN
%   walks folders down to the session only; convertFilePatternsBelowSession
%   finds the files below it that a variable can still point to.

    item = [];
    sessionLevel = [];
    usedFields = string.empty(1, 0);
    levelsBelowSession = {};
    source = location.filesystemSource;
    layout = asList(source, 'entityLayout');

    levelTypes = fieldValues(layout, 'entityType');
    sessionIndex = find(levelTypes == sessionEntity, 1);
    if isempty(sessionIndex)
        report.add(where, "No layout level holds the session entity '" + sessionEntity + "', so NANSEN could not find sessions here.")
        return
    end
    levelsBelowSession = layout(sessionIndex+1:end);
    layout = layout(1:sessionIndex);
    sessionLevel = layout{end};

    item = nansen.config.dloc.DataLocationModel.getBlankItem();
    item.Name = char(matlab.lang.makeValidName(string(location.identifier)));
    report.add(where + ".identifier", "Renamed to '" + item.Name + "' to be a valid MATLAB name.", ...
        ~strcmp(item.Name, location.identifier))
    % A placeholder that links variables to this item until it is inserted;
    % inserting an item into a catalog assigns it a new uuid.
    item.Uuid = nansen.util.getuuid();
    report.add(where + ".uuid", "NANSEN assigns its own uuid when a data location is added; the model's uuid is not kept.", ...
        isfield(location, 'uuid'))
    item = orderfields(item, ['Uuid'; setdiff(fieldnames(item), 'Uuid', 'stable')]);
    item.Type = convertType(location, where, report);
    item.RootPath = convertRootPaths(asList(source, 'rootStoragePaths'), where, report);
    item.SubfolderStructure = convertLayout(layout, where, definitions, sessionEntity, subjectEntity, report);

    [item.MetaDataDef, usedFields] = convertMetadata(asList(source, 'metadataMapping'), ...
        definitions, asList(source, 'entityLayout'), sessionIndex, where, sessionEntity, subjectEntity, ...
        sessionKeys, subjectKeys, report);
end

function type = convertType(location, where, report)
%convertType Map access and data category to a NANSEN data location type
    category = string(getOr(location, 'dataCategory', 'raw'));
    access = string(getOr(location, 'access', 'read'));

    if access == "read"
        typeName = "recorded";
        isExact = category == "raw";
    elseif category == "temporary"
        typeName = "temporary";
        isExact = true;
    else
        typeName = "processed";
        isExact = ismember(category, ["processed", "derived"]);
    end
    report.add(where + ".dataCategory", "NANSEN has no type for '" + category + "' with " + access + ...
        " access; mapped to " + typeName + ".", ~isExact)
    type = nansen.config.dloc.DataLocationType(char(typeName));
end

function rootPaths = convertRootPaths(storagePaths, where, report)
%convertRootPaths Map root storage paths to NANSEN root paths
    rootPaths = struct('Key', {}, 'Value', {}, 'DiskName', {}, 'DiskType', {});
    for j = 1:numel(storagePaths)
        storagePath = storagePaths{j};
        here = where + ".rootStoragePaths[" + string(storagePath.identifier) + "]";

        key = char(getOr(storagePath, 'uuid', ''));
        if isempty(key); key = nansen.util.getuuid(); end

        storageType = string(getOr(storagePath, 'storageType', 'local'));
        diskType = 'External';
        if storageType == "local"; diskType = 'Local'; end

        rootPaths(j) = struct('Key', key, 'Value', char(storagePath.path), ...
            'DiskName', char(getOr(storagePath, 'volumeName', '')), 'DiskType', diskType);

        report.add(here + ".storageType", "NANSEN distinguishes only local and external disks; mapped to External.", ...
            ~ismember(storageType, ["local", "external"]))
        report.add(here + ".environment", "NANSEN keeps per-machine root paths in local settings rather than by environment.", ...
            isfield(storagePath, 'environment'))
    end
end

function structure = convertLayout(layout, where, definitions, sessionEntity, subjectEntity, report)
%convertLayout Map layout levels down to the session level to a subfolder structure
    import nansen.config.dloc.dsmconversion.*

    structure = repmat(nansen.config.dloc.DataLocationModel.getDefaultSubfolderStructure(), 1, numel(layout));
    for j = 1:numel(layout)
        level = layout{j};
        here = where + ".entityLayout[" + string(level.name) + "]";
        entityType = string(getOr(level, 'entityType', ""));

        if entityType == sessionEntity
            structure(j).Type = 'Session';
        elseif entityType == subjectEntity
            structure(j).Type = 'Subject';
        else
            structure(j).Type = '';
            report.add(here, "Entity type '" + entityType + "' has no NANSEN folder type; kept as an untyped level.", entityType ~= "")
        end

        if ~getOr(level, 'isVariable', true)
            structure(j).Name = char(level.fixedName);
            structure(j).Expression = ['^', regexptranslate('escape', char(level.fixedName)), '$'];
        elseif isfield(level, 'matchPattern')
            structure(j).Expression = char(level.matchPattern);
        else
            structure(j).Expression = char(templateToPattern(string(level.pathComponentTemplate), definitions));
        end
        structure(j).IsFolder = string(getOr(level, 'fileSystemType', 'folder')) ~= "file";
        structure(j).IgnoreList = {};

        report.add(here + ".excludePatterns", "Not mapped: NANSEN's ignore list matches literal substrings, not patterns. " + ...
            "The level's expression already restricts the names, and hidden files are skipped.", ...
            ~isempty(asList(level, 'excludePatterns')))
        report.add(here + ".pathComponentTemplate", "NANSEN generates folder names itself; the template is not used for writing.", ...
            isfield(level, 'pathComponentTemplate'))
    end
end

function [metaDataDef, usedFields] = convertMetadata(mapping, definitions, layout, sessionIndex, ...
        where, sessionEntity, subjectEntity, sessionKeys, subjectKeys, report)
%convertMetadata Map extraction rules onto NANSEN's four metadata variables
    import nansen.config.dloc.dsmconversion.*

    metaDataDef = nansen.config.dloc.DataLocationModel.getDefaultMetadataStructure();
    usedFields = string.empty(1, 0);
    levelNames = fieldValues(layout, 'name');

    % A composite session identity becomes a Session ID read from the
    % joined names of several levels; a single identity field is mapped
    % by the loop below like the other variables.
    % compositeIdentityLevels reports why when the parts cannot be joined.
    compositeLevels = [];
    sessionField = "";
    if numel(sessionKeys) > 1
        compositeLevels = compositeIdentityLevels(mapping, sessionKeys, layout, sessionIndex, ...
            sessionEntity, where, report);
    else
        sessionField = identityField(sessionKeys, "session", where, report);
    end

    targets = struct( ...
        'Variable', {'Subject ID', 'Session ID', 'Experiment Date', 'Experiment Time'}, ...
        'Field', {identityField(subjectKeys, "subject", where, report), ...
                  sessionField, ...
                  temporalField(definitions, ["date", "datetime"], sessionEntity, subjectEntity), ...
                  temporalField(definitions, "time", sessionEntity, subjectEntity)});

    for k = 1:numel(targets)
        field = targets(k).Field;
        if field == ""; continue; end
        usedFields(end+1) = field; %#ok<AGROW>

        rule = findRule(mapping, field);
        here = where + ".metadataMapping[" + field + "]";
        if isempty(rule)
            report.add(here, "No extraction rule for this field in this data location; " + targets(k).Variable + " is left unset.")
            continue
        end
        extraction = rule.extraction;

        levelIndex = levelIndexOf(extraction, levelNames);
        if isempty(levelIndex) || levelIndex > sessionIndex
            report.add(here, "The rule does not read a single level at or above the session level; " + targets(k).Variable + " is left unset.")
            continue
        end

        method = string(extraction.method);
        if method == "regex"
            [input, isConverted] = convertRegexToWholeMatch(string(extraction.pattern));
            mode = "expr";
        elseif method == "substring"
            [mode, input, isConverted] = convertSliceToExtraction(string(extraction.pattern));
        else
            isConverted = false;
        end
        if ~isConverted
            report.add(here, "The " + method + " rule can not be expressed as a NANSEN ind or expr rule; " + targets(k).Variable + " is left unset.")
            continue
        end
        report.add(here + ".normalize", "Normalisation is not applied by NANSEN; extracted values may differ.", ...
            string(getOr(extraction, 'normalize', 'none')) ~= "none")

        idx = strcmp({metaDataDef.VariableName}, targets(k).Variable);
        metaDataDef(idx).SubfolderLevel = levelIndex;
        metaDataDef(idx).StringDetectMode = char(mode);
        metaDataDef(idx).StringDetectInput = char(input);
        metaDataDef(idx).StringFormat = char(getOr(extraction, 'valueFormat', ''));
    end

    if ~isempty(compositeLevels)
        idx = strcmp({metaDataDef.VariableName}, 'Session ID');
        metaDataDef(idx).SubfolderLevel = compositeLevels;
        metaDataDef(idx).StringDetectMode = 'expr';
        metaDataDef(idx).StringDetectInput = '.+';
        metaDataDef(idx).Separator = '_';
        usedFields = [usedFields, sessionKeys];
        report.add(where + ".metadataMapping[" + strjoin(sessionKeys, ", ") + "]", ...
            "The session identity is composite; the Session ID joins the names of levels " + ...
            strjoin(levelNames(compositeLevels), ", ") + " with '_', so it holds whole folder names rather than the extracted values.")
    end
end

function levels = compositeIdentityLevels(mapping, keys, layout, sessionIndex, sessionEntity, where, report)
%compositeIdentityLevels Levels whose joined names identify a session with a composite identity
%
%   NANSEN reads a Session ID from one string. It can join the names of
%   several levels into that string, but it applies one rule to the joined
%   string, so the parts of a composite identity cannot each be extracted.
%   The whole names of the levels the parts are read from are used
%   instead: every part is read from the name of its level, so sessions
%   with the same level names have the same identity.
%
%   The levels of the session's ancestor entities are joined too. A model's
%   identity is unique within its parent entities, while a NANSEN Session ID
%   is unique within the project; without the ancestors, day 1 of two
%   subjects would be one session.
%
%   A part given by a fixed rule is not in the path and is left out.
%   Returns empty, with a report, when a part is read otherwise than from
%   one level at or above the session level.

    levels = [];
    levelNames = fieldValues(layout, 'name');
    levelTypes = fieldValues(layout, 'entityType');

    for key = keys
        here = where + ".metadataMapping[" + key + "]";
        rule = findRule(mapping, key);
        if isempty(rule)
            report.add(here, "No extraction rule for this part of the composite session identity; the Session ID is left unset.")
            levels = [];
            return
        end
        method = string(rule.extraction.method);
        if method == "fixed"
            report.add(here, "A fixed part of the session identity is not in the path; the Session ID leaves it out.")
            continue
        end
        levelIndex = levelIndexOf(rule.extraction, levelNames);
        if ~ismember(method, ["substring", "regex"]) || isempty(levelIndex) || levelIndex > sessionIndex
            report.add(here, "This part of the composite session identity is not read from one level at or above the session level; the Session ID is left unset.")
            levels = [];
            return
        end
        levels(end+1) = levelIndex; %#ok<AGROW>
    end

    ancestorLevels = find(levelTypes(1:sessionIndex-1) ~= "" & levelTypes(1:sessionIndex-1) ~= sessionEntity);
    levels = unique([levels, ancestorLevels]);
end

function levelIndex = levelIndexOf(extraction, levelNames)
%levelIndexOf 1-based index of the level an extraction reads, or [] for the whole path
    levelRef = getOr(extraction, 'entityLayoutLevel', []);
    if isnumeric(levelRef) && ~isempty(levelRef)
        levelIndex = levelRef + 1;
    elseif ~isempty(levelRef)
        levelIndex = find(levelNames == string(levelRef), 1);
    else
        levelIndex = [];
    end
end

function variables = convertFilePatternsBelowSession(levels, item, where, identityKeys, report)
%convertFilePatternsBelowSession Map file patterns of levels below the session to variables
%
%   A NANSEN variable is a file in the session folder or in a subfolder of
%   it with a fixed name. Folder levels with a fixed name therefore become
%   the variable's Subfolder, and the file patterns of the levels reached
%   through them become variables. The first level that is neither a
%   fixed folder nor a level of files ends the walk; it and the levels
%   below it are dropped.
    variables = struct.empty;
    subfolders = strings(1, 0);
    for j = 1:numel(levels)
        level = levels{j};
        levelWhere = where + ".entityLayout[" + string(level.name) + "]";
        isFile = string(getOr(level, 'fileSystemType', 'folder')) == "file";
        isFixedFolder = ~isFile && isfield(level, 'fixedName') && ~getOr(level, 'isVariable', true);

        if isFixedFolder
            subfolders(end+1) = string(level.fixedName); %#ok<AGROW>
            variables = appendItems(variables, convertFilePatterns(level, item, where, ...
                identityKeys, report, strjoin(subfolders, "/")));
        elseif isFile
            variables = appendItems(variables, convertFilePatterns(level, item, where, ...
                identityKeys, report, strjoin(subfolders, "/")));
            report.add(levelWhere, "The files of this level are found in the session folder" + ...
                subfolderText(subfolders) + ". Where a session has several of them, " + ...
                "NANSEN uses the first.", isfield(level, 'entityType'))
        else
            for k = j:numel(levels)
                report.add(where + ".entityLayout[" + string(levels{k}.name) + "]", ...
                    "NANSEN finds files below the session only through folders with a fixed name; " + ...
                    "this level and the levels below it are dropped.")
            end
            return
        end
    end
end

function text = subfolderText(subfolders)
    if isempty(subfolders)
        text = "";
    else
        text = "'s subfolder " + strjoin(subfolders, "/");
    end
end

function variables = convertFilePatterns(level, item, where, identityKeys, report, subfolder)
%convertFilePatterns Map a layout level's file patterns to variable model items
%
%   identityKeys are the identity fields of the session and the subject,
%   the {tokens} a file pattern may use in place of a wildcard. subfolder
%   is the folder below the session folder where the files are, "" for
%   files in the session folder.
    import nansen.config.dloc.dsmconversion.*

    if nargin < 6
        subfolder = "";
    end
    sessionLevel = level;
    variables = struct.empty;
    here = where + ".entityLayout[" + string(sessionLevel.name) + "].filePatterns";
    patterns = asList(sessionLevel, 'filePatterns');

    for j = 1:numel(patterns)
        filePattern = patterns{j};
        if ~isfield(filePattern, 'name')
            report.add(here, "An unnamed file pattern has no variable name to map to.")
            continue
        end
        patternWhere = here + "[" + string(filePattern.name) + "]";

        [expression, fileType, isConverted, isApproximate] = ...
            convertFilePatternToWildcard(string(filePattern.pattern), identityKeys);
        if ~isConverted
            report.add(patternWhere, "The pattern has no wildcard equivalent.")
            continue
        end
        report.add(patternWhere, "Approximated as '" + expression + "': a character class became *, " + ...
            "so NANSEN may find files the pattern does not match.", isApproximate)
        report.add(patternWhere + ".cardinality", "A NANSEN variable is one file per session; " + ...
            "where several files match, NANSEN uses the first.", string(getOr(filePattern, 'cardinality', 'one')) == "many")

        variable = nansen.config.varmodel.VariableModel.getBlankItem();
        variable.VariableName = char(matlab.lang.makeValidName(string(filePattern.name)));
        variable.DataLocation = item.Name;
        variable.DataLocationUuid = item.Uuid;
        variable.Subfolder = char(subfolder);
        variable.FileNameExpression = char(expression);
        variable.FileType = char(fileType);
        variable.FileAdapter = findFileAdapter(fileType, patternWhere, report);
        variable.IsCustom = true;

        report.add(patternWhere + ".isRequired", "NANSEN does not check that required files are present.", ...
            isfield(filePattern, 'isRequired'))
        variables = appendItems(variables, variable);
    end
end

function variables = qualifyRepeatedVariableNames(variables, report)
%qualifyRepeatedVariableNames Qualify a name that several file patterns share
%
%   A file pattern name is unique within one layout level, but a NANSEN
%   variable name is unique within a project, and adding a second variable
%   with the same name fails. A name that occurs in more than one data
%   location is prefixed with the data location, <data location>_<name>,
%   so no location keeps the bare name only because it was converted
%   first. A name that occurs more than once within one data location, on
%   levels in different folders of the session, is also prefixed with the
%   variable's subfolder, <subfolder>_<name>; the variable of the session
%   folder itself has no subfolder to add. Names that are still equal
%   after this, from two levels in the same folder, are numbered.

    if isempty(variables)
        return
    end

    names = string({variables.VariableName});
    locations = string({variables.DataLocation});
    subfolders = string({variables.Subfolder});

    newNames = names;
    for i = 1:numel(variables)
        isSameName = names == names(i);
        parts = strings(1, 0);
        if numel(unique(locations(isSameName))) > 1
            parts(end+1) = locations(i); %#ok<AGROW>
        end
        if sum(isSameName & locations == locations(i)) > 1 && strlength(subfolders(i)) > 0
            parts(end+1) = replace(subfolders(i), "/", "_"); %#ok<AGROW>
        end
        newNames(i) = matlab.lang.makeValidName(strjoin([parts, names(i)], "_"));
    end
    newNames = matlab.lang.makeUniqueStrings(newNames);

    for i = find(newNames ~= names)
        report.add("variables[" + names(i) + "]", "The file pattern name is used by several file patterns; " + ...
            "renamed to '" + newNames(i) + "' in data location " + locations(i) + folderText(subfolders(i)) + ".")
        variables(i).VariableName = char(newNames(i));
    end
end

function text = folderText(subfolder)
%folderText The subfolder of a variable for a report, "" for the session folder
    if strlength(subfolder) == 0
        text = "";
    else
        text = ", subfolder " + subfolder;
    end
end

function adapterName = findFileAdapter(fileType, where, report)
%findFileAdapter Name of a file adapter for a file type, or Default
    adapterName = 'Default';
    adapters = struct.empty;
    if fileType ~= ""
        try
            adapters = nansen.dataio.listFileAdapters(char(fileType));
        catch exception
            % File adapters are listed from the current project, which
            % needs a user session. Converting a model does not, so an
            % absent session only means the adapter can not be looked up.
            if ~strcmp(exception.identifier, 'NANSEN:NoActiveUserSession')
                rethrow(exception)
            end
        end
    end
    if isempty(adapters) || strcmp(adapters(1).FileAdapterName, 'N/A')
        report.add(where + ".fileAdapter", "No file adapter supports '" + fileType + ...
            "' (or no project is active); set to Default, so the file can be found but not loaded.")
    else
        adapterName = adapters(1).FileAdapterName;
    end
end

% -------------------------------------------------------------------------

function name = chooseSessionEntity(entityTypes, locations)
%chooseSessionEntity An entity type named session with a level, else the deepest level's
    names = fieldValues(entityTypes, 'name');
    levelTypes = string.empty(1, 0);
    deepest = "";
    for i = 1:numel(locations)
        if ~isfield(locations{i}, 'filesystemSource'); continue; end
        layout = asList(locations{i}.filesystemSource, 'entityLayout');
        types = fieldValues(layout, 'entityType');
        levelTypes = [levelTypes, types]; %#ok<AGROW>
        typed = types(types ~= "");
        if ~isempty(typed) && deepest == ""
            deepest = typed(end);
        end
    end
    if ismember("session", names) && ismember("session", levelTypes)
        name = "session";
    else
        name = deepest;
    end
end

function name = chooseSubjectEntity(entityTypes, relationships, sessionEntity)
%chooseSubjectEntity An entity type named subject, else the session entity's parent
    names = fieldValues(entityTypes, 'name');
    name = "";
    if ismember("subject", names) && sessionEntity ~= "subject"
        name = "subject";
        return
    end
    for i = 1:numel(relationships)
        if string(relationships{i}.targetEntity) == sessionEntity ...
                && ismember(string(relationships{i}.relationType), ["oneToMany", "oneToOne"])
            name = string(relationships{i}.sourceEntity);
            return
        end
    end
end

function keys = identityKeys(entityTypes, entityName)
%identityKeys Identity fields of an entity type
    keys = string.empty(1, 0);
    for i = 1:numel(entityTypes)
        if string(entityTypes{i}.name) == entityName
            if isfield(entityTypes{i}, 'identifierRef')
                keys = string(entityTypes{i}.identifierRef);
            else
                keys = reshape(string(entityTypes{i}.identifierRefs), 1, []);
            end
        end
    end
end

function field = identityField(keys, role, where, report)
%identityField The single identity field, or "" with a report for a composite one
    field = "";
    if isscalar(keys)
        field = keys;
    elseif numel(keys) > 1
        report.add(where, "The " + role + " identity is composite (" + strjoin(keys, ", ") + "); NANSEN needs a single id field.")
    end
end

function field = temporalField(definitions, dataTypes, sessionEntity, subjectEntity)
%temporalField First field of a temporal data type, preferring the session entity
    field = "";
    for owner = [sessionEntity, subjectEntity]
        for name = string(fieldnames(definitions))'
            definition = definitions.(name);
            if ismember(string(definition.dataType), dataTypes) && string(definition.ofEntity) == owner
                field = name;
                return
            end
        end
    end
end

function rule = findRule(mapping, field)
%findRule The extraction rule for a field, or []
    rule = [];
    for i = 1:numel(mapping)
        if string(mapping{i}.metadataRef) == field
            rule = mapping{i};
            return
        end
    end
end

function pattern = templateToPattern(template, definitions)
%templateToPattern Derive a name pattern from a path component template
    [tokens, literals] = regexp(char(template), '\{([A-Za-z_][A-Za-z0-9_]*)\}', 'tokens', 'split');
    pattern = "^" + regexptranslate('escape', literals{1});
    for i = 1:numel(tokens)
        tokenPattern = "[^/\\]+";
        if isfield(definitions, tokens{i}{1}) && isfield(definitions.(tokens{i}{1}), 'validation') ...
                && isfield(definitions.(tokens{i}{1}).validation, 'pattern')
            tokenPattern = "(?:" + regexprep(string(definitions.(tokens{i}{1}).validation.pattern), '^\^|\$$', '') + ")";
        end
        pattern = pattern + tokenPattern + regexptranslate('escape', literals{i+1});
    end
    pattern = pattern + "$";
end

function values = fieldValues(items, fieldName)
%fieldValues One field of each item in a list, as a string row; "" where absent
    values = strings(1, numel(items));
    for i = 1:numel(items)
        values(i) = string(getOr(items{i}, fieldName, ""));
    end
end

function list = appendItems(list, items)
%appendItems Append struct items to a struct array that may still be empty
    if isempty(items)
        return
    elseif isempty(list)
        list = items;
    else
        list = [list, items];
    end
end

function items = asList(s, fieldName)
%asList A json array field as a row cell array of scalar structs or values
    items = {};
    if ~isstruct(s) || ~isfield(s, fieldName) || isempty(s.(fieldName)); return; end
    value = s.(fieldName);
    if iscell(value)
        items = reshape(value, 1, []);
    elseif isstruct(value)
        items = num2cell(reshape(value, 1, []));
    else
        items = {value};
    end
end

function value = getOr(s, fieldName, default)
%getOr A struct field, or a default when it is absent or empty
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    else
        value = default;
    end
end
