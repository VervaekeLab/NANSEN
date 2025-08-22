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
    elseif numel(fileAdapterList) > 1
        fileAdapterNames = {fileAdapterList.FunctionName};
        fileAdapterNames = nansen.util.text.strArrayToBulletList(fileAdapterNames);

        % warning(...
        %     ['Multiple matching file adapters: \n%s\n Using first one. ', ...
        %     'To use another file adapter, please specify the file ', ...
        %     'adapter using the "FileAdapter" input'], fileAdapterNames)
    end
    fileAdapterName = fileAdapterList(1).FunctionName;
    isDynamic = fileAdapterList(1).IsDynamic;
end
