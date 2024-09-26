function [S, wasAborted] = uigetFileAdapterAttributes(varargin)
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

    S = utility.parsenvpairs(S, [], varargin{:});

    % Add configuration flags
    S.AccessMode_ = {'Read', 'Read/Write'};

    [S, wasAborted] = tools.editStruct(S, '', 'Create File Adapter', ...
        'Prompt', 'Configure new file adapter:');

    if wasAborted; S = struct.empty; return; end
    
    S.SupportedFileTypes = strsplit(S.SupportedFileTypes, ',');
    if strcmp(S.AccessMode, 'Read')
        S.AccessMode = 'R';
    elseif strcmp(S.AccessMode, 'Read/Write')
        S.AccessMode = 'RW';
    end
end

% Todo:
%   [ ] Output a struct with 3 fields: Name, Attributes, Configuration:
%
%     S = struct();
%     S.Name = S_.Name;
%
%     S.Attributes = struct();
%     S.Attributes.SupportedFileTypes = strsplit(S_.SupportedFileTypes, ',');
%     S.Attributes.DataType = S_.DataType;
%
%     S.Configuration = struct();
%     if strcmp(S_.AccessMode, 'Read')
%         S.Configuration.AccessMode = 'R';
%     elseif strcmp(S_.AccessMode, 'Read/Write')
%         S.Configuration.AccessMode = 'RW';
%     end
