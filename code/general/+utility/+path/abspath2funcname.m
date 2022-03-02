function functionName = abspath2funcname(pathStr)
%abspath2func Get function name for mfile given as pathstr

    % Get function name, taking package into account
    [folderPath, functionName, ext] = fileparts(pathStr);
    
    assert(strcmp(ext, '.m'), 'pathStr must point to a .m (function) file')
    
    packageName = utility.path.pathstr2packagename(folderPath);
    functionName = strcat(packageName, '.', functionName);
    
    
    % Add package-containing folder to path if it is not...
    
    %fcnHandle = str2func(functionName);

end