function createFileAdapter(options)

    arguments
        options.?nansen.plugin.fileadapter.FileAdapterMeta
    end
    
    try
        options = nansen.plugin.fileadapter.FileAdapterMeta(options);
    catch ME
        throwAsCaller(ME)
    end

    if strcmpi(options.ImplementationType, 'class')
        error('Not implemented yet.')
    end

    fileAdapterTargetFolder = nansen.plugin.getPluginTargetFolder('fileadapter');

    nansen.plugin.fileadapter.createFileAdapter(...
        fileAdapterTargetFolder, options, "Function")
end
