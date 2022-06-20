function validate()
%validate Make changes to files/userdata if nansen has been upgraded    
    
    pm = nansen.ProjectManager();
    
    % Move tablevar folder into project folder namespace if this has not
    % been done yet:
    projectInfo = pm.getProject(pm.CurrentProject);
    filePath = fullfile(projectInfo.Path, 'Metadata Tables', '+tablevar');
    if isfolder(filePath)
        nansen.refactor.moveTableVarsToProjectNameSpace()
    end
    
    
end