function value = getParameterValueFromString(parameterString)

    parameterString = strsplit(parameterString, '=');
    parameterValueStr = strtrim(parameterString{2});
    
    if isempty(parameterValueStr)
        warning('No value was found for parameter %s', parameterString{1})
    else
        value = eval(parameterValueStr);
    end
end
