function fileAdapterList = listFileAdapters(fileExtension, refresh)
%listFileAdapters Create a list of file adapters
%
%   fileAdapterList = nansen.dataio.listFileAdapters() returns a struct
%   array containing information about file adapters.
%
%   The fileAdapterList struct array contains the following fields:
%       FileAdapterName     (char) : Name of fileadapter
%       FunctionName        (char) : Name of function for file adapter
%       SupportedFileTypes  (cell) : File types that are supported with this fileadapter
%       DataType            (char) : Name of datatype returned by this file adapter

    fileAdapterList = nansen.dataio.FileAdapterRegistry.listAdapters();
end
