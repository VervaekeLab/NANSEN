function report = renameStoredIdentifiers(projectFolder, renameMap, options)
%renameStoredIdentifiers Rewrite identifiers stored in a project after a rename
%
%   report = nansen.config.project.renameStoredIdentifiers(projectFolder, renameMap)
%   previews every stored identifier in the project at projectFolder that
%   renameMap would change and returns the changes as a table. Nothing is
%   modified (dry run).
%
%   report = nansen.config.project.renameStoredIdentifiers(___, DryRun=false)
%   applies the changes in place. Unless Backup=false, a file is copied to
%   <file>.migration-backup before it is changed. An existing backup is
%   never replaced, so after several applied runs it still holds the file
%   as it was before the first one.
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
%   A file is not renamed onto a file that exists, for example an option
%   set that OptionsManager created under the new function name. Such a
%   file keeps its content and name and is reported with the status
%   "conflict", unless Overwrite=true. With Overwrite=true the existing
%   file is replaced, after it is copied to <file>.migration-backup unless
%   Backup=false. When two files would get the same new name, the second
%   one is always a conflict.
%
%   JSON files are edited textually (only whole quoted strings that equal
%   an identifier, or start with an identifier followed by ".", change),
%   so their formatting is preserved. MAT files are loaded, every char or
%   string value inside structs, cells and tables is rewritten, and the
%   variables that changed are saved back into the file.
%
%   load reads an object whose class is not on the MATLAB path as uint32
%   when the object is a variable of its own. A MAT file with such a
%   variable keeps its content and name and is reported with the status
%   "skipped". Inside a struct or a cell, load reads such an object as an
%   empty double, and neither load nor whos reports it, so a changed
%   variable that holds one is saved with an empty double in its place.
%
%   Every file is read and its changes are computed before any file is
%   changed. A file that cannot be read or written does not stop the run:
%   it is reported with the status "failed", and the other files are still
%   changed.
%
%   Name-value arguments:
%     DryRun       - true (default) reports only; false applies the changes
%     Backup       - true (default) keeps a backup of every changed file
%     Overwrite    - false (default) leaves a file unchanged when its new
%                    name is taken; true replaces the file with that name
%     ExtraFolders - additional folders to scan recursively
%     Verbose      - true (default) prints the report
%
%   The report has the columns File, Location, Old, New, Kind, Status and
%   Message. Kind is "value" for a rewritten string, "filename" for a
%   renamed file and "file" for a file that could not be read. Location
%   is the variable path inside a MAT file, or "(json)" for a textual
%   match. Status is one of
%     "pending"  - dry run: the change is made when DryRun=false
%     "applied"  - the change was made
%     "conflict" - the file keeps its content and name because its new
%                  name is taken (see Overwrite)
%     "skipped"  - the file keeps its content and name because a variable
%                  in it loads as another class than it was saved as
%     "failed"   - reading or writing the file raised an error
%   Message says why for "conflict", "skipped" and "failed". All rows of
%   a file have the same status, because a file is changed as a whole.
%
%   See also nansen.module.twophoton.migrateProject

    arguments
        projectFolder (1,1) string {mustBeFolder}
        renameMap
        options.DryRun (1,1) logical = true
        options.Backup (1,1) logical = true
        options.Overwrite (1,1) logical = false
        options.ExtraFolders (1,:) string = string.empty
        options.Verbose (1,1) logical = true
    end

    renameMap = normalizeRenameMap(renameMap);
    filePaths = collectFiles(projectFolder, options.ExtraFolders);

    plans = planChanges(filePaths, renameMap, options.Overwrite);

    if ~options.DryRun
        % Content is written to every file before any file is renamed, so
        % that a file replaced by a rename (Overwrite=true) is not written
        % to afterwards.
        for i = 1:numel(plans)
            if plans(i).Status == "pending" && ~isempty(plans(i).Rows)
                plans(i) = writePlannedContent(plans(i), options.Backup);
            end
        end
        for i = 1:numel(plans)
            if plans(i).Status == "pending" && plans(i).NewFilePath ~= ""
                plans(i) = renamePlannedFile(plans(i), options.Backup);
            end
        end
        for i = 1:numel(plans)
            if plans(i).Status == "pending"
                plans(i) = setStatus(plans(i), "applied", "");
            end
        end
    end

    report = vertcat(emptyReport(), plans.Rows);

    if options.Verbose
        printReport(report, projectFolder, options.DryRun)
    end
