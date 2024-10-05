function [hasMethod, methodAttributes] = ismethod(classObj, methodName)
    
    classMeta = metaclass(classObj);
    methodList = classMeta.MethodList;
    
    isMethodMatch = strcmp({methodList.Name}, methodName);
    hasMethod = any(isMethodMatch);

    if nargout > 1
        if hasMethod
            methodAttributes = methodList(isMethodMatch);
        else
            methodAttributes = struct.empty;
        end
    end
end
