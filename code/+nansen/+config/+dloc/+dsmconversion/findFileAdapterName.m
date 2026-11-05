function adapterName = findFileAdapterName(fileType, fileAdapterList)
%findFileAdapterName Name of the file adapter for the longest ending of a file type that has one
%
%   Syntax:
%       adapterName = findFileAdapterName(fileType, fileAdapterList)
%
%   Returns the FileAdapterName of the first adapter in fileAdapterList
%   whose SupportedFileTypes include fileType, compared without case and
%   without a leading dot. A file type of several parts that no adapter
%   supports is tried again without its first part, until one part is
%   left: .ome.tif is tried as ome.tif, then as tif. The longest supported
%   ending is used, as detectFileAdapterForFilepath does for a file name,
%   so .nii.gz goes to an adapter for nii.gz before one for gz. Returns ""
%   when no ending of fileType is supported.
%
%   Input arguments:
%       fileType        - A file type such as .tif or .ome.tif.
%       fileAdapterList - Struct array with the fields FileAdapterName and
%                         SupportedFileTypes, as nansen.dataio.listFileAdapters
%                         returns.

    arguments
        fileType (1,1) string
        fileAdapterList struct
    end

    adapterName = "";
    if strlength(fileType) == 0
        return
    end

    parts = reshape(split(regexprep(fileType, "^\.", ""), "."), 1, []);
    for k = 1:numel(parts)
        ending = strjoin(parts(k:end), ".");
        for adapter = reshape(fileAdapterList, 1, [])
            supportedTypes = regexprep(string(adapter.SupportedFileTypes), "^\.", "");
            if any(strcmpi(supportedTypes, ending))
                adapterName = string(adapter.FileAdapterName);
                return
            end
        end
    end
end