end

function renameMap = normalizeRenameMap(renameMap)
%normalizeRenameMap Accept a struct array, a table or a JSON file path
    if isstring(renameMap) || ischar(renameMap)
        filePath = string(renameMap);
        if ~isfile(filePath)
            error("NANSEN:Project:RenameMapNotFound", ...
                "The rename map file ""%s"" does not exist.", filePath)
        end
        decoded = jsondecode(fileread(filePath));
        if isstruct(decoded) && isfield(decoded, "Renames")
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

    if ~isstruct(renameMap) || ~all(isfield(renameMap, ["Old", "New"]))
        error("NANSEN:Project:InvalidRenameMap", ...
            "The rename map must have the fields Old and New (and optionally Match).")
    end
    if ~isfield(renameMap, "Match")
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
    entry = struct("Old", "", "New", "", "Match", "prefix");
    for fieldName = ["Old", "New", "Match"]
        if isfield(decodedEntry, fieldName)
            entry.(fieldName) = string(decodedEntry.(fieldName));
        end
    end
end

function filePaths = collectFiles(projectFolder, extraFolders)
%collectFiles List the files to scan, project specification first
    filePaths = string.empty(1, 0);

    specificationPath = fullfile(projectFolder, "project.nansen.json");
    if isfile(specificationPath)
        filePaths(end+1) = specificationPath;
    end

    folders = [fullfile(projectFolder, "configurations"), extraFolders];
    for i = 1:numel(folders)
        if ~isfolder(folders(i)); continue; end
        for pattern = ["*.json", "*.mat"]
            listing = dir(fullfile(folders(i), "**", pattern));
            listing = listing(~[listing.isdir]);
            filePaths = [filePaths, string(fullfile({listing.folder}, {listing.name}))]; %#ok<AGROW>
        end
    end
    filePaths = unique(filePaths, "stable");
end

function plans = planChanges(filePaths, renameMap, allowOverwrite)
%planChanges Read every file and compute its changes before any is written
    plans = repmat(emptyPlan(), 1, numel(filePaths));
    claimedFilePaths = string.empty(1, 0);

    for i = 1:numel(filePaths)
        plan = planFile(filePaths(i), renameMap);

        if plan.Status == "pending" && plan.NewFilePath ~= ""
            [~, newName, newExtension] = fileparts(plan.NewFilePath);
            newFileName = newName + newExtension;
            if ismember(plan.NewFilePath, claimedFilePaths)
                plan = setStatus(plan, "conflict", sprintf( ...
                    "Another file in this run is renamed to ""%s"".", newFileName));
            elseif isfile(plan.NewFilePath) && ~allowOverwrite
                plan = setStatus(plan, "conflict", sprintf( ...
                    "A file named ""%s"" exists. Use Overwrite=true to replace it.", newFileName));
            else
                claimedFilePaths(end+1) = plan.NewFilePath; %#ok<AGROW>
            end
        end

        plans(i) = plan;
    end
end

function plan = planFile(filePath, renameMap)
%planFile Compute the changes renameMap makes to one file's content and name
    plan = emptyPlan();
    plan.FilePath = filePath;
    [folderPath, baseName, extension] = fileparts(filePath);

    try
        [plan.Content, valueRows, unloadedVariables] = renameInFile(filePath, extension, renameMap);
    catch exception
        plan.Rows = makeRow(filePath, "(file)", "", "", "file");
        plan = setStatus(plan, "failed", exception.message);
        return
    end
    plan.Rows = addFileColumn(valueRows, filePath);

    newBaseName = applyRename(baseName, renameMap);
    if newBaseName ~= baseName
        plan.NewFilePath = fullfile(folderPath, newBaseName + extension);
        plan.Rows = [plan.Rows; makeRow(filePath, "(file name)", baseName, newBaseName, "filename")];
    end

    if ~isempty(unloadedVariables) && ~isempty(plan.Rows)
        plan = setStatus(plan, "skipped", ...
            "Holds variables that load as another class than they were saved as: " ...
            + strjoin(unloadedVariables, ", ") + ". Put their class on the MATLAB path to rename this file.");
    end
