function [formatterFcnHandle, varNames] = getColumnFormatter(varNames, tableClass)
%getColumnFormatter Get function handle for table column formatter/renderer
%
%   formatterFcnHandle = getColumnFormatter() return function
%   handles for all available column formatters/renderers. 
%
%   formatterFcnHandle = getColumnFormatter(varNames) return function
%   handles for all column formatters that match the given list of variable 
%   names (varNames).
%
%   formatterFcnHandle = getColumnFormatter(varNames, tableClass, scope) 
%   looks in the specified scope. Scope can be 'builtin' (for nansen 
%   builtin table variables), 'project' (for current project). Default is 
%   to look in both scopes. The project scope takes precedence over the 
%   builtin scope, so if a column formatter exists both in the builtins
%   and in the project, the project's column formatter is returned.
% 
%   A column formatter is any class that inherits from the 
%   nansen.metadata.abstract.TableVariable class
    
% Todo. Turn this into an enumeration class similar to
% uiw.enum.TableColumnFormat?

    % Set default variables.
    if nargin < 1 || isempty(varNames); varNames = {}; end
    if nargin < 2 || isempty(tableClass); tableClass = 'session'; end
    currentNansenProject = nansen.ProjectManager().getCurrentProject();
    tableVariablesAttributes = currentNansenProject.getTable('TableVariable');

    % Filter by variable names
    if ~isempty(varNames)
        [~, iA] = intersect(tableVariablesAttributes.Name, varNames, 'stable');
        tableVariablesAttributes = tableVariablesAttributes(iA, :);
    end

    % Filter by table type
    if ~isempty(tableClass)
        isMember = tableVariablesAttributes.TableType == string(tableClass);
        tableVariablesAttributes = tableVariablesAttributes(isMember, :);
    end

    hasFormatter = tableVariablesAttributes.HasRendererFunction;
    fcnNames = tableVariablesAttributes.RendererFunctionName(hasFormatter);
    formatterFcnHandle = cellfun(@str2func, fcnNames, 'UniformOutput', false);
    if nargout == 2
        varNames = tableVariablesAttributes.Name(hasFormatter);
    else
        clear varNames
    end
end
