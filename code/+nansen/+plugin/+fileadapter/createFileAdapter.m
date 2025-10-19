function createFileAdapter(targetPath, fileAdapterMeta, adapterType)
%createFileAdapter Create a new file adapter definition
%
%   createFileAdapter(targetPath, fileAdapterMeta) creates a new file
%   adapter definition based on a template and saves it to the targetPath.
%   targetPath is the absolute path to a folder. fileAdapterMeta is an
%   object of nansen.plugin.fileadapter.FileAdapterMeta
%
%   Input Arguments:
%       targetPath : Pathname of folder to save file adapter in.
%       fileAdapterMeta : Object with file adapter metadata 

    arguments
        targetPath (1,1) string % Folder to save file adapter in.
        fileAdapterMeta (1,1) nansen.plugin.fileadapter.FileAdapterMeta % Fileadapter metadata 
        adapterType (1,1) string = "R"
    end

    
    % Get path for template
    rootPath = fileparts(mfilename('fullpath'));
    templateFolder = fullfile( rootPath, 'resources');

    if fileAdapterMeta.ImplementationType == "Function"
        templateTargetPath = ...
            nansen.plugin.fileadapter.internal.createFunctionBasedFileAdapter(...
                templateFolder, targetPath, fileAdapterMeta, adapterType ...
            );

    elseif fileAdapterMeta.ImplementationType == "Class"
        templateTargetPath = ...
            nansen.plugin.fileadapter.internal.createClassBasedFileAdapter(...
                templateFolder, targetPath, fileAdapterMeta, adapterType ...
            );
    else
        error('NANSEN:CreateFileAdapter:UnsupportedArgument', ...
            'Expected implementationType to be "Function" or "Class" but got "%s"', ...
            fileAdapterMeta.ImplementationType)
    end

    % Finally, open the function in the matlab editor.
    cd(templateTargetPath)
    edit(fullfile(templateTargetPath, 'read.m'))
    
    if isfile(fullfile(templateTargetPath, 'write.m'))
        edit(fullfile(templateTargetPath, 'write.m'))
    end
end
