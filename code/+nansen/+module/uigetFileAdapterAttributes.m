function S = uigetFileAdapterAttributes()
%uigetFileAdapterAttributes Open dialog for selecting file adapter options.
%
%   S = uigetFileAdapterAttributes() opens dialog and returns a struct S
%   with file adapter attributes.
%
%   S is a struct containing the following fields:
%       Name : Name of file adapter
%       SupportedFileTypes : Cell array of file extensions for files which this
%           file adapter can be used with
%       DataType : Expected output data type
%       AccessMode : Whether file adapter supports read only (R) or read and write (RW) 

    S = struct();
    S.Name = '';
    S.SupportedFileTypes = '';
    S.DataType = '';
    S.AccessMode = 'Read';
    S.AccessMode_ = {'Read', 'Read/Write'};

    S = tools.editStruct(S);

    S.SupportedFileTypes = strsplit(S.SupportedFileTypes, ',');
    if strcmp(S.AccessMode, 'Read')
        S.AccessMode = 'R';
    elseif strcmp(S.AccessMode, 'Read/Write')
        S.AccessMode = 'RW';
    end

end