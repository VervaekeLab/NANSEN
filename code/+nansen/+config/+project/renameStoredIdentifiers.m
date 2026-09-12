function report = renameStoredIdentifiers(projectFolder, renameMap, options)
%renameStoredIdentifiers Rewrite identifiers stored in a project after a rename
%
%   report = nansen.config.project.renameStoredIdentifiers(projectFolder, renameMap)
%   previews every stored identifier in the project at projectFolder that
%   renameMap would change and returns the changes as a table. Nothing is
%   modified (dry run).
%
%   report = nansen.config.project.renameStoredIdentifiers(___, DryRun=false)
%   applies the changes in place. A backup of every modified file is kept
%   next to it as <file>.migration-backup unless Backup=false.
%
%   renameMap is a struct array with the fields Old, New and Match, a
%   table with those variables, or the path of a JSON file whose "Renames"
%   array holds such objects. Match is "exact" (a value equal to Old
%   becomes New) or "prefix" (a value that starts with Old followed by a
%   "." gets that prefix replaced). Match defaults to "prefix". The first
%   matching entry wins.
%
%   What is scanned:
%     - project.nansen.json (module selections and other preferences)
%     - every .json and .mat file under <projectFolder>/configurations,
%       which holds the data-location and variable models, the catalogs,
%       the pipelines and the project's custom option sets
%     - every .json and .mat file under the folders given in ExtraFolders,
%       for example the user-level custom options folder
%   A file whose base name is an old identifier is renamed as well,
%   because option sets are stored under the fully qualified name of the
%   function they belong to.
%
%   JSON files are edited textually (only whole quoted strings that equal
%   an identifier, or start with an identifier followed by ".", change),
%   so their formatting is preserved. MAT files are loaded, every char or
%   string value inside structs, cells and tables is rewritten, and the
%   file is saved again.
%
%   Name-value arguments:
%     DryRun       - true (default) reports only; false applies the changes
%     Backup       - true (default) keeps a backup of every changed file
%     ExtraFolders - additional folders to scan recursively
%     Verbose      - true (default) prints the report
%
%   The report has the columns File, Location, Old, New and Kind. Kind is
%   "value" for a rewritten string and "filename" for a renamed file.
%   Location is the variable path inside a MAT file, or "(json)" for a
%   textual match.
%
%   See also nansen.module.twophoton.migrateProject

    arguments
        projectFolder (1,1) string {mustBeFolder}
        renameMap
        options.DryRun (1,1) logical = true
        options.Backup (1,1) logical = true
        options.ExtraFolders (1,:) string = string.empty
        options.Verbose (1,1) logical = true
    end

    renameMap = normalizeRenameMap(renameMap);
    filePaths = collectFiles(projectFolder, options.ExtraFolders);

    report = emptyReport();
    for i = 1:numel(filePaths)
        report = [report; processFile(filePaths(i), renameMap, options)]; %#ok<AGROW>
    end

    if options.Verbose
        printReport(report, projectFolder, options.DryRun)
    end
end

function renameMap = normalizeRenameMap(renameMap)
%normalizeRenameMap Accept a struct array, a table or a JSON file path
    if isstring(renameMap) || ischar(renameMap)
        filePath = string(renameMap);
        if ~isfile(filePath)
            error('NANSEN:Project:RenameMapNotFound', ...
                'The rename map file "%s" does not exist.', filePath)
        end
        decoded = jsondecode(fileread(filePath));
        if isstruct(decoded) && isfield(decoded, 'Renames')
            renameMap = decoded.Renames;
        else
            renameMap = decoded;
        end
        if iscell(renameMap)
            % Objects with different optional fields (e.g. a Note on some
            % entries) decode to a cell; keep only the fields that matter.
            renameMap = cellfun(@keepRenameFields, renameMap);
        end
    elseif istable(renameMap)
        renameMap = table2struct(renameMap);
    end

    if ~isstruct(renameMap) || ~all(isfield(renameMap, {'Old', 'New'}))
        error('NANSEN:Project:InvalidRenameMap', ...
            'The rename map must have the fields Old and New (and optionally Match).')
    end
    if ~isfield(renameMap, 'Match')
        [renameMap.Match] = deal("prefix");
    end

    for i = 1:numel(renameMap)
        renameMap(i).Old = string(renameMap(i).Old);
        renameMap(i).New = string(renameMap(i).New);
        if isempty(renameMap(i).Match) || strlength(string(renameMap(i).Match)) == 0
            renameMap(i).Match = "prefix";
        end
        renameMap(i).Match = validatestring(renameMap(i).Match, ["exact", "prefix"]);
    end
    renameMap = reshape(renameMap, 1, []);
