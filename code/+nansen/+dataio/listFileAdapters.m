function fileAdapterList = listFileAdapters(fileExtension)
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
    
    % Todo: Ignore file adapters with a name that are already in the list
    % Todo: Start adding from project dir, then watchfolder, then internal?
    
    project = nansen.getCurrentProject();
    if isempty(project); fileAdapterList = struct.empty; return; end

    fileAdapterList = table2struct(project.getTable('FileAdapter'));

    if nargin < 1; fileExtension = ''; end
    if ~isempty(fileExtension); fileExtension = strrep(fileExtension, '.', ''); end
    
    if ~isempty(fileExtension)
        validationFcn = @(extList) any(contains(extList, fileExtension, "IgnoreCase", true));
        keep = arrayfun(@(s) validationFcn(s.SupportedFileTypes), ...
            fileAdapterList);
    else
        keep = true(1, numel(fileAdapterList));
    end
    
    fileAdapterList = fileAdapterList(keep);

    if isempty(fileAdapterList)
        fileAdapterList(1).FileAdapterName = 'N/A';
        fileAdapterList(1).FunctionName = '';
        fileAdapterList(1).SupportedFileTypes = {};
        fileAdapterList(1).DataType = '';
    end
end
