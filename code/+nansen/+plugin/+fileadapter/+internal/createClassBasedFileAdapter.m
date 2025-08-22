function templateTargetPath = createClassBasedFileAdapter(templateFolder, targetFolder, fileAdapterAttributes)

    templateFolder = fullfile( templateFolder, 'class_templates');

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
    templateTargetPath = fullfile(targetFolder, ['@' fileAdapterAttributes.Name]);
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
    
    classdefStr = nansen.internal.templating.fillTemplate(...
        classdefStr, fileAdapterAttributes);

    % Create a new m-file and add the function template to the file.
    fid = fopen(newFilepath, 'w');
    fwrite(fid, classdefStr);
    fclose(fid);
end
