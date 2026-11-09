function fileAdapterList = listFileAdapters(fileExtension, options)
%listFileAdapters Return a struct array of available file adapters.
%
%   fileAdapterList = nansen.dataio.listFileAdapters() returns all adapters
%     visible to the current project.
%
%   fileAdapterList = nansen.dataio.listFileAdapters(fileExtension) filters
%     to adapters that support the given extension (with or without a dot).
%
%   fileAdapterList is an n-by-1 struct array with fields:
%       FileAdapterName     (char)    : Name of the adapter
%       FunctionName        (char)    : Full MATLAB function/package name
%       SupportedFileTypes  (cell)    : Supported file extensions
%       DataType            (char)    : Data type returned on load
%       IsDynamic           (logical) : true for sidecar-based adapters
%
%   When no adapter matches, fileAdapterList has one element whose
%   FileAdapterName is 'N/A'. Without a project, fileAdapterList is empty.
%
%   Optional name-value arguments:
%       Project - Project instance to query (defaults to current project)
%
%   See also nansen.plugin.fileadapter.Registry

    arguments
        fileExtension (1,1) string = ""
        options.Project = nansen.getCurrentProject()
    end

    if isempty(options.Project)
        fileAdapterList = struct.empty;
        return
    end

    registryEntries = options.Project.FileAdapterRegistry.list(fileExtension);
    fileAdapterList = convertToCharFields(registryEntries);

    if isempty(fileAdapterList)
        fileAdapterList(1).FileAdapterName = 'N/A';
        fileAdapterList(1).FunctionName = '';
        fileAdapterList(1).SupportedFileTypes = {};
        fileAdapterList(1).DataType = '';
    end

    if ~nargout
        fileAdapterList = struct2table(fileAdapterList, 'AsArray', true);
        fileAdapterList.FileAdapterName = string(fileAdapterList.FileAdapterName);
        fileAdapterList.FunctionName = string(fileAdapterList.FunctionName);
        fileAdapterList.DataType = string(fileAdapterList.DataType);
        fileFormats = fileAdapterList.SupportedFileTypes;
        fileFormats = cellfun(@(c) string(strjoin(c, ', ')), fileFormats);
        fileAdapterList.SupportedFileTypes = fileFormats;
    end
end

function fileAdapterList = convertToCharFields(registryEntries)
%convertToCharFields Return registry entries with char and cell text fields
%
%   The registry keeps text fields as strings. Callers of listFileAdapters
%   collect a field with braces and compare it with strcmp, which does not
%   match a string element, so the text fields are returned as char and
%   the file types as a cell array of char.
    fileAdapterList = reshape(registryEntries, [], 1);
    for i = 1:numel(fileAdapterList)
        fileAdapterList(i).FileAdapterName = char(fileAdapterList(i).FileAdapterName);
        fileAdapterList(i).FunctionName = char(fileAdapterList(i).FunctionName);
        fileAdapterList(i).SupportedFileTypes = cellstr(fileAdapterList(i).SupportedFileTypes);
        fileAdapterList(i).DataType = char(fileAdapterList(i).DataType);
    end
end
