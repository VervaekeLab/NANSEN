function targetFolder = createFunctionBasedFileAdapter(templateFolder, targetFolder, fileAdapterInfo, adapterType)

    targetFolder = fullfile(targetFolder, "+" + fileAdapterInfo.Name);
    if ~isfolder(targetFolder)
        mkdir(targetFolder);
    end
    
    templateFolder = fullfile( templateFolder, 'function_template');

    % Also rename read (and write) template files
    if strcmp(fileAdapterInfo.ReadFunction, "")
        readTemplateFile = fullfile(templateFolder, 'read.m.template');
        readTargetFile = fullfile(targetFolder, 'read.m');
        copyfile(readTemplateFile, readTargetFile)
    end
    if strcmp(fileAdapterInfo.WriteFunction, "") && adapterType == "RW"
        writeTemplateFile = fullfile(templateFolder, 'write.m.template');
        writeTargetFile = fullfile(targetFolder, 'write.m');
        copyfile(writeTemplateFile, writeTargetFile)
    end

    jsonStr = fileAdapterInfo.toJson();
    targetFile = fullfile(targetFolder, 'fileadapter.json');

    utility.filewrite(targetFile, jsonStr)
end
