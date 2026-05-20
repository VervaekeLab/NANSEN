function fileAdapterList = listFileAdapters(fileExtension)
%listFileAdapters Return a struct array of available file adapters.
%
%   fileAdapterList = nansen.dataio.listFileAdapters() returns all adapters.
%   fileAdapterList = nansen.dataio.listFileAdapters(fileExtension) filters
%     to adapters that support the given extension (with or without a dot).
%
%   Each element of fileAdapterList has:
%     FileAdapterName     - Human-readable name (char)
%     FunctionName        - MATLAB constructor function name (char)
%     SupportedFileTypes  - Supported extensions (cell of char)
%     DataType            - Data type returned on load (char)

    if nargin < 1
        fileExtension = '';
    end

    registry = nansen.plugin.fileadapter.Registry.getInstance();
    fileAdapterList = registry.listLegacy(string(fileExtension));
end
