function hModel = VariableModel(varargin)
%VariableModel Interface for managing variables
%
%   This function is a shortcut
%
%   See also nansen.config.varmodel.VariableModel

    pm = nansen.ProjectManager;
    project = pm.getCurrentProject();
    if isempty(project)
        hModel = [];
    else
        hModel = project.VariableModel;
    end
end