end

function [content, rows, unloadedVariables] = renameInFile(filePath, extension, renameMap)
%renameInFile Rewrite the identifiers in one file's content, in memory
%
%   content is the new text of a JSON file, or a struct holding the
%   changed variables of a MAT file.
    unloadedVariables = string.empty(1, 0);
    switch lower(extension)
        case ".json"
            [content, rows] = renameInJsonText(fileread(filePath), renameMap);
        case ".mat"
            [content, rows, unloadedVariables] = renameInMatFile(filePath, renameMap);
        otherwise
            % collectFiles lists only .json and .mat files.
            content = [];
            rows = emptyReport();
    end
end

function [text, rows] = renameInJsonText(text, renameMap)
%renameInJsonText Replace whole quoted identifiers and quoted prefixes
    rows = emptyReport();
    for i = 1:numel(renameMap)
        escapedOld = regexptranslate("escape", renameMap(i).Old);
        % regexprep reads escaped text literally in the replacement too.
        escapedNew = regexptranslate("escape", renameMap(i).New);
        if renameMap(i).Match == "exact"
            pattern = """" + escapedOld + """";
            replacement = """" + escapedNew + """";
        else
            pattern = """" + escapedOld + "\.";
            replacement = """" + escapedNew + ".";
        end
        numMatches = numel(regexp(text, pattern, "match"));
        if numMatches == 0; continue; end
        text = regexprep(text, pattern, replacement);
        matchRow = makeRow("", "(json)", renameMap(i).Old, renameMap(i).New, "value");
        rows = [rows; repmat(matchRow, numMatches, 1)]; %#ok<AGROW>
    end
end

function [changedVariables, rows, unloadedVariables] = renameInMatFile(filePath, renameMap)
%renameInMatFile Rewrite the char and string values of every MAT-file variable
%
%   changedVariables holds only the variables in which a value changed.
%   unloadedVariables lists the variables that load read as another class
%   than the one whos reports for the file, which is what load does with a
%   variable whose class is not on the MATLAB path.
    variableInfo = whos("-file", filePath);

    % unloadedVariables reports these variables instead of the warning.
    warningState = warning("off", "MATLAB:load:cannotInstantiateLoadedVariable");
    restoreWarning = onCleanup(@() warning(warningState));
    data = load(filePath);
    delete(restoreWarning)

    changedVariables = struct();
    rows = emptyReport();
    unloadedVariables = string.empty(1, 0);
    for i = 1:numel(variableInfo)
        variableName = variableInfo(i).name;
        savedClass = string(variableInfo(i).class);
        if string(class(data.(variableName))) ~= savedClass
            unloadedVariables(end+1) = sprintf("%s (saved as %s)", variableName, savedClass); %#ok<AGROW>
            continue
        end
        [newValue, variableRows] = renameInValue(data.(variableName), renameMap, string(variableName));
        if ~isempty(variableRows)
            changedVariables.(variableName) = newValue;
            rows = [rows; variableRows]; %#ok<AGROW>
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
            % A missing element holds no text, and missing ~= missing is
            % true, so it would be reported as a change.
            if ismissing(value(i)); continue; end
            newValue = applyRename(value(i), renameMap);
            if newValue ~= value(i)
                elementLocation = location + elementSuffix(value, i);
                rows = [rows; makeRow("", elementLocation, value(i), newValue, "value")]; %#ok<AGROW>
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
                fieldName = fieldNames{j};
                fieldLocation = location + elementSuffix(value, i) + "." + fieldName;
                [value(i).(fieldName), fieldRows] = renameInValue(value(i).(fieldName), renameMap, fieldLocation);
                rows = [rows; fieldRows]; %#ok<AGROW>
            end
        end
    elseif istable(value)
        variableNames = value.Properties.VariableNames;
        for j = 1:numel(variableNames)
            variableName = variableNames{j};
            columnLocation = location + "." + variableName;
            [value.(variableName), columnRows] = renameInValue(value.(variableName), renameMap, columnLocation);
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

