function assertSingleVersionOnPath(functionName)
% assertSingleVersionOnPath - Assert single version of a function/class on the search path
    arguments
        functionName (1,1) string
    end

    if endsWith(functionName, '.m')
        functionName = extractBefore(functionName, '.m');
    end

    result = string( which(functionName, "-all") );

    if contains(functionName, '.')
        % If this is a function with namespaces, we need to convert it to a
        % relative path for "which <function name> -all" to find all
        % instances. We use the result of the previous call to which to ensure 
        % class names are expanded properly (e.g if they are wrapped in class
        % folders (@classname))
        functionRelativePath = "+" + extractAfter(result, '+');
        result = string( which(char(functionRelativePath), '-all') );
    end

    result = unique(result);

    if isscalar(result)
        return
    else
        if isempty(result)
            exception = MException('NANSEN:Validation:NoVersionsOnPath', ...
                ['No versions of "%s" was found on MATLAB''s ', ...
                'search path. Please add "%s" to the search path and try again.'], ...
                functionName, functionName);

        elseif ~isscalar(result)
            pathNameList = " - " + result;
    
            exception = MException('NANSEN:Validation:MultipleVersionsOnPath', ...
                ['Multiple versions of "%s" was found on MATLAB''s ', ...
                'search path. "%s" exists in the following locations:\n%s\n\n', ...
                'Please ensure you only have one version of "%s" on the search path.'], ...
                functionName, functionName, strjoin(pathNameList, newline), functionName);
        end
        throwAsCaller(exception)
    end
end