end

function entry = keepRenameFields(decodedEntry)
%keepRenameFields Reduce a decoded JSON object to Old, New and Match
    entry = struct('Old', "", 'New', "", 'Match', "prefix");
    for fieldName = ["Old", "New", "Match"]
        if isfield(decodedEntry, fieldName)
            entry.(fieldName) = string(decodedEntry.(fieldName));
        end
    end
end

function filePaths = collectFiles(projectFolder, extraFolders)
%collectFiles List the files to scan, project specification first
    filePaths = string.empty(1, 0);

    specificationPath = fullfile(projectFolder, 'project.nansen.json');
    if isfile(specificationPath)
        filePaths(end+1) = specificationPath;
    end

    folders = [fullfile(projectFolder, 'configurations'), extraFolders];
    for i = 1:numel(folders)
        if ~isfolder(folders(i)); continue; end
        for pattern = ["*.json", "*.mat"]
            listing = dir(fullfile(folders(i), '**', pattern));
            listing = listing(~[listing.isdir]);
            filePaths = [filePaths, string(fullfile({listing.folder}, {listing.name}))]; %#ok<AGROW>
        end
    end
    filePaths = unique(filePaths, 'stable');
end

function rows = processFile(filePath, renameMap, options)
%processFile Rewrite one file's content and name according to the map
    [folderPath, baseName, extension] = fileparts(filePath);
    rows = emptyReport();

    switch lower(extension)
        case ".json"
            [newText, valueRows] = renameInJsonText(fileread(filePath), renameMap);
            rows = [rows; addFileColumn(valueRows, filePath)];
        case ".mat"
            S = load(filePath);
            [S, valueRows] = renameInValue(S, renameMap, "");
            rows = [rows; addFileColumn(valueRows, filePath)];
        otherwise
            return
    end

    newBaseName = applyRename(string(baseName), renameMap);
    if newBaseName ~= string(baseName)
        rows = [rows; makeRow(filePath, "(file name)", string(baseName), newBaseName, "filename")];
    end

    if options.DryRun || isempty(rows)
        return
    end

    if options.Backup
        copyfile(filePath, filePath + ".migration-backup");
    end
    if any(rows.Kind == "value")
        if lower(extension) == ".json"
            writeText(filePath, newText);
        else
            % save needs the variable in this workspace, hence no helper.
            save(filePath, '-struct', 'S');
        end
    end
    if newBaseName ~= string(baseName)
        movefile(filePath, fullfile(folderPath, newBaseName + extension));
    end
end

function writeText(filePath, text)
    fileId = fopen(filePath, 'w');
    if fileId == -1
        error('NANSEN:Project:CannotWriteFile', 'Could not open "%s" for writing.', filePath)
    end
    fileCleanup = onCleanup(@() fclose(fileId));
    fwrite(fileId, text, 'char');
end

