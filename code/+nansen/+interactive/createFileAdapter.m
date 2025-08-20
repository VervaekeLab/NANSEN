function createFileAdapter()
    currentProject = nansen.getCurrentProject();
    if isempty(currentProject)
        error('Need an active project to create a file adapter.')
    end
    targetPath = currentProject.getFileAdapterFolder();
    [S, wasAborted] = nansen.module.uigetFileAdapterAttributes();
    if wasAborted
        return
    else
        nansen.module.createFileAdapter(targetPath, S)
    end
end
