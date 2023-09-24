function defaultSessionTableVariableList = getDefaultSessionVariables()
%getDefaultSessionVariables Get variables from session class

    % Todo: Deprecate the need for this. Code should be adapted to work for
    % any metadata type...
    
    className = 'nansen.metadata.type.Session';
    mc = meta.class.fromName(className);
    
    isStatic = [mc.PropertyList.Constant];
    isTransient = [mc.PropertyList.Transient];
    keep = ~isStatic & ~isTransient;

    defaultSessionTableVariableList = {mc.PropertyList(keep).Name};
end