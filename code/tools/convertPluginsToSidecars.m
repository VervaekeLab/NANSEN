function report = convertPluginsToSidecars(varargin)
%convertPluginsToSidecars Generate sidecars for existing plugin definitions.
%
%   report = convertPluginsToSidecars() writes <itemtype>.plugin.json files
%   for discovered compatibility plugins. Existing sidecars are preserved
%   unless Overwrite is true.

    params = struct();
    params.PluginTypes = {'fileadapter', 'action', 'tablevariable'};
    params.DryRun = false;
    params.Overwrite = false;
    params.RootPath = nansen.rootpath();

    params = utility.parsenvpairs(params, 1, varargin);

    if ischar(params.PluginTypes)
        params.PluginTypes = {params.PluginTypes};
    end

    report = struct('PluginType', {}, 'SidecarPath', {}, ...
        'NumPlugins', {}, 'Status', {}, 'Message', {});

    for i = 1:numel(params.PluginTypes)
        pluginType = lower(params.PluginTypes{i});
        registry = nansen.plugin.Registry.getInstance(pluginType, true);
        specs = registry.list('IncludeDisabled', true);
        specs = keepConvertibleSpecs(specs, params.RootPath);

        sidecarFilename = getSidecarFilename(pluginType);
        sidecarPaths = cellfun( ...
            @(p) fullfile(fileparts(p), sidecarFilename), ...
            {specs.SourcePath}, 'UniformOutput', false);

        uniqueSidecarPaths = unique(sidecarPaths, 'stable');
        for j = 1:numel(uniqueSidecarPaths)
            sidecarPath = uniqueSidecarPaths{j};
            isMatch = strcmp(sidecarPaths, sidecarPath);
            groupSpecs = specs(isMatch);

            item = struct();
            item.PluginType = pluginType;
            item.SidecarPath = sidecarPath;
            item.NumPlugins = numel(groupSpecs);
            item.Status = 'pending';
            item.Message = '';

            if isfile(sidecarPath) && ~params.Overwrite
                item.Status = 'skipped';
                item.Message = 'Sidecar already exists.';
                report(end+1) = item; %#ok<AGROW>
                continue
            end

            sidecarStruct = createSidecarStruct(pluginType, groupSpecs);
            if ~params.DryRun
                writeJsonFile(sidecarPath, sidecarStruct)
            end

            if params.DryRun
                item.Status = 'dryrun';
            else
                item.Status = 'written';
            end
            report(end+1) = item; %#ok<AGROW>
        end
    end
end

function specs = keepConvertibleSpecs(specs, rootPath)
    if isempty(specs)
        return
    end

    source = lower({specs.Source});
    isGenerated = strcmp(source, 'sidecar') | strcmp(source, 'builtin');
    hasPath = ~cellfun(@isempty, {specs.SourcePath});
    isInRoot = startsWith({specs.SourcePath}, rootPath);
    specs = specs(~isGenerated & hasPath & isInRoot);
end

function filename = getSidecarFilename(pluginType)
    switch pluginType
        case 'fileadapter'
            filename = 'fileadapter.plugin.json';
        case 'action'
            filename = 'action.plugin.json';
        case 'tablevariable'
            filename = 'tablevariable.plugin.json';
        otherwise
            error('Nansen:PluginConversion:UnknownPluginType', ...
                'Unknown plugin type "%s".', pluginType)
    end
end

function S = createSidecarStruct(pluginType, specs)
    pluginSpecs = cell(1, numel(specs));
    for i = 1:numel(specs)
        pluginSpecs{i} = specToSidecarStruct(pluginType, specs(i));
    end

    pluginSpecs = harmonizeStructs(pluginSpecs);
    if numel(pluginSpecs) == 1
        S = pluginSpecs(1);
    else
        S = struct();
        S.schemaVersion = '1.0';
        S.pluginType = pluginType;
        S.plugins = pluginSpecs;
    end
end

function S = harmonizeStructs(structCells)
    allFields = {};
    for i = 1:numel(structCells)
        allFields = union(allFields, fieldnames(structCells{i}), 'stable');
    end

    S = repmat(struct(), 1, numel(structCells));
    for i = 1:numel(structCells)
        for j = 1:numel(allFields)
            fieldName = allFields{j};
            if isfield(structCells{i}, fieldName)
                S(i).(fieldName) = structCells{i}.(fieldName);
            else
                S(i).(fieldName) = [];
            end
        end
    end
end

function S = specToSidecarStruct(pluginType, spec)
    S = struct();
    S.schemaVersion = spec.SchemaVersion;
    S.id = spec.Id;
    S.pluginType = pluginType;
    S.displayName = spec.DisplayName;
    S.description = spec.Description;
    S.version = spec.Version;
    S.implementation = spec.Implementation;
    S.capabilities = spec.Capabilities;

    switch pluginType
        case 'fileadapter'
            fileAdapterSpec = ...
                nansen.plugin.fileadapter.FileAdapterSpec.fromPluginSpec(spec);
            S.match = struct('extensions', {fileAdapterSpec.SupportedFileTypes});
            S.outputs = struct('dataType', fileAdapterSpec.DataType);

        case 'action'
            actionSpec = nansen.plugin.action.ActionSpec.fromPluginSpec(spec);
            S.entityType = actionSpec.EntityType;
            S.methodName = actionSpec.MethodName;
            S.batchMode = actionSpec.BatchMode;
            S.isQueueable = actionSpec.IsQueueable;
            S.alternatives = actionSpec.Alternatives;
            S.menuLocation = actionSpec.MenuLocation;
            if isfield(spec.TypeData, 'DefaultOptions')
                S.defaultOptions = spec.TypeData.DefaultOptions;
            end

        case 'tablevariable'
            tableVariableSpec = ...
                nansen.plugin.tablevariable.TableVariableSpec.fromPluginSpec(spec);
            S.tableType = tableVariableSpec.TableType;
            S.variableName = tableVariableSpec.VariableName;
            S.isEditable = tableVariableSpec.IsEditable;
            S.defaultValue = tableVariableSpec.DefaultValue;
    end
end

function writeJsonFile(filePath, S)
    fid = fopen(filePath, 'w');
    if fid == -1
        error('Nansen:PluginConversion:FileOpenFailed', ...
            'Could not open "%s" for writing.', filePath)
    end

    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s\n', jsonencode(S, 'PrettyPrint', true));
end
