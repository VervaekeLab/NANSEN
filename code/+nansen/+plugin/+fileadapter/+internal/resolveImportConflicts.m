function conflictAction = resolveImportConflicts(destNames, targetFolder)
%resolveImportConflicts Detect naming conflicts and ask the user how to proceed
%
%   conflictAction = resolveImportConflicts(destNames, targetFolder) checks
%   whether any names in destNames already exist in targetFolder. If none
%   do, returns 'overwrite' immediately. If some do, prompts the user:
%       'Overwrite All' -> returns 'overwrite'
%       'Skip Existing' -> returns 'skip'
%       'Cancel'        -> returns 'cancel'

    existingNames = destNames( ...
        cellfun(@(n) exist(fullfile(targetFolder, n), 'file') > 0, destNames));

    if isempty(existingNames)
        conflictAction = 'overwrite';
        return
    end

    displayNames = regexprep(existingNames, '^[+@]+', '');
    displayNames = cellfun(@(n) strrep(n, '.m', ''), displayNames, 'uni', 0);

    answer = questdlg( ...
        sprintf('The following already exist in this project:\n\n  %s\n', ...
            strjoin(displayNames, [newline, '  '])), ...
        'Conflicts Found', 'Overwrite All', 'Skip Existing', 'Cancel', 'Skip Existing');

    switch answer
        case 'Overwrite All';  conflictAction = 'overwrite';
        case 'Skip Existing';  conflictAction = 'skip';
        otherwise;             conflictAction = 'cancel';
    end
end
