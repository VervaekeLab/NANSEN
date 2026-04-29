function info = createFileAdapter(varargin)
%createFileAdapter Scaffold a sidecar-defined file adapter plugin.
%
%   info = nansen.plugin.createFileAdapter('Name', name) creates a
%   function-based file adapter folder with a fileadapter.plugin.json sidecar
%   and a read.m implementation template.
%
%   Name-value options:
%       Name               Adapter display name. Required.
%       RootPath           Folder where package folders are created.
%       PackageName        Package under RootPath. Default: fileadapter.
%       Description        Adapter description.
%       SupportedFileTypes Cell array of supported extensions.
%       DataType           Name of returned data type. Default: N/A.

    params = struct();
    params.Name = '';
    params.RootPath = '';
    params.PackageName = 'fileadapter';
    params.Description = '';
    params.SupportedFileTypes = {};
    params.DataType = 'N/A';

    params = utility.parsenvpairs(params, 1, varargin);

    if isempty(params.Name)
        error('Nansen:PluginCreateFileAdapter:NameMissing', ...
            'A file adapter name is required.')
    end

    if isempty(params.RootPath)
        params.RootPath = fullfile(nansen.localpath('integrations'), ...
            'fileadapters');
    end

    adapterName = matlab.lang.makeValidName(params.Name);
    packageParts = strsplit(params.PackageName, '.');
    packageFolder = params.RootPath;
    for i = 1:numel(packageParts)
        packageFolder = fullfile(packageFolder, ['+', packageParts{i}]);
    end

    pluginFolder = fullfile(packageFolder, ['+', adapterName]);
    if ~isfolder(pluginFolder)
        mkdir(pluginFolder)
    end

    sidecarPath = fullfile(pluginFolder, 'fileadapter.plugin.json');
    readFunctionPath = fullfile(pluginFolder, 'read.m');

    spec = createFileAdapterSpec(params, adapterName, packageParts);
    writeJsonFile(sidecarPath, spec)

    if ~isfile(readFunctionPath)
        writeTextFile(readFunctionPath, createReadTemplate(adapterName))
    end

    info = struct();
    info.PluginFolder = pluginFolder;
    info.SidecarPath = sidecarPath;
    info.ReadFunctionPath = readFunctionPath;
    info.Spec = spec;
end

function spec = createFileAdapterSpec(params, adapterName, packageParts)
    entrypointParts = [packageParts, {adapterName, 'read'}];

    spec = struct();
    spec.schemaVersion = '1.0';
    spec.id = strjoin([packageParts, {adapterName}], '.');
    spec.pluginType = 'fileadapter';
    spec.displayName = params.Name;
    spec.description = params.Description;
    spec.version = '1.0.0';
    spec.implementation = struct( ...
        'language', 'matlab', ...
        'kind', 'function', ...
        'read', 'read.m', ...
        'entrypoint', strjoin(entrypointParts, '.'));
    spec.match = struct( ...
        'extensions', {normalizeFileTypes(params.SupportedFileTypes)});
    spec.outputs = struct('dataType', params.DataType);
    spec.capabilities = {'read'};
end

function fileTypes = normalizeFileTypes(fileTypes)
    if ischar(fileTypes)
        fileTypes = {fileTypes};
    elseif isstring(fileTypes)
        fileTypes = cellstr(fileTypes);
    end

    fileTypes = cellfun(@(s) char(s), fileTypes, 'UniformOutput', false);
end

function text = createReadTemplate(adapterName)
    text = sprintf([ ...
        'function data = read(filename, varargin)\n', ...
        '%%read Read data for the %s file adapter.\n', ...
        '\n', ...
        '    %% Replace this with the adapter-specific reader.\n', ...
        '    data = load(filename, varargin{:});\n', ...
        'end\n'], adapterName);
end

function writeJsonFile(filePath, S)
    jsonText = jsonencode(S, 'PrettyPrint', true);
    writeTextFile(filePath, jsonText)
end

function writeTextFile(filePath, text)
    fid = fopen(filePath, 'w');
    if fid == -1
        error('Nansen:PluginCreateFileAdapter:FileOpenFailed', ...
            'Could not open "%s" for writing.', filePath)
    end

    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s\n', text);
end
