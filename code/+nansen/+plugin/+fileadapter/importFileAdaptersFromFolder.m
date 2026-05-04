function importFileAdaptersFromFolder(targetFolder)
%importFileAdaptersFromFolder Scan a folder for file adapters and batch-import them
%
%   importFileAdaptersFromFolder(targetFolder) opens a folder picker, scans
%   the selected folder for class- and folder-based file adapters, resolves
%   any naming conflicts with items already in targetFolder, copies them,
%   and shows a summary dialog.

    arguments
        targetFolder (1,1) string
    end

    folderPath = uigetdir('', 'Select Folder Containing File Adapters');
    if isequal(folderPath, 0); return; end

    items = nansen.plugin.fileadapter.internal.scanFolderForFileAdapters(folderPath);
    if isempty(items)
        msgbox('No file adapters were found in the selected folder.', ...
            'No File Adapters Found', 'warn');
        return
    end

    destNames = {items.destName};

    if ~isfolder(targetFolder); mkdir(targetFolder); end

    conflictAction = nansen.plugin.fileadapter.internal.resolveImportConflicts( ...
        destNames, targetFolder);
    if strcmp(conflictAction, 'cancel'); return; end

    success  = false(1, numel(items));
    messages = repmat({''}, 1, numel(items));

    for i = 1:numel(items)
        destPath = fullfile(targetFolder, items(i).destName);
        alreadyExists = exist(destPath, 'file') > 0;

        if alreadyExists && strcmp(conflictAction, 'skip')
            messages{i} = 'Skipped';
            continue
        end
        try
            if alreadyExists && isfolder(destPath)
                rmdir(destPath, 's');
            end
            copyfile(items(i).sourcePath, destPath);
            success(i) = true;
        catch ME
            messages{i} = ME.message;
        end
    end

    nansen.plugin.fileadapter.internal.showImportResultsDialog(destNames, success, messages);
end
