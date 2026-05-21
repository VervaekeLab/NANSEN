function funcHandles = getCustomTableVariableFcn(varNames, projectName, tableType)
%getCustomTableVariableFcn Return function handles for custom table variable constructors.
%
%   funcHandles = getCustomTableVariableFcn(varNames) returns a function
%   handle (or cell array of handles) for each variable name. Each handle
%   constructs the corresponding TableVariable instance when called with
%   no arguments.
%
%   funcHandles = getCustomTableVariableFcn(varNames, ~, tableType) filters
%   by table type ('session' or 'subject'). The second argument (projectName)
%   is accepted for backward compatibility but is not used; the active project
%   is resolved via nansen.getCurrentProject.
%
%   funcHandles = getCustomTableVariableFcn() returns handles for all
%   variables of the default ('session') table type.

    arguments
        varNames    = []
        projectName = []    % ignored; kept for backward compatibility
        tableType   (1,1) string = "session"
    end

    funcHandles = {};

    project = nansen.getCurrentProject();
    if isempty(project); return; end

    rootPaths = nansen.plugin.tablevariable.Registry.collectRootPaths(project);
    if isempty(rootPaths); return; end

    registry = nansen.plugin.tablevariable.Registry(rootPaths);
    allSpecs = registry.listByTableType(tableType);

    if isempty(allSpecs); return; end

    % When no variable names are given, return handles for all discovered vars.
    if isempty(varNames)
        varNames = arrayfun(@(s) char(s.VariableName), allSpecs, 'uni', false);
    elseif ischar(varNames) || isstring(varNames)
        varNames = {char(varNames)};
    end

    % Build a lower-case name → spec index map for fast lookup.
    allNames = arrayfun(@(s) lower(char(s.VariableName)), allSpecs, 'uni', false);

    funcHandles = cell(1, numel(varNames));
    for i = 1:numel(varNames)
        idx = find(strcmpi(varNames{i}, allNames), 1);
        if ~isempty(idx)
            entrypoint = char(allSpecs(idx).Implementation.entrypoint);
            funcHandles{i} = str2func(entrypoint);
        else
            % Fallback for variables not yet in the registry: construct the
            % function name the old way. This keeps existing project-package
            % table variables working before their sidecars are generated.
            if ~isempty(projectName)
                pkgName = char(projectName);
            else
                pkgName = char(project.Name);
            end
            funcHandles{i} = str2func(strjoin( ...
                {pkgName, 'tablevariable', char(tableType), varNames{i}}, '.'));
        end
    end

    if isscalar(funcHandles)
        funcHandles = funcHandles{1};
    end
end
