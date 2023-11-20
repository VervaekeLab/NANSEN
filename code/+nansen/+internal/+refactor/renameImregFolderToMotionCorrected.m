function renameImregFolderToMotionCorrected()
    
    % Get project catalog
    projectManager = nansen.ProjectManager;
    
    
    % Loop through projects and rename folders.
    for iProject = [4, 1:projectManager.NumProjects]
        
        project = projectManager.getProjectObject(iProject);
        
        metaTable = project.MetaTableCatalog.getMasterMetaTable;
        dlModel = project.DataLocationModel;
        % Loop through all sessions and move files from old folder to new
        % folder
        
        
        % Loop through variable model and rename all subfolders.
        varModel = project.VariableModel;

        for i = 1:varModel.NumVariables
            iVarItem = varModel.getItem(i);
            if strcmp(iVarItem.Subfolder, 'image_registration')
                iVarItem.Subfolder = 'motion_corrected';
                varModel.replaceItem(iVarItem)
            end
            varModel.save()
        end
        
        refVar = varModel.getItem('TwoPhotonSeries_Corrected');
        
        dataLocationStructs = metaTable.entries.DataLocation;
        dataLocationStructs = dlModel.validateDataLocationPaths(dataLocationStructs);
        dataLocationStructs = arrayfun(@(i) dataLocationStructs(i,:), 1:size(dataLocationStructs,1), 'uni', 0);
        metaTable.replaceDataColumn('DataLocation', dataLocationStructs)
        
        for i = 1:size(metaTable.entries, 1)
            thisDLStruct = metaTable.entries{i, 'DataLocation'};
            if ~isfield(thisDLStruct, 'Name')
                 thisDLStruct = dlModel.expandDataLocationInfo(thisDLStruct);
            end
            thisDlItem = thisDLStruct(strcmp({thisDLStruct.Name}, refVar.DataLocation));
            
            if isempty(thisDlItem.RootUid)
                continue
            end
            
            sourceDirPathStr = fullfile(thisDlItem.RootPath, thisDlItem.Subfolders, 'image_registration');
            if isfolder(sourceDirPathStr)
                targetDirPathStr = strrep(sourceDirPathStr, 'image_registration', 'motion_corrected');
                movefile(sourceDirPathStr, targetDirPathStr)
            end
            
            sourceDirPathStr = fullfile(thisDlItem.RootPath, thisDlItem.Subfolders, 'image_registration_');
            if isfolder(sourceDirPathStr)
                targetDirPathStr = strrep(sourceDirPathStr, 'image_registration_', 'motion_corrected_');
                movefile(sourceDirPathStr, targetDirPathStr)
            end
            
        end

    end
end