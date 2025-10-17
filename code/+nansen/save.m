function save(filePath, data, options)

    arguments
        filePath (1,1) string % {mustBeFile}
        data
        options.FileAdapter (1,1) string {mustBeFileAdapterIdentifier} = missing
    end

    fileAdapterList = nansen.dataio.listFileAdapters();

    if ismissing(options.FileAdapter)
        [fileAdapterName, isDynamic] = ...
            nansen.plugin.fileadapter.internal.detectFileAdapterForFilepath(filePath);

    else
        fileAdapterName = options.FileAdapter;
        if contains(fileAdapterName, 'fileadapter.')
            isMatch = strcmp(fileAdapterName, {fileAdapterList.FunctionName});
        elseif ~contains(fileAdapterName, '.')
            isMatch = strcmp(fileAdapterName, {fileAdapterList.FileAdapterName});
            fileAdapterName = fileAdapterList(isMatch).FunctionName;
        else
            error('"%s" is not the name of a file adapter', fileAdapterName)
        end
        isDynamic = fileAdapterList(isMatch).IsDynamic;
    end


    if isDynamic
        nansen.dataio.DynamicFileAdapter(fileAdapterName, filePath).save(data);
    else
        fileAdapterFcn = str2func(fileAdapterName);
        fileAdapterFcn(filePath).save(data);
    end
end

function mustBeFileAdapterIdentifier(fileAdapterIdentifier)

    arguments
        fileAdapterIdentifier
    end

    if ismissing(fileAdapterIdentifier); return; end
    return
    % Todo: Check fileAdapterIdentifier.readData as a function
        
    assert(exist(fileAdapterIdentifier, "class"), ...
        'NANSEN:Validators:InvalidFileAdapterName', ...
        '"%s" is not the name of an existing MATLAB class', fileAdapterIdentifier)

    obj = feval(fileAdapterIdentifier);
    assert(isa(obj, 'nansen.dataio.FileAdapter'), ...
        'NANSEN:Validators:NotAFilAdapter', ...
        '"%s" is not the name of a FileAdapter class', fileAdapterIdentifier)
end
