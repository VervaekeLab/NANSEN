function data = load(filePath, options)

    arguments
        filePath (1,1) string % {mustBeFile}
        options.FileAdapter (1,1) string {mustBeFileAdapterIdentifier} = missing
    end

    fileAdapterList = nansen.dataio.listFileAdapters();

    if ismissing(options.FileAdapter)
        % todo: locate file adapter
        [~, ~, fileExtension] = fileparts(filePath);

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
            fileAdapterNames = {fileAdapterList.FunctionName};
            fileAdapterNames = " - " + string(fileAdapterNames);
            fileAdapterNames = strjoin(fileAdapterNames, newline);
            % warning(...
            %     ['Multiple matching file adapters: \n%s\n Using first one. ', ...
            %     'To use another file adapter, please specify the file ', ...
            %     'adapter using the "FileAdapter" input'], fileAdapterNames)
        end
        fileAdapterName = fileAdapterList(1).FunctionName;
        isDynamic = fileAdapterList(1).IsDynamic;
    else
        fileAdapterName = options.FileAdapter;
        isMatch = strcmp(fileAdapterName, {fileAdapterList.FunctionName});
        isDynamic = fileAdapterList(isMatch).IsDynamic;
    end

    if isDynamic
        data = nansen.dataio.DynamicFileAdapter(fileAdapterName, filePath).load();
    else
        fileAdapterFcn = str2func(fileAdapterName);
        data = fileAdapterFcn(filePath).load();
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
