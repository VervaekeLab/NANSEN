function [fileAdapterName, isDynamic] = detectFileAdapterForFilepath(filePath)
% detectFileAdapterForFilepath - Locate file adapter for a given filename and extension

    fileAdapterList = nansen.dataio.listFileAdapters();

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
    end

    fileAdapterName = fileAdapterList(1).FunctionName;
    isDynamic = fileAdapterList(1).IsDynamic;
end
