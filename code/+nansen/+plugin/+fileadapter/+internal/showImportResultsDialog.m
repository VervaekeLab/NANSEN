function showImportResultsDialog(names, success, messages)
%showImportResultsDialog Show a summary msgbox after a batch file adapter import
%
%   showImportResultsDialog(names, success, messages) displays counts for
%   imported / skipped / failed items, lists the names of successfully
%   imported adapters, and shows per-item error messages for any failures.

    displayNames = regexprep(names, '^[+@]+', '');
    displayNames = cellfun(@(n) strrep(n, '.m', ''), displayNames, 'uni', 0);

    skipped  = cellfun(@(m) strcmp(m, 'Skipped'), messages);
    nSuccess = sum(success);
    nSkipped = sum(skipped);
    nFailed  = sum(~success & ~skipped);

    header = sprintf('Imported: %d     Skipped: %d     Failed: %d', ...
        nSuccess, nSkipped, nFailed);

    lines = {header};

    successIdx = find(success);
    if ~isempty(successIdx)
        lines{end+1} = '';
        lines{end+1} = 'Imported:';
        for i = successIdx(:)'
            lines{end+1} = sprintf('  %s', displayNames{i});
        end
    end

    failedIdx = find(~success & ~skipped);
    if ~isempty(failedIdx)
        lines{end+1} = '';
        lines{end+1} = 'Failed:';
        for i = failedIdx(:)'
            lines{end+1} = sprintf('  %s: %s', displayNames{i}, messages{i});
        end
    end

    msgbox(strjoin(lines, newline), 'Import Results');
end
