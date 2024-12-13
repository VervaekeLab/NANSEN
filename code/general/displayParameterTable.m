function T = displayParameterTable(mFilePath)

    S = utility.convertParamsToStructArray(mFilePath);
    T = struct2table(S);
    
    filePathSplit = strsplit(mFilePath, filesep);
    isPackage = cellfun(@(c) strncmp(c, '+', 1), filePathSplit);
    filePathSplit = strrep(filePathSplit, '+', '');
    
    packageName = strjoin(filePathSplit(isPackage), '.');
    
    packageName = strrep(packageName, 'nansen.', '');
    packageName = strrep(packageName, '.getOptions', '');

    fprintf('\nDefault parameters and descriptions for: %s\n\n', packageName)
    disp(T)

    if ~nargout
        clear T
    end
end
