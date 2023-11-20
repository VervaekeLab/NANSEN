function moveTableVarsToProjectNameSpace(projectFolderPath)
        
    try
        % Move table vars folder into a package with project name
        [~, projectName] = fileparts(projectFolderPath);
        projectPackageName = strcat('+', projectName);

        tableFolder = fullfile(projectFolderPath, 'Metadata Tables');

        tableVarFolderSource = fullfile(tableFolder, '+tablevar');
        tableVarFolderTarget = fullfile(tableFolder, projectPackageName, '+tablevar');
        
        if ~isfolder(tableVarFolderSource)
            return
        end
        
        if isfolder(tableVarFolderTarget)
            %fprintf('Table variables are already moved for project "%s"\n', projectName)
            return
        end
        
        movefile(tableVarFolderSource, tableVarFolderTarget)
        fprintf('Moved tablevariables to project namespace for project "%s"\n', projectName)

    catch ME
        fprintf('Failed to move tablevariables to project namespace for project "%s"\n', projectName)
        disp(getReport(ME, 'extended'))
    end
    
end

% Update folder where table vars are located in nansen.localpath
% Update the function name for table variable functions (include project package)