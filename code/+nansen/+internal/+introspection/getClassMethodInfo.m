function methodInfo = getClassMethodInfo(metaclassObject, methodName, options)
% getClassMethodInfo - Get a table of attribute values for specified methods of a class.
%
%   methodInfo = nansen.internal.introspection.getClassMethodInfo(metaclassObject, methodName)
%   returns a table where each row corresponds to one of the specified
%   methods and each column corresponds to a meta.method attribute.
%
%   methodInfo = nansen.internal.introspection.getClassMethodInfo(metaclassObject, methodName, AttributeName=names)
%   returns only the attributes listed in names.
%
%   Input Arguments:
%     metaclassObject - A meta.class object (e.g. from metaclass(obj))
%     methodName      - One or more method names (string array)
%     AttributeName   - (optional) Attribute names to include in the output
%
%   Output Arguments:
%     methodInfo - Table of method attributes, with method names as row names

    arguments
        metaclassObject (1,1) meta.class
        methodName (1,:) string
        options.AttributeName (1,:) string = string.empty
    end

    allMethodNames = string({metaclassObject.MethodList.Name});
    matchIdx = ismember(allMethodNames, methodName);
    methodInfo = metaclassObject.MethodList(matchIdx);

    missingMethods = methodName(~ismember(methodName, allMethodNames));
    assert(numel(methodInfo) == numel(methodName), ...
        'NANSEN:Introspection:GetClassMethodInfo', ...
        'The following methods are not defined in class "%s": %s', ...
        metaclassObject.Name, strjoin(missingMethods, ', '))

    % Determine which attributes to include
    if ~isempty(options.AttributeName)
        attributeNames = options.AttributeName;
    else
        attributeNames = string(properties(methodInfo(1)));
    end

    % Extract attribute values for each method into a cell array
    nMethods = numel(methodInfo);
    nAttribs = numel(attributeNames);
    dataCell = cell(nMethods, nAttribs);

    for i = 1:nMethods
        for j = 1:nAttribs
            dataCell{i, j} = methodInfo(i).(attributeNames(j));
        end
    end

    % Return as table
    methodInfo = cell2table(dataCell, 'VariableNames', cellstr(attributeNames), ...
        'RowNames', cellstr(methodName));
end
