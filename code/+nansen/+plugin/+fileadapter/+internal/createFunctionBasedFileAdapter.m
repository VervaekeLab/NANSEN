function targetFolder = createFunctionBasedFileAdapter(templateFolder, targetFolder, fileAdapterAttributes)

    targetFolder = fullfile(targetFolder, "+" + fileAdapterAttributes.Name);
    if ~isfolder(targetFolder)
        mkdir(targetFolder);
    end
    
    templateFolder = fullfile( templateFolder, 'function_template');

    % Also rename read (and write) template files
    readTemplateFile = fullfile(templateFolder, 'read.m.template');
    readTargetFile = fullfile(targetFolder, 'read.m');

    copyfile(readTemplateFile, readTargetFile)

    jsonStr =fileAdapterAttributes.toJson();
    targetFile = fullfile(targetFolder, 'fileadapter.json');

    utility.filewrite(targetFile, jsonStr)
end
