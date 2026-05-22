function fileAdapterList = listFileAdapters(fileExtension, options)
%listFileAdapters Return a struct array of available file adapters.
%
%   fileAdapterList = nansen.dataio.listFileAdapters() returns all adapters
%     visible to the current project.
%
%   fileAdapterList = nansen.dataio.listFileAdapters(fileExtension) filters
%     to adapters that support the given extension (with or without a dot).
%
%   Each element of fileAdapterList has fields:
%       FileAdapterName     (char) : Class name of the adapter
%       FunctionName        (char) : Full MATLAB function/package name
%       SupportedFileTypes  (cell) : Supported file extensions
%       DataType            (char) : Data type returned on load
%       IsDynamic           (logical) : true for sidecar-based adapters
%
%   Optional name-value arguments:
%       Project - Project instance to query (defaults to current project)

    arguments
        fileExtension (1,1) string = ""
        options.Project = nansen.getCurrentProject()
    end

    if isempty(options.Project)
        fileAdapterList = struct.empty;
        return
    end

    fileAdapterList = options.Project.FileAdapterRegistry.list(fileExtension);

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
