function defaultTableVariableList = getDefaultTableVariables(className)
%getDefaultTableVariables Get variables from a specified metadata class

    if nargin < 1 || isempty(className)
        className = 'nansen.metadata.type.Session';
    end
    simpleClassName = utility.string.getSimpleClassName(className);

    mc = meta.class.fromName(className);
    % Todo: Check whether the BaseSchema is a superclass?
    
    isStatic = [mc.PropertyList.Constant];
    isTransient = [mc.PropertyList.Transient];
    isPublic = strcmp({mc.PropertyList.SetAccess}, 'public');
    keep = ~isStatic & ~isTransient & isPublic;

    defaultTableVariableNames = {mc.PropertyList(keep).Name};

    defaultTableVariableList = struct('Name', defaultTableVariableNames);
    [defaultTableVariableList(:).TableType] = deal( lower(simpleClassName) );
end
