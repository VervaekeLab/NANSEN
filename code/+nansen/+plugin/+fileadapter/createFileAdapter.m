function createFileAdapter(targetPath, fileAdapterAttributes, implementationType)
%createFileAdapter Create a new file adapter definition
%
%   createFileAdapter(targetPath, fileAdapterAttributes) creates a new file
%   adapter class based on a template and saves it to the targetPath.
%   targetPath is the absolute path to a folder. fileAdapterAttributes is a
%   struct containing the following fields:
%       Name : Name of file adapter
%       SupportedFileTypes : Cell array of file extensions for files which this
%           file adapter can be used with
%       DataType : Expected output data type
%       AccessMode : Whether file adapter supports read only (R) or read and write (RW)
%
%   Input Arguments:
%       targetPath : Pathname of folder to save file adapter in.
%       fileAdapterAttributes Struct with file adapter attributes

%     arguments
%         targetPath (1,1) string : Folder to save file adapter in.
%         fileAdapterAttributes (1,1) struct Struct with file adapter
%         attributes
%     end

    if nargin < 3 || isempty(implementationType)
        implementationType = "Function";
    end
    
    % Get path for template
    rootPath = fileparts(mfilename('fullpath'));
    templateFolder = fullfile( rootPath, 'resources');

    if implementationType == "Function"
        templateTargetPath = ...
            nansen.plugin.fileadapter.internal.createFunctionBasedFileAdapter(...
                templateFolder, targetPath, fileAdapterAttributes ...
            );

    elseif implementationType == "Class"
        templateTargetPath = ...
            nansen.plugin.fileadapter.internal.createClassBasedFileAdapter(...
                templateFolder, targetPath, fileAdapterAttributes ...
            );
    else
        error('NANSEN:CreateFileAdapter:UnsupportedArgument', ...
            'Expected implementationType to be "Function" or "Class" but got "%s"', ...
            implementationType)
    end

    % Finally, open the function in the matlab editor.
    cd(templateTargetPath)
    edit(fullfile(templateTargetPath, 'read.m'))
    
    if isfile(fullfile(templateTargetPath, 'write.m'))
        edit(fullfile(templateTargetPath, 'write.m'))
    end
end
