function openProject(projectName)
% openProject - Open the specified project in NANSEN.
%
%   If no project is selected, a selection dialog will appear.

    arguments
        projectName (1,1) string = missing
    end

    if ismissing(projectName)
        pm = nansen.ProjectManager();
        pm.uiSelectProject();
    end

    nansen()
end
