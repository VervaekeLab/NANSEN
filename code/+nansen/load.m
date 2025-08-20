function data = load(filePath, options)

    arguments
        filePath (1,1) string {mustBeFile}
        options.FileAdapter (1,1) string {mustBeFileAdapterIdentifier} = missing
    end

    if ismissing(options.FileAdapter)
        % todo: locate file adapter
        [~, ~, fileExtension] = fileparts(filePath);

        fileAdapterList = nansen.dataio.listFileAdapters();
        
        supportsFile = false(1, numel(fileAdapterList));
        % Find matching file type
        for i = 1:numel(fileAdapterList)
            currentFileAdapterInfo = fileAdapterList(i);

            if ismember(fileExtension, currentFileAdapterInfo.SupportedFileTypes) || ...
                ismember(extractAfter(fileExtension, '.'), currentFileAdapterInfo.SupportedFileTypes)
                supportsFile(i) = true;
            end
        end
        fileAdapterList = fileAdapterList(supportsFile);

        if isempty(fileAdapterList)
            error('No file adapters exist that can open files of type "%s"', fileExtension)
        elseif numel(fileAdapterList) > 1
            warning('Multiple matching file adapters. Todo: display list. Using first one. To use another file adapter, please specify the file adapter using the FileAdapter input')
        end
        fileAdapter = str2func(fileAdapterList(1).FunctionName);
    else
        fileAdapter = str2func(options.FileAdapter);
    end
    
    data = fileAdapter(filePath).load();
end

function mustBeFileAdapterIdentifier(fileAdapterIdentifier)

    arguments
        fileAdapterIdentifier
    end

    if ismissing(fileAdapterIdentifier); return; end
    
    % Todo: Check fileAdapterIdentifier.readData as a function
        
    assert(exist(fileAdapterIdentifier, "class"), ...
        'NANSEN:Validators:InvalidFileAdapterName', ...
        '"%s" is not the name of an existing MATLAB class', fileAdapterIdentifier)

    obj = feval(fileAdapterIdentifier);
    assert(isa(obj, 'nansen.dataio.FileAdapter'), ...
        'NANSEN:Validators:NotAFilAdapter', ...
        '"%s" is not the name of a FileAdapter class', fileAdapterIdentifier)
end
