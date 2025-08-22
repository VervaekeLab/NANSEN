function createFileAdapter()
    currentProject = nansen.getCurrentProject();
    if isempty(currentProject)
        error('Need an active project to create a file adapter.')
    end
    targetPath = currentProject.getFileAdapterFolder();
    [S, wasAborted] = nansen.plugin.fileadapter.uigetFileAdapterAttributes();
    if wasAborted
        return
    else
        nansen.plugin.fileadapter.createFileAdapter(targetPath, S)
    end
end
