function reorganizeProjectFolder(projectFolderPath)
    
    % Make backup:
    try 
        projectFolderPathBackup = [projectFolderPath, '_backup'];
        copyfile(projectFolderPath, projectFolderPathBackup);
        rmdir(projectFolderPath, 's')
    catch
        error('Something went wrong during backup.')
    end

    % Load project configuration
    filePath = fullfile(projectFolderPathBackup, 'nansen_project_configuration.mat');
    S = load(filePath, 'ProjectConfiguration');
    
    % Create a new project folder:
    templateFolder = fullfile(nansen.rootpath, 'modules', 'resources', 'project_template_A');
    targetFolder = projectFolderPath;

    copyfile(templateFolder, targetFolder)

    % Save project configuration as project.nansen.json
    configStr = jsonencode(S, 'PrettyPrint', true);
    fid = fopen(fullfile(projectFolderPath, 'project.nansen.json'), 'w');
    fwrite(fid, configStr);
    fclose(fid);

    projectPackageName = ['+', S.ProjectConfiguration.Name];
    
    % Rename code package folder:
    oldPacakgeFolder = fullfile(projectFolderPath, 'code', '+projectname');
    newPackageFolder = fullfile(projectFolderPath, 'code', projectPackageName);
    movefile(oldPacakgeFolder, newPackageFolder)

    % Move session methods
    oldTableVarFolder = fullfile(projectFolderPathBackup, 'Session Methods', projectPackageName);
    newTableVarFolder = fullfile(projectFolderPath, 'code', projectPackageName, '+internal', '+sessionmethod');
    
    copyfile(oldTableVarFolder, newTableVarFolder)

    % Move table variables methods
    oldTableVarFolder = fullfile(projectFolderPathBackup, 'Metadata Tables', projectPackageName, '+tablevar');
    newTableVarFolder = fullfile(projectFolderPath, 'code', projectPackageName, '+internal', '+tablevariable');
    
    copyfile(oldTableVarFolder, newTableVarFolder)

    % Copy metadata:
    oldMetadataFolder = fullfile(projectFolderPathBackup, 'Metadata Tables');
    newMetadataFolder = fullfile(projectFolderPath, 'metadata');
    
    copyfile(oldMetadataFolder, newMetadataFolder)

    % Remove table variable folder:
    rmdir( fullfile(newMetadataFolder, projectPackageName), "s" )

    % Copy config files
    oldConfigFolder = fullfile(projectFolderPathBackup, 'Configurations');
    newConfigFolder = fullfile(projectFolderPath, 'configuration');
    
    copyfile(oldConfigFolder, newConfigFolder)

    % Rename options files:
    L = utility.dir.recursiveDir(fullfile(newConfigFolder, 'custom_options'), 'Type', 'file', 'FileType', 'mat');
    filePaths = utility.dir.abspath(L);

    projectName = S.ProjectConfiguration.Name;
    for i = 1:numel(filePaths)
        thisFilePath = filePaths{i};
        newFilePath = strrep(thisFilePath, [projectName, '.'], sprintf('%s.internal.sessionmethod.', projectName));
        if ~strcmp(thisFilePath, newFilePath)
            movefile(thisFilePath, newFilePath)
        end
    end

end