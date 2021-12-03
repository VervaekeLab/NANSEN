function createProject(name, description, pathStr)

% Todo: Call functions/classes from nansen.setup... (i.e )

    
    % Add project to project manager.
    projectManager = nansen.setup.model.ProjectManager();
    projectManager.addProject(name, description, pathStr)
    

    % Make folder to save project related setting and metadata to
    if ~exist(pathStr, 'dir');    mkdir(pathStr);   end
    
    % Initialize a metatable Catalog
    
    % Set as current project
    projectManager.changeProject(name)
    
    
end