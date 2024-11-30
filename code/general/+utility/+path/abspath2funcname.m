function functionName = abspath2funcname(pathStr)
%abspath2func Get function name for mfile given as pathstr

    if isa(pathStr, 'cell')
        functionName = cellfun(@(c) utility.path.abspath2funcname(c), pathStr, 'UniformOutput', false);
        return
    elseif isa(pathStr, 'string') && numel(pathStr) > 1
        functionName = arrayfun(@(str) utility.path.abspath2funcname(str), pathStr, 'UniformOutput', false);
        return
    end

    % Get function name, taking package into account
    [folderPath, functionName, ext] = fileparts(pathStr);
    
    assert(strcmp(ext, '.m'), 'pathStr must point to a .m (function) file')
    
    packageName = utility.path.pathstr2packagename(folderPath);
    functionName = strcat(packageName, '.', functionName);
    
    % Add package-containing folder to path if it is not...
    
    %fcnHandle = str2func(functionName);

end
