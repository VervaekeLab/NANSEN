function defaultSessionTableVariableList = getDefaultSessionVariables()
%getDefaultSessionVariables Get variables from session class

    % Todo: Deprecate the need for this.
    
    className = 'nansen.metadata.type.Session';
    mc = meta.class.fromName(className);
    
    isStatic = [mc.PropertyList.Constant];
    isTransient = [mc.PropertyList.Transient];
    keep = ~isStatic & ~isTransient;

    defaultSessionTableVariableList = {mc.PropertyList(keep).Name};
end