function [text, rows] = renameInJsonText(text, renameMap)
%renameInJsonText Replace whole quoted identifiers and quoted prefixes
    rows = emptyReport();
    for i = 1:numel(renameMap)
        old = renameMap(i).Old;
        new = renameMap(i).New;
        if renameMap(i).Match == "exact"
            pattern = '"' + regexptranslate('escape', old) + '"';
            replacement = '"' + regexptranslate('escape', new) + '"';
        else
            pattern = '"' + regexptranslate('escape', old) + '\.';
            replacement = '"' + regexptranslate('escape', new) + '.';
        end
        matches = regexp(text, pattern, 'match');
        if isempty(matches); continue; end
        text = regexprep(text, pattern, replacement);
        for j = 1:numel(matches)
            rows = [rows; makeRow("", "(json)", old, new, "value")]; %#ok<AGROW>
        end
    end
end

function [value, rows] = renameInValue(value, renameMap, location)
%renameInValue Recursively rewrite char and string values inside a variable
    rows = emptyReport();

    if ischar(value)
        if isrow(value) || isempty(value)
            newValue = applyRename(string(value), renameMap);
            if newValue ~= string(value)
                rows = makeRow("", location, string(value), newValue, "value");
                value = char(newValue);
            end
        end
    elseif isstring(value)
        for i = 1:numel(value)
            newValue = applyRename(value(i), renameMap);
            if newValue ~= value(i)
                rows = [rows; makeRow("", location + elementSuffix(value, i), value(i), newValue, "value")]; %#ok<AGROW>
                value(i) = newValue;
            end
        end
    elseif iscell(value)
        for i = 1:numel(value)
            [value{i}, cellRows] = renameInValue(value{i}, renameMap, location + "{" + i + "}");
            rows = [rows; cellRows]; %#ok<AGROW>
        end
    elseif isstruct(value)
        fieldNames = fieldnames(value);
        for i = 1:numel(value)
            for j = 1:numel(fieldNames)
                fieldLocation = location + elementSuffix(value, i) + "." + fieldNames{j};
                [value(i).(fieldNames{j}), fieldRows] = renameInValue(value(i).(fieldNames{j}), renameMap, fieldLocation);
                rows = [rows; fieldRows]; %#ok<AGROW>
            end
        end
    elseif istable(value)
        variableNames = value.Properties.VariableNames;
        for j = 1:numel(variableNames)
            [value.(variableNames{j}), columnRows] = renameInValue(value.(variableNames{j}), renameMap, location + "." + variableNames{j});
            rows = [rows; columnRows]; %#ok<AGROW>
        end
    end
    % Numeric, logical and object values are left untouched.
end

function suffix = elementSuffix(value, index)
    if isscalar(value)
        suffix = "";
    else
        suffix = "(" + index + ")";
    end
end

function newValue = applyRename(value, renameMap)
%applyRename Apply the first matching rename entry to one string
    newValue = value;
    for i = 1:numel(renameMap)
        old = renameMap(i).Old;
        if renameMap(i).Match == "exact"
            if value == old
                newValue = renameMap(i).New;
                return
            end
        else
            if startsWith(value, old + ".")
                newValue = renameMap(i).New + extractAfter(value, strlength(old));
                return
            end
        end
    end
end

function rows = addFileColumn(rows, filePath)
    if ~isempty(rows)
        rows.File(:) = string(filePath);
    end
end

function row = makeRow(filePath, location, old, new, kind)
    row = table(string(filePath), string(location), string(old), string(new), string(kind), ...
        'VariableNames', {'File', 'Location', 'Old', 'New', 'Kind'});
end

function report = emptyReport()
    report = table('Size', [0, 5], ...
        'VariableTypes', {'string', 'string', 'string', 'string', 'string'}, ...
        'VariableNames', {'File', 'Location', 'Old', 'New', 'Kind'});
end

function printReport(report, projectFolder, isDryRun)
    if isempty(report)
        fprintf('No stored identifiers to rename in "%s".\n', projectFolder)
        return
    end
    disp(report)
    numFiles = numel(unique(report.File));
    if isDryRun
        fprintf(['Dry run: %d change(s) in %d file(s) would be made. ', ...
            'Call again with DryRun=false to apply them.\n'], height(report), numFiles)
    else
        fprintf('Applied %d change(s) in %d file(s).\n', height(report), numFiles)
    end
end
