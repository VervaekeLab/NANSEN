function moveTableVarsToProjectNameSpace()
    
    % Get project catalog
    projectManager = nansen.ProjectManager;
    
    % Loop through projects
    for iProject = 1:projectManager.NumProjects
        
        try
            % Move table vars folder into a package with project name
            projectFolder = projectManager.Catalog(iProject).Path;
            projectName = projectManager.Catalog(iProject).Name;
            projectPackageName = strcat('+', projectName);

            tableFolder = fullfile(projectFolder, 'Metadata Tables');

            tableVarFolderSource = fullfile(tableFolder, '+tablevar');
            tableVarFolderTarget = fullfile(tableFolder, projectPackageName, '+tablevar');
            
            if ~isfolder(tableVarFolderSource)
                continue
            end
            
            if isfolder(tableVarFolderTarget)
                fprintf('Table variables are already moved for project "%s"\n', projectName)
                continue
            end
            
            movefile(tableVarFolderSource, tableVarFolderTarget)
            fprintf('Moved tablevariables to project namespace for project "%s"\n', projectName)

        catch ME
            fprintf('Failed to move tablevariables to project namespace for project "%s"\n', projectName)
            disp(getReport(ME, 'extended'))
        end

    end
    
end



% Update folder where table vars are located in nansen.localpath
% Update the function name for table variable functions (include project package)