function plan = writePlannedContent(plan, keepBackup)
%writePlannedContent Back up one file and write its renamed values
    try
        if keepBackup
            backUpFile(plan.FilePath)
        end
        if any(plan.Rows.Kind == "value")
            writeContent(plan.FilePath, plan.Content)
        end
    catch exception
        plan = setStatus(plan, "failed", exception.message);
    end
end

function plan = renamePlannedFile(plan, keepBackup)
%renamePlannedFile Give one file its new name
%
%   The new name is taken only when Overwrite=true; that file is backed up
%   before it is replaced.
    try
        if keepBackup && isfile(plan.NewFilePath)
            backUpFile(plan.NewFilePath)
        end
        movefile(plan.FilePath, plan.NewFilePath)
    catch exception
        plan = setStatus(plan, "failed", exception.message);
    end
end

function backUpFile(filePath)
%backUpFile Copy a file to <file>.migration-backup unless that backup exists
%
%   An existing backup is kept, so it holds the file as it was before the
%   first applied run.
    backupFilePath = filePath + ".migration-backup";
    if ~isfile(backupFilePath)
        copyfile(filePath, backupFilePath)
    end
end

function writeContent(filePath, content)
%writeContent Write new JSON text, or save the changed MAT-file variables
    [~, ~, extension] = fileparts(filePath);
    if lower(extension) == ".json"
        writeText(filePath, content)
    else
        % save reads the variables from a struct in this workspace, and
        % -append leaves the variables that did not change as stored.
        changedVariables = content;
        save(filePath, "-struct", "changedVariables", "-append")
    end
end

function writeText(filePath, text)
    fileId = fopen(filePath, "w");
    if fileId == -1
        error("NANSEN:Project:CannotWriteFile", "Could not open ""%s"" for writing.", filePath)
    end
    fileCleanup = onCleanup(@() fclose(fileId));
    fwrite(fileId, char(text), "char");
end

function plan = emptyPlan()
%emptyPlan A plan that changes nothing in a file
    plan = struct("FilePath", "", "NewFilePath", "", "Content", [], ...
        "Rows", emptyReport(), "Status", "pending", "Message", "");
end

function plan = setStatus(plan, status, message)
%setStatus Set the status and message of a plan and of each of its rows
    plan.Status = status;
    plan.Message = message;
    plan.Rows.Status(:) = status;
    plan.Rows.Message(:) = message;
end

function rows = addFileColumn(rows, filePath)
    if ~isempty(rows)
        rows.File(:) = string(filePath);
    end
end

function row = makeRow(filePath, location, old, new, kind)
    row = table(string(filePath), string(location), string(old), string(new), string(kind), ...
        "pending", "", VariableNames=reportColumnNames());
end

function report = emptyReport()
    columnNames = reportColumnNames();
    report = table(Size=[0, numel(columnNames)], ...
        VariableTypes=repmat("string", 1, numel(columnNames)), VariableNames=columnNames);
end

function columnNames = reportColumnNames()
    columnNames = ["File", "Location", "Old", "New", "Kind", "Status", "Message"];
end

function printReport(report, projectFolder, isDryRun)
%printReport Display the report and count the changes by status
    if isempty(report)
        fprintf("No stored identifiers to rename in ""%s"".\n", projectFolder)
        return
    end
    disp(report)

    if isDryRun
        isCounted = report.Status == "pending";
        fprintf("Dry run: %d change(s) in %d file(s) would be made. ", ...
            nnz(isCounted), numel(unique(report.File(isCounted))))
        fprintf("Call again with DryRun=false to apply them.\n")
    else
        isCounted = report.Status == "applied";
        fprintf("Applied %d change(s) in %d file(s).\n", ...
            nnz(isCounted), numel(unique(report.File(isCounted))))
    end

    numOtherFiles = numel(unique(report.File(~isCounted)));
    if numOtherFiles > 0
        fprintf("%d file(s) have the status conflict, skipped or failed; see the Message column.\n", ...
            numOtherFiles)
    end
end
