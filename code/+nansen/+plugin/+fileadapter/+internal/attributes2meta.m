function [fileAdapterMeta, adapterType] = attributes2meta(attributes)
%attributes2meta Convert file adapter dialog output to generator inputs
%
%   [fileAdapterMeta, adapterType] = attributes2meta(attributes) converts
%   the struct returned by uigetFileAdapterAttributes to the inputs that
%   nansen.plugin.fileadapter.createFileAdapter takes after the target
%   path.
%
%   Input Arguments:
%       attributes : Struct with the fields Name, Description,
%           SupportedFileTypes, DataType and AdapterType.
%
%   Output Arguments:
%       fileAdapterMeta : nansen.plugin.fileadapter.FileAdapterMeta object
%           holding the values of every field except AdapterType.
%       adapterType : "R" for a read only file adapter, "RW" for a file
%           adapter that reads and writes.
%
%   See also nansen.plugin.fileadapter.uigetFileAdapterAttributes
%   nansen.plugin.fileadapter.createFileAdapter

    arguments
        attributes (1,1) struct
    end

    adapterType = string(attributes.AdapterType);

    % AdapterType selects a template and is not a FileAdapterMeta property.
    metaProperties = rmfield(attributes, "AdapterType");
    fileAdapterMeta = nansen.plugin.fileadapter.FileAdapterMeta(metaProperties);
end
