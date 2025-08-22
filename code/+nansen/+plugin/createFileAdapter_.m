function results = createFileAdapter_(options)

    arguments
        options.?nansen.dataio.fileadapter.FileAdapterMeta
    end
    
    options = nansen.dataio.fileadapter.FileAdapterMeta(options);

    try
        currentProject = nansen.getCurrentProject();
    catch
        currentProject = [];
    end

    if isempty(currentProject)
    end

    results = options;
end
