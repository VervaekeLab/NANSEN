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
%   formatterFcnHandle = getColumnFormatter(varNames, tableClass)
%   looks in the specified scope.
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

    keep = true(height(tableVariablesAttributes), 1);

    % Filter by variable names
    if ~isempty(varNames)
        keep = keep & ismember( tableVariablesAttributes.Name, varNames);
    end

    % Filter by table type
    if ~isempty(tableClass)
        keep = keep & tableVariablesAttributes.TableType == string(tableClass);
    end

    tableVariablesAttributes = tableVariablesAttributes(keep, :);

    hasFormatter = tableVariablesAttributes.HasRendererFunction;
    fcnNames = tableVariablesAttributes.RendererFunctionName(hasFormatter);
    formatterFcnHandle = cellfun(@str2func, fcnNames, 'UniformOutput', false);
    if nargout == 2
        varNames = tableVariablesAttributes.Name(hasFormatter);
    else
        clear varNames
    end
end
