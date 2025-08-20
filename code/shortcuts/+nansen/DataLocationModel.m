function dataLocationModel = DataLocationModel()
%nansen.DataLocationModel Interface for managing datalocations of project
%
%   nansen.DataLocationModel opens an app for editing the DataLocationModel
%   of the current project
%
%   h = nansen.DataLocationModel returns an instance of the
%   DataLocationModel of the current project.

%   Todo: Support input filepath or project name? Then it is possible to
%   open model for another project.

    pm = nansen.ProjectManager;
    project = pm.getCurrentProject();
    if isempty(project)
        dataLocationModel = [];
        if ~nargout
            error('There is no active project.')
        end
        return
    else
        dataLocationModel = project.DataLocationModel;
    end

    if ~nargout
        nansen.config.dloc.DataLocationModelApp('DataLocationModel', dataLocationModel);
        clear dataLocationModel
    end
end
