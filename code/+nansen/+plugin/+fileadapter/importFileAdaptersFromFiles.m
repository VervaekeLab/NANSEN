function importFileAdaptersFromFiles(targetFolder)
%importFileAdaptersFromFiles Batch-import class-based (.m) file adapters into a project folder
%
%   importFileAdaptersFromFiles(targetFolder) opens a multi-select file
%   picker for .m files, resolves any naming conflicts with files already in
%   targetFolder, copies the selected files, and shows a summary dialog.

    arguments
        targetFolder (1,1) string
    end

    [filenames, folder] = uigetfile('*.m', 'Select File Adapter Files', 'MultiSelect', 'on');
    if isequal(filenames, 0); return; end
    if ischar(filenames); filenames = {filenames}; end

    if ~isfolder(targetFolder); mkdir(targetFolder); end

    conflictAction = nansen.plugin.fileadapter.internal.resolveImportConflicts( ...
        filenames, targetFolder);
    if strcmp(conflictAction, 'cancel'); return; end

    success  = false(1, numel(filenames));
    messages = repmat({''}, 1, numel(filenames));

    for i = 1:numel(filenames)
        destPath = fullfile(targetFolder, filenames{i});
        if exist(destPath, 'file') > 0 && strcmp(conflictAction, 'skip')
            messages{i} = 'Skipped';
            continue
        end
        try
            copyfile(fullfile(folder, filenames{i}), destPath);
            success(i) = true;
        catch ME
            messages{i} = ME.message;
        end
    end

    nansen.plugin.fileadapter.internal.showImportResultsDialog(filenames, success, messages);
end
