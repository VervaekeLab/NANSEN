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
        % Convert attributes collected via user interaction to a
        % FileAttributes meta object
        opts = S;
        opts = rmfield(opts, "AdapterType");
        fileAdapterMeta = nansen.plugin.fileadapter.FileAdapterMeta(opts);
        nansen.plugin.fileadapter.createFileAdapter(targetPath, fileAdapterMeta, S.AdapterType)
    end
end
