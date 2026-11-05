function value = getConstantPropertyValue(className, propertyName)
% getConstantPropertyValue - Get the value of a Constant property by class name string.
%
%   value = nansen.internal.introspection.getConstantPropertyValue(className, propertyName)
%   returns the value of the Constant property named propertyName on the class
%   identified by the string className. This is the safe replacement for
%   eval(sprintf('%s.%s', className, propertyName)).
%
%   Input Arguments:
%     className    - Fully qualified class name (string or char)
%     propertyName - Name of a Constant property on that class (string or char)
%
%   Output Arguments:
%     value - Value of the Constant property

    arguments
        className    (1,1) string
        propertyName (1,1) string
    end

    mc = meta.class.fromName(className);
    if isempty(mc)
        error('nansen:introspection:ClassNotFound', ...
            'Class "%s" was not found. Ensure the class is on the MATLAB path.', className)
    end

    matchIdx = strcmp({mc.PropertyList.Name}, propertyName);
    if ~any(matchIdx)
        error('nansen:introspection:PropertyNotFound', ...
            'Class "%s" has no property named "%s".', className, propertyName)
    end

    prop = mc.PropertyList(matchIdx);
    if ~prop.Constant
        error('nansen:introspection:NotConstant', ...
            'Property "%s.%s" is not Constant.', className, propertyName)
    end

    value = prop.DefaultValue;
end
