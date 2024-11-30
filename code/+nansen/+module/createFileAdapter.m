function createFileAdapter(targetPath, fileAdapterAttributes)
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
    
    % Get path for template
    rootPath = fileparts(mfilename('fullpath'));
    templateFolder = fullfile( rootPath, 'resources', 'class_templates');

    if strcmp( fileAdapterAttributes.AccessMode, 'R' )
        sourceFolderName = '@FileAdapterR';
    elseif strcmp( fileAdapterAttributes.AccessMode, 'RW' )
        sourceFolderName = '@FileAdapterRW';
    else
        error('Expected fileAdapterAttributes.AccessMode to be "R" or "RW". Instead it was %s', ...
            fileAdapterAttributes.AccessMode)
    end

    % Copy template to target folder
    templateSourcePath = fullfile(templateFolder, sourceFolderName);
    templateTargetPath = fullfile(targetPath, ['@' fileAdapterAttributes.Name]);
    copyfile(templateSourcePath, templateTargetPath)

    % Rename classdef file
    oldFilePath = fullfile(templateTargetPath, 'FileAdapter.m.template');
    newFilepath = fullfile(templateTargetPath, [fileAdapterAttributes.Name '.m']);
    movefile(oldFilePath, newFilepath)

    % Also rename read (and write) template files
    oldTemplateFiles = utility.dir.recursiveDir(templateTargetPath, ...
        'Expression', '.m.template', 'OutputType', 'FilePath');
    newTemplateFiles = strrep(oldTemplateFiles, '.m.template', '.m');
    for i = 1:numel(oldTemplateFiles)
         movefile(oldTemplateFiles{i}, newTemplateFiles{i})
    end
    
    % Read file contents
    classdefStr = fileread(newFilepath);
    
    % Replace template variables
    templateVariableNames = fieldnames(fileAdapterAttributes);
    for i = 1:numel(templateVariableNames)
        
        thisName = templateVariableNames{i};
        thisValue = fileAdapterAttributes.(thisName);

        expression = sprintf('{{%s}}', thisName);
        if ~strcmp(thisName, 'Name')
            replacement = getStringRepresentation( thisValue );
        else
            replacement = thisValue;
        end
        classdefStr = strrep(classdefStr, expression, replacement);
    end

    % Create a new m-file and add the function template to the file.
    fid = fopen(newFilepath, 'w');
    fwrite(fid, classdefStr);
    fclose(fid);
    
    % Finally, open the function in the matlab editor.
    edit(fullfile(templateTargetPath, 'read.m'))
    
    if strcmp( fileAdapterAttributes.AccessMode, 'RW' )
        edit(fullfile(templateTargetPath, 'write.m'))
    end
end

function strValue = getStringRepresentation(value)
    
    if isa(value, 'char') || isa(value, 'string')
        strValue = sprintf('''%s''', value);
    elseif isnumeric(value)
        strValue = num2str(value);
    elseif islogical(value)
        if value
            strValue = 'true';
        else
            strValue = 'false';
        end
    elseif isa(value, 'cell')
        value = cellfun(@(v) getStringRepresentation(v), value, 'uni', 0);
        strValue = cellArrayToTextString(value);
    else
        error('Value of type %s is not supported', class(value));
    end
end

function textStr = cellArrayToTextString(cellArray)
%cellArrayToTextString Create a text string representing the cell array
    cellOfPaddedStrings = cellfun(@(c) c, cellArray, 'UniformOutput', false);
    textStr = sprintf('{%s}', strjoin(cellOfPaddedStrings, ', '));
end
