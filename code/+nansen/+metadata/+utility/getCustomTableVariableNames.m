function varNames = getCustomTableVariableNames(tableClassName)
%getCustomTableVariableNames Get names of custom tablevars for current project
%
%   varNames = getCustomTableVariableNames() returns the simple variable
%   names (column headers) for all 'session' table variables defined by
%   the current project.
%
%   varNames = getCustomTableVariableNames(tableClassName) returns variables
%   for the given table type ('session' or 'subject').

    arguments
        tableClassName (1,1) string = 'session';
    end

    varNames = string.empty;

    project = nansen.getCurrentProject();
    if isempty(project); return; end

    rootPaths = nansen.plugin.tablevariable.Registry.collectRootPaths(project);
    if isempty(rootPaths); return; end

    registry = nansen.plugin.tablevariable.Registry(rootPaths);
    specs    = registry.listByTableType(tableClassName);

    if isempty(specs); return; end
    varNames = arrayfun(@(s) s.VariableName, specs);
end
