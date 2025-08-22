function templateTargetPath = createClassBasedFileAdapter(templateFolder, targetFolder, fileAdapterInfo, adapterType)

    templateFolder = fullfile( templateFolder, 'class_templates');

    if strcmp( adapterType, 'R' )
        sourceFolderName = '@FileAdapterR';
    elseif strcmp( adapterType, 'RW' )
        sourceFolderName = '@FileAdapterRW';
    else
        error('Expected fileAdapterAttributes.AccessMode to be "R" or "RW". Instead it was %s', ...
            adapterType)
    end

    % Copy template to target folder
    templateSourcePath = fullfile(templateFolder, sourceFolderName);
    templateTargetPath = fullfile(targetFolder, sprintf("@%s", fileAdapterInfo.Name));
    copyfile(templateSourcePath, templateTargetPath)

    % Rename classdef file
    oldFilePath = fullfile(templateTargetPath, 'FileAdapter.m.template');
    newFilepath = fullfile(templateTargetPath, fileAdapterInfo.Name + ".m");
    movefile(oldFilePath, newFilepath)

    % Also rename read (and write) template files
    oldTemplateFiles = utility.dir.recursiveDir(templateTargetPath, ...
        'Expression', '.m.template', 'OutputType', 'FilePath');
    newTemplateFiles = strrep(oldTemplateFiles, '.m.template', '.m');
    for i = 1:numel(oldTemplateFiles)
         movefile(oldTemplateFiles{i}, newTemplateFiles{i})
    end
    
    fileAdapterInfo = fileAdapterInfo.toStruct();
    fileAdapterInfo = fileAdapterInfo.Properties;

    fileAdapterInfo.SupportedFileTypes = cellstr(fileAdapterInfo.SupportedFileTypes);

    % Read file contents
    classdefStr = fileread(newFilepath);
    
    classdefStr = nansen.internal.templating.fillTemplate(...
        classdefStr, fileAdapterInfo);

    % Create a new m-file and add the function template to the file.
    fid = fopen(newFilepath, 'w');
    fwrite(fid, classdefStr);
    fclose(fid);
end
