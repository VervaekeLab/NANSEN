function [fileAdapterName, isDynamic] = detectFileAdapterForFilepath(filePath, fileAdapterList)
% detectFileAdapterForFilepath - Locate file adapter for a given filename and extension
%
%   [fileAdapterName, isDynamic] = detectFileAdapterForFilepath(filePath)
%   returns the first file adapter of nansen.dataio.listFileAdapters()
%   that supports the file. An adapter supports a file whose name ends
%   with one of its SupportedFileTypes, so a type of several parts, such
%   as nii.gz, is matched as well. Where several adapters support the
%   file, one with the longest matching type is used (nii.gz before gz).
%   Case is ignored, as in listFileAdapters.
%
%   ... = detectFileAdapterForFilepath(filePath, fileAdapterList) looks in
%   the given list, a struct array with the fields of listFileAdapters.

    if nargin < 2
        fileAdapterList = nansen.dataio.listFileAdapters();
    end

    [~, fileName, fileExtension] = fileparts(filePath);
    fileName = string(fileName) + string(fileExtension);

    % Length of each adapter's longest supported type that the name ends with
    matchLength = zeros(1, numel(fileAdapterList));
    for i = 1:numel(fileAdapterList)
        fileTypes = "." + regexprep(string(fileAdapterList(i).SupportedFileTypes), '^\.', '');
        isMatch = endsWith(fileName, fileTypes, 'IgnoreCase', true);
        if any(isMatch)
            matchLength(i) = max(strlength(fileTypes(isMatch)));
        end
    end
    fileAdapterList = fileAdapterList(matchLength > 0 & matchLength == max(matchLength));

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
